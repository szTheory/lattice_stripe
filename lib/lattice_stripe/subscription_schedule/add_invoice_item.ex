defmodule LatticeStripe.SubscriptionSchedule.AddInvoiceItem do
  @moduledoc """
  A one-off invoice item to add at the start of a SubscriptionSchedule phase.

  Used to bill setup fees, credits, or other non-recurring amounts at phase
  boundaries. Smaller than `LatticeStripe.SubscriptionSchedule.PhaseItem` —
  no `billing_thresholds`, `plan`, or `trial_data`.

  ## Fields

  - `discounts` - List of discount IDs or objects
  - `metadata` - Set of key-value pairs
  - `period` - Billing period map (`%{"start" => ..., "end" => ...}`)
  - `price` - Price ID for an existing Price
  - `price_data` - Inline price data for ad-hoc pricing
  - `quantity` - Quantity for this item
  - `tax_rates` - List of tax rate objects
  - `extra` - Unknown fields from Stripe not yet in this struct
  """

  @known_fields ~w[discounts metadata period price price_data quantity tax_rates]

  defstruct [
    :discounts,
    :metadata,
    :period,
    :price,
    :price_data,
    :quantity,
    :tax_rates,
    extra: %{}
  ]

  @typedoc "A one-off add-invoice-item attached to a SubscriptionSchedule phase."
  @type t :: %__MODULE__{
          discounts: list() | nil,
          metadata: map() | nil,
          period: map() | nil,
          price: String.t() | map() | nil,
          price_data: map() | nil,
          quantity: integer() | nil,
          tax_rates: list() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%AddInvoiceItem{}` struct.

  Returns `nil` when given `nil`.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      discounts: known["discounts"],
      metadata: known["metadata"],
      period: known["period"],
      price: known["price"],
      price_data: known["price_data"],
      quantity: known["quantity"],
      tax_rates: known["tax_rates"],
      extra: extra
    }
  end
end
