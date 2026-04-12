# Phase 2: Error Handling & Retry - Research

**Researched:** 2026-04-02
**Domain:** Elixir exception enrichment, retry loop architecture, idempotency key generation, Stripe error protocol
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Error Struct Enrichment**
- D-01: Full preservation — add named fields `param`, `decline_code`, `charge`, `doc_url` to the Error struct, plus `raw_body` map for the complete error envelope. Named fields give dot-access and pattern matching for common cases; `raw_body` is the escape hatch for anything Stripe adds later.
- D-02: Single Error struct with `:type` atom — no separate exception modules. Keep Phase 1 pattern. Add `:idempotency_error` as new type atom for 409 conflicts. `parse_type/1` gains one new clause.
- D-03: Implement `String.Chars` protocol on Error, delegating to `message/1`. Enables `"#{error}"` interpolation in strings and logging.
- D-04: No `Jason.Encoder` on Error — users explicitly control what they serialize. Security-first; prevents accidental leaking of `raw_body` or `request_id` to frontends.

**Error Message Formatting**
- D-05: Structured single-line format: `"(type) status code message (request: request_id)"`. Example: `"(card_error) 402 card_declined Your card has insufficient funds. (request: req_abc123)"`.

**RetryStrategy Behaviour**
- D-06: Single callback: `retry?(attempt :: pos_integer(), context()) :: {:retry, delay_ms :: non_neg_integer()} | :stop`. Context is a plain map (not a struct) with keys: `error`, `status`, `headers`, `stripe_should_retry`, `method`, `idempotency_key`.
- D-07: Behaviour and `RetryStrategy.Default` implementation live in the same file (`retry_strategy.ex`). Subdirectory reserved for future alternative strategies.
- D-08: `retry_strategy` config field on Client struct, type `:atom`, default `LatticeStripe.RetryStrategy.Default`. Consistent with `transport` and `json_codec`.

**Default Retry Behaviour**
- D-09: `Stripe-Should-Retry` header is authoritative when present. `true` → retry. `false` → stop. Absent → fall back to status-code heuristics: retry 429, 500+, connection errors; don't retry other 4xx.
- D-10: Respect `Retry-After` header on 429 responses with a 5-second cap (`@max_retry_after 5_000`). Use exponential backoff when header is absent.
- D-11: Connection errors (timeout, DNS failure, connection refused) are retriable by default. Capped by user's `max_retries`.
- D-12: 409 Idempotency conflicts are non-retriable — retrying with the same key and different params would hit the same conflict.
- D-13: Default `max_retries` changes from 0 to 2 (up to 3 total attempts). Exponential backoff with jitter: `min(500 * 2^(attempt-1), 5000)` jittered to 50-100% of calculated value.

**Retry Integration**
- D-14: Retry loop lives internal to `Client.request/2`. One telemetry span wraps all attempts. Per-retry telemetry events `[:lattice_stripe, :request, :retry]` emitted for each retry attempt.
- D-15: `Process.sleep/1` for retry delays. Users wrap in `Task.async` if they need non-blocking calls.
- D-16: Count-based retries only (`max_retries`). No wall-clock time budget.

**Per-Request Overrides**
- D-17: `max_retries` overridable per-request via `opts: [max_retries: 5]`. `retry_strategy` is per-client only.

**Idempotency Keys**
- D-18: Auto-generate UUID v4 for all POST requests. User-provided key takes precedence. Non-POST methods don't get auto-generated keys.
- D-19: Key format: `idk_ltc_` prefix + UUID v4. Example: `"idk_ltc_7f3a1b2c-4d5e-4f7a-8b9c-0d1e2f3a4b5c"`. 44 chars total.
- D-20: UUID v4 generated inline via `:crypto.strong_rand_bytes/1`. No hex dependency.
- D-21: Same idempotency key reused across all retry attempts for a single request. Generated once before the retry loop.

**Bang Variants**
- D-22: `Client.request!/2` added in Phase 2. Resource module bang variants added in Phase 4+.
- D-23: `request!/2` retries first, raises on final failure. Thin wrapper: calls `request/2`, unwraps `{:ok, result}`, raises `{:error, error}`.

**Telemetry**
- D-24: Rich metadata on stop event: `attempts`, `retries`, `request_id`, `idempotency_key`, `http_status`, `error_type`. Per-retry event with measurements `attempt` and `delay_ms`, metadata `method`, `path`, `error_type`, `status`.
- D-25: Telemetry only — no `Logger` calls in library code.

