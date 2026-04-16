# Phase 29: Changeset-Style Param Builders - Research

**Researched:** 2026-04-16
**Domain:** Elixir fluent builder pattern, SubscriptionSchedule params, BillingPortal FlowData params
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01 (Builder API Style):** Pipe-based changeset style (`|>` chains) with data-first functions. Start with `new/0`, chain setter functions, end with `build/1` returning a plain map. Idiomatic Elixir pattern (Ecto, Ash, Req).
- **D-02 (Output Format):** `build/1` returns a plain string-keyed `map()` — not `{:ok, map}`, not a struct. Output passed directly to existing resource functions. No validation in builders — existing guards handle validation at the resource layer.
- **D-03 (Module Structure):** Two primary builder modules in `lib/lattice_stripe/builders/`:
  - `LatticeStripe.Builders.SubscriptionSchedule` — schedule creation params + phase construction helpers
  - `LatticeStripe.Builders.BillingPortal` — FlowData construction for portal session creation
  Phase/item sub-builders are nested functions or inner-module helpers within the parent — no full sub-module hierarchy.
- **D-04 (Scope):** "BillingPortal flows" means FlowData only — not Configuration params. Configuration params (`business_profile`, `features`) are simpler maps that don't need builder assistance.

### Claude's Discretion

- Exact function names for setter functions (e.g., `customer/2` vs `set_customer/2`)
- Whether `add_phase/2` accepts a sub-builder struct or a map (recommend sub-builder for consistency)
- Internal representation — opaque struct or map accumulator during the chain
- Whether to provide convenience constructors like `Phase.with_price/2` for common patterns
- `@moduledoc` and `@doc` wording for the "optional" messaging
- Test strategy — unit tests asserting `build/1` produces correct map shapes

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DX-03 | Developer can use optional changeset-style param builders for complex nested params (scoped to SubscriptionSchedule phases and BillingPortal flows) | Builder API design, module structure, integration points with existing resource modules and guards |

</phase_requirements>

---

## Summary

Phase 29 introduces a fluent builder layer on top of the existing string-keyed map API. The pattern is additive only — builders produce plain string-keyed maps that flow directly into the existing `SubscriptionSchedule.create/3` and `BillingPortal.Session.create/3` functions. No changes to resource modules are required.

The existing codebase gives us two clear targets. For SubscriptionSchedule, the `Phase` struct (`lib/lattice_stripe/subscription_schedule/phase.ex`) defines exactly 23 fields that map 1:1 to builder setter functions. The `PhaseItem` and `AddInvoiceItem` sub-modules provide the field lists for nested item builders. For BillingPortal, four `FlowData` types (subscription_cancel, subscription_update, subscription_update_confirm, payment_method_update) drive four named constructor functions, each producing the exact nested shape that `Guards.check_flow_data!/1` validates.

The internal representation decision (opaque struct vs. map accumulator) is Claude's discretion. Given that the output must be a plain string-keyed map and `build/1` is a required terminal step, an opaque struct accumulator is the better choice — it prevents the intermediate value from being passed by mistake before `build/1` is called, gives clearer error messages if someone tries `IO.inspect` mid-chain, and makes the builder's contract unambiguous. The `@moduledoc` must clearly mark both modules as optional companions to the map API.

**Primary recommendation:** Implement both builder modules using an opaque `%__MODULE__{}` accumulator struct, short function names (no `set_` prefix, Elixir convention), and a `build/1` terminal that emits a string-keyed map. Add a "Param Builders" group in `mix.exs` ExDoc groups.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Builder API (SubscriptionSchedule) | Library layer (new `builders/` namespace) | — | Pure data construction; no HTTP, no process state; stays in-process at the caller's request site |
| Builder API (BillingPortal FlowData) | Library layer (new `builders/` namespace) | — | Same as above; produces a string-keyed map fragment for `params["flow_data"]` |
| Validation of builder output | Existing resource layer (`BillingPortal.Guards`, `Billing.Guards`) | — | Guards already live at the resource boundary; builders deliberately omit validation per D-02 |
| ExDoc grouping | Build-time (`mix.exs`) | — | Additive groups_for_modules entry; no runtime impact |

## Standard Stack

### Core

