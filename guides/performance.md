# Performance

LatticeStripe is designed for production Stripe integrations. This guide covers
Finch pool sizing, per-operation timeouts, connection warm-up, and benchmarking
to help you tune performance for your workload.

## Pool Sizing

Stripe uses HTTP/1.1. In Finch, each pool worker holds one persistent TCP connection
to Stripe. Two parameters control throughput:

- **`size`** — concurrent connections per pool (queue depth per worker)
- **`count`** — number of parallel pools (worker processes)

```
Max concurrent Stripe requests = size * count
```

Choose a pool config that matches your traffic profile. These are starting points —
observe actual saturation with `Finch.get_pool_status/2` before tuning further.

**Conservative** — early-stage SaaS, fewer than 100 Stripe requests per second,
10 concurrent connections:

```elixir
{Finch,
 name: MyApp.Finch,
 pools: %{
   "https://api.stripe.com" => [
     size: 10,
     count: 1
   ]
 }}
```

**Standard production** — moderate traffic, 100–500 Stripe requests per second,
50 concurrent connections:

```elixir
{Finch,
 name: MyApp.Finch,
 pools: %{
   "https://api.stripe.com" => [
     size: 25,
     count: 2
   ]
 }}
```

**High-throughput** — more than 500 Stripe requests per second, webhook processing
pipelines, or batch operations, 200 concurrent connections:

```elixir
{Finch,
 name: MyApp.Finch,
 pools: %{
   "https://api.stripe.com" => [
     size: 50,
     count: 4
   ]
 }}
```

These configs scope the pool to `"https://api.stripe.com"` only. Traffic to other
hosts uses Finch's default pool. If you call both the live and mock Stripe APIs
(e.g., in integration tests), add a separate entry for each base URL.

## Supervision Tree

A complete `Application.start/2` example with production pool sizing and connection
warm-up:

```elixir
defmodule MyApp.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      {Finch,
       name: MyApp.Finch,
       pools: %{
         "https://api.stripe.com" => [size: 25, count: 2]
       }},
      MyApp.Repo,
      MyAppWeb.Endpoint
    ]

    {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)

    # Pre-warm Stripe connections to eliminate first-request TLS latency.
    # warm_up/1 is called after the supervisor starts so Finch is running.
    client = LatticeStripe.Client.new!(
      api_key: System.fetch_env!("STRIPE_SECRET_KEY"),
      finch: MyApp.Finch
    )

    case LatticeStripe.warm_up(client) do
      {:ok, :warmed} ->
        :ok

      {:error, reason} ->
        # Log but do not crash — warm-up failure is not fatal.
        # The first real request will establish the connection.
        Logger.warning("Stripe connection warm-up failed: #{inspect(reason)}")
    end

    {:ok, sup}
  end
end
```

Key points:

- Finch must be started before calling `warm_up/1`
- Create the client after Finch starts (client struct is plain data; no process required)
- Warm-up failure should not crash your application; log and continue

## Per-Operation Timeouts

LatticeStripe resolves the effective timeout for each request using a three-tier
precedence chain:

1. **Per-request `opts[:timeout]`** — highest priority, overrides everything
2. **`client.operation_timeouts[op_type]`** — middle tier, matched by operation type
3. **`client.timeout`** — fallback, 30 seconds by default

The middle tier is opt-in. When `operation_timeouts` is `nil` (the default), all
operations use `client.timeout` — zero behavior change for existing callers.

**Configure operation-specific timeouts:**

```elixir
client = LatticeStripe.Client.new!(
  api_key: System.fetch_env!("STRIPE_SECRET_KEY"),
  finch: MyApp.Finch,
  operation_timeouts: %{list: 60_000, search: 45_000}
)
```

Valid keys are `:list`, `:search`, `:create`, `:retrieve`, `:update`, `:delete`.
Operations not in the map fall back to `client.timeout`.

**Recommended values for production workloads:**

| Operation   | Default (ms) | Recommended for heavy workloads |
|-------------|-------------|--------------------------------|
| `:list`     | 30_000      | 60_000                         |
| `:search`   | 30_000      | 45_000                         |
| `:create`   | 30_000      | 15_000                         |
| `:retrieve` | 30_000      | 10_000                         |
| `:update`   | 30_000      | 15_000                         |
| `:delete`   | 30_000      | 15_000                         |

List and search endpoints scan large datasets and are inherently slower. Create,
retrieve, update, and delete operations should complete quickly; a tight timeout
surfaces latency problems early.

