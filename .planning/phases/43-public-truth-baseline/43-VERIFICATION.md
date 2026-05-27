---
phase: 43-public-truth-baseline
verified: 2026-05-27T06:22:03Z
status: passed
score: 4/4
overrides_applied: 0
re_verification: false
backfilled: true
backfilled_during: v1.4 milestone audit (2026-05-27)
---

# Phase 43: Public Truth Baseline Verification Report

**Phase Goal:** Align public package, version, install, and shipped-surface truth across the highest-visibility onboarding documents, and encode that contract in the docs-truth regression suite so first-run drift fails fast.
**Verified:** 2026-05-27T06:22:03Z
**Status:** PASSED
**Re-verification:** No
**Note:** Backfilled during the v1.4 milestone audit. The original phase shipped on SUMMARY evidence + a passing `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` run. The v1.4 integration checker independently re-verified the same anchors against the live working tree.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | README, Getting Started, cheatsheet, mix.exs, and CHANGELOG all agree on the shipped `1.3.x` package line | VERIFIED | `README.md` line 51; `guides/getting-started.md` line 14; `guides/cheatsheet.cheatmd` line 12; `mix.exs` line 4 (`@version "1.3.0"`); `CHANGELOG.md` line 11 (`## [1.3.0]`); `43-01-SUMMARY.md` |
| 2 | High-visibility public docs name the shipped 1.3.x surface without understating it | VERIFIED | `CHANGELOG.md` line 45 ("shipped `1.3.x` surface"); `43-01-SUMMARY.md` verification commands |
| 3 | Getting Started no longer carries the stale `~> 1.2` install snippet or "unreleased from main" wording | VERIFIED | `guides/getting-started.md`; `rg -n '~> 1\.2' guides/getting-started.md` returns no matches; `43-01-SUMMARY.md` |
| 4 | `test/lattice_stripe/docs_truth_test.exs` fails fast on onboarding install/version drift | VERIFIED | `test/lattice_stripe/docs_truth_test.exs` lines 61-62 (`refute body =~ "~> 1.2"`), 165, 171-172; `43-02-SUMMARY.md` reports `4 tests, 0 failures` on `mix test ... --warnings-as-errors` |

**Score:** 4/4 phase truths verified

### Artifact Verification

| Artifact | Status | Evidence |
|----------|--------|----------|
| `43-01-SUMMARY.md` | VERIFIED | Documents the install/version/changelog reconciliation across all five onboarding surfaces |
| `43-02-SUMMARY.md` | VERIFIED | Documents the docs-truth suite expansion for onboarding surfaces and ExDoc metadata |
| `README.md` | VERIFIED | Carries the `1.3.x` release-status wording and shipped-surface anchors |
| `guides/getting-started.md` | VERIFIED | Install snippet updated to `~> 1.3`; release-status wording aligned to shipped 1.3.x |
| `guides/cheatsheet.cheatmd` | VERIFIED | `~> 1.3` install snippet present |
| `mix.exs` | VERIFIED | `@version "1.3.0"`; ExDoc publication metadata present |
| `CHANGELOG.md` | VERIFIED | `## [1.3.0]` release with shipped-surface line |
| `test/lattice_stripe/docs_truth_test.exs` | VERIFIED | Asserts install snippets across onboarding surfaces, refutes stale `~> 1.2`, asserts ExDoc metadata |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| No stale `~> 1.2` install snippet on onboarding surfaces | `rg -n '~> 1\.2' README.md guides/getting-started.md guides/cheatsheet.cheatmd` | No matches | PASS |
| Shipped 1.3.x line present on onboarding surfaces | `rg -n '~> 1\.3\|1\.3\.0\|1\.3\.x' README.md CHANGELOG.md guides/getting-started.md guides/cheatsheet.cheatmd mix.exs` | All five surfaces match | PASS |
| Docs-truth regression suite green | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` (per 43-02-SUMMARY and later phase summaries) | `4 → 7 tests, 0 failures` across subsequent phases | PASS |

### Requirement Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| TRUTH-01 | Public package, version, and install guidance agrees across README, CHANGELOG, getting-started, cheatsheet, and HexDocs extras | VERIFIED | `43-01-SUMMARY.md`; README/getting-started/cheatsheet/mix.exs/CHANGELOG all on `~> 1.3` / `1.3.0` |
| TRUTH-02 | High-visibility docs accurately present the shipped `1.3.x` surface | VERIFIED | `43-01-SUMMARY.md`; CHANGELOG and README reference the shipped 1.3.x surface |
| VERIFY-01 | Docs-truth regression checks fail when first-run onboarding install/version snippets drift | VERIFIED | `test/lattice_stripe/docs_truth_test.exs` install/version assertions; `43-02-SUMMARY.md` |

### Gaps Summary

No verification gaps inside Phase 43 scope. Phase goal is fully achieved in the live tree.

---

_Verified: 2026-05-27T06:22:03Z_
_Verifier: gsd-audit-milestone (v1.4 audit backfill)_
