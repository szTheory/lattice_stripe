# Phase 78: Release and Repository Closeout - Research

**Researched:** 2026-09-24  
**Domain:** Elixir library release automation, Hex publication, GitHub Actions, maintainer closeout  
**Confidence:** HIGH for repository seams and intended policy; MEDIUM for external service behavior where only official docs were consulted

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Package version and release evidence
- **D-01:** Treat `2.3.0` as the expected next package version: Phase 75 added four optional public fields, and its reviewed API-surface diff recorded additions only. Recheck the final API lock diff and compatibility evidence before accepting the Release Please PR; investigate any breaking or unexpected API change rather than overriding the version by hand. Release Please remains authoritative for the package version and changelog. GSD milestone numbering does not set Hex package versions.
- **D-02:** Verify the release end to end against one immutable release SHA: successful required `ci-gate` on that SHA, matching tag and GitHub Release, the expected Hex version/checksum, accessible versioned HexDocs, and a credential-free adopter smoke that resolves the published Hex package rather than the local path dependency. Keep `2026-03-25.dahlia` as the default Stripe API version; the new fields' explicit minimum-version guidance does not authorize changing that default.

### Automated release and recovery
- **D-03:** Keep Release Please's reviewable release PR and the existing automated CI → tag/GitHub Release → Hex/HexDocs path as the routine release. Do not add a blanket human approval/UAT gate when the exact-SHA, compatibility, package, and registry checks pass. Keep the authenticated manual workflow for failed automation and docs-only recovery; it must retain exact-SHA CI checks, version validation, and idempotency.
- **D-04:** Do not let release automation bypass branch protection. Remove or replace the `--admin` auto-merge fallback with a fail-closed result that leaves the PR and reports the unmet protection/check; recovery must preserve the required `ci-gate` and resolved-conversation policies. Keep release credentials least-privileged and scoped to the jobs that need them; do not make a token change during closeout unless it is required to make the documented flow work safely.

### Pull request triage and repository cleanliness
- **D-05:** Record each open PR's disposition in its contributor-visible GitHub timeline and in a dated closeout ledger linking the PR, disposition, rationale/next step, and required-check state. Merge accepted changes only after their required checks pass. A deferred PR may remain open only with an explicit reason and next step; do not close PRs just for age or force a zero-open-PR count beyond the roadmap requirement.
- **D-06:** Prove cleanliness read-only for the primary checkout and every path from `git worktree list --porcelain`, using machine-readable status that includes untracked files. Require the primary checkout to be on/synchronized with release `main` as applicable to the final closeout. Any dirty or unowned worktree blocks completion and is preserved for its owner; never force-remove it or discard its changes to satisfy the gate.

### the agent's Discretion
- Choose the smallest maintainable post-publish verifier and adopter fixture that proves Hex installation, package metadata/checksum, versioned docs, and exact release-SHA provenance without live Stripe credentials.
- Keep existing Release Please credentials if their permissions and event behavior remain correct; prefer the known recovery path over introducing a new GitHub App credential system during this release. Document any remaining credential setup requirement as an operational prerequisite, not as UAT.
- Automate objective inventory and state checks. Escalate only a genuinely ambiguous contribution-fit/security decision or a one-way public API decision not resolved by the reviewed API lock; never use a human review to replace a reproducible test.
- No browser UI, visual design system, Ecto persistence, or Phoenix product surface applies. Phoenix is relevant only as a test host for published-package adoption proof.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within Phase 78. A GitHub App migration for release credentials may be reconsidered separately if PAT rotation or token scope becomes a demonstrated problem; do not broaden this release closeout to redesign authentication.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REL-01 | Maintainers can cut and verify a new package release whose SemVer and published API-version contract reflect the compatibility evidence from this milestone. | Release Please review PR + final API-lock compatibility diff; `mix.exs`, manifest, changelog, compatibility docs and package metadata must agree; retain API default. |
| REL-02 | Adopters can install the new release from Hex and access its matching GitHub release and HexDocs documentation. | Post-publish verifier should reconcile release SHA/tag/GitHub release/Hex version and checksum/versioned docs, then execute a minimal no-credential adopter with an explicit Hex dependency. |
| CLOSE-01 | Maintainers can confirm that all required CI checks are green on the release commit on `main`. | Query the required terminal `ci-gate` for the immutable release SHA and prove that SHA is the release commit on `main`; do not accept a green run from another SHA or branch. |
| CLOSE-02 | Every open pull request is reviewed and left with a recorded triage disposition before milestone close. | Enumerate all open PRs; record a contributor-visible disposition and a dated ledger entry with rationale/next step/check status; accepted merges require green required checks. |
| CLOSE-03 | The primary checkout and all Git worktrees are clean when the milestone closes. | Enumerate worktrees via porcelain, run stable machine-readable status including untracked files in each, and verify main synchronization without mutating/removing dirty trees. |
</phase_requirements>

