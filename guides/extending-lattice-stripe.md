# Extending LatticeStripe

LatticeStripe uses Elixir behaviours as extension points for its three main infrastructure
concerns: HTTP transport, JSON encoding/decoding, and retry strategy. You can swap any of these
with your own implementation by passing a module to `Client.new!/1`.

This is particularly useful when you need:
- A different HTTP client (Req, HTTPoison, a test mock)
- A different JSON library (Poison, stdlib JSON in Elixir 1.18+)
- Custom retry logic (circuit breakers, custom backoff curves)

All three behaviours follow the same pattern: implement the callbacks, add `@behaviour` and
`@impl true`, then pass the module to the client.

## Custom Transport

The `LatticeStripe.Transport` behaviour has a single callback:

```elixir
@callback request(request_map()) :: {:ok, response_map()} | {:error, term()}
```

Where:
- `request_map` is `%{method: atom(), url: String.t(), headers: [{String.t(), String.t()}], body: binary() | nil, opts: keyword()}`
- `response_map` is `%{status: integer(), headers: [{String.t(), String.t()}], body: binary()}`

The `body` in the response map must be a **raw binary string** (the JSON response body before
parsing). LatticeStripe handles JSON decoding internally.

### Example: Req Transport

```elixir
defmodule MyApp.ReqTransport do
  @behaviour LatticeStripe.Transport

  @impl true
  def request(%{method: method, url: url, headers: headers, body: body, opts: opts}) do
    timeout = Keyword.get(opts, :timeout, 30_000)

    req_opts = [
      method: method,
      url: url,
      headers: headers,
      body: body,
      receive_timeout: timeout,
      # Disable Req's automatic JSON decoding — LatticeStripe decodes itself
      decode_body: false,
      # Disable Req's automatic retry — LatticeStripe handles retries
      retry: false
    ]

    case Req.request(req_opts) do
      {:ok, %Req.Response{status: status, headers: resp_headers, body: body}} ->
        # Normalize Req headers to [{String.t(), String.t()}] list of 2-tuples
        headers_list = Enum.map(resp_headers, fn {k, v} -> {k, v} end)
        {:ok, %{status: status, headers: headers_list, body: body}}

      {:error, exception} ->
        {:error, exception}
    end
  end
end
```

Use it:

```elixir
client = LatticeStripe.Client.new!(
  api_key: System.fetch_env!("STRIPE_API_KEY"),
  finch: MyApp.Finch,  # still required for default; won't be called
  transport: MyApp.ReqTransport
)
```

### Example: Test Transport (without Mox)

For simple unit tests where you want full control without Mox:

```elixir
defmodule MyApp.StubTransport do
  @behaviour LatticeStripe.Transport

  @impl true
  def request(%{url: url}) do
    cond do
      url =~ "/v1/customers" ->
        {:ok, %{
          status: 200,
          headers: [{"request-id", "req_stub123"}],
          body: Jason.encode!(%{
            "id" => "cus_stub123",
            "object" => "customer",
            "email" => "stub@example.com"
          })
        }}

      true ->
        {:ok, %{
          status: 404,
          headers: [{"request-id", "req_not_found"}],
          body: Jason.encode!(%{
            "error" => %{
              "type" => "invalid_request_error",
              "message" => "No such resource"
            }
          })
        }}
    end
  end
end
```

### Transport Request Map Reference

When your callback receives the request map, these keys are always present:

| Key | Type | Description |
|-----|------|-------------|
| `:method` | `atom` | `:get`, `:post`, or `:delete` |
| `:url` | `String.t()` | Full URL, e.g. `"https://api.stripe.com/v1/customers"` |
| `:headers` | `[{String.t(), String.t()}]` | List of 2-tuple string pairs including Authorization, Stripe-Version, etc. |
| `:body` | `binary() \| nil` | URL-encoded request body for POST, `nil` for GET/DELETE |
| `:opts` | `keyword()` | Contains `:finch` (Finch pool name) and `:timeout` (milliseconds) |

### Transport Response Map Reference

Your callback must return a map with these keys:

| Key | Type | Description |
|-----|------|-------------|
| `:status` | `integer` | HTTP status code |
| `:headers` | `[{String.t(), String.t()}]` | List of 2-tuple string pairs |
| `:body` | `binary()` | **Raw JSON string** — LatticeStripe decodes this internally |

## Custom JSON Codec

The `LatticeStripe.Json` behaviour has four callbacks:

```elixir
@callback encode!(term()) :: binary()
@callback decode!(binary()) :: term()
@callback encode(term()) :: {:ok, binary()} | {:error, Exception.t()}
@callback decode(binary()) :: {:ok, term()} | {:error, Exception.t()}
```

