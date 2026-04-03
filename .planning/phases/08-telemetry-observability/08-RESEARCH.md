# Phase 8: Telemetry & Observability - Research

**Researched:** 2026-04-03
**Domain:** Elixir `:telemetry` 1.4.x — event emission, span API, handler patterns
**Confidence:** HIGH

## Summary

Phase 8 is a focused refactor-plus-extension: centralize all telemetry logic from `Client` into a new `LatticeStripe.Telemetry` module, add webhook verification telemetry, enrich existing metadata, and ship a default logger handler. The `:telemetry` library (v1.4.1) is already a runtime dependency, and the core pattern — `:telemetry.span/3` wrapping the request loop — is already working in `Client.request/2`. This phase extracts, enriches, and extends that pattern rather than introducing it from scratch.

The primary new surface area is `LatticeStripe.Telemetry`: a pure module (no GenServer, no state) containing event name constants as module attributes, public functions `request_span/4`, `webhook_verify_span/3`, `emit_retry/5`, and `attach_default_logger/1`. Client and Webhook call into this module; all telemetry logic lives in one place. This matches the Finch `Finch.Telemetry` module pattern exactly — a documentation-heavy, `@doc false` implementation module that is the single source of truth for event schemas.

The `:telemetry.span/3` API in v1.4.1 supports two return shapes from the span function: `{result, stop_metadata}` and `{result, extra_measurements, stop_metadata}`. The extra_measurements variant lets callers inject additional scalar measurements (e.g., `%{attempt_count: n}`) that merge into the auto-computed `duration` map. The `telemetry_span_context` key is auto-injected into start, stop, and exception metadata so consumers can correlate events for the same span — no manual tracking needed. Exception events fire automatically on `raise`/`throw` with `:kind`, `:reason`, `:stacktrace` in metadata — the span function does not need explicit exception handling for TLMT-03.

**Primary recommendation:** Create `LatticeStripe.Telemetry` with centralized helpers, move all logic from `Client`, add webhook span, then expand tests to assert full metadata contracts.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Emit telemetry for HTTP requests (existing) AND webhook signature verification (new). No pagination-aggregate events.
- **D-02:** Webhook verification uses `[:lattice_stripe, :webhook, :verify, :start/stop/exception]` span. Captures result (`:ok`/`:error`), error_reason (`:invalid_signature`, `:stale_timestamp`, etc.).
- **D-03:** Add `resource` and `operation` to start+stop metadata. Low cardinality, enables per-operation dashboards.
- **D-04:** Add `api_version` and `stripe_account` to start+stop metadata. Structural, not secret.
- **D-05:** Parse `resource` and `operation` from URL path at the telemetry layer — zero changes to resource modules. `POST /v1/customers` → resource: `"customer"`, operation: `"create"`; `GET /v1/customers/:id` → resource: `"customer"`, operation: `"retrieve"`.
- **D-06:** Create `LatticeStripe.Telemetry` module with full event catalog in `@moduledoc`.
- **D-07:** Include copy-paste `Telemetry.Metrics` definitions in `@moduledoc` for Prometheus/StatsD.
- **D-08:** Ship `attach_default_logger/1` public function for opt-in instant visibility. Structured one-liner: `[info] POST /v1/customers => 200 in 145ms (1 attempt, req_abc123)`. Configurable log level.
- **D-09:** Centralized helpers in `LatticeStripe.Telemetry` — event names as module attributes, private helpers. Single source of truth.
- **D-10:** Extract and refactor all existing telemetry logic from `Client` into `Telemetry` module. Client calls `Telemetry.request_span(client, req, fun)`.
- **D-11:** Webhook verification uses `:telemetry.span/3` for consistency.
- **D-12:** Full metadata contract tests — assert every metadata key, type, and value for every event type. ~25-30 test cases.

### Claude's Discretion

- Path parsing logic for resource/operation derivation (regex patterns, edge cases for nested resources like checkout/sessions)
- Default logger handler ID naming convention
- Internal helper function signatures and module organization
- Telemetry.Metrics example specifics (which metric types for which events)

