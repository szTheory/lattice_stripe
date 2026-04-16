# Phase 23: BillingPortal.Configuration CRUDL - Research

**Researched:** 2026-04-16
**Domain:** Elixir resource module pattern — Stripe BillingPortal Configuration CRUDL with nested typed structs
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01: Nesting Boundary — Features + 4 Typed Feature Sub-Structs**

Type the Features object and 4 of the 5 feature sub-objects as dedicated modules. InvoiceHistory (single `enabled` boolean) stays as `map() | nil` inside Features — not worth a module for 1 field.

Module allocation (6 total):
1. `LatticeStripe.BillingPortal.Configuration` — top-level resource
2. `LatticeStripe.BillingPortal.Configuration.Features` — features container
3. `LatticeStripe.BillingPortal.Configuration.Features.SubscriptionCancel` — mode, proration_behavior, cancellation_reason (Level 3+ as maps)
4. `LatticeStripe.BillingPortal.Configuration.Features.SubscriptionUpdate` — products, schedule_at_period_end (Level 3+ as maps)
5. `LatticeStripe.BillingPortal.Configuration.Features.CustomerUpdate` — allowed_updates, enabled
6. `LatticeStripe.BillingPortal.Configuration.Features.PaymentMethodUpdate` — enabled

Not typed (maps in parent struct):
- `business_profile` — 3 scalar fields, simple enough for map access
- `login_page` — 2 fields (enabled, url), trivial
- `invoice_history` — 1 field (enabled), single boolean not worth a module
- Level 3+ sub-objects inside feature sub-structs (cancellation_reason, products, adjustable_quantity) — stored in parent's `extra` or as `map() | nil` fields

**D-02: Configuration Lifecycle — Update-Only + @moduledoc Guidance**

No `deactivate/3` or `activate/3` convenience helpers. Developers use `update(client, id, %{"active" => false})`. The `@moduledoc` should explain:
- Configurations cannot be deleted, only deactivated via `update(active: false)`
- A configuration cannot be deactivated if it's the default (`is_default: true`)
- Stripe returns an error if you try — no client-side guard needed

**D-03: Session.configuration Upgrade — Expand in Phase 23**

Upgrade `BillingPortal.Session.configuration` from `String.t() | nil` to `Configuration.t() | String.t() | nil` with an expand guard via `ObjectTypes.maybe_deserialize/1`.

Changes required:
- Add `"billing_portal.configuration" => LatticeStripe.BillingPortal.Configuration` to ObjectTypes `@object_map`
- Add `alias LatticeStripe.ObjectTypes` to Session (if not already present)
- Add expand guard on `configuration` field in Session's `from_map/1`
- Update Session's `@type t` for configuration field
- Add expand test to session_test.exs

**D-04: Sub-Struct Naming — Mirror Stripe Field Names**

Follow existing project convention: sub-struct module name mirrors the Stripe JSON field name, converted to PascalCase.
- `features` → `Configuration.Features`
- `subscription_cancel` → `Configuration.Features.SubscriptionCancel`
- `subscription_update` → `Configuration.Features.SubscriptionUpdate`
- `customer_update` → `Configuration.Features.CustomerUpdate`
- `payment_method_update` → `Configuration.Features.PaymentMethodUpdate`

### Claude's Discretion

- Exact fields in each sub-struct (researcher should verify against current Stripe API docs)
- Whether `@known_fields` uses `~w[...]` or `~w(...)` (follow existing convention: `~w[...]`)
- Test fixture structure and assertion patterns
- `@moduledoc` wording for lifecycle guidance
- Whether to use `Map.split/2` or `Map.drop` in sub-struct from_map/1 (follow Phase 22 convention: `Map.split/2`)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FEAT-01 | Developer can create, retrieve, update, and list `BillingPortal.Configuration` resources with typed structs (Level 1 + Level 2 typed, Level 3+ in `extra`) | Full Stripe API field list verified; CRUDL endpoint paths confirmed; nested struct module allocation from D-01; `stream!/2` auto-pagination pattern from Customer/Billing.Meter precedent |
</phase_requirements>

---

## Summary

Phase 23 implements the `BillingPortal.Configuration` CRUDL resource — a deferred v1.1 item now unblocked by the v1.2 roadmap. The implementation follows an established pattern in this codebase: standard resource module with `defstruct`, `@known_fields`, `from_map/1`, CRUDL functions, bang variants, `stream!`, and Mox-backed unit tests plus stripe-mock integration tests.

The principal complexity is nesting depth. The Stripe BillingPortal Configuration object has 4 levels of nesting. D-01 caps typed structs at Level 2 (6 modules total), with Level 3+ fields landing in the parent struct's `extra` map. This is exactly the pattern documented in PITFALLS.md Pitfall 8 and is consistent with existing precedents (Billing.Meter's 4 nested struct sub-modules, all 1 level deep).

