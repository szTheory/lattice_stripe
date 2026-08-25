defmodule LatticeStripe.QuoteTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Testing.Fixtures.Quote

  alias LatticeStripe.{
    Customer,
    Error,
    Invoice,
    List,
    Quote,
    Response,
    Subscription,
    SubscriptionSchedule
  }

  alias LatticeStripe.Quote.{Computed, LineItem, StatusTransitions}

  setup :verify_on_exit!

  describe "create/3" do
    test "sends POST /v1/quotes and forwards nested line item params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/quotes")
        assert req.body =~ "customer=cus_123"
        assert req.body =~ "line_items[0][quantity]=1"
        ok_response(quote_json())
      end)

      assert {:ok, %Quote{id: "qt_test1234567890abc"}} =
               Quote.create(client, %{
                 "customer" => "cus_123",
                 "line_items" => [%{"quantity" => 1}]
               })
    end
  end

  describe "retrieve/3" do
    test "sends GET /v1/quotes/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/quotes/qt_test1234567890abc")
        ok_response(quote_json())
      end)

      assert {:ok, %Quote{id: "qt_test1234567890abc"}} =
               Quote.retrieve(client, "qt_test1234567890abc")
    end
  end

  describe "update/4" do
    test "sends POST /v1/quotes/:id" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/quotes/qt_test1234567890abc")
        assert req.body =~ "header=Updated+proposal"
        ok_response(quote_json(%{"header" => "Updated proposal"}))
      end)

      assert {:ok, %Quote{header: "Updated proposal"}} =
               Quote.update(client, "qt_test1234567890abc", %{"header" => "Updated proposal"})
    end
  end

  describe "list/3" do
    test "sends GET /v1/quotes and returns typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/quotes")
        ok_response(list_json([quote_json()], "/v1/quotes"))
      end)

      assert {:ok, %Response{data: %List{data: [%Quote{id: "qt_test1234567890abc"}]}}} =
               Quote.list(client)
    end
  end

  describe "stream!/3" do
    test "streams typed quotes" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/quotes"
        ok_response(list_json([quote_json()], "/v1/quotes"))
      end)

      assert [%Quote{id: "qt_test1234567890abc"}] = Quote.stream!(client) |> Enum.to_list()
    end
  end

  describe "finalize/4" do
    test "sends POST /v1/quotes/:id/finalize with raw params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/quotes/qt_test1234567890abc/finalize")
        assert req.body =~ "expires_at=1700086400"
        ok_response(open_quote_json())
      end)

      assert {:ok, %Quote{status: :open}} =
               Quote.finalize(client, "qt_test1234567890abc", %{"expires_at" => 1_700_086_400})
    end
  end

  describe "accept/3" do
    test "sends POST /v1/quotes/:id/accept with empty params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/quotes/qt_test1234567890abc/accept")
        assert req.body in [nil, ""]
        ok_response(accepted_quote_json())
      end)

      assert {:ok, %Quote{status: :accepted}} =
               Quote.accept(client, "qt_test1234567890abc")
    end
  end

  describe "cancel/3" do
    test "sends POST /v1/quotes/:id/cancel with empty params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/quotes/qt_test1234567890abc/cancel")
        assert req.body in [nil, ""]
        ok_response(canceled_quote_json())
      end)

      assert {:ok, %Quote{status: :canceled}} =
               Quote.cancel(client, "qt_test1234567890abc")
    end
  end

  describe "list_line_items/4" do
    test "hits /v1/quotes/:id/line_items and returns typed line items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/quotes/qt_test1234567890abc/line_items"

        ok_response(
          list_json([quote_line_item_json()], "/v1/quotes/qt_test1234567890abc/line_items")
        )
      end)

      assert {:ok, %Response{data: %List{data: [%LineItem{id: "qli_test1234567890abc"}]}}} =
               Quote.list_line_items(client, "qt_test1234567890abc")
    end
  end

  describe "stream_line_items!/4" do
    test "streams typed quote line items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/quotes/qt_test1234567890abc/line_items"

        ok_response(
          list_json([quote_line_item_json()], "/v1/quotes/qt_test1234567890abc/line_items")
        )
      end)

      assert [%LineItem{id: "qli_test1234567890abc"}] =
               Quote.stream_line_items!(client, "qt_test1234567890abc") |> Enum.to_list()
    end
  end

  describe "list_computed_upfront_line_items/4" do
    test "hits /v1/quotes/:id/computed_upfront_line_items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/quotes/qt_test1234567890abc/computed_upfront_line_items"

        ok_response(
          list_json(
            [quote_computed_upfront_line_item_json()],
            "/v1/quotes/qt_test1234567890abc/computed_upfront_line_items"
          )
        )
      end)

      assert {:ok, %Response{data: %List{data: [%LineItem{id: "qli_upfront1234567890abc"}]}}} =
               Quote.list_computed_upfront_line_items(client, "qt_test1234567890abc")
    end
  end

  describe "stream_computed_upfront_line_items!/4" do
    test "streams typed computed upfront line items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/quotes/qt_test1234567890abc/computed_upfront_line_items"

        ok_response(
          list_json(
            [quote_computed_upfront_line_item_json()],
            "/v1/quotes/qt_test1234567890abc/computed_upfront_line_items"
          )
        )
      end)

      assert [%LineItem{id: "qli_upfront1234567890abc"}] =
               Quote.stream_computed_upfront_line_items!(client, "qt_test1234567890abc")
               |> Enum.to_list()
    end
  end

  describe "pdf/3" do
    test "returns raw binary from Client.download/3" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/quotes/qt_test1234567890abc/pdf")

        {:ok,
         %{
           status: 200,
           headers: [{"content-type", "application/pdf"}, {"request-id", "req_dl"}],
           body: "pdf-binary-data"
         }}
      end)

      assert {:ok, "pdf-binary-data"} = Quote.pdf(client, "qt_test1234567890abc")
    end

    test "pdf!/3 raises on error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert_raise Error, fn -> Quote.pdf!(client, "qt_test1234567890abc") end
    end
  end

  describe "from_map/1" do
    test "returns nil for nil" do
      assert Quote.from_map(nil) == nil
    end

    test "atomizes known status values" do
      assert Quote.from_map(quote_json(%{"status" => "draft"})).status == :draft
      assert Quote.from_map(open_quote_json()).status == :open
      assert Quote.from_map(accepted_quote_json()).status == :accepted
      assert Quote.from_map(canceled_quote_json()).status == :canceled
    end

    test "passes through unknown status as string" do
      assert Quote.from_map(quote_json(%{"status" => "future_status"})).status == "future_status"
    end

    test "atomizes collection method" do
      assert Quote.from_map(quote_json(%{"collection_method" => "charge_automatically"})).collection_method ==
               :charge_automatically

      assert Quote.from_map(quote_json(%{"collection_method" => "send_invoice"})).collection_method ==
               :send_invoice
    end

    test "deserializes expanded downstream references" do
      quote = Quote.from_map(expanded_quote_json())

      assert %Customer{} = quote.customer
      assert %Invoice{} = quote.invoice
      assert %Subscription{} = quote.subscription
      assert %SubscriptionSchedule{} = quote.subscription_schedule
    end

    test "types embedded line item payloads and computed branches" do
      quote = Quote.from_map(quote_json())

      assert %List{data: [%LineItem{}]} = quote.line_items
      assert %Computed{} = quote.computed
      assert %List{data: [%LineItem{}]} = quote.computed.upfront["line_items"]
      assert [%LineItem{}] = quote.computed.recurring["line_items"]
    end

    test "types status transitions" do
      assert %StatusTransitions{finalized_at: nil} =
               Quote.from_map(quote_json()).status_transitions
    end

    test "preserves unknown fields in extra" do
      quote = Quote.from_map(quote_json(%{"future_field" => "present"}))
      assert quote.extra["future_field"] == "present"
    end
  end
end
