---
phase: 43
slug: public-truth-baseline
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-26
---

# Phase 43 - Validation Strategy

> Per-phase validation contract for public docs truth and onboarding-surface regression coverage.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit plus grep-backed file assertions |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | ~10-30 seconds for targeted docs-truth checks |

## Sampling Rate

- After each task commit: run the task's `<automated>` command
- After each plan wave: `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors`
- Before `$gsd-verify-work`: rerun targeted docs-truth tests and the phase grep assertions across the touched public docs files

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 43-01-01 | 01 | 1 | TRUTH-01 | T-43-01 | README, Getting Started, cheatsheet, and changelog agree on the current published package line | grep | `rg -n '~> 1\\.[23]|1\\.3\\.0|1\\.3\\.x|published surface' README.md CHANGELOG.md guides/getting-started.md guides/cheatsheet.cheatmd mix.exs` | ✅ | ⬜ pending |
| 43-01-02 | 01 | 1 | TRUTH-02 | T-43-02 | High-visibility docs name the shipped v1.3 surface without understating it | grep | `rg -n 'File/FileLink|Disputes|Credit Notes|Mandates|SetupAttempts|Quotes|recipes|webhook' README.md CHANGELOG.md guides/getting-started.md guides/cheatsheet.cheatmd` | ✅ | ⬜ pending |
| 43-02-01 | 02 | 2 | VERIFY-01 | T-43-03 | Docs-truth regression tests fail when onboarding/version snippets drift from the shipped package line | unit | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` | ✅ | ⬜ pending |

## Wave-Level Verification

- After Plan 01: `rg -n '~> 1\\.3|1\\.3\\.0|1\\.3\\.x' README.md CHANGELOG.md guides/getting-started.md guides/cheatsheet.cheatmd mix.exs`
- After Plan 02: `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors`
- Before verification handoff: `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors && rg -n 'recipes\\.html|guides/getting-started\\.md|guides/cheatsheet\\.cheatmd|~> 1\\.3' test/lattice_stripe/docs_truth_test.exs README.md guides/getting-started.md guides/cheatsheet.cheatmd mix.exs`

## Wave 0 Requirements

- [ ] `.planning/phases/43-public-truth-baseline/43-01-PLAN.md` exists
- [ ] `.planning/phases/43-public-truth-baseline/43-02-PLAN.md` exists

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Public docs still read coherently after truth alignment | TRUTH-01, TRUTH-02 | Grep can prove snippets exist but not whether the onboarding story feels misleading | Read README and Getting Started top-to-bottom and confirm the version/package/install story is consistent and natural |
| Regression checks focus on durable truth, not fragile prose | VERIFY-01 | Only a human can judge whether assertions are over-coupled to wording | Read `test/lattice_stripe/docs_truth_test.exs` and confirm the tests assert stable facts like version snippets, published surfaces, and docs metadata rather than large narrative paragraphs |

## Validation Sign-Off

- [x] All tasks have automated verification
- [x] Sampling continuity is adequate for a small docs-truth phase
- [x] No watch-mode or interactive dependencies
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-26
