---
phase: 49
slug: tax-calculation-transaction-core
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 49 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` (Mox already configured) |
| **Quick run command** | `mix test test/lattice_stripe/tax/calculation_test.exs test/lattice_stripe/tax/transaction_test.exs --no-start` |
| **Full suite command** | `mix test test/lattice_stripe/tax/ --no-start` |
| **Estimated runtime** | ~20 seconds |

---

## Sampling Rate

- **After every task commit:** Run task-level `<automated>` verify from PLAN.md
- **After every plan wave:** Run full `mix test test/lattice_stripe/tax/ --no-start`
- **Before `/gsd-verify-work`:** Full tax suite + `mix compile --warnings-as-errors` green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 49-01-01 | 01 | 1 | CALC-01 | — | N/A | unit | `mix test test/lattice_stripe/tax/calculation_test.exs --no-start` | ⬜ W0 | ⬜ pending |
| 49-01-02 | 01 | 1 | CALC-02, CALC-03 | — | N/A | unit | same | ⬜ W0 | ⬜ pending |
| 49-02-01 | 02 | 2 | TXN-01..04 | — | N/A | unit | `mix test test/lattice_stripe/tax/transaction_test.exs --no-start` | ⬜ W0 | ⬜ pending |
| 49-02-02 | 02 | 2 | DX-03 (moduledoc) | — | N/A | grep | `mix test test/lattice_stripe/tax/ --no-start` | ⬜ W0 | ⬜ pending |
| 49-03-01 | 03 | 2 | DX-03 | — | N/A | integration-mox | `mix test test/lattice_stripe/tax/calculation_transaction_test.exs --no-start` | ⬜ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements:
- [x] Mox `LatticeStripe.MockTransport` — configured in `test/test_helper.exs`
- [x] `LatticeStripe.TestHelpers` — `test_client/0`, `ok_response/1`
- [x] CreditNote/Quote precedents for `list_line_items` and fixtures

New files created by plans (not Wave 0 stubs):
- `test/support/fixtures/tax_calculation.ex`
- `test/support/fixtures/tax_transaction.ex`
- `test/lattice_stripe/tax/*.exs`

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
