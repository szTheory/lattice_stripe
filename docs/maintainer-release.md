# Maintainer release procedure

This document is for **LatticeStripe maintainers** preparing a patch release on the sustaining train. Adopters should use [Hex](https://hex.pm/packages/lattice_stripe) and the public [CHANGELOG](https://github.com/szTheory/lattice_stripe/blob/main/CHANGELOG.md).

## Before you start

Run the hygiene gate from the repo root:

```bash
./scripts/maintainer/repo_hygiene_check.sh
```

Resolve every `[BLOCK]` line before merging a Release Please PR or dispatching a manual Hex publish. Use `--skip-mix-ci` only when CI already proved green on `origin/main`.

See also [`.planning/RELEASE-TRAIN.md`](../.planning/RELEASE-TRAIN.md) for commit-style and cadence rules.

## Normal patch release (preferred)

1. Merge maintainer PRs to `main` using `docs:`, `fix:`, or `chore:` prefixes (patch-eligible).
2. Confirm GitHub Actions **CI / ci-gate** is green on `main`.
3. Wait for Release Please to open a Release PR (patch bump only on the maintenance train).
4. Review the Release PR: version in `mix.exs`, `.release-please-manifest.json`, and `CHANGELOG.md` must agree.
5. Merge the Release PR. The **Release** workflow creates the tag; **Publish Hex** runs after `ci-gate` passes on the release SHA.
6. Verify `mix hex.info lattice_stripe` lists the new version.

## Manual recovery (automation failed)

Use only when Release Please or Hex publish did not complete (as with **1.7.1**):

1. Ensure `mix.exs`, `.release-please-manifest.json`, and top `CHANGELOG.md` entry match the intended version.
2. Tag `vX.Y.Z` on the release commit and push the tag.
3. Run **Publish Hex** workflow (`workflow_dispatch`) with the tag, or publish locally with `HEX_API_KEY` after `mix hex.build`.

After manual recovery, close any stale Release Please PR that proposes a bogus minor/major (e.g. accumulated `feat(phase):` history).

## CI expectations

- **Required:** `ci-gate` (format, compile, test matrix, integration, docs_truth, quality/credo).
- **Branch protection:** require **CI / ci-gate**, not the aggregate workflow status alone.

## Drift and dependencies

- Stripe OpenAPI drift: `mix lattice_stripe.check_drift` (weekly automation may file issues).
- Dependabot: merge patch runtime deps after `ci-gate` is green; review Finch minors and GitHub Actions majors separately.

## Contributor gate

Contributors run `mix ci` locally (format, compile, credo, tests, docs). Maintainers run the hygiene script before release prep.