### Deferred Ideas (OUT OF SCOPE)

- Pagination aggregate telemetry (`[:lattice_stripe, :pagination, :stop]`) — add later if users request it
- JSON decode sub-timing event
- Grafana dashboard JSON template — aspirational, could be added in Phase 10 docs

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TLMT-01 | Library emits `[:lattice_stripe, :request, :start]` event before each HTTP request | Existing `:telemetry.span/3` in Client emits this; centralize in Telemetry module, enrich metadata with resource/operation/api_version/stripe_account |
| TLMT-02 | Library emits `[:lattice_stripe, :request, :stop]` after each HTTP request with duration, method, path, status, request_id | Existing span emits stop event with duration (auto from span); enrich stop metadata from `telemetry_stop_metadata/3`, move to Telemetry module |
| TLMT-03 | Library emits `[:lattice_stripe, :request, :exception]` on request failure with error details | `:telemetry.span/3` auto-emits `:exception` on uncaught raise/throw with kind/reason/stacktrace — no explicit emit code needed; verified from telemetry 1.4.1 source |

</phase_requirements>

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `:telemetry` | 1.4.1 (locked) | Event emission, span API | Runtime dep, already in mix.exs; OTP ecosystem standard |
| `Logger` | (stdlib) | Default logger handler | Ships with Elixir; no extra dep for `attach_default_logger/1` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Telemetry.Metrics` | (not a dep) | Documentation only — copy-paste metric definitions for users | Used in `@moduledoc` examples only; consumers bring their own `telemetry_metrics` / Prometheus / StatsD adapter |

No new dependencies for this phase. `:telemetry` is already locked at 1.4.1.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `:telemetry.span/3` | manual `execute/3` start + try/rescue/after + execute/3 stop | span/3 auto-handles exception events, monotonic time, span context. Always prefer span/3. |

---

## Architecture Patterns

### New Module: `lib/lattice_stripe/telemetry.ex`

```
lib/
├── lattice_stripe/
│   ├── client.ex          # MODIFIED: calls Telemetry.request_span/4, Telemetry.emit_retry/5
│   ├── webhook.ex         # MODIFIED: wraps construct_event call in Telemetry.webhook_verify_span/3
│   └── telemetry.ex       # NEW: all telemetry logic, event catalog, default logger
test/
└── lattice_stripe/
    └── telemetry_test.exs # NEW: ~25-30 metadata contract tests