No new dependencies are required. Phase 29 is pure Elixir using stdlib data structures.

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir stdlib (Map, List) | built-in | Accumulator struct construction, `Map.put/3`, `Map.reject/2` | No deps; builders are pure data transformation |
| ExUnit | built-in | Test assertions on `build/1` output shape | Standard test framework already in use |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| (none) | — | — | — |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Opaque accumulator struct | Plain map accumulator | A plain map accumulator allows partial results to be passed to resource functions by mistake (no `build/1` terminal check distinguishes it from a completed map). Struct makes the "you must call `build/1`" contract visible. |
| Short setter names (`customer/2`) | `set_customer/2` prefix | `set_` prefix is rare in idiomatic Elixir (Ecto uses `put_assoc`, `change`, `cast` without prefix). Short names read more naturally in pipes. |
| Nested functions/helpers in parent module | Full sub-module (`Builders.SubscriptionSchedule.Phase`) | Sub-modules add ceremony for a thin builder. The parent module's `phase_new/0`, `phase_items/2`, `phase_build/1` naming convention keeps everything in one place per D-03. |

**Installation:** No new packages required.

## Architecture Patterns

### System Architecture Diagram

```
Developer call site
       |
       | new/0
       v
%Builders.SubscriptionSchedule{} (opaque accumulator)
       |
       | customer/2, start_date/2, end_behavior/2, add_phase/2 ...
       v
%Builders.SubscriptionSchedule{} (fields accumulated)
       |
       | build/1
       v
%{"customer" => ..., "phases" => [...], ...}   ← plain string-keyed map
       |
       | SubscriptionSchedule.create(client, map)
       v
HTTP POST /v1/subscription_schedules
       |
       v
{:ok, %LatticeStripe.SubscriptionSchedule{}} | {:error, %Error{}}


Phase sub-builder (nested within parent module):

phase_new/0  -->  %Phase{} accumulator  -->  [setter fns]  -->  phase_build/1  -->  plain map
                                                                    ↑
                                              passed to add_phase/2 on parent builder


BillingPortal FlowData builder:

subscription_cancel(sub_id)        --> %{"type" => "subscription_cancel", "subscription_cancel" => %{"subscription" => sub_id}}
subscription_update(sub_id)        --> %{"type" => "subscription_update", "subscription_update" => %{"subscription" => sub_id}}
subscription_update_confirm(...)   --> %{"type" => "subscription_update_confirm", ...}
payment_method_update()            --> %{"type" => "payment_method_update"}
                                         ↓
               placed in params["flow_data"] key  -->  BillingPortal.Session.create/3
                                         ↓
               Guards.check_flow_data!/1 validates shape pre-network
```

### Recommended Project Structure

```
lib/
└── lattice_stripe/
    └── builders/
        ├── subscription_schedule.ex   # LatticeStripe.Builders.SubscriptionSchedule
        └── billing_portal.ex          # LatticeStripe.Builders.BillingPortal

test/
└── lattice_stripe/
    └── builders/
        ├── subscription_schedule_test.exs
        └── billing_portal_test.exs
```

No sub-module hierarchy below `builders/` per D-03. Phase/item builders are functions within `subscription_schedule.ex` with a naming convention (`phase_new/0`, `phase_items/2`, `phase_build/1`).

### Pattern 1: Opaque Accumulator Struct + Pipe Chain

**What:** Each builder module defines a `defstruct` with atom-keyed fields (nil defaults) for the accumulator. Setter functions update the struct. `build/1` converts the accumulated struct to a string-keyed map, dropping nil fields (Stripe ignores absent keys — sending `"iterations" => nil` is noise).

**When to use:** Any builder where callers must call a terminal function before use. Prevents partial-map footguns.

