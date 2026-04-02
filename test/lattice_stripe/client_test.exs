defmodule LatticeStripe.ClientTest do
  use ExUnit.Case, async: true

  import Mox

  alias LatticeStripe.{Client, Error, Request}

  setup :verify_on_exit!

  # Helper to build a test client that uses MockTransport by default.
  defp test_client(overrides \\ []) do
    defaults = [
      api_key: "sk_test_123",
      finch: :test_finch,
      transport: LatticeStripe.MockTransport,
      telemetry_enabled: false
    ]

    Client.new!(Keyword.merge(defaults, overrides))
  end

  # Helper: client with zero-delay retry for fast tests.
  defp retry_client(overrides \\ []) do
    defaults = [max_retries: 2, retry_strategy: LatticeStripe.MockRetryStrategy]
    test_client(Keyword.merge(defaults, overrides))
  end

  # Helper to build a standard 200 success response.
  defp ok_response(body \\ %{"id" => "obj_123", "object" => "charge"}) do
    {:ok,
     %{
       status: 200,
       headers: [{"request-id", "req_test_123"}],
       body: Jason.encode!(body)
     }}
  end

  # Helper to build an error response.
  defp error_response(status, type, message, extra_headers \\ []) do
    body = %{
      "error" => %{
        "type" => type,
        "message" => message,
        "code" => "some_code"
      }
    }

    {:ok,
     %{
       status: status,
       headers: [{"request-id", "req_err_456"}] ++ extra_headers,
       body: Jason.encode!(body)
     }}
  end

  # Helper to build a non-JSON response.
  defp non_json_response(status, body) do
    {:ok,
     %{
       status: status,
       headers: [{"request-id", "req_html_789"}],
       body: body
     }}
  end

  # Basic GET request struct.
  defp get_request(path \\ "/v1/customers/cus_123", opts \\ []) do
    %Request{method: :get, path: path, params: %{}, opts: opts}
  end

  # Basic POST request struct.
  defp post_request(path \\ "/v1/charges", params \\ %{}, opts \\ []) do
    %Request{method: :post, path: path, params: params, opts: opts}
  end

  # Basic DELETE request struct.
  defp delete_request(path \\ "/v1/customers/cus_123", opts \\ []) do
    %Request{method: :delete, path: path, params: %{}, opts: opts}
  end

  describe "new!/1 and new/1" do
    # Test 1: new!/1 with valid opts returns a %Client{} struct
    test "new!/1 with valid opts returns a %Client{} struct" do
      client = test_client()

      assert %Client{} = client
      assert client.api_key == "sk_test_123"
      assert client.finch == :test_finch
    end

    # Test 2: new!/1 without api_key raises NimbleOptions.ValidationError
    test "new!/1 without api_key raises NimbleOptions.ValidationError" do
      assert_raise NimbleOptions.ValidationError, ~r/api_key/, fn ->
        Client.new!(finch: MyApp.Finch)
      end
    end

    # Test 3: new!/1 without finch raises NimbleOptions.ValidationError
    test "new!/1 without finch raises NimbleOptions.ValidationError" do
      assert_raise NimbleOptions.ValidationError, ~r/finch/, fn ->
        Client.new!(api_key: "sk_test_123")
      end
    end

    # Test 4: new/1 with valid opts returns {:ok, %Client{}}
    test "new/1 with valid opts returns {:ok, %Client{}}" do
      assert {:ok, %Client{} = client} =
               Client.new(api_key: "sk_test_abc", finch: MyApp.Finch)

      assert client.api_key == "sk_test_abc"
    end

    # Test 5: new/1 with invalid opts returns {:error, _}
    test "new/1 with invalid opts returns {:error, _}" do
      assert {:error, %NimbleOptions.ValidationError{}} = Client.new(finch: MyApp.Finch)
    end

    # Test 6: Client struct is NOT a GenServer -- it's a plain struct
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

    # Test 7: Multiple clients with different API keys can coexist
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
  end

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
        assert {"stripe-version", "2025-12-18.acacia"} in req_map.headers
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

  describe "request/2 response handling" do
    # Test 14: request/2 on 200 returns {:ok, decoded_json_map}
    test "200 response returns {:ok, decoded_map}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        ok_response(%{"id" => "cus_123", "object" => "customer"})
      end)

      assert {:ok, %{"id" => "cus_123", "object" => "customer"}} =
               Client.request(client, get_request())
    end

    # Test 15: request/2 on 401 returns {:error, %Error{type: :authentication_error}}
    test "401 response returns authentication_error" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        error_response(401, "authentication_error", "No such API key")
      end)

      assert {:error, %Error{type: :authentication_error, status: 401}} =
               Client.request(client, get_request())
    end

    # Test 16: request/2 on 400 returns {:error, %Error{type: :invalid_request_error}}
    test "400 response returns invalid_request_error" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        error_response(400, "invalid_request_error", "Missing required param: source")
      end)

      assert {:error, %Error{type: :invalid_request_error, status: 400}} =
               Client.request(client, post_request())
    end

    # Test 17: request/2 on 429 returns {:error, %Error{type: :rate_limit_error}}
    test "429 response returns rate_limit_error" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        error_response(429, "rate_limit_error", "Too many requests")
      end)

      assert {:error, %Error{type: :rate_limit_error, status: 429}} =
               Client.request(client, get_request())
    end

    # Test 18: request/2 on transport error returns {:error, %Error{type: :connection_error}}
    test "transport error returns connection_error" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        {:error, :timeout}
      end)

      assert {:error, %Error{type: :connection_error}} =
               Client.request(client, get_request())
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
          send(test_pid, {:telemetry_event, event, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        ok_response()
      end)

      Client.request(client, get_request())

      refute_receive {:telemetry_event, [:lattice_stripe, :request, :start], _}
      refute_receive {:telemetry_event, [:lattice_stripe, :request, :stop], _}
    end
  end

  describe "transport swapping" do
    # Test 28: Custom transport via Mox mock works
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
      assert {:ok, %{"object" => "list"}} = Client.request(client, req)
    end
  end

  describe "request/2 retry loop" do
    # Test 29: Client retries on 500 response up to max_retries times
    test "retries on 500 up to max_retries times" do
      # max_retries: 2 means 3 total attempts (initial + 2 retries)
      client = retry_client(max_retries: 2)

      # Strategy returns {:retry, 0} for first 2 attempts, :stop on 3rd (exhausted)
      stub(LatticeStripe.MockRetryStrategy, :retry?, fn _attempt, _ctx ->
        {:retry, 0}
      end)

      # Transport called 3 times total: initial + 2 retries
      expect(LatticeStripe.MockTransport, :request, 3, fn _req_map ->
        error_response(500, "api_error", "Internal server error")
      end)

      assert {:error, %Error{type: :api_error, status: 500}} =
               Client.request(client, get_request())
    end

    # Test 30: Client stops retrying when strategy returns :stop
    test "stops retrying when strategy returns :stop" do
      client = retry_client()

      # Strategy immediately says :stop
      stub(LatticeStripe.MockRetryStrategy, :retry?, fn _attempt, _ctx ->
        :stop
      end)

      # Transport called only once (400 is not retriable for default strategy)
      expect(LatticeStripe.MockTransport, :request, 1, fn _req_map ->
        error_response(400, "invalid_request_error", "Bad param")
      end)

      assert {:error, %Error{type: :invalid_request_error, status: 400}} =
               Client.request(client, post_request())
    end

    # Test 31: Client returns final error after exhausting retries
    test "returns final error after exhausting retries" do
      client = retry_client(max_retries: 1)

      stub(LatticeStripe.MockRetryStrategy, :retry?, fn _attempt, _ctx ->
        {:retry, 0}
      end)

      # 2 total attempts (initial + 1 retry)
      expect(LatticeStripe.MockTransport, :request, 2, fn _req_map ->
        error_response(503, "api_error", "Service unavailable")
      end)

      assert {:error, %Error{status: 503}} = Client.request(client, get_request())
    end

    # Test 32: Per-request max_retries: 0 disables retries (single attempt)
    test "max_retries: 0 disables retries" do
      client = retry_client(max_retries: 0)

      stub(LatticeStripe.MockRetryStrategy, :retry?, fn _attempt, _ctx ->
        {:retry, 0}
      end)

      # Only 1 attempt even though strategy says retry
      expect(LatticeStripe.MockTransport, :request, 1, fn _req_map ->
        error_response(500, "api_error", "Internal server error")
      end)

      assert {:error, %Error{status: 500}} = Client.request(client, get_request())
    end

    # Test 33: Per-request max_retries override
    test "per-request max_retries: 5 overrides client default" do
      # Client has default max_retries: 2, but request overrides to 1
      client = retry_client(max_retries: 2)

      stub(LatticeStripe.MockRetryStrategy, :retry?, fn _attempt, _ctx ->
        {:retry, 0}
      end)

      # Only 2 attempts (initial + 1 retry with max_retries: 1 override)
      expect(LatticeStripe.MockTransport, :request, 2, fn _req_map ->
        error_response(500, "api_error", "Internal server error")
      end)

      req = get_request("/v1/customers", max_retries: 1)
      assert {:error, %Error{status: 500}} = Client.request(client, req)
    end

    # Test 34: Successful request after retries returns {:ok, result}
    test "succeeds after initial failures" do
      client = retry_client(max_retries: 2)

      stub(LatticeStripe.MockRetryStrategy, :retry?, fn _attempt, _ctx ->
        {:retry, 0}
      end)

      # First 2 attempts fail, 3rd succeeds
      expect(LatticeStripe.MockTransport, :request, 2, fn _req_map ->
        error_response(500, "api_error", "Server error")
      end)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        ok_response(%{"id" => "cus_success"})
      end)

      assert {:ok, %{"id" => "cus_success"}} = Client.request(client, get_request())
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

  describe "request/2 non-JSON responses" do
    # Test 40: HTML response body returns structured api_error with raw_body
    test "HTML response returns api_error with raw_body containing _raw key" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        non_json_response(503, "<html><body>We're down for maintenance</body></html>")
      end)

      assert {:error, %Error{type: :api_error, raw_body: %{"_raw" => raw}}} =
               Client.request(client, get_request())

      assert is_binary(raw)
      assert String.contains?(raw, "maintenance")
    end

    # Test 41: Empty response body returns structured api_error
    test "empty response body returns api_error with descriptive message" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        non_json_response(500, "")
      end)

      assert {:error, %Error{type: :api_error, message: message}} =
               Client.request(client, get_request())

      assert is_binary(message)
    end

    # Test 42: Non-JSON 503 response flows through retry loop normally
    test "non-JSON 503 response flows through retry loop" do
      client = retry_client(max_retries: 1)

      stub(LatticeStripe.MockRetryStrategy, :retry?, fn _attempt, _ctx ->
        {:retry, 0}
      end)

      # 2 total attempts (initial + 1 retry)
      expect(LatticeStripe.MockTransport, :request, 2, fn _req_map ->
        non_json_response(503, "<html>maintenance</html>")
      end)

      assert {:error, %Error{type: :api_error, status: 503}} =
               Client.request(client, get_request())
    end

    # Test 43: Non-JSON body is truncated at 500 bytes in raw_body
    test "long non-JSON body is truncated in raw_body" do
      client = test_client(max_retries: 0)
      long_body = String.duplicate("x", 1000)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        non_json_response(502, long_body)
      end)

      assert {:error, %Error{type: :api_error, raw_body: %{"_raw" => raw}}} =
               Client.request(client, get_request())

      # Should be truncated (500 chars + "...")
      assert byte_size(raw) <= 510
    end
  end

  describe "request!/2 bang variant" do
    # Test 44: request!/2 raises LatticeStripe.Error on failure
    test "raises LatticeStripe.Error on failure" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        error_response(401, "authentication_error", "Invalid API key")
      end)

      assert_raise LatticeStripe.Error, fn ->
        Client.request!(client, get_request())
      end
    end

    # Test 45: request!/2 returns decoded map on success
    test "returns decoded map on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        ok_response(%{"id" => "cus_bang_123"})
      end)

      result = Client.request!(client, get_request())
      assert result == %{"id" => "cus_bang_123"}
    end

    # Test 46: request!/2 retries before raising
    test "retries before raising on final failure" do
      client = retry_client(max_retries: 2)

      stub(LatticeStripe.MockRetryStrategy, :retry?, fn _attempt, _ctx ->
        {:retry, 0}
      end)

      # All 3 attempts fail
      expect(LatticeStripe.MockTransport, :request, 3, fn _req_map ->
        error_response(500, "api_error", "Server error")
      end)

      assert_raise LatticeStripe.Error, fn ->
        Client.request!(client, get_request())
      end
    end

    # Test 47: request!/2 raises with correct error type
    test "raised error has correct type and status" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        error_response(402, "card_error", "Card declined")
      end)

      error =
        assert_raise LatticeStripe.Error, fn ->
          Client.request!(client, post_request())
        end

      assert error.type == :card_error
      assert error.status == 402
    end
  end

  describe "request/2 retry telemetry" do
    # Test 48: Per-retry event emitted with attempt and delay_ms measurements
    test "emits per-retry telemetry events with attempt and delay_ms" do
      client =
        test_client(
          telemetry_enabled: true,
          retry_strategy: LatticeStripe.MockRetryStrategy,
          max_retries: 1
        )

      test_pid = self()
      handler_id = "test-retry-telemetry-#{:erlang.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:lattice_stripe, :request, :retry],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:retry_event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      stub(LatticeStripe.MockRetryStrategy, :retry?, fn _attempt, _ctx ->
        {:retry, 0}
      end)

      expect(LatticeStripe.MockTransport, :request, 2, fn _req_map ->
        error_response(500, "api_error", "Server error")
      end)

      Client.request(client, get_request())

      assert_receive {:retry_event, measurements, metadata}
      assert Map.has_key?(measurements, :attempt)
      assert Map.has_key?(measurements, :delay_ms)
      assert Map.has_key?(metadata, :method)
      assert Map.has_key?(metadata, :path)
    end

    # Test 49: Stop event metadata includes attempts and retries
    test "stop event metadata includes attempts and retries counts" do
      client =
        test_client(
          telemetry_enabled: true,
          retry_strategy: LatticeStripe.MockRetryStrategy,
          max_retries: 1
        )

      test_pid = self()
      handler_id = "test-stop-metadata-#{:erlang.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:lattice_stripe, :request, :stop],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:stop_event, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      stub(LatticeStripe.MockRetryStrategy, :retry?, fn _attempt, _ctx ->
        {:retry, 0}
      end)

      # Both attempts fail
      expect(LatticeStripe.MockTransport, :request, 2, fn _req_map ->
        error_response(500, "api_error", "Server error")
      end)

      Client.request(client, get_request())

      assert_receive {:stop_event, metadata}
      assert metadata.attempts == 2
      assert metadata.retries == 1
    end

    # Test 50: Successful request after retries has correct attempts in stop metadata
    test "successful request after retries has correct attempts count" do
      client =
        test_client(
          telemetry_enabled: true,
          retry_strategy: LatticeStripe.MockRetryStrategy,
          max_retries: 2
        )

      test_pid = self()
      handler_id = "test-success-retry-#{:erlang.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:lattice_stripe, :request, :stop],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:stop_event, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      stub(LatticeStripe.MockRetryStrategy, :retry?, fn _attempt, _ctx ->
        {:retry, 0}
      end)

      # First fails, second succeeds
      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        error_response(500, "api_error", "Server error")
      end)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        ok_response()
      end)

      assert {:ok, _} = Client.request(client, get_request())

      assert_receive {:stop_event, metadata}
      assert metadata.attempts == 2
      assert metadata.retries == 1
      assert metadata.status == :ok
    end
  end

  describe "request/2 Stripe-Should-Retry" do
    # Test 51: Stripe-Should-Retry: true on 400 causes retry
    test "Stripe-Should-Retry: true on 400 causes retry" do
      client = test_client(max_retries: 1)
      # Use default retry strategy which respects Stripe-Should-Retry header

      # Transport called twice: initial + 1 retry
      expect(LatticeStripe.MockTransport, :request, 2, fn _req_map ->
        error_response(400, "invalid_request_error", "Bad request", [
          {"stripe-should-retry", "true"}
        ])
      end)

      assert {:error, %Error{status: 400}} = Client.request(client, get_request())
    end

    # Test 52: Stripe-Should-Retry: false on 500 prevents retry
    test "Stripe-Should-Retry: false on 500 prevents retry" do
      client = test_client(max_retries: 2)
      # Only 1 attempt — header says don't retry

      expect(LatticeStripe.MockTransport, :request, 1, fn _req_map ->
        error_response(500, "api_error", "Server error", [{"stripe-should-retry", "false"}])
      end)

      assert {:error, %Error{status: 500}} = Client.request(client, get_request())
    end
  end
end
