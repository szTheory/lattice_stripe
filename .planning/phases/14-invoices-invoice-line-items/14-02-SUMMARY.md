---
phase: 14-invoices-invoice-line-items
plan: 02
subsystem: billing-resources
tags: [invoice, invoice-item, crud, struct, billing, atomization]
dependency_graph:
  requires:
    - LatticeStripe.Invoice.StatusTransitions (14-01)
    - LatticeStripe.Invoice.AutomaticTax (14-01)
    - LatticeStripe.Invoice.LineItem (14-01)
    - LatticeStripe.InvoiceItem.Period (14-01)
  provides:
    - LatticeStripe.Invoice
    - LatticeStripe.InvoiceItem
  affects:
    - lib/lattice_stripe/invoice.ex
    - lib/lattice_stripe/invoice_item.ex
tech_stack:
  added: []
  patterns:
    - 80+ known fields @known_fields with Map.split/2 extra catch-all (Invoice)
    - 25 known fields @known_fields with Map.split/2 extra catch-all (InvoiceItem)
    - Whitelist atomization (status/collection_method/billing_reason/customer_tax_exempt)
    - Embedded List parsing via parse_lines private helper
    - Custom Inspect impl hiding extra when empty
    - Full CRUD with bang variants following Customer template
key_files:
  created:
    - lib/lattice_stripe/invoice.ex
    - lib/lattice_stripe/invoice_item.ex
    - test/lattice_stripe/invoice_test.exs
    - test/lattice_stripe/invoice_item_test.exs
  modified: []
decisions:
  - "discount and discounts fields kept as raw map/list — Discount module does not exist in this codebase yet; keeping raw avoids a premature architectural commitment"
  - "parse_lines uses Map.update! on List.from_json result to apply LineItem.from_map to embedded list data without requiring a separate from_json override"
  - "InvoiceItem.from_map atomizes no fields — Stripe InvoiceItem has no enum fields that merit whitelist atomization"
metrics:
  duration: ~4min
  completed: 2026-04-12
  tasks_completed: 2
  files_created: 4
  files_modified: 0
---

# Phase 14 Plan 02: Invoice and InvoiceItem Resource Modules Summary

Invoice and InvoiceItem resource modules shipped: full CRUD operations, struct definitions with 80+ and 25+ known fields respectively, `from_map/1` with typed nested struct parsing, whitelist enum atomization, and embedded lines List parsing.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create LatticeStripe.Invoice module | 651d821 | lib/lattice_stripe/invoice.ex, test/lattice_stripe/invoice_test.exs |
| 2 | Create LatticeStripe.InvoiceItem module | 20936f5 | lib/lattice_stripe/invoice_item.ex, test/lattice_stripe/invoice_item_test.exs |

## What Was Built

### Task 1 — LatticeStripe.Invoice

**`lib/lattice_stripe/invoice.ex`**

- 80+ known fields with `object: "invoice"` and `extra: %{}` catch-all via `Map.split/2`
- Credo `StructFieldAmount` warning suppressed inline (>15 fields)
- `from_map/1` with nil guard clause
- 4-field whitelist atomization per D-14g:
  - `status`: `:draft | :open | :paid | :void | :uncollectible`
  - `collection_method`: `:charge_automatically | :send_invoice`
  - `billing_reason`: `:subscription_cycle | :subscription_create | :subscription_update | :subscription_threshold | :subscription | :manual | :upcoming`
  - `customer_tax_exempt`: `:none | :exempt | :reverse`
  - All unknown values pass through as strings (atom table safety)
- Typed nested structs via delegation:
  - `StatusTransitions.from_map(map["status_transitions"])`
  - `AutomaticTax.from_map(map["automatic_tax"])`
  - `discount` / `discounts` kept as raw map/list (Discount module not yet implemented)
- Embedded lines parsing: `parse_lines/1` private helper calls `List.from_json` then applies `LineItem.from_map` via `Map.update!(:data, ...)`
- Full CRUD: `create/3`, `retrieve/3`, `update/4`, `delete/3`, `list/3`, `stream!/3` with bang variants
- ASCII lifecycle diagram in `@moduledoc`:
  ```
  draft --> (finalize) --> open --> (pay) --> paid
                             |
                           (void) --> void
                             |
                     (mark_uncollectible) --> uncollectible
  ```
- Custom `Inspect` impl: shows `id`, `object`, `status`, `amount_due`, `currency`, `livemode`; shows `extra` only when non-empty

### Task 2 — LatticeStripe.InvoiceItem

**`lib/lattice_stripe/invoice_item.ex`**

- 25 known fields with `object: "invoiceitem"` and `extra: %{}` catch-all via `Map.split/2`
- `from_map/1` with nil guard clause
- Nested struct parsing: `Period.from_map(known["period"])`
- No enum atomization (InvoiceItem has no whitelist-worthy enum fields)
- Full CRUD at `/v1/invoiceitems` (not `/v1/invoice_items`): `create/3`, `retrieve/3`, `update/4`, `delete/3`, `list/3`, `stream!/3` with bang variants
- `@moduledoc` contains:
  - InvoiceItem vs Invoice Line Item disambiguation (D-14e)
  - D-05 no-search callout: no `/v1/invoiceitems/search` endpoint
  - Draft constraint notes on create/update/delete `@doc` strings
- Custom `Inspect` impl: shows `id`, `object`, `amount`, `currency`, `description`, `livemode`; shows `extra` only when non-empty

## Test Coverage

| Test File | Tests | Result |
|-----------|-------|--------|
| invoice_test.exs | 41 | PASS |
| invoice_item_test.exs | 20 | PASS |
| **Full suite** | **684** | **0 failures** |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing functionality] discount/discounts kept as raw map — Discount module absent**
- **Found during:** Task 1 implementation
- **Issue:** Plan interfaces section referenced `LatticeStripe.Discount.from_map/1` but no Discount module exists in the codebase (`lib/lattice_stripe/discount.ex` not found)
- **Fix:** Kept `discount` as raw `map() | nil` and `discounts` as raw `list() | nil` in the struct and `from_map/1`. This matches how other non-existent nested types are handled throughout the project (same approach used for `plan`, `price`, `shipping_details`, etc.)
- **Architectural note:** Creating a Discount module would be Rule 4 (new module = architectural change). Keeping raw map is the minimal, correct approach for a module that doesn't yet exist.
- **Files modified:** lib/lattice_stripe/invoice.ex (no separate deviation commit needed — handled inline)

## Known Stubs

None — all modules are fully implemented with real data flow. `discount`/`discounts` fields are intentionally raw maps because no Discount module exists yet; this is correct behavior, not a stub.

## Threat Surface Scan

T-14-04 (Tampering — whitelist atomization) is addressed: all 4 atomized fields use private `defp atomize_*/1` helpers with explicit whitelists and String.t() catch-all clauses. Unknown values never create atoms.

No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries introduced beyond what was planned.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| lib/lattice_stripe/invoice.ex | FOUND |
| lib/lattice_stripe/invoice_item.ex | FOUND |
| test/lattice_stripe/invoice_test.exs | FOUND |
| test/lattice_stripe/invoice_item_test.exs | FOUND |
| Commit 651d821 (Task 1) | FOUND |
| Commit 20936f5 (Task 2) | FOUND |
| 684 tests, 0 failures | VERIFIED |
