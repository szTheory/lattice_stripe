defmodule LatticeStripe.BillingPortal.Session.FlowData.SubscriptionUpdateConfirm do
  @moduledoc """
  The `subscription_update_confirm` branch of a
  `LatticeStripe.BillingPortal.Session.FlowData`.

  Populated when `flow_data.type == "subscription_update_confirm"`. Confirms a pending
  subscription-update preview with specific line items and optional discounts.

  `subscription` is the Stripe subscription ID to update. `items` is the list of
  subscription item changes (raw maps per D-02 — shallow leaf lists do not warrant
  dedicated modules). `discounts` is the list of discount objects to apply (raw maps).

  Parent struct: `LatticeStripe.BillingPortal.Session.FlowData`.
  """

  @known_fields ~w(subscription items discounts)

  @type t :: %__MODULE__{
          subscription: String.t() | nil,
          items: [map()] | nil,
          discounts: [map()] | nil,
          extra: map()
        }

  defstruct [:subscription, :items, :discounts, extra: %{}]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      subscription: map["subscription"],
      items: map["items"],
      discounts: map["discounts"],
      extra: Map.drop(map, @known_fields)
    }
  end
end
