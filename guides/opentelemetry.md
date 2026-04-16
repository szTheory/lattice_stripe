# OpenTelemetry

LatticeStripe emits `:telemetry` events for every API request and webhook
verification. This guide shows how to bridge those events to OpenTelemetry spans
so they appear in your distributed tracing backend — with complete examples for
Honeycomb and Datadog.

## Prerequisites

These dependencies are NOT part of LatticeStripe — add them to your own
application's `mix.exs`:

```elixir
# In your application's mix.exs
defp deps do
  [
    {:lattice_stripe, "~> 1.1"},
    # OpenTelemetry — exporter must be listed BEFORE opentelemetry
    {:opentelemetry_exporter, "~> 1.8"},
    {:opentelemetry, "~> 1.5"},
    {:opentelemetry_api, "~> 1.4"},
    # ... other deps
  ]
end
```

> **Important:** `opentelemetry_exporter` must be listed before `opentelemetry`
> in the deps list for correct initialization order.

## The Bridge Handler

The handler below bridges all LatticeStripe telemetry events to OpenTelemetry
spans. Call `setup/0` from your `Application.start/2` to activate it.

```elixir
defmodule MyApp.StripeOtelHandler do
  @moduledoc """
  Bridges LatticeStripe telemetry events to OpenTelemetry spans.

  Call `setup/0` in your Application.start/2 to attach the handler.
  """

  require OpenTelemetry.Tracer, as: Tracer

  @request_events [
    [:lattice_stripe, :request, :start],
    [:lattice_stripe, :request, :stop],
    [:lattice_stripe, :request, :exception]
  ]

  @webhook_events [
    [:lattice_stripe, :webhook, :verify, :start],
    [:lattice_stripe, :webhook, :verify, :stop]
  ]

  def setup do
    :telemetry.attach_many(
      "myapp-stripe-otel",
      @request_events ++ @webhook_events,
      &__MODULE__.handle_event/4,
      %{}
    )
  end

  # --- Request events ---

  def handle_event([:lattice_stripe, :request, :start], _measurements, metadata, _config) do
    Tracer.start_span("stripe.request", %{
      kind: :client,
      attributes: %{
        "http.request.method" => metadata.method |> to_string() |> String.upcase(),
        "url.path" => metadata.path,
        "stripe.resource" => to_string(metadata.resource),
        "stripe.operation" => to_string(metadata.operation)
      }
    })
  end

  def handle_event([:lattice_stripe, :request, :stop], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    attrs = %{
      "http.response.status_code" => metadata[:http_status],
      "stripe.request_id" => metadata[:request_id],
      "stripe.attempts" => metadata[:attempts],
      "stripe.duration_ms" => duration_ms
    }

    # Remove nil values to avoid polluting span attributes
    attrs = Map.reject(attrs, fn {_k, v} -> is_nil(v) end)
    Tracer.set_attributes(attrs)

    case metadata.status do
      :ok -> Tracer.set_status(:ok, "")
      :error -> Tracer.set_status(:error, "Stripe request failed")
    end

    Tracer.end_span()
  end

  def handle_event([:lattice_stripe, :request, :exception], _measurements, metadata, _config) do
    Tracer.record_exception(metadata.reason, metadata.stacktrace)
    Tracer.set_status(:error, "exception")
    Tracer.end_span()
  end

  # --- Webhook events ---

  def handle_event([:lattice_stripe, :webhook, :verify, :start], _measurements, metadata, _config) do
    Tracer.start_span("stripe.webhook.verify", %{kind: :server})

    if path = metadata[:path] do
      Tracer.set_attribute("url.path", path)
    end
  end

  def handle_event([:lattice_stripe, :webhook, :verify, :stop], _measurements, metadata, _config) do
    case metadata.result do
      :ok ->
        Tracer.set_status(:ok, "")

      :error ->
        Tracer.set_attribute(
          "stripe.webhook.error_reason",
          to_string(metadata[:error_reason] || "unknown")
        )
        Tracer.set_status(:error, "webhook verification failed")
    end

    Tracer.end_span()
  end
end
```

> **Span context threading:** `OpenTelemetry.Tracer.start_span/2` stores span
> context in the process dictionary. LatticeStripe uses `:telemetry.span/3`
> internally, which emits `:start` and `:stop` events in the same process.
> This means the span started in the `:start` handler is automatically available
> in the `:stop` handler.

## Wiring the Handler

Call `setup/0` in your `Application.start/2` before starting supervised children:

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    # Attach the OTel bridge before starting workers
    MyApp.StripeOtelHandler.setup()

    children = [
      {Finch, name: MyApp.Finch, pools: %{"https://api.stripe.com" => [size: 10]}},
      MyAppWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
end
```

## Backend Configuration

### Honeycomb

```elixir
# config/runtime.exs
config :opentelemetry_exporter,
  otlp_protocol: :grpc,
  otlp_compression: :gzip,
  otlp_endpoint: "https://api.honeycomb.io:443",
  otlp_headers: [
    {"x-honeycomb-team", System.fetch_env!("HONEYCOMB_API_KEY")},
    {"x-honeycomb-dataset", "myapp-stripe"}
  ]

config :opentelemetry,
  resource: %{service: %{name: "myapp", version: "1.0.0"}}
```

> **Important:** Use `config/runtime.exs` with `System.fetch_env!/1` for API
> keys. Never hardcode secrets in `config/config.exs` — they will be committed
> to git.

### Datadog

Datadog ingests OTLP directly via the Datadog Agent (no API key in config):

```elixir
# config/config.exs (no secrets needed — Agent runs on localhost)
config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: "http://localhost:4318"

config :opentelemetry,
  resource: %{service: %{name: "myapp"}}
```

The Datadog Agent must have OTLP ingestion enabled. In your `datadog.yaml`:

```yaml
otlp_config:
  receiver:
    protocols:
      http:
        endpoint: 0.0.0.0:4318
```

## What You Will See

Once the handler is wired up:

- Each Stripe API request produces a `stripe.request` span with HTTP method,
  path, response status, Stripe request ID, and duration.
- Webhook verifications produce `stripe.webhook.verify` spans with path and
  outcome.
- Failed requests (non-2xx, connection errors) show error status with the Stripe
  error details attached.
- Multiple retry attempts appear as a single span — the telemetry span wraps the
  entire retry loop, so `stripe.attempts` tells you how many attempts were made.

## Common Pitfalls

**Forgetting `require OpenTelemetry.Tracer`.** OTel Tracer functions are macros.
Without `require`, you get an undefined function error at compile time. The
`require OpenTelemetry.Tracer, as: Tracer` line at the top of the module handles
this.

**Using deprecated HTTP attribute names.** Use `http.request.method` and
`http.response.status_code` (stable OTel semantic conventions introduced in
semconv v1.20.0), not the old `http.method` / `http.status_code` which are
deprecated. Backends that enforce semconv validation will reject spans using the
old names.

**Wrong dep declaration scope.** If you are building a library (not an
application), declare OTel deps as `only: :dev` to avoid forcing them on your
users. If you are building an application, omit `:only` so the exporter runs in
production — that is where you need the traces.

---

See [Telemetry](telemetry.html) for the complete list of events and metadata
keys.

See [Performance](performance.html) for Finch pool sizing and production tuning.

See [Circuit Breaker](circuit-breaker.html) for failure protection.