```elixir
# Source: [ASSUMED] — idiomatic Elixir builder pattern (Ecto.Changeset, Req.new/1 model)
defmodule LatticeStripe.Builders.SubscriptionSchedule do
  @moduledoc """
  Optional fluent builder for `LatticeStripe.SubscriptionSchedule` creation params.

  **This builder is optional.** You may pass plain maps directly to
  `SubscriptionSchedule.create/3` — the builder is a convenience for complex
  multi-phase schedules where nested key typos are a common source of errors.

  ## Usage

      params =
        LatticeStripe.Builders.SubscriptionSchedule.new()
        |> LatticeStripe.Builders.SubscriptionSchedule.customer("cus_123")
        |> LatticeStripe.Builders.SubscriptionSchedule.start_date("now")
        |> LatticeStripe.Builders.SubscriptionSchedule.end_behavior(:release)
        |> LatticeStripe.Builders.SubscriptionSchedule.add_phase(
             LatticeStripe.Builders.SubscriptionSchedule.phase_new()
             |> LatticeStripe.Builders.SubscriptionSchedule.phase_items([
                  %{"price" => "price_123", "quantity" => 1}
                ])
             |> LatticeStripe.Builders.SubscriptionSchedule.phase_iterations(12)
             |> LatticeStripe.Builders.SubscriptionSchedule.phase_proration_behavior(:create_prorations)
             |> LatticeStripe.Builders.SubscriptionSchedule.phase_build()
           )
        |> LatticeStripe.Builders.SubscriptionSchedule.build()

      {:ok, schedule} = LatticeStripe.SubscriptionSchedule.create(client, params)
  """

  @opaque t :: %__MODULE__{}
  @opaque phase_t :: %__MODULE__.Phase{}

  defstruct [
    :customer,
    :from_subscription,
    :start_date,
    :end_behavior,
    phases: []
  ]

  defmodule Phase do
    @moduledoc false
    defstruct [
      :iterations,
      :proration_behavior,
      :billing_cycle_anchor,
      :collection_method,
      :currency,
      :default_payment_method,
      :description,
      :end_date,
      :metadata,
      :on_behalf_of,
      :trial_continuation,
      :trial_end,
      items: [],
      add_invoice_items: []
    ]
  end

  @spec new() :: t()
  def new(), do: %__MODULE__{}

  @spec customer(t(), String.t()) :: t()
  def customer(%__MODULE__{} = b, cus_id) when is_binary(cus_id),
    do: %{b | customer: cus_id}

  # ... other setters

  @spec add_phase(t(), map()) :: t()
  def add_phase(%__MODULE__{} = b, phase_map) when is_map(phase_map),
    do: %{b | phases: b.phases ++ [phase_map]}

  @spec build(t()) :: map()
  def build(%__MODULE__{} = b) do
    %{
      "customer" => b.customer,
      "from_subscription" => b.from_subscription,
      "start_date" => stringify_date(b.start_date),
      "end_behavior" => to_string_if_atom(b.end_behavior),
      "phases" => b.phases
    }
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
    |> then(fn m ->
      if b.phases == [], do: Map.delete(m, "phases"), else: m
    end)
  end

  # Phase sub-builder
  @spec phase_new() :: phase_t()
  def phase_new(), do: %Phase{}

  @spec phase_items(phase_t(), [map()]) :: phase_t()
  def phase_items(%Phase{} = p, items) when is_list(items), do: %{p | items: items}

  @spec phase_iterations(phase_t(), pos_integer()) :: phase_t()
  def phase_iterations(%Phase{} = p, n) when is_integer(n) and n > 0, do: %{p | iterations: n}

  @spec phase_proration_behavior(phase_t(), atom() | String.t()) :: phase_t()
  def phase_proration_behavior(%Phase{} = p, pb), do: %{p | proration_behavior: pb}

  @spec phase_build(phase_t()) :: map()
  def phase_build(%Phase{} = p) do
    %{
      "items" => (if p.items == [], do: nil, else: p.items),
      "add_invoice_items" => (if p.add_invoice_items == [], do: nil, else: p.add_invoice_items),
      "iterations" => p.iterations,
      "proration_behavior" => to_string_if_atom(p.proration_behavior),
      "billing_cycle_anchor" => p.billing_cycle_anchor,
      "collection_method" => p.collection_method,
      "currency" => p.currency,
      "default_payment_method" => p.default_payment_method,
      "description" => p.description,
      "end_date" => p.end_date,
      "metadata" => p.metadata,
      "on_behalf_of" => p.on_behalf_of,
      "trial_continuation" => to_string_if_atom(p.trial_continuation),
      "trial_end" => p.trial_end
    }
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp to_string_if_atom(v) when is_atom(v) and not is_nil(v), do: Atom.to_string(v)
  defp to_string_if_atom(v), do: v

  defp stringify_date(:now), do: "now"
  defp stringify_date(v) when is_integer(v), do: v
  defp stringify_date(v) when is_binary(v), do: v
  defp stringify_date(nil), do: nil
end
```

### Pattern 2: BillingPortal FlowData Named Constructors

**What:** `LatticeStripe.Builders.BillingPortal` exposes one named function per valid `flow_data.type`. Each returns the complete nested map fragment for use in `params["flow_data"]`. No accumulator needed — FlowData params are small and determined by type selection, not composition.

