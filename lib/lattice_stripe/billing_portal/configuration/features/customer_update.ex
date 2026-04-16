defmodule LatticeStripe.BillingPortal.Configuration.Features.CustomerUpdate do
  @moduledoc """
  The `customer_update` feature settings on a
  `LatticeStripe.BillingPortal.Configuration`.

  Controls whether customers can update their billing information in the portal,
  including which fields are allowed to be updated.

  Parent struct: `LatticeStripe.BillingPortal.Configuration.Features`.
  """

  @known_fields ~w[allowed_updates enabled]

  @type t :: %__MODULE__{
          allowed_updates: [String.t()] | nil,
          enabled: boolean() | nil,
          extra: map()
        }

  defstruct [:allowed_updates, :enabled, extra: %{}]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      allowed_updates: known["allowed_updates"],
      enabled: known["enabled"],
      extra: extra
    }
  end
end
