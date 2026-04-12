defmodule LatticeStripe.RefundTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestSupport
  import LatticeStripe.Test.Fixtures.Refund

  alias LatticeStripe.{Error, List, Refund, Response}

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # create/3
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "sends POST /v1/refunds with payment_intent param and returns {:ok, %Refund{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/refunds")
        assert req.body =~ "payment_intent=pi_test1234567890abc"
        ok_response(refund_json())
      end)

      assert {:ok, %Refund{id: "re_test1234567890abc", amount: 2000, currency: "usd"}} =
               Refund.create(client, %{"payment_intent" => "pi_test1234567890abc"})
    end

    test "sends POST /v1/refunds with amount for partial refund" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert req.body =~ "amount=500"
        ok_response(refund_partial_json())
      end)

      assert {:ok, %Refund{amount: 500}} =
               Refund.create(client, %{
                 "payment_intent" => "pi_test1234567890abc",
                 "amount" => 500
               })
    end

    test "raises ArgumentError when payment_intent param is missing" do
      client = test_client()

      assert_raise ArgumentError, ~r/payment_intent/, fn ->
        Refund.create(client, %{})
      end
    end

    test "raises ArgumentError when only amount is given (no payment_intent)" do
      client = test_client()

      assert_raise ArgumentError, ~r/payment_intent/, fn ->
        Refund.create(client, %{"amount" => 500})
      end
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{type: :invalid_request_error}} =
               Refund.create(client, %{"payment_intent" => "pi_test1234567890abc"})
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/refunds/:id and returns {:ok, %Refund{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/refunds/re_test1234567890abc")
        ok_response(refund_json())
      end)

      assert {:ok, %Refund{id: "re_test1234567890abc"}} =
               Refund.retrieve(client, "re_test1234567890abc")
    end

    test "returns {:error, %Error{}} when not found" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Refund.retrieve(client, "re_missing")
    end
  end

  # ---------------------------------------------------------------------------
  # update/4
  # ---------------------------------------------------------------------------

  describe "update/4" do
    test "sends POST /v1/refunds/:id with metadata and returns {:ok, %Refund{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/refunds/re_test1234567890abc")
        assert req.body =~ "metadata"
        ok_response(refund_json(%{"metadata" => %{"order_id" => "ord_123"}}))
      end)

      assert {:ok, %Refund{id: "re_test1234567890abc", metadata: %{"order_id" => "ord_123"}}} =
               Refund.update(client, "re_test1234567890abc", %{
                 "metadata" => %{"order_id" => "ord_123"}
               })
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} =
               Refund.update(client, "re_test1234567890abc", %{
                 "metadata" => %{"order_id" => "ord_123"}
               })
    end
  end

  # ---------------------------------------------------------------------------
  # cancel/4
  # ---------------------------------------------------------------------------

  describe "cancel/4" do
    test "sends POST /v1/refunds/:id/cancel and returns {:ok, %Refund{status: 'canceled'}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/refunds/re_test1234567890abc/cancel")
        ok_response(refund_pending_json(%{"status" => "canceled"}))
      end)

      assert {:ok, %Refund{id: "re_test1234567890abc", status: "canceled"}} =
               Refund.cancel(client, "re_test1234567890abc")
    end

    test "sends cancel with empty params (no required params)" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/refunds/re_test1234567890abc/cancel")
        ok_response(refund_json(%{"status" => "canceled"}))
      end)

      assert {:ok, %Refund{status: "canceled"}} =
               Refund.cancel(client, "re_test1234567890abc", %{})
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Refund.cancel(client, "re_test1234567890abc")
    end
  end

  # ---------------------------------------------------------------------------
  # list/3
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "sends GET /v1/refunds and returns {:ok, %Response{data: %List{}}} with typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/refunds")
        ok_response(list_json([refund_json()], "/v1/refunds"))
      end)

      assert {:ok, %Response{data: %List{data: [%Refund{id: "re_test1234567890abc"}]}}} =
               Refund.list(client)
    end

    test "list/3 with no params (all optional)" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/refunds")
        ok_response(list_json([refund_json()], "/v1/refunds"))
      end)

      assert {:ok, %Response{data: %List{data: [%Refund{}]}}} = Refund.list(client, %{})
    end

    test "list/3 with filters (payment_intent)" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "payment_intent=pi_test1234567890abc"
        ok_response(list_json([refund_json()], "/v1/refunds"))
      end)

      assert {:ok, %Response{data: %List{}}} =
               Refund.list(client, %{"payment_intent" => "pi_test1234567890abc"})
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Refund.list(client)
    end
  end

  # ---------------------------------------------------------------------------
  # stream!/3
  # ---------------------------------------------------------------------------

  describe "stream!/3" do
    test "streams %Refund{} structs with auto-pagination" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/refunds"
        ok_response(list_json([refund_json()], "/v1/refunds"))
      end)

      results = Refund.stream!(client) |> Enum.to_list()

      assert [%Refund{id: "re_test1234567890abc"}] = results
    end

    test "stream!/3 with params filters refunds" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "payment_intent=pi_test1234567890abc"
        ok_response(list_json([refund_json()], "/v1/refunds"))
      end)

      results =
        Refund.stream!(client, %{"payment_intent" => "pi_test1234567890abc"}) |> Enum.to_list()

      assert [%Refund{id: "re_test1234567890abc"}] = results
    end
  end

  # ---------------------------------------------------------------------------
  # Bang variants
  # ---------------------------------------------------------------------------

  describe "create!/3" do
    test "returns %Refund{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(refund_json())
      end)

      assert %Refund{id: "re_test1234567890abc"} =
               Refund.create!(client, %{"payment_intent" => "pi_test1234567890abc"})
    end

    test "raises %Error{} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Refund.create!(client, %{"payment_intent" => "pi_test1234567890abc"})
      end
    end

    test "raises ArgumentError when payment_intent is missing (pre-network)" do
      client = test_client()

      assert_raise ArgumentError, ~r/payment_intent/, fn ->
        Refund.create!(client, %{})
      end
    end
  end

  describe "retrieve!/3" do
    test "returns %Refund{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(refund_json())
      end)

      assert %Refund{id: "re_test1234567890abc"} =
               Refund.retrieve!(client, "re_test1234567890abc")
    end

    test "raises %Error{} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Refund.retrieve!(client, "re_missing")
      end
    end
  end

  describe "update!/4" do
    test "returns %Refund{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(refund_json())
      end)

      assert %Refund{} =
               Refund.update!(client, "re_test1234567890abc", %{"metadata" => %{}})
    end
  end

  describe "cancel!/4" do
    test "returns %Refund{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(refund_json(%{"status" => "canceled"}))
      end)

      assert %Refund{status: "canceled"} = Refund.cancel!(client, "re_test1234567890abc")
    end
  end

  describe "list!/3" do
    test "returns %Response{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([refund_json()], "/v1/refunds"))
      end)

      assert %Response{data: %List{data: [%Refund{}]}} = Refund.list!(client)
    end
  end

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "maps known fields to struct fields" do
      map = refund_json()
      refund = Refund.from_map(map)

      assert refund.id == "re_test1234567890abc"
      assert refund.object == "refund"
      assert refund.amount == 2000
      assert refund.currency == "usd"
      assert refund.status == "succeeded"
      assert refund.payment_intent == "pi_test1234567890abc"
      assert refund.charge == "ch_test1234567890abc"
      assert refund.reason == "requested_by_customer"
      assert refund.created == 1_700_000_000
      assert refund.metadata == %{}
    end

    test "unknown fields go to extra map" do
      map = refund_json(%{"unknown_field" => "some_value", "another_unknown" => 42})
      refund = Refund.from_map(map)

      assert refund.extra == %{"unknown_field" => "some_value", "another_unknown" => 42}
    end

    test "defaults object to 'refund'" do
      refund = Refund.from_map(%{"id" => "re_abc"})
      assert refund.object == "refund"
    end

    test "defaults extra to empty map" do
      refund = Refund.from_map(%{"id" => "re_abc"})
      assert refund.extra == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # Inspect
  # ---------------------------------------------------------------------------

  describe "Inspect" do
    test "inspect output contains id, object, amount, currency, status" do
      refund = Refund.from_map(refund_json())
      inspected = inspect(refund)

      assert inspected =~ "re_test1234567890abc"
      assert inspected =~ "refund"
      assert inspected =~ "2000"
      assert inspected =~ "usd"
      assert inspected =~ "succeeded"
    end

    test "inspect output does NOT contain payment_intent or charge" do
      refund = Refund.from_map(refund_json())
      inspected = inspect(refund)

      refute inspected =~ "pi_test1234567890abc"
      refute inspected =~ "ch_test1234567890abc"
    end

    test "inspect output does NOT contain reason or metadata" do
      refund = Refund.from_map(refund_json())
      inspected = inspect(refund)

      refute inspected =~ "requested_by_customer"
    end
  end
end
