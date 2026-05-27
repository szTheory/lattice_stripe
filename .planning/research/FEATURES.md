# Feature Research

**Domain:** Stripe Tax API — SDK resource coverage for Elixir adopters
**Researched:** 2026-05-27
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features Elixir adopters assume exist when integrating Stripe Tax. Missing these = incomplete Tax family.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| `Tax.Calculation.create/3` | Core standalone Tax flow starts here | MEDIUM | POST `/v1/tax/calculations`; nested `customer_details`, `line_items`, `shipping_cost` params |
| `Tax.Calculation.retrieve/3` | Re-fetch calculation before expiry | LOW | GET `/v1/tax/calculations/:id`; expires after 90 days |
| `Tax.Calculation.list_line_items/3` | Paginated line item access | LOW | GET `/v1/tax/calculations/:id/line_items` |
| `Tax.Transaction.create_from_calculation/3` | Record tax liability from calculation | MEDIUM | POST `/v1/tax/transactions/create_from_calculation`; requires unique `reference` |
| `Tax.Transaction.create_reversal/3` | Refund/correct recorded tax | MEDIUM | POST `/v1/tax/transactions/create_reversal` |
| `Tax.Transaction.retrieve/3` | Audit recorded transactions | LOW | GET `/v1/tax/transactions/:id` |
| `Tax.Transaction.list_line_items/3` | Paginated transaction line items | LOW | GET `/v1/tax/transactions/:id/line_items` |
| `Tax.Settings.retrieve/2` | Read account tax configuration | LOW | Singleton GET `/v1/tax/settings` |
| `Tax.Settings.update/3` | Configure defaults (tax_code, head office) | LOW | Singleton POST `/v1/tax/settings` |
| `Tax.Registration.create/3` | Enable tax collection in a jurisdiction | MEDIUM | POST `/v1/tax/registrations` with country-specific options |
| `Tax.Registration.retrieve/3` | Inspect registration status | LOW | GET `/v1/tax/registrations/:id` |
| `Tax.Registration.update/3` | Modify active registration | LOW | POST `/v1/tax/registrations/:id` |
| `Tax.Registration.list/3` | List all registrations | LOW | GET `/v1/tax/registrations` with pagination |
| `TaxId` CRUDL | B2B VAT/GST ID management | MEDIUM | Both `/v1/tax_ids` and `/v1/customers/:id/tax_ids` paths |
| Typed structs + `from_map/1` | Pattern-matchable returns | MEDIUM | Follow CreditNote/Mandate struct conventions |
| ObjectTypes registry entries | Expand deserialization + webhook dispatch | LOW | `"tax.calculation"`, `"tax.transaction"`, `"tax.settings"`, `"tax.registration"`, `"tax_id"` |

### Differentiators (Competitive Advantage)

Features that set LatticeStripe apart from minimal Stripe wrappers.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Calculation → Transaction integration spec | Proves the canonical standalone Tax flow end-to-end | MEDIUM | Chained Mox test: create calculation → create_from_calculation → retrieve |
| `LatticeStripe.Testing` Tax fixtures | Test helpers mirroring dispute/credit_note builders | LOW | `calculation/1`, `tax_transaction/1`, `tax_id/1` builders |
| Canonical `guides/tax.md` | Adopter recipe for standalone Tax API | MEDIUM | Calculate → record → reverse flow; scope boundary with Accrue |
| Moduledoc param examples | Elixir-idiomatic onboarding without reading Stripe docs | LOW | Realistic `customer_details` + `line_items` shapes in moduledocs |
| Bang variants | Consistent `!` raise-on-error surface | LOW | Auto-generated pattern from existing resources |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Tax filing/returns automation | "Complete tax compliance" | Multi-jurisdiction filing orchestration is Accrue scope | Document boundary; ship Calculation/Transaction primitives only |
| Tax rate lookup/caching layer | "Performance optimization" | Stripe owns rate data; caching creates stale-rate liability | Use Calculation API; let Stripe compute rates |
| AutomaticTax ↔ Tax.Calculation bridge | "Unify tax modules" | Different APIs — AutomaticTax is Invoice nested struct, not Tax API | Keep separate; cross-link in moduledocs only |
| Tax registration workflow wizard | "Help users register" | Dashboard/onboarding UX, not SDK | `Tax.Registration.create/3` primitive only |
| Custom tax engine fallback | "Calculate offline" | Out of SDK scope; violates Stripe-shaped contract | Use Calculation API or app-level logic outside SDK |

