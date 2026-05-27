defmodule LatticeStripe.Testing.Fixtures.TaxTransaction do
  @moduledoc """
  Canonical raw fixtures for Stripe Tax Transaction objects.
  """

  @spec tax_transaction_json(map()) :: map()
  def tax_transaction_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "tax_1test123",
        "object" => "tax.transaction",
        "created" => 1_700_000_100,
        "currency" => "usd",
        "customer" => nil,
        "customer_details" => %{
          "address" => %{
            "line1" => "123 Main St",
            "city" => "Seattle",
            "state" => "WA",
            "postal_code" => "98101",
            "country" => "US"
          },
          "address_source" => "shipping"
        },
        "line_items" => %{
          "object" => "list",
          "data" => [tax_transaction_line_item_json()],
          "has_more" => false,
          "url" => "/v1/tax/transactions/tax_1test123/line_items"
        },
        "livemode" => false,
        "metadata" => %{},
        "posted_at" => 1_700_000_100,
        "reference" => "order_test_ref",
        "reversal" => nil,
        "shipping_cost" => %{
          "amount" => 500,
          "amount_tax" => 50,
          "tax_behavior" => "exclusive"
        },
        "tax_date" => 1_700_000_000,
        "type" => "transaction"
      },
      overrides
    )
  end

  @spec tax_transaction_line_item_json(map()) :: map()
  def tax_transaction_line_item_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "taxtli_test123",
        "object" => "tax.transaction_line_item",
        "amount" => 1000,
        "amount_tax" => 100,
        "livemode" => false,
        "quantity" => 1,
        "reference" => "line-1",
        "tax_behavior" => "exclusive",
        "tax_code" => "txcd_99999999",
        "type" => "transaction"
      },
      overrides
    )
  end
end
