# Circuit Breaker

When Stripe experiences downtime, unprotected clients queue retries and cascade failures
through your application. This guide shows how to add circuit breaker protection using
`:fuse` and LatticeStripe's `RetryStrategy` behaviour — giving you fast-fail semantics
that protect your application while Stripe recovers.

## Why Circuit Breakers

When Stripe goes down or degrades, a naive retry strategy keeps hammering the API. Your
app queues requests, those requests time out, and timeouts cascade through your
supervision tree. Workers back up. Your own users start seeing errors or slow responses
that have nothing to do with their actions.

A circuit breaker solves this by tracking failures. When failures exceed a threshold, the
circuit "opens" and subsequent requests fail immediately — no network call, no timeout
wait. Your users get a fast error instead of waiting 30 seconds to find out Stripe is
unavailable. After a cooldown period, the circuit allows one probe request. If Stripe is
healthy again, the circuit closes and normal operation resumes.

For Stripe integrations specifically, circuit breakers pair naturally with
`LatticeStripe.RetryStrategy`. The retry strategy already controls whether to retry a
request; adding `:fuse` gives it a system-wide state that tracks cumulative health across
all requests, not just the current one.

## How Circuit Breakers Work

A circuit breaker is a state machine with three states:

- **Closed** (normal) — requests flow through. Each failure is recorded. When the failure
  count exceeds the threshold within a configured time window, the circuit transitions to
  Open.
- **Open** — all requests fail immediately with no network call made. After a cooldown
  period, the circuit transitions to Half-Open to probe whether the dependency has
  recovered.
- **Half-Open** — one probe request is allowed through. If it succeeds, the circuit
  returns to Closed. If it fails, the circuit returns to Open and the cooldown resets.

```
  [Closed] --failures exceed threshold--> [Open]
     ^                                       |
     |                                  cooldown expires
     |                                       |
     +----probe succeeds---- [Half-Open] <---+
                              |
                         probe fails --> [Open]
```

The key insight: in the Open state, your application does not wait for a network timeout
to find out Stripe is down. It fails in microseconds, allowing callers to present a
graceful degraded experience instead of hanging.

## Implementation with :fuse

`:fuse` is an Erlang circuit breaker library (MIT license, ~3.2M downloads on Hex.pm). It
implements the state machine above using a single `:fuse` gen_server process that manages
fuse state atomically.

**Why `:fuse` is not bundled with LatticeStripe:** LatticeStripe follows a no-global-state
philosophy — the library does not start OTP processes. `:fuse` starts a gen_server when
installed, which is process state that belongs in your application's supervision tree, not
in the SDK. Add it to your own `mix.exs`:

```elixir
# In your application's mix.exs
{:fuse, "~> 2.5"}
```

The complete `MyApp.FuseRetryStrategy` module:

```elixir
defmodule MyApp.FuseRetryStrategy do
  @moduledoc """
  Circuit breaker retry strategy using :fuse.

  Wraps LatticeStripe's retry logic with :fuse-based circuit breaking.
  When Stripe returns repeated 5xx errors or connection failures, the
  circuit opens and subsequent requests fail fast without hitting Stripe.
  """

  @behaviour LatticeStripe.RetryStrategy

  @fuse_name :stripe_api
  @max_attempts 3
  @base_delay 500
  @max_delay 5_000

  @impl true
  def retry?(attempt, context) do
    # Stripe-Should-Retry header takes highest priority.
    # If Stripe says retry, respect it. If Stripe says don't, stop.
    case Map.get(context, :stripe_should_retry) do
      true -> {:retry, backoff(attempt)}
      false -> :stop
      nil -> check_circuit_and_retry(attempt, context)
    end
  end

  defp check_circuit_and_retry(attempt, context) do
    case :fuse.ask(@fuse_name, :sync) do
      :blown ->
        # Circuit is open — fail fast, no retry
        :stop

      :ok ->
        # Circuit closed (or half-open probe) — apply normal retry logic
        retry_or_stop(attempt, context)
    end
  end

  defp retry_or_stop(attempt, _context) when attempt > @max_attempts, do: :stop

  defp retry_or_stop(attempt, context) do
    case context.status do
      # Idempotency conflicts: never retry
      409 ->
        :stop

      # 429 rate limit: retry and record failure
      429 ->
        :fuse.melt(@fuse_name)
        {:retry, backoff(attempt)}

      # 5xx server errors: retry and record failure
      status when is_integer(status) and status >= 500 ->
        :fuse.melt(@fuse_name)
        {:retry, backoff(attempt)}

      # Connection errors (nil status): retry and record failure
      nil when is_struct(context.error) ->
        :fuse.melt(@fuse_name)
        {:retry, backoff(attempt)}

      # All other statuses: don't retry
      _ ->
        :stop
    end
  end

  defp backoff(attempt) do
    base = min(@base_delay * Integer.pow(2, attempt - 1), @max_delay)
    # 50-100% jitter
    min_val = div(base, 2)
    min_val + :rand.uniform(min_val + 1) - 1
  end
end
```

