defmodule LatticeStripe.Checkout.LineItem do
  @moduledoc """
  Represents a line item in a Checkout Session.

  Returned by `Checkout.Session.list_line_items/4` and `Checkout.Session.stream_line_items!/4`.
  Line items cannot be created or fetched independently — they are always accessed
  in the context of a Checkout Session.

  ## Fields

  - `id` - Unique identifier for the line item
  - `object` - Always `"item"`
  - `amount_discount` - Total discount amount in the smallest currency unit
  - `amount_subtotal` - Subtotal amount before taxes and discounts
  - `amount_tax` - Total tax amount
  - `amount_total` - Total amount after discounts and taxes
  - `currency` - Three-letter ISO currency code
  - `description` - Human-readable description of the item
  - `price` - The price object associated with this line item
  - `quantity` - Quantity of the item purchased
  """

  @known_fields ~w[id object amount_discount amount_subtotal amount_tax amount_total currency description price quantity]

  defstruct [
    :id,
    :amount_discount,
    :amount_subtotal,
    :amount_tax,
    :amount_total,
    :currency,
    :description,
    :price,
    :quantity,
    object: "item",
    extra: %{}
  ]

  @typedoc """
  A line item within a Stripe Checkout Session.

  Line items are accessed through `Checkout.Session.list_line_items/4` or
  `Checkout.Session.stream_line_items!/4`. They cannot be fetched independently.

  See [Stripe Checkout Sessions line items](https://docs.stripe.com/api/checkout/sessions/line_items)
  for field definitions.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount_discount: integer() | nil,
          amount_subtotal: integer() | nil,
          amount_tax: integer() | nil,
          amount_total: integer() | nil,
          currency: String.t() | nil,
          description: String.t() | nil,
          price: map() | nil,
          quantity: integer() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%LineItem{}` struct.

  Maps all known line item fields. Any unrecognized fields are collected
  into the `extra` map so no data is silently lost.

  ## Example

      item = LatticeStripe.Checkout.LineItem.from_map(%{
        "id" => "li_...",
        "object" => "item",
        "description" => "T-Shirt",
        "quantity" => 1,
        "amount_total" => 2000
      })
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "item",
      amount_discount: map["amount_discount"],
      amount_subtotal: map["amount_subtotal"],
      amount_tax: map["amount_tax"],
      amount_total: map["amount_total"],
      currency: map["currency"],
      description: map["description"],
      price: map["price"],
      quantity: map["quantity"],
      extra: Map.drop(map, @known_fields)
    }
  end
end

defimpl Inspect, for: LatticeStripe.Checkout.LineItem do
  import Inspect.Algebra

  def inspect(item, opts) do
    # Show only key display fields for line items.
    fields = [
      id: item.id,
      object: item.object,
      description: item.description,
      quantity: item.quantity,
      amount_total: item.amount_total
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Checkout.LineItem<" | pairs] ++ [">"])
  end
end
