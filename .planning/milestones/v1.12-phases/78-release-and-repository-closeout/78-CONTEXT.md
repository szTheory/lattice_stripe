# Phase 78: Release and Repository Closeout - Context

**Gathered:** 2026-09-24  
**Status:** Ready for planning

<domain>
## Phase Boundary

Publish and verify the v1.12 package release, with SemVer reflecting the additive public API changes; prove the published package and matching GitHub Release and HexDocs from the release commit; require green `ci-gate` on the exact `main` release SHA; record a disposition for every open pull request; and prove that the primary checkout and all linked Git worktrees are clean. Keep the work within release and repository closeout. Preserve the SDK's public behavior and the default Stripe API version. This is a headless library: HexDocs, package installation, CI output, release evidence, and maintainer workflow are its relevant user experience; visual UI design is inapplicable.

</domain>

<decisions>
## Implementation Decisions

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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract and project policy
- `.planning/ROADMAP.md` §"Phase 78: Release and Repository Closeout" — goal, requirements, and success criteria.
- `.planning/REQUIREMENTS.md` §REL-01, REL-02, CLOSE-01, CLOSE-02, CLOSE-03 — release and closeout outcomes.
- `.planning/PROJECT.md` §"Maintainer Intent" and §"Verification and Automation Default" — milestone close conditions and shift-left/automation posture.
- `.planning/STATE.md` §"Accumulated Context" — milestone decisions, release close conditions, and adopter CI preference.
- `.planning/RELEASE-TRAIN.md` — current release train, commit classification, exact-SHA evidence contract, and recovery expectations.
- `.agents/skills/lattice-verification-policy/SKILL.md` — named executable evidence, when a human decision is genuinely needed, and no blanket UAT handoff.

### Compatibility and release operations
- `guides/api_stability.md` §"Release meanings" — patch/minor/major compatibility definitions.
- `.planning/phases/75-typed-contract-updates/75-VERIFICATION.md` and `75-01-SUMMARY.md`, `75-02-SUMMARY.md` — reviewed additive API changes, passing compatibility proof, and decision to leave versioning to this release phase.
- `.planning/phases/75-typed-contract-updates/75-EVIDENCE.md` — exact provenance and API-version constraints for new fields.
- `docs/maintainer-release.md` — normal and recovery release operations and CI expectations.
- `.github/workflows/release.yml`, `.github/workflows/release-pr-automerge.yml`, `.github/workflows/publish-hex.yml` — Release Please, branch protection, tag, publish, and recovery behavior.
- `.github/workflows/ci.yml` — `ci-gate`, adopter, package, docs, and quality checks.
- `release-please-config.json`, `.release-please-manifest.json`, `mix.exs`, and `CHANGELOG.md` — version/changelog sources and public package metadata.
- `scripts/maintainer/repo_hygiene_check.sh` — existing local repository release preflight.

### Published-package adoption proof and repository closeout
- `.planning/phases/76-phoenix-adopter-core-flow/76-CONTEXT.md` and `76-RESEARCH.md` — test-only Phoenix host boundary and the distinction between local path-dependency proof and published-package proof.
- `.planning/phases/77-adopter-edge-profiles-and-ci/77-CONTEXT.md` and `.github/workflows/ci.yml` — adopter profiles and deterministic CI gate.
- `test_apps/phoenix_adopter/` — reusable synthetic adopter fixtures and current path-dependency setup; published-package smoke must override that dependency source explicitly.
- `.planning/RELEASE-TRAIN.md` — PR dispositions, branch protection, and closeout expectations.
- Git official references: `https://git-scm.com/docs/git-worktree` and `https://git-scm.com/docs/git-status` — machine-readable worktree inventory and non-destructive cleanliness checks.
- GitHub official references: `https://docs.github.com/en/pull-requests/reference/pull-request-reviews` and `https://docs.github.com/en/actions/concepts/security/github_token` — contributor-visible review states and workflow token event behavior.

