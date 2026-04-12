---
phase: 13-billing-test-clocks
plan: 04
subsystem: test-helpers
tags: [test-clocks, advance, advance_and_wait, poll-loop, telemetry, backoff]
requires:
  - 13-01 (Error type whitelist + idempotency_key_prefix + TestSupport rename)
  - 13-02 (TestHelpers.TestClock struct + from_map/1 + atomize_status)
  - 13-03 (TestClock CRUD: create/retrieve/list/stream!/delete + bang variants)
provides:
  - TestHelpers.TestClock.advance/4, advance!/4 (POST /advance endpoint wrapper)
  - TestHelpers.TestClock.advance_and_wait/4, advance_and_wait!/4 (differentiating DX)
  - Private poll_until_ready/5 with exponential backoff + 500ms floor
  - Telemetry span [:lattice_stripe, :test_clock, :advance_and_wait]
affects:
  - Plan 13-05 (Testing.TestClock.advance/2 will build on advance_and_wait!/4)
  - Plan 13-06 (:real_stripe test uses advance_and_wait!/4 against live Stripe)
tech-stack:
  added: []
  patterns:
    - ":telemetry.span/3 gated by client.telemetry_enabled (mirrors Client.request)"
    - "Backoff config bundled into a map to keep function arity within Credo limits"
    - "Monotonic deadline via System.monotonic_time(:millisecond) (not system_time)"
    - "Error raw_body as free-form context (A-13c) — no Error schema extension"
key-files:
  modified:
    - lib/lattice_stripe/test_helpers/test_clock.ex
    - test/lattice_stripe/test_helpers/test_clock_test.exs
  created: []
decisions:
  - "Backoff params bundled into a %{delay, max_interval, multiplier, deadline, started_at} map — Credo max-arity fix while keeping poll loop readable"
  - "build_stop_meta/2 derives attempts/last_status from Error.raw_body keys (string keys, matching the raw_body shape constructed in the poll loop)"
  - "advance/4 failure short-circuits via `with` before the poll loop — the telemetry stop metadata reflects the Stripe-side error, not a fabricated timeout"
metrics:
  duration: 14min
  tasks: 2
  files: 2
  tests_before: 747
  tests_after: 766
  new_tests: 19
---

# Phase 13 Plan 04: advance_and_wait Poll Loop + Telemetry Summary

Shipped the differentiating Phase 13 feature — `TestHelpers.TestClock.advance_and_wait/4` — with exponential backoff, full jitter floored at 500ms per A-13b, monotonic deadline per D-13b, typed `:test_clock_timeout` / `:test_clock_failed` errors per A-13c, and a `:telemetry.span/3` that mirrors the Phase 12 Client.request pattern.

## Deliverables

1. **`advance/4` + `advance!/4`** — thin wrapper over `POST /v1/test_helpers/test_clocks/:id/advance` with guard clauses (`is_binary(id)` + `is_integer(frozen_time)`). Unwraps via `Resource.unwrap_singular(&from_map/1)` and `Resource.unwrap_bang!/1`. Returns `{:ok, %TestClock{status: :advancing}}` on success.