The second non-trivial piece is D-03: upgrading `BillingPortal.Session.configuration` from `String.t() | nil` to `Configuration.t() | String.t() | nil` using the `ObjectTypes.maybe_deserialize/1` expand guard pattern established in Phase 22. This requires touching `object_types.ex` and `billing_portal/session.ex` — both small, surgical changes.

**Primary recommendation:** Build in 4 sequenced tasks: (1) sub-struct modules (Features + 4 children), (2) top-level Configuration resource module + CRUDL, (3) ObjectTypes registration + Session.configuration upgrade + tests, (4) mix.exs ExDoc group update + integration test.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Configuration CRUDL (create/retrieve/update/list) | API / Backend | — | Standard Stripe REST resource; Client.request/2 handles HTTP; no browser or DB layer involved |
| Nested struct decoding | API / Backend | — | from_map/1 chain in resource modules; pure data transformation at parse time |
| ObjectTypes registration | API / Backend | — | Central dispatch table for expand guards; same layer as all other resource modules |
| Session.configuration expand guard | API / Backend | — | from_map/1 on Session; additive change, no transport/retry layer involvement |
| ExDoc grouping | Static | — | mix.exs groups_for_modules list; compile-time documentation annotation |

---

## Standard Stack

### Core (no new dependencies)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ExUnit | stdlib | Test framework | Ships with Elixir; all existing tests use it |
| Mox | ~> 1.2 | Transport mock for unit tests | Project standard; all existing resource module tests use `LatticeStripe.MockTransport` |
| Jason | ~> 1.4 | JSON in fixtures and ok_response/1 helper | Already in project; test helper serializes to JSON |

No new dependencies are added in this phase. The implementation uses only existing project infrastructure.

**Installation:** (none required)

---

## Architecture Patterns

### System Architecture Diagram

```
BillingPortal.Configuration.create(client, params, opts)
  → %Request{method: :post, path: "/v1/billing_portal/configurations", ...}
  → Client.request(client, req)
      → HTTP POST via Transport.Finch
      → JSON response decoded by Jason
      → Resource.unwrap_singular(result, &Configuration.from_map/1)
          → Configuration.from_map/1
              → Map.split(map, @known_fields)
              → Features.from_map(known["features"])
                  → SubscriptionCancel.from_map(...)  ← Level 2
                  → SubscriptionUpdate.from_map(...)  ← Level 2
                  → CustomerUpdate.from_map(...)       ← Level 2
                  → PaymentMethodUpdate.from_map(...)  ← Level 2
                  → invoice_history stays as map()    ← Level 2 (trivial)
              → business_profile stays as map()       ← Level 1 (shallow)
              → login_page stays as map()             ← Level 1 (trivial)
  → {:ok, %Configuration{}} | {:error, %Error{}}
```

### Recommended Project Structure

```
lib/lattice_stripe/billing_portal/
├── configuration.ex                          # Top-level CRUDL resource module
├── configuration/
│   └── features.ex                           # Level 1 typed sub-struct
│       └── (features/ sub-dir if needed)
│           ├── subscription_cancel.ex        # Level 2 typed sub-struct
│           ├── subscription_update.ex        # Level 2 typed sub-struct
│           ├── customer_update.ex            # Level 2 typed sub-struct
│           └── payment_method_update.ex      # Level 2 typed sub-struct
├── session.ex                                # MODIFIED: expand guard on configuration field
├── guards.ex                                 # unchanged
└── session/                                  # unchanged
    └── flow_data.ex

lib/lattice_stripe/
└── object_types.ex                           # MODIFIED: add "billing_portal.configuration"

test/lattice_stripe/billing_portal/
├── configuration_test.exs                    # Unit tests (Mox)
└── configuration/
│   ├── features_test.exs                     # from_map/1 unit tests
│   ├── features/
│   │   ├── subscription_cancel_test.exs
│   │   ├── subscription_update_test.exs
│   │   ├── customer_update_test.exs
│   │   └── payment_method_update_test.exs
└── session_test.exs                          # MODIFIED: add expand guard test

test/integration/
└── billing_portal_configuration_integration_test.exs

test/support/fixtures/billing_portal.ex       # MODIFIED: add Configuration fixtures
```

### Pattern 1: Standard Resource Module (CRUDL) — Customer.ex precedent

**What:** defstruct + @known_fields + from_map/1 + create/retrieve/update/list/stream! + bang variants

**When to use:** Every Stripe resource with CRUD operations

