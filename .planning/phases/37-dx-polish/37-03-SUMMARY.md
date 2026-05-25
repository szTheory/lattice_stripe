---
phase: 37-dx-polish
plan: "03"
subsystem: docs
tags:
  - docs
  - changelog
  - readme
  - exdoc
requires:
  - phase: 37-dx-polish
    provides: recipes guide and updated webhook/testing docs from plan 02
provides:
  - coherent branch-vs-release version story
  - refreshed README guide discovery and install guidance
  - automated docs-truth checks for recipes and install/version messaging
affects:
  - future release bumps and README/changelog edits
  - ExDoc source-link behavior for dev branches
tech-stack:
  added: []
  patterns:
    - separate branch-truth messaging from published Hex release guidance
    - narrow docs drift tests over README and ExDoc extras
key-files:
  created:
    - test/lattice_stripe/docs_truth_test.exs
  modified:
    - README.md
    - CHANGELOG.md
    - mix.exs
    - guides/getting-started.md
key-decisions:
  - "The repo branch now identifies itself as `1.3.0-dev`, while installation snippets point users at the latest published `1.2.x` release unless they explicitly opt into `main`."
  - "ExDoc source links should use `main` for `-dev` versions instead of a non-existent tag."
patterns-established:
  - "Keep docs truth checks regex-based and narrow rather than snapshotting whole markdown files."
  - "Tell users separately about the stable Hex line and the unreleased branch surface."
requirements-completed:
  - DX-04
duration: 18min
completed: 2026-05-25
---

# Phase 37 Plan 03 Summary

**Public version messaging, guide discovery, and ExDoc metadata now tell one coherent story about the stable `1.2.x` release and the unreleased `1.3.0-dev` branch.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-05-25T08:20:00Z
- **Completed:** 2026-05-25T08:38:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Replaced the stale README v1.1 framing with an explicit stable-release vs `main`-branch story.
- Updated `mix.exs` to `1.3.0-dev` and switched ExDoc source links to `main` for dev builds.
- Added a focused docs-truth test that locks the recipes extra and the README install/version messaging.

## Task Commits

1. **Task 1: Align README, changelog, docs metadata, and guide discovery with the real v1.3 branch state** - `43e87be` (`docs(37-03): align public version story`)
2. **Task 2: Add narrow docs-truth checks or durable assertions for the new DX surface** - `6b749cd` (`test(37-03): add docs truth checks`)

## Files Created/Modified

- `README.md` - stable-install guidance, branch status banner, and expanded guide discovery
- `CHANGELOG.md` - explicit unreleased v1.3 branch framing and updated docs-truth notes
- `mix.exs` - `@version "1.3.0-dev"` and branch-aware `source_ref`
- `guides/getting-started.md` - published release install snippet updated to `~> 1.2`
- `test/lattice_stripe/docs_truth_test.exs` - narrow docs drift checks

## Decisions Made

- Chose `1.3.0-dev` over a fake stable tag so repo metadata reflects the upcoming release line without pretending it has already shipped.
- Kept the README install path on the latest published Hex line and added an explicit git dependency path for users who want the unreleased branch surface.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

- Full `mix docs --warnings-as-errors` still fails on pre-existing warnings outside the files touched in this phase, but the phase 37 trust-sweep files were verified to be absent from the docs warning grep.

## User Setup Required

None.

## Next Phase Readiness

- README, changelog, ExDoc extras, and the new docs-truth test now provide a durable baseline for future version bumps and release cleanup.

## Self-Check: PASSED

---
*Phase: 37-dx-polish*
*Completed: 2026-05-25*
