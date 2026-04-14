defmodule LatticeStripe.BillingPortal.Session.FlowData.AfterCompletion do
  @moduledoc """
  The `after_completion` sub-object of a `LatticeStripe.BillingPortal.Session.FlowData`.

  Applies to all flow types. Describes what happens when a customer completes a portal
  flow. `type` is one of `"hosted_confirmation"` (show an in-portal confirmation page)
  or `"redirect"` (redirect the customer to a `return_url`).

  The `redirect` and `hosted_confirmation` sub-objects are intentionally kept as raw
  `map()` values per D-02 — shallow leaf objects do not warrant dedicated modules.
  Parent struct: `LatticeStripe.BillingPortal.Session.FlowData`.
  """

  @known_fields ~w(type redirect hosted_confirmation)

  @type t :: %__MODULE__{
          type: String.t() | nil,
          redirect: map() | nil,
          hosted_confirmation: map() | nil,
          extra: map()
        }

  defstruct [:type, :redirect, :hosted_confirmation, extra: %{}]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      type: map["type"],
      redirect: map["redirect"],
      hosted_confirmation: map["hosted_confirmation"],
      extra: Map.drop(map, @known_fields)
    }
  end
end