### Project research and authoritative release references
- `prompts/README.md` — current-versus-historical research precedence; confirms no separate brand book and that this is a headless library.
- `prompts/archive/elixir-oss-lib-ci-cd-best-practices-deep-research.md` and `prompts/archive/elixir-opensource-libs-best-practices-deep-research.md` — historical release, CI, package, docs, and maintainer-DX alternatives; reconcile with shipped workflows.
- `prompts/archive/elixir-best-practices-deep-research.md` — Elixir ecosystem expectations and least-surprise library guidance.
- `prompts/archive/stripe-sdk-api-surface-area-deep-research.md` and `prompts/archive/The definitive Stripe library gap in Elixir - a master research document.md` — historical Stripe SDK maintenance/release lessons; shipped implementation and current planning take precedence.
- Release Please action documentation: `https://github.com/googleapis/release-please-action` — conventional commits, reviewable release PRs, token behavior, and manifest flow.
- Hex publish task documentation: `https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html` — package/docs publication, dry-run, and recovery semantics.
- Hex publishing documentation: `https://hex.pm/docs/publish` — package publishing and versioned docs.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Release Please already owns version bumps, changelog release sections, tags, GitHub Releases, and routine Hex publication.
- `ci-gate` aggregates the release-relevant CI jobs, including tests, docs truth, package build, integration, quality, and the test-only Phoenix adopter.
- `publish-hex.yml` is an authenticated manual recovery path with exact-ref CI checking, dry-run, docs-only mode, version validation, and idempotency.
- `test_apps/phoenix_adopter` exercises a real Phoenix host with synthetic transport responses and has a separate lockfile; it currently uses a path dependency and therefore does not itself prove Hex installation.
- `scripts/maintainer/repo_hygiene_check.sh` and `git worktree list --porcelain` provide existing or standard inputs for automated closeout checks.

### Established Patterns
- `guides/api_stability.md` defines optional public fields as additive/minor-line changes; the Phase 75 API lock and summaries record four additions and no breaking changes.
- A successful gate must identify the exact SHA being released. Package version, tag, GitHub Release, Hex, and HexDocs should be reconciled by executable checks and an auditable closeout record.
- Release Please's `GITHUB_TOKEN` event behavior is why the project has a fine-grained `RELEASE_PLEASE_TOKEN` and explicit CI dispatches; do not simplify those event boundaries without validating the whole chain.
- Existing GSD commits are already ahead of `origin/main`; closeout must re-inventory the current branch and worktrees and preserve unrelated local changes rather than assuming a clean starting tree.

### Integration Points
- Add published-Hex smoke and registry/docs verification to the release boundary, separate from the local path-dependency adopter suite.
- The auto-merge workflow currently retries with `gh pr merge --admin`; remove that protection bypass or fail closed before relying on it for the release PR.
- PR disposition evidence should join GitHub's contributor-visible review/comment state with a dated, linked milestone ledger; automated checks can verify completeness and required CI but cannot decide ambiguous contribution intent.
- Final clean-state verification must cover the primary checkout and every linked worktree, including untracked files, before marking CLOSE-03 complete.

</code_context>

<specifics>
## Specific Ideas

- Expected package version is `2.3.0` if the final compatibility review still shows only the Phase 75 additive fields; let the generated Release Please proposal and final API diff confirm it.
- Keep the Stripe API default at `2026-03-25.dahlia`.
- Publish from the exact green release commit, then independently prove the published Hex package can be resolved and exercised by a minimal adopter with no live Stripe credentials.
- Use explicit PR dispositions such as merge, request changes, defer with reason/next step, or close with reason; do not equate inactivity with abandonment.
- There is no separate brand book in `prompts/`; user experience here means straightforward package installation, versioned docs, accurate release notes, clear CI failures, and predictable maintainer recovery steps.
</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 78. A GitHub App migration for release credentials may be reconsidered separately if PAT rotation or token scope becomes a demonstrated problem; do not broaden this release closeout to redesign authentication.

</deferred>

---

*Phase: 78-release-and-repository-closeout*  
*Context gathered: 2026-09-24*
