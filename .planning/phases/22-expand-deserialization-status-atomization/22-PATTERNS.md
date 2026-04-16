# Phase 22: Expand Deserialization & Status Atomization - Pattern Map

**Mapped:** 2026-04-16
**Files analyzed:** 15 (2 new, 13 modified categories)
**Analogs found:** 13 / 15

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/lattice_stripe/object_types.ex` | registry/utility | transform | `lib/lattice_stripe/test_helpers/test_clock.ex` (atomize pattern) | partial — new abstraction |
| `test/lattice_stripe/object_types_test.exs` | test | transform | `test/lattice_stripe/account/capability_test.exs` | role-match |
| `lib/lattice_stripe/payment_intent.ex` (modify) | resource | request-response | `lib/lattice_stripe/invoice.ex` | exact |
| `lib/lattice_stripe/subscription.ex` (modify) | resource | request-response | `lib/lattice_stripe/invoice.ex` | exact |
| `lib/lattice_stripe/subscription_schedule.ex` (modify) | resource | request-response | `lib/lattice_stripe/subscription.ex` | exact |
| `lib/lattice_stripe/payout.ex` (modify) | resource | request-response | `lib/lattice_stripe/invoice.ex` | exact |
| `lib/lattice_stripe/refund.ex` (modify) | resource | request-response | `lib/lattice_stripe/invoice.ex` | exact |
| `lib/lattice_stripe/setup_intent.ex` (modify) | resource | request-response | `lib/lattice_stripe/invoice.ex` | exact |
| `lib/lattice_stripe/charge.ex` (modify) | resource | request-response | `lib/lattice_stripe/invoice.ex` | exact |
| `lib/lattice_stripe/bank_account.ex` (modify) | resource | request-response | `lib/lattice_stripe/invoice.ex` | exact |
| `lib/lattice_stripe/balance_transaction.ex` (modify) | resource | request-response | `lib/lattice_stripe/invoice.ex` | exact |
| `lib/lattice_stripe/checkout/session.ex` (modify) | resource | request-response | `lib/lattice_stripe/invoice.ex` | exact |
| `lib/lattice_stripe/billing/meter.ex` (modify) | resource | request-response | `lib/lattice_stripe/test_helpers/test_clock.ex` | exact |
| `lib/lattice_stripe/account/capability.ex` (modify) | sub-struct | transform | `lib/lattice_stripe/test_helpers/test_clock.ex` | exact |
| `CHANGELOG.md` (modify) | documentation | — | existing CHANGELOG entries | role-match |

---

## Pattern Assignments

### `lib/lattice_stripe/object_types.ex` (NEW registry module)

**No direct analog** — this is a new abstraction. The closest structural reference is the compile-time attribute pattern used throughout the codebase (e.g., `@known_fields`, `@known_statuses` in `account/capability.ex`).

**Module shell pattern** (from `lib/lattice_stripe/account/capability.ex` lines 1-3):
```elixir
defmodule LatticeStripe.Account.Capability do
  @moduledoc """
  ...
  """
  @known_statuses ~w(active inactive pending unrequested disabled)
```

**Compile-time attribute map pattern** — copy this approach for `@object_map`:
```elixir
# lib/lattice_stripe/account/capability.ex lines 50-56
@known_statuses ~w(active inactive pending unrequested disabled)

