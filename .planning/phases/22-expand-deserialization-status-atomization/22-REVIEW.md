---
phase: 22-expand-deserialization-status-atomization
reviewed: 2026-04-16T12:00:00Z
depth: standard
files_reviewed: 36
files_reviewed_list:
  - lib/lattice_stripe/object_types.ex
  - lib/lattice_stripe/payment_intent.ex
  - lib/lattice_stripe/subscription.ex
  - lib/lattice_stripe/charge.ex
  - lib/lattice_stripe/refund.ex
  - lib/lattice_stripe/setup_intent.ex
  - lib/lattice_stripe/subscription_schedule.ex
  - lib/lattice_stripe/payout.ex
  - lib/lattice_stripe/balance_transaction.ex
  - lib/lattice_stripe/bank_account.ex
  - lib/lattice_stripe/checkout/session.ex
  - lib/lattice_stripe/billing/meter.ex
  - lib/lattice_stripe/account/capability.ex
  - lib/lattice_stripe/invoice.ex
  - lib/lattice_stripe/invoice_item.ex
  - lib/lattice_stripe/subscription_item.ex
  - lib/lattice_stripe/card.ex
  - lib/lattice_stripe/payment_method.ex
  - lib/lattice_stripe/promotion_code.ex
  - lib/lattice_stripe/transfer.ex
  - lib/lattice_stripe/transfer_reversal.ex
  - test/lattice_stripe/object_types_test.exs
  - test/lattice_stripe/payment_intent_test.exs
  - test/lattice_stripe/subscription_test.exs
  - test/lattice_stripe/charge_test.exs
  - test/lattice_stripe/refund_test.exs
  - test/lattice_stripe/setup_intent_test.exs
  - test/lattice_stripe/subscription_schedule_test.exs
  - test/lattice_stripe/payout_test.exs
  - test/lattice_stripe/balance_transaction_test.exs
  - test/lattice_stripe/bank_account_test.exs
  - test/lattice_stripe/checkout/session_test.exs
  - test/lattice_stripe/billing/meter_test.exs
  - test/lattice_stripe/account/capability_test.exs
  - test/lattice_stripe/invoice_test.exs
  - test/lattice_stripe/invoice_item_test.exs
findings:
  critical: 1
  warning: 3
  info: 3
  total: 7
status: issues_found
---

# Phase 22: Code Review Report

**Reviewed:** 2026-04-16T12:00:00Z
**Depth:** standard
**Files Reviewed:** 36
**Status:** issues_found

## Summary

This review covers the current state of all resource modules, ObjectTypes, and their tests in preparation for Phase 22 (expand deserialization and status atomization). The CHANGELOG `[Unreleased]` section already documents expand deserialization and status atomization as shipped features, but the source code has NOT yet implemented these changes for most modules. This is the primary critical finding -- the CHANGELOG is ahead of the code. Beyond that, there is one copy-paste error in an error message, an inconsistency in nil-handling between two status_atom helpers, and several minor code quality items.

## Critical Issues

### CR-01: CHANGELOG [Unreleased] describes unimplemented features

**File:** `CHANGELOG.md:9-38`
**Issue:** The `[Unreleased]` section documents two major behavioral changes -- expand deserialization and status atomization -- as completed. However, examining the source code reveals these are NOT yet implemented in most modules:

**Status atomization:** Only `Invoice.from_map/1` atomizes status fields (lines 1036-1041). The following modules listed in the CHANGELOG as affected still store `status` as raw strings in `from_map/1`: PaymentIntent (line 612), Subscription (line 498), Charge (line 292), Refund (line 388), SetupIntent (line 499), SubscriptionSchedule (line 404), Payout (line 419), BalanceTransaction (line 199), BankAccount (line 107), Checkout.Session (line 645).

**Expand deserialization:** Only Invoice, InvoiceItem, Card, SubscriptionItem, Transfer, TransferReversal, and PromotionCode call `ObjectTypes.maybe_deserialize/1` for expandable fields. PaymentIntent, Subscription, Charge, Refund, SetupIntent, SubscriptionSchedule, Payout, BalanceTransaction, BankAccount, and Checkout.Session do NOT -- their `from_map/1` functions pass expandable fields (e.g., `customer`, `payment_method`, `latest_charge`) through as raw values without dispatching through ObjectTypes.

The CHANGELOG also declares `Billing.Meter.status_atom/1` and `Account.Capability.status_atom/1` as deprecated, but no `@deprecated` annotations exist in the source.

**Fix:** Either (a) remove the `[Unreleased]` section entries until the Phase 22 implementation tasks are complete, or (b) implement the changes described. Since Phase 22 plans exist for this work, option (a) is the correct path -- write the CHANGELOG entries only after the code ships. The current state risks a release where the CHANGELOG promises behavior the code does not deliver.

