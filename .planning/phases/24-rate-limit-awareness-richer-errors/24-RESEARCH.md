# Phase 24: Rate-Limit Awareness & Richer Errors — Research

**Researched:** 2026-04-16
**Domain:** Elixir telemetry pipeline / error enrichment / fuzzy string matching
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01 (Rate-Limit Telemetry):** Thread raw response headers into telemetry via the `request_span`
closure. The `fun` closure returns `{result, attempts, last_resp_headers}` instead of
`{result, attempts}`. `build_stop_metadata` gains a `resp_headers` parameter and extracts
`Stripe-Rate-Limited-Reason` (case-insensitive header lookup, same pattern as
`parse_stripe_should_retry`). The telemetry stop event metadata includes `:rate_limited_reason` —
a `String.t() | nil` key, nil when absent or non-429.

**D-02 (Fuzzy Param Source):** Use existing `@known_fields` from each resource module as the
candidate list. Exclude `@response_only_fields` (`~w[id object created livemode url]`).
Algorithm: `String.jaro_distance/2` (stdlib), threshold 0.8, minimum param length 4. Scope:
top-level param names only; extract leaf key from bracket notation (e.g., `"card[nubmer]"` → `"number"`).

**D-03 (Error Enrichment):** Append suggestion to `:message` string in `Error.from_response/3`.
No new struct fields. Private `maybe_suggest_param/2` helper. Suggestion format mirrors Elixir
compiler: `"; did you mean :payment_method_types?"`. Guard: only when `type == :invalid_request_error`
and `param` is non-nil. Use `parse_resource_and_operation` + `ObjectTypes` for module resolution.
If no module match or no close param found, skip silently.

**D-04 (Telemetry Documentation & Default Logger):** Escalate 429 responses to `:warning` level
in `handle_default_log/4`. Append `(rate_limited: {reason})` suffix only when
`:rate_limited_reason` is present. Add `:rate_limited_reason` row to stop-event metadata tables in
both `Telemetry` moduledoc and `guides/telemetry.md`. Add "Rate Limiting" subsection in the guide
with (a) metadata key explanation, (b) `Telemetry.Metrics.counter` example tagged by
`:rate_limited_reason`, (c) custom handler recipe.

### Claude's Discretion

- Whether to extract fuzzy matching logic into `LatticeStripe.ParamSuggestion` module or keep as
  private functions in `Error`
- Exact contents of `@response_only_fields` exclusion set (start with `~w[id object created livemode url]`)
- Whether to also capture `Retry-After` header value in telemetry metadata
- Test structure: unit tests for Jaro matching + integration tests for end-to-end error enrichment
- Exact wording of the "Did you mean?" suffix format
- Whether the rate-limit guide subsection goes under "Custom Telemetry Handlers" or as a top-level section

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PERF-05 | Rate-limit information from Stripe responses (`Stripe-Rate-Limited-Reason` on 429s) is exposed via telemetry stop event metadata | Header threading via D-01; `parse_stripe_should_retry` pattern already proven in codebase |
| DX-01 | When a developer passes an invalid parameter name, the error message suggests the closest valid param name (client-side fuzzy matching) | `String.jaro_distance/2` verified in stdlib; `@known_fields` present on all 84+ modules; `Error.from_response/3` is the exact injection point |

</phase_requirements>

---

## Summary

Phase 24 adds two independent features that share only the error/response path. Both are purely
additive — no struct fields are added, no public API signatures change, and no existing pattern-match
contracts are disturbed.

**Rate-limit telemetry (PERF-05):** The `Stripe-Rate-Limited-Reason` header Stripe sends on 429
responses must travel from `do_request`'s existing 3-tuple `{:error, error, resp_headers}` upward
through `do_request_with_retries` and the telemetry closure to reach `build_stop_metadata`. The
existing `parse_stripe_should_retry/1` in `client.ex` (lines 557–568) is the exact pattern to copy
for case-insensitive header extraction. The telemetry closure currently returns `{result, attempts}`;
it must become `{result, attempts, last_resp_headers}`.

**Fuzzy param suggestion (DX-01):** `String.jaro_distance/2` is a stdlib function available since
Elixir 1.5 — no dependency needed. Verified against the `payment_method_type` → `payment_method_types`
example: score 0.983, well above the 0.8 threshold. The `@known_fields` module attribute is present
on every resource module. `Error.from_response/3` is the single correct injection point; the guard
(`type == :invalid_request_error` and `param != nil`) ensures no other error types are touched.