# Ensure atoms pre-exist in the atom table so String.to_existing_atom/1 is safe.
@known_status_atoms [:active, :inactive, :pending, :unrequested, :disabled]
@doc false
def known_status_atoms, do: @known_status_atoms
```

**Recommended implementation** (from RESEARCH.md Pattern 1 — no codebase analog, use as-is):
```elixir
defmodule LatticeStripe.ObjectTypes do
  @moduledoc false

  @object_map %{
    "account"                => LatticeStripe.Account,
    "account_link"           => LatticeStripe.AccountLink,
    "balance"                => LatticeStripe.Balance,
    "balance_transaction"    => LatticeStripe.BalanceTransaction,
    "bank_account"           => LatticeStripe.BankAccount,
    "card"                   => LatticeStripe.Card,
    "charge"                 => LatticeStripe.Charge,
    "coupon"                 => LatticeStripe.Coupon,
    "customer"               => LatticeStripe.Customer,
    "event"                  => LatticeStripe.Event,
    "invoice"                => LatticeStripe.Invoice,
    "invoiceitem"            => LatticeStripe.InvoiceItem,
    "login_link"             => LatticeStripe.LoginLink,
    "payment_intent"         => LatticeStripe.PaymentIntent,
    "payment_method"         => LatticeStripe.PaymentMethod,
    "payout"                 => LatticeStripe.Payout,
    "price"                  => LatticeStripe.Price,
    "product"                => LatticeStripe.Product,
    "promotion_code"         => LatticeStripe.PromotionCode,
    "refund"                 => LatticeStripe.Refund,
    "setup_intent"           => LatticeStripe.SetupIntent,
    "subscription"           => LatticeStripe.Subscription,
    "subscription_item"      => LatticeStripe.SubscriptionItem,
    "subscription_schedule"  => LatticeStripe.SubscriptionSchedule,
    "transfer"               => LatticeStripe.Transfer,
    "transfer_reversal"      => LatticeStripe.TransferReversal,
    "billing.meter"          => LatticeStripe.Billing.Meter,
    "billing_portal.session" => LatticeStripe.BillingPortal.Session,
    "checkout.session"       => LatticeStripe.Checkout.Session,
    "test_helpers.test_clock" => LatticeStripe.TestHelpers.TestClock,
    "line_item"              => LatticeStripe.Invoice.LineItem
  }

  @spec maybe_deserialize(map() | String.t() | nil) :: struct() | map() | String.t() | nil
  def maybe_deserialize(nil), do: nil
  def maybe_deserialize(val) when is_binary(val), do: val

  def maybe_deserialize(%{"object" => object_type} = map) do
    case Map.fetch(@object_map, object_type) do
      {:ok, module} -> module.from_map(map)
      :error        -> map
    end
  end

  def maybe_deserialize(map) when is_map(map), do: map
end
```

**Critical note:** `"list"` is NOT an entry — `LatticeStripe.List` is an internal wrapper. Verify `"billing.meter"` string against stripe-mock before committing.

---

### `test/lattice_stripe/object_types_test.exs` (NEW test file)

**Analog:** `test/lattice_stripe/account/capability_test.exs`

**Test module header pattern** (lines 1-10):
```elixir
defmodule LatticeStripe.Account.CapabilityTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Account.Capability
  alias LatticeStripe.Test.Fixtures.Account, as: AccountFixtures

  describe "cast/1" do
    test "returns nil for nil input" do
      assert Capability.cast(nil) == nil
    end
```

**Test structure to replicate** — one `describe` block per public function, covering: nil passthrough, string passthrough, known dispatch to struct, unknown object fallthrough, map without `"object"` key:
```elixir
defmodule LatticeStripe.ObjectTypesTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.{Customer, ObjectTypes, PaymentIntent}

  describe "maybe_deserialize/1" do
    test "returns nil for nil input" do
      assert ObjectTypes.maybe_deserialize(nil) == nil
    end

    test "returns string IDs unchanged" do
      assert ObjectTypes.maybe_deserialize("cus_123") == "cus_123"
    end

    test "dispatches customer map to Customer.from_map/1" do
      map = %{"object" => "customer", "id" => "cus_123", "email" => "test@example.com"}
      assert %Customer{id: "cus_123"} = ObjectTypes.maybe_deserialize(map)
    end

    test "dispatches payment_intent map to PaymentIntent.from_map/1" do
      map = %{"object" => "payment_intent", "id" => "pi_123", "amount" => 2000, "currency" => "usd"}
      assert %PaymentIntent{id: "pi_123"} = ObjectTypes.maybe_deserialize(map)
    end

    test "returns unknown object types as raw map" do
      map = %{"object" => "unknown_future_type", "id" => "foo_123"}
      assert ObjectTypes.maybe_deserialize(map) == map
    end

    test "returns maps without 'object' key as raw map" do
      map = %{"id" => "foo_123", "data" => "some_value"}
      assert ObjectTypes.maybe_deserialize(map) == map
    end
  end