## Warnings

### WR-01: PaymentMethod.stream!/3 error message references wrong function name

**File:** `lib/lattice_stripe/payment_method.ex:437-439`
**Issue:** The `require_param!` error message inside `stream!/3` says `PaymentMethod.list/3 requires a "customer" key` but it should say `PaymentMethod.stream!/3`. This misleads callers who hit the error from `stream!/3` into thinking the issue is with `list/3`.
**Fix:**
```elixir
Resource.require_param!(
  params,
  "customer",
  ~s|PaymentMethod.stream!/3 requires a "customer" key in params. | <>
    ~s|Stripe requires customer-scoped listing. | <>
    ~s|Example: PaymentMethod.stream!(client, %{"customer" => "cus_123"})|
)
```

### WR-02: Inconsistent nil handling between Capability.status_atom/1 and Meter.status_atom/1

**File:** `lib/lattice_stripe/account/capability.ex:67` and `lib/lattice_stripe/billing/meter.ex:282`
**Issue:** `Capability.status_atom(nil)` returns `nil` (line 67), but `Meter.status_atom(nil)` returns `:unknown` (line 282). These two functions implement the same pattern (documented in Phase 17 D-02), but their nil-handling semantics diverge. Callers who pattern-match on the return value will need different logic depending on which module they use. Since the CHANGELOG intends to deprecate both in favor of direct struct access, this is lower severity, but it will confuse anyone who uses both before deprecation.
**Fix:** Align both to the same convention. Since `:unknown` is more explicit about "we don't know" vs `nil` meaning "absent," consider updating `Capability.status_atom(nil)` to return `:unknown`. Alternatively, document the divergence explicitly in both `@doc` strings.

### WR-03: Billing.Meter does not set default object value in from_map/1

**File:** `lib/lattice_stripe/billing/meter.ex:259`
**Issue:** Every other resource module defaults the `object` field when it is missing from the input map (e.g., `object: map["object"] || "payment_intent"`). `Meter.from_map/1` at line 259 uses `object: map["object"]` without a fallback. Additionally, `Meter.defstruct` at line 66 sets `:object` as a bare `nil`-defaulting field (`:object`) rather than `object: "billing.meter"`. This means `Meter.from_map(%{"id" => "mtr_x"})` produces a struct with `object: nil`, while `PaymentIntent.from_map(%{"id" => "pi_x"})` produces `object: "payment_intent"`. This inconsistency could cause `ObjectTypes.maybe_deserialize/1` to fail to dispatch correctly if a Meter struct is round-tripped through serialization/deserialization.
**Fix:**
```elixir
# In defstruct, change:
:object,
# To:
object: "billing.meter",

# In from_map/1, change:
object: map["object"],
# To:
object: map["object"] || "billing.meter",
```

## Info

### IN-01: Billing.Meter uses ~w() while all other modules use ~w[]

**File:** `lib/lattice_stripe/billing/meter.ex:43-45`
**Issue:** `@known_fields` and `@known_statuses` use `~w(...)` (parentheses delimiter) while every other resource module uses `~w[...]` (bracket delimiter). This is a cosmetic inconsistency with no behavioral difference, but it breaks the visual pattern across the codebase.
**Fix:** Change to `~w[...]` for consistency with the rest of the codebase.

### IN-02: Account.Capability uses atom-keyed @known_fields while all other modules use string-keyed

**File:** `lib/lattice_stripe/account/capability.ex:21`
**Issue:** `Capability` defines `@known_fields ~w(status requested requested_at requirements disabled_reason)a` (note the `a` suffix producing atoms), then converts them to strings in `cast/1` via `Enum.map(@known_fields, &Atom.to_string/1)`. All other modules define `@known_fields` as a string list directly with `~w[...]` (no `a` suffix). This works correctly but adds an unnecessary conversion step and diverges from the established pattern.
**Fix:** Not blocking -- the code works. If refactoring, change to string-keyed `@known_fields ~w[status requested requested_at requirements disabled_reason]` and adjust `cast/1` to use them directly, matching the pattern in all other resource modules.

### IN-03: PromotionCode bang variants use abbreviated parameter names

**File:** `lib/lattice_stripe/promotion_code.ex:152-160`
**Issue:** The bang variants (`create!`, `retrieve!`, `update!`, `list!`) use abbreviated parameter names (`c`, `p`, `o`, `id`) instead of the full names (`client`, `params`, `opts`) used in every other resource module. This is a cosmetic consistency issue only.
**Fix:** Expand abbreviated names to match the codebase convention:
```elixir
def create!(%Client{} = client, params \\ %{}, opts \\ []),
  do: create(client, params, opts) |> Resource.unwrap_bang!()
```

---

_Reviewed: 2026-04-16T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