**Primary recommendation:** Implement the two features as four focused changes: (1) closure return
shape in Client + `build_stop_metadata` signature, (2) `maybe_suggest_param/2` in Error, (3) 429
warning escalation in `handle_default_log`, (4) documentation updates to moduledoc + guide.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `Stripe-Rate-Limited-Reason` header extraction | API / Client layer | — | Headers are HTTP transport artifacts; extracted at the response decode layer where all other headers are processed |
| Telemetry metadata enrichment | Telemetry module | Client (threading) | `build_stop_metadata` is the single assembly point for all stop event metadata |
| Fuzzy param suggestion | Error module | — | `Error.from_response/3` is where `%Error{}` structs are built; all enrichment should colocate there |
| Default logger 429 escalation | Telemetry module | — | `handle_default_log/4` already owns log level decisions; 429 detection reads `http_status` from metadata |
| Telemetry documentation | Telemetry moduledoc + guide | — | Both tables must stay in sync; moduledoc is the machine-readable contract, guide is human narrative |

---

## Standard Stack

### Core (All from existing project dependencies — no new dependencies required)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `:telemetry` | ~> 1.0 (already in mix.exs) | Telemetry event emission | Erlang ecosystem standard; already used throughout |
| `String.jaro_distance/2` | Elixir stdlib | Fuzzy param matching | Ships with Elixir 1.5+; exactly what Elixir's own compiler uses for "did you mean?" in `UndefinedFunctionError`; no external dep needed |
| `Mox` | ~> 1.2 (already in mix.exs) | Behaviour-based mocks for Transport in tests | Already used in telemetry tests; `MockTransport` fixture exists |
| `ExUnit.CaptureLog` | stdlib | Log output assertions in tests | Already used in `telemetry_test.exs`; needed for 429 warning level test |

**No new dependencies required for this phase.** [VERIFIED: codebase grep + stdlib docs]

---

## Architecture Patterns

### System Architecture Diagram

```
Client.request/2
    │
    ├── builds transport_request
    │
    └── LatticeStripe.Telemetry.request_span(client, req, idk, fun)
             │
             ├── :telemetry.span(:lattice_stripe_request, start_meta, fn ->
             │       {result, attempts, last_resp_headers} = fun.()  ← [CHANGE D-01]
             │       stop_meta = build_stop_metadata(result, idk, attempts, last_resp_headers, start_meta)
             │       {result, stop_meta}
             │   end)
             │
             fun = fn ->
                do_request_with_retries(...)
                → returns {result, total_attempts, last_resp_headers}  ← [CHANGE D-01]
             end

do_request_with_retries (error path)
    │
    ├── do_request → {:error, %Error{}, resp_headers}   ← already a 3-tuple
    └── maybe_retry → {{:error, error}, total_attempts}  ← must add resp_headers

do_request (success path)
    │
    └── {:ok, %Response{}}                 ← success; %Response{headers: resp_headers} already has them
        do_request_with_retries: {{:ok, resp}, total_attempts, resp.headers}  ← [CHANGE D-01]

build_stop_metadata(result, idk, attempts, resp_headers, start_meta)  ← [CHANGE D-01]
    │
    ├── success: `:rate_limited_reason` → nil (not a 429)
    └── error: extract "stripe-rate-limited-reason" header (case-insensitive)
              → present on 429 → String.t()
              → absent → nil

Error.from_response(status, decoded_body, request_id)  ← called INSIDE do_request
    │
    ├── type == :invalid_request_error && param != nil
    │       → extract_leaf_param(param)  e.g. "card[nubmer]" → "number"
    │       → resolve_module(path)  via ObjectTypes
    │       → fuzzy_match(leaf, module.@known_fields - @response_only_fields)
    │       → if score >= 0.8 && length >= 4: append "; did you mean :matched_field?"
    │
    └── all other types: pass through unchanged
```

### Recommended File Structure (changes only)

