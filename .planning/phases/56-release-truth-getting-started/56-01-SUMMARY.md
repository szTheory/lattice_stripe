---
phase: 56-release-truth-getting-started
plan: 01
subsystem: testing
tags: [exunit, docs-truth, release-truth, ssot, regression-locks]

# Dependency graph
requires:
  - phase: 54-install-pin-truth
    provides: install-pin SSOT pattern in docs_truth_test.exs
provides:
  - current_release_line/0 SSOT helper derived from mix.exs version
  - @stale_release_status_claims catalog for stale release-status prose
  - dedicated describe "guides/getting-started.md" with prose and cross-link tests
  - README release test refactored to share SSOT helpers
affects:
  - 56-02 (getting-started prose fix to turn red test green)
  - TRUTH-02 release-truth regression infrastructure

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Release-truth SSOT: derive major.minor.x from MixProject.project()[:version]"
    - "Separate describe blocks for prose drift vs cross-link routing drift"

key-files:
  created: []
  modified:
    - test/lattice_stripe/docs_truth_test.exs

key-decisions:
  - "Intentional red phase: getting-started prose test fails until Plan 02 updates guides/getting-started.md"
  - "Stale-claim list includes both backtick and plain variants of 1.3.x published-line phrasing"

patterns-established:
  - "Release-truth SSOT mirrors install-pin SSOT: current_release_line/0 + @stale_release_status_claims"
  - "Prose lock asserts release line, semantic anchor, stale claims, and no main-branch git steer"

requirements-completed: [TRUTH-02]

# Metrics
duration: 1min
completed: 2026-05-27
---

# Phase 56 Plan 01: TRUTH-02 Regression Infrastructure Summary

**Release-truth SSOT helpers and grep regression locks in docs_truth_test.exs, with intentional red-phase failure on getting-started prose until Plan 02**

## Performance

- **Duration:** 1 min
- **Started:** 2026-05-27T21:06:09Z
- **Completed:** 2026-05-27T21:06:26Z
- **Tasks:** 3
- **Files modified:** 1

## Accomplishments

- Added `@stale_release_status_claims` and `current_release_line/0` adjacent to existing install SSOT helpers
- Created `describe "guides/getting-started.md"` with separate prose lock and cross-link regression tests
- Refactored README release test to use SSOT helpers instead of hardcoded `"1.7"` and single stale-claim refute
- Established TRUTH-02 regression infrastructure before prose fix lands in Plan 02

## Task Commits

Each task was committed atomically:

1. **Task 1: Add SSOT release-truth helpers and stale-claim list** - `724ad5d` (test)
2. **Task 2: Add describe "guides/getting-started.md" with prose lock and migrated cross-link test** - `0721ae1` (test)
3. **Task 3: Refactor README release test to use SSOT helpers** - `7acb2dd` (test)

**Plan metadata:** pending (this commit)

## Files Created/Modified

- `test/lattice_stripe/docs_truth_test.exs` - SSOT release-truth helpers, getting-started describe block, README test refactor

## Decisions Made

- Followed plan's intentional red phase: getting-started prose test left failing until Plan 02 updates `guides/getting-started.md`
- Dropped stale-pin refute from migrated cross-link test (install SSOT tests already cover stale pins globally)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- **Expected failure:** `release-status prose matches current Hex surface` fails because `guides/getting-started.md` still claims `1.3.x` is the current published line and steers to git dependency from `main`. This is the intentional red phase; Plan 02 will fix the prose.

## Verification Results

```
rg -n '@stale_release_status_claims|defp current_release_line|describe "guides/getting-started.md"' test/lattice_stripe/docs_truth_test.exs
→ PASS (all patterns found)

mix compile --warnings-as-errors
→ PASS

mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors
→ 21 tests, 1 failure (getting-started prose test — expected until Plan 02)
```

## Self-Check: PASSED

All acceptance criteria met. Getting-started prose failure is intentional per plan.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- TRUTH-02 regression infrastructure is in place
- Ready for Plan 02 to update `guides/getting-started.md` release-status prose and turn the red test green
- README release test passes with SSOT helpers (20/21 docs_truth tests pass)

---
*Phase: 56-release-truth-getting-started*
*Completed: 2026-05-27*