**Example:**
```elixir
# Source: lib/lattice_stripe/customer.ex (verified)
defmodule LatticeStripe.BillingPortal.Configuration do
  alias LatticeStripe.BillingPortal.Configuration.Features
  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  @known_fields ~w[
    id object active application business_profile created default_return_url
    features is_default livemode login_page metadata name updated
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t() | nil,
          active: boolean() | nil,
          application: String.t() | nil,
          business_profile: map() | nil,
          created: integer() | nil,
          default_return_url: String.t() | nil,
          features: Features.t() | nil,
          is_default: boolean() | nil,
          livemode: boolean() | nil,
          login_page: map() | nil,
          metadata: map() | nil,
          name: String.t() | nil,
          updated: integer() | nil,
          extra: map()
        }

  defstruct [
    :id,
    :object,
    :active,
    :application,
    :business_profile,
    :created,
    :default_return_url,
    :features,
    :is_default,
    :livemode,
    :login_page,
    :metadata,
    :name,
    :updated,
    extra: %{}
  ]

  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/billing_portal/configurations", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/billing_portal/configurations/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/billing_portal/configurations/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/billing_portal/configurations", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/billing_portal/configurations", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"],
      active: known["active"],
      application: known["application"],
      business_profile: known["business_profile"],
      created: known["created"],
      default_return_url: known["default_return_url"],
      features: Features.from_map(known["features"]),
      is_default: known["is_default"],
      livemode: known["livemode"],
      login_page: known["login_page"],
      metadata: known["metadata"],
      name: known["name"],
      updated: known["updated"],
      extra: extra
    }
  end
end
```

### Pattern 2: Nested Typed Sub-Struct — FlowData.SubscriptionCancel precedent

**What:** A module with defstruct, @known_fields, @type t, from_map/1 (nil-safe). Level 3+ fields stored as `map() | nil` on the struct (not recursively typed).

**When to use:** Level 1 and Level 2 nested sub-objects that developers pattern-match against.

**Example:**
```elixir
# Source: lib/lattice_stripe/billing_portal/session/flow_data/subscription_cancel.ex (verified)
defmodule LatticeStripe.BillingPortal.Configuration.Features.SubscriptionCancel do
  @moduledoc """
  The `subscription_cancel` feature settings on a BillingPortal Configuration.

  Level 3+ fields (`cancellation_reason`) are kept as `map() | nil` per the
  6-module nesting cap (D-01). Access via `subscription_cancel["cancellation_reason"]`.
  """

  # Level 2 typed fields (known by this module)
  @known_fields ~w[enabled mode proration_behavior cancellation_reason]

  @type t :: %__MODULE__{
          enabled: boolean() | nil,
          mode: String.t() | nil,
          proration_behavior: String.t() | nil,
          cancellation_reason: map() | nil,  # Level 3+ — map access only
          extra: map()
        }

  defstruct [:enabled, :mode, :proration_behavior, :cancellation_reason, extra: %{}]

  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      enabled: known["enabled"],
      mode: known["mode"],
      proration_behavior: known["proration_behavior"],
      cancellation_reason: known["cancellation_reason"],  # raw map, not typed
      extra: extra
    }
  end
end
```

### Pattern 3: Features Dispatcher — FlowData precedent

**What:** A parent module that dispatches each known sub-key to its typed `from_map/1`, with unrecognized keys in `extra`.

**When to use:** Any "container" object that holds several sub-feature objects (mirrors FlowData.from_map/1 → SubscriptionCancel.from_map, etc.)

**Example:**
```elixir
# Source: lib/lattice_stripe/billing_portal/session/flow_data.ex (verified)
defmodule LatticeStripe.BillingPortal.Configuration.Features do
  alias LatticeStripe.BillingPortal.Configuration.Features.{
    CustomerUpdate,
    PaymentMethodUpdate,
    SubscriptionCancel,
    SubscriptionUpdate
  }

  @known_fields ~w[customer_update invoice_history payment_method_update
                   subscription_cancel subscription_update]

  @type t :: %__MODULE__{
          customer_update: CustomerUpdate.t() | nil,
          invoice_history: map() | nil,         # Level 2 — single boolean, map access only
          payment_method_update: PaymentMethodUpdate.t() | nil,
          subscription_cancel: SubscriptionCancel.t() | nil,
          subscription_update: SubscriptionUpdate.t() | nil,
          extra: map()
        }

  defstruct [
    :customer_update,
    :invoice_history,
    :payment_method_update,
    :subscription_cancel,
    :subscription_update,
    extra: %{}
  ]

  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      customer_update: CustomerUpdate.from_map(known["customer_update"]),
      invoice_history: known["invoice_history"],     # raw map
      payment_method_update: PaymentMethodUpdate.from_map(known["payment_method_update"]),
      subscription_cancel: SubscriptionCancel.from_map(known["subscription_cancel"]),
      subscription_update: SubscriptionUpdate.from_map(known["subscription_update"]),
      extra: extra
    }
  end
end
```

### Pattern 4: Session.configuration Expand Guard — Invoice.charge precedent

**What:** In `from_map/1`, wrap an expandable field with `if is_map(val), do: ObjectTypes.maybe_deserialize(val), else: val`.

**When to use:** Any field that can be either a Stripe ID string or an expanded typed struct.

**Example:**
```elixir
# Source: lib/lattice_stripe/invoice.ex (verified) — charge and customer fields
configuration:
  (if is_map(known["configuration"]),
     do: ObjectTypes.maybe_deserialize(known["configuration"]),
     else: known["configuration"]),
```

