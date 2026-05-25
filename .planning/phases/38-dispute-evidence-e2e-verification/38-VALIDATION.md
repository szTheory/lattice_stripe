---
phase: 38
slug: dispute-evidence-e2e-verification
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-25
---

# Phase 38 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with existing integration split under `test/integration/` |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/integration/dispute_integration_test.exs --include integration` |
| **Supporting regression** | `mix test test/lattice_stripe/dispute_test.exs test/integration/file_integration_test.exs --include integration` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~30 seconds targeted; longer if full suite is rerun |

---

## Sampling Rate

- **After every task commit:** Run the task’s `<automated>` command
- **After every plan wave:** Run the wave-level command listed below
- **Before `/gsd-verify-work`:** Run `mix test --include integration test/integration/dispute_integration_test.exs test/integration/file_integration_test.exs`
- **Max feedback latency:** ~30 seconds for the targeted integration path

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 38-01-01 | 01 | 1 | FILE-01, DISP-04 | T-38-01 | Uploaded file IDs can be staged into dispute evidence without malformed request encoding | integration | `mix test test/integration/dispute_integration_test.exs --include integration` | ❌ W0 | ⬜ pending |
| 38-01-02 | 01 | 1 | DISP-05 | T-38-02 | `submit_evidence/3` reaches Stripe with the expected irreversible submit path after staging | integration | `mix test test/integration/dispute_integration_test.exs --include integration` | ❌ W0 | ⬜ pending |
| 38-01-03 | 01 | 1 | DISP-01, DISP-02, DISP-03 | T-38-03 | Dispute retrieve/list/update/close integration smoke coverage matches the shipped resource surface | integration | `mix test test/integration/dispute_integration_test.exs --include integration` | ❌ W0 | ⬜ pending |
| 38-02-01 | 02 | 2 | FILE-01, FILE-02, FILE-03, FILE-04, FILE-05 | T-38-04 | Phase 32 verification report cites current automated/integration evidence and exits `human_needed` state | docs + evidence audit | `rg -n "status:|FILE-0[1-5]|human_needed|closed|verified" .planning/phases/32-file-filelink/32-VERIFICATION.md` | ✅ | ⬜ pending |
| 38-02-02 | 02 | 2 | DISP-01, DISP-02, DISP-03, DISP-04, DISP-05, DISP-06, DISP-07 | T-38-05 | Phase 33 verification report exists, is closed, and cites both unit and integration evidence | docs + evidence audit | `rg -n "status:|DISP-0[1-7]" .planning/phases/33-disputes/33-VERIFICATION.md` | ❌ W0 | ⬜ pending |
| 38-02-03 | 02 | 2 | FILE-01, FILE-02, FILE-03, FILE-04, FILE-05, DISP-01, DISP-02, DISP-03, DISP-04, DISP-05, DISP-06, DISP-07 | T-38-06 | Requirement traceability reflects the new milestone-ready evidence instead of stale `Pending` rows | docs + traceability audit | `rg -n "FILE-0[1-5]|DISP-0[1-7]" .planning/REQUIREMENTS.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave-Level Verification

- **After Plan 01:** `mix test test/integration/dispute_integration_test.exs --include integration`
- **After Plan 02:** `rg -n "status:|FILE-0[1-5]|DISP-0[1-7]" .planning/phases/32-file-filelink/32-VERIFICATION.md .planning/phases/33-disputes/33-VERIFICATION.md .planning/REQUIREMENTS.md`

---

## Wave 0 Requirements

- [ ] `test/integration/dispute_integration_test.exs`
- [ ] closed-status `.planning/phases/33-disputes/33-VERIFICATION.md`
- [ ] updated `.planning/phases/32-file-filelink/32-VERIFICATION.md`
- [ ] updated FILE/DISP traceability rows in `.planning/REQUIREMENTS.md`

*Existing ExUnit integration infrastructure covers the rest.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `stripe-mock` is running and reachable on `localhost:12111` during Plan 01 | FILE-01, DISP-04, DISP-05 | External Docker service cannot be guaranteed by static file review | Start `stripe/stripe-mock`, run the targeted integration suite, and confirm the dispute evidence flow passes without local transport hacks |
| Verification reports are milestone-credible, not merely present | FILE-01..05, DISP-01..07 | Humans must judge whether the cited evidence actually answers the audit findings | Read the updated `32-VERIFICATION.md` and new `33-VERIFICATION.md` and confirm each requirement row ties to current tests/summaries rather than copy-pasted prior claims |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references
- [x] No watch-mode flags
- [x] Feedback latency acceptable for targeted integration work
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-25