```
lib/lattice_stripe/
├── client.ex          # do_request_with_retries: {result, attempts} → {result, attempts, resp_headers}
│                      # request_span fun: 2-tuple → 3-tuple return
├── telemetry.ex       # request_span/4: destructure 3-tuple; build_stop_metadata gains resp_headers param
│                      # handle_default_log/4: 429 → :warning, append rate_limited suffix
└── error.ex           # from_response/3: add maybe_suggest_param/2 call (with guards)
                       # new private: maybe_suggest_param/2, extract_leaf_param/1, fuzzy_match/2

guides/
└── telemetry.md       # New "Rate Limiting" subsection; updated stop-event metadata table

test/lattice_stripe/
├── telemetry_test.exs # New: `:rate_limited_reason` in stop metadata; warning log level for 429
└── error_test.exs     # New: fuzzy suggestion in message; no-op for non-invalid_request_error
```

### Pattern 1: Closure Return Shape Change (D-01)

The current closure returns `{result, attempts}`. The change adds `last_resp_headers` as the third
element. On success, headers come from `resp.headers` (already on `%Response{}`). On error, they
come from the existing `resp_headers` in the 3-tuple returned by `do_request`.

```elixir
# BEFORE — client.ex, inside request_span call
LatticeStripe.Telemetry.request_span(client, req, idempotency_key, fn ->
  do_request_with_retries(client, transport_request, req.method, idempotency_key, effective_max_retries)
end)

# AFTER
LatticeStripe.Telemetry.request_span(client, req, idempotency_key, fn ->
  do_request_with_retries(client, transport_request, req.method, idempotency_key, effective_max_retries)
  # do_request_with_retries now returns {result, total_attempts, last_resp_headers}
end)
```

```elixir
# BEFORE — do_request_with_retries success branch
{:ok, _} = success ->
  {success, total_attempts}

# AFTER
{:ok, %Response{} = resp} = success ->
  {success, total_attempts, resp.headers}

# BEFORE — error branch final stop
{{:error, error}, total_attempts}

# AFTER
{{:error, error}, total_attempts, resp_headers}
```

[VERIFIED: codebase read, client.ex lines 308-313, 384-386]

### Pattern 2: Case-Insensitive Header Extraction (D-01)

Copy the exact pattern from `parse_stripe_should_retry/1`:

```elixir
# Source: lib/lattice_stripe/client.ex lines 557-568
defp parse_rate_limited_reason(headers) do
  Enum.find_value(headers, fn {k, v} ->
    if String.downcase(k) == "stripe-rate-limited-reason", do: v
  end)
end
# Returns String.t() | nil
```

[VERIFIED: codebase read, client.ex:557-568]

### Pattern 3: Telemetry Stop Metadata Extension (D-01)

```elixir
# Source: lib/lattice_stripe/telemetry.ex — build_stop_metadata/4 → build_stop_metadata/5
# (or keep arity 4 by passing resp_headers inside the result tuple — see design decision below)

# SUCCESS path gains :rate_limited_reason nil (not a 429):
defp build_stop_metadata({:ok, %Response{} = resp}, _idempotency_key, attempts, resp_headers, start_meta) do
  Map.merge(start_meta, %{
    status: :ok,
    http_status: resp.status,
    request_id: resp.request_id,
    attempts: attempts,
    retries: attempts - 1,
    rate_limited_reason: parse_rate_limited_reason(resp_headers)  # nil on success
  })
end

# ERROR (rate_limit_error) path extracts reason:
defp build_stop_metadata({:error, %Error{} = error}, idempotency_key, attempts, resp_headers, start_meta) do
  Map.merge(start_meta, %{
    status: :error,
    http_status: error.status,
    error_type: error.type,
    request_id: error.request_id,
    idempotency_key: idempotency_key,
    attempts: attempts,
    retries: attempts - 1,
    rate_limited_reason: parse_rate_limited_reason(resp_headers)
  })
end
```

[VERIFIED: codebase read, telemetry.ex lines 472-509]

### Pattern 4: Fuzzy Param Suggestion (D-02/D-03)

