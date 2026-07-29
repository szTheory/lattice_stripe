defmodule LatticeStripe.Tax.TaxBreakdown do
  @moduledoc """
  One entry in the `tax_breakdown` list on a Stripe Tax calculation.

  Reachable from `t:LatticeStripe.Tax.Calculation.t/0` as `list(t())`. Each entry is one
  jurisdiction's share of the total, so this is what you sum or display when itemising
  tax on an invoice.

  `:inclusive` distinguishes tax added on top of the amount from tax already contained
  within it — reading the total without checking it double-counts inclusive tax.

  Embedded value struct: fields are additive. Keys Stripe adds later appear under
  `:extra` rather than being dropped, so a new field never breaks decoding.
  """

  @known_fields ~w[amount inclusive tax_rate_details taxability_reason taxable_amount]

  defstruct [
    :amount,
    :inclusive,
    :tax_rate_details,
    :taxability_reason,
    :taxable_amount,
    extra: %{}
  ]

  @type t :: %__MODULE__{
          amount: integer() | nil,
          inclusive: boolean() | nil,
          tax_rate_details: map() | nil,
          taxability_reason: String.t() | nil,
          taxable_amount: integer() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      amount: known["amount"],
      inclusive: known["inclusive"],
      tax_rate_details: known["tax_rate_details"],
      taxability_reason: known["taxability_reason"],
      taxable_amount: known["taxable_amount"],
      extra: extra
    }
  end
end
