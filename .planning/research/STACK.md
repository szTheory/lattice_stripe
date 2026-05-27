# Stack Research

**Domain:** Stripe Tax API SDK surface (Elixir)
**Researched:** 2026-05-27
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Elixir | >= 1.15 | Runtime | Project constraint; existing codebase standard |
| Finch | ~> 0.21 | HTTP transport | Already the default transport; Tax endpoints use same `/v1/tax/*` REST surface |
| Jason | ~> 1.4 | JSON codec | Existing wire-format encoding/decoding for nested Tax params |
| :telemetry | ~> 1.0 | Instrumentation | Tax calls emit through existing request pipeline events |
| Existing `LatticeStripe.Request` / `Resource` / `Client` | (shipped) | Request pipeline | Tax resources follow identical CRUDL + verb patterns as CreditNote, Mandate, Billing.Meter |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| NimbleOptions | ~> 1.0 (optional) | Per-request opts validation | Only if new Tax-specific client options emerge; not required for resource modules |
| Mox | ~> 1.2 (dev) | Transport mocking | Unit/integration tests for Tax calculation → transaction chain |
| stripe-mock (Docker) | latest (CI) | Integration test server | Tax endpoints may have partial coverage; Mox-at-Transport remains primary proof path |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| ExUnit | Test framework | Chained integration specs matching v1.5 thin-event pattern |
| ExDoc | Documentation | Tax moduledocs + optional `guides/tax.md` recipe |
| Credo | Linting | No new deps |

## Installation

No new Hex dependencies required for v1.6 Tax. The milestone adds modules under `lib/lattice_stripe/tax/` and extends `ObjectTypes` registry entries.

```elixir
# mix.exs — no changes expected beyond version bump at release time
# Existing deps cover all Tax API transport needs
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Reuse existing Resource/Request pipeline | New Tax-specific HTTP client | Never — would break SDK consistency |
| `LatticeStripe.Tax.*` namespace | Flat top-level modules (`LatticeStripe.TaxCalculation`) | Never — Billing.Meter precedent favors nested namespace for Stripe object families |
| Mox-at-Transport integration tests | stripe-mock-only Tax tests | stripe-mock Tax coverage is incomplete; Mox proves request shapes and response deserialization |
| Customer-nested + top-level TaxId paths | Top-level only | Only if discuss-phase decides Customer nesting is out of scope — Stripe exposes both |

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Tax filing/returns orchestration | Accrue scope; multi-jurisdiction filing strategy is downstream | SDK primitives: Calculation, Transaction, Settings, Registration |
| New JSON codec | Unnecessary dep | Jason via existing pipeline |
| Tax-specific Finch pool | Over-engineering | Existing client `:finch` option |
| Codegen from OpenAPI | Project uses handwritten surfaces | Handwritten modules matching CreditNote/Mandate patterns |
| AutomaticTax builder abstraction | Invoice.AutomaticTax is a nested struct only; don't conflate with Tax API family | Separate `Tax.Calculation` module for standalone Tax API |

## Stack Patterns by Variant

**If implementing Tax Calculation:**
- Use `POST /v1/tax/calculations` with string-key params (Stripe wire format)
- Support `expand` for line_items inline
- Calculations expire after 90 days — document in moduledoc, don't add expiry logic

**If implementing Tax Transaction:**
- Verbs use non-standard paths: `create_from_calculation`, `create_reversal` (like CreditNote `preview`, Dispute `close`)
- `reference` param must be unique across all transactions — document in moduledoc

**If implementing Tax Settings:**
- Singleton resource: `GET/POST /v1/tax/settings` (no ID in path)
- Follow Configuration singleton pattern if one exists, otherwise first singleton in codebase

**If implementing TaxId:**
- Dual path surface: `/v1/tax_ids` and `/v1/customers/:id/tax_ids`
- Recommend `LatticeStripe.TaxId` with optional `customer_id` param routing paths

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| LatticeStripe 1.3.x+ | Stripe API 2024-11-20.acacia+ | Tax endpoints stable under `/v1/tax/*`; pin matches existing client default |
| Tax Calculations | Tax Transactions | Calculation ID required for `create_from_calculation`; 90-day expiry window |
| Tax Settings | Tax Calculations | Default tax_code in settings affects calculations without explicit tax_code |

## Sources

- [Stripe Tax Calculations API](https://docs.stripe.com/api/tax/calculations) — create, retrieve, line_items list
- [Stripe Tax Transactions API](https://docs.stripe.com/api/tax/transactions) — create_from_calculation, create_reversal, retrieve, line_items
- [Stripe Tax Settings API](https://docs.stripe.com/api/tax/settings) — singleton retrieve/update
- [Stripe Tax Registrations API](https://docs.stripe.com/api/tax/registrations) — CRUDL
- [Stripe Tax IDs API](https://docs.stripe.com/api/customer_tax_ids) — customer-nested and top-level paths
- [Standalone Tax API guide](https://docs.stripe.com/tax/standalone-tax-api) — calculate → record flow
- Existing codebase: `lib/lattice_stripe/credit_note.ex`, `lib/lattice_stripe/billing/meter.ex`, `lib/lattice_stripe/object_types.ex`

---
*Stack research for: LatticeStripe v1.6 Tax*
*Researched: 2026-05-27*