**Json Behaviour Evolution**
- D-26: Add `decode/1` and `encode/1` (non-bang) to `LatticeStripe.Json` behaviour for full bang/non-bang symmetry.
- D-27: Non-JSON responses produce a structured `%Error{type: :api_error}` with descriptive message and truncated body in `raw_body` under `%{"_raw" => "..."}` key. These flow through the retry loop normally.

**Naming**
- D-28: Keep `max_retries` naming. `max_retries: 2` means up to 3 total attempts.

**Test Strategy**
- D-29: Three-layer approach: (1) `RetryStrategy.Default` unit tests — pure functions, given context map assert return value. (2) Client retry integration tests — Mox transport + zero-delay test strategy for fast retry count verification, idempotency key reuse, header handling. (3) Client error tests — Mox transport + `max_retries: 0` for error struct fields, non-JSON handling, bang variants. All `async: true`.

### Claude's Discretion
- Internal helper function organization within modules
- Exact exponential backoff constants (500ms base, 5s max are guidelines)
- Jitter implementation details (50-100% range is guideline)
- Test fixture data shapes and assertion style
- `raw_body` truncation length for non-JSON responses (~500 bytes guideline)
- UUID v4 bit manipulation implementation details
- Error message wording for edge cases (empty body, HTML detection)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ERRR-01 | All public API functions return `{:ok, result} \| {:error, reason}` | Client.request/2 already returns this shape; Phase 2 ensures it holds even after retry loop, bang variants added |
| ERRR-02 | Bang variants (e.g., `create!/2`) are provided that raise on error | `Client.request!/2` added here; resource bang variants in Phase 4 |
| ERRR-03 | Errors are structured, pattern-matchable structs with type, code, message, param, request_id | Error struct enriched with `param`, `decline_code`, `charge`, `doc_url`, `raw_body` |
| ERRR-04 | Distinct error types: card errors, invalid request, authentication, rate limit, API errors, idempotency conflicts | `:idempotency_error` type atom added; all 6 types documented in Stripe error API |
| ERRR-05 | Error structs include HTTP status, full error body, and actionable context for debugging | `raw_body` map captures full error envelope; `doc_url`, `request_id`, `status` all present |
| ERRR-06 | Idempotency conflicts (409) surface as a distinct error type with original request_id | `parse_type/1` new clause for `"idempotency_error"` → `:idempotency_error`; non-retriable per D-12 |
| RTRY-01 | Library automatically retries failed requests with exponential backoff and jitter | Retry loop in `Client.request/2`, `RetryStrategy.Default` with jitter formula |
| RTRY-02 | Retry logic respects the Stripe-Should-Retry response header | `stripe_should_retry` key in context map, authoritative when present |
| RTRY-03 | Library auto-generates idempotency keys for mutating requests and reuses the same key on retry | UUID v4 with `idk_ltc_` prefix generated once before retry loop |
| RTRY-04 | User can provide a custom idempotency key per-request | User key in `req.opts[:idempotency_key]` takes precedence over auto-generated key |
| RTRY-05 | Retry strategy is pluggable via a RetryStrategy behaviour | `LatticeStripe.RetryStrategy` behaviour with single `retry?/2` callback |
| RTRY-06 | Max retries configurable per-client and per-request | `max_retries` in Config schema (client-level) and `req.opts[:max_retries]` (per-request) |
</phase_requirements>

---

## Summary

Phase 2 builds directly on Phase 1's foundation. The code changes are additive: existing modules get enriched (Error struct fields, Json behaviour callbacks), a new module is created (RetryStrategy), and one function gets new internal structure (Client.request/2 gains a retry loop). No public API surface changes break backward compatibility — only new fields are added to the Error struct and new functions added to Client.

The Stripe error object shape is well-documented: the `error` envelope contains `type`, `code`, `message`, `param`, `decline_code`, `charge`, `doc_url` as named fields alongside nested objects (`payment_intent`, `payment_method`, `setup_intent`, `source`). The CONTEXT.md decisions cover the four named fields plus `raw_body` as a catch-all — this is the right scope for Phase 2. The nested object fields are left in `raw_body` for now; typed access comes in Phase 4 when resource structs are built.

The retry loop architecture follows a standard recursive/tail-call or loop pattern: generate idempotency key before loop, attempt request, consult `RetryStrategy.retry?/2` with a context map, either sleep-and-recurse or return final result. The `Process.sleep/1` approach is idiomatic for a synchronous Elixir SDK — it blocks only the calling process, which is expected behavior.

**Primary recommendation:** Implement in dependency order: (1) Error struct enrichment, (2) Json behaviour non-bang callbacks, (3) RetryStrategy behaviour + default, (4) Config schema additions, (5) Client retry loop + bang variant, (6) tests.

