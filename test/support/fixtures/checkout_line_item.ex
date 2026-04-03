defmodule LatticeStripe.Test.Fixtures.Checkout.LineItem do
  @moduledoc false

  def line_item_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "li_test1234567890abc",
        "object" => "item",
        "amount_discount" => 0,
        "amount_subtotal" => 2000,
        "amount_tax" => 0,
        "amount_total" => 2000,
        "currency" => "usd",
        "description" => "T-Shirt",
        "price" => %{
          "id" => "price_test123",
          "object" => "price",
          "unit_amount" => 2000,
          "currency" => "usd",
          "product" => "prod_test123"
        },
        "quantity" => 1
      },
      overrides
    )
  end
end