**When to use:** The caller knows the flow type upfront. One call produces the complete `flow_data` map fragment.

```elixir
# Source: [ASSUMED] — derived from Guards.check_flow_data!/1 shape requirements
defmodule LatticeStripe.Builders.BillingPortal do
  @moduledoc """
  Optional fluent builders for `LatticeStripe.BillingPortal.Session` flow_data params.

  **This builder is optional.** You may pass the `"flow_data"` map directly to
  `BillingPortal.Session.create/3`. These helpers prevent typos in deeply nested
  FlowData keys and document required sub-fields inline.

  ## Usage

      flow = LatticeStripe.Builders.BillingPortal.subscription_cancel("sub_abc")

      {:ok, session} = LatticeStripe.BillingPortal.Session.create(client, %{
        "customer" => "cus_123",
        "flow_data" => flow
      })
  """

  @doc """
  Builds a `flow_data` map for the `subscription_cancel` flow.

  Required: `subscription` — the Stripe subscription ID (`sub_*`) to pre-fill.
  Optional: `retention` — a Stripe retention object map (e.g. `%{"type" => "coupon_offer", ...}`).
  Optional: `after_completion` — map describing what happens after the customer completes the flow.
  """
  @spec subscription_cancel(String.t(), keyword()) :: map()
  def subscription_cancel(subscription_id, opts \\ []) when is_binary(subscription_id) do
    sub_cancel = %{"subscription" => subscription_id}
    sub_cancel = if opts[:retention], do: Map.put(sub_cancel, "retention", opts[:retention]), else: sub_cancel

    base = %{
      "type" => "subscription_cancel",
      "subscription_cancel" => sub_cancel
    }
    if opts[:after_completion],
      do: Map.put(base, "after_completion", opts[:after_completion]),
      else: base
  end

  @doc """
  Builds a `flow_data` map for the `subscription_update` flow.

  Required: `subscription` — the Stripe subscription ID to deep-link into.
  Optional: `after_completion` — post-flow redirect/confirmation config.
  """
  @spec subscription_update(String.t(), keyword()) :: map()
  def subscription_update(subscription_id, opts \\ []) when is_binary(subscription_id) do
    base = %{
      "type" => "subscription_update",
      "subscription_update" => %{"subscription" => subscription_id}
    }
    if opts[:after_completion],
      do: Map.put(base, "after_completion", opts[:after_completion]),
      else: base
  end

  @doc """
  Builds a `flow_data` map for the `subscription_update_confirm` flow.

  Required: `subscription` — the Stripe subscription ID.
  Required: `items` — non-empty list of subscription item change maps.
  Optional: `discounts` — list of discount maps to apply.
  Optional: `after_completion` — post-flow redirect/confirmation config.
  """
  @spec subscription_update_confirm(String.t(), [map()], keyword()) :: map()
  def subscription_update_confirm(subscription_id, items, opts \\ [])
      when is_binary(subscription_id) and is_list(items) and items != [] do
    sub_confirm = %{"subscription" => subscription_id, "items" => items}
    sub_confirm = if opts[:discounts], do: Map.put(sub_confirm, "discounts", opts[:discounts]), else: sub_confirm

    base = %{
      "type" => "subscription_update_confirm",
      "subscription_update_confirm" => sub_confirm
    }
    if opts[:after_completion],
      do: Map.put(base, "after_completion", opts[:after_completion]),
      else: base
  end

  @doc """
  Builds a `flow_data` map for the `payment_method_update` flow.

  No required sub-fields. Optional: `after_completion`.
  """
  @spec payment_method_update(keyword()) :: map()
  def payment_method_update(opts \\ []) do
    base = %{"type" => "payment_method_update"}
    if opts[:after_completion],
      do: Map.put(base, "after_completion", opts[:after_completion]),
      else: base
  end
end
```

### Pattern 3: ExDoc Group Registration

**What:** Add a "Param Builders" group to `mix.exs` `groups_for_modules:` list.

**When to use:** When new module namespace is added that needs its own ExDoc section.

```elixir
# Source: [VERIFIED: mix.exs lines 51-170]
# Add after the existing "Internals" group:
"Param Builders": [
  LatticeStripe.Builders.SubscriptionSchedule,
  LatticeStripe.Builders.BillingPortal
]
```

### Anti-Patterns to Avoid

