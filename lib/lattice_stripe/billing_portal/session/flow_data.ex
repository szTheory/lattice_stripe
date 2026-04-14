defmodule LatticeStripe.BillingPortal.Session.FlowData do
  @moduledoc """
  The `flow` sub-object echoed back on a `LatticeStripe.BillingPortal.Session`.

  Polymorphic on `type`: one of `"subscription_cancel"`, `"subscription_update"`,
  `"subscription_update_confirm"`, `"payment_method_update"`. Only the branch
  matching `type` is populated; the others are `nil`. Unknown flow types added
  by future Stripe API versions land in `:extra` unchanged — existing branches
  continue to work and consumers read the new type from `flow.extra["<new>"]`
  until LatticeStripe promotes it to a first-class sub-struct.
  """

  alias LatticeStripe.BillingPortal.Session.FlowData.{
    AfterCompletion,
    SubscriptionCancel,
    SubscriptionUpdate,
    SubscriptionUpdateConfirm
  }

  @known_fields ~w(type after_completion subscription_cancel
                   subscription_update subscription_update_confirm)

  @type t :: %__MODULE__{
          type: String.t() | nil,
          after_completion: AfterCompletion.t() | nil,
          subscription_cancel: SubscriptionCancel.t() | nil,
          subscription_update: SubscriptionUpdate.t() | nil,
          subscription_update_confirm: SubscriptionUpdateConfirm.t() | nil,
          extra: map()
        }

  defstruct [
    :type,
    :after_completion,
    :subscription_cancel,
    :subscription_update,
    :subscription_update_confirm,
    extra: %{}
  ]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      type: map["type"],
      after_completion: AfterCompletion.from_map(map["after_completion"]),
      subscription_cancel: SubscriptionCancel.from_map(map["subscription_cancel"]),
      subscription_update: SubscriptionUpdate.from_map(map["subscription_update"]),
      subscription_update_confirm:
        SubscriptionUpdateConfirm.from_map(map["subscription_update_confirm"]),
      extra: Map.drop(map, @known_fields)
    }
  end
end
