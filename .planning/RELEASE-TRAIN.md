# LatticeStripe release train

LatticeStripe is on a **sustaining maintenance** release train after v1.7.x.

## Standing contract

- Latest released version: `1.7.3` (Hex + GitHub tag `v1.7.3`).
- `milestone: none` remains the default GSD state — no feature milestones on `main` unless there is clear adopter pull.
- Patch-eligible merged changes on `main` (`docs:`, `fix:`, `chore:`) flow to the next release through **Release Please** (patch bump).
- The train moves only when **`main` is green** (`ci-gate` in CI) and `./scripts/maintainer/repo_hygiene_check.sh` reports **0 BLOCK**.

## Commit style on `main`

| Work type | Commit prefix | Release impact |
|-----------|---------------|----------------|
| Docs, drift notes, credo | `docs:` / `fix:` / `chore:` | Patch |
| Maintenance quick task | `chore:` / `docs:` | Patch |
| Intentional minor feature | Feature branch + PR; `feat:` when releasing | Minor (explicit) |
| `.planning/` only | N/A (CI paths-ignore) | None |

**Avoid** `feat(phase):` on `main` — historical GSD phase commits inflated Release Please to bogus minors (see closed PR #20).

## Cadence

1. Merge maintainer PRs to `main` → `ci-gate` green.
2. Release Please opens a **patch** Release PR (e.g. `1.7.4`).
3. **Release** workflow dispatches CI on the release branch; **Release PR Auto-Merge** merges when `ci-gate` is green.
4. Tag + GitHub Release + Hex publish run automatically on merge.
5. **Manual Hex recovery** (`publish-hex.yml` workflow_dispatch) only when automation fails.

## Silence on the wire

When hygiene passes, Dependabot is drained, and no adopter issues request API work: **no milestone work** — reactive maintenance only.