end
```

---

### Resource modules needing `atomize_status/1` added (D-03 sweep)

**Primary analog:** `lib/lattice_stripe/invoice.ex` lines 1023-1029 and 927-998

#### Atomizer pattern to copy (lines 1023-1029):
```elixir
# lib/lattice_stripe/invoice.ex lines 1023-1029
defp atomize_status("draft"), do: :draft
defp atomize_status("open"), do: :open
defp atomize_status("paid"), do: :paid
defp atomize_status("void"), do: :void
defp atomize_status("uncollectible"), do: :uncollectible
defp atomize_status(other), do: other
```

**Rule:** Final clause is always `defp atomize_status(other), do: other` — NO type guard on `other`. This covers `nil` and unknown strings alike. Do NOT add `when is_binary(other)` on the final clause (TestClock has this as a two-clause fallthrough; the simpler Invoice single-clause is correct).

#### `from_map/1` body integration pattern (line 998):
```elixir
# lib/lattice_stripe/invoice.ex line 998
status: atomize_status(known["status"]),
```

#### `Map.split/2` variant of `from_map/1` (preferred for modules being touched):
```elixir
# lib/lattice_stripe/invoice.ex lines 927-928 / subscription.ex lines 453-454
def from_map(map) when is_map(map) do
  {known, extra} = Map.split(map, @known_fields)
  %__MODULE__{
    ...
    status: atomize_status(known["status"]),
    ...
    extra: extra
  }
end
```

**When touching a module that currently uses `Map.drop` instead of `Map.split/2`** (e.g. `Payout`, older pattern at line 422), prefer upgrading to `Map.split/2` to match the current Invoice/Subscription pattern. This is at Claude's discretion per CONTEXT.md.

---

### `lib/lattice_stripe/payment_intent.ex` (modify — status atomizer + expand guards)

**Analog:** `lib/lattice_stripe/invoice.ex`

**Current `from_map/1` structure** (payment_intent.ex — uses `map["field"]` directly, not `Map.split`):
```elixir
# lib/lattice_stripe/payment_intent.ex — from_map uses map["field"] not known["field"]
# When modifying, upgrade to Map.split/2 pattern per Invoice precedent.
```

**Atomizer to add** (after `from_map/1`, before any private parsers):
```elixir
# PaymentIntent status values (Stripe docs)
defp atomize_status("requires_payment_method"), do: :requires_payment_method
defp atomize_status("requires_confirmation"),   do: :requires_confirmation
defp atomize_status("requires_action"),         do: :requires_action
defp atomize_status("processing"),              do: :processing
defp atomize_status("requires_capture"),        do: :requires_capture
defp atomize_status("canceled"),                do: :canceled
defp atomize_status("succeeded"),               do: :succeeded
defp atomize_status(other),                     do: other
```

**Expand guard for expandable fields** (D-02 pattern):
```elixir
# Add alias at top of module with existing aliases:
alias LatticeStripe.ObjectTypes

# In from_map/1 struct literal — replace bare string assignment:
# BEFORE:
customer: known["customer"],
# AFTER:
customer:
  if is_map(known["customer"]),
    do: ObjectTypes.maybe_deserialize(known["customer"]),
    else: known["customer"],
```

**Typespec update for expandable fields** (lines 148, 157, 163):
```elixir
# BEFORE:
customer: String.t() | nil,
latest_charge: String.t() | nil,
payment_method: String.t() | nil,

