# Telemetry

LatticeStripe emits [`:telemetry`](https://hexdocs.pm/telemetry) events for all HTTP requests and
webhook signature verification. Attach handlers to these events to integrate with your observability
stack — Prometheus, DataDog, OpenTelemetry, or your own custom logging.

Telemetry events are emitted whether requests succeed or fail, giving you complete visibility into
your Stripe API usage without any extra configuration.

## Quick Start — Default Logger

The fastest way to see Stripe API activity is the built-in default logger:

```elixir
# In your application's start/2 callback:
def start(_type, _args) do
  LatticeStripe.Telemetry.attach_default_logger()

  children = [
    # ...
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

This attaches a handler that logs one line per completed request:

```
[info] POST /v1/customers => 200 in 145ms (1 attempt, req_abc123xyz)
[info] GET /v1/customers/cus_abc => 200 in 42ms (1 attempt, req_def456)
[warning] POST /v1/payment_intents => 429 in 312ms (3 attempts, req_ghi789)
[warning] GET /v1/customers/cus_xyz => :error in 5001ms (3 attempts, no-req-id)
```

You can set a different log level:

```elixir
LatticeStripe.Telemetry.attach_default_logger(level: :debug)
```

`attach_default_logger/1` is idempotent — safe to call multiple times. It detaches any existing
handler with the same ID before attaching.

## Request Events

LatticeStripe emits three lifecycle events per HTTP request, following the `:telemetry.span/3`
convention. The `telemetry_span_context` reference in metadata correlates the start, stop, and
exception events for the same request.

### `[:lattice_stripe, :request, :start]`

Emitted immediately before the HTTP request is dispatched to the transport.

**Measurements:**

| Key | Type | Description |
|-----|------|-------------|
| `:system_time` | `integer` | Wall clock time at span start (native time units). See `System.system_time/0`. |
| `:monotonic_time` | `integer` | Monotonic time at span start. See `System.monotonic_time/0`. |

**Metadata:**

| Key | Type | Description |
|-----|------|-------------|
| `:method` | `atom` | HTTP method: `:get`, `:post`, `:delete` |
| `:path` | `String.t()` | Request path, e.g. `"/v1/customers"` |
| `:resource` | `String.t()` | Parsed resource name, e.g. `"customer"`, `"payment_intent"`, `"checkout.session"` |
| `:operation` | `String.t()` | Parsed operation, e.g. `"create"`, `"retrieve"`, `"list"`, `"confirm"` |
| `:api_version` | `String.t()` | Stripe API version, e.g. `"2026-03-25.dahlia"` |
| `:stripe_account` | `String.t() \| nil` | Connected account ID from Stripe-Account header, or `nil` |
| `:telemetry_span_context` | `reference` | Correlates with stop/exception events |

### `[:lattice_stripe, :request, :stop]`

Emitted after each HTTP request completes — whether it returned a 200 OK, a 402 Card Error, or
a 500 Server Error. All completed requests (including API errors) emit this event.

**Measurements:**

| Key | Type | Description |
|-----|------|-------------|
| `:duration` | `integer` | Elapsed time in **native time units**. Convert with `System.convert_time_unit/3`. |
| `:monotonic_time` | `integer` | Monotonic time at span stop. |

**Metadata (all start fields plus):**

| Key | Type | Description |
|-----|------|-------------|
| `:method` | `atom` | HTTP method |
| `:path` | `String.t()` | Request path |
| `:resource` | `String.t()` | Parsed resource name |
| `:operation` | `String.t()` | Parsed operation |
| `:api_version` | `String.t()` | Stripe API version |
| `:stripe_account` | `String.t() \| nil` | Connected account ID or `nil` |
| `:status` | `:ok \| :error` | Outcome: `:ok` on 2xx, `:error` on 4xx/5xx/connection errors |
| `:http_status` | `integer \| nil` | HTTP status code; `nil` for connection errors |
| `:request_id` | `String.t() \| nil` | Stripe `request-id` header value |
| `:attempts` | `integer` | Total attempts made (1 = no retries, 2 = one retry, etc.) |
| `:retries` | `integer` | Number of retries (`attempts - 1`) |
| `:error_type` | `atom \| nil` | Error type atom on failure (e.g. `:card_error`, `:connection_error`); `nil` on success |
| `:idempotency_key` | `String.t() \| nil` | Idempotency key used (present on failure only) |
| `:telemetry_span_context` | `reference` | Correlates with start event |

### `[:lattice_stripe, :request, :exception]`

Emitted when an **uncaught exception** escapes the request function. This covers transport-level
bugs (e.g., an exception in your custom Transport implementation) — not API errors, which produce
`[:lattice_stripe, :request, :stop]` with `status: :error`.

**Measurements:**

| Key | Type | Description |
|-----|------|-------------|
| `:duration` | `integer` | Elapsed time in native time units |
| `:monotonic_time` | `integer` | Monotonic time at exception |

**Metadata:**

| Key | Type | Description |
|-----|------|-------------|
| `:method` | `atom` | HTTP method |
| `:path` | `String.t()` | Request path |
| `:resource` | `String.t()` | Parsed resource name |
| `:operation` | `String.t()` | Parsed operation |
| `:api_version` | `String.t()` | Stripe API version |
| `:stripe_account` | `String.t() \| nil` | Connected account ID or `nil` |
| `:kind` | `:error \| :exit \| :throw` | Exception kind |
| `:reason` | `any` | Exception reason |
| `:stacktrace` | `list` | Exception stacktrace |
| `:telemetry_span_context` | `reference` | Correlates with start event |

### `[:lattice_stripe, :request, :retry]`

Emitted for each retry attempt, immediately before the backoff delay sleep. Use this to track
retry rates and understand how often you're hitting rate limits or server errors.

**Measurements:**

| Key | Type | Description |
|-----|------|-------------|
| `:attempt` | `integer` | Retry attempt number (1 = first retry after initial failure) |
| `:delay_ms` | `integer` | Delay in milliseconds before the retry |

**Metadata:**

| Key | Type | Description |
|-----|------|-------------|
| `:method` | `atom` | HTTP method |
| `:path` | `String.t()` | Request path |
| `:error_type` | `atom` | Error type that triggered the retry |
| `:status` | `integer \| nil` | HTTP status code (`nil` for connection errors) |

## Webhook Events

Webhook signature verification emits its own telemetry span. These events fire regardless of the
client's `telemetry_enabled` setting — webhook verification is infrastructure-level observability.

### `[:lattice_stripe, :webhook, :verify, :start]`

Emitted before signature verification begins.

**Measurements:**

| Key | Type | Description |
|-----|------|-------------|
| `:system_time` | `integer` | Wall clock time at span start |
| `:monotonic_time` | `integer` | Monotonic time at span start |

**Metadata:**

| Key | Type | Description |
|-----|------|-------------|
| `:path` | `String.t() \| nil` | Request path where the webhook was received, if available |
| `:telemetry_span_context` | `reference` | Correlates with stop/exception events |

### `[:lattice_stripe, :webhook, :verify, :stop]`

Emitted after signature verification completes, whether it succeeded or failed.

**Measurements:**

| Key | Type | Description |
|-----|------|-------------|
| `:duration` | `integer` | Elapsed time in native time units |
| `:monotonic_time` | `integer` | Monotonic time at span stop |

**Metadata:**

| Key | Type | Description |
|-----|------|-------------|
| `:path` | `String.t() \| nil` | Request path where webhook was received |
| `:result` | `:ok \| :error` | Verification outcome |
| `:error_reason` | `atom \| nil` | Failure reason: `:invalid_signature`, `:stale_timestamp`, `:missing_header`, `:no_valid_signature`; or `nil` on success |
| `:telemetry_span_context` | `reference` | Correlates with start event |

### `[:lattice_stripe, :webhook, :verify, :exception]`

Emitted when an uncaught exception escapes webhook verification.

**Measurements:**

| Key | Type | Description |
|-----|------|-------------|
| `:duration` | `integer` | Elapsed time in native time units |
| `:monotonic_time` | `integer` | Monotonic time at exception |

**Metadata:**

| Key | Type | Description |
|-----|------|-------------|
| `:path` | `String.t() \| nil` | Request path |
| `:kind` | `:error \| :exit \| :throw` | Exception kind |
| `:reason` | `any` | Exception reason |
| `:stacktrace` | `list` | Exception stacktrace |
| `:telemetry_span_context` | `reference` | Correlates with start event |

## Custom Telemetry Handlers

Attach handlers to any LatticeStripe event using `:telemetry.attach/4`. Here are common patterns
for integrating with observability stacks.

### Request Latency Histogram

```elixir
:telemetry.attach(
  "myapp-stripe-request-duration",
  [:lattice_stripe, :request, :stop],
  fn _event, measurements, metadata, _config ->
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    MyApp.Metrics.histogram("stripe.request.duration_ms", duration_ms, %{
      resource: metadata.resource,
      operation: metadata.operation,
      http_status: metadata.http_status,
      status: metadata.status
    })
  end,
  nil
)
```

### Retry Rate Counter

```elixir
:telemetry.attach(
  "myapp-stripe-retries",
  [:lattice_stripe, :request, :retry],
  fn _event, measurements, metadata, _config ->
    MyApp.Metrics.increment("stripe.request.retry", %{
      error_type: metadata.error_type,
      attempt: measurements.attempt
    })
  end,
  nil
)
```

### Webhook Verification Monitoring

```elixir
:telemetry.attach(
  "myapp-stripe-webhook-verify",
  [:lattice_stripe, :webhook, :verify, :stop],
  fn _event, _measurements, metadata, _config ->
    case metadata.result do
      :ok ->
        MyApp.Metrics.increment("stripe.webhook.verify.success")

      :error ->
        MyApp.Metrics.increment("stripe.webhook.verify.failure", %{
          reason: metadata.error_reason
        })

        Logger.warning("Stripe webhook verification failed",
          reason: metadata.error_reason,
          path: metadata.path
        )
    end
  end,
  nil
)
```

### Structured Logger

```elixir
:telemetry.attach(
  "myapp-stripe-logger",
  [:lattice_stripe, :request, :stop],
  fn _event, measurements, metadata, %{level: level} ->
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    Logger.log(level, "Stripe API request completed",
      method: metadata.method,
      path: metadata.path,
      resource: metadata.resource,
      operation: metadata.operation,
      http_status: metadata.http_status,
      duration_ms: duration_ms,
      attempts: metadata.attempts,
      request_id: metadata.request_id
    )
  end,
  %{level: :info}
)
```

## Integration with Telemetry.Metrics

If you're using [`telemetry_metrics`](https://hexdocs.pm/telemetry_metrics) with Prometheus,
StatsD, or similar, here are ready-to-use metric definitions:

```elixir
# In your Telemetry supervisor's metrics/0 function:
def metrics do
  [
    # Request latency by resource and operation
    Telemetry.Metrics.summary("lattice_stripe.request.stop.duration",
      tags: [:resource, :operation, :status],
      unit: {:native, :millisecond}
    ),

    # Request throughput by outcome
    Telemetry.Metrics.counter("lattice_stripe.request.stop",
      tags: [:resource, :operation, :status]
    ),

    # Latency distribution for percentiles (p50/p95/p99)
    Telemetry.Metrics.distribution("lattice_stripe.request.stop.duration",
      tags: [:resource, :operation, :http_status],
      unit: {:native, :millisecond},
      reporter_options: [buckets: [10, 50, 100, 250, 500, 1000, 5000]]
    ),

    # Retry rate by error type
    Telemetry.Metrics.counter("lattice_stripe.request.retry",
      tags: [:error_type]
    ),

    # Webhook verification outcomes
    Telemetry.Metrics.counter("lattice_stripe.webhook.verify.stop",
      tags: [:result, :error_reason]
    )
  ]
end
```

## Disabling Telemetry

To disable request telemetry for a specific client (useful in tests or batch processes where
telemetry noise is unwanted):

```elixir
client = LatticeStripe.Client.new!(
  api_key: System.fetch_env!("STRIPE_API_KEY"),
  finch: MyApp.Finch,
  telemetry_enabled: false
)
```

Note: **Webhook telemetry always fires regardless of `telemetry_enabled`**. The webhook
verification span is infrastructure-level observability — it fires whether or not the client
used to construct the call had telemetry enabled.

## Converting Duration Measurements

The `:duration` measurement in stop and exception events is in **Erlang native time units**, not
milliseconds. Always convert before using in metrics or logs:

```elixir
# Convert to milliseconds
duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

# Convert to microseconds (for high-precision logging)
duration_us = System.convert_time_unit(measurements.duration, :native, :microsecond)

# Convert to seconds (for summary statistics)
duration_s = System.convert_time_unit(measurements.duration, :native, :second)
```

The `Telemetry.Metrics` library handles this automatically via the `unit: {:native, :millisecond}`
option — you don't need to convert manually when using `telemetry_metrics`.

## Common Pitfalls

**Duration is in native time units, not milliseconds**

Logging `measurements.duration` directly will produce a very large integer with no obvious unit.
Always use `System.convert_time_unit/3` to convert before displaying or storing it.

**Don't do slow work in telemetry handlers**

Telemetry handlers are called synchronously in the requesting process. A slow handler (database
writes, synchronous HTTP calls) will block every Stripe API call:

```elixir
# Bad: slow synchronous work in the handler
fn _event, measurements, metadata, _config ->
  SlowDatabase.insert_metrics(metadata)  # blocks every request
end

# Good: send to a fast async process
fn _event, measurements, metadata, _config ->
  MyApp.MetricsWorker.cast({:record, measurements, metadata})  # non-blocking
end
```

**`attach_default_logger/1` is idempotent**

It's safe to call from `application.ex` and from library code — it detaches the previous handler
before attaching the new one. Calling it twice won't cause duplicate log lines.

**Webhook telemetry fires regardless of `telemetry_enabled: false`**

Setting `telemetry_enabled: false` on a client only affects request telemetry. Webhook
verification events always fire. This is intentional — webhook security events should always
be observable.

**Use `attach_many/4` for attaching to multiple events at once**

If you want to handle start, stop, and exception with the same handler, use
`:telemetry.attach_many/4`:

```elixir
:telemetry.attach_many(
  "myapp-stripe-all",
  [
    [:lattice_stripe, :request, :start],
    [:lattice_stripe, :request, :stop],
    [:lattice_stripe, :request, :exception]
  ],
  &MyApp.StripeHandler.handle_event/4,
  nil
)
```
