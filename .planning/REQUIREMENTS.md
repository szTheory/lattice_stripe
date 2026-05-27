# Requirements: LatticeStripe

**Defined:** 2026-05-27
**Milestone:** Maintenance mode (v1.9 shipped 2026-05-27)
**Core Value:** Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.

## v1.9 Requirements (shipped)

All required v1.9 requirements complete. Archive: [milestones/v1.9-REQUIREMENTS.md](milestones/v1.9-REQUIREMENTS.md).

### Checkout Guide Truth

- [x] **CHECKOUT-01**: Adopter copying Checkout Session `stream!/2` filter examples uses atom `payment_status` (`:paid`, not wire string `"paid"`).
- [x] **CHECKOUT-02**: `guides/checkout.md` includes a status-values callout explaining atomized `payment_status` on `%Session{}`.
- [x] **CHECKOUT-03**: `docs_truth_test.exs` grep-regresses canonical guide API example patterns in `guides/checkout.md`.

### README Truth

- [x] **README-01**: README error taxonomy lists `:authentication_error` and `:api_error`.
- [x] **README-02**: `docs_truth_test.exs` grep-regresses README error atom list.

### CI Honesty

- [x] **CI-01**: Guide-only and markdown-only PRs run `docs_truth_test.exs` — paths-ignore narrowed to `.planning/**` only.

### Verification Extension

- [x] **VERIFY-05**: `docs_truth_test.exs` includes `guides/checkout.md` content locks.

### Planning Truth

- [x] **JTBD-01**: `.planning/JTBD-MAP.md` hosted checkout narrative coverage Strong with Phase 59 evidence.
- [ ] **PLAN-01** (optional, deferred): Backfill `54-VERIFICATION.md` — third carry; not blocking maintenance.

## Future Requirements (deferred)

- **TAX-01/TAX-02**: TaxCode surface, Tax.Transaction list — adopter pull only
- Specialist Stripe families — v2.0 or adopter pull
- Gap 2 narrative docs — diminishing returns

## Traceability (v1.9)

| Requirement | Phase | Status |
|-------------|-------|--------|
| CHECKOUT-01..03 | 59 | Complete |
| README-01..02 | 59 | Complete |
| VERIFY-05 | 59 | Complete |
| CI-01 | 60 | Complete |
| JTBD-01 | 60 | Complete |
| PLAN-01 | 60 | Deferred (third carry) |

---
*Requirements defined: 2026-05-27*
*Last updated: 2026-05-27 after v1.9 milestone close*