---

## Standard Stack

### Core (no new dependencies required)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `:crypto` | OTP stdlib | UUID v4 generation | Already available in OTP; `:crypto.strong_rand_bytes/1` is the canonical source of CSPRNG bytes in BEAM |
| `NimbleOptions` | ~> 1.0 (already in mix.exs) | `retry_strategy` field validation | Already used for all Client config; add `:atom` type field for `retry_strategy` |
| `:telemetry` | ~> 1.0 (already in mix.exs) | Per-retry event emission | Already wired into Client; add `[:lattice_stripe, :request, :retry]` event |

### No New Dependencies

Phase 2 introduces zero new Hex dependencies. All required functionality is covered by:
- Elixir stdlib (`defexception`, `defprotocol`, `defimpl`, `Process.sleep/1`)
- OTP stdlib (`:crypto.strong_rand_bytes/1`)
- Already-declared deps (NimbleOptions, `:telemetry`, Jason)

**Installation:** No changes to `mix.exs` deps block required.

---

## Architecture Patterns

### Recommended Project Structure (additions only)

```
lib/lattice_stripe/
├── error.ex              # MODIFY: add param, decline_code, charge, doc_url, raw_body fields
│                         #         update message/1, add String.Chars protocol impl
│                         #         add :idempotency_error type, update parse_type/1
├── json.ex               # MODIFY: add decode/1 and encode/1 callbacks to behaviour
├── json/
│   └── jason.ex          # MODIFY: add decode/1 and encode/1 implementations
├── retry_strategy.ex     # CREATE: @behaviour + Default implementation in same file
├── retry_strategy/       # RESERVE: for future alternatives (circuit_breaker.ex etc.)
├── config.ex             # MODIFY: add retry_strategy field, change max_retries default to 2
└── client.ex             # MODIFY: add retry loop, auto-idempotency, request!/2

test/lattice_stripe/
├── error_test.exs        # MODIFY: test new fields, String.Chars, :idempotency_error, message format
├── json_test.exs         # MODIFY: test decode/1, encode/1 non-bang callbacks
├── retry_strategy_test.exs  # CREATE: pure unit tests for RetryStrategy.Default
└── client_test.exs       # MODIFY: add retry loop tests, bang variant tests
```

### Pattern 1: RetryStrategy Behaviour + Default in One File

**What:** The behaviour definition (`@callback retry?/2`) and the default implementation (`defmodule LatticeStripe.RetryStrategy.Default`) coexist in `retry_strategy.ex`. This follows the Transport pattern established in Phase 1.

**When to use:** When the behaviour and its primary implementation are tightly coupled and there's one obvious default.

**Example:**
```elixir
# lib/lattice_stripe/retry_strategy.ex
defmodule LatticeStripe.RetryStrategy do
  @moduledoc """
  Behaviour for controlling retry logic.
  """

  @type context :: %{
    error: LatticeStripe.Error.t() | nil,
    status: pos_integer() | nil,
    headers: [{String.t(), String.t()}],
    stripe_should_retry: boolean() | nil,
    method: atom(),
    idempotency_key: String.t() | nil
  }

  @callback retry?(attempt :: pos_integer(), context()) ::
    {:retry, delay_ms :: non_neg_integer()} | :stop
end

defmodule LatticeStripe.RetryStrategy.Default do
  @behaviour LatticeStripe.RetryStrategy

  @base_delay 500
  @max_delay 5_000
  @max_retry_after 5_000

  @impl true
  def retry?(attempt, context) do
    # Stripe-Should-Retry header is authoritative
    # Fall back to status-code heuristics when absent
    # ...
  end
end
```

### Pattern 2: Retry Loop Internal to Client.request/2

**What:** The public `request/2` function generates the idempotency key and calls an internal `do_request_with_retry/5` (or similar) that recursively retries up to `max_retries` times.

**When to use:** When retry logic must be invisible to callers (all public API functions get retries automatically).

