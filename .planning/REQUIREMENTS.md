# Requirements: LatticeStripe v1.4

**Defined:** 2026-05-26
**Milestone:** v1.4 (Adoption Closure)
**Core Value:** Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.

## v1.4 Requirements

### Public Truth

- [x] **TRUTH-01**: Public package, version, and install guidance agrees across README, CHANGELOG, `guides/getting-started.md`, cheatsheet, and HexDocs-facing extras.
- [x] **TRUTH-02**: High-visibility docs accurately present the shipped `1.3.x` surface, including the major resource families and DX guides that already exist in repo truth.

### Docs Verification

- [x] **VERIFY-01**: Docs-truth regression checks fail when first-run onboarding install/version snippets drift from the shipped package line.
- [ ] **VERIFY-02**: Docs-truth coverage extends beyond README to the main onboarding and discovery surfaces adopters actually hit first.

### Guide Discovery

- [ ] **GUIDE-01**: Developers can find canonical guides for already-shipped high-leverage surfaces from the main docs entry points.
- [ ] **GUIDE-02**: Cross-links between recipes, resource guides, and onboarding docs make the shipped surface easier to navigate without guesswork.

### Flagship Recipes

- [ ] **RECIPE-01**: A developer can follow a flagship recipe for Checkout signup plus portal follow-through using shipped LatticeStripe primitives.
- [ ] **RECIPE-02**: A developer can follow a flagship recipe for metering runtime plus reconciliation using shipped LatticeStripe primitives.
- [ ] **RECIPE-03**: A developer can follow a flagship recipe for a Connect platform flow using shipped LatticeStripe primitives.
- [ ] **RECIPE-04**: Quote-to-billing operator guidance explains the shipped flow honestly and preserves the explicit Phase `41.1` external-proof boundary.

### Planning Truth

- [ ] **PLAN-01**: Roadmap, requirements, and state artifacts reflect v1.4 as an adoption-closure milestone and preserve the accepted Phase `41.1` follow-through truthfully.

## v2+ Requirements

Deferred until the adoption-closure work is complete and re-evaluated.

### Future Wedges

- **ADV-01**: Thin-event webhook support and guidance
- **TAX-01**: Tax resource-family coverage

## Out of Scope

| Feature | Reason |
|---------|--------|
| Thin-event webhook implementation | Leading post-adoption code wedge, but lower leverage than adoption closure for this milestone |
| Tax resource-family implementation | Valuable breadth candidate, but explicitly deferred until after adoption closure |
| Billing-engine abstractions, entitlement logic, or dunning workflows | Belong downstream in Accrue or application code, not in the SDK |
| Resolving Phase `41.1` as a merge-blocking milestone requirement | Real-sandbox proof remains valuable, but the milestone must preserve that boundary honestly rather than hinge all closure on it |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TRUTH-01 | Phase 43 | Complete |
| TRUTH-02 | Phase 43 | Complete |
| VERIFY-01 | Phase 43 | Complete |
| VERIFY-02 | Phase 44 | Pending |
| GUIDE-01 | Phase 44 | Pending |
| GUIDE-02 | Phase 44 | Pending |
| RECIPE-01 | Phase 45 | Pending |
| RECIPE-02 | Phase 45 | Pending |
| RECIPE-03 | Phase 46 | Pending |
| RECIPE-04 | Phase 46 | Pending |
| PLAN-01 | Phase 46 | Pending |

**Coverage:**
- v1.4 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0

---
*Requirements defined: 2026-05-26*
*Last updated: 2026-05-26 after initial definition*
