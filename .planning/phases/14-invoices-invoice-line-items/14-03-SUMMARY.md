---
phase: 14-invoices-invoice-line-items
plan: 03
subsystem: billing-resources
tags: [invoice, action-verbs, search, preview, proration, line-items, billing]
dependency_graph:
  requires:
    - LatticeStripe.Invoice (14-02)
    - LatticeStripe.Billing.Guards (14-01)
    - LatticeStripe.Invoice.LineItem (14-01)
  provides:
    - Invoice.finalize/4, void/4, pay/4, send_invoice/4, mark_uncollectible/4
    - Invoice.search/3, search_stream!/3
    - Invoice.upcoming/3, create_preview/3
    - Invoice.upcoming_lines/3, create_preview_lines/3
    - Invoice.list_line_items/4, stream_line_items!/4
  affects:
    - lib/lattice_stripe/invoice.ex
    - test/lattice_stripe/invoice_test.exs
tech_stack:
  added: []
  patterns:
    - Action verbs follow PaymentIntent.confirm/4 precedent — POST to /v1/invoices/:id/{verb}
    - Proration guard via 'with :ok <- Billing.Guards.check_proration_required' pattern
    - Preview endpoints return %Invoice{id: nil} (unsigned/unpersisted objects)
    - Line item child resources follow Checkout.Session.list_line_items/4 precedent
    - search/3 uses map params (not raw query string) to enable future extension
key_files:
  created: []
  modified:
    - lib/lattice_stripe/invoice.ex
    - test/lattice_stripe/invoice_test.exs
decisions:
  - "Invoice.search/3 takes a map with 'query' key (not a raw query string like Customer.search) — consistent with plan interface spec and allows additional search params"
  - "Proration guard in upcoming/create_preview uses 'with :ok <-' pattern — idiomatic Elixir short-circuit that composes cleanly with other pre-request guards in future"
  - "send_invoice named send_invoice not send — avoids shadowing Kernel.send/2"
  - "search test asserts req.url =~ path (not String.ends_with?) because GET params are query-string-appended to URL"
metrics:
  duration: ~12min
  completed: 2026-04-12
  tasks_completed: 2
  files_created: 0
  files_modified: 2
---

# Phase 14 Plan 03: Invoice Action Verbs, Search, Preview, and Line Items Summary

Invoice module extended with 21 new public functions: 5 action verbs (finalize/void/pay/send_invoice/mark_uncollectible) with bang variants, search with Eventual Consistency callout, upcoming/create_preview preview endpoints with proration guard, and list_line_items/stream_line_items child resource access.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add action verbs and search to Invoice module | eb4ab67 | lib/lattice_stripe/invoice.ex, test/lattice_stripe/invoice_test.exs |
| 2 | Add upcoming/create_preview with proration guard, and list_line_items/stream_line_items | 1a78e95 | lib/lattice_stripe/invoice.ex, test/lattice_stripe/invoice_test.exs |

## What Was Built

### Task 1 — Action Verbs and Search

**5 Action Verbs** (following PaymentIntent.confirm/4 precedent):

- `finalize/4` + `finalize!/4` — POST `/v1/invoices/:id/finalize`
- `void/4` + `void!/4` — POST `/v1/invoices/:id/void`
- `pay/4` + `pay!/4` — POST `/v1/invoices/:id/pay` (accepts `paid_out_of_band`, `payment_method`, `source`)
- `send_invoice/4` + `send_invoice!/4` — POST `/v1/invoices/:id/send` (named `send_invoice` to avoid `Kernel.send/2` conflict)
- `mark_uncollectible/4` + `mark_uncollectible!/4` — POST `/v1/invoices/:id/mark_uncollectible`

All action verbs have uniform arity `(client, id, params \\ %{}, opts \\ [])`.

**Search** (following Customer.search precedent but with map params):

- `search/3` — GET `/v1/invoices/search` with Eventual Consistency `{: .warning}` admonition
- `search_stream!/3` — lazy auto-paginated stream
- `@doc` includes searchable fields list and note that upcoming invoices are not searchable

### Task 2 — Preview Endpoints and Line Items

