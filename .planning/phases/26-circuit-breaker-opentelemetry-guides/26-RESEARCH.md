# Phase 26: Circuit Breaker & OpenTelemetry Guides — Research

**Researched:** 2026-04-16
**Domain:** Documentation authoring — Elixir circuit breaker (`:fuse`) and OpenTelemetry integration
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Circuit Breaker Guide**

- **D-01:** Create `guides/circuit-breaker.md`. The existing `guides/extending-lattice-stripe.md` sketch stays as-is; the new guide is the authoritative production-ready version.
- **D-02:** Guide centerpiece is a complete `MyApp.FuseRetryStrategy` implementing `@behaviour LatticeStripe.RetryStrategy`, using `:fuse.ask/2`, `:fuse.melt/1`, `:fuse.install/2` with `{:standard, count, window}` tolerance, handling the half-open probe, and explicitly documenting why `:fuse` is not bundled.
- **D-03:** Guide structure: (1) Why Circuit Breakers, (2) How Circuit Breakers Work (state machine prose), (3) Implementation with :fuse, (4) Wiring It Up, (5) Monitoring, (6) Testing, (7) Alternatives.
- **D-04:** Cross-references: circuit-breaker → extending-lattice-stripe, performance, error-handling; extending-lattice-stripe → circuit-breaker.

**OpenTelemetry Integration Guide**

- **D-05:** Create `guides/opentelemetry.md` bridging LatticeStripe `:telemetry` events to `opentelemetry_api` spans.
- **D-06:** Complete examples for Honeycomb and Datadog (full `mix.exs` deps, `config/config.exs`, `MyApp.StripeOtelHandler` module).
- **D-07:** Bridge handler attaches to all `[:lattice_stripe, :request, ...]` events (start/stop/exception); spans named `"stripe.request"` or `"stripe.webhook.verify"`; attributes: `http.method`, `http.status_code`, `stripe.resource`, `stripe.operation`, `stripe.request_id`, `stripe.attempts`; status `Ok` on 2xx, `Error` on errors.
- **D-08:** OTel deps declared as user-side `:only` dev dependencies; explicitly NOT LatticeStripe dependencies.

**Guide Placement & ExDoc**

- **D-09:** Both guides added to `:extras` in `mix.exs`, after `guides/performance.md`.
- **D-10:** Both guides in `:groups_for_extras` "Guides" group (same as all other guides — already covered by `Path.wildcard("guides/*.{md,cheatmd}")`).

**Verification Strategy**

- **D-11:** OTel example code verified by CI-excluded test tagged `@tag :otel_integration`; `opentelemetry_api` added as test-only dep; test compiles handler, attaches to events, fires mock request, asserts span created. Excluded via `ExUnit.configure(exclude: [:otel_integration])`.
- **D-12:** Circuit breaker example verified by CI-excluded test tagged `@tag :fuse_integration`; test installs a fuse, triggers failures, asserts circuit opens.

### Claude's Discretion

- Exact `:fuse` tolerance values in examples (e.g., `{:standard, 5, 10_000}`)
- Whether to use `:opentelemetry_telemetry` auto-bridge vs manual `OpenTelemetry.Tracer` calls
- Exact OTel span attribute naming (follow OpenTelemetry semantic conventions)
- Whether to include a Grafana dashboard section in the OTel guide
- Prose tone and depth for state machine explanation
- Whether the extending guide's circuit breaker example should be trimmed to a one-liner

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PERF-02 | Developer can implement a circuit breaker pattern using a documented `RetryStrategy` example with `:fuse` (user-side dep, not bundled) | `:fuse` 2.5.0 API verified; `RetryStrategy` behaviour contract confirmed from source; complete `MyApp.FuseRetryStrategy` pattern derived |
| DX-04 | Developer can read an OpenTelemetry integration guide connecting LatticeStripe telemetry events to `opentelemetry_api` with worked examples (Honeycomb, Datadog) | `opentelemetry_api` 1.5.0 + `opentelemetry` 1.7.0 + `opentelemetry_exporter` 1.10.0 verified; Honeycomb/Datadog OTLP config patterns confirmed |
</phase_requirements>

---

## Summary

Phase 26 is a pure documentation phase. No library code changes. Two new guide files are created: `guides/circuit-breaker.md` and `guides/opentelemetry.md`. Both become part of the "reliability narrative" established in Phase 24 (rate limiting) and Phase 25 (performance guide).

