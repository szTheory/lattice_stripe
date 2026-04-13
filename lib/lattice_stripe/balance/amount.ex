defmodule LatticeStripe.Balance.Amount do
  @moduledoc """
  A single currency-denominated amount in a Stripe Balance.

  This module is REUSED 5× inside `%LatticeStripe.Balance{}`: `available[]`,
  `pending[]`, `connect_reserved[]`, `instant_available[]`, and
  `issuing.available[]` all decode to lists of `%Balance.Amount{}`.

  `net_available` (which only appears under `instant_available[]`) lands in
  `:extra` so this single module covers all five call-sites without branching.
  """

  alias LatticeStripe.Balance.SourceTypes

  @known_fields ~w(amount currency source_types)a

  defstruct @known_fields ++ [extra: %{}]

  @typedoc "A Balance amount in a single currency."
  @type t :: %__MODULE__{
          amount: integer() | nil,
          currency: String.t() | nil,
          source_types: SourceTypes.t() | nil,
          extra: map()
        }

  @doc false
  def cast(nil), do: nil

  def cast(map) when is_map(map) do
    known_string_keys = Enum.map(@known_fields, &Atom.to_string/1)
    {known, extra} = Map.split(map, known_string_keys)

    struct(__MODULE__,
      amount: known["amount"],
      currency: known["currency"],
      source_types: SourceTypes.cast(known["source_types"]),
      extra: extra
    )
  end
end