```

### Pattern 1: Centralized Telemetry Module (Finch pattern)

**What:** A module that owns event names, measurement/metadata construction, and public span helpers. Implementation functions are `@doc false`. The `@moduledoc` is the event catalog consumers read.

**When to use:** Any SDK or library emitting telemetry events. Single-module pattern prevents schema drift.

```elixir
# Source: deps/finch/lib/finch/telemetry.ex — adapted for LatticeStripe
defmodule LatticeStripe.Telemetry do
  @moduledoc """
  Telemetry integration for LatticeStripe.

  ## Events

  ### `[:lattice_stripe, :request, :start]`
  Emitted before each HTTP request.

  #### Measurements
    * `:system_time` — system time in native units
    * `:monotonic_time` — monotonic time in native units

  #### Metadata
    * `:method` — HTTP method atom (`:get`, `:post`, `:delete`)
    * `:path` — URL path string (e.g., `"/v1/customers"`)
    * `:resource` — Stripe resource name (e.g., `"customer"`, `"payment_intent"`)
    * `:operation` — CRUD operation (e.g., `"create"`, `"retrieve"`, `"list"`)
    * `:api_version` — Stripe API version string (e.g., `"2026-03-25.dahlia"`)
    * `:stripe_account` — Connected account ID string, or `nil`
    * `:telemetry_span_context` — opaque span context for correlating start/stop/exception

  ### `[:lattice_stripe, :request, :stop]`
  Emitted after each HTTP request (success or API-level error).

  #### Measurements
    * `:duration` — elapsed time in native units
    * `:monotonic_time` — monotonic time at stop

  #### Metadata
  All start metadata fields, plus:
    * `:status` — atom `:ok` or `:error`
    * `:http_status` — integer HTTP status code (nil on connection error)
    * `:request_id` — Stripe request ID string (nil on connection error)
    * `:attempts` — total attempts including retries (integer)
    * `:retries` — retry count (attempts - 1)
    * `:idempotency_key` — idempotency key used (on error path only)
    * `:error_type` — atom error type (on error path only)

  ### `[:lattice_stripe, :request, :exception]`
  Emitted if an uncaught exception/throw occurs inside the request span.

  #### Measurements
    * `:duration` — elapsed time in native units

  #### Metadata
  Start metadata fields, plus:
    * `:kind` — exception kind (`:error`, `:throw`, `:exit`)
    * `:reason` — exception reason
    * `:stacktrace` — stack trace list

  ### `[:lattice_stripe, :request, :retry]`
  Emitted for each retry attempt (standalone execute, not a span).

  #### Measurements
    * `:attempt` — attempt number (integer, 1-based)
    * `:delay_ms` — delay before this retry in milliseconds

  #### Metadata
    * `:method` — HTTP method atom
    * `:path` — URL path string
    * `:error_type` — atom error type that triggered retry
    * `:status` — HTTP status integer (nil for connection errors)

  ### `[:lattice_stripe, :webhook, :verify, :start]`
  Emitted before webhook signature verification.

  #### Measurements
    * `:system_time`, `:monotonic_time`

  #### Metadata
    * `:path` — request path string (when available from Plug context)

  ### `[:lattice_stripe, :webhook, :verify, :stop]`
  Emitted after webhook signature verification.

  #### Measurements
    * `:duration`, `:monotonic_time`

  #### Metadata
    * `:path` — request path string
    * `:result` — atom `:ok` or `:error`
    * `:error_reason` — atom (`:invalid_signature`, `:stale_timestamp`, `:missing_header`, `:invalid_header`, `nil`)

  ### `[:lattice_stripe, :webhook, :verify, :exception]`
  Emitted on uncaught exception during webhook verification.

  #### Measurements
    * `:duration`

  #### Metadata
    * `:kind`, `:reason`, `:stacktrace`

  ## Telemetry.Metrics Examples

      # Add to your application's telemetry supervisor:
      [
        Telemetry.Metrics.summary("lattice_stripe.request.stop.duration",
          tags: [:resource, :operation, :status]
        ),
        Telemetry.Metrics.counter("lattice_stripe.request.stop",
          tags: [:resource, :operation, :status]
        ),
        Telemetry.Metrics.distribution("lattice_stripe.request.stop.duration",
          tags: [:resource, :operation],
          unit: {:native, :millisecond}
        ),
        Telemetry.Metrics.counter("lattice_stripe.request.retry",
          tags: [:error_type]
        ),
        Telemetry.Metrics.counter("lattice_stripe.webhook.verify.stop",
          tags: [:result, :error_reason]
        )
      ]

  ## Default Logger

  Call `LatticeStripe.Telemetry.attach_default_logger/1` for instant visibility:

      LatticeStripe.Telemetry.attach_default_logger(level: :info)

  This logs one line per completed request:

      [info] POST /v1/customers => 200 in 145ms (1 attempt, req_abc123)
      [warning] GET /v1/customers/cus_xxx => 404 in 12ms (1 attempt, req_yyy)

  Options:
    * `:level` — log level atom, default `:info`
  """

  @request_event [:lattice_stripe, :request]
  @webhook_verify_event [:lattice_stripe, :webhook, :verify]
  @retry_event [:lattice_stripe, :request, :retry]

  @default_logger_id :lattice_stripe_default_logger

  @doc """
  Attaches a default structured logger for all LatticeStripe request events.

  Safe to call multiple times — detaches any existing handler with the same ID first.

  ## Options
    * `:level` — log level (default: `:info`)
  """
  def attach_default_logger(opts \\ []) do
    level = Keyword.get(opts, :level, :info)
    :telemetry.detach(@default_logger_id)
    :telemetry.attach(
      @default_logger_id,
      [:lattice_stripe, :request, :stop],
      &__MODULE__.handle_default_log/4,
      %{level: level}
    )
    :ok
  end

  @doc false
  def handle_default_log(_event, measurements, metadata, %{level: level}) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    status_part = if metadata.http_status, do: "=> #{metadata.http_status} ", else: ""
    method = metadata.method |> to_string() |> String.upcase()
    req_id = Map.get(metadata, :request_id, "no-req-id")
    attempts = Map.get(metadata, :attempts, 1)

    message =
      "#{method} #{metadata.path} #{status_part}in #{duration_ms}ms (#{attempts} attempt#{if attempts == 1, do: "", else: "s"}, #{req_id})"

    Logger.log(level, message)
  end

  @doc false
  def request_span(client, req, idempotency_key, fun) do
    if client.telemetry_enabled do
      start_meta = build_start_metadata(client, req)
      :telemetry.span(@request_event, start_meta, fn ->
        {result, attempts} = fun.()
        stop_meta = build_stop_metadata(result, idempotency_key, attempts, start_meta)
        {result, stop_meta}
      end)
    else
      {result, _attempts} = fun.()
      result
    end
  end

  @doc false
  def webhook_verify_span(opts \\ [], fun) do
    path = Keyword.get(opts, :path)
    start_meta = %{path: path}
    :telemetry.span(@webhook_verify_event, start_meta, fn ->
      result = fun.()
      stop_meta = build_webhook_stop_metadata(result, path)
      {result, stop_meta}
    end)
  end

  @doc false
  def emit_retry(client, method, url, error, attempt, delay_ms) do
    if client.telemetry_enabled do
      :telemetry.execute(
        @retry_event,
        %{attempt: attempt, delay_ms: delay_ms},
        %{method: method, path: extract_path(url), error_type: error.type, status: error.status}
      )
    end
  end

  # ... private helpers for path parsing, metadata construction
