---
phase: 16
plan: 02
subsystem: billing/subscription_schedule
tags: [subscription-schedule, billing-guards, proration, action-verbs]
requirements: [BILL-03]
dependency_graph:
  requires:
    - 16-01 (SubscriptionSchedule resource shape + nested structs)
    - Phase 15 Billing.Guards (items[] branch + check_proration_required/2)
  provides:
    - SubscriptionSchedule.cancel/4 + cancel!/4
    - SubscriptionSchedule.release/4 + release!/4
    - SubscriptionSchedule.update/4 wired with proration guard
    - Billing.Guards.phases_has?/1 + extended has_proration_behavior?/1
  affects:
    - lib/lattice_stripe/billing/guards.ex
    - lib/lattice_stripe/subscription_schedule.ex
tech-stack:
  added: []
  patterns:
    - "with :ok <- Billing.Guards.check_proration_required(...)"
    - "POST /:id/cancel and POST /:id/release sub-paths (NOT DELETE)"
    - "Defensive private helpers: when is_list / catch-all clauses"
key-files:
  created: []
  modified:
    - lib/lattice_stripe/billing/guards.ex
    - lib/lattice_stripe/subscription_schedule.ex
    - test/lattice_stripe/billing/guards_test.exs
    - test/lattice_stripe/subscription_schedule_test.exs
decisions:
  - "Guard wired into update/4 ONLY — create/3, cancel/4, release/4 bypass per D4 (Stripe doesn't accept proration_behavior on those endpoints)"
  - "cancel/4 and release/4 use POST with sub-paths (NOT DELETE) — diverges from Subscription.cancel/4 wire shape"
  - "phases_has?/1 mirrors items_has?/1 byte-for-byte; does not walk phases[].items[] (Stripe rejects that path)"
metrics:
  duration: ~25min
  completed: 2026-04-12
  tasks: 3
  commits: 6
  test_count_delta: +14 (4 guards + 5 cancel + 5 release; 4 update guard tests; 1 create regression — total 14 net new tests)
---

# Phase 16 Plan 02: SubscriptionSchedule Mutations + Guard Extension Summary

Adds `cancel/4` and `release/4` action verbs to `LatticeStripe.SubscriptionSchedule` (POST sub-paths, not DELETE), extends `LatticeStripe.Billing.Guards.has_proration_behavior?/1` with a `phases[]` branch, and wires `check_proration_required/2` into `SubscriptionSchedule.update/4` only — owning the "schedule mutations are safe" review concern in one slice.

## What Was Built

### `lib/lattice_stripe/billing/guards.ex` (+21 / -2 lines)

- `@moduledoc` extended to mention `SubscriptionSchedule.update/4` (Phase 16).
- `has_proration_behavior?/1` gains an `or phases_has?(params["phases"])` branch.
- New private helper `phases_has?/1`:
  - `when is_list(phases)` clause: `Enum.any?` over phases checking each map element for `"proration_behavior"`.
  - Catch-all `phases_has?(_), do: false` covers nil, non-list, and non-map list elements.
  - Inline comment cites `https://docs.stripe.com/api/subscription_schedules/update` and explicitly forbids walking `phases[].items[]`.

### `lib/lattice_stripe/subscription_schedule.ex` (+~140 / -10 lines)

- `alias` line extended: `LatticeStripe.{Billing, Client, Error, Request, Resource, Response}`.
- `@moduledoc` "Proration guard" section rewritten to confirm wiring into `update/4` only and explicitly state `create/3`, `cancel/4`, `release/4` bypass the guard.
- `update/4` body wrapped in `with :ok <- Billing.Guards.check_proration_required(client, params) do ... end` — single-line semantic change, falls through `with` failure to return the `{:error, %Error{type: :proration_required}}` directly.
- New functions appended after `stream!/3`:
  - `cancel/4` → `POST /v1/subscription_schedules/:id/cancel` with full @doc covering `invoice_now`, `prorate`, contrast vs `release/4`, and explicit note that `prorate ≠ proration_behavior`.
  - `cancel!/4` → bang variant via `Resource.unwrap_bang!/1`.
  - `release/4` → `POST /v1/subscription_schedules/:id/release` with @doc covering `preserve_cancel_date` and an irreversibility callout that explicitly contrasts with `cancel/4`.
  - `release!/4` → bang variant.
- Both action verbs forward `opts[:idempotency_key]` via the `%Request{}.opts` keyword list (T-16-02 mitigation).

### Tests

- `test/lattice_stripe/billing/guards_test.exs`: +4 tests covering `phases[]` dimension (+ proration_behavior, − proration_behavior, non-map element, mixed elements).
- `test/lattice_stripe/subscription_schedule_test.exs`: +10 cancel/release tests + 4 update guard tests + 1 create regression test = +15 tests total.