**Preview Endpoints** (with Billing.Guards proration guard):

- `upcoming/3` + `upcoming!/3` — GET `/v1/invoices/upcoming`, includes Deprecation Notice admonition pointing to `create_preview/3`
- `create_preview/3` + `create_preview!/3` — POST `/v1/invoices/create_preview`
- Both call `Billing.Guards.check_proration_required/2` via `with :ok <-` before making HTTP request
- Both return `%Invoice{id: nil}` (preview invoices are not persisted)

**Preview Line Item Pagination**:

- `upcoming_lines/3` — GET `/v1/invoices/upcoming/lines`, returns `%List{data: [%LineItem{}]}`
- `create_preview_lines/3` — POST `/v1/invoices/create_preview/lines`

**Child Line Item Access**:

- `list_line_items/4` + `list_line_items!/4` — GET `/v1/invoices/:id/lines`
- `stream_line_items!/4` — lazy auto-paginated stream of `%Invoice.LineItem{}` structs

## Test Coverage

| Test File | Tests Before | Tests After | Result |
|-----------|-------------|-------------|--------|
| invoice_test.exs | 41 | 69 | PASS |
| **Full suite** | **684** | **712** | **0 failures** |

28 new tests added across 14 describe blocks.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] search test assertion used String.ends_with? but GET params are appended to URL**
- **Found during:** Task 1 test verification
- **Issue:** `String.ends_with?(req.url, "/v1/invoices/search")` failed because GET params produce `url?query=...`, so the URL no longer ends with the bare path
- **Fix:** Changed assertion to `req.url =~ "/v1/invoices/search"` (substring match) — same pattern used for other GET-with-params tests in the suite
- **Files modified:** test/lattice_stripe/invoice_test.exs
- **Commit:** inline in eb4ab67

**2. [Rule 1 - Bug] test_client called with map literal instead of keyword list**
- **Found during:** Task 2 test RED phase
- **Issue:** `test_client(%{require_explicit_proration: true})` triggered `FunctionClauseError` in `Keyword.merge/2` — `TestHelpers.test_client/1` expects a keyword list
- **Fix:** Changed all 4 occurrences to `test_client(require_explicit_proration: true)`
- **Files modified:** test/lattice_stripe/invoice_test.exs
- **Commit:** inline in 1a78e95

**3. [Rule 2 - Missing functionality] Billing alias added to invoice.ex**
- **Found during:** Task 2 implementation
- **Issue:** `Billing.Guards.check_proration_required/2` required the `Billing` alias to be present
- **Fix:** Added `Billing` to the existing alias line: `alias LatticeStripe.{Billing, Client, ...}`
- **Files modified:** lib/lattice_stripe/invoice.ex
- **Commit:** inline in 1a78e95

## Known Stubs

None — all functions route to real Stripe API endpoints. Preview endpoints correctly return `%Invoice{id: nil}` per Stripe API behavior (upstream invoices are not persisted objects).

## Threat Surface Scan

T-14-09 (Elevation of Privilege — proration guard bypass) is addressed: `upcoming/3` and `create_preview/3` both call `Billing.Guards.check_proration_required/2` inside a `with :ok <-` expression, ensuring the HTTP request is never made when the guard fails. Guard is not bypassable by callers using these public functions.

No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries introduced beyond what was planned.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| lib/lattice_stripe/invoice.ex | FOUND |
| test/lattice_stripe/invoice_test.exs | FOUND |
| Commit eb4ab67 (Task 1) | FOUND |
| Commit 1a78e95 (Task 2) | FOUND |
| `def finalize` present | FOUND |
| `def void` present | FOUND |
| `def pay` present | FOUND |
| `def send_invoice` present | FOUND |
| `def mark_uncollectible` present | FOUND |
| `def search` present | FOUND |
| `def upcoming` present | FOUND |
| `def create_preview` present | FOUND |
| `Billing.Guards.check_proration_required` (x2) | FOUND |
| `Deprecation Notice` in upcoming @doc | FOUND |
| `Eventual Consistency` in search @doc | FOUND |
| `Upcoming invoices...not searchable` | FOUND |
| 712 tests, 0 failures | VERIFIED |
