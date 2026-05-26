defmodule LatticeStripe.Mandate.SingleUse do
  @moduledoc """
  Represents the `single_use` nested object on a Stripe Mandate.

  Unknown fields from the Stripe API response are preserved in `:extra` for
  forward compatibility.
  """

  @known_fields ~w[amount currency]

  defstruct [:amount, :currency, extra: %{}]

  @type t :: %__MODULE__{
          amount: integer() | nil,
          currency: String.t() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      amount: known["amount"],
      currency: known["currency"],
      extra: extra
    }
  end
end
