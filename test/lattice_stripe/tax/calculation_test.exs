defmodule LatticeStripe.Tax.CalculationTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Testing.Fixtures.TaxCalculation

  alias LatticeStripe.{Error, List, Response}
  alias LatticeStripe.Tax.Calculation
  alias LatticeStripe.Tax.Calculation.LineItem

  setup :verify_on_exit!

  describe "create/3" do
    test "sends POST /v1/tax/calculations and returns typed calculation" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/tax/calculations")
        assert req.body =~ "currency=usd"
        ok_response(tax_calculation_json())
      end)

      assert {:ok, %Calculation{id: "taxcalc_test123", currency: "usd"}} =
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
    end
  end

  describe "retrieve/3" do
    test "sends GET /v1/tax/calculations/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/tax/calculations/taxcalc_test123")
        ok_response(tax_calculation_json())
      end)

      assert {:ok, %Calculation{id: "taxcalc_test123"}} =
               Calculation.retrieve(client, "taxcalc_test123")
    end

    test "returns resource_expired error for expired calculations" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        {:ok,
         %{
           status: 400,
           headers: [{"request-id", "req_expired"}],
           body:
             Jason.encode!(%{
               "error" => %{
                 "type" => "invalid_request_error",
                 "code" => "resource_expired",
                 "message" => "This calculation has expired."
               }
             })
         }}
      end)

      assert {:error, %Error{code: "resource_expired"}} =
               Calculation.retrieve(client, "taxcalc_expired")
    end
  end

  describe "list_line_items/4" do
    test "hits /v1/tax/calculations/:id/line_items and returns typed line items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/tax/calculations/taxcalc_test123/line_items"

        ok_response(
          list_json(
            [tax_calculation_line_item_json()],
            "/v1/tax/calculations/taxcalc_test123/line_items"
          )
        )
      end)

      assert {:ok, %Response{data: %List{data: [%LineItem{object: "tax.calculation_line_item"}]}}} =
               Calculation.list_line_items(client, "taxcalc_test123")
    end
  end

  describe "create!/3" do
    test "returns calculation directly on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(tax_calculation_json())
      end)

      assert %Calculation{id: "taxcalc_test123"} =
               Calculation.create!(client, %{"currency" => "usd", "line_items" => []})
    end
  end
end