end
```

### Pattern 2: `:telemetry.span/3` Return Shapes

**What:** The span function must return either `{result, stop_metadata}` or `{result, extra_measurements, stop_metadata}`. The span auto-computes `duration` and `monotonic_time` measurements. Use the 3-tuple form to inject additional integer measurements alongside duration.

**Key API fact (verified from telemetry 1.4.1 source):** The span function's exception clause auto-emits `[:prefix, :exception]` with `kind`, `reason`, `stacktrace` in metadata. No explicit rescue/after block needed for TLMT-03. This means TLMT-03 is satisfied automatically by using `:telemetry.span/3` — no extra code beyond what TLMT-01/02 require.

```elixir
# Source: deps/telemetry/src/telemetry.erl — span/3 implementation
# Two valid return forms from the span function:
{result, stop_metadata}
{result, extra_measurements, stop_metadata}

# Exception is auto-handled — the span emits [:prefix, :exception] if fun() raises
```

### Pattern 3: Path Parsing for resource/operation

**What:** Parse Stripe URL paths into low-cardinality resource and operation identifiers. Stripe v1 paths follow predictable patterns that can be handled with a small set of regex clauses.

**Discretion area** — specific implementation, but research confirms the patterns are stable:

```elixir
# Source: Analysis of Stripe API paths used in this codebase
# Verified path shapes from existing resource modules:

# /v1/customers              POST → create, GET → list
# /v1/customers/:id          GET → retrieve, POST → update, DELETE → delete
# /v1/payment_intents/:id/confirm  POST → confirm
# /v1/payment_intents/:id/capture  POST → capture
# /v1/payment_intents/:id/cancel   POST → cancel
# /v1/checkout/sessions      POST → create, GET → list (nested resource)
# /v1/checkout/sessions/:id/expire POST → expire

