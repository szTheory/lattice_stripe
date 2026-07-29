defmodule LatticeStripe.Tax.Settings.Defaults do
  @moduledoc """
  The `defaults` object embedded in your account's Stripe Tax settings.

  Reachable from `t:LatticeStripe.Tax.Settings.t/0`. These values apply to calculations
  that do not override them — notably `tax_behavior`, which decides whether your prices
  are treated as tax-inclusive or tax-exclusive.

  Embedded value struct: fields are additive. Keys Stripe adds later appear under
  `:extra` rather than being dropped, so a new field never breaks decoding.
  """

  @known_fields ~w[tax_behavior tax_code provider]

  defstruct [
    :tax_behavior,
    :tax_code,
    :provider,
    extra: %{}
  ]

  @type t :: %__MODULE__{
          tax_behavior: atom() | String.t() | nil,
          tax_code: String.t() | nil,
          provider: String.t() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      tax_behavior: atomize_tax_behavior(known["tax_behavior"]),
      tax_code: known["tax_code"],
      provider: known["provider"],
      extra: extra
    }
  end

  defp atomize_tax_behavior("exclusive"), do: :exclusive
  defp atomize_tax_behavior("inclusive"), do: :inclusive
  defp atomize_tax_behavior("inferred_by_currency"), do: :inferred_by_currency
  defp atomize_tax_behavior(nil), do: nil
  defp atomize_tax_behavior(other), do: other
end