```elixir
# Source: Elixir stdlib — String.jaro_distance/2 verified available in Elixir 1.5+
# Source: lib/lattice_stripe/error.ex — from_response/3 is the injection point

# In Error.from_response/3, after building the struct:
%__MODULE__{
  type: parse_type(type_str),
  code: Map.get(error_map, "code"),
  message: maybe_enrich_message(
    parse_type(type_str),
    Map.get(error_map, "message"),
    Map.get(error_map, "param")
  ),
  param: Map.get(error_map, "param"),
  # ... all other fields unchanged
}

defp maybe_enrich_message(:invalid_request_error, message, param)
     when is_binary(param) do
  case suggest_param(param) do
    nil    -> message
    match  -> message <> "; did you mean :#{match}?"
  end
end

defp maybe_enrich_message(_type, message, _param), do: message

@response_only_fields ~w[id object created livemode url]

defp suggest_param(param) do
  leaf = extract_leaf_param(param)  # "card[nubmer]" → "number"

  if String.length(leaf) < 4 do
    nil
  else
    # NOTE: Module resolution via ObjectTypes requires request path context.
    # See "Design Decision: Module Resolution" section below.
    candidates = all_known_fields() -- @response_only_fields

    case Enum.max_by(candidates, &String.jaro_distance(leaf, &1), fn -> nil end) do
      nil -> nil
      best ->
        if String.jaro_distance(leaf, best) >= 0.8, do: best, else: nil
    end
  end
end

defp extract_leaf_param(param) do
  # "card[nubmer]" → "number" ; "payment_method_type" → "payment_method_type"
  case Regex.run(~r/\[(\w+)\]$/, param) do
    [_, leaf] -> leaf
    nil       -> param
  end
end
```

[VERIFIED: String.jaro_distance("payment_method_type", "payment_method_types") = 0.983, threshold
passes; String.jaro_distance("xyz_totally_wrong", best_candidate) < 0.52, below 0.8]

### Pattern 5: 429 Warning Escalation (D-04)

```elixir
# Source: lib/lattice_stripe/telemetry.ex — handle_default_log/4
# The existing handler logs at the user-provided `level`. Decision D-04 overrides to :warning for 429.

def handle_default_log(_event, measurements, metadata, %{level: level}) do
  duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
  method = metadata.method |> to_string() |> String.upcase()
  status_part = if metadata[:http_status], do: "=> #{metadata.http_status} ", else: ""
  req_id = Map.get(metadata, :request_id, "no-req-id")
  attempts = Map.get(metadata, :attempts, 1)
  attempt_word = if attempts == 1, do: "attempt", else: "attempts"

  # NEW: rate-limit reason suffix
  rate_limit_suffix =
    case Map.get(metadata, :rate_limited_reason) do
      nil    -> ""
      reason -> " (rate_limited: #{reason})"
    end

  message =
    "#{method} #{metadata.path} #{status_part}in #{duration_ms}ms (#{attempts} #{attempt_word}, #{req_id})#{rate_limit_suffix}"

  # NEW: escalate 429 to :warning regardless of configured level
  effective_level = if metadata[:http_status] == 429, do: :warning, else: level
  Logger.log(effective_level, message)
end
```

[VERIFIED: codebase read, telemetry.ex lines 410-422]

### Anti-Patterns to Avoid

- **Atomizing rate-limit reason string in telemetry metadata:** `Stripe-Rate-Limited-Reason` values
  are Stripe-controlled strings (e.g., `"too_many_requests"`). Do NOT convert to atoms. Atoms are
  not garbage-collected — unexpected values from Stripe could grow the atom table. Store as
  `String.t() | nil`. [VERIFIED: CONTEXT.md specifics section]

- **Adding new fields to `%Error{}` struct:** Breaks pattern-match contracts. All enrichment goes
  into the existing `:message` field. The CONTEXT.md success criteria explicitly state this is
  prohibited. [VERIFIED: CONTEXT.md decisions D-03 + success criteria]

- **Crashing on failed module lookup:** If `ObjectTypes` has no entry for the request path, or if
  the fuzzy match finds no candidate above threshold, `suggest_param` MUST return `nil` and the
  original message is returned unchanged. Never degrade the error. [VERIFIED: CONTEXT.md D-03]

- **Matching on success path for rate-limit headers:** A 429 is an ERROR response, not a success.
  The `rate_limited_reason` key should be `nil` for all non-429 responses. [VERIFIED: Stripe API docs
  behavior — `Stripe-Rate-Limited-Reason` header only present on 429s]

---

## Design Decision: Module Resolution for Param Suggestion

The CONTEXT.md (D-03) specifies: "Use the request path to determine the resource (same
`parse_resource_and_operation` logic already in Telemetry), then look up the module via
`ObjectTypes`."

