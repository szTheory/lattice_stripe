# Phase 22: Expand Deserialization & Status Atomization - Research

**Researched:** 2026-04-16
**Domain:** Elixir struct deserialization, Stripe expand semantics, enum atomization
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01: Central ObjectTypes Registry (Expand Dispatch)**
A single `LatticeStripe.ObjectTypes` module with a compile-time `@object_map` mapping Stripe's `"object"` type strings to their LatticeStripe modules. Called from a new `Expand.maybe_deserialize/1` helper that each resource's `from_map/1` delegates to for expandable fields. When registry has no match, preserve the raw map.

**D-02: Always Auto-Deserialize Expanded Fields (Type Safety)**
In each resource's `from_map/1`, expandable fields use an `is_map(val)` guard to dispatch via the ObjectTypes registry. If the field is a string ID, it's kept as-is. Type specs become union types: `customer: Customer.t() | String.t() | nil`. CHANGELOG migration note required.

**D-03: Auto-Atomize All Status/Enum Fields (Atomization Strategy)**
Private `defp atomize_status/1` (and variant atomizers) in each resource's `from_map/1`. Unknown values fall through as raw strings. Scope: 9 modules need new status atomizers (PaymentIntent, Subscription, SubscriptionSchedule, Payout, Refund, SetupIntent, Charge, BankAccount, BalanceTransaction). 2 modules need consistency fix (Capability, Meter — deprecate public `status_atom/1`). Non-status enum fields also swept where Stripe documents a finite set.

**D-04: Response-Driven Dot-Path Expand (No Parsing Needed)**
Dot-path expand (`expand: ["data.customer"]`) works automatically — Stripe expands fields server-side, the `is_map` guard detects them, the ObjectTypes registry deserializes them. No client-side parsing needed.

### Claude's Discretion
- Order of module sweep (which resource modules to update first)
- Whether to update all 84+ modules in one plan or split into batches
- Exact set of non-status enum fields to atomize (use Stripe docs as source of truth for "finite documented values")
- Whether `Expand.maybe_deserialize/1` is a public or private function
- Test structure for the ObjectTypes registry (unit tests for registry + integration tests for end-to-end expand)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EXPD-01 | Developer can pass `expand: ["customer"]` and receive a typed `%Customer{}` struct instead of a string ID | D-01 ObjectTypes registry + D-02 `is_map` guard in `from_map/1`; auto-dispatch via `Expand.maybe_deserialize/1` |
| EXPD-02 | Developer can use dot-path expand syntax (`expand: ["data.customer"]`) to expand nested list items | D-04 response-driven: Stripe expands server-side, `is_map` guard picks it up automatically in each module's `from_map/1` |
| EXPD-03 | All status-like string fields across all 84+ resource modules have consistent `_atom` converter functions | D-03 sweep: 9 modules get new `atomize_status/1`; 2 modules (Capability, Meter) updated for auto-atomize consistency; enum fields also swept |
| EXPD-04 | Expanded fields use union types (`Customer.t() \| String.t()`) in `@type t()` specs with CHANGELOG migration note | D-02 typespec update: change `String.t() \| nil` to `Module.t() \| String.t() \| nil` for each expandable field; CHANGELOG entry |
</phase_requirements>

---

## Summary

Phase 22 is a systematic sweep across all LatticeStripe resource modules with three coordinated changes: (1) a new ObjectTypes registry that maps Stripe `"object"` type strings to their Elixir modules, (2) `is_map` guards in every `from_map/1` that auto-dispatch expanded fields through the registry (replacing the current raw-map passthrough), and (3) private atomizer functions for every status-like and finite-enum field that currently returns raw strings.

The good news: the architecture for all three changes is already proven within the codebase. `Invoice` is the reference implementation — it auto-atomizes `status`, `billing_reason`, `collection_method`, and `customer_tax_exempt`, and uses nested struct calls in `from_map/1`. The `Subscription` module uses the modern `Map.split/2` pattern. The task is mechanical replication of these patterns across the remaining modules, plus one new shared module (`ObjectTypes`).

The primary challenge is breadth: 84+ modules need touching. The planner should batch these into coherent waves — ideally by resource family (payments, billing, connect) — and ensure each wave has unit tests before moving on.

**Primary recommendation:** Create the ObjectTypes registry and Expand helper first (Wave 0), then sweep modules in waves grouped by family, with tests per wave, and update CHANGELOG last.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| ObjectTypes registry lookup | Library layer (compile-time module) | — | Pure data lookup, no I/O; compiles to pattern match |
| Expand dispatch (`is_map` guard) | `from_map/1` in each resource module | — | Deserialization happens at struct creation, not in transport or client |
| Status atomization | `from_map/1` in each resource module | — | Private to each module; mirrors Invoice precedent |
| Dot-path expand | Stripe API server | `from_map/1` guard picks up result | No client-side work needed beyond D-02 |
| Typespec updates | Each resource module | — | Documentation-only (no Dialyzer); inline with struct changes |
| CHANGELOG entry | `CHANGELOG.md` root | — | One entry covering all modules |

