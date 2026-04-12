---
phase: 14-invoices-invoice-line-items
plan: 05
subsystem: billing-documentation
tags: [invoice, invoice-item, exdoc, guides, billing, documentation]
dependency_graph:
  requires:
    - LatticeStripe.Invoice (14-02, 14-03)
    - LatticeStripe.InvoiceItem (14-02)
    - LatticeStripe.Billing.Guards (14-01)
    - LatticeStripe.Invoice.LineItem (14-01)
    - LatticeStripe.Invoice.StatusTransitions (14-01)
    - LatticeStripe.Invoice.AutomaticTax (14-01)
    - LatticeStripe.InvoiceItem.Period (14-01)
    - Auto-advance telemetry warning (14-04)
    - ExDoc configuration established in Phase 10
  provides:
    - guides/invoices.md — 556-line comprehensive workflow guide
    - Billing module group in mix.exs groups_for_modules
    - guides/invoices.md in mix.exs extras list
  affects:
    - Generated HexDocs (Billing group now visible in module nav)
    - guides/invoices.md (primary learning resource for Invoice/InvoiceItem)
tech_stack:
  added: []
  patterns:
    - Guide follows guides/payments.md conventions — plain Markdown, code blocks, admonition blockquotes, no custom ExDoc annotations
    - Billing group placed after Checkout group in groups_for_modules — domain ordering (Core, Payments, Checkout, Billing, Webhooks, Telemetry, Internals)
key_files:
  created:
    - guides/invoices.md
    - .planning/phases/14-invoices-invoice-line-items/14-05-SUMMARY.md
  modified:
    - mix.exs
key_decisions:
  - "guides/invoices.md placed after guides/checkout.md in extras list — topical ordering (payments flow -> checkout -> billing/invoices)"
  - "Billing group in groups_for_modules includes all 7 Phase 14 modules: Invoice, Invoice.LineItem, Invoice.StatusTransitions, Invoice.AutomaticTax, InvoiceItem, InvoiceItem.Period, Billing.Guards"
  - "Testing Invoices section references test clock workflow pattern without importing Phase 13 modules directly — guide stays self-contained"

requirements-completed: [BILL-04, BILL-04b, BILL-04c, BILL-10]

duration: ~10min
completed: 2026-04-12
---

# Phase 14 Plan 05: Invoices Guide and ExDoc Config Summary

**556-line invoices.md workflow guide covering the full Invoice lifecycle plus ExDoc Billing module group organizing all 7 Phase 14 modules**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-12T16:00:00Z
- **Completed:** 2026-04-12T16:17:14Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created `guides/invoices.md` (556 lines, 11 sections) matching the tone and formatting of `guides/payments.md` — the canonical reference guide for Invoice and InvoiceItem workflows
- Updated `mix.exs` to include the guide in ExDoc extras and organize all Phase 14 modules into a `Billing` group
- Guide covers the auto-advance footgun with the telemetry warning introduced in Plan 14-04, proration preview with both `upcoming/3` and `create_preview/3`, and the `require_explicit_proration` guard

## Task Commits

Each task was committed atomically:

1. **Task 1: Create guides/invoices.md comprehensive workflow guide** - `1c44bf9` (docs)
2. **Task 2: Update mix.exs ExDoc config — extras + module groups** - `939ca5b` (chore)

## Files Created/Modified

- `guides/invoices.md` — 556-line invoice workflow guide with 11 sections: The Invoice Workflow, Collection Methods, Auto-Advance Behavior, Working with Invoice Items, Draft Invoice Management, Action Verbs, Proration Preview, Subscription-Generated Invoices, Testing Invoices with Test Clocks, Listing and Searching, Common Pitfalls
- `mix.exs` — Added `"guides/invoices.md"` to extras list; added `Billing:` group to `groups_for_modules` with Invoice, Invoice.LineItem, Invoice.StatusTransitions, Invoice.AutomaticTax, InvoiceItem, InvoiceItem.Period, Billing.Guards

## Decisions Made

- `guides/invoices.md` placed after `guides/checkout.md` in the extras list to maintain topical ordering (payments flow → checkout → billing/invoices)
- Billing group in `groups_for_modules` includes all 7 Phase 14 modules, placed after the Checkout group
- The Testing Invoices section references test clock workflow without depending on Phase 13 module function signatures — keeps the guide self-contained

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Phase 14 is complete. All 5 plans executed:
- 14-01: Typed nested structs and Billing.Guards
- 14-02: Invoice and InvoiceItem resource modules
- 14-03: Invoice action verbs, search, previews, line items
- 14-04: Auto-advance telemetry + integration tests
- 14-05: Documentation guide and ExDoc config (this plan)

The Invoice/InvoiceItem subsystem is production-ready with full CRUD, lifecycle actions, proration preview, telemetry observability, stripe-mock integration tests, and comprehensive documentation.

## Known Stubs

None — the guide contains only placeholder IDs (`cus_xxx`, `sub_xxx`) as is standard for API documentation examples. No stubs that would prevent the guide's goal from being achieved.

## Threat Flags

None — documentation and configuration only, no new trust boundaries.

## Self-Check: PASSED

- `guides/invoices.md` exists (556 lines, 11 sections) ✓
- `mix.exs` contains `"guides/invoices.md"` in extras ✓
- `mix.exs` contains `LatticeStripe.Invoice,` in Billing group ✓
- Commits 1c44bf9 and 939ca5b exist ✓

---
*Phase: 14-invoices-invoice-line-items*
*Completed: 2026-04-12*