## Feature Dependencies

```
Tax.Settings (defaults)
    └──enhances──> Tax.Calculation (default tax_code)

Tax.Registration (jurisdiction)
    └──enhances──> Tax.Calculation (taxability_reason: standard_rated vs not_collecting)

Tax.Calculation
    └──requires──> Tax.Transaction.create_from_calculation (calculation ID)

Tax.Transaction
    └──optional──> Tax.Transaction.create_reversal (correct/refund)

TaxId
    └──enhances──> Tax.Calculation (customer_details.tax_ids, VAT validation)
```

### Dependency Notes

- **Calculation requires Transaction for recording:** The standalone Tax API flow is calculate → record. Both must ship in the same milestone for the family to be usable.
- **Settings/Registration enhance but don't block Calculation:** Can ship in a separate phase from Calculation/Transaction, but adopters need all five resource families for "Tax milestone complete."
- **TaxId is independent:** Can ship alongside or after Calculation; enhances B2B flows with VAT ID validation.

## MVP Definition

### Launch With (v1.6)

Minimum for "Tax family shipped":

- [ ] Tax.Calculation — create, retrieve, list_line_items
- [ ] Tax.Transaction — create_from_calculation, create_reversal, retrieve, list_line_items
- [ ] Tax.Settings — retrieve, update (singleton)
- [ ] Tax.Registration — create, retrieve, update, list
- [ ] TaxId — create, retrieve, list, delete (both path variants)
- [ ] ObjectTypes registry + typed structs for all five
- [ ] Integration spec for calculation → transaction chain
- [ ] Testing fixtures for Tax resources

### Add After Validation (v1.7+)

- [ ] `guides/tax.md` canonical recipe — if not in v1.6 scope, defer to v1.7 polish
- [ ] Docs-truth grep blocks for Tax moduledocs — can ride v1.7 VERIFY extension

### Future Consideration (v2+)

- [ ] Tax Code resource (`/v1/tax_codes`) — lookup helper, not core Tax flow
- [ ] Tax Transaction list endpoint — if Stripe adds it; currently retrieve-only for transactions
- [ ] Stripe Tax Reporting API — filing/returns, explicitly Accrue scope

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Tax.Calculation CRUDL | HIGH | MEDIUM | P1 |
| Tax.Transaction verbs | HIGH | MEDIUM | P1 |
| Tax.Settings singleton | HIGH | LOW | P1 |
| Tax.Registration CRUDL | HIGH | MEDIUM | P1 |
| TaxId dual-path CRUDL | HIGH | MEDIUM | P1 |
| ObjectTypes + typed structs | HIGH | LOW | P1 |
| Integration spec (calc→txn) | HIGH | MEDIUM | P1 |
| Testing fixtures | MEDIUM | LOW | P1 |
| guides/tax.md | MEDIUM | MEDIUM | P2 |
| Docs-truth grep extension | LOW | LOW | P2 |

## Competitor Feature Analysis

| Feature | stripity_stripe | stripe-go (official) | LatticeStripe Approach |
|---------|-----------------|---------------------|------------------------|
| Tax Calculation | Unknown/stale | Full | Handwritten with moduledoc examples |
| Tax Transaction | Unknown/stale | Full | Verb modules matching CreditNote pattern |
| Tax Settings | Unknown/stale | Singleton | First singleton resource in SDK |
| Tax Registration | Unknown/stale | CRUDL | Standard Resource pipeline |
| TaxId | Partial | Dual-path | Explicit dual-path in TaxId module |
| Testing helpers | None | N/A (Go) | LatticeStripe.Testing builders |

## Sources

- [Stripe Tax Calculations API](https://docs.stripe.com/api/tax/calculations)
- [Stripe Tax Transactions API](https://docs.stripe.com/api/tax/transactions)
- [Stripe Tax Settings API](https://docs.stripe.com/api/tax/settings)
- [Stripe Tax Registrations API](https://docs.stripe.com/api/tax/registrations)
- [Stripe Tax IDs API](https://docs.stripe.com/api/customer_tax_ids)
- [Standalone Tax API guide](https://docs.stripe.com/tax/standalone-tax-api)
- LatticeStripe v1.3-v1.5 shipped resource patterns

---
*Feature research for: LatticeStripe v1.6 Tax*
*Researched: 2026-05-27*
