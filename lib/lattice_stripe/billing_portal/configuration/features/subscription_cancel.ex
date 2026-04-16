defmodule LatticeStripe.BillingPortal.Configuration.Features.SubscriptionCancel do
  @moduledoc """
  The `subscription_cancel` feature settings on a
  `LatticeStripe.BillingPortal.Configuration`.

  Controls whether customers can cancel their subscriptions in the billing portal
  and how the cancellation flow behaves.

  ## Level 3+ fields as raw maps

  `cancellation_reason` contains nested options (`enabled`, `options` list) that
  form a Level 3+ sub-object. Per D-01 (6-module nesting cap), Level 3+ objects
  are stored as raw `map() | nil` rather than dedicated structs. This avoids
  struct explosion while still making the data accessible via direct map access.

  Parent struct: `LatticeStripe.BillingPortal.Configuration.Features`.
  """

  @known_fields ~w[enabled mode proration_behavior cancellation_reason]

  @type t :: %__MODULE__{
          enabled: boolean() | nil,
          mode: String.t() | nil,
          proration_behavior: String.t() | nil,
          cancellation_reason: map() | nil,
          extra: map()
        }

  defstruct [:enabled, :mode, :proration_behavior, :cancellation_reason, extra: %{}]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      enabled: known["enabled"],
      mode: known["mode"],
      proration_behavior: known["proration_behavior"],
      cancellation_reason: known["cancellation_reason"],
      extra: extra
    }
  end
end
