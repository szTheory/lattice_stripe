---
phase: 16
plan: 03
subsystem: billing/subscription_schedule
tags: [stripe-mock, integration-tests, form-encoder, exdoc, hexdocs, guides]
requirements: [BILL-03]
dependency_graph:
  requires:
    - 16-01 (SubscriptionSchedule resource + nested structs)
    - 16-02 (cancel/4, release/4, update/4 proration guard wiring)
  provides:
    - test/integration/subscription_schedule_integration_test.exs (10 tests, all 6 endpoints)
    - Phase 16 deepest-path form-encoder regression guard
    - guides/subscriptions.md ## Subscription Schedules section
    - mix.exs ExDoc Billing group extended with 5 Phase 16 modules
  affects:
    - guides/subscriptions.md
    - mix.exs
    - test/integration/
    - test/lattice_stripe/form_encoder_test.exs
tech-stack:
  added: []
  patterns:
    - "stripe-mock setup_all guard via :gen_tcp.connect/4 (inherited from Phase 14/15)"
    - "Shape-not-semantics assertions against stripe-mock (struct match, is_binary(id), is_list)"
    - "T-16-04 inline wire-verb regression-guard comments on cancel/release tests"
    - "Strict-client guard verified pre-network in integration context"
key-files:
  created:
    - test/integration/subscription_schedule_integration_test.exs
    - .planning/phases/16-subscription-schedules/16-03-SUMMARY.md
  modified:
    - test/lattice_stripe/form_encoder_test.exs
    - guides/subscriptions.md
    - mix.exs
decisions:
  - "Used `import LatticeStripe.TestHelpers` (matches existing integration test idiom) instead of `alias LatticeStripe.Test.Helpers` suggested in plan"
  - "list/3 assertion uses `%Response{data: %List{}}` shape (matches actual return type from lib code), not bare `%List{}` from plan text"
  - "lib/lattice_stripe/form_encoder.ex left UNCHANGED — encoder already handles arbitrary nesting"
metrics:
  duration: ~15min
  completed: 2026-04-12
  tasks: 3
  commits: 3
  test_count_delta: +11 (1 form encoder + 10 integration)
---

# Phase 16 Plan 03: SubscriptionSchedule Integration Tests + Docs Wiring Summary

Closes Phase 16 with stripe-mock integration coverage of all 6 SubscriptionSchedule endpoints, a Phase 16 deepest-path form-encoder regression guard, an extended `guides/subscriptions.md` with a `## Subscription Schedules` section, and `mix.exs` ExDoc wiring so the 5 new Phase 16 modules land under the Billing group on HexDocs.

## What Was Built

### Task 1 — Form encoder regression test (commit `c77cf9b`)

`test/lattice_stripe/form_encoder_test.exs`: appended one test inside `describe "encode/1 edge cases"` named `"phases[].items[].price_data nested encoding (Phase 16 regression guard)"` (lines 168-194). Asserts the exact wire output for the deepest known Phase 16 param path:

- `phases[0][items][0][price_data][currency]=usd`
- `phases[0][items][0][price_data][recurring][interval]=month`
- `phases[0][proration_behavior]=create_prorations`

Inline comment marks it a Phase 16 guard so future refactors do not remove it. `lib/lattice_stripe/form_encoder.ex` is UNCHANGED — the encoder already handles arbitrary-depth nesting via recursive `flatten/2`.

Test count: 26 → 27 in `form_encoder_test.exs`.

### Task 2 — stripe-mock integration suite (commit `ae7124c`)

`test/integration/subscription_schedule_integration_test.exs` (273 lines, 10 tests):

| # | Test | Endpoint | Notes |
|---|------|----------|-------|
| 1 | `create (customer + phases mode)` | `POST /v1/subscription_schedules` | Asserts struct, `is_binary(id)`, decoded `phases[]` is `[%Phase{}]` |
| 2 | `create (from_subscription mode)` | `POST /v1/subscription_schedules` | Creates a real Subscription first, then converts |
| 3 | `retrieve/3` | `GET /v1/subscription_schedules/:id` | Shape check |
| 4 | `update/4 with phases[].proration_behavior` | `POST /v1/subscription_schedules/:id` | T-16-05 form-encoder regression guard via deep nested phases[] |
| 5 | `cancel/4 uses POST` | `POST /v1/subscription_schedules/:id/cancel` | T-16-04 wire-verb guard (DELETE would 404/405) |
| 6 | `release/4 uses POST` | `POST /v1/subscription_schedules/:id/release` | T-16-04 wire-verb guard |
| 7 | `list/3` | `GET /v1/subscription_schedules` | Asserts `%Response{data: %List{}}` shape |
| 8 | `stream!/3` | `GET /v1/subscription_schedules` (paginated) | Take(2), assert all `%SubscriptionSchedule{}` |
| 9 | `strict client rejects update with phases[] missing proration_behavior` | (none — pre-network) | T-16-03 guard fires before HTTP dispatch |
| 10 | `idempotency_key forwarded on create` | `POST /v1/subscription_schedules` (×2) | T-16-02; reuses key on second call |