**Example:**
```elixir
# In Client.request/2:
idempotency_key = resolve_idempotency_key(req)
max_retries = Keyword.get(req.opts, :max_retries, client.max_retries)
retry_strategy = client.retry_strategy

# One telemetry span wraps all attempts:
if client.telemetry_enabled do
  :telemetry.span([:lattice_stripe, :request], span_meta, fn ->
    result = do_request_with_retry(client, transport_req, idempotency_key,
                                   retry_strategy, max_retries, 0)
    {result, build_stop_meta(result)}
  end)
else
  do_request_with_retry(...)
end

# Internal recursive function:
defp do_request_with_retry(client, transport_req, idem_key, strategy, max_retries, attempt) do
  result = do_request(client, transport_req)
  
  if attempt >= max_retries do
    result
  else
    context = build_retry_context(result, transport_req, idem_key)
    case strategy.retry?(attempt + 1, context) do
      {:retry, delay_ms} ->
        emit_retry_telemetry(attempt + 1, delay_ms, transport_req, result)
        Process.sleep(delay_ms)
        do_request_with_retry(client, transport_req, idem_key, strategy,
                              max_retries, attempt + 1)
      :stop ->
        result
    end
  end
end
```

### Pattern 3: Error Struct Additive Enrichment

**What:** Add new fields to `defexception` while updating `from_response/3` to populate them from the Stripe error envelope. The `raw_body` field captures the entire `decoded_body` map as the escape hatch.

**When to use:** Whenever Stripe error fields need dot-access pattern matching without risking forward-compatibility breakage.

**Example:**
```elixir
defexception [
  :type, :code, :message, :status, :request_id,
  # Phase 2 additions:
  :param, :decline_code, :charge, :doc_url, :raw_body
]

def from_response(status, decoded_body, request_id) do
  case decoded_body do
    %{"error" => %{"type" => type_str} = error_map} ->
      %__MODULE__{
        type: parse_type(type_str),
        code: Map.get(error_map, "code"),
        message: Map.get(error_map, "message"),
        status: status,
        request_id: request_id,
        param: Map.get(error_map, "param"),
        decline_code: Map.get(error_map, "decline_code"),
        charge: Map.get(error_map, "charge"),
        doc_url: Map.get(error_map, "doc_url"),
        raw_body: decoded_body
      }
    _ ->
      # Non-standard body — api_error with raw_body
      ...
  end
end
```

### Pattern 4: String.Chars Protocol Implementation

**What:** Implement `String.Chars` protocol on `LatticeStripe.Error` to delegate `to_string/1` to the existing `message/1` callback. This makes `"#{error}"` work in string interpolation and logging.

**When to use:** Whenever an exception module should support string interpolation without Jason.Encoder (security requirement).

**Example:**
```elixir
# Inside lib/lattice_stripe/error.ex, after defexception:
defimpl String.Chars, for: LatticeStripe.Error do
  def to_string(error) do
    LatticeStripe.Error.message(error)
  end
end
```

### Pattern 5: UUID v4 Without External Dependency

**What:** Generate RFC 4122 UUID v4 using `:crypto.strong_rand_bytes/1` and bit manipulation. This is the same approach used by `Ecto.UUID`.

**When to use:** Any library that needs random UUIDs without adding a dependency.

**Example:**
```elixir
defp generate_uuid_v4 do
  <<a::48, _::4, b::12, _::2, c::62>> = :crypto.strong_rand_bytes(16)
  <<a::48, 4::4, b::12, 2::2, c::62>>
  |> Base.encode16(case: :lower)
  |> then(fn hex ->
    <<p1::8, p2::4, p3::4, p4::4, p5::8, p6::12, p7::8, p8::8, p9::8>> = 
      # ... UUID string formatting
    "#{p1}-#{p2}#{p3}-4#{p4}-#{p5}#{p6}-#{p7}#{p8}#{p9}"
  end)
end

defp generate_idempotency_key do
  "idk_ltc_" <> generate_uuid_v4()
end
```

Note: The exact bit manipulation pattern should follow the Ecto.UUID source for correctness. The key output is a 44-character string (`"idk_ltc_"` = 8 chars + UUID = 36 chars).

### Pattern 6: Zero-Delay Test Strategy for Retry Tests

**What:** In tests, pass a custom `retry_strategy` module that implements `RetryStrategy` but returns `{:retry, 0}` (zero delay) instead of the calculated backoff. This makes retry tests fast without sleeping.

**When to use:** Any test that needs to verify retry count, idempotency key reuse, or retry behavior without waiting for real backoff delays.

**Example:**
```elixir
# In test_helper.exs or test support file:
defmodule LatticeStripe.TestRetryStrategy do
  @behaviour LatticeStripe.RetryStrategy
  
  @impl true
  def retry?(_attempt, _context), do: {:retry, 0}
end

# In test:
client = test_client(retry_strategy: LatticeStripe.TestRetryStrategy, max_retries: 2)
# 3 total transport calls expected, no sleeping
```

### Anti-Patterns to Avoid

