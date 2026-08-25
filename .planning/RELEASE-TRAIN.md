# LatticeStripe release train

LatticeStripe's long-term posture is **sustaining maintenance**. v1.11 is one
bounded reader-first quality closure on that train; it does not reopen broad
feature work.

## Current release truth

- Latest released version: `2.2.0`.
- GitHub Release [`v2.2.0`](https://github.com/szTheory/lattice_stripe/releases/tag/v2.2.0),
  tag `v2.2.0`, remote `main`, Hex 2.2.0, and HexDocs 2.2.0 all resolve to the
  release completed on 2026-08-25 from commit
  `984fa7cd76b338322d5856e1dc7d4a57ff84d19f`.
- Active GSD milestone: **v1.11 Reader-First Quality Closure**.
- Target package: **2.2.1**. It is not published yet and must not be described
  as shipped until the final release-SHA checks below pass.
- `milestone: none` remains the default GSD state after v1.11 closes; no later
  feature milestone starts without clear adopter pull.

## Standing contract

- Patch-eligible merged changes on `main` (`docs:`, `fix:`, `chore:`) flow to
  the next release through **Release Please**.
- The train moves only when **`main` is green** (`ci-gate`) and
  `./scripts/maintainer/repo_hygiene_check.sh` reports **0 BLOCK**.
- A release is not complete until GitHub Release, tag, Hex, HexDocs, and the
  successful `ci-gate` all identify the same release commit.
- Live Stripe claims that cannot be proved by source-backed documentation or a
  passing stripe-mock test remain explicit external-verification boundaries.

## Verified 2.2.0 baseline

Audited against the public remotes on 2026-08-25:

| Surface | Evidence | Status |
|---------|----------|--------|
| Release PR | [#56](https://github.com/szTheory/lattice_stripe/pull/56) merged as `984fa7c` | verified |
| Remote `main` and tag | Both identify `984fa7c` | verified |
| CI | [run 32892160837](https://github.com/szTheory/lattice_stripe/actions/runs/32892160837), including `ci-gate`, succeeded on `984fa7c` | verified |
| Release workflow | [run 32892163311](https://github.com/szTheory/lattice_stripe/actions/runs/32892163311) succeeded on `984fa7c` | verified |
| Hex | [lattice_stripe 2.2.0](https://hex.pm/packages/lattice_stripe/2.2.0) published 2026-08-25 | verified |
| HexDocs | [2.2.0 docs](https://hexdocs.pm/lattice_stripe/2.2.0/) resolve publicly | verified |

This table establishes the v1.11 starting baseline only. It is not evidence
that 2.2.1 or the v1.11 maintenance pause has completed.

## v1.11 release-candidate stop gates

All gates must be re-evaluated from the exact future 2.2.1 release candidate:

- [ ] Local `mix ci`, optional integration lanes, coverage, package dry-run,
      API lock, docs truth, and repository hygiene pass after the final change.
- [ ] The candidate PR has a successful current-head `ci-gate` and no unresolved
      review conversations.
- [ ] Remote `main` equals the 2.2.1 tag and the successful release/CI SHA.
- [ ] GitHub Release, Hex, and HexDocs expose 2.2.1 from that same SHA.
- [ ] Open PRs are resolved; open issues are individually triaged rather than
      required to be closed indiscriminately.
- [ ] Temporary milestone worktrees are clean and removed after integration;
      the primary worktree is clean and synchronized with remote `main`.
- [ ] Branch protection requires an up-to-date `ci-gate`, resolved
      conversations, and continues to forbid force pushes and deletion.

## Remote operations snapshot

Read-only audit at 2026-08-25 20:04 UTC:

- **Open PRs:** 0.
- **Open issues:** 1 — [#13, Stripe API drift tracker](https://github.com/szTheory/lattice_stripe/issues/13),
  correctly labeled `stripe-drift` and `maintenance`. It is accepted
  non-release-blocking radar; its body/comment release-line wording still
  references older 1.7.x/2.1.x baselines and should receive a 2.2.x status sync
  during final issue triage.
- **Security automation:** vulnerability alerts and automated security fixes are
  enabled.
- **Branch protection:** `ci-gate` is required and force pushes/deletion are
  disabled. The required-check strictness is currently off and conversation
  resolution is not required; both are pending CLOSE-04 actions.
- **Worktrees:** milestone integration and specialist worktrees are still active.
  Their existence is expected during execution and means the clean-pause gate is
  not yet satisfied.

Re-run this audit at Phase 73; snapshots are evidence, not permanent truth.

## Commit style on `main`

| Work type | Commit prefix | Release impact |
|-----------|---------------|----------------|
| Docs, drift notes, credo | `docs:` / `fix:` / `chore:` | Patch |
| Maintenance quick task | `chore:` / `docs:` | Patch |
| Intentional minor feature | Feature branch + PR; `feat:` when releasing | Minor (explicit) |
| `.planning/` only | N/A (CI paths-ignore) | None |

Avoid `feat(phase):` on `main`; historical GSD phase commits inflated Release
Please to bogus minors (see closed PR #20).

## Cadence

1. Merge maintainer PRs to `main`; require `ci-gate` green on the current head.
2. Release Please opens the next patch Release PR.
3. Release PR CI and auto-merge complete only after the required gate succeeds.
4. Tag, GitHub Release, and Hex publication run automatically and are verified
   against the same SHA.
5. Use manual Hex recovery (`publish-hex.yml` workflow dispatch) only when the
   automated publish failed.

## Silence on the wire

After the v1.11 stop gates pass, Dependabot is drained, and no adopter issue
requests API work: return to reactive maintenance. Do not manufacture another
cleanup milestone past the point of diminishing returns.
