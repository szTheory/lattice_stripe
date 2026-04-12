---
phase: 14-invoices-invoice-line-items
reviewed: 2026-04-12T00:00:00Z
depth: standard
files_reviewed: 25
files_reviewed_list:
  - guides/invoices.md
  - lib/lattice_stripe/billing/guards.ex
  - lib/lattice_stripe/client.ex
  - lib/lattice_stripe/config.ex
  - lib/lattice_stripe/error.ex
  - lib/lattice_stripe/invoice.ex
  - lib/lattice_stripe/invoice/automatic_tax.ex
  - lib/lattice_stripe/invoice/line_item.ex
  - lib/lattice_stripe/invoice/status_transitions.ex
  - lib/lattice_stripe/invoice_item.ex
  - lib/lattice_stripe/invoice_item/period.ex
  - lib/lattice_stripe/telemetry.ex
  - mix.exs
  - test/integration/invoice_integration_test.exs
  - test/integration/invoice_item_integration_test.exs
  - test/lattice_stripe/billing/guards_test.exs
  - test/lattice_stripe/client_test.exs
  - test/lattice_stripe/config_test.exs
  - test/lattice_stripe/invoice/automatic_tax_test.exs
  - test/lattice_stripe/invoice/line_item_test.exs
  - test/lattice_stripe/invoice/status_transitions_test.exs
  - test/lattice_stripe/invoice_item/period_test.exs
  - test/lattice_stripe/invoice_item_test.exs
  - test/lattice_stripe/invoice_test.exs
  - test/lattice_stripe/telemetry_test.exs
findings:
  critical: 0
  warning: 4
  info: 5
  total: 9
status: issues_found
---

# Phase 14: Code Review Report

**Reviewed:** 2026-04-12
**Depth:** standard
**Files Reviewed:** 25
**Status:** issues_found

## Summary

This phase delivers the Invoice and InvoiceItem modules — CRUD, action verbs (finalize, pay, void, send, mark_uncollectible), search, preview endpoints, line item access, streaming, and the billing guards for proration. The implementation is well-structured and follows the patterns established in earlier phases cleanly.

No critical issues were found. The four warnings are all correctness concerns: a proration guard bypass for `create_preview` when `proration_behavior` is nested inside `subscription_details`, a silent nil return from `parse_lines` on unexpected input shapes, a missing `finch` dependency version pinned lower than the CLAUDE.md recommendation, and an `id_segment?` heuristic in the telemetry path parser that does not include the `ii_` and `il_` prefixes introduced in this phase. The five info items are dead code and missing test coverage notes.

## Warnings

### WR-01: Proration guard bypassed when `proration_behavior` is nested in `subscription_details`

**File:** `lib/lattice_stripe/invoice.ex:722-728` / `lib/lattice_stripe/billing/guards.ex:24-35`

**Issue:** `Billing.Guards.check_proration_required/2` only checks for the top-level key `"proration_behavior"` in `params`. However, the Stripe `create_preview` endpoint accepts `proration_behavior` nested inside a `"subscription_details"` map (the preferred new-style params). The guide's own example shows this nested form:

```elixir
# From guides/invoices.md line 356-361
Invoice.create_preview(client, %{
  "customer" => "cus_xxx",
  "subscription_details" => %{
    "items" => [...],
    "proration_behavior" => "create_prorations"
  }
})
```

When `require_explicit_proration: true` and a caller passes the nested form, the guard fires an error even though `proration_behavior` is present. This is a correctness bug — the guard produces a false positive. For the legacy `upcoming` endpoint the params are flat, so only `create_preview` is affected.

**Fix:** Extend the guard to also accept the nested location:

```elixir
def check_proration_required(%Client{require_explicit_proration: true}, params) do
  has_proration =
    Map.has_key?(params, "proration_behavior") or
      get_in(params, ["subscription_details", "proration_behavior"]) != nil

  if has_proration do
    :ok
  else
    {:error,
     %Error{
       type: :proration_required,
       message:
         "proration_behavior is required when require_explicit_proration is enabled. " <>
           "Provide it as a top-level param or inside \"subscription_details\". " <>
           "Valid values: \"create_prorations\", \"always_invoice\", \"none\""
     }}
  end
end
```

