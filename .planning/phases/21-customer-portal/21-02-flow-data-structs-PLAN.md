---
phase: 21-customer-portal
plan: 02
type: execute
wave: 1
depends_on:
  - 21-01
files_modified:
  - lib/lattice_stripe/billing_portal/session/flow_data.ex
  - lib/lattice_stripe/billing_portal/session/flow_data/after_completion.ex
  - lib/lattice_stripe/billing_portal/session/flow_data/subscription_cancel.ex
  - lib/lattice_stripe/billing_portal/session/flow_data/subscription_update.ex
  - lib/lattice_stripe/billing_portal/session/flow_data/subscription_update_confirm.ex
  - test/lattice_stripe/billing_portal/session/flow_data_test.exs
autonomous: true
requirements:
  - PORTAL-03
must_haves:
  truths:
    - "FlowData parent struct exists with 5 fields + :extra, decoded via from_map/1"
    - "All 4 sub-struct modules exist following Meter.ValueSettings template"
    - "Unknown Stripe flow types land in :extra unchanged (forward compatibility)"
    - "Pure atom dot-access works: session.flow.subscription_cancel.subscription"
  artifacts:
    - path: "lib/lattice_stripe/billing_portal/session/flow_data.ex"
      provides: "Parent FlowData struct with polymorphic-flat branch fields"
      contains: "defmodule LatticeStripe.BillingPortal.Session.FlowData"
    - path: "lib/lattice_stripe/billing_portal/session/flow_data/after_completion.ex"
      provides: "AfterCompletion nested struct (redirect/hosted_confirmation as raw maps)"
    - path: "lib/lattice_stripe/billing_portal/session/flow_data/subscription_cancel.ex"
      provides: "SubscriptionCancel nested struct (retention as raw map)"
    - path: "lib/lattice_stripe/billing_portal/session/flow_data/subscription_update.ex"
      provides: "SubscriptionUpdate nested struct"
    - path: "lib/lattice_stripe/billing_portal/session/flow_data/subscription_update_confirm.ex"
      provides: "SubscriptionUpdateConfirm nested struct (items/discounts as raw maps)"
  key_links:
    - from: "lib/lattice_stripe/billing_portal/session/flow_data.ex"
      to: "lib/lattice_stripe/billing_portal/session/flow_data/*.ex"
      via: "from_map/1 delegation"
      pattern: "AfterCompletion.from_map|SubscriptionCancel.from_map|SubscriptionUpdate.from_map|SubscriptionUpdateConfirm.from_map"
---

<objective>
Ship the 5-module FlowData nested-struct tree exactly as locked in CONTEXT.md D-02. This plan creates the typed contracts that `LatticeStripe.BillingPortal.Session` (plan 21-03) consumes via `map["flow"] |> FlowData.from_map/1` in the response decoder. All 5 modules follow the Phase 20 `Meter.ValueSettings` template verbatim — `@known_fields` list, `defstruct` with `:extra` default, `@spec from_map(map() | nil) :: t() | nil`, `Map.drop(map, @known_fields)` for extra capture.

Purpose: Ship typed polymorphic access to `session.flow.subscription_cancel.subscription` (pure atom-dot) without forcing consumers into string-bracket code-switching (PORTAL-03, closes Phase 20 D-03 forward commitment).
Output: 5 `.ex` files under `lib/lattice_stripe/billing_portal/session/`, unit tests passing for all decode paths.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/21-customer-portal/21-CONTEXT.md
@.planning/phases/21-customer-portal/21-RESEARCH.md
@lib/lattice_stripe/billing/meter/value_settings.ex
@lib/lattice_stripe/billing/meter/customer_mapping.ex
@lib/lattice_stripe/billing/meter/default_aggregation.ex
@lib/lattice_stripe/billing/meter.ex
@test/support/fixtures/billing_portal.ex

<interfaces>
<!-- Parent FlowData sketch (VERBATIM from CONTEXT.md D-02, lines 184-240). -->
<!-- Executor implements this exactly as written. -->

