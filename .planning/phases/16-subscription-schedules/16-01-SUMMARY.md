---
phase: 16-subscription-schedules
plan: 01
subsystem: payments
tags: [stripe, subscription_schedules, billing, typed_structs, pii_safe_inspect, mox]

# Dependency graph
requires:
  - phase: 14-invoices-invoice-line-items
    provides: LatticeStripe.Invoice.AutomaticTax (reused for phases[].automatic_tax)
  - phase: 15-subscriptions-subscription-items
    provides: Subscription resource template, Billing.Guards skeleton, fixtures pattern
provides:
  - LatticeStripe.SubscriptionSchedule top-level resource (CRUD + bang variants)
  - LatticeStripe.SubscriptionSchedule.Phase (dual-usage typed struct)
  - LatticeStripe.SubscriptionSchedule.CurrentPhase (timestamp summary struct)
  - LatticeStripe.SubscriptionSchedule.PhaseItem (template item, distinct from SubscriptionItem)
  - LatticeStripe.SubscriptionSchedule.AddInvoiceItem (one-off phase invoice item)
  - LatticeStripe.Test.Fixtures.SubscriptionSchedule (fixture module)
  - PII-safe Inspect impl on top-level SubscriptionSchedule masking customer/subscription/released_subscription/default_settings/phases
affects: [16-02-action-verbs-and-guard, 16-03-integration-and-docs]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@known_fields + extra struct pattern (inherited Phase 14/15)"
    - "Top-level-only PII-safe Inspect (D1 deviation from Phase 15 nested-Inspect approach)"
    - "Reused nested struct: Phase serves both phases[] and default_settings"
    - "Template-vs-live divergence: PhaseItem deliberately omits :id/:object/:subscription/:created"

key-files:
  created:
    - lib/lattice_stripe/subscription_schedule.ex
    - lib/lattice_stripe/subscription_schedule/phase.ex
    - lib/lattice_stripe/subscription_schedule/current_phase.ex
    - lib/lattice_stripe/subscription_schedule/phase_item.ex
    - lib/lattice_stripe/subscription_schedule/add_invoice_item.ex
    - test/lattice_stripe/subscription_schedule_test.exs
    - test/lattice_stripe/subscription_schedule/phase_test.exs
    - test/lattice_stripe/subscription_schedule/current_phase_test.exs
    - test/lattice_stripe/subscription_schedule/phase_item_test.exs
    - test/lattice_stripe/subscription_schedule/add_invoice_item_test.exs
    - test/support/fixtures/subscription_schedule.ex
  modified: []

key-decisions:
  - "Followed locked D1: nested structs use default derived Inspect (NO defimpl Inspect on Phase/CurrentPhase/PhaseItem/AddInvoiceItem)"
  - "Top-level Inspect masks PII by never surfacing nested collections (mirrors Subscription Inspect strategy)"
  - "PhaseItem struct deliberately diverges from SubscriptionItem (template vs. live item)"
  - "Phase struct reused for default_settings — timeline fields nil in that position"
  - "No proration guard wired into update/4 yet (Plan 16-02 owns wiring)"

patterns-established:
  - "Per-resource Inspect-on-top-level-only: prevents PII leakage via default derived Inspect on nested structs"
  - "Template structs (PhaseItem) coexist with live structs (SubscriptionItem) under different module names — never collapse"

requirements-completed: [BILL-03]

# Metrics
duration: ~25 min
completed: 2026-04-12
---

# Phase 16 Plan 01: SubscriptionSchedule Resource + Nested Structs Summary

**`LatticeStripe.SubscriptionSchedule` resource module with CRUD + bang variants, four nested typed structs (Phase/CurrentPhase/PhaseItem/AddInvoiceItem), and a single PII-safe top-level Inspect impl masking customer/subscription/payment-method ids across all nested positions**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-12
- **Completed:** 2026-04-12
- **Tasks:** 2 (Task 1: 4 nested struct modules + tests; Task 2: top-level resource + tests + fixture)
- **Files created:** 11

## Accomplishments

- Top-level `LatticeStripe.SubscriptionSchedule` struct with 19 known fields + `extra`, `from_map/1` decoding `current_phase`/`default_settings`/`phases[]` into typed nested structs
- CRUD surface: `create/3`, `retrieve/3`, `update/4`, `list/3`, `stream!/3` plus `create!`/`retrieve!`/`update!`/`list!` bang variants
- Four new nested typed structs under `LatticeStripe.SubscriptionSchedule.*`:
  - `Phase` — dual-usage (phases[] and default_settings), 24 known fields, decodes `automatic_tax` via reused `Invoice.AutomaticTax`, `items` via `PhaseItem`, `add_invoice_items` via `AddInvoiceItem`
  - `CurrentPhase` — small read-only summary (`start_date`, `end_date`)
  - `PhaseItem` — 9 known fields; intentionally has NO `id`/`object`/`subscription`/`created`/`current_period_*`; HAS `price_data`/`trial_data`
  - `AddInvoiceItem` — 7 known fields including `period`