- **Generating a new idempotency key on each retry attempt:** Defeats the entire purpose of idempotency keys. The same key MUST be reused across all attempts for a single `request/2` call.
- **Retrying 409 idempotency conflicts:** A 409 from Stripe means parameters differ from the original request with that key. Retrying will hit the same conflict. Non-retriable.
- **Using `Logger` in library code:** Libraries emit telemetry; applications log. Using `Logger` couples the library to log level configuration it doesn't control.
- **Wrapping the retry loop in the telemetry span per-attempt:** The span should wrap ALL attempts as one logical operation. Only the `[:lattice_stripe, :request, :retry]` per-retry event fires inside the loop.
- **Implementing `Jason.Encoder` on `LatticeStripe.Error`:** Prevents accidental serialization of `raw_body` and `request_id` to API responses. The security risk for a payment library is real.
- **Using `rescue` for non-JSON response handling:** Non-bang `decode/1` returns `{:ok, map} | {:error, reason}` so non-JSON responses can be handled with `case` without exceptions.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| UUID generation | Custom PRNG or encoding | `:crypto.strong_rand_bytes/1` + bit manipulation | OTP stdlib CSPRNG is correct and available everywhere; ~5 lines, no dep needed |
| Config validation for retry_strategy | Manual `is_atom/1` check | NimbleOptions `:atom` type (already in use) | Consistent with existing Config schema; auto-generates docs |
| Telemetry retry events | Custom event system | `:telemetry.execute/3` with `[:lattice_stripe, :request, :retry]` | Already the project standard; zero-overhead when no handler attached |
| Non-bang JSON fallback | `rescue` around `decode!` | Add `decode/1` returning `{:ok, _} \| {:error, _}` to Json behaviour | Consistent with existing bang/non-bang pattern; no exception control flow |

**Key insight:** The "don't hand-roll" list is short for this phase because it's behavioral logic, not utility infrastructure. The correctness is in the retry algorithm (idempotency key reuse, `Stripe-Should-Retry` semantics) not in the supporting utilities.

---

## Common Pitfalls

### Pitfall 1: New Idempotency Key Per Retry Attempt (Double Charges)

**What goes wrong:** If `generate_idempotency_key()` is called inside the retry loop rather than before it, each attempt gets a unique key. Stripe treats each as a new request. A 500 response may mean the original succeeded server-side — retrying with a new key creates a second charge.

**Why it happens:** The key generation call is easy to place at request time, which feels natural. The retry loop calls `do_request` multiple times and it's tempting to generate the key there.

**How to avoid:** Generate the idempotency key exactly once in `Client.request/2` before any looping. Pass it as a parameter through the retry recursion. The transport request map gets the same key header on every attempt.

**Warning signs:** Tests that verify idempotency key behavior pass with a single attempt but behavior is wrong with retries.

---

### Pitfall 2: Retrying 409 Idempotency Conflicts

**What goes wrong:** 409 from Stripe on an idempotency key conflict means parameters differ from the original request that used this key. Retrying with the same key and same (differing) params will produce the same 409 indefinitely.

**Why it happens:** The DeepWiki stripe-node documentation says "Always retry [409] to handle race conditions" — this is for a *different kind* of 409. Stripe's idempotency conflict 409 has `type: "idempotency_error"` in the error body and is explicitly non-retriable.

**How to avoid:** In `RetryStrategy.Default`, check the error type: if `error.type == :idempotency_error`, return `:stop` regardless of the `Stripe-Should-Retry` header. This is codified in D-12.

**Warning signs:** Test that sends a request whose params differ from the original would loop forever without this guard.

---

### Pitfall 3: `Stripe-Should-Retry: false` Ignored When Status Looks Retriable

**What goes wrong:** The default retry strategy checks status code first (e.g., "500 → retry") and ignores the `Stripe-Should-Retry` header. Stripe explicitly sends `false` on some 500s where it knows the server-side state was never modified. Retrying wastes capacity and may cause duplicate side effects.

**Why it happens:** It's natural to pattern-match on status code before checking headers. Header processing is easy to skip.

**How to avoid:** Per D-09, the `stripe_should_retry` context key is checked FIRST. Only when the header is absent does status-code heuristic apply.

**Warning signs:** Retry tests that only exercise status codes and never pass a `stripe_should_retry: false` context.

---

### Pitfall 4: `Process.sleep/1` in Tests Without Zero-Delay Strategy

**What goes wrong:** Retry tests use the real `RetryStrategy.Default`, which applies exponential backoff. With `max_retries: 2`, tests sleep for 500ms + 1000ms = 1.5 seconds per test case. A suite with 10 retry tests adds 15+ seconds of sleep.

**Why it happens:** Easy to forget to override `retry_strategy` in test client setup.

