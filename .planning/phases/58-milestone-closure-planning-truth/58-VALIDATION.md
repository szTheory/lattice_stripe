---
phase: 58
slug: milestone-closure-planning-truth
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 58 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) + planning grep checks |
| **Config file** | `mix.exs` test_paths: ["test"] |
| **Quick run command** | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` |
| **Full suite command** | `mix test --warnings-as-errors` |
| **Estimated runtime** | ~5–15 seconds (docs_truth + adoption contract; integration requires stripe-mock) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors`
- **After every plan wave:** Run `mix test test/lattice_stripe/tax/adoption_contract_test.exs --warnings-as-errors` (wave 3+)
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 58-01-01 | 01 | 1 | ROUTE-03 | — | N/A | grep | `rg -n "payments\.md has API example bugs\|getting-started prose drift\|Gap 1: Doc-routing" .planning/JTBD-MAP.md` → no matches | ✅ | ⬜ pending |
| 58-01-02 | 01 | 1 | ROUTE-03 | — | N/A | grep | `rg -n "maintenance mode\|Doc-routing polish closed in v1.8" .planning/JTBD-MAP.md` → matches | ✅ | ⬜ pending |
| 58-02-01 | 02 | 2 | PLAN-01 | — | N/A | grep | `rg -n "Resolved in v1.8" .planning/MILESTONES.md` → match | ✅ | ⬜ pending |
| 58-02-02 | 02 | 2 | PLAN-01 | — | N/A | grep | `rg -n "## v1.8 Adopter Truth" .planning/MILESTONES.md` → match | ✅ | ⬜ pending |
| 58-02-03 | 02 | 2 | PLAN-02 | — | N/A | grep | `rg -n "## Milestone: v1.8" .planning/RETROSPECTIVE.md` → match | ✅ | ⬜ pending |
| 58-03-01 | 03 | 3 | PROOF-01 | — | N/A | unit | `mix test test/lattice_stripe/tax/adoption_contract_test.exs --warnings-as-errors` → 8 tests, 0 failures | ✅ | ⬜ pending |
| 58-03-02 | 03 | 3 | PROOF-01 | — | N/A | integration | `mix test test/integration/tax_id_integration_test.exs --include integration` → 2 tests, 0 failures | ✅ | ⬜ pending |
| 58-03-03 | 03 | 3 | PROOF-01 | — | N/A | git | `git ls-files test/lattice_stripe/tax/adoption_contract_test.exs test/integration/tax_id_integration_test.exs .github/workflows/ci.yml` → 3 files | ✅ | ⬜ pending |
| 58-04-01 | 04 | 4 | SC #5 | — | N/A | file | `test -f .planning/milestones/v1.8-MILESTONE-AUDIT.md` → exists | ⬜ | ⬜ pending |
| 58-05-01 | 05 | 5 | SC #5 | — | N/A | grep | `rg -n "status: maintenance" .planning/STATE.md` → match | ✅ | ⬜ pending |
| 58-05-02 | 05 | 5 | SC #5 | — | N/A | file | `test -f .planning/milestones/v1.8-ROADMAP.md && test -f .planning/milestones/v1.8-REQUIREMENTS.md` → both exist | ⬜ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing infrastructure covers all phase requirements — ExUnit, docs_truth_test, stripe-mock integration pattern established

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Milestone audit aggregation | SC #5 | `/gsd-audit-milestone v1.8` is orchestrator workflow | Run audit; verify v1.8-MILESTONE-AUDIT.md status PASSED |
| complete-milestone archive | SC #5 | GSD workflow command | Run `/gsd-complete-milestone v1.8`; verify archive files and posture flip |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