- Custom PII-safe `defimpl Inspect, for: LatticeStripe.SubscriptionSchedule` — the **only** Inspect impl in Phase 16 — masking `customer`, `subscription`, `released_subscription`, `default_settings`, `phases` by emitting presence booleans + `phase_count` integer instead of nested contents
- Fixture module `LatticeStripe.Test.Fixtures.SubscriptionSchedule` with `basic/1`, `with_two_phases/1`, `canceled/1`, `released/1`, `list_response/1` — includes `pm_default_test` and `pm_phase_test` strings to exercise PII masking
- 38 unit tests across 5 test files, all passing
- Full project test suite: **1013 tests, 0 failures**
- `mix credo --strict`, `mix format --check-formatted`, `mix compile --warnings-as-errors` all clean

## Task Commits

1. **Task 1 RED — Nested struct tests** — `149633b` (test)
2. **Task 1 GREEN — Nested struct implementations** — `0029602` (feat)
3. **Task 2 RED — Top-level resource tests + fixture** — `d3cfe3d` (test)
4. **Task 2 GREEN — Top-level resource implementation** — `e53d930` (feat)

## Files Created/Modified

### Library code (5 files, 687 LOC)

- `lib/lattice_stripe/subscription_schedule.ex` (330 lines) — Top-level resource: struct, `from_map/1`, CRUD + bang variants, custom PII-safe Inspect
- `lib/lattice_stripe/subscription_schedule/phase.ex` (163 lines) — Dual-usage Phase struct decoding nested AutomaticTax/PhaseItem/AddInvoiceItem
- `lib/lattice_stripe/subscription_schedule/phase_item.ex` (87 lines) — Template item; deliberately distinct from SubscriptionItem
- `lib/lattice_stripe/subscription_schedule/add_invoice_item.ex` (68 lines) — One-off phase invoice item with period
- `lib/lattice_stripe/subscription_schedule/current_phase.ex` (39 lines) — Timestamp summary struct

### Test code (6 files, 725 LOC)

- `test/lattice_stripe/subscription_schedule_test.exs` (326 lines) — Mox-based tests for from_map, CRUD, bang variants, idempotency forwarding, Inspect PII assertions
- `test/lattice_stripe/subscription_schedule/phase_test.exs` (105 lines) — Round-trip + dual-usage + nested decoding tests
- `test/lattice_stripe/subscription_schedule/phase_item_test.exs` (61 lines) — Includes regression guard `refute Map.has_key?` for `:id`/`:object`/`:subscription`/`:created`/`:current_period_*`
- `test/lattice_stripe/subscription_schedule/current_phase_test.exs` (32 lines) — `from_map/1` + extras
- `test/lattice_stripe/subscription_schedule/add_invoice_item_test.exs` (42 lines) — `from_map/1` + period decoding
- `test/support/fixtures/subscription_schedule.ex` (159 lines) — Fixture module with PII-bearing payment-method ids for masking assertions

## Decisions Made

- **Followed locked D1 verbatim:** Nested structs (Phase, CurrentPhase, PhaseItem, AddInvoiceItem) use Elixir's default derived Inspect — NO `defimpl Inspect` blocks. This is a deliberate deviation from Phase 15's pattern where `Subscription.PauseCollection`, `Subscription.CancellationDetails`, and `Subscription.TrialSettings` each have custom Inspect impls. Rationale: PII safety is centralized on the top-level `%SubscriptionSchedule{}` Inspect, which never surfaces `phases[]` or `default_settings` contents — so default Inspect on nested structs cannot leak `default_payment_method` because those structs are never inspected as top-level values. Acceptance criteria explicitly grep for 0 occurrences of `defimpl Inspect` in nested struct files.
- **Top-level Inspect masks via "never surface nested collections" strategy:** Mirrors `LatticeStripe.Subscription` Inspect (lib/lattice_stripe/subscription.ex lines 520-547). Emits `has_customer?`, `has_subscription?`, `has_released_subscription?`, `has_default_settings?`, `phase_count`, plus safe non-PII fields (`id`, `object`, `status`, `end_behavior`, `current_phase` (timestamps only), `livemode`).
- **`update/4` intentionally has NO proration-guard wiring:** Plan 16-02 owns the `Billing.Guards.check_proration_required/2` wiring. Inline NOTE comment placed at the call site to keep that diff a single line. No tests reference `Billing.Guards` (out of scope per plan).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `Inspect` "shows extra" test was over-eager**
- **Found during:** Task 2 GREEN verification (`mix test`)
- **Issue:** Initial test `refute inspect(sched_no_extra) =~ "extra:"` failed because the nested `current_phase` (a `%CurrentPhase{}`) uses Elixir's default derived Inspect which always emits `extra: %{}` even when empty. The test was conflating "top-level extra" (which the custom Inspect intentionally suppresses) with "any nested struct's extra field".
- **Fix:** Tightened the regex to anchor on the top-level position: `~r/phase_count: \d+, extra:/`. This matches only when `:extra` appears immediately after `phase_count:` at the top level — i.e., only when the top-level Inspect surfaced its own non-empty `:extra` field.
- **Files modified:** `test/lattice_stripe/subscription_schedule_test.exs`
- **Verification:** Test passes; the negative case (basic fixture, no top-level extra) and positive case (`future_field` override, top-level extra present) both exercise correctly.
- **Committed in:** `e53d930` (Task 2 GREEN commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 bug — test precision)
**Impact on plan:** Trivial test fix; no scope creep, no production code change.