# AFTER:
customer: LatticeStripe.Customer.t() | String.t() | nil,
latest_charge: LatticeStripe.Charge.t() | String.t() | nil,
payment_method: LatticeStripe.PaymentMethod.t() | String.t() | nil,
```

---

### `lib/lattice_stripe/subscription.ex` (modify — status + collection_method atomizers + expand guards)

**Analog:** `lib/lattice_stripe/invoice.ex` (exact match — uses `Map.split/2` already)

**Already uses `Map.split/2`** (lines 453-454) — no upgrade needed.

**Atomizers to add:**
```elixir
# Subscription status values
defp atomize_status("incomplete"),          do: :incomplete
defp atomize_status("incomplete_expired"),  do: :incomplete_expired
defp atomize_status("trialing"),            do: :trialing
defp atomize_status("active"),              do: :active
defp atomize_status("past_due"),            do: :past_due
defp atomize_status("canceled"),            do: :canceled
defp atomize_status("unpaid"),              do: :unpaid
defp atomize_status("paused"),              do: :paused
defp atomize_status(other),                do: other

# Subscription collection_method values (mirrors Invoice precedent)
defp atomize_collection_method("charge_automatically"), do: :charge_automatically
defp atomize_collection_method("send_invoice"),         do: :send_invoice
defp atomize_collection_method(other),                  do: other
```

**In `from_map/1` body** (lines 470, 498):
```elixir
collection_method: atomize_collection_method(known["collection_method"]),
status: atomize_status(known["status"]),
```

**Expand guards** (for customer, default_payment_method, latest_invoice, pending_setup_intent, schedule):
```elixir
customer:
  if is_map(known["customer"]),
    do: ObjectTypes.maybe_deserialize(known["customer"]),
    else: known["customer"],
```

---

### `lib/lattice_stripe/billing/meter.ex` (modify — auto-atomize + deprecate `status_atom/1`)

**Analog:** `lib/lattice_stripe/test_helpers/test_clock.ex` (exact — already has `atomize_status/1` in `from_map/1`)

**TestClock's pattern** (lines 150-163):
```elixir
# lib/lattice_stripe/test_helpers/test_clock.ex lines 141-163
def from_map(map) when is_map(map) do
  %__MODULE__{
    ...
    status: atomize_status(map["status"]),
    ...
  }
end

defp atomize_status("ready"), do: :ready
defp atomize_status("advancing"), do: :advancing
defp atomize_status("internal_failure"), do: :internal_failure
defp atomize_status(nil), do: nil
defp atomize_status(other) when is_binary(other), do: other
defp atomize_status(other), do: other
```

**For Meter** — apply same structure but with `active`/`inactive` values. Change `status: map["status"]` (line 262) to `status: atomize_status(map["status"])`.

**Deprecate public `status_atom/1`** (current lines 282-284):
```elixir
# BEFORE (lines 282-284 in billing/meter.ex):
@spec status_atom(String.t() | nil) :: :active | :inactive | :unknown
def status_atom(nil), do: :unknown
def status_atom(s) when s in @known_statuses, do: String.to_existing_atom(s)
def status_atom(_), do: :unknown

# AFTER — keep working but emit deprecation warning:
@deprecated "status is now automatically atomized in from_map/1. Access struct.status directly."
@spec status_atom(t() | String.t() | nil) :: atom()
def status_atom(%__MODULE__{status: s}), do: s   # Already an atom after from_map/1
def status_atom(nil), do: nil
def status_atom(s) when is_atom(s), do: s
def status_atom(s), do: atomize_status(s)
```

---

### `lib/lattice_stripe/account/capability.ex` (modify — auto-atomize + deprecate `status_atom/1`)

**Analog:** `lib/lattice_stripe/billing/meter.ex` (same public `status_atom/1` deprecation pattern)

**Current `cast/1`** (lines 36-48) uses `Map.split/2` already. Add atomize call:
```elixir
# BEFORE (line 41):
status: known["status"],