**Full configuration example:**

```elixir
client = LatticeStripe.Client.new!(
  api_key: System.fetch_env!("STRIPE_SECRET_KEY"),
  finch: MyApp.Finch,
  operation_timeouts: %{
    list: 60_000,
    search: 45_000,
    create: 15_000,
    retrieve: 10_000,
    update: 15_000,
    delete: 15_000
  }
)
```

You can still override any individual request with the per-request `timeout` opt:

```elixir
# This per-request timeout takes precedence over operation_timeouts
LatticeStripe.Customer.list(client, %{limit: 100}, timeout: 90_000)
```

See [Client Configuration](client-configuration.html) for the full list of
client options.

## Connection Warm-Up

A "warm" connection has completed the TLS handshake and established the HTTP
connection to Stripe's servers. Warm connections skip the handshake on subsequent
requests, saving roughly 100–300 ms of latency on the first real API call after
a deploy or restart.

Call `LatticeStripe.warm_up/1` in `Application.start/2` to pre-establish the
connection before your first real request arrives:

```elixir
case LatticeStripe.warm_up(client) do
  {:ok, :warmed} -> :ok
  {:error, reason} ->
    require Logger
    Logger.warning("Stripe warm-up failed: #{inspect(reason)}")
end
```

Internally, `warm_up/1` sends `GET /v1/` through the configured transport. This
is a lightweight request with no side effects. Stripe returns a 404, but the
response body is irrelevant — the TLS handshake and HTTP connection are what
matter. `warm_up/1` returns `{:ok, :warmed}` for any HTTP response; only
transport-level failures (network unreachable, timeout) return `{:error, reason}`.

**Return values:**

- `{:ok, :warmed}` — connection established (Stripe's 404 response is expected and fine)
- `{:error, reason}` — transport failure (network unreachable, connection refused, timeout)

**Bang variant for strict startup:**

Use `warm_up!/1` when you want warm-up failure to crash the application rather
than continue with an unwarmed connection:

```elixir
# Raises RuntimeError if the transport connection fails
:warmed = LatticeStripe.warm_up!(client)
```

This is appropriate in environments where a failed Stripe connection at startup
means the application cannot serve its core function.

See [Client Configuration](client-configuration.html) for the full supervision
tree setup including Finch configuration.

## Benchmarking

Enable pool metrics by adding `start_pool_metrics?: true` to your Finch pool
configuration at startup:

```elixir
{Finch,
 name: MyApp.Finch,
 pools: %{
   "https://api.stripe.com" => [
     size: 25,
     count: 2,
     start_pool_metrics?: true
   ]
 }}
```

Query pool utilization at runtime with `Finch.get_pool_status/2`:

```elixir
{:ok, metrics} = Finch.get_pool_status(MyApp.Finch, "https://api.stripe.com")

Enum.each(metrics, fn m ->
  IO.puts("Pool #{m.pool_index}: #{m.in_use_connections}/#{m.pool_size} connections in use")
end)
```

If `in_use_connections` is consistently at or near `pool_size`, the pool is
saturated. Either increase `size` (more connections per pool) or `count` (more
parallel pools) before adding more application instances.

For request-level timing (duration, retry counts, status codes), see the
[Telemetry](telemetry.html) guide. Telemetry events give you per-request
visibility that complements the pool-level metrics from `Finch.get_pool_status/2`.

## Common Pitfalls

**Single-pool bottleneck.** Using the default Finch configuration (no `pools:`
key) assigns all traffic to a small default pool. Always configure an explicit
pool scoped to `"https://api.stripe.com"` for production Stripe traffic.

**Not warming up.** The first Stripe request after a deploy or restart pays the
TLS handshake cost — roughly 100–300 ms of extra latency. Call `warm_up/1` in
`Application.start/2` to pre-establish the connection before traffic arrives.

**Overly aggressive timeouts on list and search.** Stripe list endpoints scan
large datasets. Setting a short global `timeout` (for example, `timeout: 5_000`)
will cause failures when listing large collections. Use `operation_timeouts` to
give `:list` and `:search` more room while keeping `:create` and `:retrieve` tight.

**Ignoring pool saturation.** Monitor with `Finch.get_pool_status/2`. When
connections are consistently saturated, increase `size` or `count`. Adding more
application instances without fixing pool saturation moves the bottleneck rather
than resolving it.
