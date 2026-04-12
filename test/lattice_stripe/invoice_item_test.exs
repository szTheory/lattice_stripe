defmodule LatticeStripe.InvoiceItemTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.{Error, InvoiceItem, List, Response}
  alias LatticeStripe.InvoiceItem.Period

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # Fixture helpers
  # ---------------------------------------------------------------------------

  defp invoice_item_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "ii_test1234567890",
        "object" => "invoiceitem",
        "amount" => 2000,
        "currency" => "usd",
        "customer" => "cus_test123",
        "date" => 1_700_000_000,
        "description" => "Professional services",
        "discountable" => true,
        "invoice" => "in_test123",
        "livemode" => false,
        "metadata" => %{},
        "period" => %{
          "start" => 1_700_000_000,
          "end" => 1_702_679_200
        },
        "proration" => false,
        "quantity" => 1,
        "unit_amount" => 2000,
        "unit_amount_decimal" => "2000"
      },
      overrides
    )
  end

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert InvoiceItem.from_map(nil) == nil
    end

    test "maps basic known fields" do
      item = InvoiceItem.from_map(invoice_item_json())

      assert item.id == "ii_test1234567890"
      assert item.object == "invoiceitem"
      assert item.amount == 2000
      assert item.currency == "usd"
      assert item.customer == "cus_test123"
      assert item.livemode == false
    end

    test "parses period nested struct" do
      item =
        InvoiceItem.from_map(
          invoice_item_json(%{
            "period" => %{
              "start" => 1_700_000_000,
              "end" => 1_702_679_200
            }
          })
        )

      assert %Period{start: 1_700_000_000, end: 1_702_679_200} = item.period
    end

    test "parses period as nil when missing" do
      item = InvoiceItem.from_map(invoice_item_json(%{"period" => nil}))
      assert item.period == nil
    end

    test "captures unknown fields in extra map" do
      item =
        InvoiceItem.from_map(invoice_item_json(%{"unknown_field" => "value", "future_key" => 42}))

      assert item.extra["unknown_field"] == "value"
      assert item.extra["future_key"] == 42
    end

    test "known fields do not appear in extra" do
      item = InvoiceItem.from_map(invoice_item_json())
      refute Map.has_key?(item.extra, "id")
      refute Map.has_key?(item.extra, "amount")
    end

    test "defaults object to invoiceitem" do
      item = InvoiceItem.from_map(%{"id" => "ii_abc"})
      assert item.object == "invoiceitem"
    end
  end

  # ---------------------------------------------------------------------------
  # create/3
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "sends POST /v1/invoiceitems and returns {:ok, %InvoiceItem{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/invoiceitems")
        ok_response(invoice_item_json())
      end)

      assert {:ok, %InvoiceItem{id: "ii_test1234567890"}} =
               InvoiceItem.create(client, %{
                 "customer" => "cus_test123",
                 "amount" => 2000,
                 "currency" => "usd"
               })
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{type: :invalid_request_error}} = InvoiceItem.create(client, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/invoiceitems/:id and returns {:ok, %InvoiceItem{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/invoiceitems/ii_test1234567890")
        ok_response(invoice_item_json())
      end)

      assert {:ok, %InvoiceItem{id: "ii_test1234567890"}} =
               InvoiceItem.retrieve(client, "ii_test1234567890")
    end

    test "returns {:error, %Error{}} when not found" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = InvoiceItem.retrieve(client, "ii_missing")
    end
  end

  # ---------------------------------------------------------------------------
  # update/4
  # ---------------------------------------------------------------------------

  describe "update/4" do
    test "sends POST /v1/invoiceitems/:id and returns {:ok, %InvoiceItem{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/invoiceitems/ii_test1234567890")
        assert req.body =~ "description=Updated"
        ok_response(invoice_item_json(%{"description" => "Updated"}))
      end)

      assert {:ok, %InvoiceItem{description: "Updated"}} =
               InvoiceItem.update(client, "ii_test1234567890", %{"description" => "Updated"})
    end
  end

  # ---------------------------------------------------------------------------
  # delete/3
  # ---------------------------------------------------------------------------

  describe "delete/3" do
    test "sends DELETE /v1/invoiceitems/:id and returns {:ok, %InvoiceItem{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :delete
        assert String.ends_with?(req.url, "/v1/invoiceitems/ii_test1234567890")

        ok_response(%{
          "id" => "ii_test1234567890",
          "object" => "invoiceitem",
          "deleted" => true
        })
      end)

      assert {:ok, %InvoiceItem{id: "ii_test1234567890"}} =
               InvoiceItem.delete(client, "ii_test1234567890")
    end
  end

  # ---------------------------------------------------------------------------
  # list/3
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "sends GET /v1/invoiceitems and returns {:ok, %Response{data: %List{}}} with typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/invoiceitems")
        ok_response(list_json([invoice_item_json()], "/v1/invoiceitems"))
      end)

      assert {:ok, %Response{data: %List{data: [%InvoiceItem{id: "ii_test1234567890"}]}}} =
               InvoiceItem.list(client)
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = InvoiceItem.list(client)
    end
  end

  # ---------------------------------------------------------------------------
  # create!/3 (bang)
  # ---------------------------------------------------------------------------

  describe "create!/3" do
    test "returns %InvoiceItem{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(invoice_item_json())
      end)

      assert %InvoiceItem{id: "ii_test1234567890"} = InvoiceItem.create!(client, %{})
    end

    test "raises %Error{} on failure" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        InvoiceItem.create!(client, %{})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Inspect
  # ---------------------------------------------------------------------------

  describe "Inspect" do
    test "inspect output contains id and object" do
      item = InvoiceItem.from_map(invoice_item_json())
      inspected = inspect(item)
      assert inspected =~ "ii_test1234567890"
      assert inspected =~ "invoiceitem"
    end

    test "inspect hides extra when empty" do
      item = InvoiceItem.from_map(invoice_item_json())
      inspected = inspect(item)
      refute inspected =~ "extra:"
    end

    test "inspect shows extra when non-empty" do
      item = InvoiceItem.from_map(invoice_item_json(%{"unknown_key" => "val"}))
      inspected = inspect(item)
      assert inspected =~ "extra:"
    end
  end
end
