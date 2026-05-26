---
phase: 46
slug: flagship-recipes-ii-planning-truth-closure
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-26
---

# Phase 46 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit |
| **Config file** | none; standard Mix/ExUnit layout |
| **Quick run command** | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors`
- **After every plan wave:** Run `mix test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 46-01-01 | 01 | 1 | RECIPE-03 | T-46-01 | Connect flagship guide keeps Express onboarding, destination charges, bearer-link handling, and webhook-owned truth explicit | docs-truth + grep | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 46-01-02 | 01 | 1 | RECIPE-04 | T-46-02 | Quote flagship guide keeps bounded downstream inspection and explicit proof-boundary wording | docs-truth + grep | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 46-02-01 | 02 | 2 | PLAN-01 | T-46-03 | Planning artifacts state v1.4 is close-ready while Phase `41.1` remains `pending-external-verification` | grep-backed artifact verification | `rg -n 'close-ready|pending-external-verification|Phase 41\\.1|adoption-closure|Phase 46' .planning/PROJECT.md .planning/ROADMAP.md .planning/REQUIREMENTS.md .planning/STATE.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/lattice_stripe/docs_truth_test.exs` — add assertions for the two new flagship guide filenames, docs extras membership, and `Flagship Recipes` grouping
- [ ] `test/lattice_stripe/docs_truth_test.exs` — add routing assertions from `guides/recipes.md` and `guides/user-flows-and-jtbd.md` into both new flagship guides
- [ ] `test/lattice_stripe/docs_truth_test.exs` — add durable truth assertions for Connect and Quote flagship guide anchor phrases

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Milestone-close wording feels truthful without over-narrating planning history | PLAN-01 | Exact wording quality and emphasis are editorial, not fully machine-checkable | Read `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, and `.planning/STATE.md` together; confirm v1.4 closure language stays explicit and Phase `41.1` remains a named external-proof boundary |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-26