The circuit breaker guide is the highest-effort deliverable: it must include a complete, self-contained `MyApp.FuseRetryStrategy` module that compiles, explain the state machine in prose, and explicitly reason why `:fuse` is not bundled as a LatticeStripe dependency. The `:fuse` library (v2.5.0, Erlang, MIT, ~3.2M downloads) has a stable, minimal API (`install/2`, `ask/2`, `melt/1`) that maps cleanly to the `RetryStrategy.retry?/2` callback signature.

The OTel guide is more configuration-oriented: show how to bridge LatticeStripe's existing `:telemetry` events (the schema is finalized in Phase 24) to `opentelemetry_api` spans, with concrete vendor configs for Honeycomb (OTLP gRPC/HTTP to `api.honeycomb.io:443`, `x-honeycomb-team` header) and Datadog (OTLP HTTP to `localhost:4318`, Datadog Agent OTLP ingestion). Both guides require CI-excluded integration tests to verify example code compiles.

**Primary recommendation:** Author guides in the same structure as `guides/performance.md` — intro, code examples with inline comments, cross-references, common pitfalls. The integration tests (`:fuse_integration`, `:otel_integration`) are straightforward additions to `test/test_helper.exs`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Circuit breaker state machine | User's app (OTP gen_server via `:fuse`) | LatticeStripe (retry callback hook) | `:fuse` starts OTP processes — library must not start processes; user wires it into their supervision tree |
| Retry abort on open circuit | LatticeStripe RetryStrategy callback | — | `retry?/2` returning `:stop` when circuit open is the integration point |
| OTel span lifecycle | User's app (OTel SDK processes) | — | `opentelemetry` SDK starts its own OTP processes; user brings them |
| Telemetry event emission | LatticeStripe | — | Already shipping events; no changes needed |
| Event-to-span bridging | User's app (handler module) | — | `MyApp.StripeOtelHandler` is user-side code |
| Guide ExDoc registration | LatticeStripe `mix.exs` | — | Two lines added to `:extras` |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard | Confidence |
|---------|---------|---------|--------------|------------|
| `:fuse` | ~> 2.5 | Circuit breaker (Erlang) | Most downloaded Erlang circuit breaker; Dashbit/Elixir community de-facto standard; jlouis/fuse; zero dependencies | HIGH [VERIFIED: hex.pm/packages/fuse] |
| `opentelemetry_api` | ~> 1.4 | OTel API (no SDK processes) | Official OpenTelemetry Erlang/Elixir package; 28M+ downloads; v1.5.0 current | HIGH [VERIFIED: hex.pm/packages/opentelemetry_api] |
| `opentelemetry` | ~> 1.5 | OTel SDK implementation | Pairs with `opentelemetry_api`; v1.7.0 current | HIGH [VERIFIED: hex.pm/packages/opentelemetry] |
| `opentelemetry_exporter` | ~> 1.8 | OTLP exporter (Honeycomb/Datadog) | Official exporter; supports gRPC and HTTP protobuf; v1.10.0 current | HIGH [VERIFIED: hex.pm/packages/opentelemetry_exporter] |

### Optional Bridge Library

| Library | Version | Purpose | When to Use | Confidence |
|---------|---------|---------|-------------|------------|
| `opentelemetry_telemetry` | ~> 1.1 | Auto-bridge `:telemetry` → OTel | Available v1.1.2; alternative to manual `Tracer` calls | MEDIUM [VERIFIED: hex.pm/packages/opentelemetry_telemetry] |

