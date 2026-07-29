defmodule LatticeStripe.Tax.ShipFromDetails do
  @moduledoc """
  The `ship_from_details` object embedded in a Stripe Tax calculation.

  Reachable from `t:LatticeStripe.Tax.Calculation.t/0`. Records the origin address for the
  shipment, which together with the destination determines the taxing jurisdiction.

  Embedded value struct: fields are additive. Keys Stripe adds later appear under
  `:extra` rather than being dropped, so a new field never breaks decoding.
  """

  @known_fields ~w[address]

  defstruct [:address, extra: %{}]

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
