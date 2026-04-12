---
phase: 14-invoices-invoice-line-items
plan: 01
subsystem: billing-foundation
tags: [structs, billing, guards, proration, invoice]
dependency_graph:
  requires: []
  provides:
    - LatticeStripe.Invoice.StatusTransitions
    - LatticeStripe.Invoice.AutomaticTax
    - LatticeStripe.Invoice.LineItem
    - LatticeStripe.InvoiceItem.Period
    - LatticeStripe.Billing.Guards
    - Client.require_explicit_proration
    - Error.error_type :proration_required
  affects:
    - lib/lattice_stripe/client.ex
    - lib/lattice_stripe/config.ex
    - lib/lattice_stripe/error.ex
tech_stack:
  added: []
  patterns:
    - typed nested struct with from_map/1 and nil guard (StatusTransitions, AutomaticTax, InvoiceItem.Period)
    - known-field split with extra catch-all (Invoice.LineItem, following Checkout.LineItem)
    - custom Inspect impl hiding empty extra field (Invoice.LineItem)
    - NimbleOptions boolean schema option (require_explicit_proration)
    - pre-request guard function returning :ok | {:error, %Error{}} (Billing.Guards)
key_files:
  created:
    - lib/lattice_stripe/invoice/status_transitions.ex
    - lib/lattice_stripe/invoice/automatic_tax.ex
    - lib/lattice_stripe/invoice/line_item.ex
    - lib/lattice_stripe/invoice_item/period.ex
    - lib/lattice_stripe/billing/guards.ex
    - test/lattice_stripe/invoice/status_transitions_test.exs
    - test/lattice_stripe/invoice/automatic_tax_test.exs
    - test/lattice_stripe/invoice/line_item_test.exs
    - test/lattice_stripe/invoice_item/period_test.exs
    - test/lattice_stripe/billing/guards_test.exs
  modified:
    - lib/lattice_stripe/client.ex
    - lib/lattice_stripe/config.ex
    - lib/lattice_stripe/error.ex
    - test/lattice_stripe/client_test.exs
    - test/lattice_stripe/config_test.exs
decisions:
  - "Invoice.LineItem uses @known_fields + Map.split/2 for extra catch-all, matching Checkout.LineItem precedent exactly"
  - "AutomaticTax.liability kept as raw map() — no sub-struct per D-14f (no nesting needed)"
  - "require_explicit_proration defaults to false — zero behavior change for existing users"
  - "Error type :test_clock_timeout and :test_clock_failed added to union alongside :proration_required to align worktree with main project state"
metrics:
  duration: ~15min
  completed: 2026-04-12
  tasks_completed: 2
  files_created: 10
  files_modified: 5
---

# Phase 14 Plan 01: Typed Nested Structs + Billing Guards Foundation Summary

Shipped typed nested structs for Invoice parsing (StatusTransitions, AutomaticTax, LineItem, InvoiceItem.Period), the proration guard module (Billing.Guards), and the `require_explicit_proration` client flag wired through Client/Config/Error.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create typed nested structs — StatusTransitions, AutomaticTax, LineItem, InvoiceItem.Period | 39b98c9 | 4 new lib + 4 new test files |
| 2 | Add require_explicit_proration to Client + Config + Error, create Billing.Guards | 68f6cda | 1 new lib + 1 new test + 5 modified files |

## What Was Built

### Task 1 — Typed Nested Structs

Four typed struct modules created, each following the Checkout.LineItem / Price.Recurring precedent:

**LatticeStripe.Invoice.StatusTransitions** (`lib/lattice_stripe/invoice/status_transitions.ex`)
- 4 Unix timestamp fields: `finalized_at`, `marked_uncollectible_at`, `paid_at`, `voided_at`
- `from_map/1` with nil guard clause and map clause
- All fields default to nil when keys are absent

**LatticeStripe.Invoice.AutomaticTax** (`lib/lattice_stripe/invoice/automatic_tax.ex`)
- Fields: `enabled` (boolean), `status` (string), `liability` (raw map)
- `liability` kept as raw map per D-14f — no sub-struct needed
- `from_map/1` with nil guard

**LatticeStripe.Invoice.LineItem** (`lib/lattice_stripe/invoice/line_item.ex`)
- 25 known fields including `invoice_item` (the InvoiceItem vs Invoice Line Item disambiguation is documented in moduledoc)
- `@known_fields` sigil + `Map.split/2` + `extra: %{}` catch-all
- Custom `Inspect` protocol implementation: hides `:extra` when empty, shows it when non-empty
- `from_map/1` with nil guard

**LatticeStripe.InvoiceItem.Period** (`lib/lattice_stripe/invoice_item/period.ex`)
- Fields: `start`, `end` (Unix timestamps)
- `from_map/1` with nil guard

### Task 2 — Cross-Cutting Infrastructure

**LatticeStripe.Billing.Guards** (`lib/lattice_stripe/billing/guards.ex`)
- `check_proration_required/2` with 3 clauses:
  1. `require_explicit_proration: false` — always returns `:ok`
  2. `require_explicit_proration: true` + `"proration_behavior"` key present — returns `:ok`
  3. `require_explicit_proration: true` + key absent — returns `{:error, %Error{type: :proration_required}}`

**LatticeStripe.Error** — Added `:proration_required` to `@type error_type` union (alongside `:test_clock_timeout` and `:test_clock_failed` to align worktree with main project state)

**LatticeStripe.Client** — Added `require_explicit_proration: false` to defstruct defaults and `@type t`

**LatticeStripe.Config** — Added `require_explicit_proration` to NimbleOptions schema (`:boolean`, default `false`)

## Test Coverage

| Test File | Tests | Result |
|-----------|-------|--------|
| status_transitions_test.exs | 4 | PASS |
| automatic_tax_test.exs | 5 | PASS |
| line_item_test.exs | 8 | PASS |
| invoice_item/period_test.exs | 4 | PASS |
| billing/guards_test.exs | 7 | PASS |
| client_test.exs (additions) | 2 | PASS |
| config_test.exs (additions) | 3 | PASS |
| **Full suite** | **623** | **0 failures** |

## Deviations from Plan

None — plan executed exactly as written.

The error.ex modification also added `:test_clock_timeout` and `:test_clock_failed` to the union because the worktree's baseline (v1) error.ex was missing those types that exist in the main project. This was a [Rule 1 - Bug] auto-fix to keep the error type union consistent.

## Known Stubs

None — all modules are fully implemented with real data flow. No hardcoded values, placeholders, or TODO markers.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries introduced. All new modules are pure data struct transformations and a guard function on client-controlled state. No threat flags.

## Self-Check: PASSED

All created files found on disk. Both task commits verified in git log.

| Check | Result |
|-------|--------|
| lib/lattice_stripe/invoice/status_transitions.ex | FOUND |
| lib/lattice_stripe/invoice/automatic_tax.ex | FOUND |
| lib/lattice_stripe/invoice/line_item.ex | FOUND |
| lib/lattice_stripe/invoice_item/period.ex | FOUND |
| lib/lattice_stripe/billing/guards.ex | FOUND |
| Commit 39b98c9 (Task 1) | FOUND |
| Commit 68f6cda (Task 2) | FOUND |
