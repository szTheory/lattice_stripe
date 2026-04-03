defmodule LatticeStripe.SetupIntentTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.SetupIntent

  alias LatticeStripe.{Error, List, Response, SetupIntent}

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # create/3
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "sends POST /v1/setup_intents and returns {:ok, %SetupIntent{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/setup_intents")
        ok_response(setup_intent_json())
      end)

      assert {:ok, %SetupIntent{id: "seti_test1234567890abc"}} = SetupIntent.create(client, %{})
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{type: :invalid_request_error}} = SetupIntent.create(client, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # create!/3
  # ---------------------------------------------------------------------------

  describe "create!/3" do
    test "returns %SetupIntent{} directly on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(setup_intent_json())
      end)

      assert %SetupIntent{id: "seti_test1234567890abc"} = SetupIntent.create!(client, %{})
    end

    test "raises %Error{} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        SetupIntent.create!(client, %{})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/setup_intents/:id and returns {:ok, %SetupIntent{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/setup_intents/seti_test1234567890abc")
        ok_response(setup_intent_json())
      end)

      assert {:ok, %SetupIntent{id: "seti_test1234567890abc"}} =
               SetupIntent.retrieve(client, "seti_test1234567890abc")
    end

    test "returns {:error, %Error{}} when not found" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = SetupIntent.retrieve(client, "seti_missing")
    end
  end

  # ---------------------------------------------------------------------------
  # update/4
  # ---------------------------------------------------------------------------

  describe "update/4" do
    test "sends POST /v1/setup_intents/:id and returns {:ok, %SetupIntent{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/setup_intents/seti_test1234567890abc")
        ok_response(setup_intent_json(%{"metadata" => %{"order_id" => "ord_123"}}))
      end)

      assert {:ok, %SetupIntent{id: "seti_test1234567890abc", metadata: %{"order_id" => "ord_123"}}} =
               SetupIntent.update(client, "seti_test1234567890abc", %{
                 "metadata" => %{"order_id" => "ord_123"}
               })
    end
  end

  # ---------------------------------------------------------------------------
  # confirm/4
  # ---------------------------------------------------------------------------

  describe "confirm/4" do
    test "sends POST /v1/setup_intents/:id/confirm and returns {:ok, %SetupIntent{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/setup_intents/seti_test1234567890abc/confirm")
        ok_response(setup_intent_json(%{"status" => "succeeded"}))
      end)

      assert {:ok, %SetupIntent{id: "seti_test1234567890abc", status: "succeeded"}} =
               SetupIntent.confirm(client, "seti_test1234567890abc", %{
                 "payment_method" => "pm_card_visa"
               })
    end

    test "sends POST with empty params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/setup_intents/seti_test1234567890abc/confirm")
        ok_response(setup_intent_json(%{"status" => "succeeded"}))
      end)

      assert {:ok, %SetupIntent{status: "succeeded"}} =
               SetupIntent.confirm(client, "seti_test1234567890abc")
    end
  end

  # ---------------------------------------------------------------------------
  # cancel/4
  # ---------------------------------------------------------------------------

  describe "cancel/4" do
    test "sends POST /v1/setup_intents/:id/cancel and returns {:ok, %SetupIntent{status: 'canceled'}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/setup_intents/seti_test1234567890abc/cancel")
        ok_response(setup_intent_json(%{"status" => "canceled"}))
      end)

      assert {:ok, %SetupIntent{id: "seti_test1234567890abc", status: "canceled"}} =
               SetupIntent.cancel(client, "seti_test1234567890abc")
    end

    test "sends cancel with cancellation_reason param" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/setup_intents/seti_test1234567890abc/cancel")
        assert req.body =~ "cancellation_reason=abandoned"

        ok_response(
          setup_intent_json(%{
            "status" => "canceled",
            "cancellation_reason" => "abandoned"
          })
        )
      end)

      assert {:ok, %SetupIntent{status: "canceled", cancellation_reason: "abandoned"}} =
               SetupIntent.cancel(client, "seti_test1234567890abc", %{
                 "cancellation_reason" => "abandoned"
               })
    end
  end

  # ---------------------------------------------------------------------------
  # verify_microdeposits/4
  # ---------------------------------------------------------------------------

  describe "verify_microdeposits/4" do
    test "sends POST /v1/setup_intents/:id/verify_microdeposits and returns {:ok, %SetupIntent{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/setup_intents/seti_test1234567890abc/verify_microdeposits")
        ok_response(setup_intent_json(%{"status" => "succeeded"}))
      end)

      assert {:ok, %SetupIntent{id: "seti_test1234567890abc", status: "succeeded"}} =
               SetupIntent.verify_microdeposits(client, "seti_test1234567890abc", %{"amounts" => [32, 45]})
    end
  end

  # ---------------------------------------------------------------------------
  # list/3
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "sends GET /v1/setup_intents and returns {:ok, %Response{data: %List{}}} with typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/setup_intents")
        ok_response(list_json([setup_intent_json()], "/v1/setup_intents"))
      end)

      assert {:ok, %Response{data: %List{data: [%SetupIntent{id: "seti_test1234567890abc"}]}}} =
               SetupIntent.list(client)
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = SetupIntent.list(client)
    end
  end

  # ---------------------------------------------------------------------------
  # list!/3 (bang)
  # ---------------------------------------------------------------------------

  describe "list!/3" do
    test "returns %Response{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([setup_intent_json()], "/v1/setup_intents"))
      end)

      assert %Response{data: %List{data: [%SetupIntent{}]}} = SetupIntent.list!(client)
    end
  end

  # ---------------------------------------------------------------------------
  # stream!/3
  # ---------------------------------------------------------------------------

  describe "stream!/3" do
    test "streams %SetupIntent{} structs with auto-pagination" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/setup_intents"

        ok_response(list_json([setup_intent_json()], "/v1/setup_intents"))
      end)

      results = SetupIntent.stream!(client) |> Enum.to_list()

      assert [%SetupIntent{id: "seti_test1234567890abc"}] = results
    end
  end

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "maps known fields to struct fields" do
      map =
        setup_intent_json(%{
          "customer" => "cus_abc",
          "payment_method_types" => ["card"],
          "description" => "Test setup"
        })

      si = SetupIntent.from_map(map)

      assert si.id == "seti_test1234567890abc"
      assert si.status == "requires_payment_method"
      assert si.usage == "off_session"
      assert si.client_secret == "seti_test1234567890abc_secret_abc"
      assert si.livemode == false
      assert si.customer == "cus_abc"
      assert si.payment_method_types == ["card"]
      assert si.description == "Test setup"
    end

    test "unknown fields go to extra map" do
      map = setup_intent_json(%{"unknown_field" => "some_value", "another_unknown" => 42})
      si = SetupIntent.from_map(map)

      assert si.extra == %{"unknown_field" => "some_value", "another_unknown" => 42}
    end

    test "defaults object to 'setup_intent'" do
      si = SetupIntent.from_map(%{"id" => "seti_abc"})
      assert si.object == "setup_intent"
    end

    test "defaults extra to empty map" do
      si = SetupIntent.from_map(%{"id" => "seti_abc"})
      assert si.extra == %{}
    end

    test "latest_attempt can be string or map" do
      si_with_string =
        SetupIntent.from_map(setup_intent_json(%{"latest_attempt" => "setatt_123"}))

      assert si_with_string.latest_attempt == "setatt_123"

      si_with_map =
        SetupIntent.from_map(setup_intent_json(%{"latest_attempt" => %{"id" => "setatt_123"}}))

      assert si_with_map.latest_attempt == %{"id" => "setatt_123"}
    end
  end

  # ---------------------------------------------------------------------------
  # Error handling
  # ---------------------------------------------------------------------------

  describe "error handling" do
    test "retrieve returns {:error, %Error{}} on API error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{type: :invalid_request_error}} =
               SetupIntent.retrieve(client, "seti_missing")
    end
  end

  # ---------------------------------------------------------------------------
  # Inspect
  # ---------------------------------------------------------------------------

  describe "Inspect" do
    test "inspect output contains id and status" do
      si = SetupIntent.from_map(setup_intent_json())
      inspected = inspect(si)
      assert inspected =~ "seti_test1234567890abc"
      assert inspected =~ "requires_payment_method"
    end

    test "inspect output contains usage" do
      si = SetupIntent.from_map(setup_intent_json())
      inspected = inspect(si)
      assert inspected =~ "off_session"
    end

    test "inspect output does NOT contain client_secret value" do
      si = SetupIntent.from_map(setup_intent_json())
      inspected = inspect(si)
      refute inspected =~ "seti_test1234567890abc_secret_abc"
    end

    test "inspect output does NOT contain client_secret key" do
      si = SetupIntent.from_map(setup_intent_json())
      inspected = inspect(si)
      refute inspected =~ "client_secret"
    end
  end
end