**How to avoid:** Per D-29, retry tests use a zero-delay test strategy. Define `LatticeStripe.TestRetryStrategy` in test support (returns `{:retry, 0}` always) and pass it as `retry_strategy:` to the test client.

**Warning signs:** Test suite getting significantly slower after adding retry tests.

---

### Pitfall 5: `message/1` and `String.Chars.to_string/1` Getting Out of Sync

**What goes wrong:** `defexception` uses `message/1` for `Exception.message/1` (used by `raise`). The `String.Chars` protocol `to_string/1` is used by string interpolation. If the two are implemented independently, they produce different strings for the same error.

**Why it happens:** It's tempting to customize the interpolation format differently from the exception message format.

**How to avoid:** Per D-03, `String.Chars.to_string/1` delegates directly to `LatticeStripe.Error.message/1`. One implementation, two entry points.

**Warning signs:** `inspect(error)` and `"#{error}"` produce different output.

---

### Pitfall 6: Non-JSON Response Handling with `rescue` Around `decode!`

**What goes wrong:** If the transport returns a non-JSON response (HTML maintenance page, empty body, malformed JSON), `json_codec.decode!(body)` raises a `Jason.DecodeError`. This breaks the retry loop — the exception escapes before the retry strategy can evaluate whether to retry.

**Why it happens:** Phase 1's `do_request` uses `client.json_codec.decode!(body)` which raises on invalid JSON. The retry loop doesn't catch exceptions.

**How to avoid:** Per D-26/D-27, add non-bang `decode/1` to the Json behaviour. `do_request` uses `json_codec.decode(body)` and handles `{:error, _}` by constructing a `%Error{type: :api_error, raw_body: %{"_raw" => truncated_body}}`. 502/503 responses (which may carry HTML) are retriable status codes — this ensures the retry loop runs.

**Warning signs:** Tests for non-JSON responses that work with `max_retries: 0` but crash when retries are enabled.

---

## Code Examples

Verified patterns from official sources:

### Stripe Error Object Shape (source: https://docs.stripe.com/api/errors)

```
{
  "error": {
    "type": "card_error",        // always present
    "code": "card_declined",     // nullable
    "message": "...",            // nullable
    "param": "card",             // nullable
    "decline_code": "insufficient_funds",  // nullable, card_error only
    "charge": "ch_xxx",          // nullable, card_error only
    "doc_url": "https://...",    // nullable
    "request_log_url": "https://dashboard..."  // nullable
  }
}
```

Idempotency conflict (409):
```
{
  "error": {
    "type": "idempotency_error",
    "code": "idempotency_key_in_use",
    "message": "Keys for idempotent requests can only be used with the same parameters..."
  }
}
```

### Updated Error Type Spec

```elixir
@type error_type ::
        :card_error
        | :invalid_request_error
        | :authentication_error
        | :rate_limit_error
        | :api_error
        | :connection_error
        | :idempotency_error    # Phase 2 addition
```

### Updated `message/1` Format (D-05)

```elixir
@impl true
def message(%__MODULE__{type: type, status: status, message: msg, request_id: request_id}) do
  status_str = if status, do: " #{status}", else: ""
  request_str = if request_id, do: " (request: #{request_id})", else: ""
  "(#{type})#{status_str} #{msg}#{request_str}"
end
```

Example output: `"(card_error) 402 Your card has insufficient funds. (request: req_abc123)"`

### Non-Bang Json Behaviour Callbacks

```elixir
# In LatticeStripe.Json behaviour:
@callback encode(term()) :: {:ok, binary()} | {:error, term()}
@callback decode(binary()) :: {:ok, term()} | {:error, term()}
@callback encode!(term()) :: binary()
@callback decode!(binary()) :: term()

# In LatticeStripe.Json.Jason:
def encode(data), do: Jason.encode(data)
def decode(data), do: Jason.decode(data)
```

### RetryStrategy.Default Decision Table

```elixir
# stripe_should_retry header takes precedence:
# "true"  → {:retry, calculated_delay}
# "false" → :stop
# absent  → check status/error:
#   :idempotency_error → :stop (D-12: non-retriable)
#   :connection_error  → {:retry, calculated_delay}
#   status 429         → {:retry, retry_after_or_backoff}
#   status 500+        → {:retry, calculated_delay}
#   other 4xx          → :stop
#   attempt >= max_retries → :stop (checked by caller, not strategy)
```

Note: The max_retries check is the responsibility of `Client.request/2`, not `RetryStrategy.retry?/2`. The strategy only evaluates whether a retry *should* happen; the caller enforces the cap.

