---
phase: 56-release-truth-getting-started
status: passed
verified: 2026-05-27
score: 8/8
requirements:
  TRUTH-01: satisfied
  TRUTH-02: satisfied
---

# Phase 56 Verification — Release Truth Getting Started

**Goal:** First-run adopters see truthful release-status prose in getting-started — aligned to Hex 1.7.0 — with docs_truth regression preventing prose drift.

**Result:** Phase goal achieved. All must-have truths verified in codebase; `docs_truth_test.exs` suite green (21/21).

---

## Score

| Category | Verified | Total |
|----------|----------|-------|
| Must-have truths (Plans 01 + 02) | 8 | 8 |
| Requirements (TRUTH-01, TRUTH-02) | 2 | 2 |
| Automated test gate | 1 | 1 |

**Overall:** 8/8 must-haves · 2/2 requirements · docs_truth 21/0

---

## Automated Verification

```text
mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors
→ 21 tests, 0 failures (2026-05-27)
```

```text
rg '1\.3\.x|unreleased work from' guides/getting-started.md
→ no matches
```

```text
mix.exs @version = "1.7.0"
current_release_line/0 → "1.7.x" (derived, not hardcoded in test asserts)
```

---

## Must-Have Truths — Plan 01 (TRUTH-02 infrastructure)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `docs_truth` derives release-status prose from `mix.exs` via `current_release_line/0` — not hardcoded version strings | ✅ | `current_release_line/0` splits `MixProject.project()[:version]`; README test uses `current_release_line()` (no `assert readme =~ "1.7"`) |
| 2 | getting-started release-status prose locked by positive assert + stale-claim refutes in dedicated describe | ✅ | `describe "guides/getting-started.md"` → `"release-status prose matches current Hex surface"` with positive + refute loops |
| 3 | Cross-link routing and release-truth tested separately under same describe | ✅ | Separate tests: `"release-status prose matches current Hex surface"` and `"branches from first success into high-leverage guides"` |
| 4 | README release test shares SSOT helpers and stale-claim list with getting-started | ✅ | Both use `current_release_line()` and `@stale_release_status_claims` refute loop |

### Plan 01 Artifacts & Key Links

| Artifact / Link | Status | Evidence |
|-------------------|--------|----------|
| `docs_truth_test.exs` contains `current_release_line` | ✅ | Lines 26–29 |
| `@stale_release_status_claims` with both 1.3.x variants | ✅ | Lines 16–19 |
| mix.exs → docs_truth via version derivation | ✅ | `@version "1.7.0"` in mix.exs; helper reads `project()[:version]` |
| docs_truth → getting-started grep lock | ✅ | Prose test reads `guides/getting-started.md` and asserts/refutes |
| Former top-level cross-link test migrated (not duplicated) | ✅ | Only inside describe; no duplicate top-level test |

---

## Must-Have Truths — Plan 02 (TRUTH-01 prose fix)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 5 | First-run adopters see **1.7.x** as current published Hex line in getting-started | ✅ | Line 20: `> **Release status:** **`1.7.x`** ships as the current published line on Hex (capstone release **1.7.0**).` |
| 6 | No stale 1.3.x published-surface claim in getting-started | ✅ | `rg` no matches; prose test refutes `@stale_release_status_claims` |
| 7 | No git-dependency-from-main steering in onboarding path | ✅ | Stale paragraph removed; prose test refutes `"unreleased work from \`main\`"` |
| 8 | All docs_truth tests pass including release-status prose lock | ✅ | 21/0 green |

### Plan 02 Artifacts & Key Links

| Artifact / Link | Status | Evidence |
|-------------------|--------|----------|
| `guides/getting-started.md` contains `Release status` blockquote | ✅ | Installation section line 20 |
| Install pin unchanged `~> 1.7` + Finch `~> 0.21` | ✅ | Lines 14–15 |
| README ↔ getting-started tone match | ✅ | Same one-liner shape as README line 8 |
| Prose lock test passes | ✅ | Included in 21/0 suite run |

---

## Requirements Traceability

| Requirement | Plan frontmatter | REQUIREMENTS.md definition | Codebase status |
|-------------|------------------|----------------------------|-----------------|
| **TRUTH-01** | 56-02-PLAN.md | Adopter sees release-status prose matching Hex 1.7.0; no stale 1.3.x claim | ✅ Satisfied — getting-started blockquote + no 1.3.x |
| **TRUTH-02** | 56-01-PLAN.md, 56-02-PLAN.md | `docs_truth_test.exs` grep-regresses release-status prose (not only install pin) | ✅ Satisfied — dedicated describe with positive/refute locks |

**Cross-reference:** Plan requirement IDs align with REQUIREMENTS.md Phase 56 mapping. Both requirements implemented and verified in code/tests.

---

## Gaps Found

None blocking phase completion.

---

## Human Verification (optional / housekeeping)

| Item | Priority | Notes |
|------|----------|-------|
| HexDocs rendered blockquote appearance | Low | Per 56-VALIDATION.md: optional `mix docs && open doc/index.html` — grep locks are the CI gate |
| REQUIREMENTS.md checkboxes / traceability table | Low | TRUTH-01/TRUTH-02 still marked `[ ] Pending` in `.planning/REQUIREMENTS.md` despite code completion — planning doc update only |

---

## Phase Goal Assessment

**Passed.** Getting-started Installation section tells the same 1.7.x release story as README and the `~> 1.7` install pin. Regression infrastructure prevents prose drift on future version bumps via SSOT-derived `current_release_line/0` and stale-claim refutes.

---

*Verified: 2026-05-27*
