defmodule LatticeStripe.Tax.Settings.HeadOffice do
  @moduledoc """
  The `head_office` object embedded in your account's Stripe Tax settings.

  Reachable from `t:LatticeStripe.Tax.Settings.t/0`. Its address is the origin Stripe Tax
  uses when no other origin applies, so it participates in every calculation your
  account performs.

  Embedded value struct: fields are additive. Keys Stripe adds later appear under
  `:extra` rather than being dropped, so a new field never breaks decoding.
  """

  @known_fields ~w[address]

  defstruct [
    :address,
    extra: %{}
  ]

  @type t :: %__MODULE__{
          address: map() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      address: known["address"],
      extra: extra
    }
  end
end