```elixir
defmodule LatticeStripe.BillingPortal.Session.FlowData do
  @moduledoc """
  The `flow` sub-object echoed back on a `LatticeStripe.BillingPortal.Session`.

  Polymorphic on `type`: one of `"subscription_cancel"`, `"subscription_update"`,
  `"subscription_update_confirm"`, `"payment_method_update"`. Only the branch
  matching `type` is populated; the others are `nil`. Unknown flow types added
  by future Stripe API versions land in `:extra` unchanged — existing branches
  continue to work and consumers read the new type from `flow.extra["<new>"]`
  until LatticeStripe promotes it to a first-class sub-struct.
  """

  alias LatticeStripe.BillingPortal.Session.FlowData.{
    AfterCompletion,
    SubscriptionCancel,
    SubscriptionUpdate,
    SubscriptionUpdateConfirm
  }

  @known_fields ~w(type after_completion subscription_cancel
                   subscription_update subscription_update_confirm)

  @type t :: %__MODULE__{
          type: String.t() | nil,
          after_completion: AfterCompletion.t() | nil,
          subscription_cancel: SubscriptionCancel.t() | nil,
          subscription_update: SubscriptionUpdate.t() | nil,
          subscription_update_confirm: SubscriptionUpdateConfirm.t() | nil,
          extra: map()
        }

  defstruct [
    :type,
    :after_completion,
    :subscription_cancel,
    :subscription_update,
    :subscription_update_confirm,
    extra: %{}
  ]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      type: map["type"],
      after_completion: AfterCompletion.from_map(map["after_completion"]),
      subscription_cancel: SubscriptionCancel.from_map(map["subscription_cancel"]),
      subscription_update: SubscriptionUpdate.from_map(map["subscription_update"]),
      subscription_update_confirm:
        SubscriptionUpdateConfirm.from_map(map["subscription_update_confirm"]),
      extra: Map.drop(map, @known_fields)
    }
  end
end
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Write 4 FlowData sub-struct modules</name>
  <files>lib/lattice_stripe/billing_portal/session/flow_data/after_completion.ex, lib/lattice_stripe/billing_portal/session/flow_data/subscription_cancel.ex, lib/lattice_stripe/billing_portal/session/flow_data/subscription_update.ex, lib/lattice_stripe/billing_portal/session/flow_data/subscription_update_confirm.ex</files>
  <behavior>
- `AfterCompletion.from_map(nil)` → `nil`
- `AfterCompletion.from_map(%{"type" => "redirect", "redirect" => %{"return_url" => "https://x"}, "other" => "keep"})` → `%AfterCompletion{type: "redirect", redirect: %{"return_url" => "https://x"}, hosted_confirmation: nil, extra: %{"other" => "keep"}}`
- `SubscriptionCancel.from_map(%{"subscription" => "sub_123", "retention" => %{"type" => "coupon_offer"}})` → `%SubscriptionCancel{subscription: "sub_123", retention: %{"type" => "coupon_offer"}, extra: %{}}`
- `SubscriptionUpdate.from_map(%{"subscription" => "sub_456", "unknown" => "x"})` → `%SubscriptionUpdate{subscription: "sub_456", extra: %{"unknown" => "x"}}`
- `SubscriptionUpdateConfirm.from_map(%{"subscription" => "sub_789", "items" => [%{"id" => "si_1"}], "discounts" => []})` → `%SubscriptionUpdateConfirm{subscription: "sub_789", items: [%{"id" => "si_1"}], discounts: [], extra: %{}}`
  </behavior>
  <action>
Use the `lib/lattice_stripe/billing/meter/customer_mapping.ex` template verbatim — `@moduledoc`, `@known_fields`, `@type t`, `defstruct`, `@spec`, two `from_map/1` clauses. Fields per D-02:

1. `after_completion.ex` → module `LatticeStripe.BillingPortal.Session.FlowData.AfterCompletion`. `@known_fields ~w(type redirect hosted_confirmation)`. `defstruct [:type, :redirect, :hosted_confirmation, extra: %{}]`. `@type`: `type: String.t() | nil, redirect: map() | nil, hosted_confirmation: map() | nil, extra: map()`.
2. `subscription_cancel.ex` → `...SubscriptionCancel`. `@known_fields ~w(subscription retention)`. `defstruct [:subscription, :retention, extra: %{}]`. `@type`: `subscription: String.t() | nil, retention: map() | nil, extra: map()`.
3. `subscription_update.ex` → `...SubscriptionUpdate`. `@known_fields ~w(subscription)`. `defstruct [:subscription, extra: %{}]`. `@type`: `subscription: String.t() | nil, extra: map()`.
4. `subscription_update_confirm.ex` → `...SubscriptionUpdateConfirm`. `@known_fields ~w(subscription items discounts)`. `defstruct [:subscription, :items, :discounts, extra: %{}]`. `@type`: `subscription: String.t() | nil, items: [map()] | nil, discounts: [map()] | nil, extra: map()`.

Each module's `@moduledoc` documents: which Stripe `flow_data.type` it corresponds to, cross-link to parent `LatticeStripe.BillingPortal.Session.FlowData`, note that leaf sub-objects (retention, items, discounts, redirect, hosted_confirmation) intentionally stay as raw maps per D-02.

NO `payment_method_update` module — zero extra fields, expressed by `FlowData.type == "payment_method_update"` alone.

Before writing modules, replace the `@tag :skip` stubs in `test/lattice_stripe/billing_portal/session/flow_data_test.exs` with real assertions for each sub-module covering: nil input → nil, happy path decode, extra-capture of unknown string keys. Test should fail (RED), then pass after module impl (GREEN).
  </action>
  <verify>
    <automated>cd /Users/jon/projects/lattice_stripe && mix test test/lattice_stripe/billing_portal/session/flow_data_test.exs</automated>
  </verify>
  <done>All 4 sub-modules compile; FlowData sub-module tests green; each `from_map/1` correctly captures unknown keys in `:extra` via `Map.drop`.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Write parent FlowData module + parent decode tests</name>
  <files>lib/lattice_stripe/billing_portal/session/flow_data.ex, test/lattice_stripe/billing_portal/session/flow_data_test.exs</files>
  <behavior>
- `FlowData.from_map(nil)` → `nil`
- `FlowData.from_map(%{"type" => "payment_method_update", "after_completion" => nil, "subscription_cancel" => nil, "subscription_update" => nil, "subscription_update_confirm" => nil})` → `%FlowData{type: "payment_method_update"}` with all branch fields `nil`, `extra: %{}`.
- `FlowData.from_map(%{"type" => "subscription_cancel", "subscription_cancel" => %{"subscription" => "sub_123"}, "after_completion" => nil, "subscription_update" => nil, "subscription_update_confirm" => nil})` → `%FlowData{type: "subscription_cancel", subscription_cancel: %SubscriptionCancel{subscription: "sub_123"}}` with atom-dot access: `result.subscription_cancel.subscription == "sub_123"`.
- Forward-compat: `FlowData.from_map(%{"type" => "subscription_pause", "subscription_pause" => %{"behavior" => "keep_as_draft"}})` → `%FlowData{type: "subscription_pause", subscription_cancel: nil, ..., extra: %{"subscription_pause" => %{"behavior" => "keep_as_draft"}}}`.
  </behavior>
  <action>
Implement `lib/lattice_stripe/billing_portal/session/flow_data.ex` VERBATIM from the `<interfaces>` block above (CONTEXT.md D-02 lines 184-240). Do not modify — the code is locked.

Extend `test/lattice_stripe/billing_portal/session/flow_data_test.exs` with a `describe "FlowData.from_map/1"` block that covers: nil → nil, each of 4 flow-type happy paths (using `LatticeStripe.Test.Fixtures.BillingPortal.Session.with_*_flow/0`-derived `"flow"` sub-map), forward-compat case where `"type" => "subscription_pause"` lands in `:extra`, and atom-dot access assertion: `assert %FlowData{subscription_cancel: %SubscriptionCancel{subscription: "sub_123"}} = FlowData.from_map(flow_map)`.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/lattice_stripe && mix test test/lattice_stripe/billing_portal/session/flow_data_test.exs</automated>
  </verify>
  <done>Parent FlowData decodes all 4 flow types + forward-compat subscription_pause case into `:extra`; atom-dot pattern matching works end-to-end.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Stripe JSON response → decoded struct | Unknown future keys must not crash decode (forward compat) |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-21-03 | Denial of Service | future Stripe API adds new flow type | mitigate | `@known_fields` + `Map.drop` pattern means unknown keys land in `:extra` unchanged; existing branches continue to work. Tested explicitly via forward-compat case in Task 2. |
| T-21-04 | Tampering | malformed `flow` sub-map from upstream | accept | `from_map/1` pattern-matches on `is_map/1`; non-map inputs fall through to `nil` clause. Not user input — decoder only runs on Stripe-returned JSON already validated by Jason. |
</threat_model>

<verification>
- `mix compile --warnings-as-errors` clean
- `mix test test/lattice_stripe/billing_portal/session/flow_data_test.exs` green
- `mix credo --strict lib/lattice_stripe/billing_portal/session/flow_data{,/*}.ex` clean
</verification>

<success_criteria>
1. 5 `.ex` files exist under `lib/lattice_stripe/billing_portal/session/`.
2. FlowData decode of all 4 known flow types returns fully-typed nested structs.
3. Forward-compat: unknown flow types land in `:extra` without crashing.
4. Atom dot-access works: `session.flow.subscription_cancel.subscription` (no string-bracket hop).
</success_criteria>

<output>
After completion, create `.planning/phases/21-customer-portal/21-02-flow-data-structs-SUMMARY.md`.
</output>