defp parse_resource_and_operation(method, path) do
  # Normalize path segments — strip /v1/ prefix
  case Regex.run(~r{^/v1/([^/]+)(?:/([^/]+))?(?:/([^/]+))?$}, path) do
    # /v1/resource_type  (list or create)
    [_, resource_type, nil, nil] ->
      operation = if method == :post, do: "create", else: "list"
      {normalize_resource(resource_type), operation}

    # /v1/resource_type/:id  (retrieve, update, delete)
    [_, resource_type, _id, nil] ->
      operation = case method do
        :get -> "retrieve"
        :post -> "update"
        :delete -> "delete"
        _ -> to_string(method)
      end
      {normalize_resource(resource_type), operation}

    # /v1/resource_type/:id/action  (confirm, capture, cancel, expire)
    [_, resource_type, _id, action] ->
      {normalize_resource(resource_type), action}

    # /v1/nested/resource  e.g. /v1/checkout/sessions
    _ ->
      case Regex.run(~r{^/v1/([^/]+)/([^/]+)(?:/([^/]+))?(?:/([^/]+))?$}, path) do
        [_, ns, resource, nil, nil] ->
          operation = if method == :post, do: "create", else: "list"
          {"#{ns}.#{singularize(resource)}", operation}
        [_, ns, resource, _id, nil] ->
          operation = case method do
            :get -> "retrieve"; :post -> "update"; :delete -> "delete"; _ -> to_string(method)
          end
          {"#{ns}.#{singularize(resource)}", operation}
        [_, ns, resource, _id, action] ->
          {"#{ns}.#{singularize(resource)}", action}
        _ ->
          {path, to_string(method)}
      end
  end
end

# Normalize plural snake_case resource names to singular dot notation
# payment_intents → payment_intent, checkout/sessions → checkout.session
defp normalize_resource(resource_type) do
  resource_type
  |> String.replace_trailing("s", "")  # simple singularize
  |> String.replace("_", "_")  # keep snake_case
end
```

**Edge cases to handle explicitly:**
- `/v1/checkout/sessions` — nested namespace: `"checkout.session"`
- `/v1/payment_methods/search` — search endpoint (no ID segment): operation `"search"`
- `/v1/customers/search` — same
- Resources ending in non-standard plurals (none in current v1 scope — all regular)

### Pattern 4: Default Logger Handler (Oban pattern)

**What:** A public `attach_default_logger/1` function that attaches a single telemetry handler. Idempotent — detaches before attaching. Uses a stable handler ID as a module attribute.

**Key design facts:**
- Handler function should be a module function capture (`&Mod.fun/4`), not an anonymous function — telemetry warns about anonymous function performance in hot paths
- `telemetry_span_context` key will be present in metadata — the logger should ignore/not log it
- Duration from `:telemetry.span/3` is in `:native` units — must convert via `System.convert_time_unit/3`

```elixir
# Oban source: hexdocs.pm/oban/Oban.Telemetry.html — attach_default_logger pattern
# The handler ID is stable (module attribute), not unique per call, so detach works safely
@default_logger_id :lattice_stripe_default_logger

def attach_default_logger(opts \\ []) do
  :telemetry.detach(@default_logger_id)
  :telemetry.attach(@default_logger_id, [:lattice_stripe, :request, :stop],
    &__MODULE__.handle_default_log/4, opts_to_config(opts))
  :ok
end

@doc false
def handle_default_log(_event, measurements, metadata, config) do
  # measurements.duration is in :native units
  ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
  # ... format and Logger.log(config.level, message)
end
```

### Pattern 5: Client Integration (after extraction)

**What:** `Client.request/2` delegates to `Telemetry.request_span/4`. The span function closure captures the retry-loop result which returns `{result, attempts}`. `Telemetry.emit_retry/5` called from retry loop.

```elixir
# In Client.request/2 — AFTER refactor (replaces lines 190-218)
LatticeStripe.Telemetry.request_span(client, req, idempotency_key, fn ->
  do_request_with_retries(client, transport_request, req.method, idempotency_key, effective_max_retries)
end)

