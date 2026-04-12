---
status: complete
phase: 14-invoices-invoice-line-items
source:
  - 14-01-SUMMARY.md
  - 14-02-SUMMARY.md
  - 14-03-SUMMARY.md
  - 14-04-SUMMARY.md
  - 14-05-SUMMARY.md
started: 2026-04-12T00:00:00Z
updated: 2026-04-12T00:00:00Z
signed_off_by: user
---

## Current Test

[testing complete]

## Tests

### 1. Full unit test suite
expected: `mix test` — 722 tests, 0 failures (including the IN-01 GET fix regression test)
result: pass
evidence: |
  Ran 2026-04-12: `722 tests, 0 failures (52 excluded)`

### 2. Integration tests against stripe-mock
expected: `mix test --only integration` — all integration tests pass against `stripe/stripe-mock:latest` on localhost:12111
result: pass
evidence: |
  Ran 2026-04-12 with stripe-mock docker container running:
  `52 tests, 0 failures, 8 skipped (722 excluded)`

### 3. Invoice CRUD + action verbs available
expected: |
  `Invoice.create/3`, `retrieve/3`, `update/4`, `delete/3`, `list/3`, `finalize/4`,
  `void/4`, `pay/4`, `send_invoice/4`, `mark_uncollectible/4` all present with bang variants.
result: pass
evidence: |
  invoice.ex lines 288-580 — verified by invoice_test.exs (69 tests)

### 4. Invoice search with eventual-consistency docs
expected: |
  `Invoice.search/3` and `search_stream!/3` available; @doc references Stripe eventual
  consistency admonition.
result: pass
evidence: invoice.ex:616-676; unit tests confirm GET /v1/invoices/search

### 5. Preview endpoints with proration guard (WR-01 regression)
expected: |
  `Invoice.upcoming/3` and `Invoice.create_preview/3` both call Billing.Guards.check_proration_required,
  and the guard accepts proration_behavior both at the top level AND nested inside subscription_details.
result: pass
evidence: |
  billing/guards.ex:37-41 `has_proration_behavior?/1` checks both paths (commit 0628bbd).
  guards_test.exs unit tests cover both shapes.

### 6. create_preview_lines/3 uses correct HTTP verb (IN-01 fix)
expected: |
  `Invoice.create_preview_lines/3` issues `GET /v1/invoices/create_preview/lines`.
  POST returns 404 "Unrecognized request URL" from stripe-mock; GET is accepted.
result: pass
evidence: |
  invoice.ex:779 method :get (commit 4709ad8).
  Direct stripe-mock probe: POST → 404 "Unrecognized request URL", GET → 400 validator error (URL accepted).
  invoice_test.exs:767-778 asserts `req.method == :get`.

### 7. Auto-advance telemetry event emitted
expected: |
  `Invoice.create/3` returning `%Invoice{auto_advance: true}` emits
  `[:lattice_stripe, :invoice, :auto_advance_scheduled]` with invoice_id and customer metadata,
  respecting client.telemetry_enabled flag.
result: pass
evidence: |
  invoice.ex:295-296 pattern-matches on {:ok, %Invoice{auto_advance: true}}.
  telemetry.ex:325 emit_auto_advance_scheduled/2, :425 handle_auto_advance_log/4.
  telemetry_test.exs covers both emission and default-logger handler.

### 8. InvoiceItem CRUD at /v1/invoiceitems
expected: |
  `InvoiceItem.create/3`, `retrieve/3`, `update/4`, `delete/3`, `list/3` operate against
  `/v1/invoiceitems` (not `/v1/invoice_items`).
result: pass
evidence: |
  invoice_item.ex 408 lines; invoice_item_test.exs 289 lines.
  Integration test hits real stripe-mock endpoint.

### 9. WR-02: parse_lines preserves unknown shapes
expected: |
  `defp parse_lines(other), do: other` — unexpected map shapes pass through as raw data
  instead of becoming nil.
result: pass
evidence: invoice.ex:1066 (commit 97bae75)

### 10. WR-03: telemetry ID-segment prefixes include ii_ and il_
expected: |
  `known_prefixes` in id_segment?/1 includes both `ii_` (InvoiceItem) and `il_` (Invoice LineItem).
result: pass
evidence: telemetry.ex:632 — `~w[cus_ pi_ seti_ pm_ re_ cs_ evt_ ch_ in_ sub_ prod_ price_ ii_ il_]` (commit c464feb)

### 11. WR-04: finch pinned to ~> 0.21
expected: |
  `mix.exs` declares `{:finch, "~> 0.21"}` matching CLAUDE.md floor.
result: pass
evidence: mix.exs:110 (commit 4a084e7)

### 12. ExDoc build: Billing group + invoices guide
expected: |
  `mix docs` succeeds; generates doc/LatticeStripe.Invoice.html; Billing group includes
  all 7 Phase 14 modules; guides/invoices.md (556 lines) is in extras.
result: pass
evidence: |
  Ran 2026-04-12: `View html docs at "doc/index.html"` with no warnings.
  doc/LatticeStripe.Invoice.html exists. mix.exs:28 extras, :61-68 groups.

## Summary

total: 12
passed: 12
issues: 0
pending: 0
skipped: 0

## Gaps

[none]

## Notes

- All 4 Warning-severity code review findings (WR-01..04) landed and are reflected in current code.
- IN-01 resolved in commit 4709ad8 after direct stripe-mock verification.
- Info-severity IN-02 (style: bang-variant pipe forwarding) and IN-03 (missing stream! unit tests) remain open — safe to defer, not blocking.
- Administrative gap: BILL-04b/04c/10 referenced in 14-05-SUMMARY.md but never registered in REQUIREMENTS.md. Functional work is present; the requirements themselves are untracked.
- 14-VERIFICATION.md is superseded by this UAT run (it still read `human_needed` because it was authored before the REVIEW-FIX + IN-01 fixes landed).
