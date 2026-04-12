defmodule LatticeStripe.InvoiceTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.{Error, Invoice, List, Response}
  alias LatticeStripe.Invoice.{AutomaticTax, LineItem, StatusTransitions}

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # Fixture helpers
  # ---------------------------------------------------------------------------

  defp invoice_json(overrides \\ %{}) do
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

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert Invoice.from_map(nil) == nil
    end

    test "maps basic known fields" do
      invoice = Invoice.from_map(invoice_json())

      assert invoice.id == "in_test1234567890"
      assert invoice.object == "invoice"
      assert invoice.livemode == false
      assert invoice.currency == "usd"
      assert invoice.amount_due == 2000
    end

    test "atomizes status: draft" do
      invoice = Invoice.from_map(invoice_json(%{"status" => "draft"}))
      assert invoice.status == :draft
    end

    test "atomizes status: open" do
      invoice = Invoice.from_map(invoice_json(%{"status" => "open"}))
      assert invoice.status == :open
    end

    test "atomizes status: paid" do
      invoice = Invoice.from_map(invoice_json(%{"status" => "paid"}))
      assert invoice.status == :paid
    end

    test "atomizes status: void" do
      invoice = Invoice.from_map(invoice_json(%{"status" => "void"}))
      assert invoice.status == :void
    end

    test "atomizes status: uncollectible" do
      invoice = Invoice.from_map(invoice_json(%{"status" => "uncollectible"}))
      assert invoice.status == :uncollectible
    end

    test "passes through unknown status as string" do
      invoice = Invoice.from_map(invoice_json(%{"status" => "future_status"}))
      assert invoice.status == "future_status"
    end

    test "atomizes collection_method: charge_automatically" do
      invoice = Invoice.from_map(invoice_json(%{"collection_method" => "charge_automatically"}))
      assert invoice.collection_method == :charge_automatically
    end

    test "atomizes collection_method: send_invoice" do
      invoice = Invoice.from_map(invoice_json(%{"collection_method" => "send_invoice"}))
      assert invoice.collection_method == :send_invoice
    end

    test "passes through unknown collection_method as string" do
      invoice = Invoice.from_map(invoice_json(%{"collection_method" => "future_method"}))
      assert invoice.collection_method == "future_method"
    end

    test "atomizes billing_reason: manual" do
      invoice = Invoice.from_map(invoice_json(%{"billing_reason" => "manual"}))
      assert invoice.billing_reason == :manual
    end

    test "atomizes billing_reason: subscription_cycle" do
      invoice = Invoice.from_map(invoice_json(%{"billing_reason" => "subscription_cycle"}))
      assert invoice.billing_reason == :subscription_cycle
    end

    test "atomizes billing_reason: subscription_create" do
      invoice = Invoice.from_map(invoice_json(%{"billing_reason" => "subscription_create"}))
      assert invoice.billing_reason == :subscription_create
    end

    test "atomizes billing_reason: upcoming" do
      invoice = Invoice.from_map(invoice_json(%{"billing_reason" => "upcoming"}))
      assert invoice.billing_reason == :upcoming
    end

    test "passes through unknown billing_reason as string" do
      invoice = Invoice.from_map(invoice_json(%{"billing_reason" => "new_reason"}))
      assert invoice.billing_reason == "new_reason"
    end

    test "atomizes customer_tax_exempt: none" do
      invoice = Invoice.from_map(invoice_json(%{"customer_tax_exempt" => "none"}))
      assert invoice.customer_tax_exempt == :none
    end

    test "atomizes customer_tax_exempt: exempt" do
      invoice = Invoice.from_map(invoice_json(%{"customer_tax_exempt" => "exempt"}))
      assert invoice.customer_tax_exempt == :exempt
    end

    test "atomizes customer_tax_exempt: reverse" do
      invoice = Invoice.from_map(invoice_json(%{"customer_tax_exempt" => "reverse"}))
      assert invoice.customer_tax_exempt == :reverse
    end

    test "passes through unknown customer_tax_exempt as string" do
      invoice = Invoice.from_map(invoice_json(%{"customer_tax_exempt" => "new_value"}))
      assert invoice.customer_tax_exempt == "new_value"
    end

    test "parses status_transitions nested struct" do
      invoice =
        Invoice.from_map(
          invoice_json(%{
            "status_transitions" => %{
              "finalized_at" => 1_700_000_100,
              "marked_uncollectible_at" => nil,
              "paid_at" => 1_700_000_200,
              "voided_at" => nil
            }
          })
        )

      assert %StatusTransitions{finalized_at: 1_700_000_100, paid_at: 1_700_000_200} =
               invoice.status_transitions
    end

    test "parses status_transitions as nil when missing" do
      invoice = Invoice.from_map(invoice_json(%{"status_transitions" => nil}))
      assert invoice.status_transitions == nil
    end

    test "parses automatic_tax nested struct" do
      invoice =
        Invoice.from_map(
          invoice_json(%{
            "automatic_tax" => %{
              "enabled" => true,
              "status" => "complete",
              "liability" => %{"type" => "self"}
            }
          })
        )

      assert %AutomaticTax{enabled: true, status: "complete"} = invoice.automatic_tax
    end

    test "parses lines as List struct when present" do
      invoice =
        Invoice.from_map(
          invoice_json(%{
            "lines" => %{
              "object" => "list",
              "data" => [
                %{
                  "id" => "il_test123",
                  "object" => "line_item",
                  "amount" => 2000,
                  "currency" => "usd"
                }
              ],
              "has_more" => false,
              "url" => "/v1/invoices/in_test1234567890/lines"
            }
          })
        )

      assert %List{data: [%LineItem{id: "il_test123"}]} = invoice.lines
    end

    test "parses lines as nil when missing" do
      invoice = Invoice.from_map(invoice_json(%{"lines" => nil}))
      assert invoice.lines == nil
    end

    test "captures unknown fields in extra map" do
      invoice = Invoice.from_map(invoice_json(%{"unknown_field" => "value", "future_key" => 42}))
      assert invoice.extra["unknown_field"] == "value"
      assert invoice.extra["future_key"] == 42
    end

    test "known fields do not appear in extra" do
      invoice = Invoice.from_map(invoice_json())
      refute Map.has_key?(invoice.extra, "id")
      refute Map.has_key?(invoice.extra, "status")
    end

    test "defaults object to invoice" do
      invoice = Invoice.from_map(%{"id" => "in_abc"})
      assert invoice.object == "invoice"
    end
  end

  # ---------------------------------------------------------------------------
  # create/3
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "sends POST /v1/invoices and returns {:ok, %Invoice{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/invoices")
        ok_response(invoice_json())
      end)

      assert {:ok, %Invoice{id: "in_test1234567890"}} =
               Invoice.create(client, %{"customer" => "cus_test123"})
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{type: :invalid_request_error}} = Invoice.create(client, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/invoices/:id and returns {:ok, %Invoice{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/invoices/in_test1234567890")
        ok_response(invoice_json())
      end)

      assert {:ok, %Invoice{id: "in_test1234567890"}} =
               Invoice.retrieve(client, "in_test1234567890")
    end

    test "returns {:error, %Error{}} when invoice not found" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Invoice.retrieve(client, "in_missing")
    end
  end

  # ---------------------------------------------------------------------------
  # update/4
  # ---------------------------------------------------------------------------

  describe "update/4" do
    test "sends POST /v1/invoices/:id and returns {:ok, %Invoice{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/invoices/in_test1234567890")
        assert req.body =~ "auto_advance=true"
        ok_response(invoice_json(%{"auto_advance" => true}))
      end)

      assert {:ok, %Invoice{id: "in_test1234567890", auto_advance: true}} =
               Invoice.update(client, "in_test1234567890", %{"auto_advance" => true})
    end
  end

  # ---------------------------------------------------------------------------
  # delete/3
  # ---------------------------------------------------------------------------

  describe "delete/3" do
    test "sends DELETE /v1/invoices/:id and returns {:ok, %Invoice{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :delete
        assert String.ends_with?(req.url, "/v1/invoices/in_test1234567890")
        ok_response(%{"id" => "in_test1234567890", "object" => "invoice", "deleted" => true})
      end)

      assert {:ok, %Invoice{id: "in_test1234567890"}} =
               Invoice.delete(client, "in_test1234567890")
    end
  end

  # ---------------------------------------------------------------------------
  # list/3
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "sends GET /v1/invoices and returns {:ok, %Response{data: %List{}}} with typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/invoices")
        ok_response(list_json([invoice_json()], "/v1/invoices"))
      end)

      assert {:ok, %Response{data: %List{data: [%Invoice{id: "in_test1234567890"}]}}} =
               Invoice.list(client)
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Invoice.list(client)
    end
  end

  # ---------------------------------------------------------------------------
  # create!/3 (bang)
  # ---------------------------------------------------------------------------

  describe "create!/3" do
    test "returns %Invoice{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(invoice_json())
      end)

      assert %Invoice{id: "in_test1234567890"} = Invoice.create!(client, %{})
    end

    test "raises %Error{} on failure" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Invoice.create!(client, %{})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # finalize/4
  # ---------------------------------------------------------------------------

  describe "finalize/4" do
    test "sends POST /v1/invoices/:id/finalize and returns {:ok, %Invoice{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/invoices/in_test1234567890/finalize")
        ok_response(invoice_json(%{"status" => "open"}))
      end)

      assert {:ok, %Invoice{status: :open}} =
               Invoice.finalize(client, "in_test1234567890")
    end

    test "accepts optional params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/invoices/in_test1234567890/finalize")
        assert req.body =~ "auto_advance=false"
        ok_response(invoice_json(%{"status" => "open"}))
      end)

      assert {:ok, %Invoice{}} =
               Invoice.finalize(client, "in_test1234567890", %{"auto_advance" => false})
    end
  end

  describe "finalize!/4" do
    test "returns %Invoice{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(invoice_json(%{"status" => "open"}))
      end)

      assert %Invoice{status: :open} = Invoice.finalize!(client, "in_test1234567890")
    end

    test "raises %Error{} on failure" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Invoice.finalize!(client, "in_test1234567890")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # void/4
  # ---------------------------------------------------------------------------

  describe "void/4" do
    test "sends POST /v1/invoices/:id/void and returns {:ok, %Invoice{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/invoices/in_test1234567890/void")
        ok_response(invoice_json(%{"status" => "void"}))
      end)

      assert {:ok, %Invoice{status: :void}} =
               Invoice.void(client, "in_test1234567890")
    end
  end

  describe "void!/4" do
    test "returns %Invoice{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(invoice_json(%{"status" => "void"}))
      end)

      assert %Invoice{status: :void} = Invoice.void!(client, "in_test1234567890")
    end
  end

  # ---------------------------------------------------------------------------
  # pay/4
  # ---------------------------------------------------------------------------

  describe "pay/4" do
    test "sends POST /v1/invoices/:id/pay and returns {:ok, %Invoice{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/invoices/in_test1234567890/pay")
        ok_response(invoice_json(%{"status" => "paid"}))
      end)

      assert {:ok, %Invoice{status: :paid}} =
               Invoice.pay(client, "in_test1234567890")
    end

    test "accepts paid_out_of_band param" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/invoices/in_test1234567890/pay")
        assert req.body =~ "paid_out_of_band=true"
        ok_response(invoice_json(%{"status" => "paid"}))
      end)

      assert {:ok, %Invoice{}} =
               Invoice.pay(client, "in_test1234567890", %{"paid_out_of_band" => true})
    end
  end

  describe "pay!/4" do
    test "returns %Invoice{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(invoice_json(%{"status" => "paid"}))
      end)

      assert %Invoice{status: :paid} = Invoice.pay!(client, "in_test1234567890")
    end
  end

  # ---------------------------------------------------------------------------
  # send_invoice/4
  # ---------------------------------------------------------------------------

  describe "send_invoice/4" do
    test "sends POST /v1/invoices/:id/send and returns {:ok, %Invoice{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/invoices/in_test1234567890/send")
        ok_response(invoice_json(%{"status" => "open"}))
      end)

      assert {:ok, %Invoice{status: :open}} =
               Invoice.send_invoice(client, "in_test1234567890")
    end
  end

  describe "send_invoice!/4" do
    test "returns %Invoice{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(invoice_json(%{"status" => "open"}))
      end)

      assert %Invoice{} = Invoice.send_invoice!(client, "in_test1234567890")
    end
  end

  # ---------------------------------------------------------------------------
  # mark_uncollectible/4
  # ---------------------------------------------------------------------------

  describe "mark_uncollectible/4" do
    test "sends POST /v1/invoices/:id/mark_uncollectible and returns {:ok, %Invoice{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/invoices/in_test1234567890/mark_uncollectible")
        ok_response(invoice_json(%{"status" => "uncollectible"}))
      end)

      assert {:ok, %Invoice{status: :uncollectible}} =
               Invoice.mark_uncollectible(client, "in_test1234567890")
    end
  end

  describe "mark_uncollectible!/4" do
    test "returns %Invoice{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(invoice_json(%{"status" => "uncollectible"}))
      end)

      assert %Invoice{status: :uncollectible} =
               Invoice.mark_uncollectible!(client, "in_test1234567890")
    end
  end

  # ---------------------------------------------------------------------------
  # search/3
  # ---------------------------------------------------------------------------

  describe "search/3" do
    test "sends GET /v1/invoices/search with query param" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/invoices/search"
        assert req.url =~ "query="
        ok_response(list_json([invoice_json()], "/v1/invoices/search"))
      end)

      assert {:ok, %Response{data: %List{data: [%Invoice{}]}}} =
               Invoice.search(client, %{"query" => "status:'open'"})
    end

    test "returns {:error, %Error{}} on failure" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Invoice.search(client, %{"query" => "status:'open'"})
    end
  end

  # ---------------------------------------------------------------------------
  # Inspect
  # ---------------------------------------------------------------------------

  describe "Inspect" do
    test "inspect output contains id and status" do
      invoice = Invoice.from_map(invoice_json())
      inspected = inspect(invoice)
      assert inspected =~ "in_test1234567890"
    end

    test "inspect hides extra when empty" do
      invoice = Invoice.from_map(invoice_json())
      inspected = inspect(invoice)
      refute inspected =~ "extra:"
    end

    test "inspect shows extra when non-empty" do
      invoice = Invoice.from_map(invoice_json(%{"unknown_key" => "val"}))
      inspected = inspect(invoice)
      assert inspected =~ "extra:"
    end
  end
end