# In Client.emit_retry_telemetry/6 — AFTER refactor (replaces lines 561-572)
LatticeStripe.Telemetry.emit_retry(client, method, url, error, attempt, delay_ms)
```

### Pattern 6: Webhook Verify Span Integration

**What:** `Webhook.construct_event/4` is wrapped in `Telemetry.webhook_verify_span/3`. The webhook span always emits (no `telemetry_enabled` check — webhook telemetry is independent of the client struct). Consider making webhook telemetry opt-in via a module attribute or always-on (decision: always-on is simpler, webhook verification has no client struct context).

**Integration point from CONTEXT.md (D-11):** `Webhook.construct_event/4` will call `Telemetry.webhook_verify_span/2` — wrapping the verify + decode sequence.

```elixir
# In Webhook.construct_event/4 — AFTER integration
def construct_event(payload, sig_header, secret, opts \\ []) when is_binary(payload) do
  LatticeStripe.Telemetry.webhook_verify_span([], fn ->
    case verify_signature(payload, sig_header, secret, opts) do
      {:ok, _timestamp} ->
        event = payload |> Jason.decode!() |> Event.from_map()
        {:ok, event}
      {:error, _reason} = error ->
        error
    end
  end)
end
```

### Anti-Patterns to Avoid

- **Anonymous function handlers:** Use `&Module.function/4` captures, not `fn ... end` in `:telemetry.attach`. Performance warning from telemetry itself.
- **Duplicating span context:** Do not manually track start times or span IDs — `:telemetry.span/3` handles this automatically via `telemetry_span_context`.
- **Including secrets in metadata:** Stripe API keys, webhook secrets — never in telemetry metadata. The `stripe_account` (Connect account ID) is safe; it's a public resource identifier.
- **Including full response body:** Don't put raw response body in telemetry metadata. `request_id` and `http_status` are sufficient.
- **Crashing the caller on handler error:** Telemetry handlers that raise will have the handler detached. The default logger should not raise. Guard with `rescue` or avoid operations that can fail.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Start/stop/exception span lifecycle | Manual try/rescue + execute/3 | `:telemetry.span/3` | Auto handles exception events, monotonic timing, span context correlation |
| Duration in native units → milliseconds | Custom arithmetic | `System.convert_time_unit(duration, :native, :millisecond)` | Correct units, handles platform differences |
| Idempotent handler attach | Track attach state manually | `:telemetry.detach/1` before `:telemetry.attach/4` | Telemetry detach is a no-op if handler not found — safe to call first |

---

## Common Pitfalls

### Pitfall 1: `:exception` Event Metadata Key Name

**What goes wrong:** Expecting exception metadata in `stop` event when using `:telemetry.span/3`.

**Why it happens:** `:telemetry.span/3` emits a SEPARATE `[:prefix, :exception]` event when the span function raises/throws. The `stop` event is NOT emitted on exception. Consumers must attach handlers to both `stop` AND `exception` events if they want full coverage.

**How to avoid:** In tests, verify both events separately. In `@moduledoc`, document this clearly.

**Warning signs:** Telemetry stop handler that "handles errors" but never fires when there's an actual Elixir exception.

### Pitfall 2: Start Metadata Not in Stop Event

**What goes wrong:** Consumer attaches to `stop` event expecting to find `:method`, `:path`, `:resource` etc. — they're absent.

**Why it happens:** `:telemetry.span/3` does NOT automatically merge start metadata into stop metadata. Stop metadata is whatever the span function returns as the second tuple element. The `telemetry_span_context` IS auto-merged (for correlation), but nothing else.

**How to avoid:** Build stop metadata struct in `Telemetry.request_span/4` that includes all needed fields from start metadata AND the result-specific fields. The current `telemetry_stop_metadata/3` in Client already does this for status/http_status — extend it to also carry method/path/resource/operation/api_version/stripe_account.

**Warning signs:** Tests on stop event that fail to find `:path` or `:method` keys.

### Pitfall 3: Duration Units

**What goes wrong:** Logging telemetry duration as raw integer and getting confusing numbers like `145234567` instead of `145`.

**Why it happens:** `:telemetry.span/3` provides duration in `:native` time units (nanoseconds on most platforms, but not guaranteed). Raw duration is not milliseconds.

**How to avoid:** Always convert: `System.convert_time_unit(measurements.duration, :native, :millisecond)`.

**Warning signs:** Log output shows multi-million "millisecond" values.

### Pitfall 4: telemetry_enabled Skips Span Entirely

**What goes wrong:** When `telemetry_enabled: false`, no exception event is emitted either (since there is no span). This is intentional and correct — but tests must account for it.

**How to avoid:** The conditional in `request_span/4` branches: `if enabled → span → else → call fun directly`. When disabled, no telemetry events of any kind are emitted, including exception. This is the correct behavior (per existing implementation).

### Pitfall 5: Webhook Span Has No client Struct

**What goes wrong:** Trying to add `telemetry_enabled` toggle to webhook verification but there's no client struct available in `Webhook.construct_event/4`.

**Why it happens:** Webhook verification is a stateless function — it takes a payload, header, and secret. No client struct context.

**How to avoid:** Webhook telemetry is always-on (no toggle). Users who don't want it can simply not attach handlers. Document this in `@moduledoc`.

### Pitfall 6: Path Parsing Edge Cases

**What goes wrong:** Path parser returns full path as resource for unknown patterns, creating high-cardinality telemetry dimensions.

**Why it happens:** Stripe paths like `/v1/customers/cus_xxx/sources` (v2 features, not in scope) or unexpected paths would fall through pattern matching.

**How to avoid:** Final catch-all clause returns `{path, to_string(method)}` — acceptable for unknown paths (they'll appear as-is). For v1 scope (all known resources), all paths are known. Add a test for each resource's paths.

---

## Code Examples

Verified patterns from official sources:

### `:telemetry.span/3` — Confirmed API from telemetry 1.4.1 source

```elixir
# Source: deps/telemetry/src/telemetry.erl
# Returns span_result() — whatever the fun returns as first element
:telemetry.span(
  [:lattice_stripe, :request],  # EventPrefix — :start/:stop/:exception appended automatically
  %{method: :post, path: "/v1/customers"},  # StartMetadata
  fn ->
    result = do_the_thing()
    # Return {result, stop_metadata} or {result, extra_measurements, stop_metadata}
    {result, %{status: :ok, http_status: 200}}
  end
)
```

### Handler attach with module function capture

```elixir
# Source: telemetry docs — prefer &Module.function/4 over anonymous fn for performance
:telemetry.attach(
  :my_handler_id,           # unique term(), stable per logical handler
  [:my, :event, :stop],
  &MyModule.handle_event/4, # module function capture, NOT anonymous fn
  %{level: :info}           # config passed as 4th arg to handler
)

