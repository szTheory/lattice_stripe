defmodule LatticeStripe.Mandate.CustomerAcceptance do
  @moduledoc """
  Represents the `customer_acceptance` nested object on a Stripe Mandate.

  Unknown fields from the Stripe API response are preserved in `:extra` for
  forward compatibility.
  """

  @known_fields ~w[accepted_at offline online type]

  defstruct [:accepted_at, :offline, :online, :type, extra: %{}]

  @type t :: %__MODULE__{
          accepted_at: integer() | nil,
          offline: map() | nil,
          online: map() | nil,
          type: atom() | String.t() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      accepted_at: known["accepted_at"],
      offline: known["offline"],
      online: known["online"],
      type: atomize_type(known["type"]),
      extra: extra
    }
  end

  defp atomize_type("online"), do: :online
  defp atomize_type("offline"), do: :offline
  defp atomize_type(other), do: other
end