- **Returning `{:ok, map}` from `build/1`:** D-02 locked this — plain map only. Callers pipe directly to resource functions without an extra `with` unwrap.
- **Validating in builders:** D-02 locked this — builders are dumb constructors. Guards at the resource layer handle correctness. Adding validation to builders would duplicate guard logic and create a maintenance split.
- **Atom-keyed output from `build/1`:** The entire SDK uses string-keyed maps (Stripe wire format). Builders must output string keys. `%{"type" => "subscription_cancel"}` not `%{type: :subscription_cancel}`.
- **Sending `nil` values to Stripe:** `build/1` must strip nil fields via `Map.reject(fn {_k, v} -> is_nil(v) end)` before returning. Stripe ignores absent keys but may return 400 on explicitly sent `nil` for some fields.
- **Building `from_subscription` + `customer` in same schedule builder call:** Stripe 400s on this combination. The builder does not validate this (per D-02) — Stripe's error is actionable. Document this in `@moduledoc`.
- **Atom values in output maps:** Stripe API does not understand atoms. `build/1` must convert all atom values (`:release`, `:create_prorations`, `:now`) to their string equivalents before output.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| FlowData structure validation | Custom validator in builder | `BillingPortal.Guards.check_flow_data!/1` (already exists) | Guards already validate builder output at the resource boundary — no duplication needed |
| Proration validation in schedule builder | Custom proration check | `Billing.Guards.check_proration_required/2` (already exists) | Same reason — builder output goes through the existing guard |
| Type-safe param schemas | NimbleOptions schema in builders | (no NimbleOptions needed) | Builders are ultra-thin map constructors; the struct accumulator gives enough type safety for IDE support and error messages |

**Key insight:** The guards at the resource layer are the validation contract. Builders are constructors only — they prevent typos in key strings, not in values. This separation means builders need zero validation logic.

## Common Pitfalls

### Pitfall 1: Atom Values Not Stringified in `build/1`
**What goes wrong:** `phase_build/1` emits `%{"proration_behavior" => :create_prorations}` (atom). Stripe receives `"create_prorations"` in JSON, but if Jason isn't configured to encode atom values as strings, this is a silent bug.
**Why it happens:** Setter functions accept `atom() | String.t()` for ergonomics, but the Stripe wire format requires strings.
**How to avoid:** All atom values must be converted to strings in `build/1` / `phase_build/1` using `Atom.to_string/1`. Add a private `to_string_if_atom/1` helper in each builder module.
**Warning signs:** Stripe returning 400 with "invalid enum value" on `proration_behavior` or `end_behavior`.

### Pitfall 2: Sending Nil Fields to Stripe
**What goes wrong:** `build/1` emits `%{"iterations" => nil, "proration_behavior" => nil, ...}`. Stripe may 400 on fields it doesn't accept as null.
**Why it happens:** The accumulator struct initializes all fields to nil.
**How to avoid:** `Map.reject(fn {_k, v} -> is_nil(v) end)` as final step in `build/1` and `phase_build/1`. Also reject empty lists where applicable.
**Warning signs:** Unexpected Stripe 400 on valid-looking params; integration tests passing but unit tests emitting unexpected keys.

### Pitfall 3: `add_phase/2` Accepting a Phase Struct Instead of a Map
**What goes wrong:** If `add_phase/2` accepts the `%Phase{}` accumulator directly (without calling `phase_build/1` first), the struct lands in the output map and Jason fails to encode it.
**Why it happens:** The sub-builder accumulator is a struct, not a map.
**How to avoid:** Two options: (a) `add_phase/2` only accepts `map()` — caller must call `phase_build/1` first. (b) `add_phase/2` accepts either and calls `phase_build/1` internally. Option (a) is simpler but more explicit; option (b) is more ergonomic. Claude's discretion — recommend option (b) with a guard `when is_map(phase_map) or is_struct(phase_map, Phase)`.
**Warning signs:** Jason encode errors at runtime; tests passing with maps but failing with structs.

### Pitfall 4: `subscription_update_confirm/3` Allows Empty Items List
**What goes wrong:** `subscription_update_confirm("sub_123", [])` produces a map with `"items" => []`. `Guards.check_flow_data!/1` raises `ArgumentError` — non-empty items is required.
**Why it happens:** The guard enforces `items != []` but the builder doesn't.
**How to avoid:** Add a guard `when items != []` on the function signature or raise a clear `ArgumentError` in the function body. This is one case where the builder CAN do pre-validation without duplicating guard logic — the guard is at the resource layer, but the builder can fail-fast on structurally invalid input. Recommend a guard clause.
**Warning signs:** `ArgumentError` from `Guards.check_flow_data!/1` when items is empty; confusing error message since the guard mentions `Session.create/3` not the builder.

