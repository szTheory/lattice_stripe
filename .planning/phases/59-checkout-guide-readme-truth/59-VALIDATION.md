---
phase: 59
slug: checkout-guide-readme-truth
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-27
---

# Phase 59 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/lattice_stripe/docs_truth_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~5 seconds (docs_truth only) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/docs_truth_test.exs`
- **After every plan wave:** Run `mix test test/lattice_stripe/docs_truth_test.exs`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 59-01-01 | 01 | 1 | CHECKOUT-02 | T-59-01 / — | Callout explains struct atoms vs wire strings | grep + test | `rg 'Status values:' guides/checkout.md` | ✅ | ⬜ pending |
| 59-01-02 | 01 | 1 | CHECKOUT-01 | T-59-01 / — | Stream filter uses atom compare | grep + test | `rg 'payment_status == :paid' guides/checkout.md` | ✅ | ⬜ pending |
| 59-02-01 | 02 | 2 | README-01 | — | README lists canonical error atoms | grep | `rg ':authentication_error' README.md` | ✅ | ⬜ pending |
| 59-02-02 | 02 | 2 | CHECKOUT-03, VERIFY-05 | T-59-02 / — | docs_truth locks checkout atoms | unit | `mix test test/lattice_stripe/docs_truth_test.exs --only describe:"guides/checkout.md"` | ✅ | ⬜ pending |
| 59-02-03 | 02 | 2 | README-02, VERIFY-05 | — | docs_truth locks README error atoms | unit | `mix test test/lattice_stripe/docs_truth_test.exs --only describe:"README.md"` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — ExUnit and `docs_truth_test.exs` already exist from Phase 57.

- [x] `test/lattice_stripe/docs_truth_test.exs` — payments describe precedent
- [x] ExUnit via Mix — no install needed

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Callout prose readability | CHECKOUT-02 | Subjective UX | Skim callout in rendered markdown; confirm fulfillment note present |

*All critical behaviors have automated grep/test verification.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
