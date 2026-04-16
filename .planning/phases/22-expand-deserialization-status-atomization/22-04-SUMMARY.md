---
phase: 22-expand-deserialization-status-atomization
plan: "04"
subsystem: expand-deserialization
tags: [expand, deserialization, typespecs, changelog, EXPD-01, EXPD-02, EXPD-04]
dependency_graph:
  requires: [22-02, 22-03]
  provides: [EXPD-01-complete, EXPD-02-verified, EXPD-04-changelog]
  affects:
    - lib/lattice_stripe/invoice.ex
    - lib/lattice_stripe/invoice_item.ex
    - lib/lattice_stripe/subscription_item.ex
    - lib/lattice_stripe/card.ex
    - lib/lattice_stripe/payment_method.ex
    - lib/lattice_stripe/promotion_code.ex
    - lib/lattice_stripe/transfer.ex
    - lib/lattice_stripe/transfer_reversal.ex
    - CHANGELOG.md
tech_stack:
  added: []
  patterns:
    - "(if is_map(val), do: ObjectTypes.maybe_deserialize(val), else: val) — expand guard pattern for struct fields in keyword lists (parentheses required)"
key_files:
  created: []
  modified:
    - lib/lattice_stripe/invoice.ex
    - lib/lattice_stripe/invoice_item.ex
    - lib/lattice_stripe/subscription_item.ex
    - lib/lattice_stripe/card.ex
    - lib/lattice_stripe/payment_method.ex
    - lib/lattice_stripe/promotion_code.ex
    - lib/lattice_stripe/transfer.ex
    - lib/lattice_stripe/transfer_reversal.ex
    - test/lattice_stripe/invoice_test.exs
    - test/lattice_stripe/invoice_item_test.exs
    - CHANGELOG.md
decisions:
  - "Parentheses required around if-expressions in Elixir keyword struct fields — bare `if` after a keyword key followed by comma causes ambiguity parse error; wrap with `(if ..., do: ..., else: ...)`"
  - "Card.cast/1 and PaymentMethod.from_map/1 use direct map access (not Map.split), but same expand guard pattern applies"
  - "Transfer uses direct map access in from_map/1 (not Map.split) due to reversals special-case decoding"
metrics:
  duration_minutes: 11
  completed_date: "2026-04-16"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 11
---

# Phase 22 Plan 04: Expand Guards for Remaining Modules + CHANGELOG Summary

Expand deserialization guards added to 8 remaining resource modules; EXPD-02 dot-path expand verified by automated test; CHANGELOG migration note for expand behavior change and status atomization delivered (EXPD-04).

## What Was Built

### Task 1: Expand guards for Invoice, InvoiceItem, SubscriptionItem, Card, PaymentMethod, PromotionCode

Added `alias LatticeStripe.ObjectTypes` and `(if is_map(val), do: ObjectTypes.maybe_deserialize(val), else: val)` guards to expandable fields in 6 modules:

| Module | Expandable fields guarded |
|--------|--------------------------|
| Invoice | customer, charge, payment_intent, subscription |
| InvoiceItem | customer, invoice, subscription |
| SubscriptionItem | subscription |
| Card | customer (in cast/1) |
| PaymentMethod | customer |
| PromotionCode | customer |

Updated `@type t` union typespecs for all guarded fields (e.g., `LatticeStripe.Customer.t() | String.t() | nil`).

Added expand dispatch tests to `invoice_test.exs` and `invoice_item_test.exs`:
- String ID preserved when not expanded
- Expanded map dispatched to typed struct via ObjectTypes
- nil handled correctly

**EXPD-02 dot-path expand verification test** added to `invoice_test.exs`:
```
test "dot-path expand: nested expanded customer in list data item deserializes to %Customer{} (EXPD-02)"
```
This proves that `expand: ["data.customer"]` works automatically — Stripe expands server-side and the `is_map` guard in `from_map/1` handles both `["customer"]` and `["data.customer"]` identically.

### Task 2: Expand guards for Transfer, TransferReversal + CHANGELOG migration note

