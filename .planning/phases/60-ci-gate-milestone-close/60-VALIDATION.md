---
phase: 60
slug: ci-gate-milestone-close
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 60 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/lattice_stripe/docs_truth_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~5 seconds (docs_truth only); ~2–5 min full suite |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/docs_truth_test.exs` when test files unchanged; skip if only workflow/planning edits
- **After Plan 60-01 (CI workflow):** `rg` ci.yml paths-ignore + CONTRIBUTING grep
- **After every plan wave:** Run `mix test test/lattice_stripe/docs_truth_test.exs`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 60-01-01 | 01 | 1 | CI-01 | T-60-01 / — | paths-ignore only `.planning/**` | grep | `rg -A3 'paths-ignore' .github/workflows/ci.yml` | ✅ | ⬜ pending |
| 60-01-02 | 01 | 1 | CI-01 | — | CONTRIBUTING reflects CI runs on docs | grep | `rg -n 'docs_truth' CONTRIBUTING.md` | ✅ | ⬜ pending |
| 60-01-03 | 01 | 1 | CI-01 | — | STATE clears CI-01 blocker | grep | `rg -n 'CI-01' .planning/STATE.md` | ✅ | ⬜ pending |
| 60-02-01 | 02 | 2 | JTBD-01 | — | Hosted checkout Strong | grep | `rg -n 'Hosted checkout.*Strong' .planning/JTBD-MAP.md` | ✅ | ⬜ pending |
| 60-02-02 | 02 | 2 | JTBD-01 | — | Gap 3 removed | grep | `! rg -n 'Gap 3:' .planning/JTBD-MAP.md` | ✅ | ⬜ pending |
| 60-02-03 | 02 | 2 | JTBD-01 | — | Maintenance-first priority | grep | `rg -n 'Maintenance mode' .planning/JTBD-MAP.md` | ✅ | ⬜ pending |
| 60-02-04 | 02 | 2 | JTBD-01 | — | 60-VERIFICATION.md exists | file | `test -f .planning/phases/60-ci-gate-milestone-close/60-VERIFICATION.md` | ⬜ | ⬜ pending |
| 60-02-05 | 02 | 2 | JTBD-01 | — | v1.9 audit exists | file | `test -f .planning/milestones/v1.9-MILESTONE-AUDIT.md` | ⬜ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

- [x] `test/lattice_stripe/docs_truth_test.exs` — 26 tests from Phase 59
- [x] `.github/workflows/ci.yml` — edit target exists
- [x] ExUnit via Mix — no install needed

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| GitHub Actions triggers on doc-only PR | CI-01 | Requires GitHub runner | Open test PR touching only `guides/checkout.md`; confirm lint + test jobs run |

*Optional post-merge smoke — not blocking plan acceptance if workflow YAML is correct.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