### Exponential Backoff with Jitter

```elixir
defp calculate_delay(attempt) do
  base = min(@base_delay * :math.pow(2, attempt - 1), @max_delay)
  # Jitter to 50-100% of base to avoid thundering herd
  jitter_factor = 0.5 + :rand.uniform() * 0.5
  trunc(base * jitter_factor)
end
```

### `Retry-After` Header Parsing with Cap

```elixir
defp parse_retry_after(headers) do
  case List.keyfind(headers, "retry-after", 0) do
    {_, value} ->
      case Integer.parse(value) do
        {seconds, ""} -> min(seconds * 1_000, @max_retry_after)
        _ -> nil
      end
    nil -> nil
  end
end
```

### `Client.request!/2`

```elixir
@spec request!(t(), Request.t()) :: map()
def request!(%__MODULE__{} = client, %Request{} = req) do
  case request(client, req) do
    {:ok, result} -> result
    {:error, error} -> raise error
  end
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single `decode!/1` in Json behaviour | Bang + non-bang (`decode!/1` and `decode/1`) | Phase 2 | Non-JSON responses handled without rescue blocks |
| `max_retries: 0` default (no retries) | `max_retries: 2` default (3 total attempts) | Phase 2 | Transient network errors and Stripe 500s handled automatically |
| No idempotency key auto-generation | Auto-generate `idk_ltc_` + UUID v4 for all POST requests | Phase 2 | POST mutations safe to retry without double-charge risk |
| Error struct: 5 fields | Error struct: 10 fields + `raw_body` | Phase 2 | Pattern matching on `decline_code`, `param` without digging into raw map |
| `message/1` format: `"(type) message"` | `"(type) status message (request: req_id)"` | Phase 2 | Log lines correlate directly to Stripe dashboard request logs |

**Deprecated/outdated within this codebase:**
- `json_codec.decode!(body)` in `do_request/2`: replace with `json_codec.decode(body)` + case to handle non-JSON responses gracefully.

---

## Open Questions

1. **Retry loop structure: recursive vs. `Enum.reduce_while`**
   - What we know: Both approaches work. Recursive private function is easier to read and debug with a named `attempt` counter. `Enum.reduce_while` over a range is more functional-style but harder to pass state through.
   - What's unclear: Team preference. The context doesn't specify.
   - Recommendation: Use a recursive private function with explicit `attempt` parameter. More readable, easier to add tracing.

2. **Telemetry stop event: wrap all attempts or just the final one?**
   - What we know: D-14 says "One telemetry span wraps all attempts." The span's `:duration` measurement will include all retry wait times.
   - What's unclear: Whether users expect `:duration` to include sleep time or only active HTTP time.
   - Recommendation: Document in the telemetry stop event metadata that `:duration` includes retry delays. Add `attempts` count to metadata so users can compute approximate HTTP time.

3. **`String.Chars` protocol placement: inside `error.ex` or separate file?**
   - What we know: `defimpl` blocks can be in the same file as the struct definition or in a separate file. Elixir consolidates protocols at compile time regardless.
   - Recommendation: Place inside `error.ex` directly after the `defexception` block. Keeps the error module self-contained.

---

## Environment Availability

Step 2.6: SKIPPED (no external dependencies introduced in Phase 2 — zero new Hex dependencies, zero external services required beyond Phase 1 baseline).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ERRR-01 | `request/2` returns `{:ok, map} \| {:error, %Error{}}` after retry exhaustion | unit | `mix test test/lattice_stripe/client_test.exs -x` | ✅ (modify) |
| ERRR-02 | `request!/2` raises `%Error{}` on final failure | unit | `mix test test/lattice_stripe/client_test.exs -x` | ✅ (modify) |
| ERRR-03 | Error struct has `param`, `decline_code`, `charge`, `doc_url`, `raw_body` fields | unit | `mix test test/lattice_stripe/error_test.exs -x` | ✅ (modify) |
| ERRR-04 | All 6 error types pattern-matchable including `:idempotency_error` | unit | `mix test test/lattice_stripe/error_test.exs -x` | ✅ (modify) |
| ERRR-05 | Error includes status, full body in `raw_body`, `doc_url`, `request_id` | unit | `mix test test/lattice_stripe/error_test.exs -x` | ✅ (modify) |
| ERRR-06 | 409 response → `%Error{type: :idempotency_error}` | unit | `mix test test/lattice_stripe/error_test.exs -x` | ✅ (modify) |
| RTRY-01 | Mox transport expects N+1 calls for max_retries N | unit | `mix test test/lattice_stripe/client_test.exs -x` | ✅ (modify) |
| RTRY-02 | `Stripe-Should-Retry: false` stops retry even on 500 | unit | `mix test test/lattice_stripe/retry_strategy_test.exs -x` | ❌ Wave 0 |
| RTRY-03 | Same idempotency key header on all retry attempts | unit | `mix test test/lattice_stripe/client_test.exs -x` | ✅ (modify) |
| RTRY-04 | User-provided key in `opts` takes precedence over auto-generated | unit | `mix test test/lattice_stripe/client_test.exs -x` | ✅ (modify) |
| RTRY-05 | Custom `retry_strategy` module is consulted instead of default | unit | `mix test test/lattice_stripe/client_test.exs -x` | ✅ (modify) |
| RTRY-06 | Per-request `max_retries` override respected | unit | `mix test test/lattice_stripe/client_test.exs -x` | ✅ (modify) |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green (`mix test` + `mix credo --strict`) before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/lattice_stripe/retry_strategy_test.exs` — covers RTRY-01 through RTRY-06 pure strategy tests