`setup_all` checks `localhost:12111` reachability and starts `LatticeStripe.IntegrationFinch` (matches `subscription_integration_test.exs` pattern). All tests use `import LatticeStripe.TestHelpers` and `test_integration_client/0`. Each test creates its own fresh Product/Price/Customer fixtures inline (stripe-mock is stateless so isolation is free).

### Task 3 — Guide + ExDoc wiring (commit `5ad95f7`)

**`guides/subscriptions.md`** (273 → 407 lines, **+134 lines**):

New `## Subscription Schedules` section inserted between `## Proration` and `## SubscriptionItem operations`. Subsections:

- `### When to use a Subscription Schedule` — deterministic future billing changes vs ad-hoc updates
- `### Creation modes` — Mode 1 (`from_subscription`) and Mode 2 (`customer + phases`) code examples; explicit note that mixing modes surfaces as `%LatticeStripe.Error{type: :invalid_request_error}`
- `### cancel vs release` — code example for each, irreversibility callout on `release/4`, wire-verb contrast (POST sub-paths vs `Subscription.cancel/4`'s DELETE)
- `### Proration on update` — `phases[].proration_behavior` example, explicit note that Stripe rejects `phases[].items[]` proration_behavior
- `### Webhook-driven state transitions` — webhook event names (`subscription_schedule.created/updated/canceled/released/aborted`)

**`mix.exs`** (+5 lines): extended the Billing `groups_for_modules` list with the 5 Phase 16 modules:

- `LatticeStripe.SubscriptionSchedule`
- `LatticeStripe.SubscriptionSchedule.Phase`
- `LatticeStripe.SubscriptionSchedule.CurrentPhase`
- `LatticeStripe.SubscriptionSchedule.PhaseItem`
- `LatticeStripe.SubscriptionSchedule.AddInvoiceItem`

`mix docs` builds clean with **zero warnings**. All 5 module HTML files generated under `doc/` (verified `doc/LatticeStripe.SubscriptionSchedule.html` and `doc/LatticeStripe.SubscriptionSchedule.Phase.html` exist).

## Commits

| Hash      | Type | Message                                                                  |
| --------- | ---- | ------------------------------------------------------------------------ |
| `c77cf9b` | test | add Phase 16 deepest-path form encoder regression guard                  |
| `ae7124c` | test | add SubscriptionSchedule stripe-mock integration suite                   |
| `5ad95f7` | docs | document SubscriptionSchedules + wire ExDoc Billing group                |

## Verification

- `mix test test/lattice_stripe/form_encoder_test.exs` — **27 tests, 0 failures**
- `mix test --include integration test/integration/subscription_schedule_integration_test.exs` — **10 tests, 0 failures** (against stripe-mock on :12111)
- `mix test --exclude integration` — **1033 tests, 0 failures** (89 excluded). No Phase 14/15 regressions.
- `mix credo --strict test/integration/subscription_schedule_integration_test.exs` — clean (no issues)
- `mix docs` — clean, no warnings, all 5 SubscriptionSchedule modules in `doc/`
- `mix format` applied to integration test file (split a long `customer = ...` line)

## Threat Model Coverage

| Threat ID | Disposition | Test(s) covering it |
| --------- | ----------- | ------------------- |
| T-16-04 (wrong HTTP verb on cancel/release) | mitigate | Tests 5 and 6 — stripe-mock returns 200 only when POST is used; inline `T-16-04` comment on each test |
| T-16-05 (deep-nested form encoding drift) | mitigate | Form encoder unit test (Task 1) + integration test 4 (update with deeply nested `phases[].items[]`) |
| T-16-02 (idempotency replay) | mitigate | Integration test 10 — `idempotency_key` forwarded twice with same key, both succeed |
| T-16-03 (silent proration on update) | mitigate | Integration test 9 — strict client rejects pre-network, no HTTP dispatched |
| T-16-Docs (misuse via missing docs) | mitigate | `## Subscription Schedules` section in guides/subscriptions.md with prominent cancel-vs-release irreversibility callout |

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 1 - Style] Replaced `length(sched.phases) >= 1` with `sched.phases != []`**
- **Found during:** Task 2 verification (`mix credo --strict`)
- **Issue:** Credo `Refactor.MapInto`/`Refactor.LengthOfList` warning — `length/1` is O(n); use empty-list comparison.
- **Fix:** Replaced with `sched.phases != []`.
- **Files modified:** `test/integration/subscription_schedule_integration_test.exs`
- **Commit:** Folded into `ae7124c`.

