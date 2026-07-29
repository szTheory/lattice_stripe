defmodule LatticeStripe.Testing.Fixtures.Invoice do
  @moduledoc """
  Canonical raw fixtures for Stripe Invoice objects.
  """

  @spec invoice_json(map()) :: map()
  def invoice_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "in_test1234567890",
        "object" => "invoice",
        "status" => "draft",
        "collection_method" => "charge_automatically",
        "billing_reason" => "manual",
        "customer_tax_exempt" => "none",
        "amount_due" => 2000,
        "amount_paid" => 0,
        "amount_remaining" => 2000,
        "currency" => "usd",
        "customer" => "cus_test123",
        "livemode" => false,
        "metadata" => %{},
        "created" => 1_700_000_000,
        "period_start" => 1_700_000_000,
        "period_end" => 1_702_679_200,
        "subtotal" => 2000,
        "total" => 2000,
        "paid" => false,
        "attempted" => false,
        "attempt_count" => 0,
        "auto_advance" => false,
        "automatic_tax" => %{
          "enabled" => false,
          "status" => nil,
          "liability" => nil
        },
        "status_transitions" => %{
          "finalized_at" => nil,
          "marked_uncollectible_at" => nil,
          "paid_at" => nil,
          "voided_at" => nil
        },
        "lines" => %{
          "object" => "list",
          "data" => [],
          "has_more" => false,
          "url" => "/v1/invoices/in_test1234567890/lines"
        }
      },
      overrides
    )
  end
end
