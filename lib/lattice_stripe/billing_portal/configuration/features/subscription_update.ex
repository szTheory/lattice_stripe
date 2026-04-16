defmodule LatticeStripe.BillingPortal.Configuration.Features.SubscriptionUpdate do
  @moduledoc """
  The `subscription_update` feature settings on a
  `LatticeStripe.BillingPortal.Configuration`.

  Controls whether customers can update their subscriptions in the billing portal,
  including which update types are allowed and how proration is handled.

  ## Level 3+ fields as raw maps

  `products` is a list of product/price objects and `schedule_at_period_end` is
  a nested configuration object. Both form Level 3+ structures. Per D-01
  (6-module nesting cap), they are stored as raw `[map()] | nil` and
  `map() | nil` respectively — accessible via direct map access without
  dedicated typed structs.

  Parent struct: `LatticeStripe.BillingPortal.Configuration.Features`.
  """

  @known_fields ~w[enabled billing_cycle_anchor default_allowed_updates proration_behavior
                   products schedule_at_period_end trial_update_behavior]

  @type t :: %__MODULE__{
          enabled: boolean() | nil,
          billing_cycle_anchor: String.t() | nil,
          default_allowed_updates: [String.t()] | nil,
          proration_behavior: String.t() | nil,
          products: [map()] | nil,
          schedule_at_period_end: map() | nil,
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

  @spec from_map(map() | nil) :: t() | nil
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