## Summary

Phase 78 is principally an evidence and closeout phase, not a release-system rewrite. The repository already has Release Please, exact-ref CI gates, automatic package/docs publication, an authenticated manual recovery workflow, a Phoenix host adopter, and a local hygiene script. Preserve that architecture and strengthen only the gaps that weaken the stated release proof: eliminate the admin override, prove the public package independently through Hex, establish one SHA chain across main/CI/tag/release/package/docs, and extend closeout inventory to every PR and worktree. [VERIFIED: `.github/workflows/release.yml:1-12,215-241,334-383`; `.github/workflows/publish-hex.yml:1-39,42-80,145-232`; `.github/workflows/release-pr-automerge.yml:1-3,18-21,66-92,139-179`; `test_apps/phoenix_adopter/mix.exs:18-25`; `scripts/maintainer/repo_hygiene_check.sh:165-223`]

**Primary recommendation:** Keep Release Please authoritative for release version/changelog and the existing CI→tag/GitHub Release→Hex/HexDocs path. Gate completion on a deterministic release-evidence verifier using the release SHA; reuse the Phoenix adopter tests in a separate published-Hex mode; make auto-merge fail closed; and make PR/worktree inventory auditable and read-only. [VERIFIED: `.planning/phases/78-release-and-repository-closeout/78-CONTEXT.md:20-99`]

### Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Version choice and changelog generation | Release automation (Release Please) | Package metadata (`mix.exs`, manifest) | Context assigns release PR/version/changelog authority to Release Please, while compatibility review decides whether its proposal is valid. |
| Required CI proof on release SHA | GitHub Actions CI | GitHub checks API / release workflow | `ci-gate` is the terminal required check; a run from a different commit cannot prove this release. |
| Hex package and docs publish | Release workflow / Hex | Release evidence verifier | The publish job is authenticated; independently query registry/docs and install the exact version afterward. |
| Public package adoption smoke | Phoenix host test app (test only) | Hex/Mix resolver | Reuse the existing host app, but make dependency source explicit as the newly published Hex release. |
| PR disposition and closeout ledger | GitHub PR timeline + planning ledger | GitHub API/CLI inventory | Contributors need the decision where they collaborate; the ledger gives the milestone a stable audit record. |
| Repository cleanliness | Local closeout probe | Git worktree inventory | Git status owns each worktree's working-tree state; Git worktree porcelain provides paths for enumerating them. |

## Standard Stack

### Core

