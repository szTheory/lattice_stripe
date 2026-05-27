# Phase 49: Tax Calculation & Transaction Core — Research

**Researched:** 2026-05-27  
**Confidence:** HIGH (Stripe API docs verified; codebase patterns confirmed)

## RESEARCH COMPLETE

## Executive Summary

Phase 49 is greenfield under `lib/lattice_stripe/tax/`. No Tax modules exist yet. Implementation follows **CreditNote + Quote + Billing.Meter** precedents: explicit verb functions for non-CRUD paths, `Resource.unwrap_singular/list`, paginated `list_line_items/4`, bounded `@known_fields` + `extra`, and Mox-at-Transport chained integration (Phase 48 D-02).

## API Surface (Verified)

### Tax.Calculation

| Verb | Method | Path |
|------|--------|------|
| `create/3` | POST | `/v1/tax/calculations` |
| `retrieve/3` | GET | `/v1/tax/calculations/:id` |
| `list_line_items/4` | GET | `/v1/tax/calculations/:id/line_items` |

**Top-level `@known_fields`:** `id`, `object`, `amount_total`, `currency`, `customer`, `customer_details`, `expires_at`, `line_items`, `livemode`, `ship_from_details`, `shipping_cost`, `tax_amount_exclusive`, `tax_amount_inclusive`, `tax_breakdown`, `tax_date`

**Object:** `tax.calculation` — default `object: "tax.calculation"` in defstruct

**Operational:** `expires_at` timestamp — calculations expire after **90 days** (Stripe docs + create_from_calculation note).

### Tax.Transaction

| Verb | Method | Path |
|------|--------|------|
| `create_from_calculation/3` | POST | `/v1/tax/transactions/create_from_calculation` |
| `create_reversal/3` | POST | `/v1/tax/transactions/create_reversal` |
| `retrieve/3` | GET | `/v1/tax/transactions/:id` |
| `list_line_items/4` | GET | `/v1/tax/transactions/:id/line_items` |

**Required params — create_from_calculation:** `calculation` (string), `reference` (string, globally unique, max 500 chars). Optional: `metadata`, `posted_at`.

**Required params — create_reversal:** `mode` (`full` | `partial`), `original_transaction` (string), `reference` (string, globally unique). Partial mode requires `line_items` and/or `shipping_cost` and/or `flat_amount`.

**Top-level `@known_fields`:** `id`, `object`, `created`, `currency`, `customer`, `customer_details`, `line_items`, `livemode`, `metadata`, `posted_at`, `reference`, `reversal`, `shipping_cost`, `tax_date`, `type`

**Object:** `tax.transaction` — Transaction line items use `tax.transaction_line_item`; Calculation line items use `tax.calculation_line_item` — **separate modules** per CONTEXT D-01.

### Nested Param Shapes (Plan-Time Locked)

**`customer_details` (typed `Tax.CustomerDetails`):**
- Flat: `address_source`, `ip_address`, `taxability_override`
- `address` → **map** (no shared Address module; Checkout.Session precedent)
- `tax_ids` → **list of maps** (not sub-struct)

**`shipping_cost` (typed `Tax.ShippingCost`):** `amount`, `amount_tax`, `shipping_rate`, `tax_behavior`, `tax_code`; `tax_breakdown` on shipping → list of maps (volatile jurisdiction trees)

**`ship_from_details` (typed `Tax.ShipFromDetails`):** `address` → map

**`tax_breakdown` (top-level on Calculation/Transaction):** Shared module `Tax.TaxBreakdown` — fields `amount`, `inclusive`, `tax_rate_details` (map), `taxability_reason`, `taxable_amount`. Calculation and Transaction top-level arrays share this shape per Stripe API.

**Line items — Calculation.LineItem `@known_fields`:** `id`, `object`, `amount`, `amount_tax`, `livemode`, `metadata`, `performance_location`, `product`, `quantity`, `reference`, `tax_behavior`, `tax_breakdown`, `tax_code`

**Line items — Transaction.LineItem adds:** `reversal`, `type` (enum strings `transaction` / reversal variants — pass through)

**`product` on line items:** decode expanded maps via `ObjectTypes.maybe_deserialize/1` (Quote `parse_expandable` pattern).

**`tax_behavior`:** atomize `:exclusive` | `:inclusive`; pass through unknown strings.

**Request encoding:** Raw string-key maps only — `FormEncoder` handles nested arrays (`line_items[0][amount]=...`). No request builders.

## Codebase Patterns to Copy

