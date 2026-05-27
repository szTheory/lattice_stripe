defmodule LatticeStripe.Testing.Fixtures.TaxCalculation do
  @moduledoc """
  Canonical raw fixtures for Stripe Tax Calculation objects.
  """

  @spec tax_calculation_json(map()) :: map()
  def tax_calculation_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "taxcalc_test123",
        "object" => "tax.calculation",
        "amount_total" => 1100,
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
          "address_source" => "shipping",
          "taxability_override" => "none"
        },
        "expires_at" => 1_800_000_000,
        "line_items" => %{
          "object" => "list",
          "data" => [tax_calculation_line_item_json()],
          "has_more" => false,
          "url" => "/v1/tax/calculations/taxcalc_test123/line_items"
        },
        "livemode" => false,
        "ship_from_details" => %{
          "address" => %{
            "line1" => "456 Warehouse Rd",
            "city" => "San Francisco",
            "state" => "CA",
            "postal_code" => "94103",
            "country" => "US"
          }
        },
        "shipping_cost" => %{
          "amount" => 500,
          "amount_tax" => 50,
          "tax_behavior" => "exclusive",
          "tax_code" => "txcd_92010001"
        },
        "tax_amount_exclusive" => 100,
        "tax_amount_inclusive" => 0,
        "tax_breakdown" => [
          %{
            "amount" => 100,
            "inclusive" => false,
            "taxability_reason" => "standard_rated",
            "taxable_amount" => 1000,
            "tax_rate_details" => %{
              "country" => "US",
              "percentage_decimal" => "10.0",
              "state" => "WA",
              "tax_type" => "sales_tax"
            }
          }
        ],
        "tax_date" => 1_700_000_000
      },
      overrides
    )
  end

  @spec tax_calculation_line_item_json(map()) :: map()
  def tax_calculation_line_item_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "taxcli_test123",
        "object" => "tax.calculation_line_item",
        "amount" => 1000,
        "amount_tax" => 100,
        "livemode" => false,
        "metadata" => %{},
        "quantity" => 1,
        "reference" => "line-1",
        "tax_behavior" => "exclusive",
        "tax_code" => "txcd_99999999"
      },
      overrides
    )
  end
end
