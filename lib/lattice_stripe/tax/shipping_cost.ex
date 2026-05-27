defmodule LatticeStripe.Tax.ShippingCost do
  @moduledoc false

  @known_fields ~w[amount amount_tax shipping_rate tax_behavior tax_code tax_breakdown]

  defstruct [
    :amount,
    :amount_tax,
    :shipping_rate,
    :tax_behavior,
    :tax_code,
    :tax_breakdown,
    extra: %{}
  ]

  @type t :: %__MODULE__{
          amount: integer() | nil,
          amount_tax: integer() | nil,
          shipping_rate: String.t() | nil,
          tax_behavior: atom() | String.t() | nil,
          tax_code: String.t() | nil,
          tax_breakdown: list() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      amount: known["amount"],
      amount_tax: known["amount_tax"],
      shipping_rate: known["shipping_rate"],
      tax_behavior: atomize_tax_behavior(known["tax_behavior"]),
      tax_code: known["tax_code"],
      tax_breakdown: known["tax_breakdown"],
      extra: extra
    }
  end

  defp atomize_tax_behavior("exclusive"), do: :exclusive
  defp atomize_tax_behavior("inclusive"), do: :inclusive
  defp atomize_tax_behavior(nil), do: nil
  defp atomize_tax_behavior(other), do: other
end
