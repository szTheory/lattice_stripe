---
phase: 25-performance-guide-per-op-timeouts-connection-warm-up
plan: "02"
subsystem: core-api
tags: [warm-up, connection, transport, performance]
dependency_graph:
  requires: []
  provides: [LatticeStripe.warm_up/1, LatticeStripe.warm_up!/1]
  affects: [lib/lattice_stripe.ex]
tech_stack:
  added: []
  patterns: [direct-transport-call, bang-variant]
key_files:
  created:
    - test/lattice_stripe/warm_up_test.exs
  modified:
    - lib/lattice_stripe.ex
decisions:
  - "warm_up/1 matches {:ok, _response} (not {:ok, %{status: 200}}) so any HTTP response, including Stripe's expected 404 from GET /v1/, returns {:ok, :warmed}"
  - "warm_up/1 calls transport directly, bypassing Client.request/2 retry/telemetry/idempotency pipeline"
  - "warm_up!/1 raises RuntimeError (not LatticeStripe.Error) since there's no Stripe API error to parse"
metrics:
  duration: "~8 minutes"
  completed: "2026-04-16"
  tasks_completed: 2
  files_changed: 2
---

# Phase 25 Plan 02: Connection Warm-Up Summary

**One-liner:** Added `LatticeStripe.warm_up/1` and `warm_up!/1` for pre-establishing TLS connections to Stripe at application startup, bypassing the retry/telemetry pipeline with a direct transport call.

## What Was Built

Two new public functions in the top-level `LatticeStripe` module:

- **`warm_up/1`** — sends `GET /v1/` directly through the configured transport. Returns `{:ok, :warmed}` on any HTTP response (200 or 404) since the TLS handshake is what matters. Returns `{:error, reason}` only on transport-level failures (network unreachable, timeout).
- **`warm_up!/1`** — bang variant that returns `:warmed` on success or raises `RuntimeError` on transport failure. Consistent with the `Client.new!/1` bang pattern.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Implement warm_up/1 and warm_up!/1 | a70a4f8 | lib/lattice_stripe.ex |
| 2 | Create warm_up_test.exs with Mox tests | ede14c2 | test/lattice_stripe/warm_up_test.exs |

## Test Coverage

9 tests in `warm_up_test.exs`:

**warm_up/1 (7 tests):**
- Returns `{:ok, :warmed}` on 200 response
- Returns `{:ok, :warmed}` on 404 response (Stripe's expected response from GET /v1/)
- Returns `{:error, :timeout}` on timeout
- Returns `{:error, :econnrefused}` on connection refused
- Sends GET to `base_url <> /v1/` with correct Authorization header, body nil, and finch/timeout opts
- Uses custom `base_url` when configured
- Only 1 transport call — does NOT go through retry pipeline

**warm_up!/1 (2 tests):**
- Returns `:warmed` on success
- Raises `RuntimeError` matching `~r/warm-up failed/` on transport failure

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking Issue] Test command `--no-start` incompatible with Mox**

- **Found during:** Task 2 verification
- **Issue:** The plan specified `mix test ... --no-start`, but `--no-start` prevents the Mox.Server GenServer from starting, causing all 9 tests to fail with `no process: the process is not alive` on `verify_on_exit!`.
- **Fix:** Ran `mix test test/lattice_stripe/warm_up_test.exs` without `--no-start`. All 9 tests pass. Other Mox-based test files in the project also do not use `--no-start`.
- **Files modified:** none (test file unchanged — the command in the plan was wrong, not the test code)

## Known Stubs

None. Both functions are fully wired.

## Threat Flags

None beyond what was covered in the plan's threat model (T-25-03, T-25-04 both accepted).

## Self-Check: PASSED

- `lib/lattice_stripe.ex` exists and contains `def warm_up(` and `def warm_up!(`
- `test/lattice_stripe/warm_up_test.exs` exists and contains `LatticeStripe.WarmUpTest`
- Commits a70a4f8 and ede14c2 exist in git log
- 9 tests pass, 0 failures
- `mix compile --warnings-as-errors` exits 0
