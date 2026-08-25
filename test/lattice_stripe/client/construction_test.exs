defmodule LatticeStripe.Client.ConstructionTest do
  use LatticeStripe.ClientCase, async: true

  describe "new!/1 and new/1" do
    test "new!/1 with valid opts returns a %Client{} struct" do
      client = test_client()

      assert %Client{} = client
      assert client.api_key == "sk_test_123"
      assert client.finch == :test_finch
    end

    test "new!/1 without api_key raises NimbleOptions.ValidationError" do
      assert_raise NimbleOptions.ValidationError, ~r/api_key/, fn ->
        Client.new!(finch: MyApp.Finch)
      end
    end

    test "new!/1 without finch defaults to LatticeStripe.Finch without raising" do
      client =
        Client.new!(
          api_key: "sk_test_123",
          transport: LatticeStripe.MockTransport,
          telemetry_enabled: false
        )

      assert %Client{} = client
      assert client.finch == LatticeStripe.Finch
    end

    test "new/1 with valid opts returns {:ok, %Client{}}" do
      assert {:ok, %Client{} = client} =
               Client.new(api_key: "sk_test_abc", finch: MyApp.Finch)

      assert client.api_key == "sk_test_abc"
    end

    test "new/1 with invalid opts returns {:error, _}" do
      assert {:error, %NimbleOptions.ValidationError{}} = Client.new(finch: MyApp.Finch)
    end

    test "Client struct is a plain struct, not a GenServer" do
      client = test_client()

      # It is a struct
      assert is_struct(client, Client)

      # It is NOT a pid or process
      refute is_pid(client)

      # Its module does not implement GenServer behaviour
      behaviours =
        client.__struct__.module_info(:attributes)
        |> Keyword.get(:behaviour, [])

      refute GenServer in behaviours
    end

    test "multiple clients with different API keys can coexist" do
      client_a =
        Client.new!(
          api_key: "sk_test_aaa",
          finch: :finch_a,
          transport: LatticeStripe.MockTransport,
          telemetry_enabled: false
        )

      client_b =
        Client.new!(
          api_key: "sk_test_bbb",
          finch: :finch_b,
          transport: LatticeStripe.MockTransport,
          telemetry_enabled: false
        )

      assert client_a.api_key == "sk_test_aaa"
      assert client_b.api_key == "sk_test_bbb"
      assert client_a.api_key != client_b.api_key

      # Each client uses its own api_key in requests
      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert {"authorization", "Bearer sk_test_aaa"} in req_map.headers
        ok_response()
      end)

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert {"authorization", "Bearer sk_test_bbb"} in req_map.headers
        ok_response()
      end)

      assert {:ok, _} = Client.request(client_a, get_request())
      assert {:ok, _} = Client.request(client_b, get_request())
    end

    test "require_explicit_proration defaults to false" do
      client = Client.new!(api_key: "sk_test_123", finch: MyApp.Finch)
      assert client.require_explicit_proration == false
    end

    test "require_explicit_proration can be set to true" do
      client =
        Client.new!(
          api_key: "sk_test_123",
          finch: MyApp.Finch,
          require_explicit_proration: true
        )

      assert client.require_explicit_proration == true
    end
  end

  describe "transport swapping" do
    test "custom transport via Mox mock works" do
      # Explicitly verify MockTransport is used and responds correctly
      client =
        Client.new!(
          api_key: "sk_test_swap",
          finch: :swap_finch,
          transport: LatticeStripe.MockTransport,
          telemetry_enabled: false
        )

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        # Verify the request came through the mock
        assert req_map.method == :get
        assert String.contains?(req_map.url, "/v1/customers")
        assert {"authorization", "Bearer sk_test_swap"} in req_map.headers

        {:ok,
         %{
           status: 200,
           headers: [],
           body: Jason.encode!(%{"object" => "list", "data" => []})
         }}
      end)

      req = %Request{method: :get, path: "/v1/customers", params: %{}, opts: []}

      assert {:ok, %Response{data: %LatticeStripe.List{object: "list"}}} =
               Client.request(client, req)
    end
  end
end
