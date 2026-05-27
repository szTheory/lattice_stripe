defmodule LatticeStripe.Tax.CalculationTransactionTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Testing.Fixtures.TaxCalculation
  import LatticeStripe.Testing.Fixtures.TaxTransaction

  alias LatticeStripe.Tax.{Calculation, Transaction}

  setup :verify_on_exit!

  test "canonical standalone tax flow" do
    client = test_client()
    calc_id = "taxcalc_#{System.unique_integer([:positive])}"
    reference = "order_#{System.unique_integer([:positive])}"
    reversal_ref = "#{reference}-rev"
    txn_id = "tax_#{System.unique_integer([:positive])}"

    expect(LatticeStripe.MockTransport, :request, fn req ->
      assert req.method == :post
      assert String.ends_with?(req.url, "/v1/tax/calculations")
      ok_response(tax_calculation_json(%{"id" => calc_id}))
    end)

    expect(LatticeStripe.MockTransport, :request, fn req ->
      assert req.method == :post
      assert String.ends_with?(req.url, "/v1/tax/transactions/create_from_calculation")
      assert req.body =~ calc_id
      assert req.body =~ "reference=#{reference}"

      ok_response(
        tax_transaction_json(%{
          "id" => txn_id,
          "reference" => reference
        })
      )
    end)

    expect(LatticeStripe.MockTransport, :request, fn req ->
      assert req.method == :get
      assert req.url =~ "/v1/tax/transactions/#{txn_id}"
      ok_response(tax_transaction_json(%{"id" => txn_id, "reference" => reference}))
    end)

    expect(LatticeStripe.MockTransport, :request, fn req ->
      assert req.method == :post
      assert String.ends_with?(req.url, "/v1/tax/transactions/create_reversal")
      assert req.body =~ "mode=full"
      assert req.body =~ "original_transaction=#{txn_id}"
      assert req.body =~ "reference=#{reversal_ref}"

      ok_response(
        tax_transaction_json(%{
          "type" => "reversal",
          "reference" => reversal_ref
        })
      )
    end)

    assert {:ok, %Calculation{id: ^calc_id}} =
             Calculation.create(client, %{
               "currency" => "usd",
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
               "line_items" => [
                 %{
                   "amount" => 1000,
                   "reference" => "line-1",
                   "tax_behavior" => "exclusive",
                   "tax_code" => "txcd_99999999"
                 }
               ]
             })

    assert {:ok, %Transaction{id: ^txn_id, reference: ^reference}} =
             Transaction.create_from_calculation(client, %{
               "calculation" => calc_id,
               "reference" => reference
             })

    assert {:ok, %Transaction{id: ^txn_id}} = Transaction.retrieve(client, txn_id)

    assert {:ok, %Transaction{type: "reversal", reference: ^reversal_ref}} =
             Transaction.create_reversal(client, %{
               "mode" => "full",
               "original_transaction" => txn_id,
               "reference" => reversal_ref
             })
  end
end
