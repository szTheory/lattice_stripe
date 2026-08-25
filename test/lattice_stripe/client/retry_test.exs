defmodule LatticeStripe.Client.RetryTest do
  use LatticeStripe.ClientCase, async: true

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

      assert {:ok, %Response{data: %{"id" => "cus_success"}}} =
               Client.request(client, get_request())
    end

    test "returns final-attempt response evidence and passes that same list to retry strategy" do
      client = retry_client(max_retries: 1)

      first_headers = [{"request-id", "req_err_456"}, {"retry-after", "5"}]

      final_headers = [
        {"request-id", "req_err_456"},
        {"Retry-After", "60"},
        {"retry-after", "120"}
      ]

      expect(LatticeStripe.MockRetryStrategy, :retry?, fn 1, context ->
        assert context.headers == first_headers
        {:retry, 0}
      end)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        error_response(429, "rate_limit_error", "Too many requests", tl(first_headers))
      end)

      expect(LatticeStripe.MockTransport, :request, fn _req_map ->
        error_response(429, "rate_limit_error", "Still limited", tl(final_headers))
      end)

      assert {:error, %Error{headers: ^final_headers, retry_after: 60} = error} =
               Client.request(client, get_request())

      assert Error.get_header(error, "RETRY-AFTER") == ["60", "120"]
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

      handler_id = "test-retry-telemetry-#{:erlang.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:lattice_stripe, :request, :retry],
        &LatticeStripe.TestTelemetryHandler.handle_event/4,
        {self(), :retry_event}
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      stub(LatticeStripe.MockRetryStrategy, :retry?, fn _attempt, _ctx ->
        {:retry, 0}
      end)

      expect(LatticeStripe.MockTransport, :request, 2, fn _req_map ->
        error_response(500, "api_error", "Server error")
      end)

      Client.request(client, get_request())

      assert_receive {:retry_event, [:lattice_stripe, :request, :retry], measurements, metadata}
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

      handler_id = "test-stop-metadata-#{:erlang.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:lattice_stripe, :request, :stop],
        &LatticeStripe.TestTelemetryHandler.handle_event/4,
        {self(), :stop_event}
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

      assert_receive {:stop_event, [:lattice_stripe, :request, :stop], _, metadata}
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

      handler_id = "test-success-retry-#{:erlang.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:lattice_stripe, :request, :stop],
        &LatticeStripe.TestTelemetryHandler.handle_event/4,
        {self(), :stop_event}
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

      assert_receive {:stop_event, [:lattice_stripe, :request, :stop], _, metadata}
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
