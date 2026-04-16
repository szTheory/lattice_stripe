---
phase: 25-performance-guide-per-op-timeouts-connection-warm-up
plan: "01"
subsystem: client-configuration
tags: [performance, timeouts, config, client]
dependency_graph:
  requires: []
  provides: [operation_timeouts_config, classify_operation, three_tier_timeout_resolution]
  affects: [lib/lattice_stripe/config.ex, lib/lattice_stripe/client.ex]
tech_stack:
  added: []
  patterns: [three-tier-timeout-precedence, NimbleOptions-map-type-validation]
key_files:
  created: []
  modified:
    - lib/lattice_stripe/config.ex
    - lib/lattice_stripe/client.ex
    - test/lattice_stripe/config_test.exs
    - test/lattice_stripe/client_test.exs
decisions:
  - "Three-tier timeout precedence: per-request opts[:timeout] > operation_timeouts map > client.timeout"
  - "classify_operation/1 only called when operation_timeouts is non-nil (hot path optimization)"
  - "NimbleOptions {:map, :atom, :pos_integer} rejects string keys, string values, zero, and negatives"
  - "operation_timeouts: nil default preserves exact existing 30s behavior with zero extra work"
metrics:
  duration_minutes: 10
  completed_date: "2026-04-16"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 4
requirements: [PERF-04]
---

# Phase 25 Plan 01: Per-Operation Timeouts Summary

Per-operation timeout configuration added to LatticeStripe Client: NimbleOptions-validated map from operation atom to millisecond integer, with a three-tier resolution cascade and zero overhead when unused.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add operation_timeouts to Config schema and Client struct | 3972547 | config.ex, client.ex, config_test.exs |
| 2 | Implement classify_operation/1 and three-tier timeout resolution | 288b1a0 | client.ex, client_test.exs |

## What Was Built

### Config Schema (lib/lattice_stripe/config.ex)

Added `operation_timeouts` NimbleOptions entry immediately after the `timeout` entry:

```elixir
operation_timeouts: [
  type: {:or, [{:map, :atom, :pos_integer}, nil]},
  default: nil,
  doc: "..."
]
```

NimbleOptions validates: atom keys only, pos_integer values only (rejects 0, negatives, strings).

### Client Struct (lib/lattice_stripe/client.ex)

- Added `operation_timeouts: nil` field to `defstruct` (after `timeout: 30_000`)
- Added `operation_timeouts: %{atom() => pos_integer()} | nil` to `@type t()`
- Added typedoc bullet for `operation_timeouts`

### classify_operation/1 Private Function

Segments the request path and dispatches on `{method, segments}`:

```elixir
{:get, [_resource]}           -> :list
{:get, [_resource, "search"]} -> :search
{:get, [_resource, _id]}      -> :retrieve
{:post, [_resource]}          -> :create
{:post, [_resource, _id]}     -> :update
{:delete, [_resource, _id]}   -> :delete
_                             -> :other
```

Only invoked inside the `%{} = timeouts` branch — never when `operation_timeouts` is `nil`.

### Three-Tier Timeout Resolution

Replaced single `Keyword.get` with `Keyword.fetch` cascade:

1. `req.opts[:timeout]` present → use it (per-request override)
2. `client.operation_timeouts` is `%{}` → classify operation, look up atom key, fall back to `client.timeout`
3. `client.operation_timeouts` is `nil` → use `client.timeout` (zero extra work)

## Tests Added

**Config tests (8 new):** nil default, valid map, explicit nil, empty map, rejects string values, rejects string keys, rejects zero, rejects negative.

**Client tests (7 new):** nil passes through to client.timeout, list uses override, retrieve falls back, per-request wins over operation_timeouts, search classified, create classified, edge-case :other path falls back.

## Verification

```
mix test test/lattice_stripe/client_test.exs test/lattice_stripe/config_test.exs
# => 79 tests, 0 failures

mix compile --warnings-as-errors
# => Generated lattice_stripe app (clean)
```

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, or trust boundaries introduced. NimbleOptions validation (T-25-01 mitigation) implemented as specified.

## Self-Check: PASSED

- lib/lattice_stripe/config.ex — FOUND (operation_timeouts schema entry)
- lib/lattice_stripe/client.ex — FOUND (struct field, typedoc, @type t, classify_operation/1, Keyword.fetch cascade)
- test/lattice_stripe/config_test.exs — FOUND (8 new validation tests)
- test/lattice_stripe/client_test.exs — FOUND (7 new timeout tests)
- Commit 3972547 — FOUND
- Commit 288b1a0 — FOUND
