defmodule LatticeStripe.Balance.SourceTypes do
  @moduledoc """
  Source-type breakdown of a `LatticeStripe.Balance.Amount`.

  Stable inner shape: `card`, `bank_account`, `fpx`. Future Stripe payment-method
  keys (e.g. `"ach_credit_transfer"`, `"link"`) land in `:extra` per the
  typed-inner-open-outer pattern (Phase 17 D-02) so struct shape never drifts
  when Stripe adds a new payment method.
  """

  @known_fields ~w(card bank_account fpx)a

  defstruct @known_fields ++ [extra: %{}]

  @typedoc "Source-type breakdown of a `Balance.Amount`."
  @type t :: %__MODULE__{
          card: integer() | nil,
          bank_account: integer() | nil,
          fpx: integer() | nil,
          extra: map()
        }

  @doc false
  def cast(nil), do: nil

  def cast(map) when is_map(map) do
    known_string_keys = Enum.map(@known_fields, &Atom.to_string/1)
    {known, extra} = Map.split(map, known_string_keys)

    struct(__MODULE__,
      card: known["card"],
      bank_account: known["bank_account"],
      fpx: known["fpx"],
      extra: extra
    )
  end
end
