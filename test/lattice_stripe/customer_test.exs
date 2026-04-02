defmodule LatticeStripe.CustomerTest do
  use ExUnit.Case, async: true

  import Mox

  alias LatticeStripe.{Client, Customer, Error, List, Response}

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

  defp customer_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "cus_test123",
        "object" => "customer",
        "email" => "test@example.com",
        "name" => "Test User",
        "livemode" => false,
        "created" => 1_700_000_000,
        "metadata" => %{},
        "deleted" => false
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
       status: 404,
       headers: [{"request-id", "req_err"}],
       body:
         Jason.encode!(%{
           "error" => %{
             "type" => "invalid_request_error",
             "message" => "not found"
           }
         })
     }}
  end

  defp list_json(items) do
    %{
      "object" => "list",
      "data" => items,
      "has_more" => false,
      "url" => "/v1/customers"
    }
  end

  # ---------------------------------------------------------------------------
  # create/3
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "sends POST /v1/customers and returns {:ok, %Customer{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/customers")
        assert req.body =~ "email=test%40example.com"
        ok_response(customer_json())
      end)

      assert {:ok, %Customer{id: "cus_test123", email: "test@example.com"}} =
               Customer.create(client, %{"email" => "test@example.com"})
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{type: :invalid_request_error}} = Customer.create(client, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/customers/:id and returns {:ok, %Customer{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/customers/cus_test123")
        ok_response(customer_json())
      end)

      assert {:ok, %Customer{id: "cus_test123"}} = Customer.retrieve(client, "cus_test123")
    end

    test "returns {:error, %Error{}} when customer not found" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Customer.retrieve(client, "cus_missing")
    end
  end

  # ---------------------------------------------------------------------------
  # update/4
  # ---------------------------------------------------------------------------

  describe "update/4" do
    test "sends POST /v1/customers/:id and returns {:ok, %Customer{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/customers/cus_test123")
        assert req.body =~ "name=New+Name"
        ok_response(customer_json(%{"name" => "New Name"}))
      end)

      assert {:ok, %Customer{id: "cus_test123", name: "New Name"}} =
               Customer.update(client, "cus_test123", %{"name" => "New Name"})
    end
  end

  # ---------------------------------------------------------------------------
  # delete/3
  # ---------------------------------------------------------------------------

  describe "delete/3" do
    test "sends DELETE /v1/customers/:id and returns {:ok, %Customer{deleted: true}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :delete
        assert String.ends_with?(req.url, "/v1/customers/cus_test123")
        ok_response(%{"id" => "cus_test123", "object" => "customer", "deleted" => true})
      end)

      assert {:ok, %Customer{id: "cus_test123", deleted: true}} =
               Customer.delete(client, "cus_test123")
    end
  end

  # ---------------------------------------------------------------------------
  # list/3
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "sends GET /v1/customers and returns {:ok, %Response{data: %List{}}} with typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/customers")
        ok_response(list_json([customer_json()]))
      end)

      assert {:ok, %Response{data: %List{data: [%Customer{id: "cus_test123"}]}}} =
               Customer.list(client)
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = Customer.list(client)
    end
  end

  # ---------------------------------------------------------------------------
  # search/3
  # ---------------------------------------------------------------------------

  describe "search/3" do
    test "sends GET /v1/customers/search with query param and returns typed items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/customers/search"
        assert req.url =~ "query="

        ok_response(%{
          "object" => "search_result",
          "data" => [customer_json()],
          "has_more" => false,
          "url" => "/v1/customers/search"
        })
      end)

      assert {:ok, %Response{data: %List{data: [%Customer{id: "cus_test123"}]}}} =
               Customer.search(client, "email:'test@example.com'")
    end
  end

  # ---------------------------------------------------------------------------
  # create!/3 (bang)
  # ---------------------------------------------------------------------------

  describe "create!/3" do
    test "returns %Customer{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(customer_json())
      end)

      assert %Customer{id: "cus_test123"} = Customer.create!(client, %{})
    end

    test "raises %Error{} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        Customer.create!(client, %{})
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
        ok_response(list_json([customer_json()]))
      end)

      assert %Response{data: %List{data: [%Customer{}]}} = Customer.list!(client)
    end
  end

  # ---------------------------------------------------------------------------
  # from_map/1
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "maps known fields to struct fields" do
      map = customer_json(%{"phone" => "+1-555-1234", "description" => "VIP customer"})
      customer = Customer.from_map(map)

      assert customer.id == "cus_test123"
      assert customer.email == "test@example.com"
      assert customer.name == "Test User"
      assert customer.phone == "+1-555-1234"
      assert customer.description == "VIP customer"
      assert customer.livemode == false
    end

    test "unknown fields go to extra map" do
      map = customer_json(%{"unknown_field" => "some_value", "another_unknown" => 42})
      customer = Customer.from_map(map)

      assert customer.extra == %{"unknown_field" => "some_value", "another_unknown" => 42}
    end

    test "defaults object to 'customer'" do
      customer = Customer.from_map(%{"id" => "cus_abc"})
      assert customer.object == "customer"
    end

    test "defaults deleted to false" do
      customer = Customer.from_map(%{"id" => "cus_abc"})
      assert customer.deleted == false
    end

    test "defaults extra to empty map" do
      customer = Customer.from_map(%{"id" => "cus_abc"})
      assert customer.extra == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # Inspect
  # ---------------------------------------------------------------------------

  describe "Inspect" do
    test "inspect output contains id and object" do
      customer = Customer.from_map(customer_json())
      inspected = inspect(customer)
      assert inspected =~ "cus_test123"
      assert inspected =~ "customer"
    end

    test "inspect output does NOT contain email" do
      customer = Customer.from_map(customer_json())
      inspected = inspect(customer)
      refute inspected =~ "test@example.com"
    end

    test "inspect output does NOT contain name" do
      customer = Customer.from_map(customer_json())
      inspected = inspect(customer)
      refute inspected =~ "Test User"
    end

    test "inspect shows livemode and deleted" do
      customer = Customer.from_map(customer_json())
      inspected = inspect(customer)
      assert inspected =~ "livemode"
      assert inspected =~ "deleted"
    end
  end
end
