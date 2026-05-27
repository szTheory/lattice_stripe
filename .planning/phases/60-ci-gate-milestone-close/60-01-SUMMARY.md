---
phase: 60-ci-gate-milestone-close
plan: 01
subsystem: infra
tags: [github-actions, ci, docs_truth, paths-ignore]

requires: []
provides:
  - CI runs on guide and markdown PRs (docs_truth enforced)
  - Accurate CONTRIBUTING.md CI expectations
  - CI-01 blocker cleared in STATE.md
affects: [60-02, v1.9-milestone-close]

tech-stack:
  added: []
  patterns: ["paths-ignore limited to .planning/** only"]

key-files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - CONTRIBUTING.md
    - .planning/STATE.md

key-decisions:
  - "paths-ignore lists only .planning/** per 60-CONTEXT D-01/D-04"
  - "No workflow jobs/permissions/matrix changes (D-02 scope limit)"

patterns-established:
  - "Guide/md PRs trigger full mix test including docs_truth_test.exs"

requirements-completed: [CI-01]

duration: 5min
completed: 2026-05-27
---

# Phase 60 Plan 01: CI paths-ignore (CI-01)

**Guide and markdown PRs now run full CI including docs_truth; planning-only edits still skip.**

## Performance

- **Duration:** ~5 min
- **Completed:** 2026-05-27
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Narrowed `paths-ignore` on push and pull_request to `.planning/**` only
- Updated CONTRIBUTING.md to document docs_truth on guide/README/md changes
- Cleared CI-01 blocker in STATE.md

## Task Commits

1. **Task 1: Narrow paths-ignore in ci.yml** - `4f49899` (ci)
2. **Task 2: Update CONTRIBUTING.md CI note** - `70f44d0` (docs)
3. **Task 3: Clear CI-01 blocker in STATE.md** - `1ffe5c8` (docs)

## Files Created/Modified

- `.github/workflows/ci.yml` - Removed `**.md` and `guides/**` from paths-ignore
- `CONTRIBUTING.md` - Accurate CI note for guide/md vs planning-only edits
- `.planning/STATE.md` - CI-01 resolved; Plan 01 complete

## Self-Check: PASSED

- paths-ignore grep: only `.planning/**` (2 blocks)
- No `guides/**` or `**.md` in ci.yml
- `mix test test/lattice_stripe/docs_truth_test.exs` — 26 tests, 0 failures
