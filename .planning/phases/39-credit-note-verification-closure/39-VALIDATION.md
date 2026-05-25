---
phase: 39
slug: credit-note-verification-closure
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-25
---

# Phase 39 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with existing `stripe-mock` integration split under `test/integration/` |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/credit_note_test.exs` |
| **Supporting integration** | `mix test test/integration/credit_note_integration_test.exs --include integration` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~30 seconds targeted; longer if a broader supporting run is chosen |

---

## Sampling Rate

- **After every task commit:** Run the task's `<automated>` command
- **After every plan wave:** Run the wave-level command listed below
- **Before `/gsd-verify-work`:** Run the targeted unit and integration CreditNote commands and capture their current output in `34-VERIFICATION.md`
- **Max feedback latency:** ~30 seconds for the scoped closure path

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 39-01-01 | 01 | 1 | CRDN-01, CRDN-02, CRDN-03, CRDN-04, CRDN-05, CRDN-06 | T-39-01 | Unit proof for API surface, line-item parser behavior, and helper coverage is current and trustworthy | unit | `mix test test/lattice_stripe/credit_note_test.exs` | ✅ | ⬜ pending |
| 39-01-02 | 01 | 1 | CRDN-01, CRDN-02, CRDN-03, CRDN-04, CRDN-05 | T-39-02 | Integration proof remains current under `stripe-mock` without overstating real Stripe lifecycle semantics | integration | `mix test test/integration/credit_note_integration_test.exs --include integration` | ✅ | ⬜ pending |
| 39-02-01 | 02 | 2 | CRDN-01, CRDN-02, CRDN-03, CRDN-04, CRDN-05, CRDN-06 | T-39-03 | `34-VERIFICATION.md` exists, is closed, and cites fresh command evidence plus Phase 34 shipped summaries | docs + evidence audit | `rg -n "status:|CRDN-0[1-6]|credit_note_test|credit_note_integration_test|34-0[12]-SUMMARY" .planning/phases/34-creditnote/34-VERIFICATION.md` | ❌ W0 | ⬜ pending |
| 39-02-02 | 02 | 2 | CRDN-01, CRDN-02, CRDN-03, CRDN-04, CRDN-05, CRDN-06 | T-39-04 | CRDN traceability rows reflect verified milestone evidence instead of stale `Pending` state | docs + traceability audit | `rg -n "CRDN-0[1-6]" .planning/REQUIREMENTS.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave-Level Verification

- **After Plan 01:** `mix test test/lattice_stripe/credit_note_test.exs test/integration/credit_note_integration_test.exs --include integration`
- **After Plan 02:** `rg -n "status:|CRDN-0[1-6]" .planning/phases/34-creditnote/34-VERIFICATION.md .planning/REQUIREMENTS.md`

---

## Wave 0 Requirements

- [ ] closed-status `.planning/phases/34-creditnote/34-VERIFICATION.md`
- [ ] updated CRDN traceability rows in `.planning/REQUIREMENTS.md`

*Existing CreditNote implementation, guide, fixtures, and test modules already exist.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `stripe-mock` is running and reachable on `localhost:12111` during Plan 01 integration verification | CRDN-01, CRDN-02, CRDN-03, CRDN-04, CRDN-05 | External Docker service cannot be guaranteed by static file review | Start `stripe/stripe-mock`, run the targeted integration suite, and confirm the CreditNote flow passes without local transport hacks |
| The verifier language stays honest about the scope of proof | CRDN-01..06 | Humans must judge whether the report distinguishes resource-scoped proof from repo-wide health | Read `34-VERIFICATION.md` and confirm it cites exact commands/date, summarizes `stripe-mock` limits correctly, and does not claim a full repo verification that did not occur |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references
- [x] No watch-mode flags
- [x] Feedback latency acceptable for targeted verification-closure work
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-25