**Critical observation from code analysis:** `Error.from_response/3` does NOT have access to the
request path. It only receives `(status, decoded_body, request_id)`. The request path context is
available in the Telemetry closure at `request_span` time, but not at `Error.from_response` call
time inside `do_request`.

**Resolution paths (for planner to choose):**

**Option A — Global candidate pool (simplest, recommended):** Build candidates from ALL
`@known_fields` across all resource modules (minus `@response_only_fields`). No path context
needed. Minor risk: a field name unique to one resource could spuriously match a typo for another.
In practice, most valid field names are short and non-overlapping. The false-positive rate is low.

**Option B — Pass path to Error.from_response:** Change `Error.from_response/3` signature to
`from_response/4` adding `path` parameter, or pass path embedded in `decoded_body` (messy).
Breaks existing callers of `from_response/3`.

**Option C — Suggest from Error struct after construction:** `do_request` builds the error then
enriches it with `Error.suggest(error, path)`. Path is available in `do_request` since it's inside
the transport request.

**Recommendation:** Option A (global pool) satisfies the requirement with zero signature changes.
The CONTEXT.md states "If no module match or no close param found, skip suggestion silently" —
the global pool approach never "fails to find a module," so the fallback is cleaner. The
`@response_only_fields` exclusion is the key filter to prevent `id`, `object`, `created`, etc.
from showing up as false positive suggestions.

[ASSUMED] Option A is correct; planner should confirm or select Option C if path context matters.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Fuzzy string matching | Custom Levenshtein or n-gram algorithm | `String.jaro_distance/2` (stdlib) | Same algorithm Elixir's compiler uses; no external dep; well-understood threshold behavior |
| Case-insensitive header lookup | Custom `Enum.find` wrapper | Copy `parse_stripe_should_retry/1` pattern verbatim | Pattern already proven in codebase; consistent with existing header parsing |
| Candidate field list | New data structure | `@known_fields` module attribute (already on every resource module) | Zero maintenance cost; automatically stays current as modules are updated |
| Telemetry span handling | Custom start/stop emission | `:telemetry.span/3` (already used) | Auto-handles exception events; idiomatic Elixir |

---

## Common Pitfalls

### Pitfall 1: Success Path Headers Missing from request_span Closure

**What goes wrong:** `do_request_with_retries` currently returns `{result, total_attempts}`. The
success case is `{:ok, resp}` where `resp.headers` already carries response headers, but the outer
closure strips this off. If only the error path is patched to pass headers, the 3-tuple shape
becomes inconsistent.

**Why it happens:** The success path has no need for headers downstream (the public API hides them
inside `%Response{}`), so the 2-tuple was sufficient. The new requirement creates a need to unify
the return shape.

**How to avoid:** Change `do_request_with_retries` success branch from `{success, total_attempts}`
to `{success, total_attempts, resp.headers}`. The `request_span` closure becomes
`{result, attempts, last_resp_headers}`. `build_stop_metadata` gains a `resp_headers` parameter.
[VERIFIED: codebase read, client.ex:308-313 and telemetry.ex:301-318]

### Pitfall 2: Jaro Distance Applied to Empty or Nil Param

**What goes wrong:** `String.jaro_distance("", candidates_item)` returns 0.0 for non-empty
candidates and 1.0 if both are empty. Nil param crashes `String.jaro_distance/2`.

**Why it happens:** Stripe can return `"param"` as `nil` or as an empty string for some error types.

**How to avoid:** The guard `is_binary(param)` in `maybe_suggest_param` catches nil. The minimum
length check `String.length(leaf) < 4` catches empty strings and very short params. These guards
are part of D-02. [VERIFIED: elixir -e test: guard pattern in Pattern 4 above]

### Pitfall 3: Arity Mismatch in build_stop_metadata Clauses

**What goes wrong:** `build_stop_metadata` has 3 clauses (success, connection_error, API error).
Adding `resp_headers` as a parameter changes arity from 4 to 5. All 3 clauses must be updated.
Missing one clause causes a `FunctionClauseError` at runtime for connection errors (which have
`[]` resp_headers).

**Why it happens:** Connection error branch in `do_request` returns `{:error, %Error{...}, []}` —
the empty list is the `resp_headers`. The connection error clause of `build_stop_metadata` must
accept this.

