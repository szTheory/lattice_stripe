defmodule LatticeStripe.TaxId.Verification do
  @moduledoc false

  @known_fields ~w[status verified_address verified_name]

  defstruct [:status, :verified_address, :verified_name, extra: %{}]

  @type t :: %__MODULE__{
          status: atom() | String.t() | nil,
          verified_address: String.t() | nil,
          verified_name: String.t() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      status: atomize_status(known["status"]),
      verified_address: known["verified_address"],
      verified_name: known["verified_name"],
      extra: extra
    }
  end

  defp atomize_status("pending"), do: :pending
  defp atomize_status("verified"), do: :verified
  defp atomize_status("unverified"), do: :unverified
  defp atomize_status("unavailable"), do: :unavailable
  defp atomize_status(nil), do: nil
  defp atomize_status(other), do: other
end
