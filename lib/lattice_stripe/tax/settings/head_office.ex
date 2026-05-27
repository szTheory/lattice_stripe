defmodule LatticeStripe.Tax.Settings.HeadOffice do
  @moduledoc false

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
