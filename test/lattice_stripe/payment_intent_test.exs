defmodule LatticeStripe.PaymentIntentTest do
  use ExUnit.Case, async: true

  import Mox

  alias LatticeStripe.{Client, Error, List, PaymentIntent, Request, Response}

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # Test helpers
  # ---------------------------------------------------------------------------

  defp test_client do
    Client.new!(
      api_key: "sk_test_123",
      finch: :test_finch,
      transport: LatticeStripe.MockTransport,
      telemetry_enabled: false,
      max_retries: 0
    )
  end

  defp payment_intent_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "pi_test123",
        "object" => "payment_intent",
        "amount" => 2000,
        "currency" => "usd",
        "status" => "requires_payment_method",
        "client_secret" => "pi_test123_secret_abc",
        "livemode" => false,
        "created" => 1_700_000_000,
        "metadata" => %{}
      },
      overrides
    )
  end

  defp ok_response(body) do
    {:ok,
     %{
       status: 200,
       headers: [{"request-id", "req_test"}],
       body: Jason.encode!(body)
     }}
  end

  defp error_response do
    {:ok,
     %{
       status: 400,
       headers: [{"request-id", "req_err"}],
       body:
         Jason.encode!(%{
           "error" => %{
             "type" => "invalid_request_error",
             "message" => "amount is required"
           }
         })
     }}
  end

  defp list_json(items) do
    %{
      "object" => "list",
      "data" => items,
      "has_more" => false,
      "url" => "/v1/payment_intents"
    }
  end

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

      assert {:ok, %PaymentIntent{id: "pi_test123", amount: 2000, currency: "usd"}} =
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
        assert String.ends_with?(req.url, "/v1/payment_intents/pi_test123")
        ok_response(payment_intent_json())
      end)

      assert {:ok, %PaymentIntent{id: "pi_test123"}} =
               PaymentIntent.retrieve(client, "pi_test123")
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
        assert String.ends_with?(req.url, "/v1/payment_intents/pi_test123")
        assert req.body =~ "metadata"
        ok_response(payment_intent_json(%{"metadata" => %{"order_id" => "ord_123"}}))
      end)

      assert {:ok, %PaymentIntent{id: "pi_test123", metadata: %{"order_id" => "ord_123"}}} =
               PaymentIntent.update(client, "pi_test123", %{
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
        assert String.ends_with?(req.url, "/v1/payment_intents/pi_test123/confirm")
        ok_response(payment_intent_json(%{"status" => "requires_capture"}))
      end)

      assert {:ok, %PaymentIntent{id: "pi_test123", status: "requires_capture"}} =
               PaymentIntent.confirm(client, "pi_test123", %{
                 "payment_method" => "pm_card_visa"
               })
    end

    test "sends POST /v1/payment_intents/:id/confirm with empty params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payment_intents/pi_test123/confirm")
        ok_response(payment_intent_json(%{"status" => "succeeded"}))
      end)

      assert {:ok, %PaymentIntent{status: "succeeded"}} =
               PaymentIntent.confirm(client, "pi_test123")
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
        assert String.ends_with?(req.url, "/v1/payment_intents/pi_test123/capture")
        ok_response(payment_intent_json(%{"status" => "succeeded"}))
      end)

      assert {:ok, %PaymentIntent{id: "pi_test123", status: "succeeded"}} =
               PaymentIntent.capture(client, "pi_test123")
    end

    test "sends capture with amount_to_capture param" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payment_intents/pi_test123/capture")
        assert req.body =~ "amount_to_capture=1500"
        ok_response(payment_intent_json(%{"status" => "succeeded", "amount_received" => 1500}))
      end)

      assert {:ok, %PaymentIntent{status: "succeeded", amount_received: 1500}} =
               PaymentIntent.capture(client, "pi_test123", %{"amount_to_capture" => 1500})
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
        assert String.ends_with?(req.url, "/v1/payment_intents/pi_test123/cancel")
        ok_response(payment_intent_json(%{"status" => "canceled"}))
      end)

      assert {:ok, %PaymentIntent{id: "pi_test123", status: "canceled"}} =
               PaymentIntent.cancel(client, "pi_test123")
    end

    test "sends cancel with cancellation_reason param" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payment_intents/pi_test123/cancel")
        assert req.body =~ "cancellation_reason=abandoned"
        ok_response(
          payment_intent_json(%{
            "status" => "canceled",
            "cancellation_reason" => "abandoned"
          })
        )
      end)

      assert {:ok, %PaymentIntent{status: "canceled", cancellation_reason: "abandoned"}} =
               PaymentIntent.cancel(client, "pi_test123", %{
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
        ok_response(list_json([payment_intent_json()]))
      end)

      assert {:ok, %Response{data: %List{data: [%PaymentIntent{id: "pi_test123"}]}}} =
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

      assert %PaymentIntent{id: "pi_test123"} =
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
        ok_response(list_json([payment_intent_json()]))
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

      assert pi.id == "pi_test123"
      assert pi.amount == 2000
      assert pi.currency == "usd"
      assert pi.status == "requires_payment_method"
      assert pi.client_secret == "pi_test123_secret_abc"
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
  # Inspect
  # ---------------------------------------------------------------------------

  describe "Inspect" do
    test "inspect output contains id and amount" do
      pi = PaymentIntent.from_map(payment_intent_json())
      inspected = inspect(pi)
      assert inspected =~ "pi_test123"
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
      refute inspected =~ "pi_test123_secret_abc"
      refute inspected =~ "client_secret"
    end
  end
end
