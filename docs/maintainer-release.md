# Maintainer release procedure

This document is for **LatticeStripe maintainers** preparing a patch release on the sustaining train. Adopters should use [Hex](https://hex.pm/packages/lattice_stripe) and the public [CHANGELOG](https://github.com/szTheory/lattice_stripe/blob/main/CHANGELOG.md).

## Before you start

Run the hygiene gate from the repo root:

```bash
./scripts/maintainer/repo_hygiene_check.sh
```

Resolve every `[BLOCK]` line before dispatching a manual Hex publish. Use `--skip-mix-ci` only when CI already proved green on `origin/main`.

See also [`.planning/RELEASE-TRAIN.md`](../.planning/RELEASE-TRAIN.md) for commit-style and cadence rules.

## Normal patch release (fully automated)

1. Merge maintainer PRs to `main` using `docs:`, `fix:`, or `chore:` prefixes (patch-eligible).
2. Confirm GitHub Actions **CI / ci-gate** is green on `main`.
3. **Release** workflow runs Release Please and opens/updates a patch Release PR.
4. **Bootstrap CI** dispatches `ci.yml` on `release-please--branches--main` (bot PRs do not trigger `pull_request` CI with `GITHUB_TOKEN`).
5. When **ci-gate** succeeds, **Release PR Auto-Merge** merges the Release PR (merge commit).
6. **Release** workflow tags the merge, waits for **ci-gate** on the tag SHA, then publishes to Hex automatically.
7. Verify `mix hex.info lattice_stripe` lists the new version.

No manual `workflow_dispatch` is required for routine patch releases. Optionally set **`RELEASE_PLEASE_TOKEN`** (fine-grained PAT) so Release Please PRs also trigger native `pull_request` CI.

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
