defmodule LatticeStripe.PaymentMethodTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.{Error, List, PaymentMethod, Response}

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # Test helpers
  # ---------------------------------------------------------------------------

  defp payment_method_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "pm_test123",
        "object" => "payment_method",
        "type" => "card",
        "customer" => "cus_test456",
        "livemode" => false,
        "created" => 1_700_000_000,
        "metadata" => %{},
        "card" => %{
          "brand" => "visa",
          "last4" => "4242",
          "exp_month" => 12,
          "exp_year" => 2030,
          "fingerprint" => "abc123"
        },
        "billing_details" => %{
          "email" => "test@example.com",
          "name" => "Test User"
        }
      },
      overrides
    )
  end

  # ---------------------------------------------------------------------------
  # create/3
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "sends POST /v1/payment_methods and returns {:ok, %PaymentMethod{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payment_methods")
        ok_response(payment_method_json())
      end)

      assert {:ok, %PaymentMethod{id: "pm_test123", type: "card"}} =
               PaymentMethod.create(client, %{"type" => "card"})
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{type: :invalid_request_error}} = PaymentMethod.create(client, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # create!/3
  # ---------------------------------------------------------------------------

  describe "create!/3" do
    test "returns %PaymentMethod{} directly on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(payment_method_json())
      end)

      assert %PaymentMethod{id: "pm_test123"} = PaymentMethod.create!(client, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/payment_methods/:id and returns {:ok, %PaymentMethod{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/payment_methods/pm_test123")
        ok_response(payment_method_json())
      end)

      assert {:ok, %PaymentMethod{id: "pm_test123"}} =
               PaymentMethod.retrieve(client, "pm_test123")
    end

    test "returns {:error, %Error{}} when not found" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = PaymentMethod.retrieve(client, "pm_missing")
    end
  end

  # ---------------------------------------------------------------------------
  # update/4
  # ---------------------------------------------------------------------------

  describe "update/4" do
    test "sends POST /v1/payment_methods/:id and returns {:ok, %PaymentMethod{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payment_methods/pm_test123")
        ok_response(payment_method_json(%{"metadata" => %{"order_id" => "ord_123"}}))
      end)

      assert {:ok, %PaymentMethod{id: "pm_test123", metadata: %{"order_id" => "ord_123"}}} =
               PaymentMethod.update(client, "pm_test123", %{
                 "metadata" => %{"order_id" => "ord_123"}
               })
    end
  end

  # ---------------------------------------------------------------------------
  # attach/4
  # ---------------------------------------------------------------------------

  describe "attach/4" do
    test "sends POST /v1/payment_methods/:id/attach and returns {:ok, %PaymentMethod{customer: ...}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payment_methods/pm_test123/attach")
        assert req.body =~ "customer=cus_test456"
        ok_response(payment_method_json(%{"customer" => "cus_test456"}))
      end)

      assert {:ok, %PaymentMethod{customer: "cus_test456"}} =
               PaymentMethod.attach(client, "pm_test123", %{"customer" => "cus_test456"})
    end

    test "returns {:ok, %PaymentMethod{}} on success (bang via attach!/4)" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(payment_method_json())
      end)

      assert %PaymentMethod{id: "pm_test123"} =
               PaymentMethod.attach!(client, "pm_test123", %{"customer" => "cus_test456"})
    end
  end

  # ---------------------------------------------------------------------------
  # detach/4
  # ---------------------------------------------------------------------------

  describe "detach/4" do
    test "sends POST /v1/payment_methods/:id/detach and returns {:ok, %PaymentMethod{customer: nil}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/payment_methods/pm_test123/detach")
        ok_response(payment_method_json(%{"customer" => nil}))
      end)

      assert {:ok, %PaymentMethod{customer: nil}} =
               PaymentMethod.detach(client, "pm_test123")
    end

    test "returns %PaymentMethod{} directly via detach!/4" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(payment_method_json(%{"customer" => nil}))
      end)

      assert %PaymentMethod{customer: nil} = PaymentMethod.detach!(client, "pm_test123")
    end
  end

  # ---------------------------------------------------------------------------
  # list/3 with validation
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "sends GET /v1/payment_methods and returns {:ok, %Response{data: %List{}}} with typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/payment_methods"
        ok_response(list_json([payment_method_json()], "/v1/payment_methods"))
      end)

      assert {:ok, %Response{data: %List{data: [%PaymentMethod{id: "pm_test123"}]}}} =
               PaymentMethod.list(client, %{"customer" => "cus_test456"})
    end

    test "raises ArgumentError when customer param is missing" do
      client = test_client()

      assert_raise ArgumentError, ~r/requires a "customer" key/, fn ->
        PaymentMethod.list(client, %{})
      end
    end

    test "raises ArgumentError when only type param is given (no customer)" do
      client = test_client()

      assert_raise ArgumentError, ~r/requires a "customer" key/, fn ->
        PaymentMethod.list(client, %{"type" => "card"})
      end
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = PaymentMethod.list(client, %{"customer" => "cus_test456"})
    end
  end

  # ---------------------------------------------------------------------------
  # list!/3 (bang)
  # ---------------------------------------------------------------------------

  describe "list!/3" do
    test "returns %Response{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([payment_method_json()], "/v1/payment_methods"))
      end)

      assert %Response{data: %List{data: [%PaymentMethod{}]}} =
               PaymentMethod.list!(client, %{"customer" => "cus_test456"})
    end
  end

  # ---------------------------------------------------------------------------
  # stream!/3 with validation
  # ---------------------------------------------------------------------------

  describe "stream!/3" do
    test "streams %PaymentMethod{} structs with auto-pagination" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/payment_methods"
        ok_response(list_json([payment_method_json()], "/v1/payment_methods"))
      end)

      results = PaymentMethod.stream!(client, %{"customer" => "cus_test456"}) |> Enum.to_list()

      assert [%PaymentMethod{id: "pm_test123"}] = results
    end

    test "raises ArgumentError when customer param is missing" do
      client = test_client()

      assert_raise ArgumentError, ~r/requires a "customer" key/, fn ->
        PaymentMethod.stream!(client, %{}) |> Enum.to_list()
      end
    end
  end

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "maps known fields to struct fields" do
      map = payment_method_json()
      pm = PaymentMethod.from_map(map)

      assert pm.id == "pm_test123"
      assert pm.object == "payment_method"
      assert pm.type == "card"
      assert pm.customer == "cus_test456"
      assert pm.livemode == false
      assert pm.created == 1_700_000_000
      assert pm.metadata == %{}
    end

    test "card nested object preserved as map" do
      map = payment_method_json()
      pm = PaymentMethod.from_map(map)

      assert pm.card == %{
               "brand" => "visa",
               "last4" => "4242",
               "exp_month" => 12,
               "exp_year" => 2030,
               "fingerprint" => "abc123"
             }
    end

    test "type-specific fields not matching type are nil" do
      map = payment_method_json()
      pm = PaymentMethod.from_map(map)

      assert is_nil(pm.us_bank_account)
      assert is_nil(pm.sepa_debit)
      assert is_nil(pm.paypal)
    end

    test "unknown fields go to extra map" do
      map = payment_method_json(%{"unknown_field" => "some_value", "another_unknown" => 42})
      pm = PaymentMethod.from_map(map)

      assert pm.extra == %{"unknown_field" => "some_value", "another_unknown" => 42}
    end

    test "defaults object to 'payment_method'" do
      pm = PaymentMethod.from_map(%{"id" => "pm_abc"})
      assert pm.object == "payment_method"
    end

    test "defaults extra to empty map when no unknown fields" do
      pm = PaymentMethod.from_map(%{"id" => "pm_abc"})
      assert pm.extra == %{}
    end

    test "from_map with non-card type has nil card and correct type-specific field" do
      map =
        payment_method_json(%{
          "type" => "sepa_debit",
          "card" => nil,
          "sepa_debit" => %{"last4" => "3000", "bank_code" => "37040044"}
        })

      pm = PaymentMethod.from_map(map)

      assert pm.type == "sepa_debit"
      assert is_nil(pm.card)
      assert pm.sepa_debit == %{"last4" => "3000", "bank_code" => "37040044"}
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
               PaymentMethod.retrieve(client, "pm_missing")
    end
  end

  # ---------------------------------------------------------------------------
  # Inspect
  # ---------------------------------------------------------------------------

  describe "Inspect" do
    test "card type shows id, type, card_brand, card_last4 but hides billing_details and fingerprint" do
      pm = PaymentMethod.from_map(payment_method_json())
      inspected = inspect(pm)

      assert inspected =~ "pm_test123"
      assert inspected =~ ~s|type: "card"|
      assert inspected =~ ~s|card_brand: "visa"|
      assert inspected =~ ~s|card_last4: "4242"|
      refute inspected =~ "billing_details"
      refute inspected =~ "fingerprint"
      refute inspected =~ "exp_month"
      refute inspected =~ "exp_year"
    end

    test "non-card type shows id and type but does NOT show card_brand or card_last4" do
      pm = PaymentMethod.from_map(payment_method_json(%{"type" => "sepa_debit", "card" => nil}))
      inspected = inspect(pm)

      assert inspected =~ "pm_test123"
      assert inspected =~ ~s|type: "sepa_debit"|
      refute inspected =~ "card_brand"
      refute inspected =~ "card_last4"
    end
  end
end