*(All other test files exist from Phase 1 and will be modified with new test cases.)*

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 2 |
|-----------|-------------------|
| No Dialyzer | Typespecs on Error fields, RetryStrategy callbacks are documentation only. No spec enforcement. |
| Minimal dependencies | Phase 2 adds zero new Hex deps. UUID via `:crypto`, behaviour/protocol via stdlib. |
| Finch as default HTTP adapter | No change. Transport behaviour is the seam. RetryStrategy operates above transport level. |
| Jason as JSON codec | `encode/1` and `decode/1` added to `Jason` adapter alongside existing bang variants. |
| Elixir 1.15+, OTP 26+ | `:crypto.strong_rand_bytes/1` available since OTP 24; safe. `Process.sleep/1` has been in Elixir since 1.0. |
| Transport behaviour contract unchanged | Retry loop calls `transport.request/1` multiple times; contract unchanged. |
| No GenServer for state | Retry loop is a pure recursive function. No process state, no GenServer. |
| Plug not needed this phase | Webhook Plug is Phase 7. No Plug dependency changes here. |

---

## Sources

### Primary (HIGH confidence)

- Stripe API error object documentation (https://docs.stripe.com/api/errors) — error field names, type values including `idempotency_error`, `decline_code`, `charge`, `doc_url`
- Stripe idempotent requests documentation (https://docs.stripe.com/api/idempotent_requests) — key format (≤255 chars, UUID v4 recommended), POST-only scope, 24-hour expiry, parameter protection on retry
- Stripe low-level error documentation (https://docs.stripe.com/error-low-level) — `Stripe-Should-Retry` header semantics: `true`→retry, `false`→stop, absent→heuristics
- Elixir `Exception` documentation (https://hexdocs.pm/elixir/Exception.html) — `defexception`, `message/1` callback, `raise/1` interaction
- Elixir `String.Chars` documentation (https://hexdocs.pm/elixir/String.Chars.html) — `to_string/1` required callback, `defimpl` pattern
- Existing Phase 1 implementation (`lib/lattice_stripe/error.ex`, `lib/lattice_stripe/client.ex`, `lib/lattice_stripe/config.ex`, `lib/lattice_stripe/json.ex`) — direct inspection confirmed current field names, function signatures, NimbleOptions schema shape

### Secondary (MEDIUM confidence)

- DeepWiki stripe-node retry documentation (https://deepwiki.com/stripe/stripe-node/3.5-idempotency-and-retry-logic) — confirmed backoff formula `INITIAL_DELAY * 2^(retries-1)` capped at `MAX_DELAY`, jitter factor 0.5-1.0, `Retry-After` honored (stripe-node cap is 60s vs our locked 5s cap per D-10)
- Phase 1 CONTEXT.md decisions D-07, D-09, D-10, D-12, D-18 — established patterns for behaviour shape, test strategy, and error struct design intent
- `.planning/research/PITFALLS.md` Pitfall 5 — confirmed double-charge risk from incorrect idempotency key handling on retry

### Tertiary (LOW confidence)

- None — all critical claims are backed by official documentation or direct code inspection.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps; all existing deps are confirmed in mix.exs
- Architecture: HIGH — patterns follow established Phase 1 conventions, verified against official Stripe error docs and Elixir stdlib docs
- Pitfalls: HIGH — derived from official Stripe docs, Pitfalls.md research, and direct code inspection of existing retry-related code paths

**Research date:** 2026-04-02
**Valid until:** 2026-06-01 (stable domain; Stripe error object shape changes are infrequent)
