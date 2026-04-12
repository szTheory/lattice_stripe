---
phase: 15
slug: subscriptions-subscription-items
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-12
updated: 2026-04-12
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Populated by the planner on 2026-04-12 after PLAN files authored. Nyquist audit pending.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) + Mox ~> 1.2 |
| **Config file** | `test/test_helper.exs` (existing) |
| **Quick run command** | `mix test --exclude integration` |
| **Full suite command** | `mix test --include integration` (requires stripe-mock Docker container on :12111) |
| **Estimated runtime** | ~5s unit / ~30s with integration |

---

## Sampling Rate

- **After every task commit:** Run `mix test <scoped test file>` + `mix format --check-formatted` + `mix credo --strict`
- **After every plan wave:** Run `mix test --exclude integration` (full unit suite)
- **Before `/gsd-verify-work`:** `mix test --include integration` must be green with stripe-mock running
- **Max feedback latency:** ~5 seconds (unit), ~30 seconds (with integration)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 15-01-T1 | 01 | 1 | BILL-03 | T-15-01 | Custom Inspect masks `CancellationDetails.comment` and other PII in nested structs | unit | `mix test test/lattice_stripe/subscription/pause_collection_test.exs test/lattice_stripe/subscription/cancellation_details_test.exs test/lattice_stripe/subscription/trial_settings_test.exs --trace` | ❌ W0 | ⬜ pending |
| 15-01-T2 | 01 | 1 | BILL-03 | T-15-03 | Guard detects `items[].proration_behavior` and rejects strict-client updates without it | unit | `mix test test/lattice_stripe/billing/guards_test.exs --trace` | ❌ W0 | ⬜ pending |
| 15-01-T3 | 01 | 1 | BILL-03 | T-15-01 / T-15-02 / T-15-03 / T-15-05 | Subscription Inspect hides PII; idempotency_key forwarded on mutations; guard wired into create/update; form encoder survives metadata injection | unit | `mix test test/lattice_stripe/subscription_test.exs test/lattice_stripe/billing/guards_test.exs --trace` | ❌ W0 | ⬜ pending |
| 15-02-T1 | 02 | 2 | BILL-03 | T-15-01 / T-15-02 / T-15-03 | SubscriptionItem Inspect masks metadata; idempotency_key forwarded; guard wired on create/update/delete; list/stream! require `subscription` param; `id` preservation regression-guarded | unit | `mix test test/lattice_stripe/subscription_item_test.exs --trace` | ❌ W0 | ⬜ pending |
| 15-03-T1 | 03 | 3 | BILL-03 | T-15-02 / T-15-03 / T-15-05 | Full lifecycle round-trip against stripe-mock; idempotency_key forwarded over HTTP; strict-client + items[] proration guard verified end-to-end; nested items[0][...] form encoding validated by server | integration | `mix test --include integration --only integration test/integration/subscription_integration_test.exs` | ❌ W0 | ⬜ pending |
| 15-03-T2 | 03 | 3 | BILL-03 | T-15-02 / T-15-03 | Full SubscriptionItem CRUD against stripe-mock; list/3 ArgumentError path; idempotency_key forwarded | integration | `mix test --include integration --only integration test/integration/subscription_item_integration_test.exs` | ❌ W0 | ⬜ pending |
| 15-03-T3 | 03 | 3 | BILL-03 | T-15-04 | Guide contains mandatory "Webhooks own state transitions" callout with exact phrase, all pause_collection atoms documented, no-new-telemetry note present | docs (grep) | `test -f guides/subscriptions.md && grep -q "Always drive your application state from webhook events" guides/subscriptions.md && grep -q ":keep_as_draft" guides/subscriptions.md && grep -q "No new telemetry events" guides/subscriptions.md` | ❌ W0 | ⬜ pending |
| 15-03-T4 | 03 | 3 | BILL-03 | (docs wiring) | All 5 new modules appear in ExDoc Billing group; guide rendered | docs build | `mix docs && grep -q "LatticeStripe.Subscription" doc/api-reference.html` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Test files that must exist as skeletons before Wave 1 execution starts (Wave 0 tasks are embedded inline in each plan's task 1 via `tdd="true"` — the plan tasks create the test file and the source file in a single task, RED→GREEN within the task boundary):

- [ ] `test/lattice_stripe/subscription_test.exs` — stubs for BILL-03 (Subscription CRUD + lifecycle) — **created by Plan 15-01 Task 3**
- [ ] `test/lattice_stripe/subscription/pause_collection_test.exs` — **created by Plan 15-01 Task 1**
- [ ] `test/lattice_stripe/subscription/cancellation_details_test.exs` — **created by Plan 15-01 Task 1**
- [ ] `test/lattice_stripe/subscription/trial_settings_test.exs` — **created by Plan 15-01 Task 1**
- [ ] `test/lattice_stripe/subscription_item_test.exs` — **created by Plan 15-02 Task 1**
- [ ] `test/integration/subscription_integration_test.exs` — **created by Plan 15-03 Task 1**
- [ ] `test/integration/subscription_item_integration_test.exs` — **created by Plan 15-03 Task 2**
- [ ] `test/support/fixtures/subscription.ex` — **created by Plan 15-01 Task 3**
- [ ] `test/support/fixtures/subscription_item.ex` — **created by Plan 15-02 Task 1**
- [ ] Extend `test/lattice_stripe/billing/guards_test.exs` with two new items[] cases — **extended by Plan 15-01 Task 2**

ExUnit + Mox already installed (no framework bootstrap needed).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `mix docs` renders `guides/subscriptions.md` cleanly under Billing module group | BILL-03 | HTML rendering + navigation structure is visual | `mix docs && open doc/index.html` — verify Billing group contains Subscription, SubscriptionItem, PauseCollection, CancellationDetails, TrialSettings and that the subscriptions guide appears in the sidebar |
| `Inspect.inspect(subscription)` hides PII | T-15-01 | Output inspection is subjective; automated regex-based check is added but visual sanity matters | `iex -S mix` → decode a fixture and `IO.inspect/1` — confirm no customer email, no payment_settings internals, no CancellationDetails comment |
| Stripe-mock acceptance of nested items[] encoding | T-15-05 | Server-side validation is the ground truth; unit tests can't fully simulate OpenAPI-level schema checks | Integration test in Plan 15-03 Task 1 delegates this verification to stripe-mock; visual confirmation of a clean pass is the sign-off |

---

## Validation Sign-Off

- [x] Planner populates per-task verification map in this file
- [x] All tasks have `<automated>` verify or Wave 0 dependencies (Wave 0 is inline in each TDD task)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s (integration), < 5s (unit)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-04-12 by plan-checker revision loop (all tasks have `<automated>` verify blocks, no watch-mode flags, <30s latency; inline TDD satisfies Wave 0 intent)