2. **`advance_and_wait/4` + `advance_and_wait!/4`** — the headline DX. Calls `advance/4` once, then enters `poll_until_ready/5` which:
   - Polls FIRST with zero delay (catches already-ready clocks and stripe-mock's instant fixture).
   - On `:ready` → `{:ok, clock}`.
   - On `:internal_failure` → `{:error, %Error{type: :test_clock_failed, raw_body: %{"clock_id", "last_status", "attempts"}}}` — terminal, no retry.
   - On any other status: checks monotonic deadline; if exceeded → `{:error, %Error{type: :test_clock_timeout, raw_body: %{"clock_id", "last_status", "attempts", "elapsed_ms"}}}`. Otherwise sleeps `max(500, :rand.uniform(delay))` (A-13b floor), multiplies delay by 1.5 (capped at 5000ms), and recurses.
   - On HTTP failure from `retrieve/3`: propagates the error unchanged.

3. **Telemetry** — `[:lattice_stripe, :test_clock, :advance_and_wait]` emits `:start` + `:stop` via `:telemetry.span/3`, gated by `client.telemetry_enabled`. Stop metadata: `%{clock_id, status, attempts, outcome: :ok | :error, error_type}`.

4. **Tests (19 new)** — all four poll branches (happy/polling/timeout/internal_failure), HTTP-error propagation (both during advance and during poll), bang variants for all three error paths, telemetry emission on success + error, and a telemetry-off assertion confirming the gate works. All tests use Mox sequential `expect/4` calls for determinism; the timeout test uses `opts[:timeout]: 0` to avoid any wall-clock flake per plan guidance.

## Implementation Notes

**Backoff is a map, not positional args.** The initial sketch had `poll_until_ready/9`. Credo max-arity (8) flagged it, so backoff state was bundled into `%{delay, max_interval, multiplier, deadline, started_at}`, giving `poll_until_ready/5` + a helper `handle_non_ready/6`. This is a pure refactor — no behavioral change — and makes the recursive call site (`%{backoff | delay: next_delay}`) clearer than threading seven positional args.

**Error shape uses string keys in raw_body.** Consistent with `Error.from_response/3` (which stores decoded JSON maps with string keys). Downstream consumers pattern-matching on `%{"clock_id" => _, "last_status" => _}` will look identical to API-error handling.

**Telemetry gating mirrors `Client.request`.** The span is wrapped in `if client.telemetry_enabled do :telemetry.span(...) else run.() (discarding meta) end`. This matches `Telemetry.request_span/4` (lib/lattice_stripe/telemetry.ex:274-291) and ensures users with `telemetry_enabled: false` pay zero telemetry cost.

**No `Date.shift/2` anywhere.** Plan acceptance criterion verified; Elixir 1.15 compatible.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Credo max-arity violation on `poll_until_ready/9`**
- **Found during:** Task 2 credo check
- **Issue:** Initial implementation had `poll_until_ready/9` which tripped the `Credo.Check.Refactor.FunctionArity` strict limit (8).
- **Fix:** Bundled backoff state into a map, reducing arity to `poll_until_ready/5` and adding a private `handle_non_ready/6` helper for the timeout-vs-sleep branch.
- **Files modified:** `lib/lattice_stripe/test_helpers/test_clock.ex`
- **Commit:** included in `c857ccf` (same Task 2 commit)

**2. [Rule 3 - Blocking] Export absence test clashed with Task 1 commit window**
- **Found during:** Task 1 GREEN step
- **Issue:** The plan-drafted export test asserted all four advance functions (`advance`, `advance!`, `advance_and_wait`, `advance_and_wait!`) are exported, which would have failed cleanly after Task 1 and blocked the Task 1 GREEN commit.
- **Fix:** Split the assertion — Task 1 commits assert only `advance/4` + `advance!/4`; the `advance_and_wait` export assertion moved into the Task 2 test block at the end of the file.
- **Files modified:** `test/lattice_stripe/test_helpers/test_clock_test.exs`

No other deviations. The plan executed as written.

## Authentication Gates

None.

## Commits

| Task | Type | Message | Commit |
|------|------|---------|--------|
| 1 RED | test | add failing tests for advance/4 and advance!/4 | 69c4419 |
| 1 GREEN | feat | implement TestHelpers.TestClock.advance/4 + bang variant | a4ef085 |
| 2 RED | test | add failing tests for advance_and_wait/4 + telemetry | 48f38bd |
| 2 GREEN | feat | implement advance_and_wait/4 + poll loop + telemetry span | c857ccf |

## Verification

- `mix compile --warnings-as-errors` — clean
- `mix test test/lattice_stripe/test_helpers/test_clock_test.exs` — 56 tests, 0 failures
- `mix test` — 766 tests + 4 properties, 0 failures (55 excluded for `:integration`/`:real_stripe`)
- `mix credo --strict lib/lattice_stripe/test_helpers/test_clock.ex` — no issues
- Acceptance criteria grep checks: all 13 patterns confirmed, `Date.shift` absent

## Requirements Satisfied

- **BILL-08** — `advance/4` ships.
- **BILL-08b** — `advance_and_wait/4` ships with exponential backoff + jitter + floor + monotonic deadline + typed errors.
- **BILL-08c** — `advance_and_wait!/4` bang variant ships, raises `%LatticeStripe.Error{}` on failure.

## Success Criteria (Plan)

- Plan 13-05 can build `Testing.TestClock.advance/2` on top of `advance_and_wait!/4` with a stable contract: `(client, id, frozen_time, opts) :: %TestClock{} | raise`.
- Plan 13-06's `:real_stripe` test can call `advance_and_wait!/4` directly.

Both satisfied.

## Self-Check: PASSED

- FOUND: lib/lattice_stripe/test_helpers/test_clock.ex
- FOUND: test/lattice_stripe/test_helpers/test_clock_test.exs
- FOUND: commit 69c4419
- FOUND: commit a4ef085
- FOUND: commit 48f38bd
- FOUND: commit c857ccf
