# Phase 25: Performance Guide, Per-Op Timeouts & Connection Warm-Up - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Developers building production SaaS on LatticeStripe get three things: (1) an authoritative `guides/performance.md` covering Finch pool sizing, supervision tree patterns, and throughput guidance, (2) per-operation timeout defaults via `operation_timeouts` in `Client.new!/1` config, and (3) a `LatticeStripe.warm_up/1` function to pre-establish Finch connections on application start.

This phase adds one new Client struct field (`operation_timeouts`), one new public function (`warm_up/1`), and one new guide. It does NOT change the existing default timeout behavior for callers who don't opt in.

</domain>

<decisions>
## Implementation Decisions

### Per-Operation Timeout Design

- **D-01:** Add `operation_timeouts` as a new optional field on the `Client` struct, defaulting to `nil` (no per-op overrides). Type: `%{atom() => pos_integer()} | nil`. When `nil`, all operations use `client.timeout` as today. When set, operations matching a key get that timeout; unmatched operations fall back to `client.timeout`.

  **Key names:** Use Stripe API operation types: `:list`, `:search`, `:create`, `:retrieve`, `:update`, `:delete`. These match the verb names already used in resource module function names (e.g., `Customer.list/2`, `Customer.retrieve/3`).

- **D-02:** Operation type inference from the `%Request{}` struct. Classify by method + path pattern:
  - `GET /v1/{resource}` (no trailing ID) → `:list`
  - `GET /v1/{resource}/search` → `:search`
  - `GET /v1/{resource}/{id}` → `:retrieve`
  - `POST /v1/{resource}` (no trailing ID) → `:create`
  - `POST /v1/{resource}/{id}` → `:update`
  - `DELETE /v1/{resource}/{id}` → `:delete`

  This is a private helper function in `Client` (`classify_operation/1`). It does NOT need to handle every Stripe path perfectly — edge cases (e.g., `/v1/charges/:id/capture`) fall through to the default timeout, which is correct behavior.

- **D-03:** Timeout precedence (highest to lowest):
  1. Per-request `opts[:timeout]` (explicit override on a single call)
  2. `client.operation_timeouts[operation_type]` (per-operation default)
  3. `client.timeout` (global default, 30_000ms)

  This means existing callers who pass `timeout:` in request opts are unaffected. Callers who don't configure `operation_timeouts` are unaffected. Only callers who explicitly set `operation_timeouts` see new behavior.

- **D-04:** NimbleOptions validation for `operation_timeouts` in `Config`:
  ```elixir
  operation_timeouts: [
    type: {:or, [{:map, :atom, :pos_integer}, nil]},
    default: nil,
    doc: "Per-operation timeout overrides in milliseconds. Keys: :list, :search, :create, :retrieve, :update, :delete."
  ]
  ```

### Connection Warm-Up

- **D-05:** `LatticeStripe.warm_up/1` as a top-level public function (not on `Client`). Takes a `%Client{}` struct as its single argument. Returns `{:ok, :warmed}` on success, `{:error, reason}` on failure.

  **Implementation:** Send a lightweight `GET /v1/` request (Stripe returns a 404 with a known JSON body at this path — but the TLS handshake and connection are established, which is the goal). Use `Finch.build(:get, url) |> Finch.request(finch_name, receive_timeout: timeout)` directly through the transport behaviour, not through the full `Client.request/2` pipeline (no retries, no telemetry, no idempotency — this is infrastructure, not an API call).

  **Why not HEAD:** Stripe's API doesn't reliably respond to HEAD for all paths. GET to root is the simplest known-working path that establishes the connection without side effects.

- **D-06:** The warm-up function pre-establishes a single connection per pool. Finch's connection pooling handles scaling from there. The function is synchronous — it blocks until the connection is established or times out.

### Performance Guide

