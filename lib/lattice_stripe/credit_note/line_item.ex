defmodule LatticeStripe.CreditNote.LineItem do
  @moduledoc """
  Represents a line item on a Stripe Credit Note.

  Credit note line items are returned inside `LatticeStripe.CreditNote` objects and
  from the dedicated line-item list endpoints. Stripe returns multiple subtype
  variants here; `type` is preserved as the original string.
  """

  @known_fields ~w[
    id object amount description discount_amount discount_amounts invoice_line_item
    livemode pretax_credit_amounts quantity tax_rates taxes type unit_amount
    unit_amount_decimal
  ]

  defstruct [
    :id,
    :amount,
    :description,
    :discount_amount,
    :discount_amounts,
    :invoice_line_item,
    :livemode,
    :pretax_credit_amounts,
    :quantity,
    :tax_rates,
    :taxes,
    :type,
    :unit_amount,
    :unit_amount_decimal,
    object: "credit_note_line_item",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          amount: integer() | nil,
          description: String.t() | nil,
          discount_amount: integer() | nil,
          discount_amounts: list() | nil,
          invoice_line_item: String.t() | nil,
          livemode: boolean() | nil,
          pretax_credit_amounts: list() | nil,
          quantity: integer() | nil,
          tax_rates: list() | nil,
          taxes: list() | map() | nil,
          type: String.t() | nil,
          unit_amount: integer() | nil,
          unit_amount_decimal: String.t() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "credit_note_line_item",
      amount: known["amount"],
      description: known["description"],
      discount_amount: known["discount_amount"],
      discount_amounts: known["discount_amounts"],
      invoice_line_item: known["invoice_line_item"],
      livemode: known["livemode"],
      pretax_credit_amounts: known["pretax_credit_amounts"],
      quantity: known["quantity"],
      tax_rates: known["tax_rates"],
      taxes: known["taxes"],
      type: known["type"],
      unit_amount: known["unit_amount"],
      unit_amount_decimal: known["unit_amount_decimal"],
      extra: extra
    }
  end
end
