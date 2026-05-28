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
4. **Bootstrap CI** dispatches `ci.yml` only when a Release PR is open but was **not** just updated (`prs_created` false). Fresh Release Please updates run **pull_request** CI via `RELEASE_PLEASE_TOKEN` — no duplicate dispatch.
5. When **ci-gate** succeeds, **Release PR Auto-Merge** merges the Release PR, dispatches **CI** on the merge commit, then **Release** (GITHUB_TOKEN merges do not emit push events).
6. **Release** workflow tags the merge, waits for **ci-gate** on the tag SHA, then publishes to Hex automatically.
7. Verify `mix hex.info lattice_stripe` lists the new version.

Routine patch releases require **`RELEASE_PLEASE_TOKEN`** (fine-grained PAT with Contents + Pull requests write) for GitHub release creation; it also enables native `pull_request` CI on Release Please PRs. **`HEX_API_KEY`** is required for Hex publish.

### What to expect in Actions

| Workflow | When it runs | Skipped is normal when |
|----------|--------------|------------------------|
| **Release** | Every push to `main` | Tag/Hex jobs skip until a Release PR merges (`release_created` is false). |
| **Release PR Auto-Merge** | After **CI** completes | CI on `main` finishes — only release-branch CI (`release-please--*`) triggers merge. |
| **Bootstrap CI on Release PR** | After **Release** on `main` | Open Release PR exists but was not just updated by Release Please (`prs_created` false). |
| **Release PR Auto-Merge** | After release-branch **CI** completes | Manual retry: **Release PR Auto-Merge** workflow_dispatch. |

A **skipped** Release PR Auto-Merge run after a maintainer push to `main` is expected, not a failed release.

### Avoiding duplicate CI on Release PRs

With `RELEASE_PLEASE_TOKEN`, Release Please PR updates trigger native `pull_request` CI. The bootstrap job **does not** `workflow_dispatch` CI when `prs_created` is true — duplicate runs cancelled each other and left a stale failed `ci-gate` on the PR.

**Automerge** merges with `GITHUB_TOKEN`, which does **not** emit `push` events. **Release PR Auto-Merge** dispatches **CI** on the merge SHA, then **Release**, so `gate-ci-green` can verify `ci-gate` before Hex publish.

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