### Pitfall 5: Module Name Collision with Existing Resource Modules
**What goes wrong:** `LatticeStripe.Builders.SubscriptionSchedule` vs `LatticeStripe.SubscriptionSchedule` — if code aliases both in the same module without explicit aliasing, Elixir warns about name collision.
**Why it happens:** Both have `SubscriptionSchedule` as the last segment.
**How to avoid:** In builder module docs and examples, show explicit module paths or `alias LatticeStripe.Builders.SubscriptionSchedule, as: SSBuilder`. Mention this in `@moduledoc`.
**Warning signs:** Elixir compiler warnings about ambiguous alias; tests that alias both at once failing.

## Code Examples

Verified patterns from official sources:

### Complete SubscriptionSchedule Builder Usage
```elixir
# Source: [ASSUMED] — derived from SubscriptionSchedule.create/3 param shapes in
# lib/lattice_stripe/subscription_schedule.ex and Phase struct fields in
# lib/lattice_stripe/subscription_schedule/phase.ex
alias LatticeStripe.Builders.SubscriptionSchedule, as: SSBuilder

params =
  SSBuilder.new()
  |> SSBuilder.customer("cus_1234567890")
  |> SSBuilder.start_date("now")
  |> SSBuilder.end_behavior(:release)
  |> SSBuilder.add_phase(
       SSBuilder.phase_new()
       |> SSBuilder.phase_items([%{"price" => "price_abc", "quantity" => 1}])
       |> SSBuilder.phase_iterations(12)
       |> SSBuilder.phase_proration_behavior(:create_prorations)
       |> SSBuilder.phase_build()
     )
  |> SSBuilder.build()

# params == %{
#   "customer" => "cus_1234567890",
#   "start_date" => "now",
#   "end_behavior" => "release",
#   "phases" => [%{"items" => [...], "iterations" => 12, "proration_behavior" => "create_prorations"}]
# }

{:ok, schedule} = LatticeStripe.SubscriptionSchedule.create(client, params)
```

### BillingPortal FlowData Builder Usage
```elixir
# Source: [VERIFIED: lib/lattice_stripe/billing_portal/guards.ex] — exact shape required by
# Guards.check_flow_data!/1 for each flow type
alias LatticeStripe.Builders.BillingPortal, as: BPBuilder

# subscription_cancel
flow = BPBuilder.subscription_cancel("sub_abc")
# => %{"type" => "subscription_cancel", "subscription_cancel" => %{"subscription" => "sub_abc"}}

# subscription_update
flow = BPBuilder.subscription_update("sub_abc")
# => %{"type" => "subscription_update", "subscription_update" => %{"subscription" => "sub_abc"}}

# subscription_update_confirm (items required, non-empty)
flow = BPBuilder.subscription_update_confirm("sub_abc", [
  %{"id" => "si_abc", "price" => "price_new"}
])
# => %{"type" => "subscription_update_confirm",
#      "subscription_update_confirm" => %{"subscription" => "sub_abc", "items" => [...]}}

# payment_method_update (no required sub-fields)
flow = BPBuilder.payment_method_update()
# => %{"type" => "payment_method_update"}

# usage with Session.create/3
{:ok, session} = LatticeStripe.BillingPortal.Session.create(client, %{
  "customer" => "cus_123",
  "flow_data" => flow
})
```

