---
phase: 42
slug: planning-truth-reconciliation
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-25
---

# Phase 42 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with repo-local docs-truth tests and grep-backed artifact assertions |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/testing_test.exs test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | ~30 seconds for targeted checks; `mix ci` is longer and currently includes unrelated red docs warnings |

---

## Sampling Rate

- **After every task commit:** Run the narrow command that matches the edited artifact family, plus a focused `rg` assertion on the touched planning file
- **After every plan wave:** `mix test test/lattice_stripe/testing_test.exs test/lattice_stripe/docs_truth_test.exs --warnings-as-errors`
- **Before `$gsd-verify-work`:** Targeted DX tests must be green, `37-VERIFICATION.md` must exist with `status: closed`, and the reconciled planning artifacts must pass grep-backed truth checks
- **Max feedback latency:** ~30 seconds for targeted checks

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 42-01-01 | 01 | 1 | DX-01, DX-02, DX-03, DX-04 | T-42-01 | `37-VERIFICATION.md` closes only shipped DX evidence, uses existing verifier vocabulary, and does not claim new SDK behavior | unit + docs artifact + grep | `mix test test/lattice_stripe/testing_test.exs test/lattice_stripe/docs_truth_test.exs --warnings-as-errors && rg -n 'status: closed|DX-0[1-4]|37-0[123]-SUMMARY|testing_test|docs_truth_test|pending-external-verification|mix docs --warnings-as-errors' .planning/phases/37-dx-polish/37-VERIFICATION.md` | ❌ W0 | ⬜ pending |
| 42-02-01 | 02 | 2 | DX-01, DX-02, DX-03, DX-04 | T-42-02 | `ROADMAP.md`, `REQUIREMENTS.md`, and `STATE.md` propagate verifier truth without erasing the open `41.1` external-proof boundary | unit + grep | `mix test test/lattice_stripe/testing_test.exs test/lattice_stripe/docs_truth_test.exs --warnings-as-errors && rg -n 'DX-0[1-4]|Phase 35|Phase 36|Phase 37|Phase 40|Phase 41\\.1|pending-external-verification|Verified|Plans:' .planning/ROADMAP.md .planning/REQUIREMENTS.md .planning/STATE.md` | ✅ | ⬜ pending |
| 42-02-03 | 02 | 2 | DX-01, DX-02, DX-03, DX-04 | T-42-03 | The milestone audit states that planning truth now matches repo reality while explicitly naming the remaining external-proof gap | grep | `rg -n 'planning truth|repo reality|pending-external-verification|Phase 41\\.1|37-VERIFICATION.md|DX-0[1-4]|gaps_found|pass|external-proof' .planning/v1.3-v1.3-MILESTONE-AUDIT.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave-Level Verification

- **After Plan 01:** `mix test test/lattice_stripe/testing_test.exs test/lattice_stripe/docs_truth_test.exs --warnings-as-errors`
- **After Plan 02:** `mix test test/lattice_stripe/testing_test.exs test/lattice_stripe/docs_truth_test.exs --warnings-as-errors && rg -n 'DX-0[1-4]|Phase 35|Phase 36|Phase 37|Phase 40|Phase 41\\.1|pending-external-verification|Verified|Plans:' .planning/ROADMAP.md .planning/REQUIREMENTS.md .planning/STATE.md`
- **After Plan 02:** `mix test test/lattice_stripe/testing_test.exs test/lattice_stripe/docs_truth_test.exs --warnings-as-errors && rg -n 'status: closed|DX-0[1-4]|pending-external-verification|Phase 41\\.1|planning truth|repo reality' .planning/phases/37-dx-polish/37-VERIFICATION.md .planning/ROADMAP.md .planning/REQUIREMENTS.md .planning/STATE.md .planning/v1.3-v1.3-MILESTONE-AUDIT.md`

---

## Wave 0 Requirements

- [ ] `.planning/phases/37-dx-polish/37-VERIFICATION.md` — missing and required before any downstream planning-truth propagation
- [ ] explicit audit-refresh task in the plan — no dedicated milestone-audit regeneration command exists in the repo

*Existing ExUnit and artifact-grep infrastructure covers the rest.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Roadmap status language still reads as truthful plain English after reconciliation | DX-01, DX-02, DX-03, DX-04 | Grep can prove strings exist but not whether the milestone story is misleading | Read the v1.3 progress rows and Phase 42 section in `.planning/ROADMAP.md`; confirm `41.1` stays explicitly open and phases 35-37 no longer understate shipped/closed work |
| Refreshed audit verdict is narrow and honest | DX-04 | Only a human can judge whether the verdict hides the external-proof nuance | Read `.planning/v1.3-v1.3-MILESTONE-AUDIT.md` top to bottom and confirm it says planning truth matches repo reality while one environment-bound proof remains open |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references
- [x] No watch-mode flags
- [x] Feedback latency acceptable for planning-doc reconciliation work
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-25