# Handler signature:
def handle_event(event_name, measurements, metadata, config) do
  # event_name: [:my, :event, :stop]
  # measurements: %{duration: integer, monotonic_time: integer}
  # metadata: whatever was returned as stop_metadata from span/3
  # config: the map passed to attach
  :ok
end
```

### Duration conversion

```elixir
# Source: Elixir stdlib System module
# Convert native units to milliseconds for display
ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
# → integer milliseconds, platform-correct
```

### Detach-then-attach idempotent pattern (Oban pattern)

```elixir
# Source: Oban.Telemetry.attach_default_logger/1 pattern
@handler_id :lattice_stripe_default_logger

def attach_default_logger(opts \\ []) do
  :telemetry.detach(@handler_id)  # no-op if not attached — safe
  :telemetry.attach(@handler_id, [:lattice_stripe, :request, :stop],
    &__MODULE__.handle_log/4, %{level: Keyword.get(opts, :level, :info)})
  :ok
end
```

### Test pattern for telemetry events

```elixir
# Source: Adapted from existing client_test.exs lines 431-484
test "emits start and stop with correct metadata" do
  test_pid = self()
  handler_id = "test-#{:erlang.unique_integer([:positive])}"

  :telemetry.attach_many(handler_id,
    [[:lattice_stripe, :request, :start], [:lattice_stripe, :request, :stop]],
    fn event, measurements, metadata, _config ->
      send(test_pid, {:telemetry, event, measurements, metadata})
    end, nil)

  on_exit(fn -> :telemetry.detach(handler_id) end)

  # ... exercise code under test ...

  assert_receive {:telemetry, [:lattice_stripe, :request, :start], measurements, metadata}
  assert is_integer(measurements.system_time)
  assert metadata.method == :post
  assert metadata.path == "/v1/customers"
  assert metadata.resource == "customer"
  assert metadata.operation == "create"

  assert_receive {:telemetry, [:lattice_stripe, :request, :stop], stop_measurements, stop_meta}
  assert is_integer(stop_measurements.duration)
  assert stop_meta.status == :ok
  assert stop_meta.http_status == 200
