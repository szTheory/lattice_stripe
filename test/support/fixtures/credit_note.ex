defmodule LatticeStripe.Test.Fixtures.CreditNote do
  @moduledoc false

  alias LatticeStripe.{CreditNote, Customer, Invoice, InvoiceItem}

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

  def create_creditable_invoice!(client, attrs \\ %{}) do
    {:ok, customer} =
      Customer.create(client, %{
        "email" => Map.get(attrs, "customer_email", "credit-note-test@example.com")
      })

    invoice_params =
      %{
        "customer" => customer.id,
        "auto_advance" => false,
        "collection_method" => "send_invoice",
        "days_until_due" => 30
      }
      |> Map.merge(Map.drop(attrs, ["customer_email", "invoice_item"]))

    {:ok, invoice} = Invoice.create(client, invoice_params)

    invoice_item_params =
      %{
        "customer" => customer.id,
        "invoice" => invoice.id,
        "amount" => 500,
        "currency" => "usd",
        "description" => "Creditable line item"
      }
      |> Map.merge(Map.get(attrs, "invoice_item", %{}))

    {:ok, _item} = InvoiceItem.create(client, invoice_item_params)
    {:ok, finalized_invoice} = Invoice.finalize(client, invoice.id)
    finalized_invoice
  end

  def create_open_invoice_credit_note!(client, attrs \\ %{}) do
    invoice = create_creditable_invoice!(client, attrs)

    params =
      %{
        "invoice" => invoice.id,
        "lines" => [
          %{
            "type" => "custom_line_item",
            "description" => "Open invoice credit",
            "quantity" => 1,
            "unit_amount" => 500
          }
        ]
      }
      |> Map.merge(Map.get(attrs, "credit_note", %{}))

    {:ok, credit_note} = CreditNote.create(client, params)
    credit_note
  end
end
