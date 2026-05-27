# Architecture Research

**Domain:** Stripe Tax resource family integration into LatticeStripe SDK
**Researched:** 2026-05-27
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Adopter Application                       │
│  (Accrue, Phoenix checkout, custom payment flow)            │
├─────────────────────────────────────────────────────────────┤
│  LatticeStripe.Tax.Calculation ──► Tax.Transaction          │
│  LatticeStripe.Tax.Settings    ──► Tax.Registration         │
│  LatticeStripe.TaxId           ──► Customer (optional link) │
├─────────────────────────────────────────────────────────────┤
│                    Request Pipeline                          │
│  Client → Request → Transport (Finch) → Response → Struct   │
├─────────────────────────────────────────────────────────────┤
│                    Stripe Tax API                            │
│  /v1/tax/calculations  /v1/tax/transactions                 │
│  /v1/tax/settings      /v1/tax/registrations                │
│  /v1/tax_ids           /v1/customers/:id/tax_ids            │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `LatticeStripe.Tax.Calculation` | Ephemeral tax estimation | create/retrieve/list_line_items; nested LineItem struct |
| `LatticeStripe.Tax.Transaction` | Persistent tax recording | Verb fns: create_from_calculation, create_reversal; retrieve/list_line_items |
| `LatticeStripe.Tax.Settings` | Account-level tax config | Singleton retrieve/update |
| `LatticeStripe.Tax.Registration` | Jurisdiction registration | Standard CRUDL |
| `LatticeStripe.TaxId` | Customer/account tax IDs | Dual-path routing (top-level vs customer-nested) |
| `LatticeStripe.ObjectTypes` | Expand + webhook dispatch | 5 new registry entries |
| `LatticeStripe.Testing.Fixtures.Tax*` | Test builders | calculation/1, transaction/1, tax_id/1 |

## Recommended Project Structure

```
lib/lattice_stripe/
├── tax/
│   ├── calculation.ex          # Tax.Calculation resource
│   ├── calculation/
│   │   └── line_item.ex        # nested line item struct
│   ├── transaction.ex          # Tax.Transaction resource
│   ├── transaction/
│   │   └── line_item.ex        # nested line item struct
│   ├── settings.ex               # Tax.Settings singleton
│   └── registration.ex           # Tax.Registration CRUDL
├── tax_id.ex                     # TaxId (top-level module, like CreditNote)
└── object_types.ex               # +5 entries

lib/lattice_stripe/testing/fixtures/
├── tax_calculation.ex
├── tax_transaction.ex
└── tax_id.ex

test/lattice_stripe/tax/
├── calculation_test.exs
├── transaction_test.exs
├── settings_test.exs
├── registration_test.exs
└── tax_id_test.exs

guides/
└── tax.md                        # optional canonical recipe
```

### Structure Rationale

- **`tax/` namespace:** Matches `billing/` namespace for Billing.Meter — Stripe groups these under `tax.*` object types
- **`tax_id.ex` at top level:** Stripe object type is `tax_id` (not `tax.tax_id`); mirrors how `CreditNote` is top-level despite nested line items
- **Separate line_item modules:** Calculation and Transaction both have paginated line_items endpoints with distinct struct shapes
- **Fixtures co-located:** Follows v1.3 pattern (CreditNote, Dispute, Mandate fixtures)

## Architectural Patterns

### Pattern 1: Standard Resource CRUDL

**What:** create/retrieve/list/update/delete via Resource pipeline
**When to use:** Registration, TaxId
**Trade-offs:** Proven pattern; minimal surprise

**Example:** Follow `LatticeStripe.CreditNote` — `@known_fields`, `defstruct`, `from_map/1`, `Client.request/2` wrapper.

### Pattern 2: Verb Functions (Non-CRUD Paths)

**What:** Explicit function names for non-standard Stripe endpoints
**When to use:** Transaction (`create_from_calculation`, `create_reversal`), Calculation (`list_line_items`)
**Trade-offs:** More discoverable than generic `action/4`; matches Dispute.close, CreditNote.preview precedent

**Example:**
```elixir
def create_from_calculation(client, params, opts \\ [])
def create_reversal(client, params, opts \\ [])
```

### Pattern 3: Singleton Resource

**What:** retrieve/update without resource ID in path
**When to use:** Tax.Settings (`GET/POST /v1/tax/settings`)
**Trade-offs:** First singleton in codebase — set precedent carefully

