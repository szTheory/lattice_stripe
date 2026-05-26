# Roadmap: LatticeStripe

## Milestones

- ✅ **v1.0 — Foundation + Billing + Connect + 1.0 Release** — Phases 1-11, 14-19 (shipped 2026-04-13 to Hex.pm) — [archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 — Accrue unblockers (metering + portal)** — Phases 20-21 (shipped 2026-04-14) — [brief](v1.1-accrue-context.md)
- ✅ **v1.2 — Production Hardening & DX** — Phases 22-31 (shipped 2026-04-17) — [archive](milestones/v1.2-ROADMAP.md)
- ✅ **v1.3 — Production Coverage & Adoption Polish** — Phases 32-42 plus Phase 41.1 follow-through (shipped 2026-05-25 with accepted external-proof gap) — [archive](milestones/v1.3-ROADMAP.md)
- 🚧 **v1.4 — Adoption Closure** — Phases 43-46 (active)

## Current Milestone: v1.4 Adoption Closure

**Goal:** Make the shipped `1.3.x` surface obvious, trustworthy, and easier to evaluate for serious Elixir and Phoenix SaaS teams.

**Why now:** The SDK is already broad for its intended scope; adopter-facing truth, guide clarity, and flagship recipes now unlock more value than another narrow resource family.

**Milestone constraints:**

- Keep recipe/operator guidance primitive-first and library-scoped.
- Do not turn LatticeStripe into a billing workflow package or Accrue substitute.
- Preserve the accepted Phase `41.1` external-proof boundary truthfully instead of flattening it into a false close.

## Phases

### Phase 43: Public Truth Baseline

**Goal**: Align public package, version, install, and shipped-surface truth across the highest-visibility onboarding documents.
**Depends on**: Phase 42
**Plans**: 2 plans

Plans:

- [x] 43-01-PLAN.md — Audit and reconcile README, CHANGELOG, Getting Started, cheatsheet, and HexDocs-facing install truth
- [x] 43-02-PLAN.md — Expand docs-truth checks so onboarding/version drift fails fast

**Details:**
This phase closes the adopter-trust gap where public docs can understate or misstate the shipped `1.3.x` surface even while narrower README checks stay green.

### Phase 44: Guide Discovery & Support Truth

**Goal**: Make already-shipped high-leverage surfaces easy to discover from the main docs entry points and guide graph.
**Depends on**: Phase 43
**Plans**: 2 plans

Plans:

- [x] 44-01-PLAN.md — Rework docs entry points and cross-links for shipped high-leverage surfaces
- [x] 44-02-PLAN.md — Publish support-truth notes and navigation paths that keep guidance honest and easy to follow

**Details:**
This phase improves findability and orientation so adopters can move from onboarding to the right canonical guides and recipes without reverse-engineering the repo.

### Phase 45: Flagship Recipes I

**Goal**: Publish the first two flagship SaaS flow guides using already-shipped primitives.
**Depends on**: Phase 44
**Plans**: 2 plans

Plans:

- [ ] 45-01-PLAN.md — Checkout signup plus portal follow-through flagship recipe
- [ ] 45-02-PLAN.md — Metering runtime plus reconciliation flagship recipe

**Details:**
These recipes should feel concrete and operator-useful while staying firmly inside the SDK boundary rather than turning into application workflow abstractions.

### Phase 46: Flagship Recipes II & Planning Truth Closure

**Goal**: Publish the remaining flagship guides and reconcile planning truth around the milestone close posture.
**Depends on**: Phase 45
**Plans**: 2 plans

Plans:

- [ ] 46-01-PLAN.md — Connect platform flow and quote-to-billing operator guidance
- [ ] 46-02-PLAN.md — Reconcile roadmap, requirements, and state truth while preserving the explicit Phase `41.1` external-proof boundary

**Details:**
This phase finishes the flagship recipe set and ensures the milestone artifacts tell the truth about what v1.4 closes versus what remains an accepted external-only follow-through item.

## Next Step

Run `$gsd-plan-phase 44` to start execution.
