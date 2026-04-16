# Phase 26: Circuit Breaker & OpenTelemetry Guides - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Developers who need cascading-failure protection or production observability get two authoritative, copy-paste-ready guides: (1) a circuit breaker guide showing a complete `:fuse`-based `RetryStrategy` implementation with state machine explanation, and (2) an OpenTelemetry integration guide bridging LatticeStripe telemetry events to `opentelemetry_api` with Honeycomb and Datadog examples.

This phase is documentation-only. No new modules, no new runtime dependencies, no code changes to the library. Both `:fuse` and `opentelemetry_api` are user-side dependencies documented as such.

</domain>

<decisions>
## Implementation Decisions

### Circuit Breaker Guide

- **D-01:** Create `guides/circuit-breaker.md` as a dedicated guide. The existing `guides/extending-lattice-stripe.md` has a brief `MyApp.CircuitBreakerRetry` example — the new guide expands this into a full worked example with `:fuse` specifically, including the failure/open/half-open state machine explained in prose. The extending guide's example stays as-is (it's a generic sketch); the circuit breaker guide is the authoritative, production-ready version.

- **D-02:** The guide's centerpiece is a complete `MyApp.FuseRetryStrategy` module that:
  - Implements `@behaviour LatticeStripe.RetryStrategy`
  - Uses `:fuse.ask/2` to check circuit state before retrying
  - Uses `:fuse.melt/1` to record failures
  - Configures `:fuse.install/2` with `{:standard, count, window}` tolerance
  - Handles the half-open probe attempt
  - Explicitly documents why `:fuse` is not bundled (starts OTP processes; violates library's no-global-state philosophy per Out of Scope table in REQUIREMENTS.md)

- **D-03:** Guide structure:
  1. **Why Circuit Breakers** — Cascading failure scenario with Stripe (dependency goes down, your app queues requests, timeouts cascade)
  2. **How Circuit Breakers Work** — Closed/open/half-open state machine with prose explanation (not just code)
  3. **Implementation with :fuse** — Complete `MyApp.FuseRetryStrategy` module, `:fuse` dependency declaration, `:fuse.install/2` in `Application.start/2`
  4. **Wiring It Up** — `Client.new!/1` with `retry_strategy: MyApp.FuseRetryStrategy`
  5. **Monitoring** — Telemetry handler that emits circuit breaker state changes (open/close events)
  6. **Testing** — How to test the strategy with Mox (mock the Transport, trigger failures, verify circuit opens)
  7. **Alternatives** — Brief mention of other circuit breaker libraries (`:circuit_breaker`, rolling your own with ETS counters)

- **D-04:** Cross-references:
  - From `guides/circuit-breaker.md` → `guides/extending-lattice-stripe.md` (RetryStrategy behaviour reference)
  - From `guides/circuit-breaker.md` → `guides/performance.md` (production reliability context)
  - From `guides/circuit-breaker.md` → `guides/error-handling.md` (retry behavior fundamentals)
  - From `guides/extending-lattice-stripe.md` → `guides/circuit-breaker.md` ("See the dedicated circuit breaker guide for a production-ready :fuse implementation")

### OpenTelemetry Integration Guide

- **D-05:** Create `guides/opentelemetry.md` as a dedicated guide. Shows how to bridge LatticeStripe's `:telemetry` events to `opentelemetry_api` spans using `:opentelemetry_telemetry` or manual `OpenTelemetry.Tracer` calls.

- **D-06:** The guide includes complete, runnable examples for two backends:
  - **Honeycomb** — `opentelemetry_exporter` with Honeycomb API key and dataset configuration
  - **Datadog** — `opentelemetry_exporter` with Datadog Agent endpoint (localhost:4318 OTLP)
  Both examples show the full `mix.exs` deps, `config/config.exs` configuration, and a `MyApp.StripeOtelHandler` module.

- **D-07:** The bridge handler (`MyApp.StripeOtelHandler`) uses `:telemetry.attach_many/4` to attach to all LatticeStripe request events (`start`, `stop`, `exception`) and creates OTel spans with:
  - Span name: `"stripe.request"` (or `"stripe.webhook.verify"` for webhook events)
  - Attributes: `http.method`, `http.status_code`, `stripe.resource`, `stripe.operation`, `stripe.request_id`, `stripe.attempts`
  - Status: `Ok` on 2xx, `Error` on 4xx/5xx/connection errors
  - Duration from the telemetry measurements

- **D-08:** OTel deps are declared as user-side `:only` dev/test dependencies in the example code:
  ```elixir
  {:opentelemetry_api, "~> 1.4", only: :dev},
  {:opentelemetry, "~> 1.5", only: :dev},
  {:opentelemetry_exporter, "~> 1.8", only: :dev}
  ```
  The guide explicitly states these are NOT LatticeStripe dependencies — users add them to their own `mix.exs`.

### Guide Placement & ExDoc

- **D-09:** Both guides are added to the `:extras` list in `mix.exs` ExDoc config, in the Guides group alongside existing guides. Placement order: after `guides/performance.md` (the reliability narrative flows: performance → circuit breaker → observability).

- **D-10:** Add both guides to the ExDoc `:groups_for_extras` config under the existing "Guides" group (same as all other guides).

### Verification Strategy

- **D-11:** The OTel guide's example code is verified by a CI-excluded integration test tagged `@tag :otel_integration`. This test:
  - Adds `opentelemetry_api` as a test dependency (in `:dev` only group)
  - Compiles the `MyApp.StripeOtelHandler` module from the guide
  - Attaches it to telemetry events
  - Fires a mock request
  - Asserts a span was created
  The test is excluded from default `mix test` runs via `ExUnit.configure(exclude: [:otel_integration])` in `test/test_helper.exs`.

- **D-12:** The circuit breaker guide's `:fuse` example is verified similarly — a CI-excluded test tagged `@tag :fuse_integration` that compiles the `MyApp.FuseRetryStrategy`, installs a fuse, triggers failures, and asserts circuit opens.

### Claude's Discretion

- Exact `:fuse` tolerance values in the example (e.g., `{:standard, 5, 10_000}` for 5 failures in 10 seconds)
- Whether to use `:opentelemetry_telemetry` (auto-bridge library) vs manual `OpenTelemetry.Tracer` calls in the handler
- Exact OTel span attribute naming conventions (follow OpenTelemetry semantic conventions for HTTP)
- Whether to include a "Grafana dashboard" section in the OTel guide or keep it focused on the bridge code
- Prose tone and depth for the state machine explanation
- Whether the extending guide's circuit breaker example should be trimmed to a one-liner cross-reference or left as-is

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### RetryStrategy Behaviour
- `lib/lattice_stripe/retry_strategy.ex` — `RetryStrategy` behaviour definition (line 1-36) and `Default` implementation (line 38-127); the circuit breaker guide wraps this behaviour
- `guides/extending-lattice-stripe.md` — Existing `MyApp.CircuitBreakerRetry` example (line 296-337) that the dedicated guide expands

### Telemetry Event Schema
- `lib/lattice_stripe/telemetry.ex` — Complete telemetry event definitions, metadata keys, `request_span/4`, `build_stop_metadata`; the OTel guide maps these events to OTel spans
- `guides/telemetry.md` — Full event documentation including all metadata tables, custom handler examples, rate limiting section; the OTel guide cross-references this

### Existing Guides (for pattern/structure reference)
- `guides/performance.md` — Most recent guide; establishes the reliability narrative that Phase 26 continues
- `guides/error-handling.md` — Retry behavior fundamentals that circuit breaker guide references
- `guides/client-configuration.md` — Client setup patterns referenced by both guides

### Project Constraints
- `.planning/REQUIREMENTS.md` — PERF-02 (circuit breaker), DX-04 (OTel guide); Out of Scope table explicitly excludes `:fuse` as bundled dep
- `.planning/PROJECT.md` — No-global-state philosophy; library doesn't start OTP processes
- `mix.exs` — ExDoc `:extras` and `:groups_for_extras` config for guide placement

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`RetryStrategy` behaviour** — Already defines the `retry?/2` callback contract; circuit breaker guide implements this
- **`RetryStrategy.Default`** — Reference implementation showing backoff, header parsing, status checks; circuit breaker guide extends this pattern
- **`MyApp.CircuitBreakerRetry`** in extending guide — Existing sketch to expand into full `:fuse` example
- **`MyApp.StripeOtelHandler`** pattern — Telemetry guide's custom handler examples (lines 219-309) provide the structural template

### Established Patterns
- **Guide structure** — All 18 guides follow: title, intro paragraph, code examples with inline comments, cross-references, common pitfalls section
- **ExDoc extras config** — Guides added to `:extras` list in `mix.exs`, grouped under "Guides" in `:groups_for_extras`
- **`:telemetry.attach_many/4`** — Pattern already shown in telemetry guide (line 469-485); OTel handler follows same approach
- **Integration test tagging** — `@tag :integration` pattern exists in test suite for stripe-mock tests; same pattern for `:otel_integration` and `:fuse_integration`

### Integration Points
- **`mix.exs` ExDoc config** — Add `guides/circuit-breaker.md` and `guides/opentelemetry.md` to `:extras`
- **`guides/extending-lattice-stripe.md`** — Add cross-reference to dedicated circuit breaker guide
- **`test/test_helper.exs`** — Add `:otel_integration` and `:fuse_integration` to exclude list

</code_context>

<specifics>
## Specific Ideas

- The circuit breaker guide must explain the state machine in prose, not just code (SC-2 requirement)
- The OTel guide must show at least Honeycomb AND Datadog backends (SC-3 requirement)
- The OTel example code must compile cleanly with `opentelemetry_api` as dev dep (SC-4 requirement)
- `:fuse` is the specific circuit breaker library — not `:circuit_breaker` or a generic approach (SC-1 requirement)
- The circuit breaker guide must explicitly document why `:fuse` is not bundled — this is a conscious design decision, not an oversight
- Both guides are the final piece of the "reliability narrative" that started with Phase 24 (rate-limit awareness) and Phase 25 (performance guide)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 26-circuit-breaker-opentelemetry-guides*
*Context gathered: 2026-04-16 via --auto mode*