---

## Standard Stack

### Core (No New Dependencies)
[VERIFIED: codebase grep] This phase adds no new hex dependencies. All tools are already present.

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ExUnit | stdlib | Test framework | Unit tests for ObjectTypes registry and atomizer coverage |
| Mox | ~> 1.2 | Mock Transport in existing unit tests | Already used project-wide |

### New Modules (New Files, Not New Deps)

| Module | File | Purpose |
|--------|------|---------|
| `LatticeStripe.ObjectTypes` | `lib/lattice_stripe/object_types.ex` | Compile-time `@object_map` registry; `from_map/1` dispatch |
| `LatticeStripe.Expand` | `lib/lattice_stripe/expand.ex` | `maybe_deserialize/1` helper; OR inline into ObjectTypes |

The decision between a separate `Expand` module vs. inlining `maybe_deserialize/1` into `ObjectTypes` is Claude's discretion. Recommendation: inline into `ObjectTypes` to minimize the public API surface — `ObjectTypes.maybe_deserialize/1` reads clearly and eliminates the extra module.

---

## Architecture Patterns

### System Architecture Diagram

```
Stripe API Response (JSON)
        |
        v
Jason.decode! (string-keyed map)
        |
        v
Resource.unwrap_singular/2 or unwrap_list/2
        |
        v
Module.from_map/1
   |            |
   v            v
known fields  expandable fields
   |            |
   |         is_map(val)?
   |          /        \
   |        YES         NO
   |         |          |
   |   ObjectTypes    keep as
   |  .maybe_deseri-   string ID
   |   alize(val)
   |         |
   |    lookup "object"
   |    key in @object_map
   |         |
   |    dispatch to
   |    Module.from_map(val)
   |         |
   v         v
atomize_status(known["status"])
atomize_foo(known["foo"])
        |
        v
%ResourceStruct{customer: %Customer{} | "cus_123", status: :active, ...}
```

### Recommended Project Structure (New Files Only)
```
lib/lattice_stripe/
├── object_types.ex       # NEW: central registry + maybe_deserialize/1
lib/lattice_stripe/       # TOUCHED: every resource module's from_map/1
test/lattice_stripe/
├── object_types_test.exs # NEW: registry lookup unit tests
CHANGELOG.md              # NEW ENTRY: expand behavior change migration note
```

### Pattern 1: ObjectTypes Registry

**What:** A module with a compile-time `@object_map` mapping Stripe `"object"` strings to LatticeStripe modules, plus a `maybe_deserialize/1` function.

**When to use:** Called from each resource's `from_map/1` for every expandable field.

**Example:**
```elixir
# lib/lattice_stripe/object_types.ex
# [VERIFIED: codebase — mirrors stripe-ruby ObjectTypes pattern from CONTEXT.md]
defmodule LatticeStripe.ObjectTypes do
  @moduledoc false

  @object_map %{
    "account"               => LatticeStripe.Account,
    "account_link"          => LatticeStripe.AccountLink,
    "balance_transaction"   => LatticeStripe.BalanceTransaction,
    "bank_account"          => LatticeStripe.BankAccount,
    "card"                  => LatticeStripe.Card,
    "charge"                => LatticeStripe.Charge,
    "checkout.session"      => LatticeStripe.Checkout.Session,
    "coupon"                => LatticeStripe.Coupon,
    "customer"              => LatticeStripe.Customer,
    "invoice"               => LatticeStripe.Invoice,
    "invoiceitem"           => LatticeStripe.InvoiceItem,
    "payment_intent"        => LatticeStripe.PaymentIntent,
    "payment_method"        => LatticeStripe.PaymentMethod,
    "payout"                => LatticeStripe.Payout,
    "price"                 => LatticeStripe.Price,
    "product"               => LatticeStripe.Product,
    "promotion_code"        => LatticeStripe.PromotionCode,
    "refund"                => LatticeStripe.Refund,
    "setup_intent"          => LatticeStripe.SetupIntent,
    "subscription"          => LatticeStripe.Subscription,
    "subscription_item"     => LatticeStripe.SubscriptionItem,
    "subscription_schedule" => LatticeStripe.SubscriptionSchedule,
    "transfer"              => LatticeStripe.Transfer,
    "transfer_reversal"     => LatticeStripe.TransferReversal,
    "billing_portal.session" => LatticeStripe.BillingPortal.Session,
    "billing.meter"         => LatticeStripe.Billing.Meter,
    "test_helpers.test_clock" => LatticeStripe.TestHelpers.TestClock
  }

  @doc """
  Deserializes a Stripe API map into a typed struct.

  If the map contains an `"object"` key that matches a known Stripe type,
  delegates to that module's `from_map/1`. Otherwise returns the map as-is.
  Returns nil unchanged.
  """
  @spec maybe_deserialize(map() | String.t() | nil) :: struct() | map() | String.t() | nil
  def maybe_deserialize(nil), do: nil
  def maybe_deserialize(val) when is_binary(val), do: val

  def maybe_deserialize(%{"object" => object_type} = map) do
    case Map.fetch(@object_map, object_type) do
      {:ok, module} -> module.from_map(map)
      :error        -> map   # Unknown object type — preserve raw map
    end
  end

  def maybe_deserialize(map) when is_map(map), do: map
end
```

