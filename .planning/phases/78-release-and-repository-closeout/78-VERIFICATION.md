---
phase: 78-release-and-repository-closeout
verified: 2026-09-25T03:00:00Z
status: gaps_found
score: 3/4 roadmap truths verified
covered_files:
  - .github/workflows/publish-hex.yml
  - .github/workflows/release-pr-automerge.yml
  - .github/workflows/release.yml
  - .planning/REQUIREMENTS.md
  - .planning/phases/78-release-and-repository-closeout/78-01-PLAN.md
  - .planning/phases/78-release-and-repository-closeout/78-01-SUMMARY.md
  - .planning/phases/78-release-and-repository-closeout/78-02-PLAN.md
  - .planning/phases/78-release-and-repository-closeout/78-02-SUMMARY.md
  - .planning/phases/78-release-and-repository-closeout/78-03-PLAN.md
  - .planning/phases/78-release-and-repository-closeout/78-03-SUMMARY.md
  - .planning/phases/78-release-and-repository-closeout/78-04-PLAN.md
  - .planning/phases/78-release-and-repository-closeout/78-04-SUMMARY.md
  - .planning/phases/78-release-and-repository-closeout/78-05-PLAN.md
  - .planning/phases/78-release-and-repository-closeout/78-05-SUMMARY.md
  - .planning/phases/78-release-and-repository-closeout/78-06-PLAN.md
  - .planning/phases/78-release-and-repository-closeout/78-06-SUMMARY.md
  - .planning/phases/78-release-and-repository-closeout/78-CLOSEOUT.md
  - .planning/phases/78-release-and-repository-closeout/78-PR-DISPOSITIONS.json
  - docs/maintainer-release.md
  - scripts/maintainer/pr_closeout_check.sh
  - scripts/maintainer/published_hex_adopter_smoke.sh
  - scripts/maintainer/release_candidate_check.sh
  - scripts/maintainer/release_evidence_check.sh
  - scripts/maintainer/test_pr_closeout_check.sh
  - scripts/maintainer/test_release_candidate_check.sh
  - scripts/maintainer/test_release_evidence_check.sh
  - scripts/maintainer/test_worktree_closeout_check.sh
  - scripts/maintainer/worktree_closeout_check.sh
  - test_apps/phoenix_adopter/mix.exs
  - test_apps/phoenix_adopter/test/core_flow_test.exs
covered_digest: "v1:sha256:d1d16f084a641c4d2ae694740ea6c0520e143c3ec59f0e611ebcd2145616d480"
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "The primary checkout and all linked worktrees are clean at milestone close."
    status: failed
    reason: "The live read-only worktree closeout command found the primary checkout dirty because .planning/milestone.lock is untracked. Its updated_at is 2026-09-24T23:43:02.752Z; at verification it was 196 minutes old, within the GSD four-hour TTL. The lock implementation defines liveness by age and expressly does not use PID liveness. Preserve this active Phase 78 claim; cleanliness cannot pass until GSD releases it or it expires and the final checker is rerun."
    artifacts:
      - path: .planning/milestone.lock
        issue: "Untracked active Phase 78 lock appears in primary worktree porcelain status."
      - path: scripts/maintainer/worktree_closeout_check.sh
        issue: "Live final check returned BLOCKED (1 blocker), while confirming primary main and origin/main both equal 629c9a2a69c1c9e38fa842e2b5157b6e64c4904d."
    missing:
      - "After GSD releases the lock or its four-hour TTL expires, rerun scripts/maintainer/worktree_closeout_check.sh --owners <owners.json> --final --expected-main-sha <current-main-sha> and obtain PASS with every worktree clean."
---

# Phase 78: Release and Repository Closeout — Verification Report

**Phase Goal:** Adopters can install a verified milestone release, and maintainers can close the milestone with healthy `main` CI, triaged pull requests, and a clean repository workspace.
**Verified:** 2026-09-25T03:00:00Z
**Status:** gaps_found
**Re-verification:** No — no prior Phase 78 verification report existed.

## Goal Achievement

### Observable Truths