The bang variants must raise on failure. The non-bang variants must return ok/error tuples.
LatticeStripe uses the non-bang variants internally for graceful handling of non-JSON responses
(HTML maintenance pages, empty bodies, etc.).

### Example: Poison Codec

```elixir
defmodule MyApp.PoisonCodec do
  @behaviour LatticeStripe.Json

  @impl true
  def encode!(data), do: Poison.encode!(data)

  @impl true
  def decode!(string), do: Poison.decode!(string)

  @impl true
  def encode(data) do
    {:ok, Poison.encode!(data)}
  rescue
    e -> {:error, e}
  end

  @impl true
  def decode(string) do
    {:ok, Poison.decode!(string)}
  rescue
    e -> {:error, e}
  end
end
```

### Example: Elixir stdlib JSON Codec (Elixir 1.18+)

```elixir
defmodule MyApp.StdlibJsonCodec do
  @behaviour LatticeStripe.Json

  @impl true
  def encode!(data), do: JSON.encode!(data)

  @impl true
  def decode!(string), do: JSON.decode!(string)

  @impl true
  def encode(data) do
    {:ok, JSON.encode!(data)}
  rescue
    e -> {:error, e}
  end

  @impl true
  def decode(string) do
    JSON.decode(string)
  end
end
```

Use it:

```elixir
client = LatticeStripe.Client.new!(
  api_key: System.fetch_env!("STRIPE_API_KEY"),
  finch: MyApp.Finch,
  json_codec: MyApp.PoisonCodec
)
```

### Application-Wide Default

To use a custom codec for all clients in your application without passing it every time, configure
it in your application config:

```elixir
# config/config.exs
config :lattice_stripe, :json_codec, MyApp.PoisonCodec
```

Then `Client.new!/1` will use it as the default (you can still override per-client).

## Custom Retry Strategy

The `LatticeStripe.RetryStrategy` behaviour has one callback:

```elixir
@callback retry?(attempt :: pos_integer(), context()) ::
            {:retry, delay_ms :: non_neg_integer()} | :stop
```

Where `attempt` is the current attempt number (1 = first retry after initial failure) and
`context` is a map with:

| Key | Type | Description |
|-----|------|-------------|
| `:error` | `LatticeStripe.Error.t() \| nil` | The error struct from the failed attempt |
| `:status` | `integer \| nil` | HTTP status code; `nil` for connection errors |
| `:headers` | `[{String.t(), String.t()}]` | Response headers from the failed attempt |
| `:stripe_should_retry` | `boolean \| nil` | Parsed `Stripe-Should-Retry` header; `nil` if absent |
| `:method` | `atom` | HTTP method of the request |
| `:idempotency_key` | `String.t() \| nil` | Idempotency key used in the request |

Return `{:retry, delay_ms}` to retry after `delay_ms` milliseconds, or `:stop` to stop retrying.

### Example: Custom Backoff Strategy

```elixir
defmodule MyApp.AggressiveRetryStrategy do
  @behaviour LatticeStripe.RetryStrategy

  # 5 retries with longer backoff for high-reliability contexts
  @max_attempts 5
  @base_delay_ms 1_000
  @max_delay_ms 30_000

  @impl true
  def retry?(attempt, context) do
    # Respect Stripe-Should-Retry header (highest priority)
    case Map.get(context, :stripe_should_retry) do
      true -> {:retry, backoff(attempt)}
      false -> :stop
      nil -> check_attempt(attempt, context)
    end
  end

  defp check_attempt(attempt, context) when attempt <= @max_attempts do
    case context.status do
      409 -> :stop  # idempotency conflicts are never retriable
      429 -> {:retry, backoff(attempt)}
      status when is_integer(status) and status >= 500 -> {:retry, backoff(attempt)}
      nil -> {:retry, backoff(attempt)}  # connection errors
      _ -> :stop  # 4xx client errors
    end
  end

  defp check_attempt(_attempt, _context), do: :stop

  defp backoff(attempt) do
    base = min(@base_delay_ms * Integer.pow(2, attempt - 1), @max_delay_ms)
    jitter(base)
  end

  defp jitter(base) do
    min_val = div(base, 2)
    range = base - min_val
    min_val + :rand.uniform(range + 1) - 1
  end
end
```

### Example: Circuit Breaker Integration