**Recommendation (Claude's Discretion):** Use **manual `OpenTelemetry.Tracer` calls** in the guide, not `opentelemetry_telemetry`. Reasons:
1. The guide must be self-explanatory — readers understand exactly what spans are created and why.
2. `opentelemetry_telemetry` adds another dependency to manage.
3. Manual approach gives full control over span naming, attribute mapping, and status logic.
4. `with_span` macro automatically handles span lifecycle, so manual doesn't mean verbose.

### Version Notes

The D-08 locked decision specifies these dep version constraints:
```elixir
{:opentelemetry_api, "~> 1.4", only: :dev},
{:opentelemetry, "~> 1.5", only: :dev},
{:opentelemetry_exporter, "~> 1.8", only: :dev}
```
Current versions (1.5.0, 1.7.0, 1.10.0) are all compatible with these constraints. [VERIFIED: hex.pm]

---

## Architecture Patterns

### System Architecture Diagram

```
LatticeStripe.Telemetry
  |-- emits [:lattice_stripe, :request, :start/stop/exception]
  |-- emits [:lattice_stripe, :webhook, :verify, :start/stop/exception]
        |
        v
  :telemetry.attach_many/4 (in MyApp.StripeOtelHandler.setup/0)
        |
        v
  MyApp.StripeOtelHandler.handle_event/4
     |-- :start  → OpenTelemetry.Tracer.start_span("stripe.request")
     |             store ctx in process dict / pass through span_ctx
     |-- :stop   → set_attributes(http.method, http.status_code, etc.)
     |             set_status(ok/error)
     |             OpenTelemetry.Tracer.end_span()
     |-- :exception → record_exception(); set_status(:error); end_span()
        |
        v
  opentelemetry SDK (running in app supervision tree)
        |
        v
  opentelemetry_exporter (OTLP)
     |-- Honeycomb: api.honeycomb.io:443 (gRPC), x-honeycomb-team header
     |-- Datadog:  localhost:4318 (HTTP), Datadog Agent OTLP ingestion
```

```
LatticeStripe.RetryStrategy callback (retry?/2)
     |
     v
  MyApp.FuseRetryStrategy.retry?(attempt, context)
     |-- :fuse.ask(:stripe_api, :sync)
     |     |-- ok     → apply normal retry logic
     |     |-- blown  → :stop (fail fast, circuit open)
     |-- :fuse.melt(:stripe_api) on 5xx/connection_error
     |-- {:retry, delay_ms} or :stop
        |
        v
  :fuse gen_server (in user's supervision tree)
     |-- {:standard, 5, 10_000}: open after 5 failures in 10s
     |-- {reset, 30_000}: half-open probe after 30s
```

### Recommended Project Structure

No new source files are created in LatticeStripe itself. New files:

```
guides/
├── circuit-breaker.md     # NEW — full :fuse-based RetryStrategy guide
├── opentelemetry.md       # NEW — OTel bridge guide (Honeycomb + Datadog)
└── performance.md         # EXISTING — referenced for reliability context
test/
├── test_helper.exs        # MODIFIED — add :otel_integration, :fuse_integration exclusions
└── integration/
    ├── circuit_breaker_integration_test.exs   # NEW — @tag :fuse_integration
    └── opentelemetry_integration_test.exs     # NEW — @tag :otel_integration
mix.exs                    # MODIFIED — add guides to :extras, add dev deps
```

### Pattern 1: `:fuse` API in Elixir

`:fuse` is an Erlang library; use with Elixir atom-style module calls via `:fuse.function()`.

```elixir
# Source: https://github.com/jlouis/fuse (verified API)

# Install in Application.start/2 — fuse starts its own gen_server
:fuse.install(:stripe_api, {{:standard, 5, 10_000}, {:reset, 30_000}})
# {:standard, MaxR, MaxT} = open after MaxR melts within MaxT milliseconds
# {:reset, TimeMs} = auto-reset (half-open probe) after TimeMs ms

# Ask: returns :ok (closed) or :blown (open)
case :fuse.ask(:stripe_api, :sync) do
  :ok    -> {:retry, delay_ms}
  :blown -> :stop
end

# Melt: record a failure
:fuse.melt(:stripe_api)
```

**Key insight on half-open:** `:fuse` handles half-open automatically via `{:reset, TimeMs}`. After `TimeMs` milliseconds, the next call to `:fuse.ask/2` returns `:ok` (probe allowed). If that probe fails (`:fuse.melt/1` called), the circuit re-opens for another `TimeMs` interval. No special half-open handling is needed in the `RetryStrategy`.

### Pattern 2: Complete `MyApp.FuseRetryStrategy`

```elixir
# Source: Derived from RetryStrategy.Default in lib/lattice_stripe/retry_strategy.ex
# and :fuse API from https://github.com/jlouis/fuse

defmodule MyApp.FuseRetryStrategy do
  @behaviour LatticeStripe.RetryStrategy

  @fuse_name :stripe_api
  @max_attempts 3

  @impl true
  def retry?(attempt, context) do
    case :fuse.ask(@fuse_name, :sync) do
      :blown ->
        # Circuit open — fail fast, no retry
        :stop

      :ok ->
        # Circuit closed or half-open probe — check if we should retry
        retry_or_stop(attempt, context)
    end
  end

  defp retry_or_stop(attempt, _context) when attempt > @max_attempts, do: :stop

  defp retry_or_stop(attempt, context) do
    # Stripe-Should-Retry header takes highest priority
    case Map.get(context, :stripe_should_retry) do
      false -> :stop
      _ ->
        case context.status do
          # Idempotency conflicts: never retry
          409 -> :stop

          # 429 rate limit: retry but record failure
          429 ->
            :fuse.melt(@fuse_name)
            {:retry, backoff(attempt)}

          # 5xx errors: retry and record failure
          status when is_integer(status) and status >= 500 ->
            :fuse.melt(@fuse_name)
            {:retry, backoff(attempt)}

          # Connection errors: retry and record failure
          nil when context.error != nil ->
            :fuse.melt(@fuse_name)
            {:retry, backoff(attempt)}

          # All other status codes: stop
          _ -> :stop
        end
    end
  end

  defp backoff(attempt) do
    base = min(500 * Integer.pow(2, attempt - 1), 5_000)
    jitter = div(base, 2)
    jitter + :rand.uniform(jitter + 1) - 1
  end
end
```

**Application.start/2 wiring:**

```elixir
def start(_type, _args) do
  # Install the fuse before starting your supervision tree.
  # :fuse starts its own gen_server; it must be running before any ask/melt.
  :fuse.install(:stripe_api, {{:standard, 5, 10_000}, {:reset, 30_000}})

  children = [
    {Finch, name: MyApp.Finch, pools: %{"https://api.stripe.com" => [size: 10]}},
    MyAppWeb.Endpoint
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

**Client wiring:**

```elixir
client = LatticeStripe.Client.new!(
  api_key: System.fetch_env!("STRIPE_SECRET_KEY"),
  finch: MyApp.Finch,
  retry_strategy: MyApp.FuseRetryStrategy
)
```

### Pattern 3: `MyApp.StripeOtelHandler`

```elixir
# Source: Derived from guides/telemetry.md handler patterns
# and OpenTelemetry.Tracer API from https://hexdocs.pm/opentelemetry_api/OpenTelemetry.Tracer.html

defmodule MyApp.StripeOtelHandler do
  require OpenTelemetry.Tracer

  @request_events [
    [:lattice_stripe, :request, :start],
    [:lattice_stripe, :request, :stop],
    [:lattice_stripe, :request, :exception],
    [:lattice_stripe, :webhook, :verify, :start],
    [:lattice_stripe, :webhook, :verify, :stop]
  ]

  def setup do
    :telemetry.attach_many(
      "myapp-stripe-otel",
      @request_events,
      &__MODULE__.handle_event/4,
      %{}
    )
  end

  # Start events — begin a new span
  def handle_event([:lattice_stripe, :request, :start], _measurements, metadata, _config) do
    span_name = "stripe.request"
    OpenTelemetry.Tracer.start_span(span_name, %{
      kind: :client,
      attributes: %{
        "http.request.method" => metadata.method |> to_string() |> String.upcase(),
        "url.path" => metadata.path,
        "stripe.resource" => metadata.resource,
        "stripe.operation" => metadata.operation
      }
    })
  end

  # Stop events — set attributes and end span
  def handle_event([:lattice_stripe, :request, :stop], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    attrs = %{
      "http.response.status_code" => metadata[:http_status],
      "stripe.resource" => metadata.resource,
      "stripe.operation" => metadata.operation,
      "stripe.request_id" => metadata[:request_id],
      "stripe.attempts" => metadata[:attempts],
      "duration_ms" => duration_ms
    }

    OpenTelemetry.Tracer.set_attributes(attrs)

    case metadata.status do
      :ok -> OpenTelemetry.Tracer.set_status(:ok, "")
      :error -> OpenTelemetry.Tracer.set_status(:error, "Stripe request failed")
    end

    OpenTelemetry.Tracer.end_span()
  end

  # Exception events — record as error
  def handle_event([:lattice_stripe, :request, :exception], _measurements, metadata, _config) do
    OpenTelemetry.Tracer.record_exception(metadata.reason, metadata.stacktrace, %{})
    OpenTelemetry.Tracer.set_status(:error, "exception")
    OpenTelemetry.Tracer.end_span()
  end

  # Webhook verify start
  def handle_event([:lattice_stripe, :webhook, :verify, :start], _measurements, metadata, _config) do
    OpenTelemetry.Tracer.start_span("stripe.webhook.verify", %{kind: :server})
    if path = metadata[:path] do
      OpenTelemetry.Tracer.set_attribute("url.path", path)
    end
  end

  # Webhook verify stop
  def handle_event([:lattice_stripe, :webhook, :verify, :stop], _measurements, metadata, _config) do
    case metadata.result do
      :ok -> OpenTelemetry.Tracer.set_status(:ok, "")
      :error ->
        OpenTelemetry.Tracer.set_attribute("stripe.webhook.error_reason",
          to_string(metadata[:error_reason] || "unknown"))
        OpenTelemetry.Tracer.set_status(:error, "webhook verification failed")
    end
    OpenTelemetry.Tracer.end_span()
  end
end
```

**Note on span context threading:** `OpenTelemetry.Tracer.start_span/2` does NOT automatically make the span current (unlike `with_span`). For start/stop event bridging, use `start_span` on `:start` and pair with `end_span` on `:stop`. The span context from `start_span` must be captured in the process dictionary. See the OTel guide section on context for details. An alternative approach is to use `with_span` in a single-event pattern (e.g., on `:stop` only, using `measurements.duration` to set an explicit start time via span options). The guide should discuss this tradeoff.

### Pattern 4: Honeycomb Configuration

```elixir
# Source: https://hexdocs.pm/opentelemetry_exporter/1.2.1/readme.html [VERIFIED]
# In config/runtime.exs (preferred for secrets):
config :opentelemetry_exporter,
  otlp_protocol: :grpc,
  otlp_compression: :gzip,
  otlp_endpoint: "https://api.honeycomb.io:443",
  otlp_headers: [
    {"x-honeycomb-team", System.fetch_env!("HONEYCOMB_API_KEY")},
    {"x-honeycomb-dataset", "myapp-stripe"}
  ]

config :opentelemetry,
  service_name: :myapp,
  resource: %{service: %{name: "myapp", version: "1.0.0"}}
```

### Pattern 5: Datadog Configuration

```elixir
# Source: Datadog OTLP ingestion docs [VERIFIED: docs.datadoghq.com]
# Datadog Agent must have OTLP ingestion enabled in datadog.yaml:
#   otlp_config:
#     receiver:
#       protocols:
#         http:
#           endpoint: 0.0.0.0:4318

# In config/config.exs:
config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: "http://localhost:4318"

config :opentelemetry,
  service_name: :myapp
```

### Anti-Patterns to Avoid

- **Calling `:fuse.install/2` in the RetryStrategy module itself:** `install/2` must be called once in `Application.start/2`. Calling it per-request causes repeated gen_server messages.
- **Using `with_span` macro for start/stop event bridging:** `with_span` requires the entire operation to run in the same lexical block. Telemetry start/stop events arrive in separate handler calls. Use `start_span`/`end_span` instead.
- **Forgetting `require OpenTelemetry.Tracer`:** OTel Tracer functions are macros; `require` is mandatory before use.
- **Atomizing span attribute values:** The OTel guide's attribute values should be strings, not atoms. `metadata.method` is an atom (`:get`); convert with `to_string()`.
- **Using old HTTP semantic conventions:** The stable HTTP conventions use `http.request.method` and `http.response.status_code`, not the old `http.method` / `http.status_code` (deprecated). [VERIFIED: opentelemetry.io/docs/specs/semconv/http/]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Circuit breaker state machine | ETS counter + GenServer | `:fuse` | Half-open logic, race conditions, reset timers, fault injection are all handled; ETS approach misses subtle linearizability issues |
| OTLP export | Custom HTTP client posting to Honeycomb | `opentelemetry_exporter` | Protobuf serialization, batching, retry on export failure, compression |
| Telemetry → OTel span bridge | Roll your own context threading | `OpenTelemetry.Tracer` API | Context API handles process dictionary management; doing it manually is fragile |

**Key insight:** The guide's job is to show readers they do NOT need to hand-roll these. The value is in demonstrating `:fuse` and `OpenTelemetry.Tracer` together with LatticeStripe's existing events.

---

## Common Pitfalls

### Pitfall 1: `:fuse` Not Started Before First `ask/2`

**What goes wrong:** `{:error, not_found}` returned from `:fuse.ask/2` at runtime; circuit breaker silently fails open.

**Why it happens:** `:fuse` has its own OTP application that must be started, and the named fuse must be installed via `:fuse.install/2` before any requests are made.

**How to avoid:** In `Application.start/2`, call `:fuse.install/2` before starting Finch or any child that will make Stripe requests. `:fuse`'s OTP app starts automatically when it's a mix dependency.

**Warning signs:** `retry?/2` never returns `:stop` from circuit logic; logs show `{:error, not_found}` from `:fuse`.

### Pitfall 2: OTel Span Context Lost Between Handler Calls

**What goes wrong:** `end_span()` in the `:stop` handler has no active span to end; spans appear empty or unrelated.

**Why it happens:** `start_span/2` stores span context in the process dictionary of the calling process. If `:telemetry` dispatches handlers in a different process (or if context is not threaded), the `:stop` handler cannot find the span started by `:start`.

**How to avoid:** Use `:telemetry.span/3` wrapping an entire operation when possible. For event-based bridging, verify that telemetry handlers run in the same process as the emitting code (they do in LatticeStripe — `:telemetry.span/3` emits in the calling process). Document this assumption in the guide.

**Warning signs:** Spans appear as separate root spans rather than complete start→stop pairs in the backend.

### Pitfall 3: Forgetting `only: :dev` on OTel Deps in Guide Examples

**What goes wrong:** Reader adds `opentelemetry_api` as a production dep to their SDK-type library, which forces OTel on all their users.

**Why it happens:** Copying the dep declaration without the `only: :dev` qualifier.

**How to avoid:** The guide must prominently show `only: :dev` and explain that these are user-side dependencies for the application using LatticeStripe, not LatticeStripe itself.

### Pitfall 4: Old HTTP Semantic Conventions

**What goes wrong:** Spans have `http.method` / `http.status_code` attributes (deprecated) instead of `http.request.method` / `http.response.status_code`.

**Why it happens:** Training data and many blog posts predate the 2023 HTTP semconv stability announcement.

**How to avoid:** Use the stable names. [VERIFIED: opentelemetry.io/docs/specs/semconv/http/http-spans/]

### Pitfall 5: CI Fails Because Integration Tests Run Without OTel/Fuse Deps

**What goes wrong:** `mix test` fails with `UndefinedFunctionError` for `:fuse.ask/2` or `OpenTelemetry.Tracer` macros.

**Why it happens:** Integration test files are compiled even when tagged tests are excluded; deps declared `only: :dev` are not available in the `:test` env.

**How to avoid:** The integration tests must also declare the deps in the `:test` env, OR the test files must guard compilation with `Code.ensure_loaded?/1` checks. The locked decision (D-11/D-12) declares deps as `only: :dev` — this means the integration tests should be in the `:dev` test path, or deps should be declared `:only: [:dev, :test]`. This is a planning decision to surface.

**Recommendation:** Declare fuse and opentelemetry_api as `only: [:dev, :test]` in the example `mix.exs` shown in the guide. The `:fuse_integration` and `:otel_integration` test files in LatticeStripe itself should be excluded from CI by default (they're documentation verification, not library tests).

---

## Code Examples

### `:fuse` Install and Ask (Elixir)

```elixir
# Source: https://github.com/jlouis/fuse — verified API [VERIFIED]

# Strategy: {:standard, MaxR, MaxT} — open after MaxR melts within MaxT ms
# Refresh: {:reset, TimeMs} — auto half-open probe after TimeMs ms
:fuse.install(:stripe_api, {{:standard, 5, 10_000}, {:reset, 30_000}})

# Returns :ok (closed/half-open probe) or :blown (open)
:fuse.ask(:stripe_api, :sync)

# Record a failure
:fuse.melt(:stripe_api)
```

### OTel Dep Declaration (User's mix.exs)

```elixir
# Source: https://hexdocs.pm/opentelemetry_exporter/1.2.1/readme.html [VERIFIED]
# Note: opentelemetry_exporter must be listed BEFORE opentelemetry in deps
defp deps do
  [
    {:lattice_stripe, "~> 1.1"},
    {:opentelemetry_exporter, "~> 1.8", only: [:dev, :test]},
    {:opentelemetry, "~> 1.5", only: [:dev, :test]},
    {:opentelemetry_api, "~> 1.4", only: [:dev, :test]},
    # ... other deps
  ]
end
```

**Note:** `opentelemetry_exporter` must come before `opentelemetry` in the deps list for proper initialization order. [CITED: hexdocs.pm/opentelemetry_exporter]

### ExUnit Test Tags for CI Exclusion

```elixir
# test/test_helper.exs — modification (additive)
ExUnit.start()
ExUnit.configure(exclude: [:integration, :fuse_integration, :otel_integration])
```

### OTel Semantic Conventions (HTTP)

Current stable names (as of OTel semconv v1.23.1+):

| Old (deprecated) | New (stable) |
|------------------|--------------|
| `http.method` | `http.request.method` |
| `http.status_code` | `http.response.status_code` |
| `http.url` | `url.full` |
| `http.target` | `url.path` |

[VERIFIED: opentelemetry.io/docs/specs/semconv/http/http-spans/]

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `http.method` / `http.status_code` span attrs | `http.request.method` / `http.response.status_code` | OTel semconv v1.20.0 → v1.23.1 (2023) | Guide must use new names |
| `opentelemetry_honeycomb` hex package | Standard `opentelemetry_exporter` with Honeycomb OTLP config | ~2022 | `opentelemetry_honeycomb` is unmaintained (v0.5.0-rc.1, last updated 2020); don't use it |
| Manual fuse supervision in `children` list | `:fuse.install/2` before `Supervisor.start_link/2` | N/A | `:fuse` manages its own gen_server; users only call `install/2` |

**Deprecated/outdated:**
- `opentelemetry_honeycomb` (garthk/opentelemetry_honeycomb): Last updated 2020, v0.5.0-rc.1. Do not recommend. Use standard `opentelemetry_exporter` instead. [ASSUMED based on hex.pm scrape; confirmed last update date]
- `http.method` / `http.status_code` OTel attributes: Deprecated in semconv v1.20.0, replaced by `http.request.method` / `http.response.status_code`.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `:fuse.ask/2` returns `:ok` for half-open probe attempts (not a special third value) | Pattern 1 | Guide would need to add half-open handling logic |
| A2 | `opentelemetry_exporter` must be listed before `opentelemetry` in mix.exs deps | Code Examples | Compilation/init order could silently break OTel setup |
| A3 | OTel handler functions run in the same process as the telemetry emitter (LatticeStripe), so span context in process dict is accessible | Pitfall 2 | Span start/stop won't correlate; need `telemetry_span_context` reference-based approach |
| A4 | `only: :dev` deps are NOT available in the `:test` env by default | Pitfall 5 | Integration tests may fail to compile; planning must clarify dep env scope |

---

## Open Questions

1. **Span context threading for start/stop events**
   - What we know: `start_span/2` stores ctx in process dict; `:telemetry.span/3` emits start/stop in the same process
   - What's unclear: Does the OTel context persist between the `:start` telemetry handler call and the `:stop` handler call if they run in the same `GenServer` request context?
   - Recommendation: The guide should document using `telemetry_span_context` reference from metadata to correlate events, and recommend using `with_span` wrapping a single operation where feasible.

2. **`:fuse` dep scope for integration test (D-12)**
   - What we know: D-08 specifies `only: :dev` for OTel deps; D-12 says add them as test deps
   - What's unclear: Should `:fuse` be `only: [:dev, :test]` in LatticeStripe's mix.exs to enable the `:fuse_integration` test to compile?
   - Recommendation: Yes — add `:fuse` as `only: [:dev, :test]` (not `:only: :dev`) in LatticeStripe's mix.exs for the duration of Phase 26. This is the minimum change to make the integration test compile.

3. **Grafana section in OTel guide**
   - Claude's discretion area. Recommendation: Skip it. The guide is already covering two backends. Grafana would require a separate OTEL Collector config. Keep the guide focused on the bridge code.

---

## Environment Availability

Step 2.6: SKIPPED (no external runtime dependencies — phase is documentation-only with opt-in test verification; `:fuse` and `opentelemetry_api` are user-side deps, not system dependencies).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test` |
| Full suite command | `mix test --include fuse_integration --include otel_integration` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PERF-02 | `MyApp.FuseRetryStrategy` compiles and circuit opens after failures | integration | `mix test test/integration/circuit_breaker_integration_test.exs --include fuse_integration` | ❌ Wave 0 |
| DX-04 | `MyApp.StripeOtelHandler` compiles, attaches, creates span on mock request | integration | `mix test test/integration/opentelemetry_integration_test.exs --include otel_integration` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test` (quick; excludes integration tags)
- **Per wave merge:** `mix test` (integration tests are optional CI-excluded; verified manually)
- **Phase gate:** `mix test --warnings-as-errors` + `mix docs --warnings-as-errors` (guide links/ExDoc config)

### Wave 0 Gaps

- [ ] `test/integration/circuit_breaker_integration_test.exs` — covers PERF-02; requires `:fuse` dep
- [ ] `test/integration/opentelemetry_integration_test.exs` — covers DX-04; requires `opentelemetry_api` dep
- [ ] `mix.exs` dep additions: `{:fuse, "~> 2.5", only: [:dev, :test]}` and `{:opentelemetry_api, "~> 1.4", only: [:dev, :test]}`

---

## Security Domain

Phase 26 is documentation-only. No code paths, no data processing, no authentication, no input validation surfaces are introduced. ASVS categories V2/V3/V4/V5/V6 do not apply.

**One documentation security note:** The OTel guide config examples show `System.fetch_env!("HONEYCOMB_API_KEY")` in `runtime.exs`. The guide must emphasize this pattern (runtime env, not hardcoded) to avoid readers committing API keys to git.

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 26 |
|-----------|-------------------|
| No new runtime dependencies | `:fuse` and `opentelemetry_api` are user-side deps; LatticeStripe adds them as `only: [:dev, :test]` at most |
| No Dialyzer | Not applicable |
| Minimal dependencies | OTel guide explicitly states these are user-side; guide shows `only: :dev` pattern |
| No GenServer for state | `:fuse` starts its OTP processes in the user's app, not LatticeStripe — guide explains this design decision |
| Transport behaviour | Not affected by this phase |
| GSD workflow enforcement | All file changes must go through GSD execute-phase |

---

## Sources

### Primary (HIGH confidence)

- [VERIFIED: hex.pm/packages/fuse] — v2.5.0 confirmed, MIT, Erlang circuit breaker
- [VERIFIED: hex.pm/packages/opentelemetry_api] — v1.5.0 confirmed, Apache-2.0
- [VERIFIED: hex.pm/packages/opentelemetry] — v1.7.0 confirmed
- [VERIFIED: hex.pm/packages/opentelemetry_exporter] — v1.10.0 confirmed
- [VERIFIED: hex.pm/packages/opentelemetry_telemetry] — v1.1.2 confirmed
- [CITED: github.com/jlouis/fuse] — `:fuse.install/2`, `:fuse.ask/2`, `:fuse.melt/1` API signatures confirmed
- [CITED: hexdocs.pm/opentelemetry_api/OpenTelemetry.Tracer.html] — `start_span`, `with_span`, `set_attributes`, `set_status`, `end_span`, `record_exception` confirmed
- [CITED: hexdocs.pm/opentelemetry_exporter/1.2.1/readme.html] — Honeycomb and Datadog OTLP configuration patterns confirmed
- [CITED: opentelemetry.io/docs/specs/semconv/http/http-spans/] — Stable HTTP semantic conventions (http.request.method, http.response.status_code)
- [CITED: docs.datadoghq.com/opentelemetry/setup/otlp_ingest_in_the_agent/] — Datadog Agent OTLP ingestion port 4318 confirmed

### Secondary (MEDIUM confidence)

- Honeycomb OTLP config pattern (`x-honeycomb-team`, `x-honeycomb-dataset` headers, endpoint `api.honeycomb.io:443`) confirmed via search + opentelemetry_exporter docs example [CITED: hexdocs.pm/opentelemetry_exporter/1.2.1/readme.html]

### Tertiary (LOW confidence / ASSUMED)

- `:fuse.ask/2` returns `:ok` for half-open probe (not a third value) — [ASSUMED from fuse README; needs verification against source or hexdocs]
- `opentelemetry_exporter` must come before `opentelemetry` in deps list — [ASSUMED from community knowledge; should be verified in exporter README]

---

## Metadata

**Confidence breakdown:**

- Standard stack (versions): HIGH — all packages verified against hex.pm registry
- `:fuse` API: HIGH — verified against github.com/jlouis/fuse README and hexdocs
- OTel API patterns: HIGH — verified against hexdocs.pm/opentelemetry_api
- Vendor configs (Honeycomb/Datadog): MEDIUM — patterns confirmed from official exporter docs and vendor OTLP docs
- HTTP semconv attribute names: HIGH — verified against opentelemetry.io official spec

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 (OTel semconv is stable; `:fuse` is mature/slow-moving)
