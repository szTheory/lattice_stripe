defmodule LatticeStripe.Tax.Transaction.LineItem do
  @moduledoc """
  Represents a line item on a Stripe Tax Transaction.

  Returned embedded on `%LatticeStripe.Tax.Transaction{}` objects and from
  `LatticeStripe.Tax.Transaction.list_line_items/4`.
  """

  alias LatticeStripe.ObjectTypes

  @known_fields ~w[
    id object amount amount_tax livemode metadata performance_location product
    quantity reference reversal tax_behavior tax_breakdown tax_code type
  ]

  defstruct [
    :id,
    :amount,
    :amount_tax,
    :livemode,
    :metadata,
    :performance_location,
    :product,
    :quantity,
    :reference,
    :reversal,
    :tax_behavior,
    :tax_breakdown,
    :tax_code,
    :type,
    object: "tax.transaction_line_item",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount: integer() | nil,
          amount_tax: integer() | nil,
          livemode: boolean() | nil,
          metadata: map() | nil,
          performance_location: map() | nil,
          product: LatticeStripe.Product.t() | String.t() | map() | nil,
          quantity: integer() | nil,
          reference: String.t() | nil,
          reversal: map() | String.t() | nil,
          tax_behavior: atom() | String.t() | nil,
          tax_breakdown: list() | nil,
          tax_code: String.t() | nil,
          type: String.t() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "tax.transaction_line_item",
      amount: known["amount"],
      amount_tax: known["amount_tax"],
      livemode: known["livemode"],
      metadata: known["metadata"],
      performance_location: known["performance_location"],
      product: parse_product(known["product"]),
      quantity: known["quantity"],
      reference: known["reference"],
      reversal: known["reversal"],
      tax_behavior: atomize_tax_behavior(known["tax_behavior"]),
      tax_breakdown: known["tax_breakdown"],
      tax_code: known["tax_code"],
      type: known["type"],
      extra: extra
    }
  end

  defp parse_product(value) when is_map(value), do: ObjectTypes.maybe_deserialize(value)
  defp parse_product(value), do: value

  defp atomize_tax_behavior("exclusive"), do: :exclusive
  defp atomize_tax_behavior("inclusive"), do: :inclusive
  defp atomize_tax_behavior(nil), do: nil
  defp atomize_tax_behavior(other), do: other
end
