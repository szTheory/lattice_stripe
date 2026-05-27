---
phase: 57
slug: payments-guide-charge-routing
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-27
---

# Phase 57 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `mix.exs` — `test_paths: ["test"]` |
| **Quick run command** | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` |
| **Full suite command** | `mix test --warnings-as-errors` |
| **Estimated runtime** | ~2–5 seconds (docs_truth only) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors`
- **After every plan wave:** Run `mix test --warnings-as-errors`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 57-01-01 | 01 | 1 | VERIFY-04 | — | N/A | unit | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 57-01-02 | 01 | 1 | VERIFY-04 | — | N/A | unit | same | ✅ | ⬜ pending |
| 57-02-01 | 02 | 2 | GUIDE-01, GUIDE-02 | — | N/A | unit | same | ✅ | ⬜ pending |
| 57-02-02 | 02 | 2 | GUIDE-03 | — | N/A | unit | same | ✅ | ⬜ pending |
| 57-02-03 | 02 | 2 | ROUTE-01 | — | N/A | unit | same | ✅ | ⬜ pending |
| 57-03-01 | 03 | 3 | ROUTE-02 | — | N/A | unit + grep | same + `rg update/4 guides/production-checklist.md guides/event-debugging.md` | ✅ | ⬜ pending |
| 57-03-02 | 03 | 3 | ROUTE-02 | — | N/A | unit | docs_truth optional operator asserts | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — no Wave 0 tasks.

- [x] `test/lattice_stripe/docs_truth_test.exs` — docs regression harness
- [x] ExUnit via Mix — no new framework install

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Charge section editorial polish (~55 lines) | ROUTE-01 | Readability not grep-locked | Skim `guides/payments.md` Charge section for PI-first framing and no moduledoc wholesale paste |

All phase behaviors have automated verification for copy-paste API contracts.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 10s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
