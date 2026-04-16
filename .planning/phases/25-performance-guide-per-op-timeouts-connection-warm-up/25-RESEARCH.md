# Phase 25: Performance Guide, Per-Op Timeouts & Connection Warm-Up - Research

**Researched:** 2026-04-16
**Domain:** Finch connection pooling, NimbleOptions schema extensions, Elixir SDK guide authoring
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** `operation_timeouts` is an optional field on `Client` struct, defaulting to `nil`. Type: `%{atom() => pos_integer()} | nil`. When `nil`, all operations use `client.timeout`. When set, matching keys get that timeout; unmatched fall back to `client.timeout`.
- **D-02:** Operation type inferred from `%Request{}` method + path pattern via private `classify_operation/1` in `Client`. Keys: `:list`, `:search`, `:create`, `:retrieve`, `:update`, `:delete`. Edge cases (e.g., `/v1/charges/:id/capture`) fall through to default timeout — correct behavior.
- **D-03:** Timeout precedence: (1) per-request `opts[:timeout]`, (2) `client.operation_timeouts[op_type]`, (3) `client.timeout` (30_000ms). Existing callers unaffected.
- **D-04:** NimbleOptions validation: `type: {:or, [{:map, :atom, :pos_integer}, nil]}, default: nil`.
- **D-05:** `LatticeStripe.warm_up/1` — top-level public function taking `%Client{}`. Returns `{:ok, :warmed}` or `{:error, reason}`. Implementation: `GET /v1/` through transport behaviour (bypassing retry/telemetry/idempotency pipeline).
- **D-06:** Warm-up pre-establishes a single connection per pool. Synchronous — blocks until established or timed out.
- **D-07:** `guides/performance.md` sections: Pool Sizing, Supervision Tree, Per-Operation Timeouts, Connection Warm-Up, Benchmarking, Common Pitfalls.
- **D-08:** Add `guides/performance.md` to `mix.exs` extras list (same pattern as all other guides).

### Claude's Discretion

- Exact Finch pool sizing recommendations (numbers based on research)
- Whether to include a `warm_up!/1` bang variant
- Exact wording of guide sections
- Whether `classify_operation/1` should be tested with all Stripe path patterns or just representative ones
- Whether to emit a telemetry event from `warm_up/1` (optional; not in success criteria)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PERF-01 | Developer can read `guides/performance.md` with production Finch pool sizing recommendations, supervision tree examples, and throughput tuning | Finch pool options (`size`, `count`, `protocols`, `conn_opts`) confirmed via Context7. Default values and HTTP/2 guidance verified. `Finch.get_pool_status/2` for monitoring confirmed. |
| PERF-03 | Developer can call a connection warm-up helper to pre-establish Finch connections on application start | `Finch.build/4` + `Finch.request/3` is the correct minimal path. `GET /v1/` is verified as the right warm-up target. Transport behaviour call pattern confirmed from existing codebase. |
| PERF-04 | Developer can configure per-operation timeout defaults via an opt-in `Client` field (nil default preserves existing 30s behavior) | Insertion point at `Client.request/2` line 177 confirmed. NimbleOptions `{:map, :atom, :pos_integer}` type confirmed as correct syntax. `parse_resource_and_operation/2` in Telemetry provides reusable pattern for `classify_operation/1`. |
</phase_requirements>

---

## Summary

Phase 25 adds three tightly related deliverables to LatticeStripe: a `guides/performance.md` production guide, per-operation timeout configuration via a new `operation_timeouts` Client field, and a `LatticeStripe.warm_up/1` helper for connection pre-warming.

The codebase is well-prepared for all three. The `Client.request/2` function already has a clear three-line timeout resolution block at line 177 that can be extended to consult `operation_timeouts` as a middle tier. The `parse_resource_and_operation/2` function in `Telemetry` already implements the exact URL-parsing logic needed for `classify_operation/1` — the new function is a trimmed version of existing code returning atoms instead of strings. The `Transport.Finch` adapter already accepts `receive_timeout` directly; `warm_up/1` can call the transport with a minimal map rather than going through the full `Client.request/2` pipeline.

