---
phase: 44-guide-discovery-support-truth
plan: "01"
subsystem: docs
tags:
  - docs
  - exdoc
  - navigation
  - onboarding
requires: []
provides:
  - explicit docs ladder across README, Getting Started, JTBD, and recipes
  - layered ExDoc extras grouping with entry-point, canonical, and operations roles
affects:
  - README.md
  - guides/getting-started.md
  - guides/user-flows-and-jtbd.md
  - guides/recipes.md
  - mix.exs
tech-stack:
  added: []
  patterns:
    - docs-ladder routing
    - layered ExDoc extras grouping
key-files:
  created: []
  modified:
    - README.md
    - guides/getting-started.md
    - guides/user-flows-and-jtbd.md
    - guides/recipes.md
    - mix.exs
key-decisions:
  - "Kept `guides/getting-started.md` as the first-success landing page and turned it into a branching point after the initial API call."
  - "Used JTBD and recipes as routing layers into canonical guides instead of creating a second competing docs tree."
  - "Replaced the flat ExDoc extras bucket with explicit role-based groupings."
patterns-established:
  - "README should route by intent before dropping readers into the full guide list."
  - "Entry-point docs should branch into subscriptions, portal, metering, Connect, webhooks, testing, and troubleshooting explicitly."
requirements-completed:
  - GUIDE-01
  - GUIDE-02
duration: 24min
completed: 2026-05-26
---

# Phase 44 Plan 01 Summary

**Reframed the public docs entry points as a deliberate discovery ladder so README, Getting Started, JTBD, recipes, and ExDoc now steer evaluators into the right shipped guide surfaces instead of a flat list.**

## Performance

- **Duration:** 24 min
- **Started:** 2026-05-26T12:35:00Z
- **Completed:** 2026-05-26T12:59:32Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added a repo-level docs ladder and route-by-intent section to `README.md`.
- Replaced the overlapping Getting Started next-step sections with one first-success branching menu.
- Added task-first routing reinforcement to `guides/user-flows-and-jtbd.md` and `guides/recipes.md`.
- Reorganized `mix.exs` ExDoc extras into `Start Here`, `Canonical Guides`, and `Operations & DX`.

## Verification Evidence

| Command | Observed Result |
|---------|-----------------|
| `rg -n 'user-flows-and-jtbd|subscriptions|customer-portal|metering|connect|webhooks|testing|error-handling' README.md guides/getting-started.md` | Passed — README and Getting Started now expose the expected route anchors for the high-leverage guide graph. |
| `rg -n 'Read next|See also|subscriptions|customer-portal|metering|connect|webhooks|testing|error-handling' guides/user-flows-and-jtbd.md guides/recipes.md` | Passed — JTBD and recipes now act as routing layers into canonical guides. |
| `rg -n 'main: "getting-started"|groups_for_extras|Start Here|Canonical Guides|Operations & DX' mix.exs` | Passed — ExDoc still lands on Getting Started and now uses layered guide-role groups. |

## Task Commits

No task commits were created in this run because the phase targeted files already had pre-existing local modifications in the working tree. I kept the execution changes applied and verified without bundling unrelated in-flight work into a commit.

## Files Created/Modified

- `README.md` - added the docs ladder, route-by-intent menu, and clustered HexDocs navigation
- `guides/getting-started.md` - turned the first-success guide into an explicit branching point
- `guides/user-flows-and-jtbd.md` - reinforced the task-first routing layer into canonical guides
- `guides/recipes.md` - tightened the compact bridge into deeper canonical guides
- `mix.exs` - replaced the flat ExDoc extras bucket with layered guide groups

## Decisions Made

- Preserved the existing library-scoped voice and avoided expanding these entry points into Accrue-style workflow ownership.
- Made route markers short and explicit rather than adding long prose explanations.

## Deviations from Plan

None - plan executed exactly as written within the dirty-worktree constraint.

## Issues Encountered

- The target docs files were already modified before this run, so commit-level isolation was unsafe. The route and grouping changes were still applied and verified successfully in the worktree.

## User Setup Required

None.

## Next Phase Readiness

- The canonical guide graph can now carry the inline support-truth and deeper routing work from Plan 02.
- The ExDoc grouping and public entry points now provide stable anchors for docs-truth regression coverage.

## Self-Check: PASSED

---
*Phase: 44-guide-discovery-support-truth*
*Completed: 2026-05-26*