### Anti-Patterns to Avoid
- **Typing all 4 levels:** Creates ~10 modules with high maintenance burden as Stripe evolves the API. Cap at 2 levels typed, Level 3+ as `map() | nil` (Pitfall 8 in PITFALLS.md).
- **`Map.drop` instead of `Map.split`:** Phase 22 established `Map.split/2` as standard; `Map.drop` was the old pattern. Use `{known, extra} = Map.split(map, @known_fields)` followed by `known["field"]` access.
- **Adding deactivate/activate convenience wrappers:** Breaks 1:1 endpoint mapping convention. Document via `@moduledoc`, not extra functions.
- **Leaving Session.configuration as String.t() | nil:** Creates the sole expand outlier in the SDK. D-03 upgrades it in this phase.

---

## Verified Stripe API Fields

### Top-Level Configuration Object
[VERIFIED: docs.stripe.com/api/customer_portal/configurations/object]

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | `bpc_*` prefix |
| `object` | string | `"billing_portal.configuration"` |
| `active` | boolean | Deactivate via `update(active: false)` |
| `application` | string, nullable | Connect: associated application |
| `business_profile` | object | Level 1 map — headline, privacy_policy_url, terms_of_service_url |
| `created` | timestamp | Unix integer |
| `default_return_url` | string, nullable | Portal default return URL |
| `features` | object | Level 1 → typed Features struct |
| `is_default` | boolean | Default config for the account |
| `livemode` | boolean | |
| `login_page` | object | Level 1 map — enabled, url |
| `metadata` | object, nullable | |
| `name` | string, nullable | |
| `updated` | timestamp | Unix integer |

### features Sub-Object (Level 1 → Level 2)
[VERIFIED: docs.stripe.com/api/customer_portal/configurations/object]

| Sub-Object | Level 2 Module | Level 2 Fields | Level 3+ (raw map) |
|------------|---------------|----------------|---------------------|
| `customer_update` | `CustomerUpdate` | `allowed_updates` (array), `enabled` (bool) | — |
| `invoice_history` | map() only | `enabled` (bool) | — |
| `payment_method_update` | `PaymentMethodUpdate` | `enabled` (bool), `payment_method_configuration` (string, nullable) | — |
| `subscription_cancel` | `SubscriptionCancel` | `enabled` (bool), `mode` (enum), `proration_behavior` (enum) | `cancellation_reason` → `{enabled, options[]}` |
| `subscription_update` | `SubscriptionUpdate` | `enabled` (bool), `billing_cycle_anchor` (enum, nullable), `default_allowed_updates` (array), `proration_behavior` (enum), `trial_update_behavior` (enum) | `products` (array of objects), `schedule_at_period_end` (conditions object) |

### List Endpoint Parameters
[VERIFIED: docs.stripe.com/api/customer_portal/configurations/list]

| Parameter | Type | Description |
|-----------|------|-------------|
| `active` | boolean | Filter active/inactive configurations |
| `is_default` | boolean | Filter default/non-default |
| `limit` | integer | 1–100 |
| `starting_after` | string | Cursor pagination |
| `ending_before` | string | Cursor pagination |

### Stripe API Endpoint Paths
[VERIFIED: docs.stripe.com/api/customer_portal/configurations]

| Operation | Method | Path |
|-----------|--------|------|
| create | POST | `/v1/billing_portal/configurations` |
| retrieve | GET | `/v1/billing_portal/configurations/:id` |
| update | POST | `/v1/billing_portal/configurations/:id` |
| list | GET | `/v1/billing_portal/configurations` |
| (no delete) | — | Stripe deactivates, not deletes |

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Typed expand dispatch for Session.configuration | Custom if/else branching | `ObjectTypes.maybe_deserialize/1` | Already handles the `is_map` check and object type routing; adding Configuration to `@object_map` is the only change needed |
| Auto-pagination / stream | Custom loop with has_more check | `List.stream!/3` | Existing utility; all other resources use it (Customer.stream!, Billing.Meter — verified in codebase) |
| Bang variants | Re-implement error raising | `Resource.unwrap_bang!/1` | All existing resource bang variants delegate here; one line each |
| List deserialization | Manual map/reduce | `Resource.unwrap_list/2` | Existing utility; returns `{:ok, %Response{data: %List{}}}` |
| Singular deserialization | Manual struct construction | `Resource.unwrap_singular/2` | Existing utility |

**Key insight:** Every non-trivial concern (pagination, bang wrapping, expand dispatch, list unwrapping) has an existing project utility. Phase 23 adds zero new infrastructure — it assembles the existing pieces.

---

## Common Pitfalls

### Pitfall 1: Level 3+ Fields Silently Dropped (not stored in `extra`)
**What goes wrong:** `SubscriptionCancel.from_map/1` processes `cancellation_reason` but does not include it in `@known_fields`, so it falls into `extra` via `Map.split` rather than being explicitly stored as `cancellation_reason: known["cancellation_reason"]`. Developer accesses `config.features.subscription_cancel.cancellation_reason` and gets `nil`; the data is actually in `config.features.subscription_cancel.extra["cancellation_reason"]`.

