defmodule LatticeStripe.PaymentIntentTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.PaymentIntent

  alias LatticeStripe.{Error, List, PaymentIntent, Response}

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # create/3
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "sends POST /v1/payment_intents and returns {:ok, %PaymentIntent{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payment_intents")
        assert req.body =~ "amount=2000"
        assert req.body =~ "currency=usd"
        ok_response(payment_intent_json())
      end)

      assert {:ok, %PaymentIntent{id: "pi_test1234567890abc", amount: 2000, currency: "usd"}} =
               PaymentIntent.create(client, %{"amount" => 2000, "currency" => "usd"})
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{type: :invalid_request_error}} = PaymentIntent.create(client, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/payment_intents/:id and returns {:ok, %PaymentIntent{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/payment_intents/pi_test1234567890abc")
        ok_response(payment_intent_json())
      end)

      assert {:ok, %PaymentIntent{id: "pi_test1234567890abc"}} =
               PaymentIntent.retrieve(client, "pi_test1234567890abc")
    end

    test "returns {:error, %Error{}} when not found" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = PaymentIntent.retrieve(client, "pi_missing")
    end
  end

  # ---------------------------------------------------------------------------
  # update/4
  # ---------------------------------------------------------------------------

  describe "update/4" do
    test "sends POST /v1/payment_intents/:id and returns {:ok, %PaymentIntent{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payment_intents/pi_test1234567890abc")
        assert req.body =~ "metadata"
        ok_response(payment_intent_json(%{"metadata" => %{"order_id" => "ord_123"}}))
      end)

      assert {:ok, %PaymentIntent{id: "pi_test1234567890abc", metadata: %{"order_id" => "ord_123"}}} =
               PaymentIntent.update(client, "pi_test1234567890abc", %{
                 "metadata" => %{"order_id" => "ord_123"}
               })
    end
  end

  # ---------------------------------------------------------------------------
  # confirm/4
  # ---------------------------------------------------------------------------

  describe "confirm/4" do
    test "sends POST /v1/payment_intents/:id/confirm and returns {:ok, %PaymentIntent{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payment_intents/pi_test1234567890abc/confirm")
        ok_response(payment_intent_json(%{"status" => "requires_capture"}))
      end)

      assert {:ok, %PaymentIntent{id: "pi_test1234567890abc", status: "requires_capture"}} =
               PaymentIntent.confirm(client, "pi_test1234567890abc", %{
                 "payment_method" => "pm_card_visa"
               })
    end

    test "sends POST /v1/payment_intents/:id/confirm with empty params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payment_intents/pi_test1234567890abc/confirm")
        ok_response(payment_intent_json(%{"status" => "succeeded"}))
      end)

      assert {:ok, %PaymentIntent{status: "succeeded"}} =
               PaymentIntent.confirm(client, "pi_test1234567890abc")
    end
  end

  # ---------------------------------------------------------------------------
  # capture/4
  # ---------------------------------------------------------------------------

  describe "capture/4" do
    test "sends POST /v1/payment_intents/:id/capture and returns {:ok, %PaymentIntent{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payment_intents/pi_test1234567890abc/capture")
        ok_response(payment_intent_json(%{"status" => "succeeded"}))
      end)

      assert {:ok, %PaymentIntent{id: "pi_test1234567890abc", status: "succeeded"}} =
               PaymentIntent.capture(client, "pi_test1234567890abc")
    end

    test "sends capture with amount_to_capture param" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payment_intents/pi_test1234567890abc/capture")
        assert req.body =~ "amount_to_capture=1500"
        ok_response(payment_intent_json(%{"status" => "succeeded", "amount_received" => 1500}))
      end)

      assert {:ok, %PaymentIntent{status: "succeeded", amount_received: 1500}} =
               PaymentIntent.capture(client, "pi_test1234567890abc", %{"amount_to_capture" => 1500})
    end
  end

  # ---------------------------------------------------------------------------
  # cancel/4
  # ---------------------------------------------------------------------------

  describe "cancel/4" do
    test "sends POST /v1/payment_intents/:id/cancel and returns {:ok, %PaymentIntent{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payment_intents/pi_test1234567890abc/cancel")
        ok_response(payment_intent_json(%{"status" => "canceled"}))
      end)

      assert {:ok, %PaymentIntent{id: "pi_test1234567890abc", status: "canceled"}} =
               PaymentIntent.cancel(client, "pi_test1234567890abc")
    end

    test "sends cancel with cancellation_reason param" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payment_intents/pi_test1234567890abc/cancel")
        assert req.body =~ "cancellation_reason=abandoned"

        ok_response(
          payment_intent_json(%{
            "status" => "canceled",
            "cancellation_reason" => "abandoned"
          })
        )
      end)

      assert {:ok, %PaymentIntent{status: "canceled", cancellation_reason: "abandoned"}} =
               PaymentIntent.cancel(client, "pi_test1234567890abc", %{
                 "cancellation_reason" => "abandoned"
               })
    end
  end

  # ---------------------------------------------------------------------------
  # list/3
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "sends GET /v1/payment_intents and returns {:ok, %Response{data: %List{}}} with typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/payment_intents")
        ok_response(list_json([payment_intent_json()], "/v1/payment_intents"))
      end)

      assert {:ok, %Response{data: %List{data: [%PaymentIntent{id: "pi_test1234567890abc"}]}}} =
               PaymentIntent.list(client)
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = PaymentIntent.list(client)
    end
  end

  # ---------------------------------------------------------------------------
  # create!/3 (bang)
  # ---------------------------------------------------------------------------

  describe "create!/3" do
    test "returns %PaymentIntent{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(payment_intent_json())
      end)

      assert %PaymentIntent{id: "pi_test1234567890abc"} =
               PaymentIntent.create!(client, %{"amount" => 2000, "currency" => "usd"})
    end

    test "raises %Error{} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        PaymentIntent.create!(client, %{})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # list!/3 (bang)
  # ---------------------------------------------------------------------------

  describe "list!/3" do
    test "returns %Response{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([payment_intent_json()], "/v1/payment_intents"))
      end)

      assert %Response{data: %List{data: [%PaymentIntent{}]}} = PaymentIntent.list!(client)
    end
  end

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "maps known fields to struct fields" do
      map =
        payment_intent_json(%{
          "capture_method" => "manual",
          "confirmation_method" => "automatic"
        })

      pi = PaymentIntent.from_map(map)

      assert pi.id == "pi_test1234567890abc"
      assert pi.amount == 2000
      assert pi.currency == "usd"
      assert pi.status == "requires_payment_method"
      assert pi.client_secret == "pi_test1234567890abc_secret_abc"
      assert pi.capture_method == "manual"
      assert pi.confirmation_method == "automatic"
    end

    test "unknown fields go to extra map" do
      map =
        payment_intent_json(%{
          "unknown_stripe_field" => "some_value",
          "another_unknown" => 42
        })

      pi = PaymentIntent.from_map(map)

      assert pi.extra == %{"unknown_stripe_field" => "some_value", "another_unknown" => 42}
    end

    test "defaults object to 'payment_intent'" do
      pi = PaymentIntent.from_map(%{"id" => "pi_abc"})
      assert pi.object == "payment_intent"
    end

    test "defaults extra to empty map" do
      pi = PaymentIntent.from_map(%{"id" => "pi_abc"})
      assert pi.extra == %{}
    end

    test "preserves status field" do
      pi = PaymentIntent.from_map(payment_intent_json(%{"status" => "succeeded"}))
      assert pi.status == "succeeded"
    end
  end

  # ---------------------------------------------------------------------------
  # search/3
  # ---------------------------------------------------------------------------

  describe "search/3" do
    test "sends GET /v1/payment_intents/search with query param and returns typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/payment_intents/search"
        assert req.url =~ "query="

        ok_response(%{
          "object" => "search_result",
          "data" => [payment_intent_json()],
          "has_more" => false,
          "url" => "/v1/payment_intents/search"
        })
      end)

      assert {:ok, %Response{data: %List{data: [%PaymentIntent{id: "pi_test1234567890abc"}]}}} =
               PaymentIntent.search(client, "status:'succeeded'")
    end
  end

  # ---------------------------------------------------------------------------
  # search!/3
  # ---------------------------------------------------------------------------

  describe "search!/3" do
    test "returns %Response{} directly on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(%{
          "object" => "search_result",
          "data" => [payment_intent_json()],
          "has_more" => false,
          "url" => "/v1/payment_intents/search"
        })
      end)

      assert %Response{data: %List{data: [%PaymentIntent{}]}} =
               PaymentIntent.search!(client, "status:'succeeded'")
    end
  end

  # ---------------------------------------------------------------------------
  # search_stream!/3
  # ---------------------------------------------------------------------------

  describe "search_stream!/3" do
    test "streams %PaymentIntent{} structs from search results" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "/v1/payment_intents/search"

        ok_response(%{
          "object" => "search_result",
          "data" => [payment_intent_json()],
          "has_more" => false,
          "url" => "/v1/payment_intents/search"
        })
      end)

      results = PaymentIntent.search_stream!(client, "status:'succeeded'") |> Enum.to_list()

      assert [%PaymentIntent{id: "pi_test1234567890abc"}] = results
    end
  end

  # ---------------------------------------------------------------------------
  # Inspect
  # ---------------------------------------------------------------------------

  describe "Inspect" do
    test "inspect output contains id and amount" do
      pi = PaymentIntent.from_map(payment_intent_json())
      inspected = inspect(pi)
      assert inspected =~ "pi_test1234567890abc"
      assert inspected =~ "2000"
    end

    test "inspect output contains currency and status" do
      pi = PaymentIntent.from_map(payment_intent_json())
      inspected = inspect(pi)
      assert inspected =~ "usd"
      assert inspected =~ "requires_payment_method"
    end

    test "inspect output does NOT contain client_secret" do
      pi = PaymentIntent.from_map(payment_intent_json())
      inspected = inspect(pi)
      refute inspected =~ "pi_test1234567890abc_secret_abc"
      refute inspected =~ "client_secret"
    end
  end
end