---

### WR-02: `parse_lines/1` silently drops unexpected map shapes

**File:** `lib/lattice_stripe/invoice.ex:1058-1066`

**Issue:** The last clause of `parse_lines/1` returns `nil` for any map that does not have `"object" => "list"`. This means if Stripe ever returns a lines map with a different or missing `"object"` key (e.g., an expanded lines object or a future API shape), the field is silently lost rather than preserved in some form. `nil` is indistinguishable from the case where the field was absent.

```elixir
defp parse_lines(_), do: nil  # swallows any non-list map silently
```

This is a mild correctness issue — callers cannot tell whether `invoice.lines == nil` means "field absent" or "field present but unrecognised". Given the rest of the codebase uses the `extra` map pattern to preserve unknown data, the fallback here is inconsistent.

**Fix:** Preserve the raw map as-is instead of returning `nil`, so the data is not lost:

```elixir
defp parse_lines(other), do: other
```

---

### WR-03: `id_segment?/1` in telemetry path parser missing `ii_` and `il_` prefixes

**File:** `lib/lattice_stripe/telemetry.ex:632-637`

**Issue:** The `id_segment?/1` helper used to classify URL segments as IDs vs. action/resource words lists a set of known Stripe ID prefixes but does not include `ii_` (InvoiceItem IDs) or `il_` (Invoice LineItem IDs), both introduced in this phase. As a result, paths like `/v1/invoiceitems/ii_abc123` may fall through to the heuristic `String.length > 10` check instead of the fast-path prefix check, which is less reliable.

More importantly, any future path like `/v1/invoiceitems/ii_short` (a short ID) would be misclassified as a resource-plural segment rather than an ID, yielding a wrong `operation` in telemetry metadata.

```elixir
known_prefixes = ~w[cus_ pi_ seti_ pm_ re_ cs_ evt_ ch_ in_ sub_ prod_ price_]
# Missing: ii_ (InvoiceItem), il_ (Invoice LineItem)
```

**Fix:** Add the new prefixes to the list:

```elixir
known_prefixes = ~w[cus_ pi_ seti_ pm_ re_ cs_ evt_ ch_ in_ sub_ prod_ price_ ii_ il_]
```

---

### WR-04: Finch version pinned below CLAUDE.md recommendation

**File:** `mix.exs:110`

**Issue:** `mix.exs` declares `{:finch, "~> 0.19"}` but `CLAUDE.md` specifies `~> 0.21`. The lower bound means the package resolves to Finch 0.19.x or 0.20.x in fresh environments, versions that are two minor releases behind the intentional floor. This is an inconsistency between stated intent and declared constraint that will silently resolve to an older version.

**Fix:**

```elixir
{:finch, "~> 0.21"},
```

---

## Info

### IN-01: `create_preview_lines/3` uses POST but should likely use GET

**File:** `lib/lattice_stripe/invoice.ex:777-786`

