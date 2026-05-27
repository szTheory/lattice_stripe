defmodule LatticeStripe.Tax.Settings.StatusDetails do
  @moduledoc false

  @known_fields ~w[active pending]

  defstruct [
    :active,
    :pending,
    extra: %{}
  ]

  @type t :: %__MODULE__{
          active: map() | nil,
          pending: map() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      active: known["active"],
      pending: known["pending"],
      extra: extra
    }
  end
end
