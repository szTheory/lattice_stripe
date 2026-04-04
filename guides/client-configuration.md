# Client Configuration

LatticeStripe is configured through a plain `%LatticeStripe.Client{}` struct — no global
state, no application environment magic, no process-based config. You create a client once
with `Client.new!/1` and pass it explicitly to every API call.

This approach means:
- Different parts of your app can use different configurations simultaneously
- Testing is straightforward — pass a test-configured client, no global state to restore
- Behavior is always explicit and predictable

## Required Options

Every client requires exactly two options:

```elixir
client = LatticeStripe.Client.new!(
  api_key: "sk_test_YOUR_STRIPE_TEST_KEY",
  finch: MyApp.Finch
)
```

- **`api_key`** — Your Stripe secret key. Use `sk_test_...` in development and `sk_live_...`
  in production. Both are valid at `Client.new!` time — the key is validated for presence
  and format but not verified against Stripe's servers until you make an actual request.

- **`finch`** — The name atom of a running Finch pool in your supervision tree. See
  [Getting Started](getting-started.html#setting-up-finch) for how to configure Finch.
  Passing a name that has no pool will produce a runtime error on the first request.

`Client.new!` raises `NimbleOptions.ValidationError` if any required option is missing or
any option has the wrong type. This catches misconfiguration at startup, not buried in a
production request.

If you prefer a non-raising variant:

```elixir
case LatticeStripe.Client.new(api_key: "sk_test_...", finch: MyApp.Finch) do
  {:ok, client} -> client
  {:error, error} -> raise "Invalid Stripe client config: #{Exception.message(error)}"
end
```

## Optional Settings

All optional settings have sensible defaults chosen to match Stripe's own SDK conventions.

### `base_url`

The Stripe API base URL. Default: `"https://api.stripe.com"`.

Override this to point at stripe-mock in tests or a staging environment:

```elixir
# Integration tests against stripe-mock
test_client = LatticeStripe.Client.new!(
  api_key: "sk_test_123",
  finch: MyApp.Finch,
  base_url: "http://localhost:12111"
)
```

### `api_version`

The Stripe API version sent in the `Stripe-Version` header. Default: `"2026-03-25.dahlia"`.

LatticeStripe pins to a specific Stripe API version per library release. You normally
shouldn't change this, but you can override it for testing or if you've manually upgraded
your Stripe account's version:

```elixir
client = LatticeStripe.Client.new!(
  api_key: "sk_test_...",
  finch: MyApp.Finch,
  api_version: "2025-01-27.acacia"
)
```

You can also override per-request using the `:stripe_version` option (see below).

### `max_retries`

Maximum number of retry attempts after the initial request fails. Default: `2` (3 total
attempts — 1 initial + 2 retries).

LatticeStripe automatically retries on transient errors: network timeouts, 429 Too Many
Requests, and 5xx server errors. It respects Stripe's `Stripe-Should-Retry` header when
present. Retries use exponential backoff with jitter.

```elixir
client = LatticeStripe.Client.new!(
  api_key: "sk_test_...",
  finch: MyApp.Finch,
  max_retries: 3  # 4 total attempts
)
```

Set `max_retries: 0` to disable retries entirely.

### `retry_strategy`

A module implementing the `LatticeStripe.RetryStrategy` behaviour. Default:
`LatticeStripe.RetryStrategy.Default`.

Use this to customize retry behavior — for example, to always retry, never retry, or
implement custom backoff logic:

```elixir
defmodule MyApp.NoRetry do
  @behaviour LatticeStripe.RetryStrategy

  @impl true
  def retry?(_attempt, _context), do: :stop
end

client = LatticeStripe.Client.new!(
  api_key: "sk_test_...",
  finch: MyApp.Finch,
  retry_strategy: MyApp.NoRetry
)
```

### `timeout`

Request timeout in milliseconds. Default: `30_000` (30 seconds).

This applies to each individual request attempt (not the total time across retries):

```elixir
client = LatticeStripe.Client.new!(
  api_key: "sk_test_...",
  finch: MyApp.Finch,
  timeout: 60_000  # 60 seconds for long-running operations
)
```

### `telemetry_enabled`

Whether to emit telemetry events for request lifecycle. Default: `true`.

LatticeStripe emits `[:lattice_stripe, :request, :start | :stop | :exception]` events and
`[:lattice_stripe, :request, :retry]` events for retries. These are compatible with any
`:telemetry` consumer (Prometheus, DataDog, OpenTelemetry).

Set `telemetry_enabled: false` to suppress all telemetry events from this client:

```elixir
# In tests, you may want to suppress telemetry noise
test_client = LatticeStripe.Client.new!(
  api_key: "sk_test_...",
  finch: MyApp.Finch,
  telemetry_enabled: false
)
```

### `stripe_account`

A Stripe Connect account ID (e.g., `"acct_1234567890"`). Default: `nil`.

Used for Stripe Connect platforms that perform operations on behalf of connected accounts.
When set, LatticeStripe sends the `Stripe-Account` header with every request from this
client. See [Stripe Connect](#stripe-connect) below.

## Per-Request Overrides

You can override client defaults for a single request by passing keyword options as the
last argument to any API function:

```elixir
LatticeStripe.Customer.create(client, params,
  idempotency_key: "create-customer-#{user_id}",
  stripe_account: "acct_1ABCconnected",
  timeout: 60_000,
  expand: ["default_source"]
)
```

Available per-request options:

| Option | Type | Description |
|--------|------|-------------|
| `idempotency_key` | `string` | Custom idempotency key. Auto-generated for POST if not set. |
| `stripe_account` | `string` | Connected account ID. Overrides client's `stripe_account`. |
| `stripe_version` | `string` | API version for this request only. |
| `api_key` | `string` | API key for this request only. Useful for Connect platforms. |
| `timeout` | `integer` | Timeout in ms for this request only. |
| `expand` | `[string]` | List of fields to expand (e.g., `["customer", "payment_method"]`). |
| `max_retries` | `integer` | Max retries for this request only. |

Per-request options **override** (not merge with) client defaults. For example, setting
`stripe_account: "acct_123"` in opts uses that account; the client's `stripe_account` is
ignored for that call.

### Idempotency Keys

LatticeStripe automatically generates an idempotency key for every POST request using a
UUID v4 with an `idk_ltc_` prefix. This makes retries safe — if a retry hits the same
endpoint with the same key, Stripe returns the cached response rather than processing twice.

For operations you want to control explicitly — like "create this specific order" — supply
your own key:

```elixir
LatticeStripe.PaymentIntent.create(client, params,
  idempotency_key: "payment-intent-for-order-#{order_id}"
)
```

Your key must be unique per distinct operation. Don't reuse the same key with different
parameters — Stripe will return the original response (for that key's operation), not the
new one.

## Multiple Clients

Create as many clients as you need. They're plain structs — there's no per-client process
or pool. The Finch connection pool is shared:

```elixir
# Live production client
live_client = LatticeStripe.Client.new!(
  api_key: System.fetch_env!("STRIPE_LIVE_KEY"),
  finch: MyApp.Finch
)

# Test mode client for sandboxing
test_client = LatticeStripe.Client.new!(
  api_key: System.fetch_env!("STRIPE_TEST_KEY"),
  finch: MyApp.Finch
)

# Client with faster timeout for non-critical background jobs
fast_client = LatticeStripe.Client.new!(
  api_key: System.fetch_env!("STRIPE_TEST_KEY"),
  finch: MyApp.Finch,
  timeout: 5_000,
  max_retries: 0
)
```

## Stripe Connect

[Stripe Connect](https://docs.stripe.com/connect) lets you build platforms where you
create charges and manage payments on behalf of connected seller accounts.

There are two ways to configure a connected account:

### Client-level (all requests from this client use the account)

```elixir
connected_client = LatticeStripe.Client.new!(
  api_key: "sk_live_platform_key",
  finch: MyApp.Finch,
  stripe_account: "acct_1ABCconnected"
)

# All calls use acct_1ABCconnected
{:ok, customer} = LatticeStripe.Customer.create(connected_client, %{"email" => "seller@example.com"})
{:ok, payment} = LatticeStripe.PaymentIntent.create(connected_client, %{"amount" => 5000, "currency" => "usd"})
```

### Per-request (useful when managing many accounts from one client)

```elixir
platform_client = LatticeStripe.Client.new!(
  api_key: "sk_live_platform_key",
  finch: MyApp.Finch
)

# Route specific calls to specific connected accounts
{:ok, balance} = LatticeStripe.Customer.list(platform_client, %{},
  stripe_account: "acct_1ABCconnected"
)
```

For more on Connect patterns, see [Stripe's Connect docs](https://docs.stripe.com/connect).

## Common Pitfalls

**Client is a struct, not a process.**
You don't `start_link` a client or add it to your supervision tree. Just call `Client.new!`
and pass the returned struct to API functions. There's no state to clean up.

**`api_key` is validated at `Client.new!` time.**
If you pass a malformed key (wrong prefix, wrong format), you'll get a
`NimbleOptions.ValidationError` immediately. This is intentional — catch typos at startup,
not in the middle of a payment flow.

**Per-request opts override client defaults, not merge.**
Setting `stripe_account: nil` in per-request opts doesn't "unset" the client's
`stripe_account`. It explicitly passes `nil` as the account. If you want to use the
client's default, simply omit that opt.

**Don't put the API key in source control.**
Load it from environment variables or a secrets manager:

```elixir
client = LatticeStripe.Client.new!(
  api_key: System.fetch_env!("STRIPE_SECRET_KEY"),
  finch: MyApp.Finch
)
```

`System.fetch_env!/1` raises at startup if the variable isn't set, which is better than
silently using the wrong key in production.
