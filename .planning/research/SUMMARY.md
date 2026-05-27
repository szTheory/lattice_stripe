# Project Research Summary

**Project:** LatticeStripe
**Domain:** Stripe Tax API SDK surface (Elixir)
**Researched:** 2026-05-27
**Confidence:** HIGH

## Executive Summary

LatticeStripe v1.6 Tax adds the broadest remaining mainstream Stripe resource family using zero new dependencies. All five target resources — Calculation, Transaction, Settings, Registration, and TaxId — map cleanly to existing SDK patterns: Resource/Request pipeline, explicit verb functions for non-CRUD paths, and the `billing/` namespace precedent for `tax/` grouping.

The canonical adopter flow is calculate → record → (optional) reverse. Calculation is ephemeral (90-day expiry); Transaction is persistent. Settings and Registration configure the account; TaxId enables B2B VAT validation. The primary risk is scope bleed into filing orchestration (Accrue territory) — mitigated by hard primitive-only boundary and discuss-phase negotiation.

Recommended phase structure: (1) Calculation + Transaction core flow with integration proof, (2) Settings + Registration configuration, (3) TaxId + Testing fixtures + docs. Three phases align with PROJECT.md's 2-3 phase estimate.

## Key Findings

### Recommended Stack

No new Hex dependencies. Tax resources reuse Finch + Jason + existing Request/Resource/Client pipeline. Namespace follows `LatticeStripe.Tax.*` (matching `Billing.Meter` precedent). TaxId is top-level `LatticeStripe.TaxId` (Stripe object type `tax_id`).

**Core technologies:**
- Existing Request/Resource pipeline — proven across 40+ resource modules
- Finch transport — same `/v1/tax/*` REST endpoints
- ObjectTypes registry — 5 new entries for expand deserialization

### Expected Features

**Must have (table stakes):**
- Tax.Calculation — create, retrieve, list_line_items
- Tax.Transaction — create_from_calculation, create_reversal, retrieve, list_line_items
- Tax.Settings — singleton retrieve/update
- Tax.Registration — create, retrieve, update, list
- TaxId — dual-path CRUDL (top-level + customer-nested)
- ObjectTypes entries + typed structs for all five
- Integration spec proving calc → txn chain
- Testing fixtures

**Should have (competitive):**
- Canonical `guides/tax.md` recipe
- Docs-truth grep extension for Tax moduledocs

**Defer (v1.7+):**
- Tax Code lookup resource
- Tax Reporting/filing API

### Architecture Approach

New `lib/lattice_stripe/tax/` directory with Calculation, Transaction, Settings, Registration modules. Top-level `tax_id.ex`. Verb functions for Transaction (`create_from_calculation`, `create_reversal`). Settings is the codebase's first singleton resource. TaxId uses arity-based dual-path routing.

**Major components:**
1. `Tax.Calculation` — ephemeral tax estimation with nested LineItem struct
2. `Tax.Transaction` — persistent tax recording with verb endpoints
3. `Tax.Settings` + `Tax.Registration` — account configuration
4. `TaxId` — B2B tax ID management with dual URL paths

### Critical Pitfalls

1. **Scope bleed into filing** — keep Calculation/Transaction primitives only; no returns automation
2. **Calculation 90-day expiry** — document in moduledoc; integration spec demonstrates prompt txn creation
3. **Transaction reference uniqueness** — global uniqueness required; document in moduledoc
4. **AutomaticTax conflation** — separate namespace from existing `Invoice.AutomaticTax`
5. **TaxId dual-path** — implement both `/v1/tax_ids` and `/v1/customers/:id/tax_ids`

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 49: Tax Calculation & Transaction Core
**Rationale:** Calculation → Transaction is the canonical standalone Tax flow; both required for the family to be usable. Integration spec proves the chain.
**Delivers:** Tax.Calculation, Tax.Transaction, nested LineItem structs, ObjectTypes entries, calc→txn integration spec
**Addresses:** All CALC-* and TXN-* requirements
**Avoids:** Pitfall 2 (expiry), Pitfall 3 (reference uniqueness), Pitfall 4 (AutomaticTax conflation)

### Phase 50: Tax Settings & Registration
**Rationale:** Configuration resources enhance Calculation accuracy but are independent of the core flow. Settings singleton sets codebase precedent.
**Delivers:** Tax.Settings (singleton), Tax.Registration (CRUDL), ObjectTypes entries
**Addresses:** CONF-* requirements
**Avoids:** Pitfall 7 (singleton path mistake)

### Phase 51: TaxId, Testing & Adoption Surface
**Rationale:** TaxId is independent but completes the five-resource family. Testing fixtures and optional guide close the adopter story.
**Delivers:** TaxId dual-path CRUDL, Testing fixtures, optional guides/tax.md, docs-truth extension
**Addresses:** TAXID-* and DX-* requirements
**Avoids:** Pitfall 5 (dual-path confusion), Pitfall 6 (ObjectTypes gap)

### Phase Ordering Rationale

- Calculation + Transaction first because Transaction depends on Calculation ID
- Settings + Registration second because they configure but don't block the core flow
- TaxId last because it's independent and completes the family
- Testing/guide in final phase follows v1.5 pattern (code first, adoption surface second)

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 49:** Tax Calculation nested param shapes (`customer_details`, `line_items`, `shipping_cost`) — verify against Stripe docs during plan-phase
- **Phase 50:** Tax.Settings singleton — first in codebase; confirm path pattern during discuss-phase
- **Phase 51:** TaxId dual-path arity design — discuss-phase decision on Customer-nested vs unified module

Phases with standard patterns (lighter research):
- **Phase 50:** Tax.Registration — standard CRUDL, follows CreditNote pattern

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Zero new deps; proven pipeline |
| Features | HIGH | Stripe docs verified for all 5 resource families |
| Architecture | HIGH | Clear precedent in Billing.Meter, CreditNote, Dispute verbs |
| Pitfalls | HIGH | Scope boundary well-established in PROJECT.md |

**Overall confidence:** HIGH

### Gaps to Address

- **TaxId module design:** Dual-path vs separate modules — resolve in Phase 51 discuss-phase
- **guides/tax.md scope:** Include in v1.6 or defer to v1.7 — user scoping decision during requirements
- **stripe-mock Tax coverage:** May be partial; Mox-at-Transport remains primary proof path

## Sources

### Primary (HIGH confidence)
- [Stripe Tax Calculations API](https://docs.stripe.com/api/tax/calculations)
- [Stripe Tax Transactions API](https://docs.stripe.com/api/tax/transactions)
- [Stripe Tax Settings API](https://docs.stripe.com/api/tax/settings)
- [Stripe Tax Registrations API](https://docs.stripe.com/api/tax/registrations)
- [Stripe Tax IDs API](https://docs.stripe.com/api/customer_tax_ids)
- [Standalone Tax API guide](https://docs.stripe.com/tax/standalone-tax-api)

### Secondary (MEDIUM confidence)
- stripity_stripe Tax coverage — assumed stale/incomplete based on project history

---
*Research completed: 2026-05-27*
*Ready for roadmap: yes*
