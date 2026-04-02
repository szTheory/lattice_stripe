defmodule LatticeStripe.RetryStrategy do
  @moduledoc """
  Behaviour for controlling retry logic on failed Stripe API requests.

  Implement this behaviour to customize retry decisions. The default
  implementation (`LatticeStripe.RetryStrategy.Default`) follows Stripe's
  official SDK retry conventions.

  ## Example

      defmodule MyApp.RetryStrategy do
        @behaviour LatticeStripe.RetryStrategy

        @impl true
        def retry?(attempt, context) do
          if attempt <= 5 and context.status in [429, 500, 502, 503] do
            {:retry, attempt * 1000}
          else
            :stop
          end
        end
      end
  """

  @type context :: %{
          error: LatticeStripe.Error.t() | nil,
          status: pos_integer() | nil,
          headers: [{String.t(), String.t()}],
          stripe_should_retry: boolean() | nil,
          method: atom(),
          idempotency_key: String.t() | nil
        }

  @callback retry?(attempt :: pos_integer(), context()) ::
                {:retry, delay_ms :: non_neg_integer()} | :stop
end

defmodule LatticeStripe.RetryStrategy.Default do
  @moduledoc """
  Default retry strategy following Stripe SDK conventions.

  Behavior:
  - `Stripe-Should-Retry: true` header forces retry regardless of status
  - `Stripe-Should-Retry: false` header forces stop regardless of status
  - Without header: retry on 429, 500+, and connection errors; stop on other 4xx
  - 409 (idempotency conflict) is never retried
  - `Retry-After` header respected on 429, capped at 5 seconds
  - Exponential backoff: `min(500 * 2^(attempt-1), 5000)` with 50-100% jitter
  """

  @behaviour LatticeStripe.RetryStrategy

  @base_delay 500
  @max_delay 5_000
  @max_retry_after 5_000

  @impl true
  def retry?(attempt, context) do
    # stripe_should_retry is pre-parsed from the Stripe-Should-Retry response header.
    # It takes precedence over all other signals per D-09.
    stripe_should_retry = Map.get(context, :stripe_should_retry)

    cond do
      stripe_should_retry == true ->
        {:retry, backoff_delay(attempt)}

      stripe_should_retry == false ->
        :stop

      # 409 idempotency conflict is never retriable (D-12)
      context.status == 409 ->
        :stop

      # Connection errors (nil status with connection_error type) are retriable (D-11)
      is_nil(context.status) and is_connection_error?(context.error) ->
        {:retry, backoff_delay(attempt)}

      # nil status without connection_error: not retriable
      is_nil(context.status) ->
        :stop

      # 429: respect Retry-After header if present, otherwise backoff
      context.status == 429 ->
        delay = retry_after_delay(context.headers) || backoff_delay(attempt)
        {:retry, delay}

      # 500+: exponential backoff
      context.status >= 500 ->
        {:retry, backoff_delay(attempt)}

      # All other statuses (4xx, etc.): not retriable
      true ->
        :stop
    end
  end

  # Compute exponential backoff with 50-100% jitter.
  # Formula: min(500 * 2^(attempt-1), 5000) jittered to 50-100% of value.
  defp backoff_delay(attempt) do
    base = min(@base_delay * Integer.pow(2, attempt - 1), @max_delay)
    jitter(base)
  end

  # Apply 50-100% jitter to the base value.
  defp jitter(base) do
    min_val = div(base, 2)
    range = base - min_val
    min_val + :rand.uniform(range + 1) - 1
  end

  # Parse Retry-After header value (seconds) into milliseconds, capped at @max_retry_after.
  # Returns nil if header is absent or non-integer.
  defp retry_after_delay(headers) do
    case find_header(headers, "retry-after") do
      nil ->
        nil

      value ->
        case Integer.parse(value) do
          {seconds, _} -> min(seconds * 1000, @max_retry_after)
          :error -> nil
        end
    end
  end

  # Find a header value by lowercase name (case-insensitive).
  defp find_header(headers, name) do
    Enum.find_value(headers, fn {k, v} ->
      if String.downcase(k) == name, do: v
    end)
  end

  # Check if an error struct represents a connection-level failure.
  defp is_connection_error?(%LatticeStripe.Error{type: :connection_error}), do: true
  defp is_connection_error?(_), do: false
end