```elixir
defmodule MyApp.CircuitBreakerRetry do
  @behaviour LatticeStripe.RetryStrategy

  @impl true
  def retry?(attempt, context) do
    if circuit_open?() do
      # Circuit is open — fail fast, don't retry
      :stop
    else
      # Normal retry logic
      case context.status do
        409 -> :stop
        429 -> {:retry, backoff(attempt)}
        status when is_integer(status) and status >= 500 ->
          # Record failure for circuit breaker
          record_failure()
          if attempt <= 3, do: {:retry, backoff(attempt)}, else: :stop
        nil ->
          record_failure()
          if attempt <= 3, do: {:retry, backoff(attempt)}, else: :stop
        _ -> :stop
      end
    end
  end

  defp circuit_open? do
    # Check your circuit breaker state (e.g., Fuse, Elixometer, or a simple ETS counter)
    MyApp.CircuitBreaker.open?(:stripe)
  end

  defp record_failure do
    MyApp.CircuitBreaker.record_failure(:stripe)
  end

  defp backoff(attempt) do
    base = min(500 * Integer.pow(2, attempt - 1), 5_000)
    div(base, 2) + :rand.uniform(div(base, 2) + 1) - 1
  end
end
```

### Example: No Retries

For contexts where you want immediate failure (your caller has its own retry logic):

```elixir
defmodule MyApp.NoRetryStrategy do
  @behaviour LatticeStripe.RetryStrategy

  @impl true
  def retry?(_attempt, _context), do: :stop
end
```

Use it:

```elixir
client = LatticeStripe.Client.new!(
  api_key: System.fetch_env!("STRIPE_API_KEY"),
  finch: MyApp.Finch,
  retry_strategy: MyApp.CircuitBreakerRetry
)
```

## Combining Custom Implementations

All three can be combined:

```elixir
client = LatticeStripe.Client.new!(
  api_key: System.fetch_env!("STRIPE_API_KEY"),
  finch: MyApp.Finch,
  transport: MyApp.ReqTransport,
  json_codec: MyApp.StdlibJsonCodec,
  retry_strategy: MyApp.CircuitBreakerRetry
)
```

## Testing Custom Implementations

Validate your custom implementations against stripe-mock before deploying to production:

```elixir
defmodule MyApp.ReqTransportTest do
  use ExUnit.Case

  setup_all do
    case :gen_tcp.connect(~c"localhost", 12111, [], 1_000) do
      {:ok, socket} -> :gen_tcp.close(socket); :ok
      {:error, _} -> raise "stripe-mock not running"
    end
  end

  test "ReqTransport works with stripe-mock" do
    client = LatticeStripe.Client.new!(
      api_key: "sk_test_123",
      finch: MyApp.Finch,
      transport: MyApp.ReqTransport,
      base_url: "http://localhost:12111"
    )

    assert {:ok, %LatticeStripe.Customer{}} =
      LatticeStripe.Customer.create(client, %{"email" => "test@example.com"})
  end
end
```

## Common Pitfalls

**Transport response body must be a raw binary string**

LatticeStripe decodes JSON internally. If your Transport returns a decoded map as the body,
LatticeStripe will try to JSON-decode a map and crash.

```elixir
# Wrong: body already decoded
{:ok, %{status: 200, headers: [], body: %{"id" => "cus_123"}}}

# Correct: body is raw JSON string
{:ok, %{status: 200, headers: [...], body: "{\"id\":\"cus_123\"}"}}
```

**Transport response headers must be a list of 2-tuples**

```elixir
# Wrong: headers as map
{:ok, %{status: 200, headers: %{"request-id" => "req_123"}, body: "..."}}

# Correct: headers as list of 2-tuples
{:ok, %{status: 200, headers: [{"request-id", "req_123"}], body: "..."}}
```

**JSON codec `encode!/1` and `decode!/1` must raise on failure**

LatticeStripe calls bang variants in contexts where failure means a programming error (not a user
error). If your bang variant silently returns an error tuple, LatticeStripe's error handling will
produce confusing behavior.

**JSON codec non-bang variants must return `{:ok, result}` or `{:error, exception}`**

The non-bang variants are used for graceful handling of non-JSON responses. If your implementation
raises from `decode/1`, a Stripe maintenance page (HTML response) will crash your request instead
of returning a structured `:api_error`.

**RetryStrategy must handle all status codes explicitly**

Pattern-matching only on statuses you know about and using a wildcard fallback is safer than trying
to enumerate every case:

```elixir
# Good pattern: explicit about what retries, fallthrough stops
defp should_retry?(status) when status in [429, 500, 502, 503, 504], do: true
defp should_retry?(_), do: false
```

**RetryStrategy `stripe_should_retry` takes precedence**

When Stripe includes a `Stripe-Should-Retry: true` header, the default strategy retries regardless
of status code. If you implement a custom strategy, you should honor this header too — Stripe uses
it to signal that a specific 500 error is safe to retry.

**Test custom Transport implementations against stripe-mock**

Unit testing a Transport implementation with mocked responses doesn't validate that your request
shape is correct. Use stripe-mock in integration tests — it validates requests against Stripe's
actual OpenAPI spec and will reject malformed requests.
