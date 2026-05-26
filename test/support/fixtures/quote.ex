defmodule LatticeStripe.Test.Fixtures.Quote do
  @moduledoc false

  alias LatticeStripe.{Customer, Product, Quote}

  def quote_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "qt_test1234567890abc",
        "object" => "quote",
        "amount_subtotal" => 2_000,
        "amount_total" => 2_000,
        "application" => nil,
        "application_fee_amount" => nil,
        "application_fee_percent" => nil,
        "automatic_tax" => %{"enabled" => false, "status" => nil},
        "collection_method" => "charge_automatically",
        "computed" => %{
          "upfront" => %{
            "amount_subtotal" => 2_000,
            "amount_total" => 2_000,
            "line_items" => %{
              "object" => "list",
              "data" => [quote_computed_upfront_line_item_json()],
              "has_more" => false,
              "url" => "/v1/quotes/qt_test1234567890abc/computed_upfront_line_items"
            },
            "total_details" => %{"amount_discount" => 0, "amount_tax" => 0}
          },
          "recurring" => %{
            "amount_subtotal" => 1_500,
            "amount_total" => 1_500,
            "interval" => "month",
            "interval_count" => 1,
            "line_items" => [quote_line_item_json(%{"id" => "qli_recurring_123"})],
            "total_details" => %{"amount_discount" => 0, "amount_tax" => 0}
          }
        },
        "created" => 1_700_000_000,
        "currency" => "usd",
        "customer" => "cus_test1234567890abc",
        "default_tax_rates" => [],
        "description" => "Pro annual plan",
        "discounts" => [],
        "expires_at" => 1_700_086_400,
        "footer" => "Net 30",
        "from_quote" => %{"is_revision" => false, "quote" => nil},
        "header" => "Proposal",
        "invoice" => "in_test1234567890abc",
        "invoice_settings" => %{"days_until_due" => 30},
        "line_items" => %{
          "object" => "list",
          "data" => [quote_line_item_json()],
          "has_more" => false,
          "url" => "/v1/quotes/qt_test1234567890abc/line_items"
        },
        "livemode" => false,
        "metadata" => %{"opportunity" => "opp_123"},
        "number" => nil,
        "on_behalf_of" => nil,
        "status" => "draft",
        "status_transitions" => %{
          "accepted_at" => nil,
          "canceled_at" => nil,
          "finalized_at" => nil
        },
        "subscription" => "sub_test1234567890abc",
        "subscription_data" => %{"effective_date" => nil},
        "subscription_schedule" => "sub_sched_test1234567890abc",
        "test_clock" => nil,
        "total_details" => %{"amount_discount" => 0, "amount_tax" => 0},
        "transfer_data" => nil
      },
      overrides
    )
  end

  def open_quote_json(overrides \\ %{}) do
    Map.merge(
      quote_json(%{
        "number" => "QT-2026-0001",
        "status" => "open",
        "status_transitions" => %{
          "accepted_at" => nil,
          "canceled_at" => nil,
          "finalized_at" => 1_700_000_100
        }
      }),
      overrides
    )
  end

  def accepted_quote_json(overrides \\ %{}) do
    Map.merge(
      open_quote_json(%{
        "status" => "accepted",
        "status_transitions" => %{
          "accepted_at" => 1_700_000_200,
          "canceled_at" => nil,
          "finalized_at" => 1_700_000_100
        }
      }),
      overrides
    )
  end

  def canceled_quote_json(overrides \\ %{}) do
    Map.merge(
      quote_json(%{
        "status" => "canceled",
        "status_transitions" => %{
          "accepted_at" => nil,
          "canceled_at" => 1_700_000_150,
          "finalized_at" => nil
        }
      }),
      overrides
    )
  end

  def quote_line_item_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "qli_test1234567890abc",
        "object" => "quote_line_item",
        "amount_discount" => 0,
        "amount_subtotal" => 2_000,
        "amount_tax" => 0,
        "amount_total" => 2_000,
        "currency" => "usd",
        "description" => "Pro plan",
        "discounts" => [],
        "period" => %{"start" => 1_700_000_000, "end" => 1_702_592_000},
        "pricing" => %{
          "price_details" => %{"price" => "price_123", "product" => "prod_123"},
          "type" => "price_details",
          "unit_amount_decimal" => "2000"
        },
        "quantity" => 1,
        "taxes" => []
      },
      overrides
    )
  end

  def quote_computed_upfront_line_item_json(overrides \\ %{}) do
    Map.merge(
      quote_line_item_json(%{
        "id" => "qli_upfront1234567890abc",
        "description" => "Setup fee",
        "amount_subtotal" => 500,
        "amount_total" => 500,
        "pricing" => %{
          "price_details" => %{"price" => "price_setup_123", "product" => "prod_setup_123"},
          "type" => "price_details",
          "unit_amount_decimal" => "500"
        }
      }),
      overrides
    )
  end

  def expanded_quote_json(overrides \\ %{}) do
    Map.merge(
      accepted_quote_json(%{
        "customer" => %{"id" => "cus_test1234567890abc", "object" => "customer"},
        "invoice" => %{"id" => "in_test1234567890abc", "object" => "invoice"},
        "subscription" => %{"id" => "sub_test1234567890abc", "object" => "subscription"},
        "subscription_schedule" => %{
          "id" => "sub_sched_test1234567890abc",
          "object" => "subscription_schedule"
        }
      }),
      overrides
    )
  end

  def create_quote_customer!(client, attrs \\ %{}) do
    {:ok, customer} =
      Customer.create(client, %{
        "email" => Map.get(attrs, "customer_email", "quote-test@example.com")
      })

    customer
  end

  def create_quote_product!(client, attrs \\ %{}) do
    {:ok, product} =
      Product.create(client, %{
        "name" => Map.get(attrs, "product_name", "Quote fixture product")
      })

    product
  end

  def create_quote!(client, attrs \\ %{}) do
    customer = create_quote_customer!(client, attrs)
    product = create_quote_product!(client, attrs)

    params =
      %{
        "customer" => customer.id,
        "line_items" => [
          %{
            "price_data" => %{
              "currency" => "usd",
              "product" => product.id,
              "unit_amount" => 2_000,
              "recurring" => %{"interval" => "month"}
            },
            "quantity" => 1
          }
        ]
      }
      |> Map.merge(Map.get(attrs, "quote", %{}))

    {:ok, quote} = Quote.create(client, params)
    quote
  end
end
