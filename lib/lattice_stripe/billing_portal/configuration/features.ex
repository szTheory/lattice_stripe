defmodule LatticeStripe.BillingPortal.Configuration.Features do
  @moduledoc """
  The `features` sub-object on a `LatticeStripe.BillingPortal.Configuration`.

  Dispatches each feature key to a typed sub-struct via `from_map/1`, except
  `invoice_history` which is kept as a raw `map() | nil`. The `invoice_history`
  object contains only a single boolean (`enabled`) and does not warrant a
  dedicated module per D-01.

  ## Children

  - `customer_update` → `LatticeStripe.BillingPortal.Configuration.Features.CustomerUpdate`
  - `invoice_history` → raw `map() | nil`
  - `payment_method_update` → `LatticeStripe.BillingPortal.Configuration.Features.PaymentMethodUpdate`
  - `subscription_cancel` → `LatticeStripe.BillingPortal.Configuration.Features.SubscriptionCancel`
  - `subscription_update` → `LatticeStripe.BillingPortal.Configuration.Features.SubscriptionUpdate`

  Parent struct: `LatticeStripe.BillingPortal.Configuration`.
  """

  alias LatticeStripe.BillingPortal.Configuration.Features.{
    CustomerUpdate,
    PaymentMethodUpdate,
    SubscriptionCancel,
    SubscriptionUpdate
  }

  @known_fields ~w[customer_update invoice_history payment_method_update
                   subscription_cancel subscription_update]

  @type t :: %__MODULE__{
          customer_update: CustomerUpdate.t() | nil,
          invoice_history: map() | nil,
          payment_method_update: PaymentMethodUpdate.t() | nil,
          subscription_cancel: SubscriptionCancel.t() | nil,
          subscription_update: SubscriptionUpdate.t() | nil,
          extra: map()
        }

  defstruct [
    :customer_update,
    :invoice_history,
    :payment_method_update,
    :subscription_cancel,
    :subscription_update,
    extra: %{}
  ]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      customer_update: CustomerUpdate.from_map(known["customer_update"]),
      invoice_history: known["invoice_history"],
      payment_method_update: PaymentMethodUpdate.from_map(known["payment_method_update"]),
      subscription_cancel: SubscriptionCancel.from_map(known["subscription_cancel"]),
      subscription_update: SubscriptionUpdate.from_map(known["subscription_update"]),
      extra: extra
    }
  end
end