### Pattern 2: `is_map` Guard in `from_map/1` (Expandable Fields)

**What:** Each expandable field in a resource's `from_map/1` uses an `if is_map(val)` dispatch instead of direct assignment.

**When to use:** Every field documented by Stripe as expandable (returns an ID string by default, full object when expand is passed).

**Example (from D-02):**
```elixir
# [VERIFIED: CONTEXT.md D-02 pattern]
# In LatticeStripe.PaymentIntent.from_map/1:
alias LatticeStripe.ObjectTypes

customer: if is_map(map["customer"]),
  do: ObjectTypes.maybe_deserialize(map["customer"]),
  else: map["customer"]
```

**Compact single-expression form** (when the field name is unambiguous):
```elixir
customer: ObjectTypes.maybe_deserialize_if_map(map["customer"])
# OR keep inline with the guard — both are valid
```

### Pattern 3: Private Atomizer (Status/Enum Fields)

**What:** Private `defp atomize_*/1` functions at the bottom of each resource module's private section.

**When to use:** Any field documented by Stripe with a finite set of string values (status, type, collection_method, etc.).

**Reference implementation:**
```elixir
# [VERIFIED: lib/lattice_stripe/invoice.ex lines 1024-1050]
defp atomize_status("draft"), do: :draft
defp atomize_status("open"), do: :open
defp atomize_status("paid"), do: :paid
defp atomize_status("void"), do: :void
defp atomize_status("uncollectible"), do: :uncollectible
defp atomize_status(other), do: other   # Forward-compat: unknown values pass through

defp atomize_collection_method("charge_automatically"), do: :charge_automatically
defp atomize_collection_method("send_invoice"), do: :send_invoice
defp atomize_collection_method(other), do: other
```

**Note:** `other` catch-all MUST be the last clause. Do NOT use `nil` as a special case — `nil` is covered by `other` and returns `nil` unchanged, which is correct.

### Pattern 4: Typespec Update for Expandable Fields

**What:** Change `String.t() | nil` to `Module.t() | String.t() | nil` for each expandable field.

```elixir
# Before (EXPD-04 target):
customer: String.t() | nil,

# After:
customer: LatticeStripe.Customer.t() | String.t() | nil,
```

### Anti-Patterns to Avoid

- **Using `String.to_atom/1` directly:** Creates unbounded atoms from external input. The private atomizer pattern with whitelisted clauses is correct and safe.
- **Using `String.to_existing_atom/1` in atomizers:** The Capability/Meter pattern uses this — but it requires pre-declaring `@known_status_atoms` literals. The Invoice `defp` clause pattern is simpler and equally safe without the pre-declaration ceremony.
- **Dispatching on `is_map(val)` without checking `"object"` key:** The `ObjectTypes.maybe_deserialize/1` handles the fallthrough correctly — a map without an `"object"` key passes through as raw map. Callers don't need to guard before calling `maybe_deserialize/1`.
- **Adding `Expand` dispatch to nested sub-structs (AutomaticTax, CancellationDetails, etc.):** These internal types do not appear as expandable fields in the Stripe API — they're always inlined. Do NOT add expand dispatch to them.
- **Modifying `Resource.unwrap_singular/2` or `unwrap_list/2`:** The expand dispatch belongs in each `from_map/1`, not in the shared Resource helpers. This keeps the dispatch localized and avoids a recursive walk that's unnecessary given D-04.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Object type dispatch | Custom if-else chains in each module | `ObjectTypes.maybe_deserialize/1` | Centralizes logic; one change updates all modules |
| Safe string→atom conversion | `String.to_atom/1` or `String.to_existing_atom/1` | Private `defp atomize_*/1` whitelist clauses | Atom table safety; forward compat fallthrough |
| Dot-path expand parsing | Client-side path traversal | None — Stripe does it server-side | D-04: pass through, detect on return |

**Key insight:** Every problem in this phase is already solved by existing patterns in the codebase. ObjectTypes is the only new abstraction needed.

---