| # | Roadmap truth | Status | Evidence |
|---|---|---|---|
| 1 | A new package version consistent with the delivered public API changes is published and verified on Hex, with matching GitHub release and HexDocs content. | VERIFIED | Ran `scripts/maintainer/release_evidence_check.sh --version 2.3.0 --sha 1e83a99029f19c24c97549752adf8f57cabc7dd0`. It passed tag peeling, GitHub Release identity, main ancestry, exact release-SHA `ci-gate` (run 36084155921), Hex checksum `e921209a…cab088`, versioned HexDocs, and the published-Hex Phoenix smoke (3 tests, 0 failures). The smoke resolved `lattice_stripe 2.3.0` from Hex. |
| 2 | All required CI checks are green for the release commit on `main`. | VERIFIED | The exact-SHA release evidence command passed the release commit's `ci-gate`; the immutable release SHA remains an ancestor of current main `629c9a2a69c1c9e38fa842e2b5157b6e64c4904d`. PR #71's pull-request CI run 36088077120 passed every listed test, integration and `ci-gate` check on head `dfb43de084c831e51a834b30596f7f468a2f9e72`; it merged as current main commit `629c9a2a…`. |
| 3 | Every open pull request has a recorded triage disposition and any accepted changes have passed their required checks. | VERIFIED | Live `gh pr list --state open` returned `[]`; `scripts/maintainer/pr_closeout_check.sh --ledger .planning/phases/78-release-and-repository-closeout/78-PR-DISPOSITIONS.json` reported all open PRs have current disposition evidence. PRs #66, #69, and #70 were recorded as merged in the closeout summary; PR #71 merged after its exact-head CI passed. |
| 4 | The primary checkout and all linked Git worktrees have no uncommitted changes at milestone close. | FAILED | Live `scripts/maintainer/worktree_closeout_check.sh --owners /private/tmp/phase78-worktree-owners.json --final --expected-main-sha 629c9a2a69c1c9e38fa842e2b5157b6e64c4904d` inventoried one worktree. It confirmed primary `main` and `origin/main` match the expected current SHA, but reported `.planning/milestone.lock` as an untracked entry and returned `BLOCKED (1 blocker)`. The lock's timestamp is within the four-hour TTL defined in `~/.codex/gsd-core/bin/lib/milestone-lock.cjs`; preserving it is required while active. |

**Score:** 3/4 roadmap truths verified (0 present, behavior-unverified).

The roadmap plan checklist still labels plans 78-05 and 78-06 unchecked even though both summaries exist and both were reviewed here. This is a planning-state bookkeeping mismatch; it does not change the four roadmap success-criteria verdicts above. GSD manager therefore continues to show `roadmap_complete: false` until that checklist is reconciled.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `scripts/maintainer/release_evidence_check.sh` | Join immutable release SHA, CI, registry, docs and actual Hex consumption | VERIFIED | Live 2.3.0 exact-SHA invocation passed every component and the 3-test published package smoke. |
| `scripts/maintainer/test_release_evidence_check.sh` | Reject stale/mismatched release evidence | VERIFIED | Fixture command passed valid and negative cases for wrong tag SHA, stale CI, wrong Hex version/source, checksum mismatch, and absent docs. |
| `scripts/maintainer/release_candidate_check.sh` | Check compatibility and Release Please candidate | VERIFIED | `bash scripts/maintainer/test_release_candidate_check.sh` passed additive candidate, protection and all negative fixtures. |
| `scripts/maintainer/pr_closeout_check.sh` | Check the live PR inventory against dispositions | VERIFIED | Live checker passed; GitHub open-PR inventory is empty. Fixture suite passed. |
| `scripts/maintainer/worktree_closeout_check.sh` | Read-only inventory including untracked state, owners and final main synchronization | FAILED at final acceptance | Implementation and fixture suite are substantive; live invocation confirmed one primary worktree and main synchronization but blocked on active untracked lock. |
| `.planning/phases/78-release-and-repository-closeout/78-CLOSEOUT.md` and `78-PR-DISPOSITIONS.json` | Dated release, PR and worktree evidence | PARTIAL | Release and PR evidence is corroborated. Closeout ledger explicitly leaves worktree cleanliness pending; PR ledger live entries are empty with historical dispositions retained. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Release workflows | `release_evidence_check.sh` | Resolved version and release SHA passed after publication | WIRED | Workflow fixtures passed; live verifier successfully consumed published 2.3.0 evidence. |
| Published-Hex smoke | Hex registry package | Isolated Mix resolution plus exact dependency metadata assertion | WIRED | Live run resolved 2.3.0 from Hex and passed all 3 Phoenix host-flow tests. |
| Live GitHub PR inventory | PR disposition ledger/checker | `gh pr list` and checker ledger input | WIRED | Inventory empty and checker passed. |
| Worktree closeout command | Every Git worktree status and expected main refs | NUL-delimited `git worktree list` and per-path porcelain status | WIRED | Fixture suite passed; live final-mode check proved main refs synchronized and exposed the lock blocker without modifying the tree. |

### Data-Flow Trace (Level 4)