## Issues Encountered

- Worktree branch was created from `main` (commit `a01dadc8`) instead of the expected base `fad35e13`. Resolved by `git reset --hard fad35e13e6232333eea22e45f02dc7226ffaafb7` per the worktree-branch-check protocol. After reset, all phase 16 planning artifacts were present and intact.

## Next Phase Readiness

**Plan 16-02 inputs ready:**

- `lib/lattice_stripe/subscription_schedule.ex:201-209` — `update/4` body has an inline `NOTE:` comment marking the exact insertion point for `with :ok <- Billing.Guards.check_proration_required(client, params) do ... end`. The diff should be ~3 lines: wrap the existing pipeline in a `with` block.
- `lib/lattice_stripe/billing/guards.ex` — currently exists with `check_proration_required/2`, `top_level_has?/1`, `subscription_details_has?/1`, `items_has?/1`. Plan 16-02 Task 1 needs to add `phases_has?/1` private helper + new `or` branch in `has_proration_behavior?/1`.
- `LatticeStripe.SubscriptionSchedule` is fully ready to absorb `cancel/4`, `cancel!/4`, `release/4`, `release!/4` action verbs in Plan 16-02. The CRUD section ends at the end of the `stream!/3` definition; insert action verbs above `from_map/1`.
- Fixture module already provides `canceled/1` and `released/1` shapes for action-verb tests in Plan 16-02.

**Plan 16-03 inputs ready:**

- `LatticeStripe.Test.Fixtures.SubscriptionSchedule.basic/1` round-trips through `from_map/1` and includes a single `phases[0].items[0]` element — usable as the form-encoder regression-test fixture for `phases[][items][][price_data]` deep-nested encoding.
- All five new modules (`SubscriptionSchedule` + 4 nested) are ready to be added to `mix.exs` ExDoc `groups_for_modules` Billing group.

**Verification commands all green:**
- `mix test test/lattice_stripe/subscription_schedule_test.exs test/lattice_stripe/subscription_schedule/` — 38 tests, 0 failures
- `mix test --exclude integration` — 1013 tests, 0 failures
- `mix credo --strict lib/lattice_stripe/subscription_schedule.ex lib/lattice_stripe/subscription_schedule/` — 0 issues
- `mix format --check-formatted` — clean
- `mix compile --warnings-as-errors` — clean

## Self-Check

Verifying claimed artifacts before finishing.

- FOUND: `lib/lattice_stripe/subscription_schedule.ex`
- FOUND: `lib/lattice_stripe/subscription_schedule/phase.ex`
- FOUND: `lib/lattice_stripe/subscription_schedule/current_phase.ex`
- FOUND: `lib/lattice_stripe/subscription_schedule/phase_item.ex`
- FOUND: `lib/lattice_stripe/subscription_schedule/add_invoice_item.ex`
- FOUND: `test/lattice_stripe/subscription_schedule_test.exs`
- FOUND: `test/lattice_stripe/subscription_schedule/phase_test.exs`
- FOUND: `test/lattice_stripe/subscription_schedule/current_phase_test.exs`
- FOUND: `test/lattice_stripe/subscription_schedule/phase_item_test.exs`
- FOUND: `test/lattice_stripe/subscription_schedule/add_invoice_item_test.exs`
- FOUND: `test/support/fixtures/subscription_schedule.ex`
- FOUND: commit `149633b` (test RED nested structs)
- FOUND: commit `0029602` (feat GREEN nested structs)
- FOUND: commit `d3cfe3d` (test RED top-level resource)
- FOUND: commit `e53d930` (feat GREEN top-level resource)

## Self-Check: PASSED

---
*Phase: 16-subscription-schedules*
*Plan: 01*
*Completed: 2026-04-12*