Added expand guards to:

| Module | Expandable fields guarded |
|--------|--------------------------|
| Transfer | balance_transaction, destination, destination_payment, source_transaction |
| TransferReversal | balance_transaction, destination_payment_refund, source_refund, transfer |

Updated union typespecs:
- `Transfer.balance_transaction: LatticeStripe.BalanceTransaction.t() | String.t() | nil`
- `Transfer.destination: LatticeStripe.Account.t() | String.t() | nil`
- `Transfer.destination_payment: LatticeStripe.Charge.t() | String.t() | nil`
- `Transfer.source_transaction: LatticeStripe.Charge.t() | String.t() | nil`
- `TransferReversal.balance_transaction: LatticeStripe.BalanceTransaction.t() | String.t() | nil`
- `TransferReversal.destination_payment_refund: LatticeStripe.Refund.t() | String.t() | nil`
- `TransferReversal.source_refund: LatticeStripe.Refund.t() | String.t() | nil`
- `TransferReversal.transfer: LatticeStripe.Transfer.t() | String.t() | nil`

Added `## [Unreleased]` section to CHANGELOG.md with:
- Expand deserialization migration note (before/after pattern-match examples)
- Status atomization migration note (before/after comparison examples)
- Deprecation notice for `Billing.Meter.status_atom/1` and `Account.Capability.status_atom/1`
- Addition note for `LatticeStripe.ObjectTypes`

## Commits

| Hash | Task | Description |
|------|------|-------------|
| 071c740 | Task 1 | feat(22-04): add expand guards to Invoice, InvoiceItem, SubscriptionItem, Card, PaymentMethod, PromotionCode + EXPD-02 dot-path expand test |
| c3c8c84 | Task 2 | feat(22-04): add expand guards to Transfer/TransferReversal + CHANGELOG migration note |

## Verification Results

- `mix compile --warnings-as-errors` — clean (0 warnings)
- `mix test` — 1505 tests, 0 failures (149 excluded integration tests)
- `grep -l "ObjectTypes.maybe_deserialize" lib/lattice_stripe/*.ex` — returns all 8 target modules
- `grep "Expand deserialization" CHANGELOG.md` — found
- `grep "Status atomization" CHANGELOG.md` — found
- `grep "dot-path expand" test/lattice_stripe/invoice_test.exs` — found

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Elixir `if` keyword argument ambiguity in struct literals**
- **Found during:** Task 1 (first compile after writing expand guards)
- **Issue:** Elixir parse error: bare `if is_map(val), do: ..., else: val,` after a struct keyword key causes `unexpected comma` and `missing parentheses` errors because the compiler cannot distinguish whether the comma ends the `if` argument list or the struct field list
- **Fix:** Wrapped all expand guard `if` expressions in parentheses: `(if is_map(val), do: ..., else: val)` — this is the idiomatic Elixir pattern for if-expressions as values inside keyword lists
- **Files modified:** invoice.ex, invoice_item.ex, subscription_item.ex, card.ex, payment_method.ex, promotion_code.ex, transfer.ex, transfer_reversal.ex
- **Commit:** 071c740 (Task 1), c3c8c84 (Task 2)

## Known Stubs

None. All expand guards wire to `ObjectTypes.maybe_deserialize/1` which dispatches through the compile-time whitelist registry.

## Threat Flags

None. No new network endpoints, auth paths, or trust boundary changes introduced. The expand deserialization guards operate entirely within existing `from_map/1` call sites — no new surface.

## Self-Check

Verified:
- `lib/lattice_stripe/invoice.ex` exists and contains `ObjectTypes.maybe_deserialize(known["customer"])` — FOUND
- `lib/lattice_stripe/transfer.ex` exists and contains `ObjectTypes.maybe_deserialize(map["balance_transaction"])` — FOUND
- `CHANGELOG.md` contains "Expand deserialization" — FOUND
- Commit 071c740 exists — FOUND
- Commit c3c8c84 exists — FOUND

## Self-Check: PASSED
