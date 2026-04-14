---
phase: 20
slug: billing-metering
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-14
---

# Phase 20 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) + Mox ~> 1.2 |
| **Config file** | `test/test_helper.exs` (exists — Mox defined) |
| **Quick run command** | `mix test test/lattice_stripe/billing/` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick command scoped to touched files
- **After every plan wave:** Run `mix test` full suite
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 20-01-01 | 01 | 0 | TEST-01 | — | Wave 0 scaffolding — stripe-mock endpoint probe | probe | `mix run scripts/verify_meter_endpoints.exs` | ✅ W0 | ⬜ pending |
| 20-02-01 | 02 | 1 | METER-01 | — | Billing.Meter struct round-trips from Stripe payload | unit | `mix test test/lattice_stripe/billing/meter_test.exs` | ✅ W0 | ⬜ pending |
| 20-02-02 | 02 | 1 | METER-02 | — | Nested ValueSettings + CustomerMapping + StatusTransitions decode | unit | `mix test test/lattice_stripe/billing/meter_test.exs` | ✅ W0 | ⬜ pending |
| 20-03-01 | 03 | 2 | METER-03..06 | — | Meter CRUD (create, retrieve, update, list) against stripe-mock | integration | `mix test test/lattice_stripe/billing/meter_integration_test.exs` | ✅ W0 | ⬜ pending |
| 20-03-02 | 03 | 2 | METER-07, METER-08 | — | deactivate/reactivate lifecycle | integration | `mix test test/lattice_stripe/billing/meter_integration_test.exs` | ✅ W0 | ⬜ pending |
| 20-03-03 | 03 | 2 | GUARD-01 | T-20-01 silent-zero | check_meter_value_settings!/1 raises on sum/last with malformed value_settings | unit | `mix test test/lattice_stripe/billing/meter_guards_test.exs` | ✅ W0 | ⬜ pending |
| 20-04-01 | 04 | 2 | EVENT-01, EVENT-02 | — | MeterEvent.create/3 with body `identifier` + `idempotency_key:` opt | unit + integration | `mix test test/lattice_stripe/billing/meter_event_test.exs` | ✅ W0 | ⬜ pending |
| 20-04-02 | 04 | 2 | EVENT-03 | T-20-02 async ack | @doc explicitly states {:ok, ...} is async ack, cross-links webhook | doc test | `mix docs && grep -q "accepted for processing" doc/LatticeStripe.Billing.MeterEvent.html` | ❌ W0 | ⬜ pending |
| 20-04-03 | 04 | 2 | GUARD-02 | T-20-03 payload masking | Inspect protocol masks payload values | unit | `mix test test/lattice_stripe/billing/meter_event_test.exs` | ✅ W0 | ⬜ pending |
| 20-05-01 | 05 | 2 | EVENT-04, EVENT-05 | T-20-04 cancel.identifier | MeterEventAdjustment nested cancel.identifier round-trip | unit | `mix test test/lattice_stripe/billing/meter_event_adjustment_test.exs` | ✅ W0 | ⬜ pending |
| 20-05-02 | 05 | 2 | GUARD-03 | — | check_adjustment_cancel_shape!/1 raises on top-level identifier | unit | `mix test test/lattice_stripe/billing/meter_guards_test.exs` | ✅ W0 | ⬜ pending |
| 20-06-01 | 06 | 3 | DOCS-01, DOCS-03 | — | guides/metering.md exists with required sections (Monitoring, Idempotency, Backdating, AccrueLike) | doc test | `test -f guides/metering.md && grep -q "error_report_triggered" guides/metering.md` | ❌ W0 | ⬜ pending |
| 20-06-02 | 06 | 3 | DOCS-04 | — | ExDoc groups_for_modules includes "Billing Metering" group | build | `mix docs 2>&1 \| grep -vq warning` | ❌ W0 | ⬜ pending |
| 20-06-03 | 06 | 3 | TEST-03, TEST-05 | — | All metering tests tagged + credo clean | style | `mix credo --strict lib/lattice_stripe/billing/` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `scripts/verify_meter_endpoints.exs` — stripe-mock endpoint availability probe for all 7 metering endpoints
- [x] `test/lattice_stripe/billing/meter_test.exs` — unit stubs for METER-01..02
- [x] `test/lattice_stripe/billing/meter_integration_test.exs` — integration stubs for METER-03..08
- [x] `test/lattice_stripe/billing/meter_guards_test.exs` — stubs for GUARD-01, GUARD-03
- [x] `test/lattice_stripe/billing/meter_event_test.exs` — stubs for EVENT-01..03, GUARD-02
- [x] `test/lattice_stripe/billing/meter_event_adjustment_test.exs` — stubs for EVENT-04..05
- [x] `test/support/fixtures/metering.ex` — shared Stripe payload fixtures (meter, meter_event, meter_event_adjustment) — matches existing test/support/fixtures/ pattern

*ExUnit + Mox infrastructure already exists; Wave 0 only adds new test files and the Wave 0 probe script.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `identifier`-based dedup in production | EVENT-02 | stripe-mock is stateless — cannot replay identifier to verify Stripe's server-side dedup | Against real test-mode key: post two MeterEvents with identical `identifier`, verify Stripe returns the first payload both times |
| 24h adjustment backdating window | EVENT-04 | stripe-mock does not enforce the window | Against real test-mode key: post adjustment with `cancel.identifier` > 24h old, verify `out_of_window` error code |
| `archived_meter` error after deactivate | METER-07 | stripe-mock allows events post-deactivate | Against real test-mode key: deactivate meter, post event, verify webhook error `archived_meter` |
| Webhook `v1.billing.meter.error_report_triggered` delivery | DOCS-03 | Requires real Stripe webhook endpoint | Documented in guides/metering.md Monitoring section with error code table |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
