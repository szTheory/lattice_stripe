---
phase: 56-release-truth-getting-started
plan: 02
subsystem: docs
tags: [hexdocs, release-truth, getting-started, docs-truth, TRUTH-01]

# Dependency graph
requires:
  - phase: 56-release-truth-getting-started
    plan: 01
    provides: docs_truth SSOT helpers and intentional red-phase prose lock
provides:
  - Truthful 1.7.x release-status blockquote on HexDocs main page
  - TRUTH-01 satisfied: getting-started aligned with README and install pin
  - All 21 docs_truth tests green including getting-started prose lock
affects:
  - HexDocs first-run adopter experience
  - Phase 56 completion (release-truth getting-started)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "README-style release-status one-liner on getting-started (no milestone archaeology)"

key-files:
  created: []
  modified:
    - guides/getting-started.md

key-decisions:
  - "One-liner blockquote only per D-04 — no README milestone bullets duplicated"
  - "Git-dependency-from-main paragraph removed per D-11/D-12"

patterns-established:
  - "Getting-started Installation section mirrors README release-status tone without duplicating full release block"

requirements-completed: [TRUTH-01, TRUTH-02]

# Metrics
duration: 1min
completed: 2026-05-27
---

# Phase 56 Plan 02: TRUTH-01 Getting-Started Prose Fix Summary

**HexDocs getting-started Installation section now shows truthful 1.7.x release status aligned with README and install pin; all docs_truth tests green**

## Performance

- **Duration:** 1 min
- **Started:** 2026-05-27T21:06:54Z
- **Completed:** 2026-05-27T21:07:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Removed stale `1.3.x` published-surface claim and git-dependency steering from `guides/getting-started.md`
- Inserted README-style release-status blockquote immediately after install code block
- Install pin unchanged at `{:lattice_stripe, "~> 1.7"}` with Finch `~> 0.21`
- Turned Plan 01 intentional red-phase prose test green — 21/21 docs_truth tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace stale release prose with README-style blockquote one-liner** - `b193ecc` (docs)

**Plan metadata:** pending (this commit)

## Files Created/Modified

- `guides/getting-started.md` - Installation section release-status prose aligned with README and mix.exs version

## Decisions Made

- Followed plan exactly: one-liner blockquote only, no README milestone bullet list
- Removed git-dependency paragraph intentionally (post-1.7 Hex capstone makes it obsolete)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## Verification Results

```
! rg -n '1\.3\.x|unreleased work from' guides/getting-started.md
→ PASS (no matches)

rg -n 'Release status.*1\.7\.x.*current published line on Hex' guides/getting-started.md
→ PASS (line 20)

mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors
→ 21 tests, 0 failures
```

## Self-Check: PASSED

All acceptance criteria met. TRUTH-01 and TRUTH-02 satisfied.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Getting-started release truth aligned with README and install pin
- docs_truth suite fully green
- Phase 56 release-truth getting-started work complete

---
*Phase: 56-release-truth-getting-started*
*Completed: 2026-05-27*
