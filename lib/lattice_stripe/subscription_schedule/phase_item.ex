defmodule LatticeStripe.SubscriptionSchedule.PhaseItem do
  @moduledoc """
  A single item inside a SubscriptionSchedule phase.

  A phase item is a **template** that Stripe materializes into a real
  `%LatticeStripe.SubscriptionItem{}` when the phase activates. Its shape
  differs from a live SubscriptionItem:

  - NO `id`, `object`, `subscription`, `created`, `current_period_start`,
    `current_period_end` — a template has no identity yet.
  - HAS `price_data` (inline price creation) and `trial_data` (phase-scoped
    trial settings) — a live item would use the parent subscription's trial
    settings instead.

  See also: `LatticeStripe.SubscriptionItem` for live items on an active
  subscription.

  ## Fields

  - `billing_thresholds` - Per-item billing threshold map
  - `discounts` - List of discount IDs or objects
  - `metadata` - Set of key-value pairs
  - `plan` - Plan object (legacy)
  - `price` - Price ID for an existing Price
  - `price_data` - Inline price data for ad-hoc pricing
  - `quantity` - Quantity for this item
  - `tax_rates` - List of tax rate objects
  - `trial_data` - Phase-scoped trial configuration map
  - `extra` - Unknown fields from Stripe not yet in this struct
  """

  @known_fields ~w[
    billing_thresholds discounts metadata plan price price_data quantity tax_rates trial_data
  ]

  defstruct [
    :billing_thresholds,
    :discounts,
    :metadata,
    :plan,
    :price,
    :price_data,
    :quantity,
    :tax_rates,
    :trial_data,
    extra: %{}
  ]

  @typedoc "A phase-item template on a Stripe Subscription Schedule phase."
  @type t :: %__MODULE__{
          billing_thresholds: map() | nil,
          discounts: list() | nil,
          metadata: map() | nil,
          plan: map() | nil,
          price: String.t() | map() | nil,
          price_data: map() | nil,
          quantity: integer() | nil,
          tax_rates: list() | nil,
          trial_data: map() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%PhaseItem{}` struct.

  Returns `nil` when given `nil`.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      billing_thresholds: known["billing_thresholds"],
      discounts: known["discounts"],
      metadata: known["metadata"],
      plan: known["plan"],
      price: known["price"],
      price_data: known["price_data"],
      quantity: known["quantity"],
      tax_rates: known["tax_rates"],
      trial_data: known["trial_data"],
      extra: extra
    }
  end
end