The `retry?/2` callback checks `stripe_should_retry` first — matching the priority order
of the built-in default retry strategy. Only when Stripe does not send a retry hint does
the circuit breaker state come into play.

## Wiring It Up

Install the fuse in your application's `start/2` callback, before any children that make
Stripe requests:

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    # Install the fuse BEFORE starting workers that make Stripe requests.
    # :fuse manages its own gen_server — it must be running first.
    # Opens after 5 failures within 10 seconds; auto-probes after 30 seconds.
    :fuse.install(:stripe_api, {{:standard, 5, 10_000}, {:reset, 30_000}})

    children = [
      {Finch, name: MyApp.Finch, pools: %{"https://api.stripe.com" => [size: 10]}},
      MyAppWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
end
```

The `:fuse.install/2` parameters:

- `{:standard, 5, 10_000}` — open the circuit after 5 `melt` calls within 10,000ms (10
  seconds). Each `melt` call in `retry_or_stop/2` above counts as one failure.
- `{:reset, 30_000}` — after 30 seconds in the Open state, transition to Half-Open and
  allow one probe request through.

Then create a client with the strategy:

```elixir
client = LatticeStripe.Client.new!(
  api_key: System.fetch_env!("STRIPE_SECRET_KEY"),
  finch: MyApp.Finch,
  retry_strategy: MyApp.FuseRetryStrategy
)
```

## Monitoring

Attach a telemetry handler to log when the circuit state changes. The
`[:lattice_stripe, :request, :stop]` event fires after every request, making it a natural
place to inspect circuit state:

```elixir
defmodule MyApp.CircuitBreakerMonitor do
  require Logger

  def setup do
    :telemetry.attach(
      "myapp-circuit-monitor",
      [:lattice_stripe, :request, :stop],
      &__MODULE__.handle_event/4,
      %{last_state: :ok}
    )
  end

  def handle_event(_event, _measurements, _metadata, _config) do
    case :fuse.ask(:stripe_api, :sync) do
      :blown ->
        Logger.warning("[CircuitBreaker] Stripe circuit is OPEN — requests will fail fast")

      :ok ->
        :ok
    end
  end
end
```

This is a simple example. In production, track state transitions with an Agent or ETS
counter to avoid repeated log messages on every request while the circuit is open.

## Testing

**Unit test with :fuse directly** — install a test fuse with a low threshold and verify
circuit state:

```elixir
test "circuit opens after repeated 500 errors" do
  :fuse.install(:test_stripe, {{:standard, 2, 10_000}, {:reset, 60_000}})

  # Simulate failures
  :fuse.melt(:test_stripe)
  :fuse.melt(:test_stripe)

  assert :blown = :fuse.ask(:test_stripe, :sync)
end
```

**Full integration test** — see `test/integration/circuit_breaker_integration_test.exs`,
which compiles `FuseRetryStrategy` inline and verifies all retry scenarios. Run it with:

```
mix test test/integration/circuit_breaker_integration_test.exs --include fuse_integration
```

The integration test is excluded from the default `mix test` run via `@moduletag
:fuse_integration`.

## Alternatives

If `:fuse` is not right for your project, alternatives exist:

- **`:circuit_breaker`** — Another Erlang circuit breaker library. Less widely used than
  `:fuse`; similar API but smaller community and fewer downloads.
- **ETS counters** — Roll your own with ETS atomic counters. Works, but you must handle
  race conditions, timer-based resets, and half-open probing yourself. `:fuse` implements
  all of this correctly.
- **`GenServer` wrapper** — A GenServer that tracks failure counts. Similar tradeoffs to
  ETS, but introduces a process bottleneck under high concurrency since all failure
  recording serializes through the single process.

## Common Pitfalls

**`:fuse` not installed before first request.** If you forget to call `:fuse.install/2` in
`Application.start/2`, `:fuse.ask/2` returns `{:error, not_found}` instead of `:ok` or
`:blown`. The circuit breaker silently does nothing — the `check_circuit_and_retry/2`
clause only matches `:ok` and `:blown`. Always install the fuse before starting Finch or
any child that makes Stripe requests.

**Calling `:fuse.install/2` per request.** `install/2` should be called once at
application startup. Calling it on every request re-installs the fuse, resetting the
failure counter and defeating the purpose of the circuit breaker entirely.

**Not handling the `{:error, not_found}` return.** If you use a fuse name that has not
been installed, `:fuse.ask/2` returns `{:error, not_found}`. The `MyApp.FuseRetryStrategy`
example matches only on `:ok` and `:blown`. If you change the fuse name, ensure it matches
between `install/2` and `ask/2`. Consider adding a catch-all clause that logs a warning
and falls through to normal retry logic so a misconfigured fuse name does not silently
disable retries.

---

See [Extending LatticeStripe](extending-lattice-stripe.html) for the full `RetryStrategy`
behaviour reference and other extension points.

See [Performance](performance.html) for Finch pool sizing and connection warm-up.

See [Error Handling](error-handling.html) for retry behavior fundamentals.