end
```

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/telemetry_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TLMT-01 | start event emitted with method/path/resource/operation/api_version/stripe_account | unit | `mix test test/lattice_stripe/telemetry_test.exs` | ❌ Wave 0 |
| TLMT-02 | stop event emitted with duration/status/http_status/request_id/attempts | unit | `mix test test/lattice_stripe/telemetry_test.exs` | ❌ Wave 0 |
| TLMT-03 | exception event emitted on uncaught raise in span | unit | `mix test test/lattice_stripe/telemetry_test.exs` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/telemetry_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/lattice_stripe/telemetry_test.exs` — covers TLMT-01, TLMT-02, TLMT-03 (~25-30 test cases)
  - All metadata key/value/type assertions per D-12
  - Default logger output format
  - `telemetry_enabled: false` suppression
  - webhook verify span metadata
  - retry event measurements and metadata
  - attach_default_logger idempotency

---

## Existing Implementation to Extract

This is a refactor phase for telemetry logic. Current locations (MUST read before implementing):

| Location | Lines | What to Extract |
|----------|-------|-----------------|
| `lib/lattice_stripe/client.ex` | 190–218 | `:telemetry.span/3` call in `request/2` → becomes `Telemetry.request_span/4` |
| `lib/lattice_stripe/client.ex` | 561–572 | `emit_retry_telemetry/6` → becomes `Telemetry.emit_retry/5` |
| `lib/lattice_stripe/client.ex` | 574–617 | `extract_path/1` + `telemetry_stop_metadata/3` → move to `Telemetry` module, enrich with new fields |
| `test/lattice_stripe/client_test.exs` | 431–484, 846–947 | Existing telemetry tests — keep passing, extend rather than replace |

**Critical refactor constraint:** After extraction, `Client.request/2` must still work identically. The public API does not change. Only internal routing of telemetry emission changes.

---

## Environment Availability

Step 2.6: SKIPPED — this phase is purely code changes with no new external dependencies. `:telemetry` 1.4.1 is already a locked runtime dependency.

---

## Sources

### Primary (HIGH confidence)

- `deps/telemetry/src/telemetry.erl` — `:telemetry.span/3` API signature, return types, exception auto-emit behavior verified from source
- `deps/finch/lib/finch/telemetry.ex` — Centralized telemetry module pattern, `@doc false` helper convention, `@moduledoc` as event catalog
- `lib/lattice_stripe/client.ex` (lines 190–218, 561–617) — Existing implementation to be extracted
- `lib/lattice_stripe/config.ex` (line 85) — `telemetry_enabled` option definition

### Secondary (MEDIUM confidence)

- Oban.Telemetry `attach_default_logger/1` pattern — module function capture, stable handler ID, opts-based config; cited in CONTEXT.md as canonical reference
- Elixir stdlib `System.convert_time_unit/3` — duration conversion from native to millisecond units

### Tertiary (LOW confidence)

- None — all findings verified from source or in-repo deps

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — no new deps; `:telemetry` 1.4.1 source in deps, API fully verified
- Architecture: HIGH — existing working implementation in Client; Finch pattern directly in deps
- Pitfalls: HIGH — all verified from telemetry source (span/exception behavior), existing tests (metadata shape), and Stripe API path analysis
- Path parsing: MEDIUM — regex patterns are researcher's recommendation (Claude's discretion per CONTEXT.md); no official source; but Stripe path structure is well-documented by existing resource modules in codebase

**Research date:** 2026-04-03
**Valid until:** 2026-07-03 (telemetry API is extremely stable; `:telemetry` version pinned in mix.lock)
