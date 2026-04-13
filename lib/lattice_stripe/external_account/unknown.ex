defmodule LatticeStripe.ExternalAccount.Unknown do
  @moduledoc """
  Forward-compatibility fallback for `LatticeStripe.ExternalAccount` responses
  whose `object` is neither `"bank_account"` nor `"card"`. Preserves the raw
  payload in `:extra` so user code does not crash on a new Stripe object type.

  Callers should match `%LatticeStripe.BankAccount{}` or `%LatticeStripe.Card{}`
  first and treat `%LatticeStripe.ExternalAccount.Unknown{}` as an escape hatch:

      case ea do
        %LatticeStripe.BankAccount{} -> handle_bank(ea)
        %LatticeStripe.Card{} -> handle_card(ea)
        %LatticeStripe.ExternalAccount.Unknown{} = u ->
          Logger.warning("unknown external account type: \#{u.object}")
      end
  """

  @known_fields ~w(id object)a
  defstruct @known_fields ++ [extra: %{}]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t() | nil,
          extra: map()
        }

  @doc false
  @spec cast(map() | nil) :: t() | nil
  def cast(nil), do: nil

  def cast(map) when is_map(map) do
    known_string_keys = Enum.map(@known_fields, &Atom.to_string/1)

    %__MODULE__{
      id: map["id"],
      object: map["object"],
      extra: Map.drop(map, known_string_keys)
    }
  end
end
