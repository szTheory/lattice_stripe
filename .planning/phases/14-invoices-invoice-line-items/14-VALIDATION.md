---
phase: 14
slug: invoices-invoice-line-items
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-12
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/invoice_test.exs test/lattice_stripe/invoice_item_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/invoice_test.exs test/lattice_stripe/invoice_item_test.exs`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | BILL-04 | — | N/A | unit | `mix test test/lattice_stripe/invoice_test.exs` | ❌ W0 | ⬜ pending |
| 14-01-02 | 01 | 1 | BILL-04b | — | N/A | unit | `mix test test/lattice_stripe/invoice/line_item_test.exs` | ❌ W0 | ⬜ pending |
| 14-02-01 | 02 | 1 | BILL-04c | — | N/A | unit | `mix test test/lattice_stripe/invoice_item_test.exs` | ❌ W0 | ⬜ pending |
| 14-03-01 | 03 | 2 | BILL-10 | — | N/A | unit | `mix test test/lattice_stripe/billing/guards_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/lattice_stripe/invoice_test.exs` — stubs for BILL-04
- [ ] `test/lattice_stripe/invoice/line_item_test.exs` — stubs for BILL-04b
- [ ] `test/lattice_stripe/invoice_item_test.exs` — stubs for BILL-04c
- [ ] `test/lattice_stripe/billing/guards_test.exs` — stubs for BILL-10

*Existing infrastructure covers test framework and helpers.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Auto-advance telemetry Logger.warning | BILL-04 | Logger output inspection | Create invoice without auto_advance, verify warning appears in console |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
