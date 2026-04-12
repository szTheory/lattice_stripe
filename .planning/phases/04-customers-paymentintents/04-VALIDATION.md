---
phase: 04
slug: customers-paymentintents
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-02
---

# Phase 04 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | test/test_helper.exs |
| **Quick run command** | `mix test` |
| **Full suite command** | `mix test --warnings-as-errors` |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test`
- **After every plan wave:** Run `mix test --warnings-as-errors`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 3 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | CUST-01..06 | unit | `mix test test/lattice_stripe/customer_test.exs` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 2 | PINT-01..07 | unit | `mix test test/lattice_stripe/payment_intent_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/lattice_stripe/customer_test.exs` — stubs for CUST-01..06
- [ ] `test/lattice_stripe/payment_intent_test.exs` — stubs for PINT-01..07

*Existing test infrastructure (test_helper.exs, Mox setup, MockTransport) covers all framework requirements.*

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 3s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
