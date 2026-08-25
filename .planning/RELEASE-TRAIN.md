# LatticeStripe release train

LatticeStripe's long-term posture is **sustaining maintenance**. v1.11 was a
bounded reader-first quality closure on that train; it did not reopen broad
feature work.

## Current release truth

- Latest released version: `2.2.2`.
- GitHub Release [`v2.2.2`](https://github.com/szTheory/lattice_stripe/releases/tag/v2.2.2),
  tag `v2.2.2`, and Hex 2.2.2 resolve to the release completed on 2026-08-25
  from commit `7f290b11ddc5dcdefc9e6e0aa5cad43e9d734440`. HexDocs was refreshed by
  [docs-only run 32900456977](https://github.com/szTheory/lattice_stripe/actions/runs/32900456977)
  from exact-green archive SHA `10baf33770bdeebd94b5a04754c83740046326f6`
  under accepted risk `R73-01`.
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

## Verified final 2.2.2 release

Audited against the public remotes on 2026-08-25:

| Surface | Evidence | Status |
|---------|----------|--------|
| Milestone/audit PRs | [#57](https://github.com/szTheory/lattice_stripe/pull/57) and [#61](https://github.com/szTheory/lattice_stripe/pull/61) merged after current-head CI | verified |
| Release PR | [#62](https://github.com/szTheory/lattice_stripe/pull/62) produced release commit/tag `7f290b1` | verified |
| CI and release | [run 32899071873](https://github.com/szTheory/lattice_stripe/actions/runs/32899071873) passed exact-SHA `ci-gate`, authenticated dry-run, publish, and registry verification on `7f290b1` | verified |
| Hex | [lattice_stripe 2.2.2](https://hex.pm/packages/lattice_stripe/2.2.2) published with checksum `0d990ceaeb2794a24de200e7f7cff769491cb284350c148abdc02946fb66fed8` | verified |
| HexDocs | [2.2.2 docs](https://hexdocs.pm/lattice_stripe/2.2.2/) resolve publicly with final prose from exact-green archive SHA `10baf33770bdeebd94b5a04754c83740046326f6`; [docs-only run 32900456977](https://github.com/szTheory/lattice_stripe/actions/runs/32900456977) succeeded | verified with split provenance |

The package tag remains the immutable release commit. The docs-only milestone
closure refreshed HexDocs from an exact-green same-version source without
changing the package.

## v1.11 release stop gates

All gates were re-evaluated from the exact final 2.2.2 release candidate:

- [x] Local `mix ci`, optional integration lanes, coverage, package dry-run,
      API lock, docs truth, and repository hygiene pass after the final change.
- [x] The candidate PR has a successful current-head `ci-gate` and no unresolved
      review conversations.
- [x] The 2.2.2 tag and successful release workflow identify the release SHA.
- [x] GitHub Release and Hex expose 2.2.2 from that release SHA; HexDocs exposes
      the same version with its accepted docs-only archive-SHA provenance recorded.
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
  non-release-blocking radar; its status is synchronized to the published 2.2.2 line.
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
