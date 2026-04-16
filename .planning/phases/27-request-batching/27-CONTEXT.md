# Phase 27: Request Batching - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Developers can execute multiple independent Stripe API calls concurrently with a single ergonomic helper (`LatticeStripe.Batch.run/2`) that returns structured results per-call without crashing the caller when individual requests fail or time out.

This phase adds one new module (`LatticeStripe.Batch`) with one public function (`run/2`). It does NOT modify Client, Request, Error, Transport, or any existing resource modules. It does NOT implement Stripe's server-side batch API — it's a client-side fan-out convenience using `Task.async_stream`.

</domain>

<decisions>
## Implementation Decisions

### Input Format

- **D-01:** Callers pass a list of MFA tuples `{module, :function, args}` where each tuple represents a complete Stripe API call. Example:
  ```elixir
  LatticeStripe.Batch.run(client, [
    {LatticeStripe.Customer, :retrieve, ["cus_123"]},
    {LatticeStripe.Subscription, :list, [%{customer: "cus_123"}]},
    {LatticeStripe.Invoice, :list, [%{customer: "cus_123"}]}
  ])
  ```
  The `client` is prepended to each tuple's args automatically — callers don't repeat it. MFA tuples are explicit, inspectable, and debuggable. Anonymous function support omitted to keep the API surface minimal and logs meaningful.

### Concurrency Control

- **D-02:** `max_concurrency` is configurable via the second argument's opts: `Batch.run(client, tasks, max_concurrency: 4)`. Default is `System.schedulers_online()` (typically 4-8 on production hardware). This maps directly to `Task.async_stream`'s `:max_concurrency` option.

### Timeout Behavior

- **D-03:** No batch-level timeout. Each task runs through `Client.request/2`, which already applies the three-tier timeout cascade (per-request > `operation_timeouts` > `client.timeout`). `Task.async_stream`'s `:timeout` is set to `:infinity` to avoid double-timeout conflicts — the Client's per-request timeout is the authoritative timeout boundary. If a task times out at the Client level, its slot gets `{:error, %Error{type: :connection_error}}`.

### Result Contract

- **D-04:** `Batch.run/2` returns `{:ok, results}` where `results` is a list of `{:ok, struct} | {:error, %Error{}}` tuples — one per input, order preserved. The batch itself always succeeds; individual calls may fail. A top-level `{:error, reason}` is returned only for argument validation failures (empty task list, invalid MFA format).

  **Per-task error isolation:** Each task body is wrapped in `try/rescue` to catch unexpected exceptions. `{:exit, :timeout}` from `Task.async_stream` is mapped to `{:error, %Error{type: :connection_error, message: "Task timed out"}}`. Linked task crashes do not propagate to the caller.

### Telemetry

- **D-05:** No batch-level telemetry events. Each task already emits `[:lattice_stripe, :request, :start/:stop/:exception]` events individually via the existing request pipeline. Adding batch-level events would duplicate information without adding signal. Users can correlate concurrent requests by timing or by attaching batch metadata via per-request `opts`.

### API Surface

- **D-06:** Single public function `run/2` (with optional opts as third arg via `run/3`). No bang variant — the batch always returns `{:ok, results}`, so there's nothing to bang on. Callers pattern-match individual result tuples.

  **Typespec:**
  ```elixir
  @type task :: {module(), atom(), [term()]}
  @type result :: {:ok, term()} | {:error, Error.t()}

  @spec run(Client.t(), [task()], keyword()) :: {:ok, [result()]} | {:error, Error.t()}
  ```

### Claude's Discretion

- Whether to add an `ordered: false` option for callers who don't need order preservation (could improve throughput)
- Internal module structure — single file or split helpers
- Exact validation logic for MFA tuples (arity checking, module existence, etc.)
- Test organization — unit tests with Mox transport vs integration tests with stripe-mock
- @doc examples — how many usage examples to include

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Infrastructure
- `lib/lattice_stripe/client.ex` — Client struct with timeout cascade, `request/2` entry point
- `lib/lattice_stripe/error.ex` — Error defexception struct, `from_response/3` constructor
- `lib/lattice_stripe/request.ex` — Request struct shape that MFA calls produce

### Prior Phase Decisions
- `.planning/phases/24-rate-limit-awareness-richer-errors/24-CONTEXT.md` — D-01 rate-limit telemetry; D-03 error enrichment (batch errors will carry these)
- `.planning/phases/25-performance-guide-per-op-timeouts-connection-warm-up/25-CONTEXT.md` — D-01..D-04 per-op timeout cascade (batch tasks inherit this)

### Requirements
- `.planning/REQUIREMENTS.md` §DX-02 — "Developer can execute multiple API calls concurrently via a `LatticeStripe.Batch` module using `Task.async_stream` with proper error handling (no linked task crashes)"

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Client.request/2` — the full request pipeline (telemetry, retries, error handling) that each batch task invokes
- `Error` defexception — already handles all Stripe error types + connection errors; batch wraps exits into this
- `Task.async_stream` (Elixir stdlib) — native concurrent stream processing with `max_concurrency` and `:timeout` options

### Established Patterns
- All resource modules follow `def operation(%Client{} = client, ...)` — batch MFA tuples prepend client
- `{:ok, struct} | {:error, %Error{}}` return contract is universal across all resource functions
- No existing concurrency helpers in the codebase — `Batch` is the first

### Integration Points
- `LatticeStripe.Batch` will be a new top-level module alongside `Client`, `Error`, etc.
- ExDoc grouping: belongs in the "Client" group (alongside Client, Config, Request, Response)
- No existing modules need modification — purely additive

</code_context>

<specifics>
## Specific Ideas

- The roadmap explicitly specifies `Task.async_stream` as the concurrency primitive — not `Task.async/await` pairs or GenServer pooling
- Per STATE.md pitfalls: `try/rescue` per task body is mandatory; `{:exit, :timeout}` must map to `{:error, %Error{}}`
- The `@doc` must include a "when to use" note (per success criteria SC-3): fan-out patterns like fetching customer + subscriptions + invoices in parallel; NOT a substitute for Stripe's native batch API

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 27-request-batching*
*Context gathered: 2026-04-16*