| Tool / surface | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Release Please GitHub Action | Existing pinned v5 SHA | Changelog/version proposal, release PR, tag and GitHub Release | Already integrated and documented in the current workflow; retains a reviewable compatibility checkpoint. |
| GitHub Actions + `ci-gate` | Existing workflow; Elixir matrix 1.15/1.17/1.19 with OTP 26/27/28 | Required test, docs, integration, package, and quality signal | Existing project CI defines the required release signal; avoid a parallel redundant full CI lane. |
| Mix / Hex tasks | Current project toolchain from `.tool-versions` | Build, dry-run/publish package and docs, registry query, dependency resolution | Idiomatic Elixir library release surface. Official Hex docs support `mix hex.publish --dry-run`, package-only and docs-only flows, versioned docs, and recommendation to test installation after publication. [CITED: [Hex publish task](https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html), [Hex publishing](https://hex.pm/docs/publish)] |
| Phoenix adopter host | Existing nested test app / lockfile | Consumer-level compile and behavior proof | Already tests SDK integration through synthetic Mox transport, with Phoenix kept out of SDK runtime dependencies. |
| `gh` / GitHub REST checks API | Existing workflow tool usage | PR inventory, check state, release metadata, contributor-visible dispositions | Existing workflows already use `gh` and GitHub API; stable source of remote release/PR/check state. |
| Git `status --porcelain` + `worktree list --porcelain -z` | Git installed | Machine-readable local cleanliness inventory | Git documents porcelain as stable for scripts, and lists main and linked worktrees; status includes untracked non-ignored files. [CITED: [git status](https://git-scm.com/docs/git-status), [git worktree](https://git-scm.com/docs/git-worktree)] |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `mix hex.info` / Hex package release metadata API | Check published version and checksum | Post-publish registry consistency probe, paired with fetching the package into a clean external consumer project. |
| `curl` to versioned HexDocs URL | Check version-specific docs are reachable | After publication; check the version-specific path rather than only the latest alias. |
| Existing `repo_hygiene_check.sh` | Local release preflight | Keep its project invariants; supplement the final closeout mode because its current checks only inspect the current checkout and latest-main CI heuristically. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing Release Please review PR | Hand-bump package files or custom release script | Hand editing conflicts with locked authority and bypasses the established semver/changelog review workflow. |
| Small published-Hex adopter smoke | A second standalone demo app or live Stripe request | A second app duplicates maintenance; live credentials/service add nondeterminism and are out of scope. Reuse the current Phoenix host with an explicit Hex dependency source. |
| Normal protected merge with fail-closed error | `gh pr merge --admin` retry | CLI docs state `--admin` merges when requirements are unmet / bypasses the merge queue; this contradicts branch-protection contract. [CITED: [gh pr merge](https://cli.github.com/manual/gh_pr_merge)] |
| Read-only dirty-tree report | Automatically stash, clean, or force-remove worktrees | This can destroy or hide owner changes; it also proves a mutation, not that all work was clean at close. |

No external package is proposed for installation. Do not add a verifier dependency: the current GitHub CLI/API, shell/POSIX tools, Mix/Hex tasks, and existing test app are sufficient.

## Architecture Patterns

### Release-to-evidence flow

```text
main changes
  → Release Please proposal PR
  → final API-lock/SemVer review + required ci-gate on PR head
  → protected squash merge
  → release tag + GitHub Release at immutable release SHA
  → ci-gate on that SHA (confirmed as main's release commit)
  → Hex package + bundled/versioned HexDocs publish
  → registry/checksum/docs probes + clean consumer install and adopter tests
  → dated closeout record: SHA, CI run, version, tag/release, checksum, docs, smoke result
```

`GITHUB_TOKEN`-created events do not trigger normal follow-on workflow runs (with documented `workflow_dispatch` and `repository_dispatch` exceptions), explaining the current explicit workflow dispatches. Preserve the token event architecture unless testing the entire chain proves a safe alternative. [CITED: [GitHub Actions events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows)]

### Pattern 1: Reconcile a release using one immutable SHA

**What:** Resolve the Release Please output/tag to a full commit SHA once and thread it through CI, checkout, publication metadata, registry/docs checks, and the closeout ledger. Verify the SHA is reachable as the intended release commit on `main`; record any docs-only refresh as a separate artifact with its own exact source SHA and provenance.

**When to use:** Every first publication or recovery path. The regular workflow and manual workflow already wait for `ci-gate` on their target/tag SHA and check package version; the normal path checks out the tag for publishing. [VERIFIED: `.github/workflows/release.yml:215-241,334-383`; `.github/workflows/publish-hex.yml:42-80,145-191`]

**Proof to add/retain:** compare (1) `mix.exs` version, `.release-please-manifest.json`, changelog heading and package release version; (2) full SHA of main release commit, tag target, GitHub Release target, and successful required `ci-gate`; (3) Hex release checksum to a checksum computed from the release build artifact using the registry's documented representation; (4) versioned docs URL; (5) a cold consumer resolution using the exact package version. Hex recommends installing and compiling the published package after publication; Hex versioned docs URLs are distinct from the moving latest docs alias. [CITED: [Hex publishing](https://hex.pm/docs/publish), [Hex publish task](https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html)]

### Pattern 2: Reuse the Phoenix adopter but make Hex source explicit

The current adopter's dependency is `{:lattice_stripe, path: "../../"}` and has its own Mix lockfile, so it proves checked-out source adoption rather than Hex distribution. [VERIFIED: `test_apps/phoenix_adopter/mix.exs:18-25`; `test_apps/phoenix_adopter/README.md:5-24`]

**Recommendation:** Keep the current fast path-dependency suite unchanged for every pull request. Add a release-only input/mode that configures this same host to require the precise just-published Hex version, resolve it in an isolated temporary `MIX_DEPS_PATH`/lock context, then run the compact host suite. Guard that Hex mode so it errors if source remains path-based or resolved dependency version differs from the requested release. This proves installed consumer bytes without forking the application or adding live credentials. The exact mechanism (environment-selected dependency vs. generated temp copy) is discretionary; prefer an explicit mode that cannot silently fall back to the local tree.

Minimum evidence: fetched dependency source is Hex registry; dependency metadata/version exactly matches release; app compiles and selected Checkout/webhook synthetic path passes; no Stripe key or network request is used; result records release SHA, Hex version, and checksum. Keep test scope minimal and reuse existing synthetic transport. [VERIFIED: `test_apps/phoenix_adopter/test/core_flow_test.exs`; `test_apps/phoenix_adopter/config/config.exs:8-10`; `.github/workflows/ci.yml:201-219`]

### Pattern 3: Fail closed on branch-protection mismatch

The auto-merge workflow verifies the latest `ci-gate` and matches the PR head SHA, but after normal `gh pr merge` fails it retries with `--admin`. `gh` documents that option as administrator merge despite unmet requirements / a merge-queue bypass. Remove that branch. On blocked merge, report the PR number, head SHA, merge state and unmet check/conversation requirement, then exit nonzero while leaving the PR open. Do not silently let the job succeed or convert this to manual blanket UAT. [VERIFIED: `.github/workflows/release-pr-automerge.yml:66-92,102-169`; CITED: [gh pr merge](https://cli.github.com/manual/gh_pr_merge), [protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)]

### Pattern 4: Inventory and report before closeout mutation

`git worktree list --porcelain -z` is designed for stable script parsing; parse worktree path records rather than splitting paths by whitespace. For each path, run `git -C <path> status --porcelain=v1 --untracked-files=all` (or documented stable porcelain-v2 equivalent), and report path + branch/SHA + dirty/untracked status. Also verify primary checkout is `main` at release SHA / synchronized to `origin/main` when required. Never auto-stash/clean or call `git worktree remove --force`; Git refuses removal of unclean worktrees unless forced. [CITED: [git worktree](https://git-scm.com/docs/git-worktree), [git status](https://git-scm.com/docs/git-status)]

For PRs, inventory all open PRs rather than sampling or filtering only Release Please/Dependabot. Each record needs PR URL/number, contributor-visible action/comment or review state, disposition, rationale and next action/date, required-check summary, and whether merge occurred. A checker can prove all inventory entries have a recognized disposition and linked evidence; it cannot decide the genuinely ambiguous security or contribution-fit question. [VERIFIED: `.planning/phases/78-release-and-repository-closeout/78-CONTEXT.md:26-31,78-99`; CITED: [GitHub pull request reviews](https://docs.github.com/en/pull-requests/reference/pull-request-reviews)]

### Existing project structure and integration points

| Area | Current asset | Planning consequence |
|------|---------------|----------------------|
| Routine release | `.github/workflows/release.yml` | Extend/reuse exact-SHA proof; do not replace Release Please. |
| Merge | `.github/workflows/release-pr-automerge.yml` | Delete admin retry; improve diagnostic/fail-closed path. |
| Recovery | `.github/workflows/publish-hex.yml` | Preserve exact ref CI wait, version validation, dry-run, idempotent publish/docs-only branches. |
| CI | `.github/workflows/ci.yml` | Existing `ci-gate` includes adopter, API/package/docs/quality and integration checks; only add a new recurring lane if published-Hex smoke recurring value justifies it. |
| Adopter | `test_apps/phoenix_adopter/` | Current lockfile and Mox fixtures reusable; add explicit published package mode, not a second Phoenix application. |
| Hygiene | `scripts/maintainer/repo_hygiene_check.sh` | Existing script checks version agreement, current checkout state and a recent main CI run; current PR logic only warns about Dependabot count and it does not inventory linked worktrees. Extend with precise closeout checks or add a focused read-only closeout verifier. |
| Release truth | `.planning/RELEASE-TRAIN.md` | Update the ledger from the prior 2.2.2 snapshot only after fresh remote checks; preserve split provenance for docs-only refreshes. |
| User-facing contract | `guides/api_stability.md`, `CHANGELOG.md`, README/guides | Confirm release line and optional-field changes remain represented; package version changes should be mechanically cross-checked. |

The local workspace snapshot during research is `main` at `556d0e6` with 67 commits ahead of `origin/main`, several dirty/untracked files, and no linked worktrees reported. This is transient research-time state, not closeout evidence; re-inventory at execution and preserve current dirty paths until their owner resolves them. [VERIFIED: local `git status --short --branch`; local `git worktree list --porcelain`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SemVer/changelog determination | Manual package version edits or custom commit parser | Release Please release proposal plus reviewed API lock | Prevents release metadata divergence; lets the reviewable PR expose unexpected breaking changes. |
| GitHub Actions event chaining | Assume bot-authored push starts another workflow | Existing `workflow_dispatch` and Release Please token behavior | GitHub deliberately suppresses most `GITHUB_TOKEN`-caused workflow events to prevent recursive runs. [CITED: [GitHub Actions events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows)] |
| Elixir package publish validation | Custom tarball publishing client | `mix hex.build`, `mix hex.publish --dry-run`, and `mix hex.publish` | Hex task owns package checks and docs publication; supports separate package/docs actions and documented rollback window. [CITED: [Hex publish task](https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html)] |
| Host boundary proof | Live Stripe API test or fake HTTP server | Existing Phoenix adopter + injected Mox `LatticeStripe.Transport` synthetic responses | Reuses a real SDK request/decode path without external credentials or nondeterminism. |
| Worktree inventory / cleanliness | Parse human Git output, remove dirty worktrees, or inspect `.git/worktrees` internals | `git worktree list --porcelain -z`, `git -C path status --porcelain` | Git provides stable machine-oriented output; force removal explicitly permits deleting dirty worktrees. [CITED: Git docs above] |

**Key insight:** Release correctness is the relationship among independently observable artifacts. A green main workflow, an existing tag, a package listing, or latest HexDocs alone is insufficient; the closeout record must bind each to the same release SHA/version while representing docs-only recovery provenance honestly.

## Common Pitfalls

### Pitfall 1: Accepting the expected version without rechecking the final public API diff

**What goes wrong:** Release Please proposes `2.3.0`, but a changed/removed API entry or changed compatibility promise still ships under a minor version.  
**Why it happens:** Expected version is evidence-based, not a hard-coded override; proposal generation summarizes commits but is not the compatibility proof.  
**How to avoid:** Before accepting the Release PR, compare final `priv/api/current.txt` against the last published snapshot and ensure only four intended optional fields were added; review `guides/api_stability.md`, changelog, minimum API-version prose, and unchanged default. Fail/resolve unexpected changes instead of changing version manually. The previous 75 verification says four entries were additions and no existing lock entries changed; use that as baseline, not as substitute for final diff review. [VERIFIED: `.planning/phases/78-release-and-repository-closeout/78-CONTEXT.md:24-28,102-109`; `.planning/phases/75-typed-contract-updates/75-VERIFICATION.md:38-59`; `.planning/phases/75-typed-contract-updates/75-01-SUMMARY.md`; `.planning/phases/75-typed-contract-updates/75-02-SUMMARY.md`; `guides/api_stability.md:1-69`]

### Pitfall 2: Treating tag CI as proof that `main` is green

**What goes wrong:** Exact tagged SHA passes, but required branch status for the release commit on `main` is absent or newer `main` is different.  
**How to avoid:** Verify commit ancestry/equality and query `ci-gate` result for that precise SHA on the required main/release flow. If GitHub Actions bot merge suppresses push runs, dispatch CI and wait; don't accept another SHA's result. [VERIFIED: `.planning/RELEASE-TRAIN.md:20-29,47-63`; `.github/workflows/release-pr-automerge.yml:171-187`; `.github/workflows/release.yml:241-332`]

### Pitfall 3: “Published” means merely visible in Hex

**What goes wrong:** Correct-looking version exists but package cannot resolve/compile in an adopter, checksum is not tied to source build, or docs latest alias shows a different version.  
**How to avoid:** Cold-fetch exact version from Hex in isolated consumer cache, check dependency resolution source/version, compile and run the minimal adopter path, compare registered checksum to release artifact and probe the explicit `/<version>/` HexDocs URL. Hex describes publication as CDN/registry processing and recommends testing by adding/fetching/compiling in a Mix project. [CITED: [Hex publishing](https://hex.pm/docs/publish), [Hex publish task](https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html)]

### Pitfall 4: Worktree-clean check misses untracked files or corruptly parses paths

**What goes wrong:** `git status --porcelain` default output may collapse untracked directories; whitespace parsing breaks a path with spaces/newlines; only primary checkout is checked.  
**How to avoid:** Parse NUL-delimited porcelain worktree inventory and use per-path status with `--untracked-files=all`; any inspection or auth failure is `unknown/block`, not clean. Do not clean/remove worktrees as part of verification. [CITED: Git docs above]

### Pitfall 5: PR disposition is a local note only or a false “all closed” gate

**What goes wrong:** Contributor cannot find the decision; open deferred PR disappears from maintainer view; closing PRs to hit zero-open target loses valid work.  
**How to avoid:** Make contributor-visible timeline note/review and ledger mirror mandatory; include explicit defer rationale and next step; inventory all open PRs and only gate missing/ambiguous dispositions, not legitimate open count. Escalate only unresolved contribution-fit or security decision. [VERIFIED: `78-CONTEXT.md:26-31,78-99`]

### Pitfall 6: `--admin` masks unmet branch protections

**What goes wrong:** Required conversation resolution or checks can be bypassed by fallback after regular merge fails.  
**How to avoid:** Remove `gh pr merge --admin`; after checks and head match, use only protected normal merge and report unmet rule state. GitHub CLI explicitly documents admin mode as merging without requirements / bypassing merge queue. [VERIFIED: `.github/workflows/release-pr-automerge.yml:139-169`; CITED: [gh pr merge](https://cli.github.com/manual/gh_pr_merge), [branch protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)]

## Code Examples

These are acceptance-command shapes for the planner; status claims use shell exit/output rather than ambiguous prose. [CITED: [git status](https://git-scm.com/docs/git-status), [git worktree](https://git-scm.com/docs/git-worktree)]

```bash
# Per-worktree check; capture non-empty output as dirty and preserve the checkout.
git -C "$worktree_path" status --porcelain=v1 --untracked-files=all

# Inventory emits machine-oriented records; consume NUL terminators so paths are safe.
git worktree list --porcelain -z

# Reuse the existing Phoenix host only after switching dependency source explicitly.
cd test_apps/phoenix_adopter
mix deps.get --check-locked
mix test --warnings-as-errors
```

The published-Hex mode must assert from Mix dependency metadata that `lattice_stripe` resolved at the expected exact Hex version, and should run with clean isolated deps/lock state. Do not copy the local path dependency command as evidence for REL-02. [VERIFIED: `test_apps/phoenix_adopter/mix.exs:18-25`; `test_apps/phoenix_adopter/README.md:5-24`]

## State of the Art

| Old / unsafe approach | Current approach | Impact |
|-----------------------|------------------|--------|
| Human checks only the latest Hex page after publishing | Release SHA-bound registry, checksum, versioned docs and consumer-resolution probes | Detects artifact/source/version drift without a blanket UAT step. |
| Workflow success from a prior merge authorizes current publish | Check `ci-gate` against resolved immutable SHA before publish | Prevents stale/other-ref CI from satisfying release gate. |
| Admin retries are a resilient merge fallback | Protected normal merge, then fail with actionable reason | Preserves required checks and conversation resolution. |
| “Clean checkout” means no tracked modifications in main tree | Machine inventory of all main/linked trees with untracked state | Captures parallel GSD working areas and owner changes. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Exact package checksum can be compared against a locally built Hex artifact using the checksum field exposed for the public release. | Summary / Pattern 1 | Medium: Hash representations may differ between the API's package digest and Hex tarball; resolve from Hex API docs/response before locking the assertion. |
| A2 | A release-only input or generated temporary copy is the smallest safe way to reuse the Phoenix app with a Hex dependency. | Pattern 2 | Low: implementation can choose another explicit mechanism while retaining source/version assertion. |
| A3 | Current dirty/untracked research snapshot belongs to active work and should not be automatically removed. | Existing project structure | High: discarding it could lose user/agent changes; closeout must identify owners and resolve deliberately. |

## Open Questions

1. **What exact checksum representation is authoritative for parity checking?** Hex's public package release API should be inspected against a known release and compared with `mix hex.build` output before implementing an assertion. Do not infer that tarball SHA-256 and registry checksum string are interchangeable.
2. **How does current branch protection surface failed conversation-resolution state to `gh`/REST in this repository?** The workflow should report objective merge/check state but must not attempt changes to repository protection during this release phase.
3. **Which live PRs will remain open at closeout?** Planning-time state is transient; inventory all PRs at execution and only persist decisions after contributor-visible triage.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Git / GitHub CLI | Local inventory, checks, PR triage | Git available; `gh` auth not probed | Research snapshot has primary worktree only | Git checks work locally; remote inventory requires authenticated `gh`/Actions token. |
| Elixir / Mix / Hex | Release build and adopter smoke | Project workflows pin toolchain; local versions not probed in this subtask | `.tool-versions` authoritative for release job | Run in existing GitHub Actions release lane. |
| Hex registry / HexDocs | Post-publish probes and dependency fetch | External service availability not probed | — | Retry transient propagation within bounded timeout then fail with URLs and SHA. |
| Stripe API / credentials | None | Not needed | — | Mox-backed synthetic transport is the normal proof. |

**Missing dependencies with no fallback:** Authenticated remote GitHub state is required for final remote PR/release checks; document operational credential prerequisite if unavailable.  
**Missing dependencies with fallback:** None for local phase planning; no live Stripe service or token is needed for adopter proof.

## Validation Architecture

### Test Framework / evidence surfaces

| Property | Value |
|----------|-------|
| Framework | ExUnit in package + nested Phoenix adopter; shell probes for release/worktree inventory; GitHub Actions `ci-gate` for remote required checks |
| Config file | Root `.github/workflows/ci.yml`; adopter `test_apps/phoenix_adopter/test/test_helper.exs`; current separate nested lockfile |
| Quick run command | `cd test_apps/phoenix_adopter && mix test --warnings-as-errors` (current CI command) |
| Full release gate | Required `ci-gate` on exact release SHA, then publish verifier and Hex-sourced adopter smoke |

### Phase requirements → evidence map

| Req ID | Behavior | Test Type | Automated Command / Probe | File Exists? |
|--------|----------|-----------|---------------------------|--------------|
| REL-01 | Version and API compatibility agree | Release validation | API surface diff/check; release-please proposed version; `mix lattice_stripe.version_prose --check`; package/manifest/changelog consistency script | Compatibility checks exist; Phase 78 final release reconciliation evidence is not yet recorded. |
| REL-02 | Published package and matching GitHub Release/HexDocs work for adopters | Registry + cold consumer smoke | Hex API/release metadata, versioned docs HTTP probe, isolated Mix dependency fetch/compile/test from Hex | Local path adopter exists; published-Hex mode and post-publish verifier do not yet exist. |
| CLOSE-01 | Required CI green on release commit on main | GitHub check query | `ci-gate` check-run status for resolved full SHA + verify main/tag/release commit association | Existing release workflow waits on tag SHA; exact closeout proof for main membership must be reported. |
| CLOSE-02 | Every open PR has disposition evidence | Inventory / evidence completeness | `gh pr list --state open` + per-PR timeline/review/check state + ledger completeness audit | Hygiene script has only targeted PR checks; full ledger/inventory absent. |
| CLOSE-03 | Primary and every linked worktree clean | Read-only local probe | Parse `git worktree list --porcelain -z`; run per-path `git status --porcelain=v1 --untracked-files=all`; check primary main/upstream relationship | Existing hygiene covers current tree status only; linked worktree iteration absent. |

### Sampling Rate

- **Per workflow change:** run Actionlint via existing CI job; test shell verifier against fixtures for clean, tracked-dirty, untracked, path-with-spaces, detached/locked linked worktree, missing `gh`, API/check timeout, and malformed inventory cases.
- **Per release PR:** required `ci-gate` on the current release PR head; verify that stale CI cannot authorize merge.
- **Release gate:** after release is tagged/published, run exact-SHA verifier plus clean Hex-resolved adopter smoke; no credentials/Stripe requests.
- **Final closeout:** read-only fresh inventory of all open PRs and every worktree; any inspection failure/unknown state remains a blocker, never “pass by absence.”

### Wave 0 Gaps

- [ ] A post-publish release evidence verifier that binds current main release commit, `ci-gate`, tag/GitHub Release, Hex version and checksum, versioned HexDocs, and Hex-sourced consumer smoke.
- [ ] A safe published-Hex mode for the existing Phoenix adopter that cannot silently use `path: "../../"`.
- [ ] Remove `--admin` fallback and improve actionable protected-merge failure output.
- [ ] A dated PR closeout ledger plus checker that ensures every open PR has a contributor-visible disposition and check state.
- [ ] Extend/add read-only worktree cleanliness probe to include all porcelain-enumerated worktrees and untracked files; ensure errors fail closed.

## Security Domain

Security enforcement is enabled (no explicit opt-out was found in planning config). This headless library/release phase has no user authentication or product database; relevant controls are workflow authority, credential scope, dependency/source trust, PR contribution decisions, and preserving user-owned local work.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No product auth; yes publishing identity | Use the existing narrow Hex publish key only in publish jobs; never expose it to adopter smoke. |
| V3 Session Management | No | No browser or user sessions. |
| V4 Access Control | Yes (workflow/GitHub) | Existing job-level least privilege; merge must require `ci-gate` and conversation policy; no admin bypass. |
| V5 Input Validation | Yes (manual workflow inputs/PR metadata) | Validate release version/ref shape and resolve to commit before checkout; avoid raw interpolation into shell. |
| V6 Cryptography | Yes (artifact integrity/signatures) | Use Hex's documented package checksum and GitHub's exact SHA; no hand-rolled release signing. |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| `--admin` merge ignores missing policy | Elevation of privilege | Fail closed on normal protected merge errors; preserve PR and report unmet policy. |
| Hex credential leaks to test or PR-controlled code | Information disclosure / elevation | Scope secret to publish job/step after untrusted test steps; least permissions for GITHUB_TOKEN; no new PAT/App during closeout absent demonstrated need. |
| Stale green CI from another SHA is treated as release evidence | Tampering / repudiation | Resolve full commit SHA and select check run whose head SHA exactly equals it; ledger run URL and commit. |
| Dirty owner worktree is force-cleaned or removed | Tampering / availability | Read-only status; block closeout; owner resolves changes; never force removal. |

## Project Constraints (from AGENTS.md)

No root `AGENTS.md` exists. Project-specific verification constraints are carried by the configured [`lattice-verification-policy`](../../../.agents/skills/lattice-verification-policy/SKILL.md): prove deliverables with named passing executable checks; retain human judgment only for its closed irreducible list; use the narrowest honest seam and recurring CI when value justifies it; avoid blanket UAT, redundant checks, quotas, or a backstop in place of evidence. [VERIFIED: `.agents/skills/lattice-verification-policy/SKILL.md:6-25,48-65,86-105,116-128`]

## Sources

### Primary (HIGH confidence)

- `.planning/phases/78-release-and-repository-closeout/78-CONTEXT.md` — locked scope and decisions.
- `.planning/REQUIREMENTS.md` — REL-01, REL-02, CLOSE-01..03.
- `.planning/RELEASE-TRAIN.md` — current 2.2.2 release evidence, exact-SHA standing contract, branch protection and earlier closeout procedure.
- `.planning/phases/75-typed-contract-updates/75-VERIFICATION.md` and `75-01-SUMMARY.md`, `75-02-SUMMARY.md` — additive-only API surface, field count, version scope and unchanged API default.
- `.github/workflows/release.yml`, `release-pr-automerge.yml`, `publish-hex.yml`, `ci.yml` — current release, CI, credentials, and recovery behavior.
- `test_apps/phoenix_adopter/**`, `scripts/maintainer/repo_hygiene_check.sh`, `docs/maintainer-release.md`, `guides/api_stability.md` — consumer host, hygiene, release process and SemVer contract.
- `.agents/skills/lattice-verification-policy/SKILL.md` — executable-evidence and human handoff policy.
- `prompts/README.md` and requested archived research prompts — historical alternatives; prompts README states shipped source/current docs/planning take precedence and that no design system applies.

### Secondary (MEDIUM confidence; official documentation)

- [Release Please Action](https://github.com/googleapis/release-please-action) — manifest workflow, release PR and output semantics.
- [Mix `hex.publish`](https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html) and [Hex publishing](https://hex.pm/docs/publish) — dry run, docs/version paths, package install and publish recovery behavior.
- [GitHub `GITHUB_TOKEN` event behavior](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows) — workflow dispatch exception and suppressed recursive runs.
- [`gh pr merge`](https://cli.github.com/manual/gh_pr_merge) and [protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches) — `--admin` semantics and required branch constraints.
- [`git status`](https://git-scm.com/docs/git-status) and [`git worktree`](https://git-scm.com/docs/git-worktree) — stable porcelain output, worktree enumeration and clean-only removal.
- [GitHub pull request reviews](https://docs.github.com/en/pull-requests/reference/pull-request-reviews) — contributor-visible PR decision surfaces.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — existing workflow and Mix files directly show current stack; official Hex docs checked.
- Architecture: HIGH — current release flow, path adopter boundary, and hygiene script were read; exact artifact checksum format remains open.
- Pitfalls: HIGH for admin override/token/event/worktree behavior (repo plus primary docs); MEDIUM for registry checksum linkage until API representation is confirmed.

**Research date:** 2026-09-24  
**Valid until:** 2026-10-24 (recheck GitHub/Hex state and workflow configuration immediately before execution)