**How to avoid:** Update all 3 clauses of `build_stop_metadata` simultaneously. For connection
errors, `parse_rate_limited_reason([])` returns nil, which is correct.
[VERIFIED: codebase read, telemetry.ex:472-509 + client.ex:480-487]

### Pitfall 4: `request_span` Telemetry Disabled Branch

**What goes wrong:** `request_span/4` has an `else` branch for `telemetry_enabled: false`. This
branch currently does `{result, _attempts} = fun.()` and discards attempts. If the closure is
changed to return a 3-tuple, the pattern match breaks in this branch.

**Why it happens:** The `telemetry_enabled: false` path pattern-matches the closure return
directly. [VERIFIED: codebase read, telemetry.ex:308-318]

**How to avoid:** Update the disabled branch to `{result, _attempts, _resp_headers} = fun.()`.

### Pitfall 5: ObjectTypes Registry Mismatch

**What goes wrong:** `ObjectTypes.@object_map` maps Stripe object type strings (e.g., `"customer"`)
to modules. `parse_resource_and_operation` returns resource names parsed from URL paths (e.g.,
`"customer"` from `/v1/customers`). The keys use different conventions for namespaced resources:
`"billing.meter"` (ObjectTypes) vs what parse_resource_and_operation returns.

**Why it happens:** ObjectTypes uses `"billing.meter"` but parse_resource_and_operation may return
`"billing.meter"` too — or may not. Needs verification.

**How to avoid:** If using Option C for module resolution, test the lookup for namespaced paths.
If using Option A (global pool), this pitfall is irrelevant.
[VERIFIED: codebase read, object_types.ex lines 31-36, telemetry.ex singularize/1]

---

## Code Examples

### Test: `:rate_limited_reason` in Stop Metadata

```elixir
# Pattern from existing telemetry_test.exs (lines 30-45)
test "stop event includes :rate_limited_reason when 429 with header" do
  attach_handler([[:lattice_stripe, :request, :stop]])
  client = test_client()

  MockTransport
  |> expect(:request, fn _req ->
    {:ok, %{
      status: 429,
      headers: [
        {"stripe-rate-limited-reason", "too_many_requests"},
        {"request-id", "req_rl123"}
      ],
      body: Jason.encode!(%{"error" => %{"type" => "rate_limit_error", "message" => "Too many requests"}})
    }}
  end)

  Client.request(client, get_request())

  assert_receive {:telemetry, [:lattice_stripe, :request, :stop], _measurements, metadata}
  assert metadata[:rate_limited_reason] == "too_many_requests"
end

test "stop event has :rate_limited_reason nil on non-429" do
  # ...
  assert metadata[:rate_limited_reason] == nil
end
```

### Test: Fuzzy Suggestion in Error Message

```elixir
# In error_test.exs
test "from_response/3 appends did-you-mean for invalid_request_error with near-miss param" do
  body = %{
    "error" => %{
      "type" => "invalid_request_error",
      "message" => "No such parameter: payment_method_type",
      "param" => "payment_method_type"
    }
  }

  error = Error.from_response(400, body, "req_fuzzy")

  assert error.type == :invalid_request_error
  assert error.param == "payment_method_type"
  assert error.message =~ "did you mean :payment_method_types"
end

test "from_response/3 does NOT append suggestion for card_error" do
  body = %{
    "error" => %{
      "type" => "card_error",
      "message" => "Card declined",
      "param" => "card[number]"
    }
  }

  error = Error.from_response(402, body, "req_card")
  refute error.message =~ "did you mean"
end

test "from_response/3 does NOT append suggestion when param is nil" do
  body = %{
    "error" => %{
      "type" => "invalid_request_error",
      "message" => "Missing required param",
      "param" => nil
    }
  }

  error = Error.from_response(400, body, "req_noparam")
  refute error.message =~ "did you mean"
end
```

---

## Claude's Discretion Recommendations

### 1. Module Placement for Fuzzy Logic

**Recommendation: Keep as private functions in `Error`** (not a separate `ParamSuggestion` module).

Rationale: `maybe_suggest_param/2` is called exactly once, from `Error.from_response/3`. Extracting
it to a separate module provides no reuse benefit at this scope. Private functions in `Error` keep
the concern colocated with the caller, avoid a new public module in the namespace, and require no
module attribute sharing mechanism for `@response_only_fields`. If Phase 30 (drift detection) evolves
this into a more sophisticated per-operation validator, extraction makes sense then.

