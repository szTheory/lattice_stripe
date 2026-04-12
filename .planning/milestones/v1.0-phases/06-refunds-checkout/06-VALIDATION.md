---
phase: 6
slug: refunds-checkout
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-02
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/refund_test.exs test/lattice_stripe/checkout/session_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command for the resource being modified
- **After every plan wave:** Run `mix test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | - | refactor | `mix test` | ✅ | ⬜ pending |
| 06-01-02 | 01 | 1 | RFND-01 | unit | `mix test test/lattice_stripe/refund_test.exs` | ❌ W0 | ⬜ pending |
| 06-01-03 | 01 | 1 | RFND-02 | unit | `mix test test/lattice_stripe/refund_test.exs` | ❌ W0 | ⬜ pending |
| 06-01-04 | 01 | 1 | RFND-03 | unit | `mix test test/lattice_stripe/refund_test.exs` | ❌ W0 | ⬜ pending |
| 06-01-05 | 01 | 1 | RFND-04 | unit | `mix test test/lattice_stripe/refund_test.exs` | ❌ W0 | ⬜ pending |
| 06-02-01 | 02 | 1 | CHKT-01, CHKT-02, CHKT-03, CHKT-04 | unit | `mix test test/lattice_stripe/checkout/session_test.exs` | ❌ W0 | ⬜ pending |
| 06-02-02 | 02 | 1 | CHKT-05 | unit | `mix test test/lattice_stripe/checkout/session_test.exs` | ❌ W0 | ⬜ pending |
| 06-02-03 | 02 | 1 | CHKT-06 | unit | `mix test test/lattice_stripe/checkout/session_test.exs` | ❌ W0 | ⬜ pending |
| 06-02-04 | 02 | 1 | CHKT-07 | unit | `mix test test/lattice_stripe/checkout/session_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/support/fixtures/customer.ex` — LatticeStripe.Test.Fixtures.Customer (extracted from customer_test.exs)
- [ ] `test/support/fixtures/payment_intent.ex` — LatticeStripe.Test.Fixtures.PaymentIntent
- [ ] `test/support/fixtures/setup_intent.ex` — LatticeStripe.Test.Fixtures.SetupIntent
- [ ] `test/support/fixtures/payment_method.ex` — LatticeStripe.Test.Fixtures.PaymentMethod
- [ ] `test/support/fixtures/refund.ex` — LatticeStripe.Test.Fixtures.Refund
- [ ] `test/support/fixtures/checkout_session.ex` — LatticeStripe.Test.Fixtures.Checkout.Session
- [ ] `test/support/fixtures/checkout_line_item.ex` — LatticeStripe.Test.Fixtures.Checkout.LineItem
- [ ] `test/lattice_stripe/refund_test.exs` — Refund resource tests
- [ ] `test/lattice_stripe/checkout/session_test.exs` — Checkout.Session resource tests

*Existing infrastructure (ExUnit, Mox, MockTransport, TestHelpers) covers framework needs.*

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