### Test Pattern for Builder Output
```elixir
# Source: [VERIFIED: test/lattice_stripe/subscription_schedule_test.exs and
# test/lattice_stripe/billing_portal/guards_test.exs] — existing test style
defmodule LatticeStripe.Builders.SubscriptionScheduleTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Builders.SubscriptionSchedule, as: SSBuilder

  describe "build/1" do
    test "customer-mode schedule with one phase" do
      params =
        SSBuilder.new()
        |> SSBuilder.customer("cus_123")
        |> SSBuilder.end_behavior(:release)
        |> SSBuilder.add_phase(
             SSBuilder.phase_new()
             |> SSBuilder.phase_items([%{"price" => "price_abc", "quantity" => 1}])
             |> SSBuilder.phase_iterations(12)
             |> SSBuilder.phase_build()
           )
        |> SSBuilder.build()

      assert params["customer"] == "cus_123"
      assert params["end_behavior"] == "release"
      assert [phase] = params["phases"]
      assert phase["iterations"] == 12
      assert [%{"price" => "price_abc", "quantity" => 1}] = phase["items"]
    end

    test "nil fields are omitted from build/1 output" do
      params = SSBuilder.new() |> SSBuilder.customer("cus_123") |> SSBuilder.build()
      refute Map.has_key?(params, "from_subscription")
      refute Map.has_key?(params, "start_date")
    end

    test "atom enum values are stringified" do
      params =
        SSBuilder.new()
        |> SSBuilder.end_behavior(:release)
        |> SSBuilder.build()
      assert params["end_behavior"] == "release"
    end
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Plain string-keyed maps for all Stripe params | Plain maps (still valid) + optional builder API | Phase 29 (2026) | Developer choice; builders are additive, not replacing |
| No fluent builder in SDK | `LatticeStripe.Builders.*` namespace | Phase 29 introduces this | Pattern aligns with Ecto.Changeset, Req.new/1 ergonomics |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Opaque struct accumulator is better than map accumulator for internal representation | Architecture Patterns | Low — both approaches work; struct is slightly safer ergonomically but either can be implemented quickly |
| A2 | Short setter names without `set_` prefix (e.g., `customer/2` not `set_customer/2`) are idiomatic Elixir | Anti-Patterns | Low — purely a naming convention; either is clear |
| A3 | `phase_build/1` should accept either a `%Phase{}` accumulator or a plain map in `add_phase/2` (option b recommendation) | Architecture Patterns | Low — option (a) is simpler; both work |
| A4 | `subscription_update_confirm/3` should guard against empty items list at the builder level | Common Pitfalls | Low — the resource guard catches it anyway; builder guard is defense-in-depth but not required |
| A5 | `after_completion` is accepted as an optional keyword argument in BillingPortal builder functions | Code Examples | Low — Stripe docs confirm `after_completion` is valid in flow_data; implementation detail only |

**Items that were directly verified against codebase:**
- Phase struct fields (23 fields): VERIFIED from `lib/lattice_stripe/subscription_schedule/phase.ex`
- PhaseItem fields: VERIFIED from `lib/lattice_stripe/subscription_schedule/phase_item.ex`
- AddInvoiceItem fields: VERIFIED from `lib/lattice_stripe/subscription_schedule/add_invoice_item.ex`
- FlowData type list: VERIFIED from `lib/lattice_stripe/billing_portal/guards.ex` and `flow_data.ex`
- Guard shapes for each flow type: VERIFIED from `lib/lattice_stripe/billing_portal/guards.ex`
- `build/1` must return plain map: VERIFIED from D-02 (CONTEXT.md)
- String-keyed output required: VERIFIED from CLAUDE.md conventions and all existing resource modules
- ExDoc group insertion point: VERIFIED from `mix.exs` lines 51-170

## Open Questions

1. **Should `add_phase/2` accept both `%Phase{}` and `map()` or only `map()`?**
   - What we know: `phase_build/1` converts `%Phase{}` → map. `add_phase/2` stores phases as a list of maps in the output. D-03 says "Phase/item sub-builders are nested functions or inner-module helpers within the parent."
   - What's unclear: Whether callers should always explicitly call `phase_build/1` or whether `add_phase/2` should call it automatically.
   - Recommendation: Accept both and call `phase_build/1` internally on `%Phase{}` inputs — more ergonomic, fewer steps for callers.

2. **Should `Builders.SubscriptionSchedule` support the `from_subscription` mode alongside the `customer + phases` mode?**
   - What we know: `SubscriptionSchedule.create/3` accepts `"from_subscription"` as a mutually exclusive alternative to `"customer" + "phases"`. The builder's `from_subscription/2` setter would simply set that field.
   - What's unclear: Whether providing both setters adds confusion given Stripe's mutual exclusivity.
   - Recommendation: Include `from_subscription/2` as a setter since it's a valid param — document the mutual exclusivity in `@moduledoc`. The builder doesn't validate mode selection (per D-02).

## Environment Availability

Step 2.6: SKIPPED — Phase 29 is purely code/config changes (new Elixir modules + tests). No external dependencies beyond the existing Elixir/OTP runtime.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/builders/ --no-start` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DX-03 | `Builders.SubscriptionSchedule.build/1` produces correct string-keyed map for customer-mode schedule | unit | `mix test test/lattice_stripe/builders/subscription_schedule_test.exs -x` | Wave 0 |
| DX-03 | `Builders.SubscriptionSchedule.phase_build/1` produces correct nested phase map | unit | `mix test test/lattice_stripe/builders/subscription_schedule_test.exs -x` | Wave 0 |
| DX-03 | `Builders.SubscriptionSchedule.build/1` omits nil fields | unit | `mix test test/lattice_stripe/builders/subscription_schedule_test.exs -x` | Wave 0 |
| DX-03 | `Builders.SubscriptionSchedule.build/1` stringifies atom enum values | unit | `mix test test/lattice_stripe/builders/subscription_schedule_test.exs -x` | Wave 0 |
| DX-03 | `Builders.BillingPortal.subscription_cancel/2` produces shape that passes `Guards.check_flow_data!/1` | unit | `mix test test/lattice_stripe/builders/billing_portal_test.exs -x` | Wave 0 |
| DX-03 | `Builders.BillingPortal.subscription_update/2` produces valid shape | unit | `mix test test/lattice_stripe/builders/billing_portal_test.exs -x` | Wave 0 |
| DX-03 | `Builders.BillingPortal.subscription_update_confirm/3` produces valid shape | unit | `mix test test/lattice_stripe/builders/billing_portal_test.exs -x` | Wave 0 |
| DX-03 | `Builders.BillingPortal.payment_method_update/1` produces valid shape | unit | `mix test test/lattice_stripe/builders/billing_portal_test.exs -x` | Wave 0 |
| DX-03 | `Builders.BillingPortal` output can be passed directly to `Session.create/3` (integration) | integration | `mix test test/integration/ -x --only billing_portal` | Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/builders/ --no-start`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/lattice_stripe/builders/subscription_schedule_test.exs` — covers DX-03 (SubscriptionSchedule builder)
- [ ] `test/lattice_stripe/builders/billing_portal_test.exs` — covers DX-03 (BillingPortal builder)
- [ ] `lib/lattice_stripe/builders/` directory — does not exist yet

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | Builders are constructors only; validation lives at resource layer (existing guards) |
| V6 Cryptography | no | — |

