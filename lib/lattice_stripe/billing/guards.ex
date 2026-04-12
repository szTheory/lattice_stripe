defmodule LatticeStripe.Billing.Guards do
  @moduledoc """
  Shared pre-request guards for Billing operations.

  Used by `Invoice.upcoming/3`, `Invoice.create_preview/3` (Phase 14),
  and `Subscription`/`SubscriptionItem` mutations (Phase 15).
  """
  alias LatticeStripe.{Client, Error}

  @doc """
  Checks if the client requires explicit proration_behavior and if the param is present.

  Returns `:ok` when:
  - `client.require_explicit_proration` is `false` (default), OR
  - `params` contains the key `"proration_behavior"`

  Returns `{:error, %Error{type: :proration_required}}` when:
  - `client.require_explicit_proration` is `true`, AND
  - `params` does NOT contain the key `"proration_behavior"`
  """
  @spec check_proration_required(Client.t(), map()) :: :ok | {:error, Error.t()}
  def check_proration_required(%Client{require_explicit_proration: false}, _params), do: :ok

  def check_proration_required(%Client{require_explicit_proration: true}, params) do
    if Map.has_key?(params, "proration_behavior") do
      :ok
    else
      {:error,
       %Error{
         type: :proration_required,
         message:
           "proration_behavior is required when require_explicit_proration is enabled. Valid values: \"create_prorations\", \"always_invoice\", \"none\""
       }}
    end
  end
end