Test count delta: 17 → 37 (subscription_schedule_test.exs); 14 → 18 (guards_test.exs).

## Commits

| Hash      | Type | Message                                                                  |
| --------- | ---- | ------------------------------------------------------------------------ |
| `8f59821` | test | add failing tests for phases[] proration guard                           |
| `6e98f9e` | feat | extend Billing.Guards with phases[] proration detection                  |
| `d174fa5` | test | add failing tests for SubscriptionSchedule cancel/4 + release/4          |
| `beed446` | feat | add cancel/4 and release/4 action verbs to SubscriptionSchedule          |
| `2868c8e` | test | add failing tests for SubscriptionSchedule.update/4 proration guard      |
| `622861f` | feat | wire Billing.Guards into SubscriptionSchedule.update/4                   |

## Verification

- `mix test test/lattice_stripe/subscription_schedule_test.exs test/lattice_stripe/billing/guards_test.exs` — 55 tests, 0 failures.
- `mix test --exclude integration` — 1032 tests, 0 failures (79 excluded). No Phase 15 regressions.
- `mix credo --strict lib/lattice_stripe/subscription_schedule.ex lib/lattice_stripe/billing/guards.ex` — 28 mods/funs, no issues.
- `mix compile --warnings-as-errors` — clean.
- `mix format` applied to all Plan 16-02 files (subscription_schedule.ex picked up small formatting deltas in the new function bodies; see Deviations).

## Threat Model Coverage

| Threat ID | Disposition | Test(s) covering it                                                                                                                  |
| --------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| T-16-02   | mitigate    | "forwards opts[:idempotency_key]" tests in both `cancel/4` and `release/4` describe blocks.                                          |
| T-16-02a  | mitigate    | "phases[] with non-map element does not crash" guards test.                                                                          |
| T-16-03   | mitigate    | "update/4 proration guard" describe block (4 tests including zero-Transport-call assertion via Mox `verify_on_exit!`).               |
| T-16-04   | mitigate    | "uses POST to /cancel sub-path (NOT DELETE)" + "uses POST to /release sub-path"; `lib/lattice_stripe/subscription_schedule.ex` contains zero `method: :delete`. |

## Deviations from Plan

### Documentation drift only

**1. [Rule 3 - Blocking] Fixed body assertion idiom**

- **Found during:** Task 2 RED.
- **Issue:** Plan suggested `IO.iodata_to_binary(req.body || "")` but every other test in the suite uses `assert req.body =~ "..."` directly.
- **Fix:** Used the existing codebase idiom.
- **Files modified:** `test/lattice_stripe/subscription_schedule_test.exs`
- **Commit:** Folded into `d174fa5`.

### `mix format` auto-applied

- The formatter rewrote a couple of long-arg `def` lines in `subscription_schedule.ex` and one test arg-list in `subscription_schedule_test.exs`. Tests still pass, behavior unchanged. Folded into `622861f`.

### Out of scope (deferred)

- `mix format --check-formatted` reports pre-existing formatting drift in `lib/lattice_stripe/invoice.ex`, `test/lattice_stripe/invoice_test.exs`, and `test/lattice_stripe/config_test.exs`. None of these files were touched by Plan 16-02. Logged in `.planning/phases/16-subscription-schedules/deferred-items.md`.

## Issues with Plan 16-01 Output

None. `lib/lattice_stripe/subscription_schedule.ex` from 16-01 left a clean wiring point inside `update/4` (the `# NOTE: Plan 16-02 Task 3 adds...` comment), and the proration-guard `@moduledoc` section was already shaped to receive the wiring update without restructuring. Plan 16-03 can proceed unblocked.

## Self-Check: PASSED

- `lib/lattice_stripe/billing/guards.ex` — modified, `phases_has?/1` present, comment cites Stripe URL: FOUND.
- `lib/lattice_stripe/subscription_schedule.ex` — `cancel/4`, `cancel!/4`, `release/4`, `release!/4`, `with :ok <- Billing.Guards...` all present: FOUND. Zero `method: :delete` references: VERIFIED.
- `test/lattice_stripe/billing/guards_test.exs` — 4 new phases[] tests: FOUND.
- `test/lattice_stripe/subscription_schedule_test.exs` — `describe "cancel/4"`, `describe "release/4"`, `describe "update/4 proration guard"`, `create/3 does NOT invoke Billing.Guards` test: FOUND.
- All 6 task commits present in `git log 158fbf5..HEAD`: VERIFIED.
- `mix test --exclude integration` exits 0: VERIFIED.
