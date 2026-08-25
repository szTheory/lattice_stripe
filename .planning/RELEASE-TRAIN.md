# LatticeStripe release train

LatticeStripe's long-term posture is **sustaining maintenance**. v1.11 was a
bounded reader-first quality closure on that train; it did not reopen broad
feature work.

## Current release truth

- Latest released version: `2.2.1`.
- GitHub Release [`v2.2.1`](https://github.com/szTheory/lattice_stripe/releases/tag/v2.2.1),
  tag `v2.2.1`, Hex 2.2.1, and HexDocs 2.2.1 resolve to the release completed
  on 2026-08-25 from commit `058f64b9602b2bd08b70a8413eeb16260512eb73`.
- Latest completed GSD milestone: **v1.11 Reader-First Quality Closure**.
- `milestone: none` is the default GSD state after v1.11; no later
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

## Verified 2.2.1 release

Audited against the public remotes on 2026-08-25:

| Surface | Evidence | Status |
|---------|----------|--------|
| Milestone PR | [#57](https://github.com/szTheory/lattice_stripe/pull/57) merged as `8586473` after current-head CI | verified |
| Release PR | [#58](https://github.com/szTheory/lattice_stripe/pull/58) produced release commit/tag `058f64b` | verified |
| CI and release | [run 32895251954](https://github.com/szTheory/lattice_stripe/actions/runs/32895251954) passed `ci-gate`, authenticated dry-run, publish, and registry verification on `058f64b` | verified |
| Hex | [lattice_stripe 2.2.1](https://hex.pm/packages/lattice_stripe/2.2.1) published with checksum `8eafac9fb365c6309ed145e6945addf3096549266c23c027d366c921e0e459bf` | verified |
| HexDocs | [2.2.1 docs](https://hexdocs.pm/lattice_stripe/2.2.1/) resolve publicly | verified |

The package tag remains the immutable release commit. A docs-only milestone
closure may refresh HexDocs from final `main` without changing the package.

## v1.11 release stop gates

All gates were re-evaluated from the exact 2.2.1 release candidate:

- [x] Local `mix ci`, optional integration lanes, coverage, package dry-run,
      API lock, docs truth, and repository hygiene pass after the final change.
- [x] The candidate PR has a successful current-head `ci-gate` and no unresolved
      review conversations.
- [x] The 2.2.1 tag and successful release workflow identify the release SHA.
- [x] GitHub Release, Hex, and HexDocs expose 2.2.1 from that release SHA.
- [x] Open PRs are resolved; open issues are individually triaged rather than
      required to be closed indiscriminately.
- [x] Specialist worktrees were removed; the closure worktree is removed after integration;
      the primary worktree is clean and synchronized with remote `main`.
- [x] Branch protection requires an up-to-date `ci-gate`, resolved
      conversations, and continues to forbid force pushes and deletion.

## Remote operations snapshot

Read-only audit at milestone close on 2026-08-25:

- **Open PRs:** 0.
- **Open issues:** 1 — [#13, Stripe API drift tracker](https://github.com/szTheory/lattice_stripe/issues/13),
  correctly labeled `stripe-drift` and `maintenance`. It is accepted
  non-release-blocking radar; its status is synchronized to the published 2.2.1 line.
- **Security automation:** vulnerability alerts and automated security fixes are
  enabled.
- **Branch protection:** strict current-head `ci-gate`, administrator enforcement,
  and resolved conversations are required; force pushes and deletion are disabled.
- **Worktrees:** specialist worktrees are removed. The final closure worktree is
  temporary and is removed immediately after its PR lands.

This snapshot records Phase 73 close-time truth; future operations must still
re-check live state rather than treating it as permanent.

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

The v1.11 stop gates passed and no adopter issue requests API work, so the
project is in reactive maintenance. Do not manufacture another
cleanup milestone past the point of diminishing returns.