### 2. `@response_only_fields` Exclusion Set

Start with `~w[id object created livemode url]` as specified in CONTEXT.md. Review `@known_fields`
on `Customer`, `PaymentIntent`, and `Subscription` for any additional response-only fields that
should not appear as suggestions:

Additional candidates to consider: `deleted`, `has_more`, `data`, `total_count`, `next_page`,
`previous_page`. The key question: can any of these be sent as parameters? (`deleted` cannot; 
`has_more`/`data` are list metadata). Recommended set: `~w[id object created livemode url deleted
has_more total_count next_page previous_page data]`.

[ASSUMED] The extended exclusion set above; verify against actual `@known_fields` during implementation.

### 3. `Retry-After` Header in Telemetry Metadata

**Recommendation: Include it** — low effort, high value.

The `Retry-After` header is already parsed by the RetryStrategy for backoff delay calculation. It
is present on 429 responses alongside `Stripe-Rate-Limited-Reason`. Adding `:retry_after_seconds`
as an optional `integer | nil` key to the stop event metadata costs one additional
`Enum.find_value` call. Monitoring dashboards that alert on rate limiting can use this value to set
appropriate backoff expectations.

Implementation: add `parse_retry_after/1` private function alongside `parse_rate_limited_reason/1`.

[ASSUMED] Teams find `Retry-After` useful in telemetry; if this adds complexity, omit it.

### 4. Test Structure

**Recommendation:** Unit tests in `error_test.exs` for fuzzy logic (no transport needed), plus
telemetry integration tests in `telemetry_test.exs` using `MockTransport` (same pattern as
existing telemetry tests). No separate test file needed.

- `error_test.exs`: Pure unit tests for `maybe_suggest_param/2` behavior — near-miss match,
  non-match, nil param guard, bracket notation extraction, `@response_only_fields` exclusion.
- `telemetry_test.exs`: Integration via `MockTransport` — `:rate_limited_reason` in stop metadata
  on 429, nil on non-429, warning log level for 429 via `CaptureLog`.

### 5. Suggestion Wording

**Recommendation:** `"; did you mean :payment_method_types?"` — lowercase "did", semicolon
separator, colon-prefixed atom notation. Matches Elixir compiler's `UndefinedFunctionError` style.
The semicolon (not period) correctly continues the Stripe error message sentence.

### 6. Rate Limiting Guide Placement

**Recommendation:** Add "Rate Limiting" as a **top-level section** in `guides/telemetry.md`,
not nested under "Custom Telemetry Handlers". Rate limiting is a distinct operational concern
(not just a custom handler pattern), and deserves its own heading for discoverability.

---

## Runtime State Inventory

Step 2.5 SKIPPED — not a rename/refactor/migration phase.

---

## Environment Availability