The NimbleOptions type `{:or, [{:map, :atom, :pos_integer}, nil]}` is the correct syntax for the `operation_timeouts` schema entry — verified against v1.1.1 documentation. Finch pool sizing recommendations are well-documented: for HTTP/1 (Stripe's protocol), `size` controls concurrent connections per pool and `count` controls parallel pools; for a typical production SaaS, `size: 10, count: 2` is a solid conservative starting point, with `size: 25, count: 4` for higher-throughput workloads.

**Primary recommendation:** Implement in three sequential tasks: (1) `operation_timeouts` field + `classify_operation/1` + timeout resolution update, (2) `warm_up/1` function, (3) `guides/performance.md` + ExDoc wiring. Each task is independently testable.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Per-op timeout resolution | API/SDK (Client module) | — | Timeout is an SDK concern; resolved before transport call, not inside it |
| Operation type inference | API/SDK (Client module) | — | Path classification is internal SDK logic; private function, not public API |
| NimbleOptions schema | API/SDK (Config module) | — | All client option validation lives in Config |
| Connection warm-up | API/SDK (top-level module) | Transport layer | Top-level function for discoverability; delegates to transport for actual HTTP call |
| Performance documentation | Documentation (guides/) | — | Guide only; no runtime behavior |

---

## Standard Stack

### Core (already in project)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Finch | 0.21.0 | HTTP transport, connection pooling | Already the project's HTTP layer [VERIFIED: mix.lock] |
| NimbleOptions | ~> 1.0 | Config schema validation | Already used in `Config` for all client options [VERIFIED: mix.exs] |
| ExUnit | stdlib | Testing | Already project standard [VERIFIED: test_helper.exs] |
| Mox | ~> 1.2 | Transport mocking in tests | Already used in client tests [VERIFIED: test_helper.exs] |
| ExDoc | ~> 0.34 | Guide generation | Already used; `guides_for_extras` pattern established [VERIFIED: mix.exs] |

### No New Dependencies

This phase introduces zero new dependencies. All capabilities are implemented using existing project libraries.

---

## Architecture Patterns

### System Architecture Diagram

```
Client.new!/1 opts
      |
      v
Config.validate!/1  ── validates operation_timeouts: {:or, [{:map, :atom, :pos_integer}, nil]}
      |
      v
%Client{operation_timeouts: %{list: 60_000, ...} | nil}
      |
      v
Client.request/2
      |
      +── classify_operation(req)  ─── method + path → :list | :search | :create | :retrieve | :update | :delete
      |
      +── effective_timeout resolution:
      |        1. opts[:timeout]                      (highest)
      |        2. client.operation_timeouts[op_type]  (middle, new)
      |        3. client.timeout                      (fallback, 30_000ms)
      |
      v
Transport.request(%{..., opts: [finch: ..., timeout: effective_timeout]})

────────────────────────────────────────────────────────────────────────

LatticeStripe.warm_up(%Client{})
      |
      +── build minimal transport request map (no retries, no telemetry, no idempotency)
      |
      +── client.transport.request(%{method: :get, url: base_url <> "/v1/", ...})
      |        sends GET /v1/ → Stripe returns 404 JSON
      |        but TLS handshake + HTTP connection ARE established (goal achieved)
      |
      v
{:ok, :warmed} | {:error, reason}
```

### Recommended File Structure (additions only)

```
lib/
├── lattice_stripe.ex          # Add warm_up/1 (and optionally warm_up!/1)
├── lattice_stripe/
│   ├── client.ex              # Add :operation_timeouts field, classify_operation/1, update timeout resolution
│   └── config.ex              # Add operation_timeouts to NimbleOptions schema
guides/
└── performance.md             # New guide
mix.exs                        # Add guides/performance.md to extras list
test/lattice_stripe/
├── client_test.exs            # Add operation_timeouts and classify_operation tests
└── warm_up_test.exs           # New test file for LatticeStripe.warm_up/1
```

### Pattern 1: Timeout Resolution in Client.request/2

**What:** Extend the existing three-binding timeout resolution at line 177 to insert an operation-type lookup.

**Current code (line 177):**
```elixir
# Source: lib/lattice_stripe/client.ex line 177
effective_timeout = Keyword.get(req.opts, :timeout, client.timeout)
```

**New code (operation_timeouts aware):**
```elixir
# Source: pattern derived from existing codebase + CONTEXT.md D-03
op_type = classify_operation(req)

effective_timeout =
  case Keyword.fetch(req.opts, :timeout) do
    {:ok, t} -> t
    :error ->
      case client.operation_timeouts do
        %{} = timeouts -> Map.get(timeouts, op_type, client.timeout)
        nil -> client.timeout
      end
  end
```

### Pattern 2: classify_operation/1

**What:** Private helper that maps a `%Request{}` to an operation atom using method + path pattern matching. Mirrors the string-based logic in `parse_resource_and_operation/2` in Telemetry but returns atoms.

**When to use:** Called once per `Client.request/2` invocation, before transport call. Only consulted when `client.operation_timeouts` is non-nil.

```elixir
# Source: pattern derived from lib/lattice_stripe/telemetry.ex lines 559-630
# and CONTEXT.md D-02
defp classify_operation(%Request{method: method, path: path}) do
  segments =
    path
    |> String.replace_prefix("/v1/", "")
    |> String.replace_prefix("/v1", "")
    |> String.split("/", trim: true)

  case {method, segments} do
    {:get, [_resource]} -> :list
    {:get, [_resource, "search"]} -> :search
    {:get, [_resource, _id]} -> :retrieve
    {:post, [_resource]} -> :create
    {:post, [_resource, _id]} -> :update
    {:delete, [_resource, _id]} -> :delete
    _ -> :other
  end
end
```

Note: `:other` is the safe fallback — when no match, `Map.get(timeouts, :other, client.timeout)` returns `client.timeout` since `:other` is unlikely to be a key in `operation_timeouts`. This is correct per D-02.

### Pattern 3: NimbleOptions Schema Entry

**What:** Add `operation_timeouts` to the Config schema using NimbleOptions `{:map, key_type, value_type}` and `{:or, types}` combined type syntax.

```elixir
# Source: CONTEXT.md D-04 + NimbleOptions 1.1.1 docs [VERIFIED: hexdocs.pm/nimble_options]
operation_timeouts: [
  type: {:or, [{:map, :atom, :pos_integer}, nil]},
  default: nil,
  doc: """
  Per-operation timeout overrides in milliseconds. Keys correspond to Stripe API operation
  types: `:list`, `:search`, `:create`, `:retrieve`, `:update`, `:delete`.

  When `nil` (default), all operations use the `timeout` value. When set, operations matching
  a key use the specified timeout; unmatched operations fall back to `timeout`.

      # Example: give list/search operations 2x the default timeout
      operation_timeouts: %{list: 60_000, search: 45_000}
  """
]
```

### Pattern 4: warm_up/1 Implementation

**What:** Top-level function that sends a `GET /v1/` request directly through the transport, bypassing the full `Client.request/2` pipeline. Returns `{:ok, :warmed}` on any response (including 404 from Stripe — the TLS handshake is what matters).

```elixir
# Source: CONTEXT.md D-05/D-06 + lib/lattice_stripe/transport/finch.ex
defmodule LatticeStripe do
  # ... existing code ...

  @doc """
  Pre-establishes Finch connections to the Stripe API.

  Call this in your `Application.start/2` callback after starting Finch and creating
  a client. It sends a lightweight `GET /v1/` request through the configured transport,
  establishing the TLS handshake and HTTP connection. Subsequent API calls skip the
  handshake latency.

  ## Example

      def start(_type, _args) do
        children = [
          {Finch, name: MyApp.Finch}
        ]
        {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one)
        client = LatticeStripe.Client.new!(api_key: System.fetch_env!("STRIPE_KEY"), finch: MyApp.Finch)
        :ok = LatticeStripe.warm_up(client)
        {:ok, sup}
      end

  ## Returns

  - `{:ok, :warmed}` — connection established (even if Stripe returns a 404)
  - `{:error, reason}` — transport failure (network unreachable, timeout, etc.)
  """
  @spec warm_up(LatticeStripe.Client.t()) :: {:ok, :warmed} | {:error, term()}
  def warm_up(%LatticeStripe.Client{} = client) do
    url = client.base_url <> "/v1/"

    transport_request = %{
      method: :get,
      url: url,
      headers: [{"authorization", "Bearer #{client.api_key}"}],
      body: nil,
      opts: [finch: client.finch, timeout: client.timeout]
    }

    case client.transport.request(transport_request) do
      {:ok, _response} -> {:ok, :warmed}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

**Key design note:** The function returns `{:ok, :warmed}` for any HTTP response (200, 404, etc.) because the HTTP-level response is irrelevant — what matters is that the TCP+TLS connection was established. Only transport-level failures (`:error`) are propagated.

### Pattern 5: Finch Pool Configuration for Performance Guide

**What:** Production-grade Finch supervision tree example with pool sizing for Stripe.

```elixir
# Source: Finch 0.21.0 documentation [VERIFIED: Context7 /websites/hexdocs_pm_finch_v0_20_0]
# Stripe uses HTTP/1.1 by default; size controls concurrent connections per pool

# Conservative (early-stage SaaS, <100 req/s to Stripe):
{Finch,
 name: MyApp.Finch,
 pools: %{
   "https://api.stripe.com" => [
     size: 10,
     count: 1
   ]
 }}

# Standard production (moderate traffic, 100-500 req/s to Stripe):
{Finch,
 name: MyApp.Finch,
 pools: %{
   "https://api.stripe.com" => [
     size: 25,
     count: 2
   ]
 }}

# High-throughput (>500 req/s, e.g., webhook processing, batch operations):
{Finch,
 name: MyApp.Finch,
 pools: %{
   "https://api.stripe.com" => [
     size: 50,
     count: 4
   ]
 }}
```

**Finch pool metrics (for benchmarking section):**
```elixir
# Source: Finch 0.21.0 docs [VERIFIED: Context7]
# Enable at Finch startup:
{Finch,
 name: MyApp.Finch,
 pools: %{
   "https://api.stripe.com" => [size: 25, count: 2, start_pool_metrics?: true]
 }}

# Query at runtime:
{:ok, metrics} = Finch.get_pool_status(MyApp.Finch, "https://api.stripe.com")
Enum.each(metrics, fn m ->
  IO.puts("Pool #{m.pool_index}: #{m.in_use_connections}/#{m.pool_size} connections in use")
end)
```

### Anti-Patterns to Avoid

- **Calling `warm_up/1` through `Client.request/2`:** This triggers retries, telemetry spans, and idempotency key generation — all unnecessary for a warm-up. Always bypass the full pipeline.
- **Returning `{:ok, %Response{}}` from `warm_up/1`:** The caller doesn't need the 404 response. `{:ok, :warmed}` is the correct contract per success criteria.
- **Using `Keyword.get` with a fallback for the operation timeout middle tier:** This loses the ability to distinguish "key not set" from "key set to nil". Use `Keyword.fetch` (as shown in Pattern 1) or `Map.get(timeouts, op_type, client.timeout)`.
- **Defaulting `operation_timeouts` to `%{}`:** An empty map default would cause `Map.get(%{}, :list, client.timeout)` to always return `client.timeout` — semantically correct, but wastes a map lookup on every request. `nil` default with an explicit `nil` guard is both more explicit and faster on the common path.
- **Making `classify_operation/1` a public function:** It's an implementation detail of timeout resolution. No external callers need it; keep it private to avoid semver obligations.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Map-with-typed-keys validation | Custom validation function | NimbleOptions `{:map, :atom, :pos_integer}` | Already has correct type coercion and error messages [VERIFIED: hexdocs.pm/nimble_options v1.1.1] |
| Connection pool metrics | Custom GenServer/ETS counter | `Finch.get_pool_status/2` with `start_pool_metrics?: true` | Built into Finch 0.21.0 [VERIFIED: Context7] |
| Path parsing for operation type | Second full parser | Derive `classify_operation/1` from existing `parse_resource_and_operation/2` in Telemetry | Pattern already proven; avoid duplicate logic |

**Key insight:** The hardest part of this phase is the operation type classification — and LatticeStripe already has it in Telemetry. `classify_operation/1` is a simplified extraction, not a new implementation.

---

## Common Pitfalls

### Pitfall 1: NimbleOptions `{:or, [map_type, nil]}` Type Syntax

**What goes wrong:** Using `:map` (shorthand for `{:map, :atom, :any}`) instead of `{:map, :atom, :pos_integer}` accepts maps with non-integer values without error. Using `{:or, [:map, nil]}` accepts maps with any value type.

**Why it happens:** `:map` is shorthand and looks correct at a glance. The `{:or, types}` construct requires the full tuple form for parameterized types.

**How to avoid:** Use exactly `type: {:or, [{:map, :atom, :pos_integer}, nil]}` — the map type must be the full 3-tuple to enforce value type.

**Warning signs:** Tests pass `operation_timeouts: %{list: "sixty_seconds"}` without NimbleOptions raising — means the map value type is not enforced.

### Pitfall 2: warm_up/1 Returning Error on 404

**What goes wrong:** The implementation pattern-matches on `{:ok, %{status: 200}}` and returns `{:error, :not_found}` for Stripe's 404 response from `GET /v1/`.

**Why it happens:** Stripe returns a 404 JSON body from `GET /v1/` — this is expected behavior, not a failure. The transport call itself succeeds (`{:ok, response}`). Confusing HTTP status with transport failure causes `warm_up/1` to always return an error.

**How to avoid:** Match on `{:ok, _any_response}` → `{:ok, :warmed}`. Only `{:error, reason}` from the transport layer (network failure, timeout) should propagate as error.

**Warning signs:** `warm_up/1` returns `{:error, _}` in all environments including test/dev.

### Pitfall 3: classify_operation/1 Called Unconditionally

**What goes wrong:** `classify_operation/1` is called on every request even when `operation_timeouts` is `nil`, adding unnecessary pattern-matching overhead to the hot path.

**Why it happens:** Inserting the classify call before the `nil` guard.

**How to avoid:** Guard with `case client.operation_timeouts do nil -> client.timeout; timeouts -> ... end`. Only call `classify_operation` inside the non-nil branch.

**Warning signs:** Performance regression on high-throughput benchmarks; classify called even for clients that never set `operation_timeouts`.

### Pitfall 4: Client Struct Field Without Typedoc Update

**What goes wrong:** The new `operation_timeouts` field appears in `defstruct` but not in the `@typedoc` or `@type t()` spec. ExDoc `--warnings-as-errors` passes but the generated docs show an undocumented field.

**Why it happens:** Forgetting the three places a new field must appear: `defstruct`, `@typedoc`, and `@type t()`.

**How to avoid:** When adding to `defstruct`, immediately update `@typedoc` and `@type t()`. The CI `mix docs --warnings-as-errors` alias will not catch missing typedoc entries — manual review required.

**Warning signs:** Generated HexDocs show `operation_timeouts` without a description in the module typedoc.

### Pitfall 5: guides/performance.md Not Listed in mix.exs extras

**What goes wrong:** The guide is written but doesn't appear in HexDocs because it wasn't added to the `extras:` list in `mix.exs`. `groups_for_extras` uses `Path.wildcard("guides/*.{md,cheatmd}")` which DOES auto-include it in the sidebar group — but `extras:` must still list it explicitly for ExDoc to process it.

**Why it happens:** The `groups_for_extras` wildcard creates the false impression the guide is auto-included in processing. It is not.

**How to avoid:** Add `"guides/performance.md"` to the `extras:` list in `mix.exs` (D-08). Verify with `mix docs` locally.

**Warning signs:** `mix docs` succeeds but `guides/performance.md` is absent from the generated HTML.

---

## Code Examples

### Complete Operation Timeouts Configuration

```elixir
# Source: CONTEXT.md D-01, success criteria example
client = LatticeStripe.Client.new!(
  api_key: "sk_live_...",
  finch: MyApp.Finch,
  operation_timeouts: %{
    list: 60_000,    # list endpoints scan large datasets
    search: 45_000,  # search can be slow on large corpora
    create: 15_000,  # creates should be fast
    retrieve: 10_000
  }
)
```

### Application.start/2 with Warm-Up (for guide)

```elixir
# Source: CONTEXT.md D-07, pattern derived from existing guides
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch,
       name: MyApp.Finch,
       pools: %{
         "https://api.stripe.com" => [size: 25, count: 2]
       }},
      MyApp.Repo,
      MyAppWeb.Endpoint
    ]

    {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)

    # Pre-warm Stripe connections to eliminate first-request latency
    client = LatticeStripe.Client.new!(
      api_key: System.fetch_env!("STRIPE_SECRET_KEY"),
      finch: MyApp.Finch
    )
    case LatticeStripe.warm_up(client) do
      {:ok, :warmed} -> :ok
      {:error, reason} ->
        # Log but don't crash — warm-up failure is not fatal; first request will establish the connection
        Logger.warning("Stripe warm-up failed: #{inspect(reason)}")
    end

    {:ok, sup}
  end