**Why it happens:** `@known_fields` is defined but `cancellation_reason` is listed there to route it into `known`, then explicitly stored as a `map() | nil` field. If the field is omitted from `@known_fields`, it routes to `extra` instead.

**How to avoid:** List ALL Level 2 fields explicitly in `@known_fields` of the sub-struct, including the Level 3+ raw-map fields like `cancellation_reason` and `products`. Store them as typed `map() | nil` fields on the struct. They live in the struct, not in `extra`. `extra` is for fields not recognized at compile time.

**Warning signs:** A sub-struct with `extra` containing `"cancellation_reason"` or `"products"` after parsing.

### Pitfall 2: Session.configuration Typespec Not Updated
**What goes wrong:** `from_map/1` now returns `Configuration.t() | String.t() | nil` for the `configuration` field, but `@type t` in `session.ex` still says `configuration: String.t() | nil`. HexDocs shows the old type; downstream code assumes string-only.

**How to avoid:** Update `@type t` in Session simultaneously with the `from_map/1` change. Verify with `grep -n "configuration" lib/lattice_stripe/billing_portal/session.ex` after the change.

### Pitfall 3: ObjectTypes Entry Uses Wrong Key String
**What goes wrong:** Stripe's object type string for configurations is `"billing_portal.configuration"` (dot notation, not underscore). Registering it as `"billing_portal_configuration"` means `maybe_deserialize/1` will never match the object and Session.configuration remains as a raw map.

**How to avoid:** [VERIFIED: docs.stripe.com/api/customer_portal/configurations/object] — the `object` field value is `"billing_portal.configuration"`. Match existing keys in `object_types.ex` like `"billing_portal.session"` which uses the same dot-notation pattern.

### Pitfall 4: ExDoc Group Entry Missing Sub-Struct Modules
**What goes wrong:** `LatticeStripe.BillingPortal.Configuration` is added to the "Customer Portal" group in `mix.exs`, but the 5 nested modules (Features, SubscriptionCancel, etc.) are omitted. They appear in the ExDoc "Uncategorized" section instead of "Customer Portal".

**How to avoid:** Add all 6 modules explicitly to the `groups_for_modules` "Customer Portal" list in `mix.exs`. Pattern: examine how Billing.Meter handles its 4 nested modules in the "Billing Metering" group (all listed explicitly — verified lines 95–104 in mix.exs).

### Pitfall 5: Using `Map.drop` Instead of `Map.split`
**What goes wrong:** Pre-Phase-22 code used `extra: Map.drop(map, @known_fields)` with direct `map["field"]` access. Phase 22 standardized on `{known, extra} = Map.split(map, @known_fields)` with `known["field"]` access. Mixing patterns creates inconsistency and reviewers will flag it.

**How to avoid:** Always use `Map.split/2` in `from_map/1` for new modules. The Session module currently uses `Map.drop` (old pattern); new Configuration modules should use `Map.split/2`.

---

## Code Examples

### Sub-Struct: SubscriptionUpdate (Level 2 with Level 3+ raw maps)
```elixir
# Source: Pattern verified from lib/lattice_stripe/billing_portal/session/flow_data/subscription_cancel.ex
defmodule LatticeStripe.BillingPortal.Configuration.Features.SubscriptionUpdate do
  @moduledoc """
  The `subscription_update` feature settings on a BillingPortal Configuration.

  Level 3+ fields (`products`, `schedule_at_period_end`) are kept as `map() | nil`
  or `list() | nil` per the 6-module nesting cap (D-01). Access via map notation:
  `sub_update.products` (list of product-price maps).
  """

  # All Level 2 fields, including those kept as raw maps (Level 3+)
  @known_fields ~w[
    enabled billing_cycle_anchor default_allowed_updates proration_behavior
    products schedule_at_period_end trial_update_behavior
  ]

  @type t :: %__MODULE__{
          enabled: boolean() | nil,
          billing_cycle_anchor: String.t() | nil,
          default_allowed_updates: [String.t()] | nil,
          proration_behavior: String.t() | nil,
          products: [map()] | nil,               # Level 3+ — list of product-price maps
          schedule_at_period_end: map() | nil,   # Level 3+ — conditions object
          trial_update_behavior: String.t() | nil,
          extra: map()
        }

  defstruct [
    :enabled,
    :billing_cycle_anchor,
    :default_allowed_updates,
    :proration_behavior,
    :products,
    :schedule_at_period_end,
    :trial_update_behavior,
    extra: %{}
  ]

  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      enabled: known["enabled"],
      billing_cycle_anchor: known["billing_cycle_anchor"],
      default_allowed_updates: known["default_allowed_updates"],
      proration_behavior: known["proration_behavior"],
      products: known["products"],
      schedule_at_period_end: known["schedule_at_period_end"],
      trial_update_behavior: known["trial_update_behavior"],
      extra: extra
    }
  end
end
```