**2. [Rule 1 - Style] `mix format` applied to integration test file**
- **Found during:** Task 2 verification (`mix format`)
- **Issue:** A long `customer = fresh_customer!(...)` call inside `create_basic_schedule!/1` exceeded the line length budget.
- **Fix:** `mix format` split it across two lines.
- **Files modified:** `test/integration/subscription_schedule_integration_test.exs`
- **Commit:** Folded into `ae7124c`.

### Idiom adjustment (not a true deviation)

The plan suggested `alias LatticeStripe.Test.Helpers` and references like `Helpers.test_integration_client()`. The actual codebase uses `import LatticeStripe.TestHelpers` (single-word module name) and a bare `test_integration_client()` call. I followed the existing-codebase idiom — confirmed by reading `test/integration/subscription_integration_test.exs` and `test/support/test_helpers.ex` first.

### Out of scope

- Pre-existing `mix format --check-formatted` drift in `lib/lattice_stripe/invoice.ex`, `test/lattice_stripe/config_test.exs`, and `test/lattice_stripe/invoice_test.exs` — already logged in `.planning/phases/16-subscription-schedules/deferred-items.md` from Plan 16-02, untouched by this plan.

## Worktree Branch Reset

The worktree was checked out at `a01dadc8` (main) instead of the expected base `a2cfbaa7` (Plan 16-02 SUMMARY commit). I followed the worktree-branch-check protocol: soft-reset to `a2cfbaa7` and `git checkout` of all phase 16 lib/test/planning files from that commit. After reset, all Plan 16-01 + 16-02 outputs were intact and the plan executed without further issue.

## Issues Encountered

None beyond the worktree reset above.

## Next Phase Readiness

**Phase 16 is now functionally complete from a plan perspective.** The next step is `/gsd-verify-work` (Phase 16 gate), which should:

1. Re-run `mix test --include integration` end-to-end against a fresh stripe-mock container
2. Re-run `mix docs` to confirm the Billing group renders all 5 new modules
3. Verify `guides/subscriptions.md` Subscription Schedules section reads cleanly in HexDocs preview
4. Confirm BILL-03 requirement is fully discharged
5. Decide whether to address the pre-existing format drift in `lib/lattice_stripe/invoice.ex` etc. (likely a separate cleanup commit, not Phase 16's responsibility)

**Optional follow-ups for Phase 16 verifier:**

- The form-encoder regression test (`c77cf9b`) is the second line of defense behind stripe-mock. If `lib/lattice_stripe/form_encoder.ex` is ever rewritten, this test must continue to pass — it's worth promoting to a CI gate marker.
- The integration test's strict-client `proration_required` test could be moved to the unit suite (no network) — but keeping it in the integration suite proves the guard works in the same configuration users actually use.

## Self-Check

Verifying claimed artifacts before finishing.

- FOUND: `test/integration/subscription_schedule_integration_test.exs` (273 lines)
- FOUND: `test/lattice_stripe/form_encoder_test.exs` contains `phases[0][items][0][price_data][recurring][interval]=month`
- FOUND: `test/lattice_stripe/form_encoder_test.exs` contains `Phase 16 regression guard`
- FOUND: `guides/subscriptions.md` contains `## Subscription Schedules`
- FOUND: `guides/subscriptions.md` contains `### Creation modes`, `### cancel vs release`, `### Proration on update`, `### Webhook-driven state transitions`
- FOUND: `guides/subscriptions.md` contains `irreversible` and `subscription_schedule.created`
- FOUND: `mix.exs` contains `LatticeStripe.SubscriptionSchedule`, `.Phase`, `.CurrentPhase`, `.PhaseItem`, `.AddInvoiceItem`
- FOUND: `doc/LatticeStripe.SubscriptionSchedule.html`
- FOUND: `doc/LatticeStripe.SubscriptionSchedule.Phase.html`
- FOUND: commit `c77cf9b` (test Task 1)
- FOUND: commit `ae7124c` (test Task 2)
- FOUND: commit `5ad95f7` (docs Task 3)
- VERIFIED: `lib/lattice_stripe/form_encoder.ex` UNCHANGED (no diff in HEAD~3..HEAD)

## Self-Check: PASSED

---
*Phase: 16-subscription-schedules*
*Plan: 03*
*Completed: 2026-04-12*