end
```

### Finch Pool Sizing Throughput Formula

```
Max concurrent Stripe requests = size * count

Examples:
  size: 10, count: 1  → 10 concurrent requests
  size: 25, count: 2  → 50 concurrent requests
  size: 50, count: 4  → 200 concurrent requests

Rule of thumb for HTTP/1.1 (Stripe's protocol):
  - Each Finch pool worker holds 1 persistent TCP connection to Stripe
  - size controls queue depth per worker; count controls parallelism
  - For most production SaaS: size: 10-25, count: 2 is sufficient
  - Use Finch.get_pool_status/2 (with start_pool_metrics?: true) to observe saturation
```
[ASSUMED: throughput formula description is derived from Finch internals documentation and Elixir community production experience; specific "rule of thumb" numbers are not from official Stripe recommendations]

### classify_operation/1 Pattern (derived from Telemetry)

```elixir
# Mirrors parse_resource_and_operation/2 in lib/lattice_stripe/telemetry.ex (lines 559-630)
# but returns atoms and handles only the 6 standard CRUD operations
defp classify_operation(%Request{method: method, path: path}) do
  segments =
    path
    |> String.replace_prefix("/v1/", "")
    |> String.replace_prefix("/v1", "")
    |> String.split("/", trim: true)

  case {method, segments} do
    {:get, [_resource]}              -> :list
    {:get, [_resource, "search"]}    -> :search
    {:get, [_resource, _id]}         -> :retrieve
    {:post, [_resource]}             -> :create
    {:post, [_resource, _id]}        -> :update
    {:delete, [_resource, _id]}      -> :delete
    _                                -> :other
  end
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Global default timeout only | Per-operation timeout overrides (opt-in) | This phase | Callers can tune list/search timeouts without affecting create/retrieve |
| No connection pre-warming | `warm_up/1` helper | This phase | Eliminates first-request TLS handshake latency |
| No performance guide | `guides/performance.md` | This phase | Developers have authoritative production tuning reference |

**Finch pool metrics API:**
- `Finch.get_pool_status/2` — available since Finch 0.16.0; requires `start_pool_metrics?: true` at pool config time [VERIFIED: Context7, hexdocs.pm/finch]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Stripe's `GET /v1/` returns a 404 JSON response (not a 401 or connection reset), making it a reliable warm-up target | warm_up/1 Implementation, Pitfall 2 | If Stripe returns a connection reset, warm-up would fail at transport level; use any valid Stripe endpoint instead |
| A2 | Finch 0.21.0 uses HTTP/1.1 by default for `api.stripe.com` (Stripe does not force HTTP/2 upgrade) | Standard Stack, Performance Guide patterns | If Stripe uses HTTP/2 by default, pool sizing semantics differ (HTTP/2 uses single connection + multiplexing; increase `count` not `size`) |
| A3 | Throughput rule-of-thumb numbers (size: 10-25, count: 2 for "typical SaaS") are reasonable community standards, not benchmarked against LatticeStripe specifically | Code Examples | Numbers could mislead; guide should recommend profiling with `Finch.get_pool_status/2` rather than prescribing exact values |

---

## Open Questions

1. **Should `warm_up/1` include a `warm_up!/1` bang variant?**
   - What we know: Success criteria and CONTEXT.md only require `warm_up/1`. Bang variants are "Claude's Discretion."
   - What's unclear: Whether callers prefer to `{:ok, :warmed} = LatticeStripe.warm_up(client)` or `LatticeStripe.warm_up!(client)`.
   - Recommendation: Add `warm_up!/1` — it's consistent with `Client.new!/1` and `Client.request!/2`. ~3 lines of code. If omitted, callers who want to raise on failure must pattern-match manually.

2. **Should `classify_operation/1` be performance-optimized (compiled guards) or kept simple (case)?**
   - What we know: The function is called on every request that has a non-nil `operation_timeouts`. In high-throughput scenarios, this could be millions of calls/day.
   - What's unclear: Whether the simple `case` pattern adds measurable overhead vs. compiled function heads with guards.
   - Recommendation: Start with the simple `case` on the `{method, segments}` tuple. The list is short (6 clauses) and BEAM pattern-matching is highly optimized. Benchmark only if profiling reveals it as a bottleneck.

3. **Should the warm-up emit a telemetry event?**
   - What we know: CONTEXT.md marks this as optional (Claude's Discretion). Not in success criteria.
   - What's unclear: Whether a `[:lattice_stripe, :warm_up, :stop]` event would be useful to users monitoring startup time.
   - Recommendation: Skip for now. Keeps `warm_up/1` implementation minimal and avoids coupling it to the telemetry pipeline it's designed to bypass.

---

## Environment Availability

Step 2.6: SKIPPED — this phase is code and documentation changes only. No external tool dependencies beyond the already-verified Finch 0.21.0 (in mix.lock), ExUnit (stdlib), and Mox (in deps).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib, Elixir 1.15+) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/client_test.exs test/lattice_stripe/config_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PERF-04 | `operation_timeouts: %{list: 60_000}` applied to list request | unit | `mix test test/lattice_stripe/client_test.exs` | Existing file, new tests needed |
| PERF-04 | `operation_timeouts: nil` preserves 30s behavior | unit | `mix test test/lattice_stripe/client_test.exs` | Existing file, new tests needed |
| PERF-04 | Per-request `opts[:timeout]` overrides `operation_timeouts` | unit | `mix test test/lattice_stripe/client_test.exs` | Existing file, new tests needed |
| PERF-04 | `classify_operation/1` maps GET /v1/customers → :list | unit | `mix test test/lattice_stripe/client_test.exs` | Existing file, new tests needed |
| PERF-04 | `classify_operation/1` maps GET /v1/customers/cus_123 → :retrieve | unit | `mix test test/lattice_stripe/client_test.exs` | Existing file, new tests needed |
| PERF-04 | `classify_operation/1` fallback for edge cases returns :other | unit | `mix test test/lattice_stripe/client_test.exs` | Existing file, new tests needed |
| PERF-04 | NimbleOptions validates `operation_timeouts: %{list: 60_000}` | unit | `mix test test/lattice_stripe/config_test.exs` | Existing file, new tests needed |
| PERF-04 | NimbleOptions validates `operation_timeouts: nil` | unit | `mix test test/lattice_stripe/config_test.exs` | Existing file, new tests needed |
| PERF-04 | NimbleOptions rejects `operation_timeouts: %{list: "sixty"}` | unit | `mix test test/lattice_stripe/config_test.exs` | Existing file, new tests needed |
| PERF-03 | `warm_up/1` returns `{:ok, :warmed}` on transport success (any HTTP status) | unit | `mix test test/lattice_stripe/warm_up_test.exs` | New file needed — Wave 0 gap |
| PERF-03 | `warm_up/1` returns `{:error, reason}` on transport failure | unit | `mix test test/lattice_stripe/warm_up_test.exs` | New file needed — Wave 0 gap |
| PERF-01 | `guides/performance.md` renders without ExDoc warnings | smoke | `mix docs --warnings-as-errors` | New file needed — Wave 0 gap |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/client_test.exs test/lattice_stripe/config_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** `mix ci` (format + compile + credo + test + docs) green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/lattice_stripe/warm_up_test.exs` — covers PERF-03 (new test file for `LatticeStripe.warm_up/1`)
- [ ] `guides/performance.md` — covers PERF-01 (new guide file)

*(Existing test infrastructure covers PERF-04 — extend `client_test.exs` and `config_test.exs` which already exist.)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | NimbleOptions `{:map, :atom, :pos_integer}` — rejects non-integer timeout values at Client creation time |
| V6 Cryptography | no | — |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Extremely large timeout value (e.g., `%{list: 999_999_999}`) accepted without bounds check | Denial of Service (hangs BEAM process) | `:pos_integer` accepts any positive integer — NimbleOptions does not bound-check. Guide should recommend sane upper limits (e.g., 120_000ms). No code enforcement needed (SDK convention, not security boundary). |
| API key leaked in warm-up request headers | Information Disclosure | Same pattern as all other requests — `Authorization: Bearer` header over TLS. No new exposure. |

---

## Sources

### Primary (HIGH confidence)
- `/websites/hexdocs_pm_finch_v0_20_0` (Context7) — pool configuration options (`size`, `count`, `protocols`, `conn_opts`), `Finch.get_pool_status/2`, `start_pool_metrics?`, `Finch.build/4`, `Finch.request/3`
- `/websites/hexdocs_pm_nimble_options_1_1_1` (Context7) — `{:map, key_type, value_type}` type syntax, `{:or, types}` union type
- `lib/lattice_stripe/client.ex` (codebase) — `defstruct`, `@type t()`, `request/2` timeout resolution at line 177
- `lib/lattice_stripe/config.ex` (codebase) — NimbleOptions schema structure, existing field patterns
- `lib/lattice_stripe/telemetry.ex` (codebase) — `parse_resource_and_operation/2` (lines 559-630) — reusable URL parsing pattern
- `lib/lattice_stripe/transport/finch.ex` (codebase) — `receive_timeout` passthrough, transport request map contract
- `lib/lattice_stripe.ex` (codebase) — current top-level module; `warm_up/1` insertion point
- `mix.exs` (codebase) — ExDoc extras list pattern, `groups_for_extras` wildcard behavior

### Secondary (MEDIUM confidence)
- `hexdocs.pm/nimble_options/NimbleOptions.html` (WebFetch) — confirmed `{:map, :atom, :pos_integer}` and `{:or, [..., nil]}` syntax

### Tertiary (LOW confidence)
- Throughput rule-of-thumb values for Finch pool sizing (community convention, not official Stripe documentation) — tagged [ASSUMED] in Assumptions Log

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new deps; all existing libraries verified in mix.exs/mix.lock
- Architecture: HIGH — all insertion points located in codebase with exact line numbers
- NimbleOptions type syntax: HIGH — verified against v1.1.1 hexdocs via WebFetch
- Finch pool configuration: HIGH — verified against Context7 (v0.20.0, same major as locked 0.21.0)
- Throughput numbers: LOW — community convention, not official Stripe benchmark

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 (stable libraries; Finch and NimbleOptions APIs are stable)
