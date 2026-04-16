defmodule LatticeStripe.BillingPortal.Configuration.Features.PaymentMethodUpdate do
  @moduledoc """
  The `payment_method_update` feature settings on a
  `LatticeStripe.BillingPortal.Configuration`.

  Controls whether customers can update their payment methods in the billing
  portal and which payment method configurations are available.

  Parent struct: `LatticeStripe.BillingPortal.Configuration.Features`.
  """

  @known_fields ~w[enabled payment_method_configuration]

  @type t :: %__MODULE__{
          enabled: boolean() | nil,
          payment_method_configuration: String.t() | nil,
          extra: map()
        }

  defstruct [:enabled, :payment_method_configuration, extra: %{}]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      enabled: known["enabled"],
      payment_method_configuration: known["payment_method_configuration"],
      extra: extra
    }
  end
end