| Pattern | Source | Apply to |
|---------|--------|----------|
| `create/3` POST + `Resource.unwrap_singular` | `CreditNote` | Calculation.create |
| `list_line_items/4` + `do_list_line_items` | `Quote`, `CreditNote` | Both Tax resources |
| Verb POST empty path suffix | `Billing.Meter.deactivate` | `create_from_calculation`, `create_reversal` |
| `parse_line_items` + `List.from_json` | `Quote` | embedded + list endpoints |
| Nested struct `from_map` | `CreditNote.LineItem` | Tax line items |
| Mox chained `expect/3` | `Webhook.ThinEventTest` | `calculation_transaction_test.exs` |
| Per-verb unit split | `credit_note_test.exs` | `calculation_test.exs`, `transaction_test.exs` |
| Fixture `Map.merge` | `test/support/fixtures/credit_note.ex` | `tax_calculation.ex`, `tax_transaction.ex` |

## ObjectTypes (D-04)

```elixir
"tax.calculation" => LatticeStripe.Tax.Calculation,
"tax.transaction" => LatticeStripe.Tax.Transaction,
```

Add two dispatch tests in `object_types_test.exs`. No expand integration test in Phase 49 (DX-01 is Phase 51).

## Moduledoc Grep Targets (DX-03 prep, full grep Phase 51)

| Module | Required substrings |
|--------|---------------------|
| `Tax.Calculation` | `90`, day/expiry language, `Invoice.AutomaticTax` |
| `Tax.Transaction` | `reference`, unique/globally, `Invoice.AutomaticTax` |

## Integration Test Contract (D-02)

**File:** `test/lattice_stripe/tax/calculation_transaction_test.exs`  
**Tags:** `async: true`, `setup :verify_on_exit!`, **no** `@moduletag :integration`

**Test name:** `"canonical standalone tax flow"`

**Four expects (ordered):**
1. POST `/v1/tax/calculations` → fixture with dynamic `id`
2. POST `/v1/tax/transactions/create_from_calculation` → body contains calc `id` + `"order_#{System.unique_integer([:positive])}"` reference
3. GET `/v1/tax/transactions/:id` → txn fixture
4. POST `/v1/tax/transactions/create_reversal` → `mode=full`, `original_transaction`, unique reversal reference

## Anti-Patterns (Do NOT)

- Extend `Invoice.AutomaticTax` — cross-reference only (Pitfall #4)
- Hardcode `taxcalc_*` / `tax_*` IDs in integration test (Pitfall #2, #3)
- Unify Calculation/Transaction LineItem modules (distinct Stripe object types)
- Add `@moduletag :integration` to Mox chain test (Phase 48 D-02)
- Defer ObjectTypes to Phase 51 (Pitfall #6, CONTEXT D-04)

## Validation Architecture

Nyquist validation applies. Automated verification uses ExUnit + Mox:

| Layer | Command | When |
|-------|---------|------|
| Quick (per task) | `mix test test/lattice_stripe/tax/calculation_test.exs --no-start` (or transaction path) | After Calculation/Transaction module tasks |
| Quick (object types) | `mix test test/lattice_stripe/object_types_test.exs --no-start` | After ObjectTypes registration |
| Full tax suite | `mix test test/lattice_stripe/tax/ --no-start` | After wave 2 / before verify-work |
| Compile gate | `mix compile --warnings-as-errors` | Every plan |

**Estimated runtime:** ~15–30s for full `test/lattice_stripe/tax/` on typical dev hardware.

**Manual-only:** None — Mox covers calc→txn→reversal chain; stripe-mock optional smoke deferred.

## Plan Split Recommendation

| Plan | Wave | Delivers |
|------|------|----------|
| 49-01 | 1 | Shared nested modules + Tax.Calculation + fixtures + `tax.calculation` ObjectTypes + unit tests |
| 49-02 | 2 | Tax.Transaction + moduledocs (both) + `tax.transaction` ObjectTypes + unit tests |
| 49-03 | 2 | Chained integration spec (DX-03) |

## Sources

- [Tax Calculation object](https://docs.stripe.com/api/tax/calculations/object)
- [Create transaction from calculation](https://docs.stripe.com/api/tax/transactions/create_from_calculation)
- [Create reversal](https://docs.stripe.com/api/tax/transactions/create_reversal)
- [Standalone Tax API](https://docs.stripe.com/tax/standalone-tax-api)
- `.planning/phases/49-tax-calculation-transaction-core/49-CONTEXT.md` (locked decisions D-01–D-04)