### Unit Test Pattern (Mox-based)
```elixir
# Source: Verified pattern from test/lattice_stripe/billing_portal/session_test.exs
defmodule LatticeStripe.BillingPortal.ConfigurationTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  @moduletag :billing_portal

  alias LatticeStripe.BillingPortal.Configuration
  alias LatticeStripe.Test.Fixtures.BillingPortal, as: Fixtures

  setup :verify_on_exit!

  describe "create/3" do
    test "returns {:ok, %Configuration{}} on success" do
      client = test_client()
      fixture = Fixtures.Configuration.basic()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(fixture)
      end)

      assert {:ok, %Configuration{id: "bpc_123"}} =
               Configuration.create(client, %{"features" => %{}})
    end
  end

  describe "from_map/1" do
    test "decodes features into %Features{}" do
      map = Fixtures.Configuration.with_features()
      config = Configuration.from_map(map)

      assert %Configuration.Features{} = config.features
    end

    test "captures unknown keys into :extra" do
      map = Fixtures.Configuration.basic(%{"future_field" => "val"})
      config = Configuration.from_map(map)
      assert config.extra == %{"future_field" => "val"}
    end

    test "returns nil when given nil" do
      assert Configuration.from_map(nil) == nil
    end
  end
end
```

### Integration Test Pattern (stripe-mock)
```elixir
# Source: Verified pattern from test/integration/billing_portal_session_integration_test.exs
defmodule LatticeStripe.BillingPortal.ConfigurationIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration
  @moduletag :billing_portal

  alias LatticeStripe.BillingPortal.Configuration

  setup_all do
    case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
        :ok
      {:error, _} ->
        raise "stripe-mock not running on localhost:12111"
    end
  end

  setup do
    {:ok, client: test_integration_client()}
  end

  test "full lifecycle: create → retrieve → update → list", %{client: client} do
    {:ok, %Configuration{id: id}} =
      Configuration.create(client, %{
        "business_profile" => %{"headline" => "Test Portal"},
        "features" => %{
          "customer_update" => %{"enabled" => true, "allowed_updates" => ["email"]},
          "invoice_history" => %{"enabled" => true},
          "payment_method_update" => %{"enabled" => false},
          "subscription_cancel" => %{"enabled" => false},
          "subscription_update" => %{"enabled" => false, "default_allowed_updates" => [],
                                     "products" => [], "proration_behavior" => "none"}
        }
      })

    assert is_binary(id)
    assert {:ok, %Configuration{id: ^id}} = Configuration.retrieve(client, id)
    assert {:ok, %Configuration{}} = Configuration.update(client, id, %{"name" => "Updated"})
    {:ok, list_resp} = Configuration.list(client)
    assert is_list(list_resp.data.data)
  end
end
```

### ObjectTypes Registration
```elixir
# Source: Verified from lib/lattice_stripe/object_types.ex (lines 31-34 show existing pattern)
# ADD this entry to @object_map in lib/lattice_stripe/object_types.ex:
"billing_portal.configuration" => LatticeStripe.BillingPortal.Configuration,
# Place near existing "billing_portal.session" entry for readability
```

### Session.configuration Expand Guard
```elixir
# Source: Verified from lib/lattice_stripe/invoice.ex lines 947-950 (charge field pattern)
# In BillingPortal.Session.from_map/1:
configuration:
  (if is_map(known["configuration"]),
     do: ObjectTypes.maybe_deserialize(known["configuration"]),
     else: known["configuration"]),
```

---

## Test Fixture Requirements

### Configuration.basic/1 fixture (to add to test/support/fixtures/billing_portal.ex)
```elixir
defmodule LatticeStripe.Test.Fixtures.BillingPortal.Configuration do
  def basic(overrides \\ %{}) do
    %{
      "id" => "bpc_123",
      "object" => "billing_portal.configuration",
      "active" => true,
      "application" => nil,
      "business_profile" => %{
        "headline" => nil,
        "privacy_policy_url" => nil,
        "terms_of_service_url" => nil
      },
      "created" => 1_712_345_678,
      "default_return_url" => nil,
      "features" => %{
        "customer_update" => %{"allowed_updates" => [], "enabled" => false},
        "invoice_history" => %{"enabled" => true},
        "payment_method_update" => %{"enabled" => false, "payment_method_configuration" => nil},
        "subscription_cancel" => %{
          "cancellation_reason" => %{"enabled" => false, "options" => []},
          "enabled" => false,
          "mode" => "at_period_end",
          "proration_behavior" => "none"
        },
        "subscription_update" => %{
          "billing_cycle_anchor" => nil,
          "default_allowed_updates" => [],
          "enabled" => false,
          "products" => [],
          "proration_behavior" => "none",
          "schedule_at_period_end" => nil,
          "trial_update_behavior" => nil
        }
      },
      "is_default" => false,
      "livemode" => false,
      "login_page" => %{"enabled" => false, "url" => nil},
      "metadata" => %{},
      "name" => nil,
      "updated" => 1_712_345_678
    }
    |> Map.merge(overrides)
  end
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Map.drop(map, @known_fields)` in from_map/1 | `{known, extra} = Map.split(map, @known_fields)` | Phase 22 | New modules must use Map.split; old modules (Session) use drop and don't need migration |
| Direct `map["field"]` access in from_map/1 | `known["field"]` after Map.split | Phase 22 | Same implication — follow new pattern |
| `configuration: String.t() \| nil` on Session | `configuration: Configuration.t() \| String.t() \| nil` | Phase 23 (this phase) | Additive type widening; backward compatible (non-expanded remains string) |

