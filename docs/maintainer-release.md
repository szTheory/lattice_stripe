# Maintainer release procedure

This document is for **LatticeStripe maintainers** preparing a package release on the sustaining train. Adopters should use [Hex](https://hex.pm/packages/lattice_stripe) and the public [CHANGELOG](https://github.com/szTheory/lattice_stripe/blob/main/CHANGELOG.md).

## Before you start

Run the hygiene gate from the repo root:

```bash
./scripts/maintainer/repo_hygiene_check.sh
```

Resolve every `[BLOCK]` line before dispatching a manual Hex publish. Use `--skip-mix-ci` only when CI already proved green on `origin/main`.

See also [`.planning/RELEASE-TRAIN.md`](../.planning/RELEASE-TRAIN.md) for commit-style and cadence rules.

## Normal release (fully automated)

For the currently reviewed additive Invoice and Refund fields, Release Please should propose
**2.3.0**. The final API-lock delta must contain only `Invoice.amount_paid_off_stripe` and
`Refund.customer`, `Refund.customer_account`, and `Refund.payment_method`; the default Stripe
API version remains `2026-03-25.dahlia`. Release Please owns the version and changelog edits.
Before merging a generated Release Please PR, the workflow runs
`scripts/maintainer/release_candidate_check.sh` from trusted `main` and reads the proposal
at the current PR head. Maintainers can run that same preflight from a trusted `main`
checkout with:

```bash
git fetch origin main --tags
git switch main
bash scripts/maintainer/release_candidate_check.sh
```

1. Merge maintainer PRs to `main` after their required checks pass.
2. Confirm GitHub Actions **CI / ci-gate** is green on `main`.
3. **Release** workflow runs Release Please and opens/updates the release PR.
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
| **Sync version prose on release PR** | After **Release** on `main` | No open Release PR, or the prose already matches `mix.exs`. |
| **Bootstrap CI on Release PR** | After **Release** on `main` | Open Release PR exists but was not just updated by Release Please (`prs_created` false). |
| **Release PR Auto-Merge** | After release-branch **CI** completes | Manual retry: **Release PR Auto-Merge** workflow_dispatch. |

A **skipped** Release PR Auto-Merge run after a maintainer push to `main` is expected, not a failed release.

If protected merge fails after `ci-gate` passes, the auto-merge workflow leaves the Release
Please PR open and reports its current head SHA, merge/review state, check conclusions, and
available unresolved review-conversation state. Resolve the reported protection requirement,
then rerun **Release PR Auto-Merge** with `workflow_dispatch` and that same current head SHA.
The workflow rechecks both the PR head and `ci-gate` before every retry and uses GitHub's
head-match guard for the merge. Do not use administrator override; if the required policy
cannot be met, leave the PR open and correct the repository policy through the normal
maintainer process.

### Version prose on the Release PR

Release Please updates `mix.exs` and `CHANGELOG.md`. It does **not** update the install
snippets or "current release" lines in `README.md` and the guides, and it cannot: the pins are
`~> MAJOR.MINOR`, which no `x-release-please-*` annotation produces, and they sit inside fenced
code blocks where an HTML-comment annotation would render literally.

Because `docs_truth_test.exs` derives its expectations from `mix.exs`, that gap made every
Release PR fail CI on three assertions and stall — it blocked 2.0.0 until fixed by hand. The
**Sync version prose on release PR** job now runs `mix lattice_stripe.version_prose --update`
on the release branch and pushes the result, so the PR reaches `ci-gate` green on its own.

The push needs `RELEASE_PLEASE_TOKEN`: pushes authenticated with `GITHUB_TOKEN` do not start
workflow runs, which would leave `ci-gate` never reporting and the PR unmergeable. The job
dispatches CI explicitly afterwards as a fallback.

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

## Final worktree closeout

The release closeout probe reads `git worktree list --porcelain -z` and checks each
listed tree with NUL-delimited porcelain status including individual untracked files.
It does not fetch, switch branches, clean, stash, reset, or remove worktrees. Refresh
the remote-tracking ref as a separate step, then pass the immutable release commit:

```bash
git fetch origin main
bash scripts/maintainer/worktree_closeout_check.sh --owners .planning/phases/78-release-and-repository-closeout/78-WORKTREE-OWNERS.json --final --expected-main-sha "$(git rev-parse HEAD)"
```

Before running the probe, create `78-WORKTREE-OWNERS.json` with an explicit owner
for every linked worktree path. Paths are absolute, exact keys from the inventory;
the primary checkout is reported separately and must not be listed as a linked owner.
For example:

```json
{
  "owners": {
    "/absolute/path/to/linked worktree": "maintainer or agent name"
  }
}
```

An omitted owner, dirty status, missing worktree record, or status inspection error
blocks closeout. Identify the tree's owner and preserve the worktree. Ask that owner
to resolve changes through ordinary commits or explicitly dispose of their own work;
never clean, reset, stash, or force-remove another owner's tree to satisfy the gate.
Locked and detached worktrees are included in the inventory and reported with their
state. The final check requires the primary checkout on `main`, with its HEAD equal
to both the supplied release SHA and freshly fetched `origin/main`.

The research-time checkout was ahead of `origin/main`; that observation is historical
and its count is not a current closeout fact. Final synchronization is a separate
release step, followed by a fresh read-only probe. Do not infer current synchronization
from the earlier inventory.

## Drift and dependencies

- Stripe OpenAPI drift: `mix lattice_stripe.check_drift` (weekly automation may file issues).
- Dependabot: merge patch runtime deps after `ci-gate` is green; review Finch minors and GitHub Actions majors separately.

## Contributor gate

Contributors run `mix ci` locally (format, compile, credo, tests, docs). Maintainers run the hygiene script before release prep.
