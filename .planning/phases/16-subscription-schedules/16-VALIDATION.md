---
phase: 16
slug: subscription-schedules
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-12
---

# Phase 16 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/subscription_schedule_test.exs test/lattice_stripe/subscription_schedule/ test/lattice_stripe/billing/guards_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~12 seconds (unit) / ~45 seconds (full w/ stripe-mock) |

---

## Sampling Rate

- **After every task commit:** Run the quick command scoped to touched test files
- **After every plan wave:** Run `mix test --only unit` (unit) or `mix test` (full)
- **Before `/gsd-verify-work`:** Full suite must be green including `mix test --only integration`
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

> Task IDs finalized by planner; this table is a scaffold aligned to D5's 3-plan split.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 16-01-01 | 01 | 1 | BILL-03 | — | `%SubscriptionSchedule.Phase{}` decodes with `@known_fields` + `extra` | unit | `mix test test/lattice_stripe/subscription_schedule/phase_test.exs` | ❌ W0 | ⬜ pending |
| 16-01-02 | 01 | 1 | BILL-03 | — | `%SubscriptionSchedule.PhaseItem{}` decodes with `@known_fields` + `extra`; distinct from `SubscriptionItem` | unit | `mix test test/lattice_stripe/subscription_schedule/phase_item_test.exs` | ❌ W0 | ⬜ pending |
| 16-01-03 | 01 | 1 | BILL-03 | — | `%SubscriptionSchedule.AddInvoiceItem{}` + `%CurrentPhase{}` decode | unit | `mix test test/lattice_stripe/subscription_schedule/` | ❌ W0 | ⬜ pending |
| 16-01-04 | 01 | 1 | BILL-03 | T-16-01 (PII) | PII-safe `Inspect` hides `customer`, `default_payment_method` | unit | `mix test test/lattice_stripe/subscription_schedule_test.exs` | ❌ W0 | ⬜ pending |
| 16-01-05 | 01 | 2 | BILL-03 | — | `create/3`, `retrieve/3`, `update/4`, `list/3`, `stream!/3` + bang variants wire to correct verb+path | unit | `mix test test/lattice_stripe/subscription_schedule_test.exs` | ❌ W0 | ⬜ pending |
| 16-02-01 | 02 | 1 | BILL-03 | T-16-02 | `Billing.Guards.phases_has?/1` tolerates nil/non-list/non-map | unit | `mix test test/lattice_stripe/billing/guards_test.exs` | ✅ | ⬜ pending |
| 16-02-02 | 02 | 1 | BILL-03 | T-16-02 | `has_proration_behavior?/1` returns true for top-level AND `phases[].proration_behavior` | unit | `mix test test/lattice_stripe/billing/guards_test.exs` | ✅ | ⬜ pending |
| 16-02-03 | 02 | 2 | BILL-03 | T-16-03 | `update/4` raises `Client.MissingProrationBehaviorError` when `require_explicit_proration: true` and `phases[].proration_behavior` absent but `phases` present | unit | `mix test test/lattice_stripe/subscription_schedule_test.exs` | ❌ W0 | ⬜ pending |
| 16-02-04 | 02 | 2 | BILL-03 | T-16-04 | `cancel/4` POSTs to `/v1/subscription_schedules/:id/cancel` (NOT DELETE) with params/opts separation | unit | `mix test test/lattice_stripe/subscription_schedule_test.exs` | ❌ W0 | ⬜ pending |
| 16-02-05 | 02 | 2 | BILL-03 | T-16-04 | `release/4` POSTs to `/v1/subscription_schedules/:id/release` with params/opts separation | unit | `mix test test/lattice_stripe/subscription_schedule_test.exs` | ❌ W0 | ⬜ pending |
| 16-03-01 | 03 | 1 | BILL-03 | T-16-05 | `form_encoder` encodes `phases[0][items][0][price_data][recurring][interval]` regression test | unit | `mix test test/lattice_stripe/form_encoder_test.exs` | ✅ | ⬜ pending |
| 16-03-02 | 03 | 2 | BILL-03 | — | stripe-mock round-trip: create (customer+phases) | integration | `mix test test/integration/subscription_schedule_integration_test.exs --only integration` | ❌ W0 | ⬜ pending |
| 16-03-03 | 03 | 2 | BILL-03 | — | stripe-mock round-trip: retrieve, update, list, cancel, release | integration | `mix test test/integration/subscription_schedule_integration_test.exs --only integration` | ❌ W0 | ⬜ pending |
| 16-03-04 | 03 | 3 | BILL-03 | — | `guides/subscriptions.md` Schedules section + `mix.exs` ExDoc Billing group wiring | doc-build | `mix docs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/lattice_stripe/subscription_schedule_test.exs` — resource unit tests
- [ ] `test/lattice_stripe/subscription_schedule/phase_test.exs` — Phase struct tests
- [ ] `test/lattice_stripe/subscription_schedule/phase_item_test.exs` — PhaseItem struct tests
- [ ] `test/lattice_stripe/subscription_schedule/current_phase_test.exs` — CurrentPhase struct tests
- [ ] `test/lattice_stripe/subscription_schedule/add_invoice_item_test.exs` — AddInvoiceItem struct tests
- [ ] `test/integration/subscription_schedule_integration_test.exs` — stripe-mock round trips
- [ ] `test/support/fixtures/subscription_schedule.ex` — fixture module with minimal + full shapes

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `guides/subscriptions.md` Schedules section renders correctly on HexDocs | BILL-03 | ExDoc build only verifies compilation, not prose quality | Run `mix docs && open doc/index.html`; navigate to Billing → SubscriptionSchedule group; confirm Schedules section reads clearly |
| `release/4` destructive-semantics warning is visible in generated docs | BILL-03 | Content-quality check | Inspect rendered `@doc` for `release/4` in `doc/LatticeStripe.SubscriptionSchedule.html`; confirm contrast with `cancel/4` is prominent |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
