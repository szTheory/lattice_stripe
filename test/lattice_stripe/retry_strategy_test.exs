defmodule LatticeStripe.RetryStrategyTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.{Error, RetryStrategy}

  describe "Stripe-Should-Retry header" do
    test "stripe_should_retry: true forces retry regardless of status" do
      ctx = %{stripe_should_retry: true, status: 400, headers: [], error: nil, method: :get, idempotency_key: nil}
      assert {:retry, delay_ms} = RetryStrategy.Default.retry?(1, ctx)
      assert delay_ms > 0
    end

    test "stripe_should_retry: false forces stop regardless of status" do
      ctx = %{stripe_should_retry: false, status: 500, headers: [], error: nil, method: :get, idempotency_key: nil}
      assert :stop = RetryStrategy.Default.retry?(1, ctx)
    end

    test "stripe_should_retry: nil falls through to status heuristics" do
      ctx = %{stripe_should_retry: nil, status: 500, headers: [], error: nil, method: :get, idempotency_key: nil}
      assert {:retry, delay_ms} = RetryStrategy.Default.retry?(1, ctx)
      assert delay_ms > 0
    end
  end

  describe "status code heuristics" do
    test "status 429 is retriable" do
      ctx = %{stripe_should_retry: nil, status: 429, headers: [], error: nil, method: :get, idempotency_key: nil}
      assert {:retry, delay_ms} = RetryStrategy.Default.retry?(1, ctx)
      assert delay_ms > 0
    end

    test "status 500 is retriable" do
      ctx = %{stripe_should_retry: nil, status: 500, headers: [], error: nil, method: :get, idempotency_key: nil}
      assert {:retry, _delay_ms} = RetryStrategy.Default.retry?(1, ctx)
    end

    test "status 502 is retriable" do
      ctx = %{stripe_should_retry: nil, status: 502, headers: [], error: nil, method: :get, idempotency_key: nil}
      assert {:retry, _delay_ms} = RetryStrategy.Default.retry?(1, ctx)
    end

    test "status 503 is retriable" do
      ctx = %{stripe_should_retry: nil, status: 503, headers: [], error: nil, method: :get, idempotency_key: nil}
      assert {:retry, _delay_ms} = RetryStrategy.Default.retry?(1, ctx)
    end

    test "status 400 is NOT retriable (client error)" do
      ctx = %{stripe_should_retry: nil, status: 400, headers: [], error: nil, method: :get, idempotency_key: nil}
      assert :stop = RetryStrategy.Default.retry?(1, ctx)
    end

    test "status 401 is NOT retriable (auth error)" do
      ctx = %{stripe_should_retry: nil, status: 401, headers: [], error: nil, method: :get, idempotency_key: nil}
      assert :stop = RetryStrategy.Default.retry?(1, ctx)
    end

    test "status 409 is NOT retriable (idempotency conflict)" do
      ctx = %{stripe_should_retry: nil, status: 409, headers: [], error: nil, method: :post, idempotency_key: "idk_ltc_abc"}
      assert :stop = RetryStrategy.Default.retry?(1, ctx)
    end

    test "status 404 is NOT retriable" do
      ctx = %{stripe_should_retry: nil, status: 404, headers: [], error: nil, method: :get, idempotency_key: nil}
      assert :stop = RetryStrategy.Default.retry?(1, ctx)
    end
  end

  describe "connection errors" do
    test "connection_error with nil status is retriable" do
      error = %Error{type: :connection_error, message: "timeout"}
      ctx = %{stripe_should_retry: nil, status: nil, headers: [], error: error, method: :get, idempotency_key: nil}
      assert {:retry, delay_ms} = RetryStrategy.Default.retry?(1, ctx)
      assert delay_ms > 0
    end

    test "nil status without connection_error is NOT retriable" do
      ctx = %{stripe_should_retry: nil, status: nil, headers: [], error: nil, method: :get, idempotency_key: nil}
      assert :stop = RetryStrategy.Default.retry?(1, ctx)
    end
  end

  describe "Retry-After header" do
    test "Retry-After header is respected on 429 (returns ~2000ms)" do
      ctx = %{
        stripe_should_retry: nil,
        status: 429,
        headers: [{"retry-after", "2"}],
        error: nil,
        method: :get,
        idempotency_key: nil
      }

      assert {:retry, delay_ms} = RetryStrategy.Default.retry?(1, ctx)
      # Should be 2000ms (2 * 1000), possibly with jitter applied
      # We just verify it's a reasonable range: 1000..2000
      assert delay_ms >= 1000
      assert delay_ms <= 2000
    end

    test "Retry-After header capped at 5000ms" do
      ctx = %{
        stripe_should_retry: nil,
        status: 429,
        headers: [{"retry-after", "60"}],
        error: nil,
        method: :get,
        idempotency_key: nil
      }

      assert {:retry, delay_ms} = RetryStrategy.Default.retry?(1, ctx)
      assert delay_ms <= 5000
    end

    test "Retry-After header not used for non-429 errors" do
      ctx = %{
        stripe_should_retry: nil,
        status: 500,
        headers: [{"retry-after", "2"}],
        error: nil,
        method: :get,
        idempotency_key: nil
      }

      assert {:retry, delay_ms} = RetryStrategy.Default.retry?(1, ctx)
      # 500 uses exponential backoff, not Retry-After
      # Attempt 1: min(500 * 2^0, 5000) = 500, jittered to 250..500
      assert delay_ms >= 250
      assert delay_ms <= 500
    end

    test "Retry-After header is case-insensitive" do
      ctx = %{
        stripe_should_retry: nil,
        status: 429,
        headers: [{"Retry-After", "3"}],
        error: nil,
        method: :get,
        idempotency_key: nil
      }

      assert {:retry, delay_ms} = RetryStrategy.Default.retry?(1, ctx)
      assert delay_ms >= 1500
      assert delay_ms <= 3000
    end
  end

  describe "exponential backoff" do
    test "attempt 1 has lower average delay than attempt 2" do
      ctx_base = %{stripe_should_retry: nil, status: 500, headers: [], error: nil, method: :get, idempotency_key: nil}

      # Run multiple times and check the max of attempt 1 is less than min of attempt 3
      delays_1 = for _ <- 1..50, do: (assert {:retry, d} = RetryStrategy.Default.retry?(1, ctx_base); d)
      delays_3 = for _ <- 1..50, do: (assert {:retry, d} = RetryStrategy.Default.retry?(3, ctx_base); d)

      avg_1 = Enum.sum(delays_1) / length(delays_1)
      avg_3 = Enum.sum(delays_3) / length(delays_3)

      assert avg_1 < avg_3
    end

    test "delay is capped at 5000ms even for high attempt numbers" do
      ctx = %{stripe_should_retry: nil, status: 500, headers: [], error: nil, method: :get, idempotency_key: nil}

      for attempt <- [10, 20, 100] do
        assert {:retry, delay_ms} = RetryStrategy.Default.retry?(attempt, ctx)
        assert delay_ms <= 5000
      end
    end

    test "jitter keeps delay between 50-100% of calculated base value" do
      ctx = %{stripe_should_retry: nil, status: 500, headers: [], error: nil, method: :get, idempotency_key: nil}

      # Attempt 1: base = min(500 * 2^0, 5000) = 500
      # Jitter: 50-100% of 500 = 250..500
      delays = for _ <- 1..100, do: (assert {:retry, d} = RetryStrategy.Default.retry?(1, ctx); d)

      Enum.each(delays, fn delay ->
        assert delay >= 250, "Delay #{delay} below 50% of 500ms base"
        assert delay <= 500, "Delay #{delay} above 100% of 500ms base"
      end)
    end

    test "jitter for attempt 2: delay between 50-100% of 1000ms base" do
      ctx = %{stripe_should_retry: nil, status: 500, headers: [], error: nil, method: :get, idempotency_key: nil}

      # Attempt 2: base = min(500 * 2^1, 5000) = 1000
      # Jitter: 50-100% of 1000 = 500..1000
      delays = for _ <- 1..100, do: (assert {:retry, d} = RetryStrategy.Default.retry?(2, ctx); d)

      Enum.each(delays, fn delay ->
        assert delay >= 500, "Delay #{delay} below 50% of 1000ms base"
        assert delay <= 1000, "Delay #{delay} above 100% of 1000ms base"
      end)
    end

    test "stripe_should_retry: true uses exponential backoff" do
      ctx = %{stripe_should_retry: true, status: 400, headers: [], error: nil, method: :get, idempotency_key: nil}

      delays = for _ <- 1..20, do: (assert {:retry, d} = RetryStrategy.Default.retry?(1, ctx); d)
      Enum.each(delays, fn delay ->
        assert delay >= 250
        assert delay <= 500
      end)
    end
  end
end
