---
phase: 78-release-and-repository-closeout
plan: 02
subsystem: release
tags: [release-please, semver, github-actions, hex]

requires:
  - phase: 75-typed-contract-updates
    provides: Reviewed additive Invoice and Refund API fields and the unchanged Stripe API default
provides:
  - Executable compatibility preflight for the Release Please 2.3.0 proposal
  - Protected Release PR auto-merge with exact-head checks and actionable blocker diagnostics
  - Maintainer release instructions for the minor release and fail-closed recovery
affects: [release, ci, maintainer-operations]

actuals:
  tokens: 4830
  tasks: 2
  commits: 4
  plan_head_before: 40bf169e810836cb62528ab9d731f16d84703671

tech-stack:
  added: []
  patterns: [GitHub PR-head content verification, exact-head protected merge]

key-files:
  created:
    - scripts/maintainer/release_candidate_check.sh
    - scripts/maintainer/test_release_candidate_check.sh
  modified:
    - .github/workflows/release-pr-automerge.yml
    - docs/maintainer-release.md

key-decisions:
  - "Release Please remains authoritative for the package version and changelog; the current additive API proposal must be 2.3.0."
  - "Protected merges use the verified head SHA and never use administrator override."

patterns-established:
  - "Release candidates are read from the open PR head and compared with the v2.2.2 API lock baseline."
  - "Failed protected merges report current PR, review, check, and available conversation state while leaving the PR open."

requirements-completed: [REL-01, CLOSE-01]

coverage:
  - id: D1
    description: "A trusted-main preflight verifies the four reviewed additive API fields, the unchanged Stripe API default, and the generated Release Please 2.3.0 proposal."
    requirement: REL-01
    verification:
      - kind: other
        ref: "scripts/maintainer/test_release_candidate_check.sh (valid candidate plus removed API row, changed pin, absent PR, stale head, and wrong version fixtures)"
        status: pass
      - kind: unit
        ref: "mix test test/lattice_stripe/api_surface_lock_test.exs test/lattice_stripe/version_prose_test.exs (19 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Release PR auto-merge requires the exact ci-gate-passed head, honors normal branch protection, and reports blocker state without an administrator bypass."
    requirement: CLOSE-01
    verification:
      - kind: other
        ref: "scripts/maintainer/test_release_candidate_check.sh (protected merge workflow safeguards)"
        status: pass
      - kind: other
        ref: "actionlint .github/workflows/release-pr-automerge.yml"
        status: pass
      - kind: other
        ref: "scripts/maintainer/repo_hygiene_check.sh --ci (6 PASS, 0 WARN, 0 BLOCK)"
        status: pass
    human_judgment: false

duration: 11min
completed: 2026-09-24
status: complete
---

# Phase 78 Plan 02: Release Candidate and Protected Merge Summary

**A trusted-main compatibility gate validates the generated 2.3.0 Release Please proposal, while release auto-merge stays bound to the green PR head and repository protection.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-09-24T23:46:43Z
- **Completed:** 2026-09-24T23:57:28Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added a compatibility preflight that compares the checked-in API lock to `v2.2.2`, requires exactly four reviewed optional-field additions, checks the default API version, and reads version/changelog/source files from the current Release Please PR head.
- Added positive and negative candidate fixtures, including workflow safeguards against admin bypass and stale-head merges.
- Removed administrator merge fallback. Auto-merge now uses `--match-head-commit`, rechecks the current PR head and latest `ci-gate` before each retry, and reports mergeability, review, check, and available conversation state when blocked.
- Updated maintainer guidance for the 2.3.0 minor release and the protected-merge recovery path.

## Task Commits

1. **Task 1: Check Release Please proposal against compatibility evidence** - `1f8998f` (feat)
2. **Task 1 verification fix: Clear fixture ShellCheck warnings** - `cc325df` (fix)
3. **Task 2: Preserve protected Release Please merges** - `29fbe97` (fix)
4. **Workflow regression assertions** - `85f8b2e` (test)

**Plan metadata:** This summary is committed in the plan close-out commit; its hash is reported by the executor.

## Files Created/Modified

- `scripts/maintainer/release_candidate_check.sh` - Validates source API delta and the actual generated Release Please proposal.
- `scripts/maintainer/test_release_candidate_check.sh` - Exercises candidate rejection cases and protects key auto-merge invariants.
- `.github/workflows/release-pr-automerge.yml` - Runs the trusted-main preflight and uses exact-head protected merge with blocker diagnostics.
- `docs/maintainer-release.md` - Documents the expected minor release and recovery procedure.

## Decisions Made

- Kept Release Please authoritative for version and changelog generation; did not hand-edit package metadata.
- Required only the four Phase 75 additions and retained `2026-03-25.dahlia` as the default Stripe API version.
- Used GitHub's head-match merge option and failed closed on unresolved protection requirements.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Cleared fixture ShellCheck warnings**
- **Found during:** Task 2 verification
- **Issue:** ShellCheck reported ambiguous argument forwarding in the Task 1 fixture helper.
- **Fix:** Forwarded optional fixture runner arguments explicitly.
- **Files modified:** `scripts/maintainer/test_release_candidate_check.sh`
- **Verification:** ShellCheck passed for both release candidate scripts.
- **Committed in:** `cc325df`

**2. [Rule 2 - Missing Critical] Added regression assertions for protected merge safeguards**
- **Found during:** Final verification
- **Issue:** Workflow syntax validation alone did not lock the exact-head, repeated-check, and no-admin invariants.
- **Fix:** Added executable assertions for the verified-head merge guard, PR-head and `ci-gate` rechecks, review-thread diagnostics, and absence of `--admin`.
- **Files modified:** `scripts/maintainer/test_release_candidate_check.sh`
- **Verification:** Candidate fixture suite passed, including protected-merge assertions.
- **Committed in:** `85f8b2e`

**Total deviations:** 2 auto-fixed (1 Rule 1, 1 Rule 2). **Impact:** Both changes improve verification of the planned release trust boundary; no scope expansion.

## Issues Encountered

- The first Mix dependency fetch could not write Hex's default cache under the home directory (`:eaccess`). It succeeded with `HEX_HOME=/private/tmp/lattice-stripe-hex`; the lockfile and dependency set remained unchanged.
- GitHub reported no open Release Please PR during execution. The live candidate verdict therefore remains pending PR creation; the absent-PR fixture confirms the preflight blocks clearly in that state.

## Authentication Gates

None. GitHub CLI was authenticated; no auth action was needed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The release candidate and protected merge checks are ready for the generated Release Please PR. Rerun the candidate preflight when that PR exists; the workflow invokes it automatically before merging. Requirements updates remain deferred because both IDs are shared with other incomplete Phase 78 plans. `STATE.md` and `ROADMAP.md` were left unchanged as instructed.

## Self-Check: PASSED

- Summary file exists at the planned phase path.
- Task commits `1f8998f`, `cc325df`, `29fbe97`, and `85f8b2e` exist in Git history.
- Coverage classifier reports 2/2 deliverables auto-covered with no schema errors.
- `STATE.md` and `ROADMAP.md` have no changes in this worktree.

---
*Phase: 78-release-and-repository-closeout*
*Completed: 2026-09-24*
