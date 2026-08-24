---
phase: 62
slug: 1-1-1-7-what-landed-migration-guide
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-24
---

# Phase 62 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/docs_truth_test.exs` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | Quick: <10 seconds; full: use current `mix ci` baseline |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/docs_truth_test.exs`
- **After every plan wave:** Run `mix docs --warnings-as-errors`
- **Before `$gsd-verify-work`:** `mix ci` must be green
- **Max feedback latency:** 10 seconds for task-level sampling

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 62-01-01 | 01 | 1 | DOC-01 | T-62-01 / T-62-02 | Historical scope and webhook safety boundaries remain explicit | semantic docs regression | `mix test test/lattice_stripe/docs_truth_test.exs` | ✅ extend existing | ⬜ pending |
| 62-01-02 | 01 | 1 | DOC-01 | T-62-01 / T-62-03 | Guide is historically correct, complete, and routes to canonical safe flows | docs build | `mix docs --warnings-as-errors` | ✅ | ⬜ pending |
| 62-01-03 | 01 | 1 | DOC-01 | — | Project-wide regressions remain absent | full CI | `mix ci` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Extend `test/lattice_stripe/docs_truth_test.exs` with the focused historical-guide contract specified by D-13 and D-14 before relying on task-level semantic sampling.

---

## Manual-Only Verifications

All phase behaviors have automated verification. Human editorial review is useful but is not required to prove the fixed historical claims, ExDoc placement, content anchors, or build health.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10 seconds for task-level sampling
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