## Complete Module Audit

### Modules with Raw `status` (Need Atomizer Added)

[VERIFIED: codebase grep `status: map\["status"\]` and `status: known\["status"\]`]

| Module | File | Status Values (Stripe Docs) | Already Has Atomizer? |
|--------|------|---------------------------|-----------------------|
| `PaymentIntent` | `payment_intent.ex` | `requires_payment_method`, `requires_confirmation`, `requires_action`, `processing`, `requires_capture`, `canceled`, `succeeded` | No — raw string |
| `Subscription` | `subscription.ex` | `incomplete`, `incomplete_expired`, `trialing`, `active`, `past_due`, `canceled`, `unpaid`, `paused` | No — raw string |
| `SubscriptionSchedule` | `subscription_schedule.ex` | `not_started`, `active`, `completed`, `released`, `canceled` | No — raw string |
| `Payout` | `payout.ex` | `paid`, `pending`, `in_transit`, `canceled`, `failed` | No — raw string |
| `Refund` | `refund.ex` | `pending`, `requires_action`, `succeeded`, `failed`, `canceled` | No — raw string |
| `SetupIntent` | `setup_intent.ex` | `requires_payment_method`, `requires_confirmation`, `requires_action`, `processing`, `canceled`, `succeeded` | No — raw string |
| `Charge` | `charge.ex` | `succeeded`, `pending`, `failed` | No — raw string |
| `BankAccount` | `bank_account.ex` | `new`, `validated`, `verified`, `verification_failed`, `errored` | No — raw string |
| `BalanceTransaction` | `balance_transaction.ex` | `available`, `pending` | No — raw string |
| `Checkout.Session` | `checkout/session.ex` | `open`, `complete`, `expired` | No — raw string |
| `Invoice.AutomaticTax` | `invoice/automatic_tax.ex` | `requires_location_inputs`, `complete`, `failed` | No — raw string |
| `Billing.Meter` | `billing/meter.ex` | `active`, `inactive` | Has public `status_atom/1` — needs auto-atomize + deprecate public API |
| `Account.Capability` | `account/capability.ex` | `active`, `inactive`, `pending`, `unrequested`, `disabled` | Has public `status_atom/1` — needs auto-atomize + deprecate public API |

**Already atomized (Invoice precedent):**
[VERIFIED: codebase grep `atomize_status\|atomize_billing_reason`]
- `Invoice` — `status`, `billing_reason`, `collection_method`, `customer_tax_exempt`
- `Price` — `type`, `billing_scheme`, `tax_behavior`, `interval`, `usage_type`, `aggregate_usage`
- `Coupon` — `duration`
- `TestHelpers.TestClock` — `status`

### Non-Status Enum Fields to Atomize

[ASSUMED: Based on Stripe docs knowledge and Invoice precedent — verify each field against current Stripe API docs during implementation]

| Module | Field | Documented Values |
|--------|-------|------------------|
| `Subscription` | `collection_method` | `charge_automatically`, `send_invoice` |
| `Subscription` | `billing_thresholds.billing_cycle_anchor` | Could be open-ended — verify |
| `Payout` | `type` | `bank_account`, `card` |
| `Payout` | `method` | `standard`, `instant` |
| `BalanceTransaction` | `type` | 30+ values — verify if worth atomizing |
| `SetupIntent` | `usage` | `off_session`, `on_session` |
| `Checkout.Session` | `mode` | `payment`, `setup`, `subscription` |
| `Checkout.Session` | `payment_status` | `paid`, `unpaid`, `no_payment_required` |
| `SubscriptionSchedule` | `end_behavior` | `release`, `cancel` |

**Note:** `BalanceTransaction.type` has 30+ documented values (charge, refund, adjustment, etc.) — this is a judgment call. The D-03 decision says "use Stripe docs as source of truth for finite documented values." It is finite. Include it. The fallthrough clause handles future additions.

### Modules with Expandable Fields Needing `is_map` Guard

[VERIFIED: codebase grep for `String.t() | map() | nil` + Stripe docs expand annotations]

**Already documented as polymorphic (have `String.t() | map() | nil`) — these are the first candidates for the full D-02 treatment:**

| Module | Expandable Fields |
|--------|------------------|
| `Payout` | `balance_transaction`, `destination`, `failure_balance_transaction` |
| `Charge` | `balance_transaction`, `destination`, `source_transfer` |
| `Transfer` | `balance_transaction`, `destination`, `destination_payment`, `source_transaction` |
| `TransferReversal` | `balance_transaction`, `destination_payment_refund`, `source_refund`, `transfer` |
| `SetupIntent` | `latest_attempt` |
| `SubscriptionSchedule.PhaseItem` | `price` |
| `SubscriptionSchedule.AddInvoiceItem` | `price` |
| `BalanceTransaction` | `source` |

