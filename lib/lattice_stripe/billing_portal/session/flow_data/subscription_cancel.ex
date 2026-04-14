defmodule LatticeStripe.BillingPortal.Session.FlowData.SubscriptionCancel do
  @moduledoc """
  The `subscription_cancel` branch of a `LatticeStripe.BillingPortal.Session.FlowData`.

  Populated when `flow_data.type == "subscription_cancel"`. Provides deep-link access
  to a cancellation flow for a specific subscription.

  `subscription` is the Stripe subscription ID (`sub_*`) the portal should prefill.
  `retention` is the raw Stripe retention object (type `"coupon_offer"` etc.) — kept as
  a raw `map()` per D-02 (shallow leaf objects do not warrant dedicated modules).

  Parent struct: `LatticeStripe.BillingPortal.Session.FlowData`.
  """

  @known_fields ~w(subscription retention)

  @type t :: %__MODULE__{
          subscription: String.t() | nil,
          retention: map() | nil,
          extra: map()
        }

  defstruct [:subscription, :retention, extra: %{}]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      subscription: map["subscription"],
      retention: map["retention"],
      extra: Map.drop(map, @known_fields)
    }
  end
end
