defmodule LatticeStripe.Builders.BillingPortal do
  @moduledoc """
  Optional fluent builders for `LatticeStripe.BillingPortal.Session` flow_data params.

  These builders construct the nested `flow_data` map that `Session.create/3` expects,
  using named constructor functions for each portal flow type. Builder output passes
  `LatticeStripe.BillingPortal.Guards.check_flow_data!/1` validation automatically.

  ## Usage

      alias LatticeStripe.Builders.BillingPortal, as: BPBuilder

      # Build the flow_data map
      flow = BPBuilder.subscription_cancel("sub_abc123")

      # Pass directly to Session.create/3
      {:ok, session} = LatticeStripe.BillingPortal.Session.create(client, %{
        "customer" => "cus_xyz",
        "flow_data" => flow
      })

  ## With after_completion

      after_completion = %{"type" => "redirect", "redirect" => %{"return_url" => "https://example.com/done"}}

      flow = BPBuilder.subscription_cancel("sub_abc123", after_completion: after_completion)

  All builder functions accept an optional `after_completion` keyword argument that is
  included in the top-level flow_data map. The `after_completion` value should be a raw
  map matching the Stripe API shape.

  ## Alias Suggestion

  Because the module name is long, we recommend aliasing at the call site:

      alias LatticeStripe.Builders.BillingPortal, as: BPBuilder
  """

  @doc """
  Builds a `subscription_cancel` flow_data map.

  ## Parameters

  - `subscription_id` - The Stripe subscription ID (`sub_*`) to prefill in the cancel flow.
  - `opts` - Optional keyword list:
    - `:retention` - A raw map for the retention offer object (e.g. `%{"type" => "coupon_offer", ...}`).
    - `:after_completion` - A raw map for the after-completion action.

  ## Returns

  A map with string keys matching the Stripe API `flow_data` shape for `subscription_cancel`.

  ## Example

      BPBuilder.subscription_cancel("sub_abc")
      # => %{"type" => "subscription_cancel", "subscription_cancel" => %{"subscription" => "sub_abc"}}

      BPBuilder.subscription_cancel("sub_abc", retention: %{"type" => "coupon_offer"})
  """
  @spec subscription_cancel(String.t(), keyword()) :: map()
  def subscription_cancel(subscription_id, opts \\ []) when is_binary(subscription_id) do
    sub_cancel = %{"subscription" => subscription_id}
    sub_cancel = if opts[:retention], do: Map.put(sub_cancel, "retention", opts[:retention]), else: sub_cancel

    base = %{"type" => "subscription_cancel", "subscription_cancel" => sub_cancel}
    maybe_after_completion(base, opts)
  end

  @doc """
  Builds a `subscription_update` flow_data map.

  ## Parameters

  - `subscription_id` - The Stripe subscription ID (`sub_*`) to prefill in the update flow.
  - `opts` - Optional keyword list:
    - `:after_completion` - A raw map for the after-completion action.

  ## Returns

  A map with string keys matching the Stripe API `flow_data` shape for `subscription_update`.

  ## Example

      BPBuilder.subscription_update("sub_abc")
      # => %{"type" => "subscription_update", "subscription_update" => %{"subscription" => "sub_abc"}}
  """
  @spec subscription_update(String.t(), keyword()) :: map()
  def subscription_update(subscription_id, opts \\ []) when is_binary(subscription_id) do
    base = %{
      "type" => "subscription_update",
      "subscription_update" => %{"subscription" => subscription_id}
    }

    maybe_after_completion(base, opts)
  end

  @doc """
  Builds a `subscription_update_confirm` flow_data map.

  ## Parameters

  - `subscription_id` - The Stripe subscription ID (`sub_*`) to update.
  - `items` - A non-empty list of subscription item maps (e.g. `[%{"id" => "si_abc", "price" => "price_123"}]`).
    An empty list raises `FunctionClauseError` — Stripe requires at least one item.
  - `opts` - Optional keyword list:
    - `:discounts` - A list of discount objects to apply.
    - `:after_completion` - A raw map for the after-completion action.

  ## Returns

  A map with string keys matching the Stripe API `flow_data` shape for `subscription_update_confirm`.

  ## Example

      items = [%{"id" => "si_abc", "price" => "price_123"}]
      BPBuilder.subscription_update_confirm("sub_abc", items)
      # => %{
      #   "type" => "subscription_update_confirm",
      #   "subscription_update_confirm" => %{
      #     "subscription" => "sub_abc",
      #     "items" => [%{"id" => "si_abc", "price" => "price_123"}]
      #   }
      # }
  """
  @spec subscription_update_confirm(String.t(), [map()], keyword()) :: map()
  def subscription_update_confirm(subscription_id, items, opts \\ [])
      when is_binary(subscription_id) and is_list(items) and items != [] do
    sub_confirm = %{"subscription" => subscription_id, "items" => items}
    sub_confirm = if opts[:discounts], do: Map.put(sub_confirm, "discounts", opts[:discounts]), else: sub_confirm

    base = %{"type" => "subscription_update_confirm", "subscription_update_confirm" => sub_confirm}
    maybe_after_completion(base, opts)
  end

  @doc """
  Builds a `payment_method_update` flow_data map.

  This flow type has no required sub-fields. The portal prompts the customer to
  update their payment method.

  ## Parameters

  - `opts` - Optional keyword list:
    - `:after_completion` - A raw map for the after-completion action.

  ## Returns

  A map with string keys matching the Stripe API `flow_data` shape for `payment_method_update`.

  ## Example

      BPBuilder.payment_method_update()
      # => %{"type" => "payment_method_update"}
  """
  @spec payment_method_update(keyword()) :: map()
  def payment_method_update(opts \\ []) do
    base = %{"type" => "payment_method_update"}
    maybe_after_completion(base, opts)
  end

  defp maybe_after_completion(base, opts) do
    if opts[:after_completion],
      do: Map.put(base, "after_completion", opts[:after_completion]),
      else: base
  end
end
