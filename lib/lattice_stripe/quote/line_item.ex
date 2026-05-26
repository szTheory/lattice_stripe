defmodule LatticeStripe.Quote.LineItem do
  @moduledoc """
  Represents a line item returned by Stripe Quote APIs.

  Quote line items appear in three places:

  - embedded on `%LatticeStripe.Quote{}` snapshots
  - embedded inside `computed.upfront` or `computed.recurring`
  - from paginated Quote line-item endpoints

  Stripe may evolve the pricing subtrees here over time, so bounded fields are
  typed directly while pricing, period, tax, and discount detail branches remain
  raw maps or lists. Unknown fields are preserved in `extra`.
  """

  @known_fields ~w[
    id object amount_discount amount_subtotal amount_tax amount_total currency
    description discounts period price pricing quantity taxes
  ]

  defstruct [
    :id,
    :amount_discount,
    :amount_subtotal,
    :amount_tax,
    :amount_total,
    :currency,
    :description,
    :discounts,
    :period,
    :price,
    :pricing,
    :quantity,
    :taxes,
    object: "quote_line_item",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount_discount: integer() | nil,
          amount_subtotal: integer() | nil,
          amount_tax: integer() | nil,
          amount_total: integer() | nil,
          currency: String.t() | nil,
          description: String.t() | nil,
          discounts: list() | nil,
          period: map() | nil,
          price: map() | nil,
          pricing: map() | nil,
          quantity: integer() | nil,
          taxes: list() | map() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "quote_line_item",
      amount_discount: known["amount_discount"],
      amount_subtotal: known["amount_subtotal"],
      amount_tax: known["amount_tax"],
      amount_total: known["amount_total"],
      currency: known["currency"],
      description: known["description"],
      discounts: known["discounts"],
      period: known["period"],
      price: known["price"],
      pricing: known["pricing"],
      quantity: known["quantity"],
      taxes: known["taxes"],
      extra: extra
    }
  end
end
