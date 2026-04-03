defmodule LatticeStripe.TelemetryTest do
  use ExUnit.Case, async: false

  import Mox
  import ExUnit.CaptureLog

  alias LatticeStripe.{Client, Request, Webhook}

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # Test helpers
  # ---------------------------------------------------------------------------

  defp test_client(opts \\ []) do
    Client.new!(
      Keyword.merge(
        [
          api_key: "sk_test_telemetry",
          finch: :telemetry_test_finch,
          transport: LatticeStripe.MockTransport,
          telemetry_enabled: true,
          max_retries: 0
        ],
        opts
      )
    )
  end

  defp attach_handler(events) do
    test_pid = self()
    handler_id = "telemetry-test-#{:erlang.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      events,
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    handler_id
  end

  defp ok_response do
    {:ok,
     %{
       status: 200,
       headers: [{"request-id", "req_test123"}],
       body: Jason.encode!(%{"id" => "cus_123", "object" => "customer"})
     }}
  end

  defp error_response(status, type, message) do
    body = Jason.encode!(%{"error" => %{"type" => type, "message" => message}})
    {:ok, %{status: status, headers: [{"request-id", "req_err456"}], body: body}}
  end

  defp get_request(path \\ "/v1/customers/cus_123") do
    %Request{method: :get, path: path}
  end

  defp post_request(path \\ "/v1/customers", params \\ %{}) do
    %Request{method: :post, path: path, params: params}
  end

  defp delete_request(path \\ "/v1/customers/cus_123") do
    %Request{method: :delete, path: path}
  end

  # ---------------------------------------------------------------------------
  # 1. Request start metadata
  # ---------------------------------------------------------------------------

  describe "request start metadata" do
    test "start event has :method key with atom value" do
      attach_handler([[:lattice_stripe, :request, :start]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)
      Client.request(client, post_request())

      assert_receive {:telemetry, [:lattice_stripe, :request, :start], _measurements, metadata}
      assert metadata.method == :post
      assert is_atom(metadata.method)
    end

    test "start event has :path key with string value" do
      attach_handler([[:lattice_stripe, :request, :start]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)
      Client.request(client, get_request("/v1/customers"))

      assert_receive {:telemetry, [:lattice_stripe, :request, :start], _measurements, metadata}
      assert metadata.path == "/v1/customers"
      assert is_binary(metadata.path)
    end

    test "start event has :resource key parsed from path" do
      attach_handler([[:lattice_stripe, :request, :start]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)
      Client.request(client, post_request("/v1/customers"))

      assert_receive {:telemetry, [:lattice_stripe, :request, :start], _measurements, metadata}
      assert metadata.resource == "customer"
      assert is_binary(metadata.resource)
    end

    test "start event has :operation key parsed from path and method" do
      attach_handler([[:lattice_stripe, :request, :start]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)
      Client.request(client, post_request("/v1/customers"))

      assert_receive {:telemetry, [:lattice_stripe, :request, :start], _measurements, metadata}
      assert metadata.operation == "create"
      assert is_binary(metadata.operation)
    end

    test "start event has :api_version and :stripe_account from client config" do
      attach_handler([[:lattice_stripe, :request, :start]])

      client = test_client(stripe_account: "acct_connect123")

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)
      Client.request(client, get_request())

      assert_receive {:telemetry, [:lattice_stripe, :request, :start], _measurements, metadata}
      assert is_binary(metadata.api_version)
      assert String.contains?(metadata.api_version, ".")
      assert metadata.stripe_account == "acct_connect123"
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Request stop metadata — success
  # ---------------------------------------------------------------------------

  describe "request stop metadata - success" do
    test "stop event has all start metadata keys" do
      attach_handler([[:lattice_stripe, :request, :stop]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)
      Client.request(client, get_request("/v1/customers/cus_123"))

      assert_receive {:telemetry, [:lattice_stripe, :request, :stop], _measurements, metadata}
      assert Map.has_key?(metadata, :method)
      assert Map.has_key?(metadata, :path)
      assert Map.has_key?(metadata, :resource)
      assert Map.has_key?(metadata, :operation)
      assert Map.has_key?(metadata, :api_version)
      assert Map.has_key?(metadata, :stripe_account)
    end

    test "stop event has :status => :ok for successful response" do
      attach_handler([[:lattice_stripe, :request, :stop]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)
      Client.request(client, get_request())

      assert_receive {:telemetry, [:lattice_stripe, :request, :stop], _measurements, metadata}
      assert metadata.status == :ok
    end

    test "stop event has :http_status integer and :request_id string" do
      attach_handler([[:lattice_stripe, :request, :stop]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)
      Client.request(client, get_request())

      assert_receive {:telemetry, [:lattice_stripe, :request, :stop], _measurements, metadata}
      assert metadata.http_status == 200
      assert is_integer(metadata.http_status)
      assert metadata.request_id == "req_test123"
      assert is_binary(metadata.request_id)
    end

    test "stop event has :attempts and :retries integers" do
      attach_handler([[:lattice_stripe, :request, :stop]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)
      Client.request(client, get_request())

      assert_receive {:telemetry, [:lattice_stripe, :request, :stop], _measurements, metadata}
      assert metadata.attempts == 1
      assert metadata.retries == 0
      assert is_integer(metadata.attempts)
      assert is_integer(metadata.retries)
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Request stop metadata — error
  # ---------------------------------------------------------------------------

  describe "request stop metadata - error" do
    test "stop event has :status => :error for API error response" do
      attach_handler([[:lattice_stripe, :request, :stop]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response(400, "invalid_request_error", "No such customer")
      end)

      Client.request(client, get_request())

      assert_receive {:telemetry, [:lattice_stripe, :request, :stop], _measurements, metadata}
      assert metadata.status == :error
    end

    test "stop event has :error_type atom and :idempotency_key string on POST error" do
      attach_handler([[:lattice_stripe, :request, :stop]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response(402, "card_error", "Card declined")
      end)

      Client.request(client, post_request())

      assert_receive {:telemetry, [:lattice_stripe, :request, :stop], _measurements, metadata}
      assert metadata.error_type == :card_error
      assert is_atom(metadata.error_type)
      # POST auto-generates an idempotency key
      assert is_binary(metadata.idempotency_key)
    end

    test "stop event has :http_status on API error, nil on connection error" do
      attach_handler([[:lattice_stripe, :request, :stop]])
      client = test_client()

      # API error: has http_status
      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response(500, "api_error", "Internal server error")
      end)

      Client.request(client, get_request())
      assert_receive {:telemetry, [:lattice_stripe, :request, :stop], _measurements, meta_api}
      assert meta_api.http_status == 500

      # Connection error: no http_status
      expect(LatticeStripe.MockTransport, :request, fn _req ->
        {:error, :econnrefused}
      end)

      Client.request(client, get_request())
      assert_receive {:telemetry, [:lattice_stripe, :request, :stop], _measurements, meta_conn}
      assert meta_conn.status == :error
      # connection errors don't have http_status in metadata
      refute Map.has_key?(meta_conn, :http_status)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Request exception metadata
  # ---------------------------------------------------------------------------

  describe "request exception metadata" do
    test "exception event fires on uncaught raise with :kind, :reason, :stacktrace" do
      attach_handler([[:lattice_stripe, :request, :exception]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        raise RuntimeError, "transport blew up"
      end)

      assert_raise RuntimeError, "transport blew up", fn ->
        Client.request(client, get_request())
      end

      assert_receive {:telemetry, [:lattice_stripe, :request, :exception], _measurements,
                      metadata}

      assert metadata.kind == :error
      assert %RuntimeError{message: "transport blew up"} = metadata.reason
      assert is_list(metadata.stacktrace)
    end

    test "exception event has start metadata keys (method, path, etc.)" do
      attach_handler([[:lattice_stripe, :request, :exception]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        raise "boom"
      end)

      assert_raise RuntimeError, fn ->
        Client.request(client, get_request("/v1/customers"))
      end

      assert_receive {:telemetry, [:lattice_stripe, :request, :exception], _measurements,
                      metadata}

      assert metadata.method == :get
      assert metadata.path == "/v1/customers"
      assert is_binary(metadata.resource)
      assert is_binary(metadata.operation)
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Retry event metadata
  # ---------------------------------------------------------------------------

  describe "retry event metadata" do
    test "retry event measurements have :attempt and :delay_ms" do
      attach_handler([[:lattice_stripe, :request, :retry]])

      client =
        test_client(
          max_retries: 1,
          retry_strategy: LatticeStripe.MockRetryStrategy
        )

      # First call fails, retry fires, second call succeeds
      expect(LatticeStripe.MockTransport, :request, 2, fn _req ->
        error_response(500, "api_error", "Server error")
      end)

      expect(LatticeStripe.MockRetryStrategy, :retry?, fn _attempt, _context ->
        {:retry, 0}
      end)

      Client.request(client, get_request())

      assert_receive {:telemetry, [:lattice_stripe, :request, :retry], measurements, _metadata}
      assert is_integer(measurements.attempt)
      assert measurements.attempt == 1
      assert is_integer(measurements.delay_ms)
      assert measurements.delay_ms == 0
    end

    test "retry event metadata has :method, :path, :error_type, :status" do
      attach_handler([[:lattice_stripe, :request, :retry]])

      client =
        test_client(
          max_retries: 1,
          retry_strategy: LatticeStripe.MockRetryStrategy
        )

      expect(LatticeStripe.MockTransport, :request, 2, fn _req ->
        error_response(503, "api_error", "Service unavailable")
      end)

      expect(LatticeStripe.MockRetryStrategy, :retry?, fn _attempt, _context ->
        {:retry, 0}
      end)

      Client.request(client, get_request("/v1/customers"))

      assert_receive {:telemetry, [:lattice_stripe, :request, :retry], _measurements, metadata}
      assert metadata.method == :get
      assert metadata.path == "/v1/customers"
      assert is_atom(metadata.error_type)
      assert metadata.status == 503
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Telemetry disabled
  # ---------------------------------------------------------------------------

  describe "telemetry disabled" do
    test "telemetry_enabled: false suppresses start/stop/retry events" do
      attach_handler([
        [:lattice_stripe, :request, :start],
        [:lattice_stripe, :request, :stop],
        [:lattice_stripe, :request, :retry]
      ])

      client = test_client(telemetry_enabled: false)

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)
      Client.request(client, get_request())

      refute_receive {:telemetry, [:lattice_stripe, :request, :start], _, _}
      refute_receive {:telemetry, [:lattice_stripe, :request, :stop], _, _}
      refute_receive {:telemetry, [:lattice_stripe, :request, :retry], _, _}
    end

    test "telemetry_enabled: false suppresses exception events" do
      attach_handler([[:lattice_stripe, :request, :exception]])

      client = test_client(telemetry_enabled: false)

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        raise RuntimeError, "boom"
      end)

      assert_raise RuntimeError, fn ->
        Client.request(client, get_request())
      end

      refute_receive {:telemetry, [:lattice_stripe, :request, :exception], _, _}
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Resource and operation parsing
  # ---------------------------------------------------------------------------

  describe "resource and operation parsing" do
    defp get_start_metadata(path, method) do
      test_pid = self()
      handler_id = "parse-test-#{:erlang.unique_integer([:positive])}"

      :telemetry.attach_many(
        handler_id,
        [[:lattice_stripe, :request, :start]],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:meta, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)

      req = %Request{method: method, path: path}
      Client.request(client, req)

      assert_receive {:meta, metadata}
      metadata
    end

    test "POST /v1/customers => resource: customer, operation: create" do
      meta = get_start_metadata("/v1/customers", :post)
      assert meta.resource == "customer"
      assert meta.operation == "create"
    end

    test "GET /v1/customers/cus_123 => resource: customer, operation: retrieve" do
      meta = get_start_metadata("/v1/customers/cus_123", :get)
      assert meta.resource == "customer"
      assert meta.operation == "retrieve"
    end

    test "GET /v1/customers => resource: customer, operation: list" do
      meta = get_start_metadata("/v1/customers", :get)
      assert meta.resource == "customer"
      assert meta.operation == "list"
    end

    test "DELETE /v1/customers/cus_123 => resource: customer, operation: delete" do
      meta = get_start_metadata("/v1/customers/cus_123", :delete)
      assert meta.resource == "customer"
      assert meta.operation == "delete"
    end

    test "POST /v1/payment_intents/pi_123/confirm => resource: payment_intent, operation: confirm" do
      meta = get_start_metadata("/v1/payment_intents/pi_123abc/confirm", :post)
      assert meta.resource == "payment_intent"
      assert meta.operation == "confirm"
    end

    test "POST /v1/checkout/sessions => resource: checkout.session, operation: create" do
      meta = get_start_metadata("/v1/checkout/sessions", :post)
      assert meta.resource == "checkout.session"
      assert meta.operation == "create"
    end
  end

  # ---------------------------------------------------------------------------
  # 8. Webhook verify telemetry
  # ---------------------------------------------------------------------------

  describe "webhook verify telemetry" do
    @secret "whsec_test_secret_key_for_telemetry"

    defp valid_webhook_payload do
      Jason.encode!(%{
        "id" => "evt_test",
        "object" => "event",
        "type" => "payment_intent.succeeded",
        "api_version" => "2026-03-25.dahlia",
        "created" => System.system_time(:second),
        "livemode" => false,
        "pending_webhooks" => 1,
        "request" => nil,
        "data" => %{"object" => %{"id" => "pi_test", "object" => "payment_intent"}}
      })
    end

    test "verify span emits start with :path metadata" do
      attach_handler([[:lattice_stripe, :webhook, :verify, :start]])

      payload = valid_webhook_payload()
      sig = Webhook.generate_test_signature(payload, @secret)

      Webhook.construct_event(payload, sig, @secret)

      assert_receive {:telemetry, [:lattice_stripe, :webhook, :verify, :start], _measurements,
                      metadata}

      assert Map.has_key?(metadata, :path)
    end

    test "verify span emits stop with :result => :ok on success" do
      attach_handler([[:lattice_stripe, :webhook, :verify, :stop]])

      payload = valid_webhook_payload()
      sig = Webhook.generate_test_signature(payload, @secret)

      assert {:ok, _event} = Webhook.construct_event(payload, sig, @secret)

      assert_receive {:telemetry, [:lattice_stripe, :webhook, :verify, :stop], _measurements,
                      metadata}

      assert metadata.result == :ok
    end

    test "verify span emits stop with :result => :error and :error_reason on failure" do
      attach_handler([[:lattice_stripe, :webhook, :verify, :stop]])

      payload = valid_webhook_payload()
      # Use a current timestamp but a bad signature so we get :no_matching_signature
      # (not :timestamp_expired)
      ts = System.system_time(:second)

      bad_sig_header =
        "t=#{ts},v1=deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"

      assert {:error, :no_matching_signature} =
               Webhook.construct_event(payload, bad_sig_header, @secret)

      assert_receive {:telemetry, [:lattice_stripe, :webhook, :verify, :stop], _measurements,
                      metadata}

      assert metadata.result == :error
      assert is_atom(metadata.error_reason)
    end

    test "verify span always fires regardless of telemetry_enabled on client" do
      # Webhook telemetry is NOT gated by client.telemetry_enabled --
      # it's infrastructure-level (D-02), always on.
      attach_handler([[:lattice_stripe, :webhook, :verify, :stop]])

      payload = valid_webhook_payload()
      sig = Webhook.generate_test_signature(payload, @secret)

      Webhook.construct_event(payload, sig, @secret)

      assert_receive {:telemetry, [:lattice_stripe, :webhook, :verify, :stop], _measurements,
                      _metadata}
    end
  end

  # ---------------------------------------------------------------------------
  # 9a. Metadata field exhaustiveness
  # ---------------------------------------------------------------------------

  describe "start event metadata exhaustiveness" do
    test "start event has :telemetry_span_context injected by :telemetry.span/3" do
      # :telemetry.span/3 auto-injects telemetry_span_context reference for correlating
      # start/stop/exception events — this should always be present
      attach_handler([[:lattice_stripe, :request, :start]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)
      Client.request(client, get_request("/v1/customers"))

      assert_receive {:telemetry, [:lattice_stripe, :request, :start], _measurements, metadata}
      assert Map.has_key?(metadata, :telemetry_span_context)
      assert is_reference(metadata.telemetry_span_context)
    end

    test "start event has all six documented metadata fields" do
      attach_handler([[:lattice_stripe, :request, :start]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)
      Client.request(client, post_request("/v1/customers"))

      assert_receive {:telemetry, [:lattice_stripe, :request, :start], _measurements, metadata}

      assert Map.has_key?(metadata, :method)
      assert Map.has_key?(metadata, :path)
      assert Map.has_key?(metadata, :resource)
      assert Map.has_key?(metadata, :operation)
      assert Map.has_key?(metadata, :api_version)
      assert Map.has_key?(metadata, :stripe_account)
    end

    test "start event :stripe_account is nil when client has no stripe_account configured" do
      attach_handler([[:lattice_stripe, :request, :start]])
      # no stripe_account option => nil
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)
      Client.request(client, get_request())

      assert_receive {:telemetry, [:lattice_stripe, :request, :start], _measurements, metadata}
      assert metadata.stripe_account == nil
    end
  end

  describe "stop event metadata exhaustiveness - success" do
    test "stop event success: :error_type and :idempotency_key are absent on success" do
      # On success the stop metadata does NOT include :error_type or :idempotency_key
      attach_handler([[:lattice_stripe, :request, :stop]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)
      Client.request(client, get_request())

      assert_receive {:telemetry, [:lattice_stripe, :request, :stop], _measurements, metadata}
      refute Map.has_key?(metadata, :error_type)
      refute Map.has_key?(metadata, :idempotency_key)
    end

    test "stop event has :telemetry_span_context that matches start event context" do
      attach_handler([
        [:lattice_stripe, :request, :start],
        [:lattice_stripe, :request, :stop]
      ])

      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)
      Client.request(client, get_request())

      assert_receive {:telemetry, [:lattice_stripe, :request, :start], _, start_meta}
      assert_receive {:telemetry, [:lattice_stripe, :request, :stop], _, stop_meta}

      # Both events share the same telemetry_span_context reference for correlation
      assert start_meta.telemetry_span_context == stop_meta.telemetry_span_context
    end

    test "stop event success: measurements include :duration and :monotonic_time" do
      attach_handler([[:lattice_stripe, :request, :stop]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)
      Client.request(client, get_request())

      assert_receive {:telemetry, [:lattice_stripe, :request, :stop], measurements, _metadata}
      assert Map.has_key?(measurements, :duration)
      assert Map.has_key?(measurements, :monotonic_time)
      assert is_integer(measurements.duration)
      assert measurements.duration >= 0
    end

    test "start event measurements include :system_time and :monotonic_time" do
      attach_handler([[:lattice_stripe, :request, :start]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)
      Client.request(client, get_request())

      assert_receive {:telemetry, [:lattice_stripe, :request, :start], measurements, _metadata}
      assert Map.has_key?(measurements, :system_time)
      assert Map.has_key?(measurements, :monotonic_time)
      assert is_integer(measurements.system_time)
      assert is_integer(measurements.monotonic_time)
    end
  end

  describe "stop event metadata exhaustiveness - error" do
    test "stop event API error: has :error_type, :http_status, :request_id, :idempotency_key (on POST)" do
      attach_handler([[:lattice_stripe, :request, :stop]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response(402, "card_error", "Card declined")
      end)

      Client.request(client, post_request("/v1/payment_intents"))

      assert_receive {:telemetry, [:lattice_stripe, :request, :stop], _measurements, metadata}
      assert metadata.status == :error
      assert Map.has_key?(metadata, :error_type)
      assert Map.has_key?(metadata, :http_status)
      assert Map.has_key?(metadata, :request_id)
      assert Map.has_key?(metadata, :idempotency_key)
    end

    test "stop event connection error: has :error_type but NOT :http_status or :request_id" do
      attach_handler([[:lattice_stripe, :request, :stop]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        {:error, :econnrefused}
      end)

      Client.request(client, get_request())

      assert_receive {:telemetry, [:lattice_stripe, :request, :stop], _measurements, metadata}
      assert metadata.status == :error
      assert metadata.error_type == :connection_error
      refute Map.has_key?(metadata, :http_status)
      refute Map.has_key?(metadata, :request_id)
    end
  end

  describe "exception event metadata exhaustiveness" do
    test "exception event has all documented metadata fields" do
      attach_handler([[:lattice_stripe, :request, :exception]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        raise RuntimeError, "transport failure"
      end)

      assert_raise RuntimeError, fn ->
        Client.request(client, post_request("/v1/customers"))
      end

      assert_receive {:telemetry, [:lattice_stripe, :request, :exception], _measurements,
                      metadata}

      # Start metadata fields
      assert Map.has_key?(metadata, :method)
      assert Map.has_key?(metadata, :path)
      assert Map.has_key?(metadata, :resource)
      assert Map.has_key?(metadata, :operation)
      assert Map.has_key?(metadata, :api_version)
      assert Map.has_key?(metadata, :stripe_account)

      # Exception-specific fields
      assert Map.has_key?(metadata, :kind)
      assert Map.has_key?(metadata, :reason)
      assert Map.has_key?(metadata, :stacktrace)
      assert Map.has_key?(metadata, :telemetry_span_context)
    end

    test "exception event measurements include :duration and :monotonic_time" do
      attach_handler([[:lattice_stripe, :request, :exception]])
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        raise "boom"
      end)

      assert_raise RuntimeError, fn ->
        Client.request(client, get_request())
      end

      assert_receive {:telemetry, [:lattice_stripe, :request, :exception], measurements,
                      _metadata}

      assert Map.has_key?(measurements, :duration)
      assert Map.has_key?(measurements, :monotonic_time)
      assert is_integer(measurements.duration)
    end
  end

  # ---------------------------------------------------------------------------
  # 9. Default logger
  # ---------------------------------------------------------------------------

  describe "default logger" do
    setup do
      on_exit(fn -> :telemetry.detach(:lattice_stripe_default_logger) end)
      :ok
    end

    test "attach_default_logger/1 attaches handler that logs on stop event" do
      assert :ok = LatticeStripe.Telemetry.attach_default_logger(level: :info)

      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)

      log =
        capture_log(fn ->
          Client.request(client, post_request("/v1/customers"))
        end)

      assert log =~ "POST"
      assert log =~ "/v1/customers"
    end

    test "logger output matches format: METHOD /path => status in Nms (N attempt, req_xxx)" do
      assert :ok = LatticeStripe.Telemetry.attach_default_logger(level: :info)

      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req -> ok_response() end)

      log =
        capture_log(fn ->
          Client.request(client, post_request("/v1/customers"))
        end)

      assert log =~ "POST"
      assert log =~ "/v1/customers"
      assert log =~ "200"
      assert log =~ "ms"
      assert log =~ "attempt"
      assert log =~ "req_test123"
    end
  end
end