**Deprecated/outdated:**
- `BillingPortal.Session.@moduledoc` reference to "planned for v1.2+": remove and replace with reference to the new `Configuration` module.

---

## File Change Summary

### New Files (7)
| File | Type | Description |
|------|------|-------------|
| `lib/lattice_stripe/billing_portal/configuration.ex` | New | Top-level CRUDL resource module |
| `lib/lattice_stripe/billing_portal/configuration/features.ex` | New | Features container Level 1 |
| `lib/lattice_stripe/billing_portal/configuration/features/subscription_cancel.ex` | New | Level 2 sub-struct |
| `lib/lattice_stripe/billing_portal/configuration/features/subscription_update.ex` | New | Level 2 sub-struct |
| `lib/lattice_stripe/billing_portal/configuration/features/customer_update.ex` | New | Level 2 sub-struct |
| `lib/lattice_stripe/billing_portal/configuration/features/payment_method_update.ex` | New | Level 2 sub-struct |
| `test/integration/billing_portal_configuration_integration_test.exs` | New | Integration test |

### Modified Files (4)
| File | Change |
|------|--------|
| `lib/lattice_stripe/object_types.ex` | Add `"billing_portal.configuration"` entry to `@object_map` |
| `lib/lattice_stripe/billing_portal/session.ex` | Add expand guard on `configuration` field + update `@type t` + update `@moduledoc` |
| `test/support/fixtures/billing_portal.ex` | Add `Configuration` fixture submodule |
| `mix.exs` | Add 6 Configuration modules to "Customer Portal" `groups_for_modules` list |

### New Test Files (multiple)
Unit tests for each new module:
- `test/lattice_stripe/billing_portal/configuration_test.exs`
- `test/lattice_stripe/billing_portal/configuration/features_test.exs`
- `test/lattice_stripe/billing_portal/configuration/features/subscription_cancel_test.exs`
- `test/lattice_stripe/billing_portal/configuration/features/subscription_update_test.exs`
- `test/lattice_stripe/billing_portal/configuration/features/customer_update_test.exs`
- `test/lattice_stripe/billing_portal/configuration/features/payment_method_update_test.exs`
- Session test modification: add expand guard test to `test/lattice_stripe/billing_portal/session_test.exs`

---

## Environment Availability

Step 2.6: Checked. stripe-mock must be running for integration tests.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| stripe-mock | Integration tests | ✓ (assumed running per project CI) | latest | Unit tests (Mox) cover all non-integration paths |
| Elixir/OTP | All | ✓ | 1.15+ per project | — |