Not applicable: Phase 78 produces release and maintainer tooling, not rendered application data. The release verifier reads live GitHub, Hex and HexDocs evidence; its published-package smoke executes the actual Hex dependency.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Published release evidence and Hex adopter flow | `scripts/maintainer/release_evidence_check.sh --version 2.3.0 --sha 1e83a99029f19c24c97549752adf8f57cabc7dd0` | All remote checks passed; 3 tests, 0 failures; dependency source Hex 2.3.0 | PASS |
| PR checker fixture behavior | `bash scripts/maintainer/test_pr_closeout_check.sh` | All eight fixture cases passed | PASS |
| Release candidate fixture behavior | `bash scripts/maintainer/test_release_candidate_check.sh` | Valid candidate and five rejection fixtures passed | PASS |
| Release evidence negative cases | `bash scripts/maintainer/test_release_evidence_check.sh` | All six fixture/workflow checks passed | PASS |
| Worktree closeout fixture behavior | `bash scripts/maintainer/test_worktree_closeout_check.sh` | All twelve fixture cases passed | PASS |
| Final live worktree state | `scripts/maintainer/worktree_closeout_check.sh --owners /private/tmp/phase78-worktree-owners.json --final --expected-main-sha 629c9a2a69c1c9e38fa842e2b5157b6e64c4904d` | One untracked lock; synchronized main refs; exit 1, BLOCKED | FAIL |

### Probe Execution

No phase-declared or conventional migration/tooling probes were specified in the plans. The named shell fixture suites and live release/worktree checks were run directly.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| REL-01 | 78-02, 78-05, 78-06 | Cut and verify SemVer/API-compatible package release | SATISFIED | Candidate fixtures, exact release verifier, public 2.3.0 package and associated release evidence passed. |
| REL-02 | 78-01, 78-02, 78-05, 78-06 | Install release from Hex with matching GitHub release and HexDocs | SATISFIED | Exact-SHA verifier and published-Hex smoke passed. |
| CLOSE-01 | 78-01, 78-02, 78-06 | Required checks green on release commit on main | SATISFIED | Exact release-SHA `ci-gate` passed; release commit is an ancestor of current main. |
| CLOSE-02 | 78-03, 78-06 | Open PRs reviewed and dispositioned before close | SATISFIED | Live inventory empty; PR checker passed; dispositions and merge/check evidence recorded. |
| CLOSE-03 | 78-04, 78-06 | Primary and all linked worktrees clean at close | BLOCKED | Current main and origin/main match, but live inventory finds active untracked `.planning/milestone.lock`. |

No additional Phase 78 requirement IDs are mapped in `REQUIREMENTS.md`.

### Test Quality Audit

| Test File | Linked requirement | Active | Skipped | Circular | Assertion level | Verdict |
|---|---|---:|---:|---:|---|---|
| `scripts/maintainer/test_release_evidence_check.sh` | REL-01, REL-02, CLOSE-01 | Yes | 0 found in relevant cases | No circular expected-value generation found | Value/failure-component assertions | PASS |
| `scripts/maintainer/test_release_candidate_check.sh` | REL-01 | Yes | 0 found in relevant cases | No circular expected-value generation found | Value and rejection assertions | PASS |
| `scripts/maintainer/test_pr_closeout_check.sh` | CLOSE-02 | Yes | 0 found in relevant cases | No circular expected-value generation found | Current-head and disposition assertions | PASS |
| `scripts/maintainer/test_worktree_closeout_check.sh` | CLOSE-03 | Yes | 0 found in relevant cases | No circular expected-value generation found | Dirty/clean/final-state assertions | PASS |

Disabled tests linked to the requirements: 0 found. Circular expected-value generation: 0 found. Insufficient assertions: 0 found.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| None | — | No unreferenced `TBD`, `FIXME`, or `XXX` debt markers in the checked phase tooling/docs | — | No blocker |

### Human Verification Required

N/A — this is a release/CI/maintainer-tooling phase with no user-facing interaction. Every positive release, PR and checker claim has named executable or exact remote evidence. The remaining issue is a deterministically observed active lock, not a human judgment question.

### Gaps Summary

Release publication and proof, release-SHA CI, PR triage, and synchronization of primary `main` with `origin/main` are verified. Phase completion is blocked only by the active Phase 78 milestone lock appearing as an untracked worktree entry. The lock is 196 minutes old at verification, within the four-hour TTL; GSD lock code does not use PID liveness. Preserve it, then rerun the final read-only worktree checker after release or expiry. Do not mark this phase or milestone complete while the checker reports dirty state.

---

_Verified: 2026-09-25T03:00:00Z_  
_Verifier: the agent (gsd-verifier)_
