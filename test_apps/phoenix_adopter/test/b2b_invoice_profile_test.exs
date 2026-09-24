defmodule PhoenixAdopter.B2BInvoiceProfileTest do
  use ExUnit.Case, async: true

  import Mox

  alias LatticeStripe.{Client, Invoice}

  @invoice_id "in_test_adopter_b2b_123"
  @api_version "2026-05-27.dahlia"

  setup :verify_on_exit!

  test "versioned invoice retrieval exposes typed off-Stripe amount" do
    expect(PhoenixAdopter.MockTransport, :request, fn request ->
      assert request.method == :get
      assert String.ends_with?(request.url, "/v1/invoices/#{@invoice_id}")

      assert Enum.find_value(request.headers, fn {name, value} ->
               if String.downcase(name) == "stripe-version", do: value
             end) == @api_version

      {:ok,
       %{
         status: 200,
         headers: [{"content-type", "application/json"}],
         body:
           Jason.encode!(%{
             "id" => @invoice_id,
             "object" => "invoice",
             "amount_paid" => 300,
             "amount_paid_off_stripe" => 700
           })
       }}
    end)

    client =
      Client.new!(
        api_key: "sk_test_synthetic_adopter_key",
        transport: PhoenixAdopter.MockTransport,
        max_retries: 0,
        telemetry_enabled: false
      )

    assert {:ok, %Invoice{amount_paid: 300, amount_paid_off_stripe: 700}} =
             Invoice.retrieve(client, @invoice_id, stripe_version: @api_version)
  end
end