# AFTER:
status: atomize_status(known["status"]),
```

**Add private atomizer** (after `cast/1`):
```elixir
defp atomize_status("active"),       do: :active
defp atomize_status("inactive"),     do: :inactive
defp atomize_status("pending"),      do: :pending
defp atomize_status("unrequested"),  do: :unrequested
defp atomize_status("disabled"),     do: :disabled
defp atomize_status(other),          do: other
```

**Deprecate public `status_atom/1`** (current lines 64-69) — same `@deprecated` pattern as Meter above.

**Note:** `cast/1` (not `from_map/1`) is the entry point here — that is correct. `Account.Capability` is a sub-struct, not a top-level resource; its deserialization entry point is `cast/1`. Do NOT rename to `from_map/1` unless `Account.Capability` ends up in the ObjectTypes registry (it should NOT — it's not an expand target).

---

### `lib/lattice_stripe/payout.ex` (modify — status/type/method atomizers + expand guards)

**Analog:** `lib/lattice_stripe/invoice.ex`

**Current `from_map/1`** (lines 394-424) uses `Map.drop` directly — upgrade to `Map.split/2` when touching.

**Already has `String.t() | map() | nil` type** (lines 147-152) — this is the existing polymorphic type that predates Phase 22. The D-02 pattern upgrades these to `ObjectTypes.maybe_deserialize/1` dispatch.

**Expand guard for existing polymorphic fields**:
```elixir
# BEFORE (lines 402-404):
balance_transaction: map["balance_transaction"],
destination: map["destination"],
failure_balance_transaction: map["failure_balance_transaction"],

# AFTER:
balance_transaction:
  if is_map(known["balance_transaction"]),
    do: ObjectTypes.maybe_deserialize(known["balance_transaction"]),
    else: known["balance_transaction"],
destination:
  if is_map(known["destination"]),
    do: ObjectTypes.maybe_deserialize(known["destination"]),
    else: known["destination"],
failure_balance_transaction:
  if is_map(known["failure_balance_transaction"]),
    do: ObjectTypes.maybe_deserialize(known["failure_balance_transaction"]),
    else: known["failure_balance_transaction"],
```

**Atomizers to add:**
```elixir
defp atomize_status("paid"),       do: :paid
defp atomize_status("pending"),    do: :pending
defp atomize_status("in_transit"), do: :in_transit
defp atomize_status("canceled"),   do: :canceled
defp atomize_status("failed"),     do: :failed
defp atomize_status(other),        do: other

defp atomize_type("bank_account"), do: :bank_account
defp atomize_type("card"),         do: :card
defp atomize_type(other),          do: other

defp atomize_method("standard"), do: :standard
defp atomize_method("instant"),  do: :instant
defp atomize_method(other),      do: other
```

**Typespec update** (lines 147-152):
```elixir
# BEFORE:
balance_transaction: String.t() | map() | nil,
destination: String.t() | map() | nil,
failure_balance_transaction: String.t() | map() | nil,
status: String.t() | nil,
type: String.t() | nil,