**Documented as `String.t() | nil` but Stripe marks expandable — need guard + typespec update:**

| Module | Expandable Fields |
|--------|------------------|
| `PaymentIntent` | `customer`, `latest_charge`, `payment_method` |
| `Subscription` | `customer`, `default_payment_method`, `latest_invoice`, `pending_setup_intent`, `schedule` |
| `Invoice` | `customer`, `charge`, `payment_intent`, `subscription` |
| `Refund` | `charge`, `payment_intent` |
| `Charge` | `customer`, `invoice`, `payment_intent`, `payment_method` |
| `SetupIntent` | `customer`, `payment_method` |
| `Checkout.Session` | `customer`, `invoice`, `payment_intent`, `subscription` |
| `SubscriptionSchedule` | `customer`, `subscription` |
| `PromotionCode` | `customer` |
| `InvoiceItem` | `customer`, `invoice`, `subscription` |
| `SubscriptionItem` | `subscription` |
| `Card` | `customer` |
| `BankAccount` | `customer` |
| `PaymentMethod` | `customer` |

---

## ObjectTypes Registry: Complete Entry List

[VERIFIED: codebase grep for `object: "` across all modules]

All Stripe `"object"` values present in the LatticeStripe codebase, mapped to their modules:

```elixir
@object_map %{
  # Top-level resources
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

  # Namespaced resources (dot notation in Stripe)
  "billing.meter"           => LatticeStripe.Billing.Meter,
  "billing_portal.session"  => LatticeStripe.BillingPortal.Session,
  "checkout.session"        => LatticeStripe.Checkout.Session,
  "test_helpers.test_clock" => LatticeStripe.TestHelpers.TestClock,

  # Nested resource with its own from_map (appears when expanded in lists)
  "line_item"   => LatticeStripe.Invoice.LineItem
}
```

**Note:** `"list"` is NOT included — `LatticeStripe.List` is an internal wrapper, not a Stripe expandable object type. `"item"` (Checkout.LineItem) uses object string `"item"` — omit from registry since checkout line items don't appear as expand targets on other resources.

**Note on Billing.Meter object string:** Stripe uses `"billing.meter"` (dot notation, not underscore). Verify this when implementing — the existing code has `object: map["object"]` without a default for Meter, suggesting the object string wasn't pinned during Phase 20. [ASSUMED: "billing.meter" is the Stripe string — verify against stripe-mock or docs]

---

## Common Pitfalls

### Pitfall 1: Silent Pattern Match Break for Callers
**What goes wrong:** Callers doing `%PaymentIntent{customer: "cus_" <> _} = pi` will get a MatchError when customer is now `%Customer{}`.
**Why it happens:** This is a deliberate behavior change (D-02). Callers who pass `expand:` were getting a raw `map()` before; now they get a typed struct. Callers who were pattern-matching on the string ID still work (no expand = string ID preserved).
**How to avoid:** CHANGELOG migration note is required (EXPD-04). Note must explain: "If you pass `expand: [...]` and pattern-match on the expanded field, update your match to use the typed struct or `is_map/1`."
**Warning signs:** Accrue integration tests — grep for string matches on expandable fields before cutting a release.

### Pitfall 2: Atom Table Exhaustion from External Input
**What goes wrong:** Using `String.to_atom/1` or `String.to_existing_atom/1` on Stripe's status values. If Stripe adds a new value not in the known list, `to_existing_atom` crashes.
**Why it happens:** The Capability and Meter modules use `String.to_existing_atom/1` via `@known_statuses` guard — this pattern requires exact synchronization between atom declarations and the guard. If Stripe adds a new status, it crashes.
**How to avoid:** Use the Invoice `defp` clause pattern. Unknown values fall through as strings. No `to_existing_atom/1` needed.

### Pitfall 3: Missing `nil` Passthrough in Atomizers
**What goes wrong:** `atomize_status(nil)` crashes with no-function-clause-matching if `nil` isn't handled.
**Why it happens:** The `other` catch-all covers `nil` since Elixir pattern matching treats `nil` as a value. But if someone writes `when is_binary(other)` on the fallthrough clause, `nil` won't match.
**How to avoid:** The final clause MUST be `defp atomize_status(other), do: other` — no type guard on `other`. The TestClock implementation has a slightly different pattern (`when is_binary(other)` + separate `other`) — avoid that complexity.

### Pitfall 4: Circular Module Dependency in ObjectTypes
**What goes wrong:** `LatticeStripe.ObjectTypes` references e.g. `LatticeStripe.PaymentIntent`, which imports `LatticeStripe.ObjectTypes`. Elixir allows compile-time circular deps in some cases but they can produce confusing errors.
**Why it happens:** The registry module depends on all resource modules; resource modules depend on the registry module for expand dispatch.
**How to avoid:** The registry has no `use` or `import` — it's a pure data module. Resource modules `alias LatticeStripe.ObjectTypes` and call `ObjectTypes.maybe_deserialize/1`. Elixir handles this fine as long as ObjectTypes doesn't `import` or `use` any resource module. Verify with `mix compile` after creating ObjectTypes.