**Example:**
```elixir
def retrieve(client, opts \\ [])  # GET /v1/tax/settings
def update(client, params, opts \\ [])  # POST /v1/tax/settings
```

### Pattern 4: Dual-Path Resource

**What:** Same module, different URL paths based on optional parent ID
**When to use:** TaxId (top-level vs customer-nested)
**Trade-offs:** Slightly more complex path construction; avoids duplicating two modules

**Example:**
```elixir
# Top-level: POST /v1/tax_ids
TaxId.create(client, params, opts)

# Customer-nested: POST /v1/customers/:customer_id/tax_ids
TaxId.create(client, customer_id, params, opts)
```

## Data Flow

### Canonical Standalone Tax Flow

```
Adopter calls Tax.Calculation.create/3
    ↓
POST /v1/tax/calculations → %Tax.Calculation{}
    ↓
Adopter calls Tax.Transaction.create_from_calculation/3
    ↓
POST /v1/tax/transactions/create_from_calculation → %Tax.Transaction{}
    ↓
(Optional) Tax.Transaction.create_reversal/3 for refunds
    ↓
POST /v1/tax/transactions/create_reversal → %Tax.Transaction{}
```

### Configuration Flow

```
Tax.Settings.retrieve/2 → read defaults (tax_code, head_office)
Tax.Registration.create/3 → enable jurisdiction
TaxId.create/3 → attach VAT ID to customer
    ↓
These enhance Calculation accuracy but aren't required for basic flow
```

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Single-tenant SaaS | No changes — direct API calls per checkout |
| High-volume checkout | Calculation API calls are per-transaction; no SDK-side caching needed |
| Multi-jurisdiction | Registration list grows; pagination via existing List module |

### Scaling Priorities

1. **First bottleneck:** Calculation API rate (10 free calls per transaction, 4¢ above) — document in guide, not SDK concern
2. **Second bottleneck:** 90-day calculation expiry — document; adopters must create transactions promptly

## Anti-Patterns

### Anti-Pattern 1: Conflating AutomaticTax with Tax API

**What people do:** Extend `Invoice.AutomaticTax` to cover standalone Tax
**Why it's wrong:** Different API surfaces, different object types, different use cases
**Do this instead:** New `Tax.*` namespace; cross-reference in moduledocs

### Anti-Pattern 2: Generic Action Dispatch for Tax Verbs

**What people do:** `Tax.Transaction.action(client, "create_from_calculation", params)`
**Why it's wrong:** Breaks LatticeStripe explicit-verb convention; worse discoverability
**Do this instead:** Named functions `create_from_calculation/3`, `create_reversal/3`

### Anti-Pattern 3: Filing Orchestration in SDK

**What people do:** Add helpers that chain registration → calculation → filing
**Why it's wrong:** Scope bleed into Accrue; SDK should expose primitives
**Do this instead:** Document flow in guide; keep modules independent

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Stripe Tax Calculations | POST/GET `/v1/tax/calculations` | Calculations expire after 90 days |
| Stripe Tax Transactions | Verb POST paths | `reference` must be globally unique |
| Stripe Tax Settings | Singleton GET/POST | No list/delete |
| Stripe Tax Registrations | Standard CRUDL | Country-specific `country_options` nesting |
| Stripe Tax IDs | Dual-path CRUDL | Customer events: `customer.tax_id.*` |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Tax.* ↔ ObjectTypes | Registry lookup for expand | Add 5 entries at implementation time |
| Tax.* ↔ Testing.Fixtures | Builder functions | Mirror dispute/credit_note fixture pattern |
| Tax.* ↔ Invoice.AutomaticTax | None (moduledoc cross-ref only) | Different APIs — no code coupling |
| Tax.* ↔ Customer | TaxId nested paths only | Customer module doesn't need TaxId delegation |

## Sources

- Existing codebase: `lib/lattice_stripe/credit_note.ex`, `lib/lattice_stripe/billing/meter.ex`, `lib/lattice_stripe/dispute.ex`
- [Stripe Standalone Tax API guide](https://docs.stripe.com/tax/standalone-tax-api)
- [Stripe Tax API Reference](https://docs.stripe.com/api/tax)

---
*Architecture research for: LatticeStripe v1.6 Tax*
*Researched: 2026-05-27*
