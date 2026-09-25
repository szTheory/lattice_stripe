# Phase 78 Closeout — Release Evidence and Remaining Repository Gate

**Last refreshed:** 2026-09-25 UTC

**Repository:** `szTheory/lattice_stripe`

**Release:** `2.3.0` at `1e83a99029f19c24c97549752adf8f57cabc7dd0`
**Evidence ledger:** [78-PR-DISPOSITIONS.json](./78-PR-DISPOSITIONS.json)

## Release evidence — passed

- Release Please PR [#68](https://github.com/szTheory/lattice_stripe/pull/68) was merged by the protected auto-merge workflow after candidate preflight and successful `ci-gate` on exact candidate `eb215b19f035c782dca5edafe1bbb9e8233f5efd`. The workflow passed: [auto-merge run 36084111513](https://github.com/szTheory/lattice_stripe/actions/runs/36084111513).
- Release commit: `1e83a99029f19c24c97549752adf8f57cabc7dd0`, parent `260edf43189e7b180c863e413472d832c6352d00`.
- [Release workflow 36084157667](https://github.com/szTheory/lattice_stripe/actions/runs/36084157667) passed, including `ci-gate` verification on the release SHA and Hex publication.
- [GitHub Release v2.3.0](https://github.com/szTheory/lattice_stripe/releases/tag/v2.3.0) and tag `v2.3.0` resolve to the same release commit.
- Exact-SHA verifier `scripts/maintainer/release_evidence_check.sh --version 2.3.0 --sha 1e83a99029f19c24c97549752adf8f57cabc7dd0` passed all checks: tag peeling, GitHub Release, main ancestry, newest exact-SHA `ci-gate` ([CI run 36084155921, job 107912495099](https://github.com/szTheory/lattice_stripe/actions/runs/36084155921/job/107912495099)), Hex registry/tarball SHA-256 parity, versioned HexDocs, and published-Hex Phoenix adopter smoke (3 tests, 0 failures).
- Hex 2.3.0 checksum: `e921209af48b4673fab1f39eb210839b41d55497ad456822b78f6f36d4cab088`.
- Versioned docs: [HexDocs 2.3.0](https://hexdocs.pm/lattice_stripe/2.3.0/).

## PR disposition — refreshed

PRs [#66](https://github.com/szTheory/lattice_stripe/pull/66) and [#69](https://github.com/szTheory/lattice_stripe/pull/69) have since been squash-merged after current-head CI passed. The refreshed open-PR inventory is empty. Current main is `ad48bd3259a22155fa4f6e4f88b0dfa8d7f54d64`; required `ci-gate`, tests, and relevant lanes passed in [run 36085912335](https://github.com/szTheory/lattice_stripe/actions/runs/36085912335). No administrator bypass was used.

## Worktree gate — blocked, user state preserved

The read-only final check still finds the primary checkout dirty and its cached remote ref stale. Release identity remains `1e83a99029f19c24c97549752adf8f57cabc7dd0`; the later current main is `ad48bd3259a22155fa4f6e4f88b0dfa8d7f54d64`. The closeout helper now compares primary HEAD and `origin/main` to an explicit expected current-main SHA, while immutable package artifacts remain verified independently by `release_evidence_check.sh`.

1. Primary checkout `/Users/jon/projects/lattice_stripe` is dirty. It contains user-owned modifications to `.agents/skills/lattice-verification-policy/SKILL.md`, `.planning/PROJECT.md`, `.planning/STATE.md`, `.planning/phases/75-typed-contract-updates/75-UAT.md`, `.planning/phases/75-typed-contract-updates/75-VERIFICATION.md`, and `.planning/state.json`, plus untracked `.gsd/dispatch-isolation-sentinel.json`, `.planning/milestone.lock`, and `.planning/phases/76-phoenix-adopter-core-flow/COVERAGE.md`. None were changed or removed for this phase.
2. Primary checkout HEAD is `dcb514d14aee41cb7e7e3213a276932f8e33ff74`, not current main `ad48bd3259a22155fa4f6e4f88b0dfa8d7f54d64`.
3. Primary checkout's cached `origin/main` is stale at `a318624dbcf45546d66a4aaaece19dff42ba13ad`. Refreshing it from this checkout was blocked by `.git/FETCH_HEAD` write permission. The isolated recovery clone was used for authenticated remote verification and was not counted as the primary worktree.

The worktree closeout check is read-only and did not modify any tree. Final clean/synchronized-worktree acceptance remains open until the owner state is reconciled and the primary checkout can safely refresh its remote ref.

## Verification record

```text
Release Please protected auto-merge: passed (run 36084111513)
Release workflow and Hex publication: passed (run 36084157667)
Release evidence exact-SHA verifier: passed (all checks; checksum above)
Current PR inventory: empty after #66 and #69 squash merges; main CI run 36085912335 passed
Final worktree check: blocked (3 blockers above; no files changed)
```
