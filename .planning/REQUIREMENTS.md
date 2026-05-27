# Requirements: LatticeStripe

**Defined:** 2026-05-27
**Milestone:** v1.8 Adopter Truth & Doc Routing Polish
**Core Value:** Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.

## v1.8 Requirements

Requirements for this milestone. Each maps to roadmap phases 56–58.

### Release Truth

- [x] **TRUTH-01**: Adopter reading `guides/getting-started.md` sees release-status prose that matches Hex 1.7.0 as the current published surface (no stale `1.3.x` claim).
- [x] **TRUTH-02**: `docs_truth_test.exs` grep-regresses release-status prose in getting-started (not only the `~> 1.7` install pin).

### Canonical Guide Correctness

- [x] **GUIDE-01**: Adopter copying PaymentIntent `confirm/3` status handling from `guides/payments.md` matches on atom statuses (`:succeeded`, `:requires_action`, etc.).
- [x] **GUIDE-02**: Adopter copying `PaymentIntent.stream!/2` filter examples uses atom status (`:succeeded`).
- [x] **GUIDE-03**: Adopter copying `PaymentIntent.search/3` examples uses the correct arity (`search(client, query_string, opts \\ [])`).

### Doc Routing

- [x] **ROUTE-01**: Adopter following `guides/payments.md` discovers Charge list/search/update/capture for reconciliation workflows (PI-first narrative preserved).
- [x] **ROUTE-02**: Adopter following operator guides (`production-checklist.md`, `event-debugging.md`) finds Charge update/capture guidance alongside list/search.
- [x] **ROUTE-03**: `.planning/JTBD-MAP.md` charge-reconciliation route reflects post-v1.8 doc routing (no false "payments guide gap" after fixes land).

### Verification

- [x] **VERIFY-04**: `docs_truth_test.exs` grep-regresses canonical guide API example patterns in `guides/payments.md` (status atoms, search arity).

### Planning Truth

- [ ] **PLAN-01**: `.planning/MILESTONES.md` v1.7 section prose reflects published 1.7.0 state (no pre-publish wording).
- [ ] **PLAN-02**: `.planning/RETROSPECTIVE.md` historical bullets accurate post-1.7.0 Hex publish.

### Proof Hygiene (optional)

- [x] **PROOF-01**: Untracked tax proof files (`test/integration/tax_id_integration_test.exs`, `test/lattice_stripe/tax/adoption_contract_test.exs`) are committed on branch or explicitly dropped with rationale.

## Future Requirements

Deferred beyond v1.8. Tracked but not in current roadmap.

### CI Honesty

- **CI-01**: Guide-only PRs run `docs_truth_test.exs` (narrow `.github/workflows/ci.yml` paths-ignore) — awaiting explicit approval per STATE.md.

### Tax Narrow

- **TAX-01**: `TaxCode` resource surface — adopter pull only.
- **TAX-02**: `Tax.Transaction` list endpoint — adopter pull only.

### Specialist Stripe Families

- Identity, Treasury, Issuing, Terminal, Financial Connections, Climate, Sigma, Reporting — only with documented adopter pull (likely v2.0).

## Out of Scope

| Feature | Reason |
|---------|--------|
| New Stripe resource modules | v1.x stop signal; maintenance mode after v1.8 |
| New flagship recipes | Diminishing returns; doc-routing polish only |
| CI paths-ignore change | Requires explicit workflow approval; tracked as CI-01 future |
| Hex version bump to 1.8.0 | Doc-only milestone unless release policy changes |
| Charge API code changes | Surface shipped in v1.7; this milestone is docs/routing only |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TRUTH-01 | Phase 56 | Complete |
| TRUTH-02 | Phase 56 | Complete |
| GUIDE-01 | Phase 57 | Complete |
| GUIDE-02 | Phase 57 | Complete |
| GUIDE-03 | Phase 57 | Complete |
| ROUTE-01 | Phase 57 | Complete |
| ROUTE-02 | Phase 57 | Complete |
| VERIFY-04 | Phase 57 | Complete |
| ROUTE-03 | Phase 58 | Complete |
| PLAN-01 | Phase 58 | Pending |
| PLAN-02 | Phase 58 | Pending |
| PROOF-01 | Phase 58 | Complete |

**Coverage:**

- v1.8 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-27*
*Last updated: 2026-05-27 after milestone v1.8 roadmap creation*