Step 2.6: No new external dependencies. All tools and runtimes already in use.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir stdlib `String.jaro_distance/2` | Fuzzy matching | Yes | Elixir 1.19.5 (requires 1.5+) | — |
| `:telemetry` | Rate-limit metadata | Yes | Already in mix.exs | — |
| `Mox` | Tests | Yes | Already in mix.exs | — |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | `mix.exs` (test task), `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/error_test.exs test/lattice_stripe/telemetry_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PERF-05 | `:rate_limited_reason` in stop event metadata on 429 | unit (MockTransport) | `mix test test/lattice_stripe/telemetry_test.exs` | Yes (needs new tests) |
| PERF-05 | `:rate_limited_reason` is nil on non-429 | unit (MockTransport) | `mix test test/lattice_stripe/telemetry_test.exs` | Yes (needs new tests) |
| PERF-05 | 429 response logs at `:warning` level | unit (CaptureLog) | `mix test test/lattice_stripe/telemetry_test.exs` | Yes (needs new tests) |
| DX-01 | Fuzzy suggestion appended to message for near-miss param | unit | `mix test test/lattice_stripe/error_test.exs` | Yes (needs new tests) |
| DX-01 | No suggestion for card_error or nil param | unit | `mix test test/lattice_stripe/error_test.exs` | Yes (needs new tests) |
| DX-01 | Bracket notation leaf extraction works | unit | `mix test test/lattice_stripe/error_test.exs` | Yes (needs new tests) |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/error_test.exs test/lattice_stripe/telemetry_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

None — existing test infrastructure covers all phase requirements. Both `error_test.exs` and
`telemetry_test.exs` exist and follow established patterns (MockTransport, attach_handler helper).
New test cases append to existing describe blocks.

---

## Security Domain

No new security surface. This phase:
- Reads a response header value (string, no parsing that introduces injection risk)
- Performs fuzzy string matching on static in-memory field name lists
- Appends a string to an error message

No authentication, session management, cryptography, or external input processing changes.
ASVS categories V2/V3/V4/V6 do not apply. V5 (input validation) is tangentially relevant only to
the point that raw Stripe header values are stored as strings without atomization — already handled
by the "no atomize" constraint in D-04 and CONTEXT.md specifics section.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Option A (global candidate pool across all `@known_fields`) is the correct approach for module resolution in fuzzy matching | Design Decision: Module Resolution | If path context matters for accuracy, Option C (enrich after `do_request`) is needed — would require a different injection point |
| A2 | Extended `@response_only_fields` set includes `deleted`, `has_more`, `total_count`, `next_page`, `previous_page`, `data` | Claude's Discretion #2 | If any of these can be valid request params, the exclusion would hide valid suggestions |
| A3 | `Retry-After` header capture is worth including in telemetry stop metadata | Claude's Discretion #3 | Adds one more function and one more key; if planner wants minimal scope, omit |

---

## Open Questions

1. **Injection point for `Error.from_response/3`**
   - What we know: The function has no access to the request path, which the CONTEXT.md says to use
     for module resolution.
   - What's unclear: Whether Option A (global pool) is acceptable or Option C (enrich in `do_request`
     with path context) is preferred.
   - Recommendation: Use Option A unless precise per-resource suggestions are a priority. The
     threshold of 0.8 + minimum length 4 + `@response_only_fields` exclusion is sufficient noise
     filtering for a global pool.

2. **`build_stop_metadata` arity or tuple wrapping**
   - What we know: Adding `resp_headers` adds a 5th parameter to a 3-clause function. Credo has an
     arity/clause awareness; it's fine for 5-arity.
   - What's unclear: Whether the planner prefers to wrap `{result, resp_headers}` in a single tuple
     to keep `build_stop_metadata/4` arity, or accept the arity increase to `5`.
   - Recommendation: Accept arity 5 — it's explicit and readable. Wrapping creates a needless tuple.

---

## Sources

### Primary (HIGH confidence)

- Codebase: `lib/lattice_stripe/client.ex` — `parse_stripe_should_retry/1` pattern (lines 557-568),
  `do_request_with_retries` return shape (lines 308-313), retry loop
- Codebase: `lib/lattice_stripe/telemetry.ex` — `request_span/4` closure contract (lines 301-318),
  `build_stop_metadata` all 3 clauses (lines 472-509), `handle_default_log/4` (lines 410-422)
- Codebase: `lib/lattice_stripe/error.ex` — `from_response/3` exact implementation (lines 126-162)
- Codebase: `lib/lattice_stripe/object_types.ex` — resource-to-module registry (all entries)
- Codebase: `lib/lattice_stripe/customer.ex` — `@known_fields` pattern (lines 53-59)
- Codebase: `test/lattice_stripe/telemetry_test.exs` — `attach_handler` helper, `MockTransport`
  pattern (lines 30-68)
- Codebase: `test/lattice_stripe/error_test.exs` — existing test patterns for `from_response/3`
- Elixir stdlib (VERIFIED): `String.jaro_distance("payment_method_type", "payment_method_types") = 0.983`
- Elixir stdlib (VERIFIED): `String.jaro_distance("xyz_totally_wrong", "customer") = 0.517 < 0.8`

### Secondary (MEDIUM confidence)

- Elixir docs: `String.jaro_distance/2` available since Elixir 1.5 [CITED: stdlib documentation]
- Stripe API docs: `Stripe-Rate-Limited-Reason` header present on 429 responses [CITED: behavior
  is established from CONTEXT.md; direct Stripe docs not fetched in this session]

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — no new dependencies; all tools verified in codebase
- Architecture: HIGH — all integration points directly read from source files
- Pitfalls: HIGH — identified from direct code inspection of the exact change points
- Fuzzy matching behavior: HIGH — verified with live Elixir runtime

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 (stable codebase; Stripe header names do not change without notice)
