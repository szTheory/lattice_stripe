defmodule LatticeStripe.Tax.TransactionTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Testing.Fixtures.TaxTransaction

  alias LatticeStripe.{Error, List, Response}
  alias LatticeStripe.Tax.Transaction
  alias LatticeStripe.Tax.Transaction.LineItem

  setup :verify_on_exit!

  describe "create_from_calculation/3" do
    test "sends POST create_from_calculation with calculation and reference" do
      client = test_client()
      reference = "order_#{System.unique_integer([:positive])}"

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/tax/transactions/create_from_calculation")
        assert req.body =~ "calculation=taxcalc_test123"
        assert req.body =~ "reference=#{reference}"
        ok_response(tax_transaction_json(%{"reference" => reference}))
      end)

      assert {:ok, %Transaction{reference: ^reference}} =
               Transaction.create_from_calculation(client, %{
                 "calculation" => "taxcalc_test123",
                 "reference" => reference
               })
    end

    test "returns reference_already_exists error" do
      client = test_client()
      reference = "order_#{System.unique_integer([:positive])}"

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        {:ok,
         %{
           status: 400,
           headers: [{"request-id", "req_dup"}],
           body:
             Jason.encode!(%{
               "error" => %{
                 "type" => "invalid_request_error",
                 "code" => "reference_already_exists",
                 "message" => "Reference already exists."
               }
             })
         }}
      end)

      assert {:error, %Error{code: "reference_already_exists"}} =
               Transaction.create_from_calculation(client, %{
                 "calculation" => "taxcalc_test123",
                 "reference" => reference
               })
    end
  end

  describe "create_reversal/3" do
    test "sends POST create_reversal with mode and original_transaction" do
      client = test_client()
      reference = "order_#{System.unique_integer([:positive])}-rev"

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/tax/transactions/create_reversal")
        assert req.body =~ "mode=full"
        assert req.body =~ "original_transaction=tax_1test123"
        assert req.body =~ "reference=#{reference}"
        ok_response(tax_transaction_json(%{"type" => "reversal", "reference" => reference}))
      end)

      assert {:ok, %Transaction{type: "reversal"}} =
               Transaction.create_reversal(client, %{
                 "mode" => "full",
                 "original_transaction" => "tax_1test123",
                 "reference" => reference
               })
    end
  end

  describe "retrieve/3" do
    test "sends GET /v1/tax/transactions/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/tax/transactions/tax_1test123")
        ok_response(tax_transaction_json())
      end)

      assert {:ok, %Transaction{id: "tax_1test123"}} =
               Transaction.retrieve(client, "tax_1test123")
    end
  end

  describe "list_line_items/4" do
    test "hits /v1/tax/transactions/:id/line_items and returns typed line items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/tax/transactions/tax_1test123/line_items"

        ok_response(
          list_json(
            [tax_transaction_line_item_json()],
            "/v1/tax/transactions/tax_1test123/line_items"
          )
        )
      end)

      assert {:ok, %Response{data: %List{data: [%LineItem{object: "tax.transaction_line_item"}]}}} =
               Transaction.list_line_items(client, "tax_1test123")
    end
  end

end
