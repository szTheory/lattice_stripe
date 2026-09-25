# Phase 78 Closeout — Release Evidence and Remaining Repository Gate

**Last refreshed:** 2026-09-25 03:45 UTC

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

PRs [#66](https://github.com/szTheory/lattice_stripe/pull/66), [#69](https://github.com/szTheory/lattice_stripe/pull/69), [#70](https://github.com/szTheory/lattice_stripe/pull/70), [#71](https://github.com/szTheory/lattice_stripe/pull/71), and [#72](https://github.com/szTheory/lattice_stripe/pull/72) have been squash-merged after exact-head CI passed. PR #72 is at current main `7f0eb4ba75da2e256f4e05bdd10cf64551dd154e`; full CI, including `ci-gate`, passed on exact PR head `2b37f26ce05cfd311f4bdc103970107c2bd47e73` in [run 36089067158](https://github.com/szTheory/lattice_stripe/actions/runs/36089067158). The refreshed open-PR inventory is empty. No administrator bypass was used.

## Worktree gate — passed

The 4-hour GSD milestone lock expired and was removed. The final read-only checker inventoried exactly one worktree: the clean primary checkout. Primary `main` and `origin/main` both equal `7f0eb4ba75da2e256f4e05bdd10cf64551dd154e`. The immutable package release remains `1e83a99029f19c24c97549752adf8f57cabc7dd0`; later closeout commits do not alter the release identity. The previous local history is preserved in `/private/tmp/lattice-root-state-backup.bundle`.

Final checker command:

```text
bash scripts/maintainer/worktree_closeout_check.sh --owners /private/tmp/phase78-worktree-owners.json --final --expected-main-sha 7f0eb4ba75da2e256f4e05bdd10cf64551dd154e
```

Result: PASS; one clean primary path; primary `main` and `origin/main` match the expected SHA.

## Verification record

```text
Release Please protected auto-merge: passed (run 36084111513)
Release workflow and Hex publication: passed (run 36084157667)
Release evidence exact-SHA verifier: passed (all checks; checksum above)
Current PR inventory: empty after #66, #69, #70, #71, and #72 squash merges; run 36089067158 passed on PR #72 exact head 2b37f26ce05cfd311f4bdc103970107c2bd47e73
Final worktree check: passed; one clean primary worktree, primary main and origin/main match 7f0eb4ba75da2e256f4e05bdd10cf64551dd154e
```
