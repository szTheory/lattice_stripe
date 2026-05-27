---
phase: 51-taxid-testing-adoption-surface
reviewed: 2026-05-27T12:00:00Z
depth: standard
files_reviewed: 33
files_reviewed_list:
  - README.md
  - guides/invoices.md
  - guides/payments.md
  - guides/recipes.md
  - guides/subscriptions.md
  - guides/tax.md
  - guides/testing.md
  - guides/user-flows-and-jtbd.md
  - lib/lattice_stripe/object_types.ex
  - lib/lattice_stripe/tax/calculation.ex
  - lib/lattice_stripe/tax/calculation/line_item.ex
  - lib/lattice_stripe/tax/customer_details.ex
  - lib/lattice_stripe/tax/registration.ex
  - lib/lattice_stripe/tax/settings.ex
  - lib/lattice_stripe/tax/ship_from_details.ex
  - lib/lattice_stripe/tax/shipping_cost.ex
  - lib/lattice_stripe/tax/tax_breakdown.ex
  - lib/lattice_stripe/tax/transaction.ex
  - lib/lattice_stripe/tax/transaction/line_item.ex
  - lib/lattice_stripe/tax_id.ex
  - lib/lattice_stripe/tax_id/owner.ex
  - lib/lattice_stripe/tax_id/verification.ex
  - lib/lattice_stripe/testing.ex
  - lib/lattice_stripe/testing/fixtures/tax_calculation.ex
  - lib/lattice_stripe/testing/fixtures/tax_id.ex
  - lib/lattice_stripe/testing/fixtures/tax_transaction.ex
  - mix.exs
  - test/lattice_stripe/docs_truth_test.exs
  - test/lattice_stripe/object_types_test.exs
  - test/lattice_stripe/tax/calculation_test.exs
  - test/lattice_stripe/tax/calculation_transaction_test.exs
  - test/lattice_stripe/tax/transaction_test.exs
  - test/lattice_stripe/tax_id_test.exs
  - test/lattice_stripe/tax_object_types_expand_test.exs
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
status: issues_found
---

# Phase 51: Code Review Report

**Reviewed:** 2026-05-27T12:00:00Z
**Depth:** standard
**Files Reviewed:** 33
**Status:** issues_found

## Summary

Phase 51 delivers a well-structured Tax adoption surface: dual-path `LatticeStripe.TaxId` with guard-based arity routing, public Testing fixtures, canonical `guides/tax.md`, discovery wiring, and docs-truth regression locks. The implementation follows established SDK patterns (Coupon CRUDL-minus-update, ObjectTypes dispatch, Mox URL contract tests).

Two warnings affect `TaxId` request hygiene and PII handling in inspect output. One info item notes an ergonomic footgun on nested `stream!/3`. Documentation and test coverage align with phase CONTEXT requirements (including the intentional four-scenario expand proof scope for DX-01).

## Warnings

### WR-01: Nested create only strips string `"customer"` key

**File:** `lib/lattice_stripe/tax_id.ex:110`
**Issue:** Nested `create/4` calls `Map.drop(params, ["customer"])` before POSTing to `/v1/customers/:id/tax_ids`. Atom-key params (`%{customer: "cus_..."}`) are not stripped. `FormEncoder` encodes atom keys as `customer=...`, so a caller mixing atom keys could send a redundant or conflicting `customer` field despite the URL-scoped customer. Moduledoc examples use string keys, but the SDK does not enforce that convention here.
**Fix:**
```elixir
params = Map.drop(params, ["customer", :customer])
```

### WR-02: TaxId Inspect redacts `:value` but nested verification PII remains visible

**File:** `lib/lattice_stripe/tax_id.ex:359-380`
**Issue:** Custom `Inspect` for `%TaxId{}` redacts `:value` (tax ID number) but leaves `%TaxId.Verification{}` subfields (`verified_name`, `verified_address`) visible via default struct inspection. Logging or IEx output of a `%TaxId{}` can still leak PII that the redaction was meant to prevent. Account modules (e.g. `Account.Individual`) redact multiple sensitive fields explicitly.
**Fix:** Either add a custom `Inspect` for `TaxId.Verification` that redacts `verified_name` and `verified_address`, or recursively redact those fields in the TaxId inspect impl before calling `to_doc/2`.

## Info

### IN-01: Nested `stream!/3` requires an explicit params map

**File:** `lib/lattice_stripe/tax_id.ex:254-278`
**Issue:** `TaxId.stream!(client, "cus_123")` raises `FunctionClauseError` because the nested clause requires `is_map(params)`. Callers must use `stream!(client, "cus_123", %{})`. This matches `list/4` behavior but is easy to miss since top-level `stream!(client)` works with defaults.
**Fix:** Document in the dual-path table that nested stream/list require `%{}` when no query params are needed, or add a clause `stream!(client, customer_id) when is_binary(customer_id)` delegating to `stream!(client, customer_id, %{})`.

---

_Reviewed: 2026-05-27T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
