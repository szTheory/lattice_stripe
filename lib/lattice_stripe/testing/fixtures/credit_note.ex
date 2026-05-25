defmodule LatticeStripe.Testing.Fixtures.CreditNote do
  @moduledoc """
  Canonical raw fixtures for Stripe CreditNote objects.
  """

  @spec credit_note_json(map()) :: map()
  def credit_note_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "cn_test1234567890abc",
        "object" => "credit_note",
        "amount" => 500,
        "amount_shipping" => 0,
        "created" => 1_700_000_000,
        "currency" => "usd",
        "customer" => "cus_test1234567890abc",
        "customer_balance_transaction" => "cbtxn_test1234567890abc",
        "effective_at" => 1_700_000_001,
        "invoice" => "in_test1234567890abc",
        "lines" => %{
          "object" => "list",
          "data" => [credit_note_line_item_json()],
          "has_more" => false,
          "url" => "/v1/credit_notes/cn_test1234567890abc/lines"
        },
        "livemode" => false,
        "memo" => "Support adjustment",
        "metadata" => %{"ticket" => "123"},
        "number" => "C9E0-1234-CN-01",
        "out_of_band_amount" => 0,
        "pdf" => "https://example.com/credit_note.pdf",
        "pre_payment_amount" => 500,
        "post_payment_amount" => 0,
        "reason" => "duplicate",
        "refunds" => [],
        "shipping_cost" => %{"amount_subtotal" => 0, "amount_tax" => 0},
        "status" => "issued",
        "subtotal" => 500,
        "subtotal_excluding_tax" => 500,
        "total" => 500,
        "total_excluding_tax" => 500,
        "total_taxes" => [],
        "type" => "pre_payment",
        "voided_at" => nil
      },
      overrides
    )
  end

  @spec credit_note_line_item_json(map()) :: map()
  def credit_note_line_item_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "cnli_test1234567890abc",
        "object" => "credit_note_line_item",
        "amount" => 500,
        "description" => "Credited invoice line item",
        "discount_amount" => 0,
        "discount_amounts" => [],
        "invoice_line_item" => "il_test1234567890abc",
        "livemode" => false,
        "pretax_credit_amounts" => [],
        "quantity" => 1,
        "tax_rates" => [],
        "taxes" => [],
        "type" => "invoice_line_item",
        "unit_amount" => 500,
        "unit_amount_decimal" => "500"
      },
      overrides
    )
  end

  @spec custom_credit_note_line_item_json(map()) :: map()
  def custom_credit_note_line_item_json(overrides \\ %{}) do
    Map.merge(
      credit_note_line_item_json(%{
        "description" => "Goodwill credit",
        "invoice_line_item" => nil,
        "type" => "custom_line_item"
      }),
      overrides
    )
  end
end
