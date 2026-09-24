# Requirements: LatticeStripe

**Defined:** 2026-09-23
**Milestone:** v1.12 API Contract Freshness and Adopter Proof
**Core Value:** Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.

## v1 Requirements

### Stripe API Contract Freshness

- [x] **DRIFT-01**: Maintainers can trace candidate changes in already-supported Stripe resources to stable, versioned Stripe API sources and distinguish applicable changes from preview or OpenAPI-shape noise.
- [x] **DRIFT-02**: Adopters can access selected high-value, stable Stripe fields through typed resource fields while unmodeled response fields remain available through the existing `extra` behavior.
- [x] **DRIFT-03**: Maintainers can verify promoted field decoding and compatibility through focused tests without removing or changing existing public behavior.
- [x] **DRIFT-04**: Adopters can find the supported API-version and promoted-field contract documented; the default API version changes only when compatibility evidence justifies it.

### Phoenix Adopter Proof

- [ ] **ADOPT-01**: Maintainers can run one test-only Phoenix application that imports the checked-out LatticeStripe package as a dependency and verifies host configuration and supervision.
- [ ] **ADOPT-02**: An adopter test can exercise a common Checkout or subscription flow through typed responses and webhook handling using synthetic data and no live Stripe credentials.
- [ ] **ADOPT-03**: The adopter can opt into B2B invoicing, usage reconciliation, and Connect tenant-context profiles that exercise distinct SDK contracts without implementing application billing policy.
- [ ] **ADOPT-04**: The adopter proof covers meaningful integration boundaries, including error handling, pagination or streaming, idempotency, and webhook verification, where relevant to the selected flows.
- [ ] **ADOPT-05**: CI can run the adopter proof deterministically without live Stripe credentials or production adopter data.

### Release and Milestone Closeout

- [ ] **REL-01**: Maintainers can cut and verify a new package release whose SemVer and published API-version contract reflect the compatibility evidence from this milestone.
- [ ] **REL-02**: Adopters can install the new release from Hex and access its matching GitHub release and HexDocs documentation.
- [ ] **CLOSE-01**: Maintainers can confirm that all required CI checks are green on the release commit on `main`.
- [ ] **CLOSE-02**: Every open pull request is reviewed and left with a recorded triage disposition before milestone close.
- [ ] **CLOSE-03**: The primary checkout and all Git worktrees are clean when the milestone closes.

## Future Requirements

- Property-based testing for pure invariants, only if this milestone's triage or adopter proof identifies a high-risk invariant better covered by generated cases.
- Additional adopter profiles or Stripe resource families, only when a named adopter job and distinct reusable SDK contract justify their maintenance cost.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Promoting every one of the 104 reported drift candidates | Candidates require stable-version, semantic, and adopter-value triage; raw count does not establish value. |
| Wrappers for all 94 unmodeled Stripe object types | Object count does not establish a missing adopter workflow; specialist breadth remains pull-driven. |
| Changing the default Stripe API version by date alone | The newer stable version includes compatibility-sensitive behavior and must be evaluated separately. |
| Multiple industry sample applications or an application billing engine | LatticeStripe owns Stripe-shaped primitives; adopter applications own billing orchestration and domain policy. |
| Live Stripe credentials or real adopter data in CI fixtures | Synthetic, deterministic proof is sufficient for this host-app boundary and avoids secret/data handling. |
| Blanket property-based test conversion | Add generators only when a specific high-risk invariant demonstrates the need. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DRIFT-01 | Phase 74 | Complete |
| DRIFT-02 | Phase 75 | Complete |
| DRIFT-03 | Phase 75 | Complete |
| DRIFT-04 | Phase 75 | Complete |
| ADOPT-01 | Phase 76 | Pending |
| ADOPT-02 | Phase 76 | Pending |
| ADOPT-03 | Phase 77 | Pending |
| ADOPT-04 | Phase 77 | Pending |
| ADOPT-05 | Phase 77 | Pending |
| REL-01 | Phase 78 | Pending |
| REL-02 | Phase 78 | Pending |
| CLOSE-01 | Phase 78 | Pending |
| CLOSE-02 | Phase 78 | Pending |
| CLOSE-03 | Phase 78 | Pending |

**Coverage:**

- v1 requirements: 14 total
- Mapped to phases: 14
- Unmapped: 0 ✓

---
*Requirements defined: 2026-09-23*
*Last updated: 2026-09-23 after v1.12 closeout scope was added*