- **D-07:** `guides/performance.md` structure:
  1. **Pool Sizing** — Production Finch pool recommendations (`:size`, `:count`), throughput formulas, when to scale pools
  2. **Supervision Tree** — Complete `Application.start/2` example with Finch child spec and LatticeStripe client initialization
  3. **Per-Operation Timeouts** — Usage of `operation_timeouts`, recommended values, timeout hierarchy diagram
  4. **Connection Warm-Up** — `warm_up/1` usage in `Application.start/2`, what "warm" means (TLS handshake + HTTP/2 connection established), observable behavior (subsequent requests skip handshake latency)
  5. **Benchmarking** — How to measure request latency, throughput benchmarks at different pool sizes
  6. **Common Pitfalls** — Single-pool bottleneck, not warming up, overly aggressive timeouts on list/search

- **D-08:** Add `:performance` to the ExDoc `:groups_for_extras` config in `mix.exs` and place `guides/performance.md` in the Guides group (same pattern as all other guides).

### Claude's Discretion

- Exact Finch pool sizing recommendations (numbers based on research of Finch/Mint internals and common production patterns)
- Whether to include a `warm_up!/1` bang variant
- Exact wording of the guide sections
- Whether `classify_operation/1` should be tested with all Stripe path patterns or just representative ones
- Whether to emit a telemetry event from `warm_up/1` (optional; not in success criteria)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Client & Config
- `lib/lattice_stripe/client.ex` — Client struct (line 52-65), `request/2` timeout resolution (line 177), `do_request_with_retries` retry loop
- `lib/lattice_stripe/config.ex` — NimbleOptions schema (line 31-96), `validate!/1` for adding `operation_timeouts`
- `lib/lattice_stripe/request.ex` — Request struct with `method`, `path`, `params`, `opts`

### Transport Layer
- `lib/lattice_stripe/transport.ex` — Transport behaviour contract
- `lib/lattice_stripe/transport/finch.ex` — Finch adapter, `receive_timeout` passthrough (line 43-47)

### Telemetry & Resource Pattern
- `lib/lattice_stripe/telemetry.ex` — `parse_resource_and_operation/2` (line 534-543) — existing path parser, may inform `classify_operation/1`

### Guides & Docs
- `guides/client-configuration.md` — Existing client setup guide (warm-up section should cross-reference)
- `guides/telemetry.md` — Existing telemetry guide (per-op timeout telemetry if added)
- `guides/api_stability.md` — Semver contract; new field + function = minor bump

### Project Constraints
- `.planning/PROJECT.md` — Core value, design philosophy
- `.planning/REQUIREMENTS.md` — PERF-01, PERF-03, PERF-04

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`parse_resource_and_operation/2`** in Telemetry — already parses resource name from URL path; pattern reusable for `classify_operation/1`
- **`effective_timeout` resolution** in `Client.request/2` (line 177) — the exact insertion point for operation_timeout lookup
- **NimbleOptions schema** in Config — established pattern for adding new client options with validation and docs
- **Transport behaviour** — `warm_up/1` can go through the transport behaviour or call Finch directly (both patterns exist)

### Established Patterns
- **Client struct field addition** — Add field to `defstruct`, add to `@typedoc`, add to NimbleOptions schema, add to `new!/1` pipeline
- **Per-request override pattern** — `Keyword.get(req.opts, :key, client.key)` pattern at line 175-179
- **Guide structure** — All guides follow the same pattern: title, intro paragraph, code examples, cross-references to related guides

### Integration Points
- **`Client.request/2` line 177** — Insert operation timeout resolution between per-request opts and client default
- **`Config` schema** — Add `operation_timeouts` option
- **`LatticeStripe` top-level module** — Add `warm_up/1` delegate
- **`mix.exs` ExDoc config** — Add `guides/performance.md` to extras

</code_context>

<specifics>
## Specific Ideas

- The success criteria specifies `operation_timeouts: %{list: 60_000, search: 45_000}` as the example config — use this exact format in docs and tests
- `warm_up/1` must return `{:ok, :warmed}` specifically (not `{:ok, %Response{}}` or other)
- The performance guide should be production-oriented: real numbers, real supervision trees, not toy examples
- `nil` default for `operation_timeouts` ensures zero behavior change for existing callers — this is critical for semver compliance

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 25-performance-guide-per-op-timeouts-connection-warm-up*
*Context gathered: 2026-04-16 via --auto mode*
