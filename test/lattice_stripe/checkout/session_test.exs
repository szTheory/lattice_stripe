defmodule LatticeStripe.Checkout.SessionTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestSupport
  import LatticeStripe.Test.Fixtures.Checkout.Session
  import LatticeStripe.Test.Fixtures.Checkout.LineItem

  alias LatticeStripe.Checkout.{LineItem, Session}
  alias LatticeStripe.{Error, List, Response}

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # create/3
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "sends POST /v1/checkout/sessions in payment mode and returns {:ok, %Session{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/checkout/sessions")
        assert req.body =~ "mode=payment"
        ok_response(checkout_session_payment_json())
      end)

      assert {:ok, %Session{id: "cs_test1234567890abc", mode: "payment", status: "open"}} =
               Session.create(client, %{
                 "mode" => "payment",
                 "success_url" => "https://example.com/success",
                 "cancel_url" => "https://example.com/cancel",
                 "line_items" => [%{"price" => "price_test123", "quantity" => 1}]
               })
    end

    test "sends POST /v1/checkout/sessions in subscription mode" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert req.body =~ "mode=subscription"
        ok_response(checkout_session_subscription_json())
      end)

      assert {:ok, %Session{mode: "subscription", subscription: "sub_test123"}} =
               Session.create(client, %{
                 "mode" => "subscription",
                 "success_url" => "https://example.com/success",
                 "line_items" => [%{"price" => "price_monthly", "quantity" => 1}]
               })
    end

    test "sends POST /v1/checkout/sessions in setup mode" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert req.body =~ "mode=setup"
        ok_response(checkout_session_setup_json())
      end)

      assert {:ok,
              %Session{
                mode: "setup",
                setup_intent: "seti_test123",
                payment_status: "no_payment_required"
              }} =
               Session.create(client, %{
                 "mode" => "setup",
                 "success_url" => "https://example.com/success"
               })
    end

    test "raises ArgumentError when mode param is missing" do
      client = test_client()

      assert_raise ArgumentError, ~r/mode/, fn ->
        Session.create(client, %{
          "success_url" => "https://example.com/success",
          "line_items" => [%{"price" => "price_test123", "quantity" => 1}]
        })
      end
    end

    test "raises ArgumentError when params is empty" do
      client = test_client()

      assert_raise ArgumentError, ~r/mode/, fn ->
        Session.create(client, %{})
      end
    end

    test "passes line_items, success_url, and cancel_url in request body" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.body =~ "success_url"
        assert req.body =~ "cancel_url"
        ok_response(checkout_session_payment_json())
      end)

      assert {:ok, %Session{}} =
               Session.create(client, %{
                 "mode" => "payment",
                 "success_url" => "https://example.com/success",
                 "cancel_url" => "https://example.com/cancel",
                 "line_items" => [%{"price" => "price_test123", "quantity" => 1}]
               })
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{type: :invalid_request_error}} =
               Session.create(client, %{"mode" => "payment"})
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/checkout/sessions/:id and returns {:ok, %Session{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/checkout/sessions/cs_test1234567890abc")
        ok_response(checkout_session_payment_json())
      end)

      assert {:ok, %Session{id: "cs_test1234567890abc"}} =
               Session.retrieve(client, "cs_test1234567890abc")
    end

    test "returns {:error, %Error{}} when not found" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Session.retrieve(client, "cs_missing")
    end
  end

  # ---------------------------------------------------------------------------
  # list/3
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "sends GET /v1/checkout/sessions and returns {:ok, %Response{data: %List{}}} with typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/checkout/sessions")
        ok_response(list_json([checkout_session_payment_json()], "/v1/checkout/sessions"))
      end)

      assert {:ok,
              %Response{
                data: %List{data: [%Session{id: "cs_test1234567890abc"}]}
              }} = Session.list(client)
    end

    test "list/3 with no params (all optional)" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        ok_response(list_json([checkout_session_payment_json()], "/v1/checkout/sessions"))
      end)

      assert {:ok, %Response{data: %List{data: [%Session{}]}}} = Session.list(client, %{})
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Session.list(client)
    end
  end

  # ---------------------------------------------------------------------------
  # expire/4
  # ---------------------------------------------------------------------------

  describe "expire/4" do
    test "sends POST /v1/checkout/sessions/:id/expire and returns {:ok, %Session{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/checkout/sessions/cs_test1234567890abc/expire")
        ok_response(checkout_session_expired_json())
      end)

      assert {:ok, %Session{id: "cs_test1234567890abc", status: "expired"}} =
               Session.expire(client, "cs_test1234567890abc")
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Session.expire(client, "cs_test1234567890abc")
    end
  end

  # ---------------------------------------------------------------------------
  # search/3
  # ---------------------------------------------------------------------------

  describe "search/3" do
    test "sends GET /v1/checkout/sessions/search with query and returns {:ok, %Response{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/checkout/sessions/search"
        assert req.url =~ "query="
        ok_response(list_json([checkout_session_payment_json()], "/v1/checkout/sessions/search"))
      end)

      assert {:ok, %Response{data: %List{data: [%Session{}]}}} =
               Session.search(client, "status:'open'")
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Session.search(client, "status:'open'")
    end
  end

  # ---------------------------------------------------------------------------
  # stream!/3
  # ---------------------------------------------------------------------------

  describe "stream!/3" do
    test "returns a Stream of %Session{} structs with auto-pagination" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/checkout/sessions"
        ok_response(list_json([checkout_session_payment_json()], "/v1/checkout/sessions"))
      end)

      results = Session.stream!(client) |> Enum.to_list()

      assert [%Session{id: "cs_test1234567890abc"}] = results
    end

    test "stream!/3 with params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "limit=10"
        ok_response(list_json([checkout_session_payment_json()], "/v1/checkout/sessions"))
      end)

      results = Session.stream!(client, %{"limit" => "10"}) |> Enum.to_list()

      assert [%Session{}] = results
    end
  end

  # ---------------------------------------------------------------------------
  # search_stream!/3
  # ---------------------------------------------------------------------------

  describe "search_stream!/3" do
    test "returns a Stream of %Session{} structs from search" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "/v1/checkout/sessions/search"
        ok_response(list_json([checkout_session_payment_json()], "/v1/checkout/sessions/search"))
      end)

      results = Session.search_stream!(client, "status:'open'") |> Enum.to_list()

      assert [%Session{id: "cs_test1234567890abc"}] = results
    end
  end

  # ---------------------------------------------------------------------------
  # list_line_items/4
  # ---------------------------------------------------------------------------

  describe "list_line_items/4" do
    test "sends GET /v1/checkout/sessions/:id/line_items and returns {:ok, %Response{data: %List{data: [%LineItem{}]}}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/checkout/sessions/cs_test1234567890abc/line_items")

        ok_response(
          list_json([line_item_json()], "/v1/checkout/sessions/cs_test1234567890abc/line_items")
        )
      end)

      assert {:ok,
              %Response{
                data: %List{data: [%LineItem{id: "li_test1234567890abc", description: "T-Shirt"}]}
              }} = Session.list_line_items(client, "cs_test1234567890abc")
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Session.list_line_items(client, "cs_test1234567890abc")
    end
  end

  # ---------------------------------------------------------------------------
  # stream_line_items!/4
  # ---------------------------------------------------------------------------

  describe "stream_line_items!/4" do
    test "returns a Stream of %LineItem{} structs" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "/v1/checkout/sessions/cs_test1234567890abc/line_items"

        ok_response(
          list_json([line_item_json()], "/v1/checkout/sessions/cs_test1234567890abc/line_items")
        )
      end)

      results = Session.stream_line_items!(client, "cs_test1234567890abc") |> Enum.to_list()

      assert [%LineItem{id: "li_test1234567890abc", description: "T-Shirt"}] = results
    end
  end

  # ---------------------------------------------------------------------------
  # Bang variants
  # ---------------------------------------------------------------------------

  describe "create!/3" do
    test "returns %Session{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(checkout_session_payment_json())
      end)

      assert %Session{id: "cs_test1234567890abc"} =
               Session.create!(client, %{"mode" => "payment"})
    end

    test "raises %Error{} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Session.create!(client, %{"mode" => "payment"})
      end
    end

    test "raises ArgumentError when mode is missing (pre-network)" do
      client = test_client()

      assert_raise ArgumentError, ~r/mode/, fn ->
        Session.create!(client, %{})
      end
    end
  end

  describe "retrieve!/3" do
    test "returns %Session{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(checkout_session_payment_json())
      end)

      assert %Session{id: "cs_test1234567890abc"} =
               Session.retrieve!(client, "cs_test1234567890abc")
    end

    test "raises %Error{} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Session.retrieve!(client, "cs_missing")
      end
    end
  end

  describe "list!/3" do
    test "returns %Response{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([checkout_session_payment_json()], "/v1/checkout/sessions"))
      end)

      assert %Response{data: %List{data: [%Session{}]}} = Session.list!(client)
    end
  end

  describe "expire!/4" do
    test "returns %Session{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(checkout_session_expired_json())
      end)

      assert %Session{status: "expired"} = Session.expire!(client, "cs_test1234567890abc")
    end
  end

  describe "search!/3" do
    test "returns %Response{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([checkout_session_payment_json()], "/v1/checkout/sessions/search"))
      end)

      assert %Response{data: %List{data: [%Session{}]}} = Session.search!(client, "status:'open'")
    end
  end

  describe "list_line_items!/4" do
    test "returns %Response{} with LineItem structs on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(
          list_json([line_item_json()], "/v1/checkout/sessions/cs_test1234567890abc/line_items")
        )
      end)

      assert %Response{data: %List{data: [%LineItem{}]}} =
               Session.list_line_items!(client, "cs_test1234567890abc")
    end
  end

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "maps known fields to struct fields" do
      map = checkout_session_payment_json()
      session = Session.from_map(map)

      assert session.id == "cs_test1234567890abc"
      assert session.object == "checkout.session"
      assert session.mode == "payment"
      assert session.status == "open"
      assert session.payment_status == "unpaid"
      assert session.amount_total == 2000
      assert session.currency == "usd"
      assert session.success_url == "https://example.com/success"
      assert session.cancel_url == "https://example.com/cancel"
      assert session.payment_intent == "pi_test1234567890abc"
      assert session.livemode == false
      assert session.metadata == %{}
    end

    test "unknown fields go to extra map" do
      map =
        checkout_session_payment_json(%{
          "unknown_field" => "some_value",
          "another_unknown" => 42
        })

      session = Session.from_map(map)

      assert session.extra == %{"unknown_field" => "some_value", "another_unknown" => 42}
    end

    test "defaults object to 'checkout.session'" do
      session = Session.from_map(%{"id" => "cs_abc"})
      assert session.object == "checkout.session"
    end

    test "defaults extra to empty map" do
      session = Session.from_map(%{"id" => "cs_abc"})
      assert session.extra == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # Inspect
  # ---------------------------------------------------------------------------

  describe "Inspect" do
    test "inspect output contains id, object, mode, status, payment_status, amount_total, currency" do
      session = Session.from_map(checkout_session_payment_json())
      inspected = inspect(session)

      assert inspected =~ "cs_test1234567890abc"
      assert inspected =~ "checkout.session"
      assert inspected =~ "payment"
      assert inspected =~ "open"
      assert inspected =~ "unpaid"
      assert inspected =~ "2000"
      assert inspected =~ "usd"
    end

    test "inspect output does NOT contain client_secret" do
      session =
        Session.from_map(checkout_session_payment_json(%{"client_secret" => "cs_secret_123"}))

      inspected = inspect(session)

      refute inspected =~ "cs_secret_123"
      refute inspected =~ "client_secret"
    end

    test "inspect output does NOT contain customer_email (PII)" do
      session =
        Session.from_map(checkout_session_payment_json(%{"customer_email" => "user@example.com"}))

      inspected = inspect(session)

      refute inspected =~ "user@example.com"
      refute inspected =~ "customer_email"
    end

    test "inspect output does NOT contain customer_details (PII)" do
      session =
        Session.from_map(
          checkout_session_payment_json(%{"customer_details" => %{"email" => "user@example.com"}})
        )

      inspected = inspect(session)

      refute inspected =~ "customer_details"
    end

    test "inspect output does NOT contain shipping_details (PII)" do
      session =
        Session.from_map(
          checkout_session_payment_json(%{
            "shipping_details" => %{"address" => %{"line1" => "123 Main St"}}
          })
        )

      inspected = inspect(session)

      refute inspected =~ "shipping_details"
    end
  end

  # ---------------------------------------------------------------------------
  # LineItem.from_map/1
  # ---------------------------------------------------------------------------

  describe "LineItem.from_map/1" do
    test "maps known fields to struct fields" do
      map = line_item_json()
      item = LineItem.from_map(map)

      assert item.id == "li_test1234567890abc"
      assert item.object == "item"
      assert item.amount_discount == 0
      assert item.amount_subtotal == 2000
      assert item.amount_tax == 0
      assert item.amount_total == 2000
      assert item.currency == "usd"
      assert item.description == "T-Shirt"
      assert item.quantity == 1
      assert is_map(item.price)
    end

    test "unknown fields go to extra map" do
      map = line_item_json(%{"unknown_field" => "some_value"})
      item = LineItem.from_map(map)

      assert item.extra == %{"unknown_field" => "some_value"}
    end

    test "defaults object to 'item'" do
      item = LineItem.from_map(%{"id" => "li_abc"})
      assert item.object == "item"
    end
  end

  # ---------------------------------------------------------------------------
  # LineItem Inspect
  # ---------------------------------------------------------------------------

  describe "LineItem Inspect" do
    test "inspect output contains id, object, description, quantity, amount_total" do
      item = LineItem.from_map(line_item_json())
      inspected = inspect(item)

      assert inspected =~ "li_test1234567890abc"
      assert inspected =~ "item"
      assert inspected =~ "T-Shirt"
      assert inspected =~ "1"
      assert inspected =~ "2000"
    end
  end
end
