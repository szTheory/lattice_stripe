defmodule LatticeStripe.Client.RequestBuildingTest do
  use LatticeStripe.ClientCase, async: true

  describe "request/2 headers" do
    # Test 8: request/2 sends GET with Authorization Bearer header
    test "sends Authorization Bearer header" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert {"authorization", "Bearer sk_test_123"} in req_map.headers
        ok_response()
      end)

      assert {:ok, _} = Client.request(client, get_request())
    end

    # Test 9: request/2 sends Stripe-Version header from client config
    test "sends Stripe-Version header from client config" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert {"stripe-version", LatticeStripe.api_version()} in req_map.headers
        ok_response()
      end)

      assert {:ok, _} = Client.request(client, get_request())
    end

    # Test 10: request/2 sends User-Agent header containing "LatticeStripe"
    test "sends User-Agent header containing LatticeStripe" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        user_agent = req_map.headers |> Enum.find(fn {k, _} -> k == "user-agent" end)
        assert user_agent != nil
        {_, ua_value} = user_agent
        assert String.starts_with?(ua_value, "LatticeStripe/")
        assert String.contains?(ua_value, "elixir/")
        ok_response()
      end)

      assert {:ok, _} = Client.request(client, get_request())
    end

    # Test 11: request/2 POST sends Content-Type application/x-www-form-urlencoded
    test "POST sends Content-Type application/x-www-form-urlencoded" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert {"content-type", "application/x-www-form-urlencoded"} in req_map.headers
        ok_response()
      end)

      assert {:ok, _} = Client.request(client, post_request())
    end
  end

  describe "request/2 encoding" do
    # Test 12: request/2 POST encodes params as form body via FormEncoder
    test "POST encodes params as form body" do
      client = test_client()
      params = %{amount: 1000, currency: "usd"}

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert req_map.method == :post
        assert req_map.body != nil
        assert req_map.body != ""
        assert String.contains?(req_map.body, "amount=1000")
        assert String.contains?(req_map.body, "currency=usd")
        ok_response()
      end)

      assert {:ok, _} = Client.request(client, post_request("/v1/charges", params))
    end

    # Test 13: request/2 GET appends params as query string
    test "GET appends params as query string" do
      client = test_client()
      params = %{limit: 10}

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert req_map.method == :get
        assert req_map.body == nil
        assert String.contains?(req_map.url, "limit=10")
        ok_response()
      end)

      req = %Request{method: :get, path: "/v1/customers", params: params, opts: []}
      assert {:ok, _} = Client.request(client, req)
    end
  end

  describe "request/2 per-request overrides" do
    # Test 19: Per-request api_key overrides client api_key
    test "per-request api_key overrides client api_key" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert {"authorization", "Bearer sk_test_override"} in req_map.headers
        ok_response()
      end)

      req = get_request("/v1/customers", api_key: "sk_test_override")
      assert {:ok, _} = Client.request(client, req)
    end

    # Test 20: Per-request stripe_account adds Stripe-Account header
    test "per-request stripe_account adds Stripe-Account header" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert {"stripe-account", "acct_connect_123"} in req_map.headers
        ok_response()
      end)

      req = get_request("/v1/charges", stripe_account: "acct_connect_123")
      assert {:ok, _} = Client.request(client, req)
    end

    # Test 21: Per-request timeout overrides client timeout
    test "per-request timeout overrides client timeout" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert req_map.opts[:timeout] == 5_000
        ok_response()
      end)

      req = get_request("/v1/customers", timeout: 5_000)
      assert {:ok, _} = Client.request(client, req)
    end

    # Test 22: Per-request stripe_version overrides client api_version
    test "per-request stripe_version overrides client api_version" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert {"stripe-version", "2024-06-20"} in req_map.headers
        ok_response()
      end)

      req = get_request("/v1/customers", stripe_version: "2024-06-20")
      assert {:ok, _} = Client.request(client, req)
    end

    # Test 23: Per-request idempotency_key adds Idempotency-Key header (user key takes precedence)
    test "per-request idempotency_key overrides auto-generated key" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert {"idempotency-key", "unique-key-abc"} in req_map.headers
        ok_response()
      end)

      req = post_request("/v1/charges", %{}, idempotency_key: "unique-key-abc")
      assert {:ok, _} = Client.request(client, req)
    end

    # Test 24: Per-request expand merges into params
    test "per-request expand merges into request params" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert String.contains?(req_map.url, "expand")
        ok_response()
      end)

      req = %Request{
        method: :get,
        path: "/v1/payment_intents/pi_123",
        params: %{},
        opts: [expand: ["payment_method"]]
      }

      assert {:ok, _} = Client.request(client, req)
    end

    # Test 25: request_id extracted from response headers and included in error structs
    test "request_id from response header is included in error struct" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        {:ok,
         %{
           status: 401,
           headers: [{"request-id", "req_specific_789"}],
           body:
             Jason.encode!(%{
               "error" => %{"type" => "authentication_error", "message" => "Invalid key"}
             })
         }}
      end)

      assert {:error, %Error{request_id: "req_specific_789"}} =
               Client.request(client, get_request())
    end
  end

  describe "request/2 telemetry" do
    # Test 26: Telemetry events emitted when telemetry_enabled: true
    test "emits telemetry start and stop events" do
      client = test_client(telemetry_enabled: true)
      test_pid = self()
      handler_id = "test-telemetry-handler-#{:erlang.unique_integer([:positive])}"

      :telemetry.attach_many(
        handler_id,
        [[:lattice_stripe, :request, :start], [:lattice_stripe, :request, :stop]],
        fn event, _measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        ok_response()
      end)

      Client.request(client, get_request())

      assert_receive {:telemetry_event, [:lattice_stripe, :request, :start], _meta}
      assert_receive {:telemetry_event, [:lattice_stripe, :request, :stop], _meta}
    end

    # Test 27: No telemetry events when telemetry_enabled: false
    test "does NOT emit telemetry events when telemetry_enabled is false" do
      client = test_client(telemetry_enabled: false)
      test_pid = self()
      handler_id = "test-no-telemetry-handler-#{:erlang.unique_integer([:positive])}"

      :telemetry.attach_many(
        handler_id,
        [[:lattice_stripe, :request, :start], [:lattice_stripe, :request, :stop]],
        fn event, _measurements, metadata, _config ->
          if metadata[:path] == "/v1/customers/cus_123" do
            send(test_pid, {:telemetry_event, event, metadata})
          end
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        ok_response()
      end)

      Client.request(client, get_request())

      refute_receive {:telemetry_event, [:lattice_stripe, :request, :start], _}, 100
      refute_receive {:telemetry_event, [:lattice_stripe, :request, :stop], _}, 100
    end
  end

  describe "request/2 idempotency keys" do
    # Test 35: POST request gets auto-generated idempotency-key header
    test "POST request gets auto-generated idempotency-key header" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        idk_header = Enum.find(req_map.headers, fn {k, _} -> k == "idempotency-key" end)
        assert idk_header != nil
        {_, key} = idk_header
        # Matches idk_ltc_ prefix + UUID v4 format
        assert Regex.match?(
                 ~r/^idk_ltc_[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
                 key
               )

        ok_response()
      end)

      assert {:ok, _} = Client.request(client, post_request())
    end

    # Test 36: GET request does NOT get auto-generated idempotency-key header
    test "GET request does NOT get auto-generated idempotency-key header" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        refute Enum.any?(req_map.headers, fn {k, _} -> k == "idempotency-key" end)
        ok_response()
      end)

      assert {:ok, _} = Client.request(client, get_request())
    end

    # Test 37: DELETE request does NOT get auto-generated idempotency-key header
    test "DELETE request does NOT get auto-generated idempotency-key header" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        refute Enum.any?(req_map.headers, fn {k, _} -> k == "idempotency-key" end)
        ok_response()
      end)

      assert {:ok, _} = Client.request(client, delete_request())
    end

    # Test 38: User-provided idempotency_key in opts takes precedence
    test "user-provided idempotency_key takes precedence over auto-generated" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        # Should have exactly the user-provided key, not an auto-generated one
        idk_header = Enum.find(req_map.headers, fn {k, _} -> k == "idempotency-key" end)
        assert idk_header != nil
        {_, key} = idk_header
        assert key == "my-custom-key-xyz"
        ok_response()
      end)

      req = post_request("/v1/charges", %{}, idempotency_key: "my-custom-key-xyz")
      assert {:ok, _} = Client.request(client, req)
    end

    # Test 39: Same idempotency key sent on all retry attempts
    test "same idempotency key reused across all retry attempts" do
      client = retry_client(max_retries: 2)
      seen_keys = Agent.start_link(fn -> [] end) |> elem(1)

      stub(LatticeStripe.MockRetryStrategy, :retry?, fn _attempt, _ctx ->
        {:retry, 0}
      end)

      expect(LatticeStripe.MockTransport, :request, 3, fn req_map ->
        idk_header = Enum.find(req_map.headers, fn {k, _} -> k == "idempotency-key" end)
        assert idk_header != nil
        {_, key} = idk_header
        Agent.update(seen_keys, fn keys -> [key | keys] end)
        error_response(500, "api_error", "Server error")
      end)

      assert {:error, _} = Client.request(client, post_request())

      keys = Agent.get(seen_keys, & &1)
      Agent.stop(seen_keys)

      # All 3 attempts used the same key
      assert length(keys) == 3
      assert Enum.uniq(keys) |> length() == 1
    end
  end

  describe "operation_timeouts" do
    # Test: nil operation_timeouts uses client.timeout for all operations
    test "nil operation_timeouts uses client.timeout for all operations" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert req_map.opts[:timeout] == 30_000
        ok_response()
      end)

      assert {:ok, _} = Client.request(client, get_request("/v1/customers"))
    end

    # Test: list operation uses operation_timeouts[:list]
    test "list operation uses operation_timeouts[:list]" do
      client = test_client(operation_timeouts: %{list: 60_000})

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert req_map.opts[:timeout] == 60_000
        ok_response()
      end)

      req = %Request{method: :get, path: "/v1/customers", params: %{}, opts: []}
      assert {:ok, _} = Client.request(client, req)
    end

    # Test: retrieve operation falls back to client.timeout when not in operation_timeouts
    test "retrieve operation falls back to client.timeout when not in operation_timeouts" do
      client = test_client(operation_timeouts: %{list: 60_000})

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert req_map.opts[:timeout] == 30_000
        ok_response()
      end)

      req = %Request{method: :get, path: "/v1/customers/cus_123", params: %{}, opts: []}
      assert {:ok, _} = Client.request(client, req)
    end

    # Test: per-request opts[:timeout] overrides operation_timeouts
    test "per-request opts[:timeout] overrides operation_timeouts" do
      client = test_client(operation_timeouts: %{list: 60_000})

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert req_map.opts[:timeout] == 5_000
        ok_response()
      end)

      req = %Request{method: :get, path: "/v1/customers", params: %{}, opts: [timeout: 5_000]}
      assert {:ok, _} = Client.request(client, req)
    end

    # Test: search operation classified from GET /v1/{resource}/search
    test "search operation classified from GET /v1/{resource}/search" do
      client = test_client(operation_timeouts: %{search: 45_000})

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert req_map.opts[:timeout] == 45_000
        ok_response()
      end)

      req = %Request{method: :get, path: "/v1/customers/search", params: %{}, opts: []}
      assert {:ok, _} = Client.request(client, req)
    end

    # Test: create operation classified from POST /v1/{resource}
    test "create operation classified from POST /v1/{resource}" do
      client = test_client(operation_timeouts: %{create: 15_000})

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert req_map.opts[:timeout] == 15_000
        ok_response()
      end)

      req = %Request{method: :post, path: "/v1/customers", params: %{}, opts: []}
      assert {:ok, _} = Client.request(client, req)
    end

    # Test: edge case path falls through to client.timeout
    test "edge case path falls through to client.timeout" do
      client = test_client(operation_timeouts: %{list: 60_000})

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert req_map.opts[:timeout] == 30_000
        ok_response()
      end)

      # POST /v1/charges/ch_123/capture => :other (3 segments, no match)
      req = %Request{method: :post, path: "/v1/charges/ch_123/capture", params: %{}, opts: []}
      assert {:ok, _} = Client.request(client, req)
    end
  end
end
