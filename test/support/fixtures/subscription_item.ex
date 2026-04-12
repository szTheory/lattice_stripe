defmodule LatticeStripe.Test.Fixtures.SubscriptionItem do
  @moduledoc false

  @doc "Basic subscription item with id, quantity, and price map."
  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "si_test1234567890",
        "object" => "subscription_item",
        "subscription" => "sub_test1234567890",
        "quantity" => 1,
        "price" => %{
          "id" => "price_test1",
          "object" => "price",
          "unit_amount" => 1000,
          "currency" => "usd"
        },
        "created" => 1_700_000_000,
        "metadata" => %{},
        "tax_rates" => []
      },
      overrides
    )
  end

  @doc "Item with an explicit proration_behavior for strict-client tests."
  def with_proration(overrides \\ %{}) do
    basic(Map.merge(%{"proration_behavior" => "create_prorations"}, overrides))
  end

  @doc "Stripe-shaped list response wrapping N basic items."
  def list_response(count) when is_integer(count) and count >= 0 do
    %{
      "object" => "list",
      "data" =>
        for i <- 1..max(count, 1)//1, count > 0 do
          basic(%{"id" => "si_test#{i}"})
        end,
      "has_more" => false,
      "url" => "/v1/subscription_items"
    }
  end
end
