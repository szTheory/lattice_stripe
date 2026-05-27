defmodule LatticeStripe.TaxIdTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.{List, Response, TaxId}
  alias LatticeStripe.TaxId.Verification

  setup :verify_on_exit!

  defp tax_id_json(overrides \\ %{}) do
    Map.merge(
      %{
        "object" => "tax_id",
        "id" => "txi_test123",
        "country" => "DE",
        "created" => 1_700_000_000,
        "livemode" => false,
        "type" => "eu_vat",
        "value" => "DE123456789"
      },
      overrides
    )
  end

  describe "module surface" do
    test "does not export update or search" do
      refute function_exported?(TaxId, :update, 3)
      refute function_exported?(TaxId, :update, 4)
      refute function_exported?(TaxId, :search, 2)
      refute function_exported?(TaxId, :search, 3)
    end

    test "exports dual-path create arities" do
      assert function_exported?(TaxId, :create, 3)
      assert function_exported?(TaxId, :create, 4)
    end
  end

  describe "top-level create/3" do
    test "POST /v1/tax_ids without customers in path" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/tax_ids")
        refute req.url =~ "/customers/"
        ok_response(tax_id_json())
      end)

      assert {:ok, %TaxId{id: "txi_test123"}} =
               TaxId.create(client, %{"type" => "eu_vat", "value" => "DE123456789"})
    end
  end

  describe "nested create/4" do
    test "POST /v1/customers/:id/tax_ids without customer in body" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert req.url =~ "/v1/customers/cus_test123/tax_ids"
        refute req.body =~ "customer="
        ok_response(tax_id_json())
      end)

      assert {:ok, %TaxId{id: "txi_test123"}} =
               TaxId.create(client, "cus_test123", %{
                 "type" => "eu_vat",
                 "value" => "DE123456789",
                 "customer" => "cus_should_be_stripped"
               })
    end

    test "strips atom-key customer from body" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert req.url =~ "/v1/customers/cus_test123/tax_ids"
        refute req.body =~ "customer="
        ok_response(tax_id_json())
      end)

      assert {:ok, %TaxId{id: "txi_test123"}} =
               TaxId.create(client, "cus_test123", %{
                 "type" => "eu_vat",
                 "value" => "DE123456789",
                 customer: "cus_should_be_stripped"
               })
    end
  end

  describe "top-level retrieve/3" do
    test "GET /v1/tax_ids/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/tax_ids/txi_test123")
        ok_response(tax_id_json())
      end)

      assert {:ok, %TaxId{id: "txi_test123"}} = TaxId.retrieve(client, "txi_test123")
    end
  end

  describe "nested retrieve/4" do
    test "GET /v1/customers/:customer_id/tax_ids/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/customers/cus_test123/tax_ids/txi_test123"
        ok_response(tax_id_json())
      end)

      assert {:ok, %TaxId{id: "txi_test123"}} =
               TaxId.retrieve(client, "cus_test123", "txi_test123")
    end
  end

  describe "top-level list/3" do
    test "GET /v1/tax_ids" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/tax_ids")
        refute req.url =~ "/customers/"
        ok_response(list_json([tax_id_json()], "/v1/tax_ids"))
      end)

      assert {:ok, %Response{data: %List{data: [%TaxId{id: "txi_test123"}]}}} =
               TaxId.list(client, %{})
    end
  end

  describe "nested list/4" do
    test "GET /v1/customers/:customer_id/tax_ids" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/customers/cus_test123/tax_ids"
        ok_response(list_json([tax_id_json()], "/v1/customers/cus_test123/tax_ids"))
      end)

      assert {:ok, %Response{data: %List{data: [%TaxId{id: "txi_test123"}]}}} =
               TaxId.list(client, "cus_test123", %{})
    end
  end

  describe "top-level delete/3" do
    test "DELETE /v1/tax_ids/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :delete
        assert String.ends_with?(req.url, "/v1/tax_ids/txi_test123")
        ok_response(tax_id_json(%{"deleted" => true}))
      end)

      assert {:ok, %TaxId{id: "txi_test123", deleted: true}} =
               TaxId.delete(client, "txi_test123")
    end
  end

  describe "nested delete/4" do
    test "DELETE /v1/customers/:customer_id/tax_ids/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :delete
        assert req.url =~ "/v1/customers/cus_test123/tax_ids/txi_test123"
        ok_response(tax_id_json(%{"deleted" => true}))
      end)

      assert {:ok, %TaxId{id: "txi_test123", deleted: true}} =
               TaxId.delete(client, "cus_test123", "txi_test123")
    end
  end

  describe "inspect" do
    test "TaxId redacts value and nested verification PII" do
      tax_id = %TaxId{
        id: "txi_test123",
        type: "eu_vat",
        value: "DE123456789",
        verification: %Verification{
          status: :verified,
          verified_name: "Acme GmbH",
          verified_address: "Berlin, DE"
        }
      }

      output = inspect(tax_id)

      refute output =~ "DE123456789"
      refute output =~ "Acme GmbH"
      refute output =~ "Berlin, DE"
      assert output =~ "[REDACTED]"
      assert output =~ "status: :verified"
    end

    test "nil PII fields do not print [REDACTED]" do
      tax_id = %TaxId{value: nil, verification: %Verification{verified_name: nil}}

      output = inspect(tax_id)
      refute output =~ "[REDACTED]"
    end
  end
end