**Security note:** Builders do not handle secrets, tokens, or PII. Builder output (plain maps) passes through the existing `BillingPortal.Guards.check_flow_data!/1` and `Billing.Guards.check_proration_required/2` guards at the resource layer — no additional security controls needed in builders themselves.

## Sources

### Primary (HIGH confidence)

- `lib/lattice_stripe/subscription_schedule/phase.ex` — 23 phase fields verified directly; defines all setter functions needed
- `lib/lattice_stripe/subscription_schedule/phase_item.ex` — PhaseItem fields verified
- `lib/lattice_stripe/subscription_schedule/add_invoice_item.ex` — AddInvoiceItem fields verified
- `lib/lattice_stripe/billing_portal/guards.ex` — Guard shapes verified; exact map shapes required for each FlowData type
- `lib/lattice_stripe/billing_portal/session/flow_data.ex` — FlowData polymorphic structure verified
- `lib/lattice_stripe/billing_portal/session/flow_data/subscription_cancel.ex` — subscription + retention fields
- `lib/lattice_stripe/billing_portal/session/flow_data/subscription_update.ex` — subscription field
- `lib/lattice_stripe/billing_portal/session/flow_data/subscription_update_confirm.ex` — subscription + items + discounts fields
- `lib/lattice_stripe/billing_portal/session/flow_data/after_completion.ex` — type + redirect + hosted_confirmation fields
- `mix.exs` lines 51-170 — ExDoc groups structure verified; "Param Builders" insertion point identified
- `CLAUDE.md` — String-keyed params convention, dependency constraints

### Secondary (MEDIUM confidence)

- CONTEXT.md D-01 through D-04 — User decisions verified from discussion session

### Tertiary (LOW confidence)

- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps; pure Elixir stdlib
- Architecture: HIGH — all field shapes verified directly from source files; guard shapes verified
- Pitfalls: HIGH — derived from direct code inspection of existing guards and conventions

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 (stable domain — field shapes only change if SubscriptionSchedule or BillingPortal Session source files are modified)
