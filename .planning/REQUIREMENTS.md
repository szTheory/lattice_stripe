# Requirements: LatticeStripe

**Defined:** 2026-05-27
**Milestone:** v1.9 CI & Doc Honesty
**Core Value:** Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.

## v1.9 Requirements

Requirements for this milestone. Each maps to roadmap phases 59–60.

### Checkout Guide Truth

- [ ] **CHECKOUT-01**: Adopter copying Checkout Session `stream!/2` filter examples uses atom `payment_status` (`:paid`, not wire string `"paid"`).
- [ ] **CHECKOUT-02**: `guides/checkout.md` includes a status-values callout explaining atomized `payment_status` on `%Session{}` (mirror `guides/payments.md` PaymentIntent pattern).
- [ ] **CHECKOUT-03**: `docs_truth_test.exs` grep-regresses canonical guide API example patterns in `guides/checkout.md` (atom status filters, stale string patterns).

### README Truth

- [ ] **README-01**: README error taxonomy lists `:authentication_error` and `:api_error` (matching `LatticeStripe.Error` atoms), not stale `:auth_error`/`:server_error`.
- [ ] **README-02**: `docs_truth_test.exs` grep-regresses README error atom list (fail on stale taxonomy).

### CI Honesty

- [ ] **CI-01**: Guide-only and markdown-only PRs still run `docs_truth_test.exs` — narrow `.github/workflows/ci.yml` `paths-ignore` so docs_truth is not bypassed on highest-risk edit surface.

### Verification Extension

- [ ] **VERIFY-05**: `docs_truth_test.exs` canonical-guides coverage explicitly includes `guides/checkout.md` content locks (status atoms) alongside existing payments.md locks.

### Planning Truth

- [ ] **JTBD-01**: `.planning/JTBD-MAP.md` hosted checkout row reflects locked checkout examples (narrative coverage upgraded to Strong when CHECKOUT-01..03 ship).
- [ ] **PLAN-01** (optional): Backfill missing `54-VERIFICATION.md` from v1.7 Phase 54 with close-time evidence.

## Future Requirements (deferred)

Tracked from prior milestones — not in v1.9 roadmap:

- **TAX-01/TAX-02**: TaxCode surface, Tax.Transaction list — adopter pull only
- Specialist Stripe families (Identity, Treasury, Issuing, etc.) — v2.0 or adopter pull
- Gap 2 narrative docs (Product/Price, BillingPortal config, disputes deep playbooks) — diminishing returns

## Out of Scope

| Feature | Reason |
|---------|--------|
| New Stripe resource families | v1.x stop signal holds |
| Hex version bump | v1.9 is doc-only like v1.8 |
| New flagship recipes | Diminishing returns; checkout fix only |
| payments.md output comment polish | Lower priority; wire-string comments in `# Status:` lines are non-blocking |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CHECKOUT-01 | Phase 59 | Pending |
| CHECKOUT-02 | Phase 59 | Pending |
| CHECKOUT-03 | Phase 59 | Pending |
| README-01 | Phase 59 | Pending |
| README-02 | Phase 59 | Pending |
| VERIFY-05 | Phase 59 | Pending |
| CI-01 | Phase 60 | Pending |
| JTBD-01 | Phase 60 | Pending |
| PLAN-01 | Phase 60 | Pending (optional) |

**Coverage:**
- v1.9 requirements: 9 total (8 required + 1 optional)
- Mapped to phases: 9
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-27*
*Last updated: 2026-05-27 after v1.9 milestone scoping*