### Pitfall 5: `from_map/1` vs `cast/1` Inconsistency
**What goes wrong:** Some modules use `cast/1` as the primary deserialization function (`BankAccount`, `Card`, `Account.Capability`, `Balance.Amount`, `ExternalAccount.Unknown`). The ObjectTypes registry calls `module.from_map(map)` — but if the module only has `cast/1`, this crashes.
**Why it happens:** Historical inconsistency in the codebase — earlier modules used `cast/1`, later ones use `from_map/1`. `BankAccount` already has both (`from_map/1` delegates to `cast/1`).
**How to avoid:** The ObjectTypes registry should call `from_map/1` uniformly. Verify that every module in `@object_map` exposes `from_map/1`. Modules that only have `cast/1` need a `from_map/1` alias added (like BankAccount already has).

**Modules needing `from_map/1` verification:**
[VERIFIED: codebase grep] These modules have `cast/1` but may not have `from_map/1`:
- `LatticeStripe.Account.Capability` — only has `cast/1`, no `from_map/1` alias
- `LatticeStripe.Balance.Amount` — only has `cast/1` (not in ObjectTypes registry — balance isn't expandable on other resources)
- `LatticeStripe.ExternalAccount.Unknown` — only has `cast/1` (not a direct expand target)

For ObjectTypes, only `Account.Capability` is a potential registry entry concern — verify if Capability appears as an expand target anywhere.

### Pitfall 6: `Billing.Meter` Object String
**What goes wrong:** The Meter module uses `object: map["object"]` (no default), meaning the `"object"` string is whatever Stripe sends. If Stripe uses `"billing.meter"` but registry uses `"billing_meter"`, dispatch fails silently.
**Why it happens:** The Meter module was written without pinning the object string default.
**How to avoid:** When building the ObjectTypes registry, use stripe-mock to confirm the exact `"object"` string that Stripe returns for a Billing Meter. [ASSUMED: it is `"billing.meter"` based on Stripe's dot-notation convention for namespaced resources]

### Pitfall 7: Sweep Order and Compile-time Dependencies
**What goes wrong:** If the planner creates ObjectTypes in a late wave, early waves can't use it.
**Why it happens:** Wave sequencing error.
**How to avoid:** ObjectTypes MUST be Wave 0 (the first task). All subsequent waves depend on it.

---

## Code Examples

### ObjectTypes.maybe_deserialize/1 — the core dispatch function
```elixir
# Source: D-01 pattern from CONTEXT.md
def maybe_deserialize(nil), do: nil
def maybe_deserialize(val) when is_binary(val), do: val

def maybe_deserialize(%{"object" => object_type} = map) do
  case Map.fetch(@object_map, object_type) do
    {:ok, module} -> module.from_map(map)
    :error        -> map
  end
end

def maybe_deserialize(map) when is_map(map), do: map
```

### Expandable Field Guard in from_map/1
```elixir
# Source: D-02 pattern from CONTEXT.md
# Applied to each expandable field; alias ObjectTypes at top of module
customer:
  if is_map(map["customer"]),
    do: ObjectTypes.maybe_deserialize(map["customer"]),
    else: map["customer"]
```

### Complete PaymentIntent Atomizer Set (D-03)
```elixir
# Source: Stripe PaymentIntent docs [ASSUMED: verify all values]
defp atomize_status("requires_payment_method"), do: :requires_payment_method
defp atomize_status("requires_confirmation"),   do: :requires_confirmation
defp atomize_status("requires_action"),         do: :requires_action
defp atomize_status("processing"),              do: :processing
defp atomize_status("requires_capture"),        do: :requires_capture
defp atomize_status("canceled"),                do: :canceled
defp atomize_status("succeeded"),               do: :succeeded
defp atomize_status(other),                     do: other
```

### Deprecating Public status_atom/1 (Capability & Meter)
```elixir
# Source: CONTEXT.md D-03
# Option A: deprecate via @deprecated attribute, keep function
@deprecated "status is now automatically atomized in from_map/1. Access struct.status directly."
@spec status_atom(t() | String.t() | nil) :: atom()
def status_atom(%__MODULE__{status: s}), do: s  # Already an atom after from_map/1
def status_atom(s) when is_atom(s), do: s
def status_atom(nil), do: nil
def status_atom(s), do: atomize_status(s)

# Option B: keep public function, have it call private atomizer
# Planner decides which is less breaking for existing callers.
```

### Unit Test Pattern for ObjectTypes
```elixir
# Source: [ASSUMED — follow existing test conventions]
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

### Integration Test Pattern for Expand
```elixir
# Source: [ASSUMED — follow existing integration test conventions in test/integration/]
# Requires stripe-mock running on localhost:12111
test "retrieve/3 with expand: [\"customer\"] returns %Customer{}", %{client: client} do
  {:ok, pi} = PaymentIntent.retrieve(client, "pi_test",
    expand: ["customer"])

  # When stripe-mock returns an expanded customer, it should be a struct
  case pi.customer do
    %LatticeStripe.Customer{} -> :ok  # Expanded path
    customer_id when is_binary(customer_id) -> :ok  # Unexpanded path (mock may not expand)
    nil -> :ok  # No customer
  end
end
```

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Billing.Meter`'s Stripe `"object"` string is `"billing.meter"` (dot notation, not underscore) | ObjectTypes Registry | Registry dispatch fails silently for expanded Meter objects |
| A2 | `BillingPortal.Session`'s Stripe `"object"` string is `"billing_portal.session"` | ObjectTypes Registry | Same — dispatch fails for expanded session objects |
| A3 | `Account.Capability` does not need to be in the ObjectTypes registry (not an expand target on other resources) | Module Audit | If Capability is expandable on Account, dispatch would silently fail |
| A4 | `BalanceTransaction.type` (30+ values) is worth atomizing (finite documented set) | Non-status enum fields | More churn if Stripe adds types; the fallthrough clause mitigates this |
| A5 | Stripe sends `nil` for `status` on new resources before status is set (covered by `other` fallthrough) | Atomizer patterns | If a nil status is unexpected, some downstream code may fail |
| A6 | stripe-mock correctly responds to `expand: ["customer"]` on PaymentIntent for integration tests | Validation Architecture | Integration tests may need to test expand path differently if stripe-mock doesn't support it |

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Public `status_atom/1` helper (Capability, Meter pattern) | Private `defp atomize_status/1` auto-applied in `from_map/1` | Phase 22 | Callers no longer call `status_atom/1` — access `.status` directly |
| Expandable fields return raw `map()` | Expandable fields return typed struct (or string ID if not expanded) | Phase 22 | Breaking for callers who pattern-match on expanded maps; migration note in CHANGELOG |
| `String.t() \| nil` typespec for expandable fields | `Module.t() \| String.t() \| nil` union type | Phase 22 | Documentation improvement; no runtime change (no Dialyzer) |

**Deprecated/outdated:**
- `Account.Capability.status_atom/1`: Deprecated in Phase 22 — `cast/1` will auto-atomize; callers access `.status` directly
- `Billing.Meter.status_atom/1`: Deprecated in Phase 22 — `from_map/1` will auto-atomize; callers access `.status` directly

---

## Environment Availability

Step 2.6: SKIPPED (no new external dependencies — this phase is code changes only). stripe-mock is already proven available for existing integration tests.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | None — uses `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/object_types_test.exs` |
| Full suite command | `mix test` |
| Integration suite | `mix test --include integration` (requires stripe-mock on port 12111) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| EXPD-01 | `expand: ["customer"]` returns `%Customer{}` struct | unit (from_map fixture) + integration | `mix test test/lattice_stripe/object_types_test.exs` | ❌ Wave 0 |
| EXPD-01 | String ID passthrough (no expand) unchanged | unit | `mix test test/lattice_stripe/payment_intent_test.exs` | ✅ (existing tests cover no-expand path) |
| EXPD-02 | Dot-path `expand: ["data.customer"]` works on list | integration | `mix test --include integration test/integration/` | ✅ (form_encoder_test.exs covers encoding; integration covers end-to-end) |
| EXPD-03 | `PaymentIntent.status` is atom `:succeeded`, not `"succeeded"` | unit | `mix test test/lattice_stripe/payment_intent_test.exs` | ❌ Wave N (per module) |
| EXPD-03 | Unknown status values pass through as strings | unit | `mix test test/lattice_stripe/payment_intent_test.exs` | ❌ Wave N |
| EXPD-03 | `Meter.status` is auto-atomized in `from_map/1` | unit | `mix test test/lattice_stripe/billing/meter_test.exs` | ❌ Wave N |
| EXPD-04 | `@type t()` for expandable fields uses union type | (static — review only) | n/a | n/a |
| EXPD-04 | CHANGELOG contains migration note | (static — review only) | n/a | n/a |

### Sampling Rate
- **Per task commit:** Quick run for that module's test file
- **Per wave merge:** `mix test` (full unit suite)
- **Phase gate:** Full unit suite green + relevant integration tests pass before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/lattice_stripe/object_types_test.exs` — covers ObjectTypes.maybe_deserialize/1 (EXPD-01 dispatch)
- [ ] ObjectTypes unit tests: nil, string ID passthrough, known object dispatch, unknown object fallthrough

*(Existing test infrastructure covers all other module tests — each module already has a test file; gaps are per-module atomizer tests added during each wave)*

---

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — |
| V3 Session Management | No | — |
| V4 Access Control | No | — |
| V5 Input Validation | Yes (atom creation) | Private `defp atomize_*/1` whitelist pattern — never `String.to_atom/1` on external input |
| V6 Cryptography | No | — |

**Security note:** The atomizer pattern is the key safety control. Using `String.to_atom/1` on Stripe's status values would allow a compromised Stripe response to exhaust the BEAM atom table. The `defp` whitelist clause pattern is the correct approach and is already proven in Invoice.

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 22 |
|-----------|-------------------|
| No Dialyzer — typespecs are documentation only | Typespec updates (EXPD-04) are documentation improvements; zero runtime enforcement impact |
| Minimal dependencies | No new hex deps needed; ObjectTypes is a new source file |
| Elixir 1.15+ | `Map.split/2` and pattern-matching used throughout are 1.15+ compatible |
| Jason for JSON | No impact — expand dispatch happens after Jason decoding |
| No GenServer for state | ObjectTypes registry is compile-time `@object_map` attribute — no process state |
| Follow existing patterns | Invoice is the reference; use `Map.split/2` variant when touching modules that currently use `Map.drop` |

---

## Open Questions

1. **Exact `"object"` string for `Billing.Meter` and `BillingPortal.Session`**
   - What we know: These modules don't pin their object string default; we have assumed dot-notation (`"billing.meter"`, `"billing_portal.session"`)
   - What's unclear: Whether stripe-mock returns exactly those strings
   - Recommendation: During Wave 0 (ObjectTypes creation), verify by calling `mix test --include integration` with a Meter retrieve and inspecting the raw `"object"` key. Alternatively, check stripe-mock's fixture JSON.

2. **Deprecation strategy for `status_atom/1` on Capability and Meter**
   - What we know: These are public functions; changing behavior is a minor-semver change
   - What's unclear: Whether any downstream callers (e.g., Accrue) use `Capability.status_atom/1` or `Meter.status_atom/1` directly
   - Recommendation: Use `@deprecated` attribute to emit a compile-time warning; keep the function working by delegating to the atom value; remove in v2.0.

3. **Checkout.Session `status` atomization**
   - What we know: Has a `status` field with documented values `open`, `complete`, `expired`
   - What's unclear: Whether this was in the D-03 scope ("9 modules") — CONTEXT.md lists 9 specific modules but the grep revealed `Checkout.Session` also has raw status
   - Recommendation: Include in the sweep since it's documented as finite values; D-03 says "sweep" stops at open-ended text fields.

---

## Sources

### Primary (HIGH confidence)
- `lib/lattice_stripe/invoice.ex` — Reference atomizer implementation (Invoice precedent, verified in codebase)
- `lib/lattice_stripe/account/capability.ex` — Public `status_atom/1` pattern to be deprecated (verified)
- `lib/lattice_stripe/billing/meter.ex` — Meter `status_atom/1` pattern (verified)
- `lib/lattice_stripe/payout.ex` — `String.t() | map() | nil` expand type precedent (verified)
- `lib/lattice_stripe/resource.ex` — `unwrap_singular/2` and `unwrap_list/2` (verified)
- `.planning/phases/22-expand-deserialization-status-atomization/22-CONTEXT.md` — Locked decisions D-01 through D-04 (primary source)
- [Stripe PaymentIntent API docs](https://docs.stripe.com/api/payment_intents/object) — Expandable fields list (fetched)
- [Stripe Subscription API docs](https://docs.stripe.com/api/subscriptions/object) — Expandable fields list (fetched)

### Secondary (MEDIUM confidence)
- Codebase grep: `status: map\["status"\]` — all modules with un-atomized status fields (verified)
- Codebase grep: `object: "..."` — all object type strings for ObjectTypes registry (verified)
- Codebase grep: `String.t() | map() | nil` — already-documented polymorphic fields (verified)

### Tertiary (LOW confidence — assumptions flagged)
- Stripe dot-notation convention for `"billing.meter"` object string (inferred from naming convention, not verified against live API or stripe-mock)

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — no new dependencies; all patterns exist in codebase
- Architecture: HIGH — decisions locked in CONTEXT.md; ObjectTypes pattern verified against stripe-ruby reference
- Module Audit: HIGH — all modules scanned via grep; status lists from Stripe docs
- Pitfalls: HIGH — based on verified code patterns and known Elixir atomization concerns
- Enum field values: MEDIUM — Stripe docs consulted but specific status strings should be verified during implementation

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 (stable domain; no external dependency churn)
