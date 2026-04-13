defmodule LatticeStripe.Billing.Guards do
  @moduledoc false
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
    if has_proration_behavior?(params) do
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

  defp has_proration_behavior?(params) do
    Map.has_key?(params, "proration_behavior") or
      (is_map(params["subscription_details"]) and
         Map.has_key?(params["subscription_details"], "proration_behavior")) or
      items_has?(params["items"]) or
      phases_has?(params["phases"])
  end

  # Detects whether any element of an `items[]` array carries a
  # `"proration_behavior"` key. Defensive against nil, non-list, and
  # non-map list elements.
  defp items_has?(items) when is_list(items) do
    Enum.any?(items, fn
      item when is_map(item) -> Map.has_key?(item, "proration_behavior")
      _ -> false
    end)
  end

  defp items_has?(_), do: false

  # Detects whether any element of a `phases[]` array carries a
  # `"proration_behavior"` key at the phase level. Defensive against nil,
  # non-list, and non-map list elements.
  #
  # NOTE: Stripe only accepts `proration_behavior` at top-level and at
  # `phases[].proration_behavior` on POST /v1/subscription_schedules/:id —
  # it does NOT accept it at `phases[].items[]`. Do not walk deeper.
  # Source: https://docs.stripe.com/api/subscription_schedules/update
  defp phases_has?(phases) when is_list(phases) do
    Enum.any?(phases, fn
      phase when is_map(phase) -> Map.has_key?(phase, "proration_behavior")
      _ -> false
    end)
  end

  defp phases_has?(_), do: false
end
