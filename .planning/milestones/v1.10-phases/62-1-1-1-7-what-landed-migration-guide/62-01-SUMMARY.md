---
phase: 62-1-1-1-7-what-landed-migration-guide
plan: "01"
subsystem: documentation
tags: [exdoc, exunit, migration-guide, stripe]
requires:
  - phase: 61-default-finch-pool-optional-application
    provides: current-release setup boundary used only as a historical exclusion
provides:
  - historically accurate 1.1-to-1.7 migration guide
  - action-first complete capability inventory
  - semantic regression contract for the guide
affects: [hexdocs, docs-truth, adopter-migrations]
tech-stack:
  added: []
  patterns: [semantic documentation truth test, job-routed ExDoc inventory]
key-files:
  created:
    - .planning/phases/62-1-1-1-7-what-landed-migration-guide/62-01-SUMMARY.md
  modified:
    - guides/upgrading-1-1-to-1-7.md
    - test/lattice_stripe/docs_truth_test.exs
    - .planning/phases/62-1-1-1-7-what-landed-migration-guide/62-VALIDATION.md
key-decisions:
  - "Keep the guide strictly historical through 1.7 and route current setup to current guides."
  - "Put required migration checks before optional capabilities and release chronology."
  - "Protect durable adopter harms with one semantic docs-truth test rather than snapshots."
patterns-established:
  - "Migration extras start with required behavior triage, then route optional jobs to canonical guides."
requirements-completed: [DOC-01]
coverage:
  - id: D1
    description: Historical 1.1-to-1.7 guide boundary and ExDoc discoverability
    requirement: DOC-01
    verification:
      - kind: unit
        ref: test/lattice_stripe/docs_truth_test.exs#1.1-to-1.7 guide remains historically scoped and discoverable
        status: pass
      - kind: other
        ref: mix docs --warnings-as-errors
        status: pass
    human_judgment: false
  - id: D2
    description: Mandatory migration checks, safe webhook tolerance guidance, and complete job-routed inventory
    requirement: DOC-01
    verification:
      - kind: unit
        ref: test/lattice_stripe/docs_truth_test.exs#1.1-to-1.7 guide remains historically scoped and discoverable
        status: pass
      - kind: other
        ref: mix ci
        status: pass
    human_judgment: false
  - id: D3
    description: Zero-library-code scope and protected milestone audit preservation
    requirement: DOC-01
    verification:
      - kind: other
        ref: 62-VALIDATION.md#d-15-exact-scope-audit
        status: pass
    human_judgment: false
duration: 8min
completed: 2026-08-24
status: complete
---

# Phase 62 Plan 01: 1.1 → 1.7 What Landed Migration Guide Summary

**A historically accurate, action-first HexDocs migration guide now lets 1.1 adopters confirm required code changes and discover every 1.3–1.7 capability by job.**

## Performance

- **Duration:** 8 min
- **Tasks:** 3 completed
- **Files modified:** 4

## Accomplishments

- Removed the post-1.7 Finch claim while preserving the intentional 1.7 pin and a thin route to 2.0/current setup documentation.
- Put the three affected-user checks, safe exit, and application-test instruction before a complete inventory grouped by adopter job and familiar ExDoc family.
- Added a compact semantic documentation contract covering scope, discoverability, safety anchors, inventory routes, and stale navigation labels.

## Task Commits

1. **Task 1: Correct the historical dependency path and lock it end to end** — `51110ef`, `1a7d712`
2. **Task 2: Complete the action-first migration checklist and capability inventory** — `dfadc16`
3. **Task 3: Run the strict phase gate and record mechanical evidence** — this commit

## Verification

- `mix test test/lattice_stripe/docs_truth_test.exs` — PASS (57 tests, 0 failures)
- `mix docs --warnings-as-errors` — PASS
- `mix ci` — PASS (2392 tests, 0 failures, 1 skipped, 214 excluded)
- D-15 executor-range committed/staged/unstaged allowlist audit and protected audit fingerprint — PASS; recorded in `62-VALIDATION.md`.

### D-15 Boundary Clarification

This summary's exact four-path audit proves the immutable executor boundary
through `9d111dfb4c251d544570aebcce951094ba4161f4`. Required later review,
verification, and closure records are intentionally outside that historical
range; the separate lifecycle/corrective audit in `62-VALIDATION.md` supplies
the final whole-phase scope proof without rewriting this task history.

## Decisions Made

- Use a strict historical boundary: current setup remains in current guides, not in the 1.7 dependency path.
- Make the guide a migration decision aid first and a capability catalogue second; leave chronology in its final appendix.
- Treat the existing DocsTruthTest as the semantic lock, complementing rather than replacing docs and CI builds.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Documentation build] Qualified the `File.create/3` table reference.**
- **Found during:** Task 2
- **Issue:** ExDoc interpreted the unqualified `File.create/3` reference as an undefined/private function.
- **Fix:** Used `LatticeStripe.File.create/3` and `LatticeStripe.FileLink.create/3`.
- **Verification:** `mix docs --warnings-as-errors` passed.
- **Committed in:** `dfadc16`

**Total deviations:** 1 auto-fixed.

## Issues Encountered

None remaining. The focused contract intentionally failed before the historical correction, then passed after the guide was fixed.

## User Setup Required

None.

## Next Phase Readiness

DOC-01 has fresh semantic, documentation-build, full-CI, and exact-scope evidence. No production surface changed.

## Self-Check: PASSED

- Required guide, docs-truth test, validation record, and this summary exist.
- Task commits `51110ef`, `1a7d712`, and `dfadc16` exist in Git history.