**Issue:** `create_preview_lines/3` sends `POST /v1/invoices/create_preview/lines`. The [Stripe API docs for create_preview lines](https://docs.stripe.com/api/invoices/create_preview_lines) show this endpoint accepts `GET` (with query params), consistent with how `upcoming_lines/3` uses `GET /v1/invoices/upcoming/lines`. Using `POST` for a list/preview fetch is semantically wrong and may cause Stripe to reject the request or misinterpret it. This deserves verification against the Stripe spec before shipping.

No immediate fix is given here because it depends on the live Stripe API spec — flag for verification.

---

### IN-02: `upcoming!/3` passes wrong argument order to `upcoming/3`

**File:** `lib/lattice_stripe/invoice.ex:693-694`

**Issue:** The bang variant calls `upcoming(params, opts)` instead of `upcoming(client, params, opts)`. However, because `client` is already in scope via the pattern-match `%Client{} = client`, and the pipe `client |> upcoming(params, opts)` is used, this actually resolves correctly in Elixir's pipe semantics. It is not a bug, but the style is inconsistent with every other bang variant in the file, which all use `client |> action(id, params, opts)`. This makes it look like a copy-paste oversight worth a second glance.

```elixir
# Line 693-694 — `client` is piped, so it works but looks wrong
def upcoming!(%Client{} = client, params \\ %{}, opts \\ []),
  do: client |> upcoming(params, opts) |> Resource.unwrap_bang!()

# Compare with create_preview!/3 line 732-733 (same pattern — also correct but unusual)
def create_preview!(%Client{} = client, params \\ %{}, opts \\ []),
  do: client |> create_preview(params, opts) |> Resource.unwrap_bang!()
```

Both are functionally correct via pipe, but the style diverges from `finalize!`, `void!`, `pay!`, etc., which all include the `id` argument explicitly. No fix required, but worth normalizing for readability.

---

### IN-03: No unit tests for `stream!` / `stream_line_items!` on `Invoice` or `InvoiceItem`

**File:** `test/lattice_stripe/invoice_test.exs`, `test/lattice_stripe/invoice_item_test.exs`

**Issue:** The `stream!/3`, `search_stream!/3`, and `stream_line_items!/3` functions in `Invoice`, and `stream!/3` in `InvoiceItem`, have no unit test coverage. Other modules in the codebase (e.g., `Customer`) have stream tests. This is a gap — stream auto-pagination logic is the most likely place for subtle bugs.

**Fix:** Add at least one unit test per stream function that verifies a single-page response is emitted as individual items:

```elixir
test "stream!/2 yields individual Invoice structs" do
  client = test_client()

  expect(LatticeStripe.MockTransport, :request, fn _req ->
    ok_response(list_json([invoice_json()], "/v1/invoices"))
  end)

  results = Invoice.stream!(client, %{}) |> Enum.to_list()
  assert [%Invoice{id: "in_test1234567890"}] = results
end
```

---

### IN-04: `Billing` alias in `invoice.ex` inconsistently references module

**File:** `lib/lattice_stripe/invoice.ex:57`

**Issue:** The alias line is `alias LatticeStripe.{Billing, Client, Error, ...}`, which creates an alias to the `LatticeStripe.Billing` module. The actual guard function is in `LatticeStripe.Billing.Guards`. The call at line 684 is `Billing.Guards.check_proration_required(...)`, which works because `Billing` resolves to `LatticeStripe.Billing` and then `.Guards` navigates to the submodule. This is correct but indirect — aliasing `LatticeStripe.Billing.Guards` directly would be cleaner and match the pattern in other files:

```elixir
# Current (works but indirect)
alias LatticeStripe.{Billing, ...}
# ...
Billing.Guards.check_proration_required(client, params)

# Cleaner (matches guards_test.exs pattern)
alias LatticeStripe.Billing.Guards
# ...
Guards.check_proration_required(client, params)
```

---

### IN-05: Integration tests accept both `:ok` and `:error` from stripe-mock for mutating operations

**File:** `test/integration/invoice_integration_test.exs:90-93`, `test/integration/invoice_item_integration_test.exs:127-130`

**Issue:** Several integration tests assert:

```elixir
assert match?({:ok, %Invoice{}}, result) or match?({:error, %Error{}}, result)
```

This pattern always passes regardless of the outcome, making these tests non-assertive. If `delete/3` or `finalize/3` is broken and always returns `{:error, %Error{}}`, these tests still pass. The comment says "stripe-mock may return an error depending on state," but this should be structured as a `case` that asserts on the specific error reason, not a catch-all OR.

**Fix:** If stripe-mock reliably accepts these operations (it does for draft invoices), assert `{:ok, _}` unconditionally. If stripe-mock is known to be flaky on delete/finalize, skip the test entirely with `@tag :skip` and a comment rather than masking the result.

---

_Reviewed: 2026-04-12_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
