defmodule LatticeStripe.CircuitBreakerIntegrationTest do
  @moduledoc """
  Integration test verifying the circuit breaker guide's code examples.

  Run with: mix test test/integration/circuit_breaker_integration_test.exs --include fuse_integration
  Excluded from default `mix test` runs.
  """
  use ExUnit.Case, async: false

  @moduletag :fuse_integration

  # Define the guide's MyApp.FuseRetryStrategy inline for compilation verification
  defmodule FuseRetryStrategy do
    @behaviour LatticeStripe.RetryStrategy

    @fuse_name :test_stripe_api
    @max_attempts 3
    @base_delay 500
    @max_delay 5_000

    @impl true
    def retry?(attempt, context) do
      case Map.get(context, :stripe_should_retry) do
        true -> {:retry, backoff(attempt)}
        false -> :stop
        nil -> check_circuit_and_retry(attempt, context)
      end
    end

    defp check_circuit_and_retry(attempt, context) do
      case :fuse.ask(@fuse_name, :sync) do
        :blown -> :stop
        :ok -> retry_or_stop(attempt, context)
      end
    end

    defp retry_or_stop(attempt, _context) when attempt > @max_attempts, do: :stop

    defp retry_or_stop(attempt, context) do
      case context.status do
        409 ->
          :stop

        429 ->
          :fuse.melt(@fuse_name)
          {:retry, backoff(attempt)}

        status when is_integer(status) and status >= 500 ->
          :fuse.melt(@fuse_name)
          {:retry, backoff(attempt)}

        nil when is_struct(context.error) ->
          :fuse.melt(@fuse_name)
          {:retry, backoff(attempt)}

        _ ->
          :stop
      end
    end

    defp backoff(attempt) do
      base = min(@base_delay * Integer.pow(2, attempt - 1), @max_delay)
      min_val = div(base, 2)
      min_val + :rand.uniform(min_val + 1) - 1
    end
  end

  setup do
    # Install a fresh fuse for each test with a low threshold.
    # {:standard, 1, 10_000} opens the circuit after 2 melt calls (threshold + 1).
    :fuse.install(:test_stripe_api, {{:standard, 1, 10_000}, {:reset, 60_000}})
    :ok
  end

  test "FuseRetryStrategy compiles and implements RetryStrategy behaviour" do
    assert function_exported?(FuseRetryStrategy, :retry?, 2)
  end

  test "returns {:retry, delay} on 500 when circuit is closed" do
    context = %{
      error: nil,
      status: 500,
      headers: [],
      stripe_should_retry: nil,
      method: :get,
      idempotency_key: nil
    }

    assert {:retry, _delay} = FuseRetryStrategy.retry?(1, context)
  end

  test "returns :stop when circuit is open (blown)" do
    # Melt twice to open circuit (threshold is 2)
    :fuse.melt(:test_stripe_api)
    :fuse.melt(:test_stripe_api)

    assert :blown = :fuse.ask(:test_stripe_api, :sync)

    context = %{
      error: nil,
      status: 500,
      headers: [],
      stripe_should_retry: nil,
      method: :get,
      idempotency_key: nil
    }

    assert :stop = FuseRetryStrategy.retry?(1, context)
  end

  test "respects stripe_should_retry: true even when circuit is open" do
    :fuse.melt(:test_stripe_api)
    :fuse.melt(:test_stripe_api)

    context = %{
      error: nil,
      status: 500,
      headers: [],
      stripe_should_retry: true,
      method: :get,
      idempotency_key: nil
    }

    assert {:retry, _delay} = FuseRetryStrategy.retry?(1, context)
  end

  test "respects stripe_should_retry: false even when circuit is closed" do
    context = %{
      error: nil,
      status: 500,
      headers: [],
      stripe_should_retry: false,
      method: :get,
      idempotency_key: nil
    }

    assert :stop = FuseRetryStrategy.retry?(1, context)
  end

  test "returns :stop on 409 idempotency conflict" do
    context = %{
      error: nil,
      status: 409,
      headers: [],
      stripe_should_retry: nil,
      method: :post,
      idempotency_key: "key-123"
    }

    assert :stop = FuseRetryStrategy.retry?(1, context)
  end

  test "returns :stop when max attempts exceeded" do
    context = %{
      error: nil,
      status: 500,
      headers: [],
      stripe_should_retry: nil,
      method: :get,
      idempotency_key: nil
    }

    assert :stop = FuseRetryStrategy.retry?(4, context)
  end
end