# AFTER:
balance_transaction: LatticeStripe.BalanceTransaction.t() | String.t() | nil,
destination: LatticeStripe.BankAccount.t() | LatticeStripe.Card.t() | String.t() | nil,
failure_balance_transaction: LatticeStripe.BalanceTransaction.t() | String.t() | nil,
status: atom() | String.t() | nil,
type: atom() | String.t() | nil,
```

---

### All other resource modules with `atomize_status/1` needed

The following modules follow the same pattern as the Invoice reference. The planner can apply the pattern mechanically: add `defp atomize_status/1` after `from_map/1`, update the `status:` field in the struct literal, add expand guards for expandable fields, update typespecs.

| Module | Status Values | Additional Atomizers |
|--------|--------------|----------------------|
| `lib/lattice_stripe/subscription_schedule.ex` | `not_started`, `active`, `completed`, `released`, `canceled` | `atomize_end_behavior/1`: `release`, `cancel` |
| `lib/lattice_stripe/refund.ex` | `pending`, `requires_action`, `succeeded`, `failed`, `canceled` | — |
| `lib/lattice_stripe/setup_intent.ex` | `requires_payment_method`, `requires_confirmation`, `requires_action`, `processing`, `canceled`, `succeeded` | `atomize_usage/1`: `off_session`, `on_session` |
| `lib/lattice_stripe/charge.ex` | `succeeded`, `pending`, `failed` | — |
| `lib/lattice_stripe/bank_account.ex` | `new`, `validated`, `verified`, `verification_failed`, `errored` | — |
| `lib/lattice_stripe/balance_transaction.ex` | `available`, `pending` | `atomize_type/1`: 30+ values (use fallthrough heavily) |
| `lib/lattice_stripe/checkout/session.ex` | `open`, `complete`, `expired` | `atomize_mode/1`: `payment`, `setup`, `subscription`; `atomize_payment_status/1`: `paid`, `unpaid`, `no_payment_required` |

**For all of the above, use Invoice atomizer template** (lines 1024-1029):
```elixir
defp atomize_status("<value_1>"), do: :<value_1>
# ... one clause per documented value ...
defp atomize_status(other), do: other
```

---

## Shared Patterns

### `from_map/1` Guard (nil safety)

**Source:** `lib/lattice_stripe/invoice.ex` lines 924-925 and `lib/lattice_stripe/payout.ex` lines 391-392

**Apply to:** All resource modules

```elixir
@spec from_map(map() | nil) :: t() | nil
def from_map(nil), do: nil

def from_map(map) when is_map(map) do
  {known, extra} = Map.split(map, @known_fields)
  %__MODULE__{
    ...
  }
end
```

The nil clause must always precede the `when is_map(map)` clause.

---

### Map.split/2 vs Map.drop Pattern

**Source:** `lib/lattice_stripe/invoice.ex` line 928 (preferred), `lib/lattice_stripe/payout.ex` line 422 (legacy)

**Apply to:** All resource modules being touched

```elixir
# PREFERRED (Map.split/2) — Invoice, Subscription:
{known, extra} = Map.split(map, @known_fields)
# Access as known["field_name"]
# extra is already separated

# LEGACY (Map.drop) — Payout, Meter, older modules:
extra: Map.drop(map, @known_fields)
# Access as map["field_name"]
```

When a module is being modified for Phase 22, upgrade from `Map.drop` to `Map.split/2`.

---

### ObjectTypes Expand Guard

**Source:** CONTEXT.md D-02 / RESEARCH.md Pattern 2 (no codebase analog — new pattern)

**Apply to:** Every expandable field in every modified resource module

```elixir
# Add at top of module with existing aliases:
alias LatticeStripe.ObjectTypes

# In from_map/1 struct literal — for each expandable field:
customer:
  if is_map(known["customer"]),
    do: ObjectTypes.maybe_deserialize(known["customer"]),
    else: known["customer"],
```

This replaces the previous raw passthrough `customer: known["customer"]`.

---

### Atomizer Placement Convention

**Source:** `lib/lattice_stripe/invoice.ex` lines 1019-1050

**Apply to:** All resource modules with atomizers

```elixir
# ---------------------------------------------------------------------------
# Private: atomization helpers
# ---------------------------------------------------------------------------

defp atomize_status("<value>"), do: :<value>
# ... whitelist clauses ...
defp atomize_status(other), do: other

defp atomize_<field>("<value>"), do: :<value>
# ... whitelist clauses ...
defp atomize_<field>(other), do: other
```

Section header comment `# Private: atomization helpers` should be placed immediately after `from_map/1` close. Atomizers come before any other private helpers (e.g., `parse_lines/1`).

