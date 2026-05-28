# Post-v1.x Maintenance Posture

Updated: 2026-05-28

## Status

LatticeStripe v1.x is **feature-complete for intended scope**. Operate as a **finished OSS SDK** in reactive maintenance — not an active build track.

## Public surface (no website)

| Surface | URL / path | Purpose |
|---------|------------|---------|
| README | `README.md` | Discovery, install, route-by-intent |
| HexDocs | https://hexdocs.pm/lattice_stripe | API reference + guides |
| Hex package | https://hex.pm/packages/lattice_stripe | Install (`~> 1.7`) |
| Scope | `guides/scope.md` | v1.x boundaries |

**Decision:** No marketing website. Duplicates HexDocs; low ROI for an SDK library.

## Adoption posture

**Pure maintenance / silence** until external pull — no scheduled Forum post, blog, or launch site. Optional later: one short Elixir Forum post or Accrue doc cross-link only if visibility becomes a goal.

## When to act

| Trigger | Response | GSD |
|---------|----------|-----|
| Bug report / wrong Stripe behavior | Fix + test; semver patch if needed | `/gsd-quick` or `/gsd-debug` |
| Stripe API drift | Narrow update + CHANGELOG | `/gsd-quick` or milestone if large |
| Adopter needs new resource family | Document pull; narrow implementation | `/gsd-new-milestone` if multi-phase |
| Doc defect | Fix + `docs_truth` lock | `/gsd-quick` |
| TAX-01/02 or specialist families | Adopter pull only | Per `guides/scope.md` |

## When NOT to act

- Doc nits without adopter impact
- Structured v1.10 milestone (assessment wedges closed 2026-05-28)
- Hex bump for doc-only changes
- Marketing website or second docs system

## Closed in 2026-05-28 session

Quick tasks: 260527-tkc (Wedge A), 260527-tm1 (Wedge B), 260527-tp8 (Gap 2), 260527-tqf (PLAN-01).
