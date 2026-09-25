---
phase: 78-release-and-repository-closeout
plan: 04
subsystem: maintainer-workflows
tags: [git, worktrees, closeout, bash]

requires: []
provides:
  - Read-only inventory of every linked worktree and the primary checkout with untracked-file status.
  - Final release-main gate and explicit owner mapping for linked worktrees.
  - Maintainer instructions for preserving dirty or unowned worktrees.
affects: [release-closeout, maintainer-operations]

actuals:
  tokens: 3678
  tasks: 2
  commits: 3
plan_head_before: e017a3566b7b741fb8266d0c78bdf5899a0ae9fd

tech-stack:
  added: []
  patterns:
    - NUL-delimited Git worktree and status data is parsed without whitespace-splitting paths.
    - Final closeout reads a separately refreshed origin/main ref and never performs fetch or cleanup.

key-files:
  created:
    - scripts/maintainer/worktree_closeout_check.sh
    - scripts/maintainer/test_worktree_closeout_check.sh
  modified:
    - docs/maintainer-release.md

key-decisions:
  - "Every linked worktree requires an explicit path-to-owner mapping; missing ownership blocks closeout."
  - "The primary checkout is derived from Git's common directory, so execution from a linked worktree still checks the real primary checkout."

patterns-established:
  - "Status failures and missing inventory facts fail closed and are reported without mutating any worktree."

requirements-completed: [CLOSE-03]
coverage:
  - id: D1
    description: "A read-only checker inventories the primary checkout and every linked worktree, including tracked and untracked status, safely handling paths with spaces."
    requirement: CLOSE-03
    verification:
      - kind: other
        ref: "bash scripts/maintainer/test_worktree_closeout_check.sh (clean, dirty, untracked, path-space, locked, ownership, missing-primary, command-failure, and status-failure fixtures)"
        status: pass
      - kind: other
        ref: "shellcheck scripts/maintainer/worktree_closeout_check.sh scripts/maintainer/test_worktree_closeout_check.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "Final mode requires the primary checkout on main at the release SHA and synchronized with origin/main, while dirty, uninspectable, or unowned worktrees block without cleanup."
    requirement: CLOSE-03
    verification:
      - kind: other
        ref: "bash scripts/maintainer/test_worktree_closeout_check.sh (release-SHA, branch, remote-ref, dirty-tree, missing-owner, and inspection-error cases)"
        status: pass
      - kind: other
        ref: "bash scripts/maintainer/worktree_closeout_check.sh --owners /private/tmp/78-04-worktree-owners.json (live read-only inventory; primary checkout blocked on local and GSD run-state changes)"
        status: pass
    human_judgment: false

duration: 6min
completed: 2026-09-25
status: complete
---

# Phase 78 Plan 04: Worktree Closeout Gate Summary

**A NUL-safe, read-only worktree closeout gate reports ownership and cleanliness for every checkout and binds final main state to the release SHA.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-09-25T00:11:49Z
- **Completed:** 2026-09-25T00:17:31Z
- **Tasks:** 2
- **Files modified:** 4, including this summary

## Accomplishments

- Added a read-only checker that parses NUL-delimited worktree inventory and porcelain status, safely reports paths with spaces, and blocks dirty, uninspectable, or unowned linked trees.
- Added final-mode checks that require the primary checkout on `main` at the release SHA and the separately refreshed `origin/main` ref.
- Added deterministic fixtures for clean, tracked dirty, untracked, path-with-spaces, locked, missing owner/primary, mismatched branch/SHA/remote, and command or status failures.
- Documented the exact invocation, owner-map format, remote refresh prerequisite, and owner-safe response to blockers.

## Task Commits

1. **Task 1: Probe every Git worktree and the release-main relation** - `d4d22e1` (feat)
2. **Task 2: Document the owner-safe worktree closeout procedure** - `d4456e2` (docs)

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `scripts/maintainer/worktree_closeout_check.sh` - inventories and checks each worktree without changing Git state.
- `scripts/maintainer/test_worktree_closeout_check.sh` - deterministic fixture coverage for clean and blocking cases plus the documented command.
- `docs/maintainer-release.md` - owner-map, refresh, and final worktree closeout instructions.

## Decisions Made

- Required a path-to-owner mapping for every linked worktree; missing ownership is a blocker even when the tree is clean.
- Derived the primary checkout from Git's common directory so invoking the script from a linked GSD worktree still identifies the true primary checkout.
- Kept fetch separate from the checker; final verification consumes the freshly updated remote-tracking ref without changing repository state.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The live read-only inventory found seven tracked or untracked status entries in the primary checkout and therefore blocked. These include pre-existing user edits and GSD run-state artifacts created during this execution. The checker did not modify those paths. The current Phase 78 worktree was clean after the task commits and had an explicit owner association. The final closeout condition remains unmet until the primary checkout's owner resolves those changes and reruns the gate.
- Git index operations required sandbox escalation because this worktree's Git metadata is outside the writable workspace; normal hooks ran for both task commits.
- `CLOSE-03` is also declared by unfinished plan 78-06, so the requirement checkbox was not updated from this isolated worktree.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The checker, fixtures, and maintainer procedure are ready for final closeout. Final release mode must be rerun after refreshing `origin/main`, using the actual release SHA and a current owner map; the current primary checkout remains blocked by its dirty status.

## Self-Check: PASSED

- Checker, fixture script, maintainer documentation, and this summary exist.
- Task commits `d4d22e1` and `d4456e2` are present.
- Fixture suite, ShellCheck, Bash syntax checks, and `git diff --check` passed.
- `STATE.md` and `ROADMAP.md` remain unchanged.

---
*Phase: 78-release-and-repository-closeout*
*Completed: 2026-09-25*