---

### Unit Test: Atomizer Coverage Pattern

**Source:** `test/lattice_stripe/invoice_test.exs` lines 82-158

**Apply to:** Every resource module test file after atomizer is added

```elixir
describe "from_map/1" do
  # ... existing tests ...

  test "atomizes status: <value>" do
    result = Module.from_map(fixture_json(%{"status" => "<value>"}))
    assert result.status == :<value>
  end

  # One test per documented status value

  test "passes through unknown status as string" do
    result = Module.from_map(fixture_json(%{"status" => "future_unknown_status"}))
    assert result.status == "future_unknown_status"
  end

  test "handles nil status" do
    result = Module.from_map(fixture_json(%{"status" => nil}))
    assert result.status == nil
  end
end
```

---

### Unit Test: Expand Guard Coverage Pattern

**Source:** `test/lattice_stripe/invoice_test.exs` structure (no expand tests yet — new pattern)

**Apply to:** Resource module test files for modules with expanded fields

```elixir
describe "from_map/1 expand dispatch" do
  test "customer field: keeps string ID when not expanded" do
    result = Module.from_map(fixture_json(%{"customer" => "cus_123"}))
    assert result.customer == "cus_123"
  end

  test "customer field: deserializes to %Customer{} when expanded" do
    expanded_customer = %{"object" => "customer", "id" => "cus_123", "email" => "x@y.com"}
    result = Module.from_map(fixture_json(%{"customer" => expanded_customer}))
    assert %LatticeStripe.Customer{id: "cus_123"} = result.customer
  end

  test "customer field: handles nil" do
    result = Module.from_map(fixture_json(%{"customer" => nil}))
    assert result.customer == nil
  end
end
```

---

### Integration Test: Expand End-to-End

**Source:** `test/integration/payment_intent_integration_test.exs` lines 1-32 (structure reference)

**Apply to:** `test/integration/payment_intent_integration_test.exs` (add expand test)

```elixir
# lib/lattice_stripe/test/integration/payment_intent_integration_test.exs
# Add to existing integration test file — do NOT create new file
test "retrieve/3 with expand: [\"customer\"] returns string or %Customer{}", %{client: client} do
  {:ok, created} = PaymentIntent.create(client, %{"amount" => "2000", "currency" => "usd"})
  {:ok, pi} = PaymentIntent.retrieve(client, created.id, expand: ["customer"])

  # stripe-mock may or may not expand; both outcomes are valid
  case pi.customer do
    %LatticeStripe.Customer{} -> :ok        # expanded path
    customer_id when is_binary(customer_id) -> :ok   # unexpanded path
    nil -> :ok                               # no customer
  end
end
```

---

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/lattice_stripe/object_types.ex` | registry | transform | No central dispatch registry exists in the codebase yet; this is a new pattern. Use RESEARCH.md Pattern 1 directly. |

---

## Metadata

**Analog search scope:** `lib/lattice_stripe/`, `test/lattice_stripe/`, `test/integration/`
**Files scanned:** ~20 source files, ~15 test files
**Pattern extraction date:** 2026-04-16

**Key patterns confirmed in codebase:**
- `Map.split/2` + `known["field"]` is the current idiomatic `from_map/1` pattern (Invoice, Subscription — prefer over `Map.drop`)
- `defp atomize_*/1` whitelist with bare `other` catch-all is proven (Invoice, Price, Coupon, TestClock, Product)
- `@moduledoc false` on internal/utility modules (`account/capability.ex` uses standard `@moduledoc` — but registry should use `@moduledoc false` as it's not public API)
- `use ExUnit.Case, async: true` is universal across all unit test files
- Integration tests use `@moduletag :integration` + stripe-mock connectivity check in `setup_all`
- `from_map(nil), do: nil` nil-guard clause is universal across all resource modules
