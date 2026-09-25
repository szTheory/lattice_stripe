# Phase 78: Release and Repository Closeout - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-24  
**Phase:** 78-release-and-repository-closeout  
**Areas discussed:** version and release evidence, release automation and recovery, pull request triage and clean worktrees

---

## Version and release evidence

| Option | Description | Selected |
|--------|-------------|----------|
| Release Please with exact-SHA proof and a published-Hex adopter smoke | Retains generated version/changelog/release artifacts, proves the exact release commit and registry artifacts, and tests Hex installation rather than relying only on the current path dependency. | ✓ |
| Existing automation plus manual post-publish checklist | Uses fewer new checks but leaves drift detection and successful package installation dependent on a person. | |
| Fully manual version/tag/Hex publication | Offers direct control but duplicates automation and increases mismatch and credential-handling risk; retain only as recovery. | |

**User's choice:** Discuss all areas and auto-decide; selected the Release Please path with executable evidence.  
**Notes:** Phase 75 records four additive public field entries and no breaking API changes. SemVer policy makes `2.3.0` the expected proposal; final diff and generated Release Please PR remain the release gate. Keep default Stripe API version `2026-03-25.dahlia`.

## Release automation and recovery path

| Option | Description | Selected |
|--------|-------------|----------|
| Preserve the existing Release Please automated flow, require exact-SHA checks, keep manual publishing recovery-only | Fits the current release train and avoids routine human handoffs; requires careful token/event and idempotency handling. | ✓ |
| Migrate to a GitHub App token before this release | May reduce long-lived PAT exposure, but adds setup and another credential system to a release already in progress. | |
| Add a human approval gate before Hex publication | Could provide a deliberate policy pause but adds a routine handoff after reproducible checks and can stall the release. | |

**User's choice:** Discuss all areas and auto-decide; retain automated release with the existing documented credential path.  
**Notes:** Keep credentials least-privileged and narrowly scoped. Recovery stays explicit and auditable. Do not permit `--admin` to bypass branch protection; fail closed when required checks or protections are unmet. Use the existing workflow-token behavior rather than removing explicit dispatches without end-to-end evidence.

## Pull request triage and clean worktrees

| Option | Description | Selected |
|--------|-------------|----------|
| Record disposition in GitHub and a linked closeout ledger; automate inventory/completeness checks | Makes contributor decisions visible and leaves a dated milestone audit; objective PR/check/worktree state is machine-verifiable. | ✓ |
| Use a closeout ledger as the sole disposition record | Simpler but can become stale and leaves the decision less visible to contributors. | |
| Automatically close stale PRs and force-remove linked worktrees | May reduce apparent backlog but can discard contributor intent and uncommitted work. | |

**User's choice:** Discuss all areas and auto-decide; use contributor-visible dispositions plus an auditable snapshot and read-only clean-state proof.  
**Notes:** A deferred PR may remain open when it has a reason and next step. Never close by age alone or discard dirty/unowned worktree changes. Validate all paths from `git worktree list --porcelain` with machine-readable status including untracked files. The current roadmap requires recorded disposition for every open PR; it does not require closing every PR.

## the agent's Discretion

- Choose the smallest reliable published-Hex verification and adopter smoke implementation.
- Preserve the current token/recovery architecture during closeout unless a concrete security or correctness defect requires a change.
- Escalate only ambiguous semantic contribution decisions or a novel one-way API decision that existing compatibility checks cannot resolve.
- No visual UI, brand-book, Ecto persistence, or Phoenix product work applies to this headless release phase.

## Deferred Ideas

- GitHub App credential migration: reconsider only if PAT rotation/scope proves problematic; it is not required to deliver this release.
