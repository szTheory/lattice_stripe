defmodule LatticeStripe.BillingPortal.Session.FlowData.SubscriptionUpdate do
  @moduledoc """
  The `subscription_update` branch of a `LatticeStripe.BillingPortal.Session.FlowData`.

  Populated when `flow_data.type == "subscription_update"`. Provides deep-link access
  to the plan-change flow for a specific subscription.

  `subscription` is the Stripe subscription ID (`sub_*`) to deep-link into.

  Parent struct: `LatticeStripe.BillingPortal.Session.FlowData`.
  """

  @known_fields ~w(subscription)

  @type t :: %__MODULE__{
          subscription: String.t() | nil,
          extra: map()
        }

  defstruct [:subscription, extra: %{}]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      subscription: map["subscription"],
      extra: Map.drop(map, @known_fields)
    }
  end
end