**Missing dependencies with no fallback:** None — integration tests skip if stripe-mock not running (TCP check pattern from existing integration tests).

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/billing_portal/ --no-start` |
| Full suite command | `mix test --no-start` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FEAT-01 | `create/3` returns `{:ok, %Configuration{}}` | unit | `mix test test/lattice_stripe/billing_portal/configuration_test.exs -x` | ❌ Wave 0 |
| FEAT-01 | `retrieve/3` returns typed struct | unit | `mix test test/lattice_stripe/billing_portal/configuration_test.exs -x` | ❌ Wave 0 |
| FEAT-01 | `update/4` returns typed struct | unit | `mix test test/lattice_stripe/billing_portal/configuration_test.exs -x` | ❌ Wave 0 |
| FEAT-01 | `list/2` returns `{:ok, %Response{data: %List{}}}` | unit | `mix test test/lattice_stripe/billing_portal/configuration_test.exs -x` | ❌ Wave 0 |
| FEAT-01 | `stream!/2` emits `%Configuration{}` items | unit | `mix test test/lattice_stripe/billing_portal/configuration_test.exs -x` | ❌ Wave 0 |
| FEAT-01 | `features` decoded into `%Features{}` | unit | `mix test test/lattice_stripe/billing_portal/configuration/features_test.exs -x` | ❌ Wave 0 |
| FEAT-01 | Level 2 sub-structs decode correctly | unit | sub-struct test files | ❌ Wave 0 |
| FEAT-01 | Level 3+ fields in struct (not dropped) | unit | sub-struct test files | ❌ Wave 0 |
| FEAT-01 | Unknown keys captured in `extra` | unit | `from_map/1` tests | ❌ Wave 0 |
| FEAT-01 | Integration: create → retrieve → update → list via stripe-mock | integration | `mix test test/integration/billing_portal_configuration_integration_test.exs` | ❌ Wave 0 |
| D-03 | Session.configuration decoded as `%Configuration{}` when expanded | unit | `test/lattice_stripe/billing_portal/session_test.exs` | ❌ Wave 0 (new test in existing file) |
| D-03 | Session.configuration remains string when not expanded | unit | `test/lattice_stripe/billing_portal/session_test.exs` | ❌ Wave 0 (new test in existing file) |

### Sampling Rate
- **Per task commit:** `mix test test/lattice_stripe/billing_portal/ --no-start`
- **Per wave merge:** `mix test --no-start`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] All new test files listed above (11 new files)
- [ ] Fixture additions to `test/support/fixtures/billing_portal.ex`

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth handled here — API key lives in Client |
| V3 Session Management | no | Portal session lifecycle is Stripe-side; no server-side session state in SDK |
| V4 Access Control | no | SDK sends requests; access control is Stripe API key scoping |
| V5 Input Validation | yes | No required params for Configuration (unlike Session which requires `customer`); no pre-flight guard needed per D-02 |
| V6 Cryptography | no | No crypto operations |

**Inspect masking consideration:** The `BillingPortal.Configuration` object contains `metadata` and `name` — neither is a bearer credential or PII in the Session sense. No custom `Inspect` implementation is required (unlike Session which masks `:url`). The default struct inspect is appropriate.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | stripe-mock correctly responds to `/v1/billing_portal/configurations` CRUDL endpoints | Integration test section | Integration tests fail; would need `@tag :skip` and manual verification with real Stripe test key |
| A2 | `payment_method_configuration` field on `payment_method_update` is nullable string (not expandable) | Features verified fields table | If expandable, would need ObjectTypes entry and expand guard on PaymentMethodUpdate |

---

## Open Questions

1. **Does stripe-mock support BillingPortal Configuration endpoints?**
   - What we know: stripe-mock is based on Stripe's OpenAPI spec; Configuration CRUD is a standard Stripe v1 endpoint
   - What's unclear: Specific stripe-mock version in CI may lag behind Stripe's OpenAPI spec additions
   - Recommendation: Include TCP check in integration test (existing pattern); if stripe-mock returns 404 on first test run, add `@tag :skip` and note for manual verification

2. **Session.from_map uses Map.drop not Map.split — should it be migrated?**
   - What we know: Phase 22 standardized on Map.split; Session.from_map currently uses `Map.drop(map, @known_fields)` with direct `map["configuration"]` access
   - What's unclear: Whether D-03 changes require migrating Session's full from_map/1 to Map.split or just patching the configuration field
   - Recommendation: Minimal patch only — change `configuration: map["configuration"]` to the expand guard pattern; leave existing `Map.drop` pattern intact in Session to minimize diff size and regression risk

---

## Sources

### Primary (HIGH confidence)
- `lib/lattice_stripe/billing_portal/session.ex` — Session namespace patterns, defstruct, from_map/1, Inspect impl [VERIFIED: read directly]
- `lib/lattice_stripe/billing_portal/session/flow_data.ex` — Parent + N typed children dispatch pattern [VERIFIED: read directly]
- `lib/lattice_stripe/billing_portal/session/flow_data/subscription_cancel.ex` — Leaf sub-struct with Level 3+ raw map field pattern [VERIFIED: read directly]
- `lib/lattice_stripe/customer.ex` — Full CRUDL + stream! + bang variants reference [VERIFIED: read directly]
- `lib/lattice_stripe/object_types.ex` — ObjectTypes @object_map and maybe_deserialize/1 [VERIFIED: read directly]
- `lib/lattice_stripe/invoice.ex` — ObjectTypes.maybe_deserialize expand guard pattern on `charge` and `customer` fields [VERIFIED: read directly]
- `mix.exs` lines 87–94 — "Customer Portal" ExDoc group (current modules listed) [VERIFIED: read directly]
- `test/support/fixtures/billing_portal.ex` — Existing Session fixture pattern [VERIFIED: read directly]
- `test/integration/billing_portal_session_integration_test.exs` — Integration test setup pattern [VERIFIED: read directly]
- `test/lattice_stripe/billing_portal/session_test.exs` — Mox-based unit test pattern [VERIFIED: read directly]
- `.planning/research/PITFALLS.md` Pitfall 8 — Nesting depth cap at 6 modules, Level 3+ as maps [VERIFIED: read directly]
- `.planning/research/ARCHITECTURE.md` Section 8 — BillingPortal.Configuration integration analysis [VERIFIED: read directly]

### Secondary (MEDIUM confidence)
- [Stripe BillingPortal Configuration object](https://docs.stripe.com/api/customer_portal/configurations/object) — All top-level and nested field names and types [VERIFIED: WebFetch 2026-04-16]
- [Stripe BillingPortal Configuration list](https://docs.stripe.com/api/customer_portal/configurations/list) — List endpoint parameters [VERIFIED: WebFetch 2026-04-16]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps; all patterns verified from existing codebase
- Architecture: HIGH — verified from ARCHITECTURE.md + direct codebase reads
- Stripe API fields: HIGH — verified from official Stripe docs 2026-04-16
- Pitfalls: HIGH — verified from PITFALLS.md (Pitfall 8 specifically for this phase)

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 (Stripe API field shapes are stable; patterns are internal and stable)
