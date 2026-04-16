defmodule LatticeStripe.OpenTelemetryIntegrationTest do
  @moduledoc """
  Integration test verifying the OpenTelemetry guide's code examples.

  Run with: mix test test/integration/opentelemetry_integration_test.exs --include otel_integration
  Excluded from default `mix test` runs.
  """
  use ExUnit.Case, async: false

  @moduletag :otel_integration

  # Define the guide's handler inline for compilation verification
  defmodule StripeOtelHandler do
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
        "test-stripe-otel",
        @request_events ++ @webhook_events,
        &__MODULE__.handle_event/4,
        %{}
      )
    end

    def teardown do
      :telemetry.detach("test-stripe-otel")
    end

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

  setup do
    StripeOtelHandler.setup()
    on_exit(fn -> StripeOtelHandler.teardown() end)
    :ok
  end

  test "StripeOtelHandler compiles and implements handle_event/4" do
    assert function_exported?(StripeOtelHandler, :handle_event, 4)
    assert function_exported?(StripeOtelHandler, :setup, 0)
  end

  test "handler processes :start event without crashing" do
    metadata = %{
      method: :get,
      path: "/v1/customers/cus_123",
      resource: :customer,
      operation: :retrieve,
      api_version: "2024-06-20",
      stripe_account: nil,
      telemetry_span_context: make_ref()
    }

    # Should not raise
    :telemetry.execute(
      [:lattice_stripe, :request, :start],
      %{system_time: System.system_time()},
      metadata
    )
  end

  test "handler processes :stop event without crashing" do
    # First fire a start event to create a span
    start_metadata = %{
      method: :post,
      path: "/v1/payment_intents",
      resource: :payment_intent,
      operation: :create,
      api_version: "2024-06-20",
      stripe_account: nil,
      telemetry_span_context: make_ref()
    }

    :telemetry.execute(
      [:lattice_stripe, :request, :start],
      %{system_time: System.system_time()},
      start_metadata
    )

    stop_metadata = %{
      method: :post,
      path: "/v1/payment_intents",
      resource: :payment_intent,
      operation: :create,
      api_version: "2024-06-20",
      stripe_account: nil,
      status: :ok,
      http_status: 200,
      request_id: "req_test123",
      attempts: 1,
      retries: 0,
      error_type: nil,
      idempotency_key: nil,
      rate_limited_reason: nil,
      telemetry_span_context: make_ref()
    }

    # Should not raise
    :telemetry.execute(
      [:lattice_stripe, :request, :stop],
      %{duration: System.convert_time_unit(100, :millisecond, :native)},
      stop_metadata
    )
  end

  test "handler processes webhook verify events without crashing" do
    :telemetry.execute(
      [:lattice_stripe, :webhook, :verify, :start],
      %{system_time: System.system_time()},
      %{path: "/webhooks/stripe"}
    )

    :telemetry.execute(
      [:lattice_stripe, :webhook, :verify, :stop],
      %{duration: System.convert_time_unit(5, :millisecond, :native)},
      %{path: "/webhooks/stripe", result: :ok, error_reason: nil}
    )
  end

  test "handler processes webhook verify error without crashing" do
    :telemetry.execute(
      [:lattice_stripe, :webhook, :verify, :start],
      %{system_time: System.system_time()},
      %{path: "/webhooks/stripe"}
    )

    :telemetry.execute(
      [:lattice_stripe, :webhook, :verify, :stop],
      %{duration: System.convert_time_unit(1, :millisecond, :native)},
      %{path: "/webhooks/stripe", result: :error, error_reason: :invalid_signature}
    )
  end
end
