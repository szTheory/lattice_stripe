defmodule LatticeStripe.Telemetry do
  @moduledoc """
  Telemetry integration for LatticeStripe.

  LatticeStripe emits [`:telemetry`](https://hexdocs.pm/telemetry) events for all
  HTTP requests and webhook signature verification. Attach handlers to these events
  to integrate with your observability stack (Prometheus, DataDog, OpenTelemetry, etc.).

  ## HTTP Request Events

  ### `[:lattice_stripe, :request, :start]`

  Emitted before each HTTP request is dispatched.

  **Measurements:**

  | Key | Type | Description |
  |-----|------|-------------|
  | `:system_time` | `integer` | System time at span start (in native time units). See `System.system_time/0`. |
  | `:monotonic_time` | `integer` | Monotonic time at span start. See `System.monotonic_time/0`. |

  **Metadata:**

  | Key | Type | Description |
  |-----|------|-------------|
  | `:method` | `atom` | HTTP method atom: `:get`, `:post`, `:delete` |
  | `:path` | `String.t()` | Request path, e.g. `"/v1/customers"` |
  | `:resource` | `String.t()` | Parsed resource name, e.g. `"customer"`, `"payment_intent"`, `"checkout.session"` |
  | `:operation` | `String.t()` | Parsed operation name, e.g. `"create"`, `"retrieve"`, `"list"`, `"confirm"` |
  | `:api_version` | `String.t()` | Stripe API version, e.g. `"2026-03-25.dahlia"` |
  | `:stripe_account` | `String.t() \\| nil` | Connected account ID from Stripe-Account header, or `nil` |
  | `:telemetry_span_context` | `reference` | Auto-injected by `:telemetry.span/3` for correlating start/stop/exception events |

  ---

  ### `[:lattice_stripe, :request, :stop]`

  Emitted after each HTTP request completes (success or API error).

  **Measurements:**

  | Key | Type | Description |
  |-----|------|-------------|
  | `:duration` | `integer` | Elapsed time in native time units. Convert via `System.convert_time_unit/3`. |
  | `:monotonic_time` | `integer` | Monotonic time at span stop. |

  **Metadata (all start fields plus):**

  | Key | Type | Description |
  |-----|------|-------------|
  | `:method` | `atom` | HTTP method atom |
  | `:path` | `String.t()` | Request path |
  | `:resource` | `String.t()` | Parsed resource name |
  | `:operation` | `String.t()` | Parsed operation name |
  | `:api_version` | `String.t()` | Stripe API version |
  | `:stripe_account` | `String.t() \\| nil` | Connected account ID or `nil` |
  | `:status` | `:ok \\| :error` | Outcome of the request |
  | `:http_status` | `integer \\| nil` | HTTP status code (nil for connection errors) |
  | `:request_id` | `String.t() \\| nil` | Stripe `request-id` header value |
  | `:attempts` | `integer` | Total attempts made (1 = no retries, 2 = one retry, etc.) |
  | `:retries` | `integer` | Number of retries (attempts - 1) |
  | `:error_type` | `atom \\| nil` | Error type atom on failure: `:connection_error`, `:card_error`, etc. |
  | `:idempotency_key` | `String.t() \\| nil` | Idempotency key used (on error only) |
  | `:telemetry_span_context` | `reference` | Correlates with start event |

  ---

  ### `[:lattice_stripe, :request, :exception]`

  Emitted when an uncaught exception or throw escapes the request function. This covers
  transport-level bugs, not API errors (which produce `[:lattice_stripe, :request, :stop]`
  with `status: :error`). Handled automatically by `:telemetry.span/3`.

  **Measurements:**

  | Key | Type | Description |
  |-----|------|-------------|
  | `:duration` | `integer` | Elapsed time in native time units |
  | `:monotonic_time` | `integer` | Monotonic time at exception |

  **Metadata:**

  | Key | Type | Description |
  |-----|------|-------------|
  | `:method` | `atom` | HTTP method atom |
  | `:path` | `String.t()` | Request path |
  | `:resource` | `String.t()` | Parsed resource name |
  | `:operation` | `String.t()` | Parsed operation name |
  | `:api_version` | `String.t()` | Stripe API version |
  | `:stripe_account` | `String.t() \\| nil` | Connected account ID or `nil` |
  | `:kind` | `:error \\| :exit \\| :throw` | Exception kind |
  | `:reason` | `any` | Exception reason |
  | `:stacktrace` | `list` | Exception stacktrace |
  | `:telemetry_span_context` | `reference` | Correlates with start event |

  ---

  ### `[:lattice_stripe, :request, :retry]`

  Emitted for each retry attempt before the retry delay sleep.

  **Measurements:**

  | Key | Type | Description |
  |-----|------|-------------|
  | `:attempt` | `integer` | Retry attempt number (1 = first retry after initial failure) |
  | `:delay_ms` | `integer` | Delay in milliseconds before the retry |

  **Metadata:**

  | Key | Type | Description |
  |-----|------|-------------|
  | `:method` | `atom` | HTTP method atom |
  | `:path` | `String.t()` | Request path |
  | `:error_type` | `atom` | Error type that triggered the retry |
  | `:status` | `integer \\| nil` | HTTP status code (nil for connection errors) |

  ---

  ## Webhook Verification Events

  ### `[:lattice_stripe, :webhook, :verify, :start]`

  Emitted before webhook signature verification begins.

  **Measurements:**

  | Key | Type | Description |
  |-----|------|-------------|
  | `:system_time` | `integer` | System time at span start |
  | `:monotonic_time` | `integer` | Monotonic time at span start |

  **Metadata:**

  | Key | Type | Description |
  |-----|------|-------------|
  | `:path` | `String.t() \\| nil` | Request path where webhook was received, if available |
  | `:telemetry_span_context` | `reference` | Auto-injected for span correlation |

  ---

  ### `[:lattice_stripe, :webhook, :verify, :stop]`

  Emitted after webhook signature verification completes.

  **Measurements:**

  | Key | Type | Description |
  |-----|------|-------------|
  | `:duration` | `integer` | Elapsed time in native time units |
  | `:monotonic_time` | `integer` | Monotonic time at span stop |

  **Metadata:**

  | Key | Type | Description |
  |-----|------|-------------|
  | `:path` | `String.t() \\| nil` | Request path where webhook was received |
  | `:result` | `:ok \\| :error` | Verification outcome |
  | `:error_reason` | `atom \\| nil` | Failure reason: `:invalid_signature`, `:stale_timestamp`, `:missing_header`, `:no_valid_signature`, or `nil` on success |
  | `:telemetry_span_context` | `reference` | Correlates with start event |

  ---

  ### `[:lattice_stripe, :webhook, :verify, :exception]`

  Emitted when an uncaught exception escapes webhook verification. Handled automatically by `:telemetry.span/3`.

  **Measurements:**

  | Key | Type | Description |
  |-----|------|-------------|
  | `:duration` | `integer` | Elapsed time in native time units |
  | `:monotonic_time` | `integer` | Monotonic time at exception |

  **Metadata:**

  | Key | Type | Description |
  |-----|------|-------------|
  | `:path` | `String.t() \\| nil` | Request path |
  | `:kind` | `:error \\| :exit \\| :throw` | Exception kind |
  | `:reason` | `any` | Exception reason |
  | `:stacktrace` | `list` | Exception stacktrace |
  | `:telemetry_span_context` | `reference` | Correlates with start event |

  ---

  ## Usage with `Telemetry.Metrics`

  If you're using `telemetry_metrics` with Prometheus or StatsD, here are ready-to-use metric
  definitions:

  ```elixir
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

    # Latency distribution (p50/p95/p99)
    Telemetry.Metrics.distribution("lattice_stripe.request.stop.duration",
      tags: [:resource, :operation],
      unit: {:native, :millisecond}
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
  ```

  ## Invoice Auto-Advance Events

  ### `[:lattice_stripe, :invoice, :auto_advance_scheduled]`

  Emitted after a successful `Invoice.create/3` when the returned invoice has
  `auto_advance: true`. This signals that Stripe will automatically finalize the
  draft invoice after approximately 1 hour. Attach a handler to log a warning or
  trigger a monitoring alert when auto-advance invoices are created.

  **Measurements:**

  | Key | Type | Description |
  |-----|------|-------------|
  | `:system_time` | `integer` | System time at emission (in native time units). See `System.system_time/0`. |

  **Metadata:**

  | Key | Type | Description |
  |-----|------|-------------|
  | `:invoice_id` | `String.t()` | The created invoice ID (e.g. `"in_123"`) |
  | `:customer` | `String.t() \\| nil` | Customer ID associated with the invoice, or `nil` |

  ---

  ## Attaching a Default Logger

  For instant visibility during development or to log all Stripe requests in production,
  use `attach_default_logger/1`:

  ```elixir
  # In your application start/2:
  LatticeStripe.Telemetry.attach_default_logger()

  # Or with options:
  LatticeStripe.Telemetry.attach_default_logger(level: :debug)
  ```

  This logs one line per request in the format:

  ```
  [info] POST /v1/customers => 200 in 145ms (1 attempt, req_abc123)
  [warn] GET /v1/payment_intents/pi_123 => :error in 301ms (3 attempts, connection_error)
  [warning] Invoice in_123 (customer: cus_456) has auto_advance: true — Stripe will auto-finalize in ~1 hour
  ```

  ## Converting Duration

  The `:duration` measurement is in native time units. Convert to milliseconds:

  ```elixir
  duration_ms = System.convert_time_unit(duration, :native, :millisecond)
  ```
  """

  require Logger

  alias LatticeStripe.{Error, Response}

  @request_event [:lattice_stripe, :request]
  @webhook_verify_event [:lattice_stripe, :webhook, :verify]
  @retry_event [:lattice_stripe, :request, :retry]
  @auto_advance_event [:lattice_stripe, :invoice, :auto_advance_scheduled]
  @default_logger_id :lattice_stripe_default_logger
  @auto_advance_logger_id :lattice_stripe_auto_advance_logger

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  # Wraps the request function in a telemetry span (emitting start/stop/exception events).
  # @doc false — implementation detail; event catalog documented in @moduledoc.
  @doc false
  @spec request_span(
          LatticeStripe.Client.t(),
          LatticeStripe.Request.t(),
          String.t() | nil,
          (-> {term(), non_neg_integer(), list()})
        ) :: {:ok, Response.t()} | {:error, Error.t()}
  def request_span(client, req, idempotency_key, fun) do
    if client.telemetry_enabled do
      start_meta = build_start_metadata(client, req)

      :telemetry.span(
        @request_event,
        start_meta,
        fn ->
          {result, attempts, resp_headers} = fun.()
          stop_meta = build_stop_metadata(result, idempotency_key, attempts, resp_headers, start_meta)
          {result, stop_meta}
        end
      )
    else
      {result, _attempts, _resp_headers} = fun.()
      result
    end
  end

  # Emits the [:lattice_stripe, :invoice, :auto_advance_scheduled] event after a successful
  # Invoice.create/3 when the returned invoice has auto_advance: true.
  # @doc false — implementation detail; event catalog documented in @moduledoc.
  @doc false
  @spec emit_auto_advance_scheduled(LatticeStripe.Client.t(), map()) :: :ok
  def emit_auto_advance_scheduled(client, invoice) do
    if client.telemetry_enabled do
      :telemetry.execute(
        @auto_advance_event,
        %{system_time: System.system_time()},
        %{invoice_id: invoice.id, customer: invoice.customer}
      )
    end

    :ok
  end

  # Emits the per-retry telemetry event. Called once per retry, before the delay sleep.
  # @doc false — implementation detail; event catalog documented in @moduledoc.
  @doc false
  @spec emit_retry(
          LatticeStripe.Client.t(),
          atom(),
          String.t(),
          Error.t(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :ok
  def emit_retry(client, method, url, error, attempt, delay_ms) do
    if client.telemetry_enabled do
      :telemetry.execute(
        @retry_event,
        %{attempt: attempt, delay_ms: delay_ms},
        %{
          method: method,
          path: extract_path(url),
          error_type: error.type,
          status: error.status
        }
      )
    end

    :ok
  end

  @doc """
  Attaches a default structured logger for all LatticeStripe request events.

  Safe to call multiple times -- detaches any existing handler with the same ID first.

  ## Options
    * `:level` -- log level (default: `:info`)

  ## Example

      LatticeStripe.Telemetry.attach_default_logger(level: :info)

  Logs one line per completed request:

      [info] POST /v1/customers => 200 in 145ms (1 attempt, req_abc123)
      [warning] GET /v1/customers/cus_xxx => 404 in 12ms (1 attempt, req_yyy)

  Also logs a warning when an invoice is created with `auto_advance: true`:

      [warning] Invoice in_123 (customer: cus_456) has auto_advance: true — Stripe will auto-finalize in ~1 hour
  """
  @spec attach_default_logger(keyword()) :: :ok
  def attach_default_logger(opts \\ []) do
    level = Keyword.get(opts, :level, :info)
    :telemetry.detach(@default_logger_id)
    :telemetry.detach(@auto_advance_logger_id)

    :telemetry.attach(
      @default_logger_id,
      [:lattice_stripe, :request, :stop],
      &__MODULE__.handle_default_log/4,
      %{level: level}
    )

    :telemetry.attach(
      @auto_advance_logger_id,
      @auto_advance_event,
      &__MODULE__.handle_auto_advance_log/4,
      %{}
    )

    :ok
  end

  @doc false
  def handle_default_log(_event, measurements, metadata, %{level: level}) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    method = metadata.method |> to_string() |> String.upcase()
    status_part = if metadata[:http_status], do: "=> #{metadata.http_status} ", else: ""
    req_id = Map.get(metadata, :request_id, "no-req-id")
    attempts = Map.get(metadata, :attempts, 1)
    attempt_word = if attempts == 1, do: "attempt", else: "attempts"

    rate_limit_suffix =
      case Map.get(metadata, :rate_limited_reason) do
        nil -> ""
        reason -> " (rate_limited: #{reason})"
      end

    message =
      "#{method} #{metadata.path} #{status_part}in #{duration_ms}ms (#{attempts} #{attempt_word}, #{req_id})#{rate_limit_suffix}"

    effective_level = if metadata[:http_status] == 429, do: :warning, else: level
    Logger.log(effective_level, message)
  end

  @doc false
  def handle_auto_advance_log(_event, _measurements, metadata, _config) do
    customer_part =
      if metadata[:customer], do: " (customer: #{metadata.customer})", else: ""

    Logger.warning(
      "Invoice #{metadata.invoice_id}#{customer_part} has auto_advance: true — Stripe will auto-finalize in ~1 hour"
    )
  end

  # Wraps webhook verification in a telemetry span.
  # Uses @webhook_verify_event [:lattice_stripe, :webhook, :verify] event prefix.
  # @doc false — implementation detail; event catalog documented in @moduledoc.
  @doc false
  @spec webhook_verify_span(keyword(), (-> term())) :: term()
  def webhook_verify_span(opts \\ [], fun) do
    path = Keyword.get(opts, :path)
    start_meta = %{path: path}

    :telemetry.span(@webhook_verify_event, start_meta, fn ->
      result = fun.()
      stop_meta = build_webhook_stop_metadata(result, path)
      {result, stop_meta}
    end)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Build start metadata map for the request span.
  # Includes enriched fields: resource and operation parsed from the URL path,
  # plus api_version and stripe_account from the client config (D-03, D-04, D-05).
  defp build_start_metadata(client, req) do
    {resource, operation} = parse_resource_and_operation(req.method, req.path)

    %{
      method: req.method,
      path: req.path,
      resource: resource,
      operation: operation,
      api_version: client.api_version,
      stripe_account: client.stripe_account
    }
  end

  # Build stop metadata for a successful response.
  # Merges all start_meta fields so stop event has full context (RESEARCH Pitfall 2).
  defp build_stop_metadata({:ok, %Response{} = resp}, _idempotency_key, attempts, resp_headers, start_meta) do
    Map.merge(start_meta, %{
      status: :ok,
      http_status: resp.status,
      request_id: resp.request_id,
      attempts: attempts,
      retries: attempts - 1,
      rate_limited_reason: parse_rate_limited_reason(resp_headers)
    })
  end

  # Build stop metadata for a connection error (no HTTP status).
  defp build_stop_metadata(
         {:error, %Error{type: :connection_error}},
         idempotency_key,
         attempts,
         resp_headers,
         start_meta
       ) do
    Map.merge(start_meta, %{
      status: :error,
      error_type: :connection_error,
      idempotency_key: idempotency_key,
      attempts: attempts,
      retries: attempts - 1,
      rate_limited_reason: parse_rate_limited_reason(resp_headers)
    })
  end

  # Build stop metadata for an API error (has HTTP status, error type, request_id).
  defp build_stop_metadata({:error, %Error{} = error}, idempotency_key, attempts, resp_headers, start_meta) do
    Map.merge(start_meta, %{
      status: :error,
      http_status: error.status,
      error_type: error.type,
      request_id: error.request_id,
      idempotency_key: idempotency_key,
      attempts: attempts,
      retries: attempts - 1,
      rate_limited_reason: parse_rate_limited_reason(resp_headers)
    })
  end

  # Parse the Stripe-Rate-Limited-Reason header value (case-insensitive).
  # Returns the raw string value or nil when absent. Do NOT atomize — values
  # are Stripe-controlled strings; atomizing risks atom table growth.
  defp parse_rate_limited_reason(headers) when is_list(headers) do
    Enum.find_value(headers, fn {k, v} ->
      if String.downcase(k) == "stripe-rate-limited-reason", do: v
    end)
  end

  defp parse_rate_limited_reason(_), do: nil

  # Extract just the path component from a full URL for telemetry metadata.
  # Falls back to the raw URL if parsing fails or produces no path.
  defp extract_path(url) do
    case URI.parse(url) do
      %URI{path: path} when is_binary(path) -> path
      _ -> url
    end
  end

  # Parse resource name and operation from a Stripe API URL path.
  #
  # Stripe's URL structure follows predictable patterns:
  #   POST /v1/customers           -> {"customer", "create"}
  #   GET  /v1/customers           -> {"customer", "list"}
  #   GET  /v1/customers/cus_123   -> {"customer", "retrieve"}
  #   POST /v1/customers/cus_123   -> {"customer", "update"}
  #   DELETE /v1/customers/cus_123 -> {"customer", "delete"}
  #   POST /v1/payment_intents/pi_123/confirm -> {"payment_intent", "confirm"}
  #   POST /v1/checkout/sessions   -> {"checkout.session", "create"}
  #   GET  /v1/customers/search    -> {"customer", "search"}
  #
  # Returns {resource, operation} as strings.
  # Falls back to {path, to_string(method)} for unrecognized patterns.
  defp parse_resource_and_operation(method, path) do
    # Strip leading /v1/ or /v1 prefix and split into segments
    segments =
      path
      |> String.replace_prefix("/v1/", "")
      |> String.replace_prefix("/v1", "")
      |> String.split("/", trim: true)

    parse_segments(method, segments, path)
  end

  # Dispatch on segment count and structure. is_id/1 is a function (not guard),
  # so we use nested cond/if for multi-segment patterns that need dynamic checks.
  defp parse_segments(method, segments, path) do
    case segments do
      [resource_plural] ->
        resource = singularize(resource_plural)
        operation = if method == :get, do: "list", else: "create"
        {resource, operation}

      [first, second] ->
        parse_two_segments(method, first, second)

      [first, second, third] ->
        parse_three_segments(method, first, second, third)

      [first, second, _third, fourth] ->
        # /v1/namespace/resource_plural/id/action OR /v1/resource_plural/id/action/???
        if id_segment?(first) do
          # Unexpected 4-segment pattern starting with an ID — fallback
          {path, to_string(method)}
        else
          # Namespace pattern: /v1/namespace/resource_plural/id/action
          resource = "#{first}.#{singularize(second)}"
          {resource, fourth}
        end

      _ ->
        {path, to_string(method)}
    end
  end

  defp parse_two_segments(method, first, second) do
    cond do
      # /v1/resource_plural/search
      second == "search" ->
        {singularize(first), "search"}

      # /v1/resource_plural/id  (e.g. /v1/customers/cus_123)
      id_segment?(second) ->
        {singularize(first), derive_crud_operation(method)}

      # /v1/namespace/resource_plural  (e.g. /v1/checkout/sessions)
      # First segment is not an ID and not "search" — treat as namespace
      not id_segment?(first) ->
        resource = "#{first}.#{singularize(second)}"
        operation = if method == :get, do: "list", else: "create"
        {resource, operation}

      # Fallback: treat second as action on first resource
      true ->
        {singularize(first), second}
    end
  end

  defp parse_three_segments(method, first, second, third) do
    cond do
      # /v1/namespace/resource_plural/search  (e.g. /v1/checkout/sessions/search)
      third == "search" and not id_segment?(first) ->
        resource = "#{first}.#{singularize(second)}"
        {resource, "search"}

      # /v1/namespace/resource_plural/id  (e.g. /v1/checkout/sessions/cs_123)
      not id_segment?(first) and id_segment?(third) ->
        resource = "#{first}.#{singularize(second)}"
        {resource, derive_crud_operation(method)}

      # /v1/namespace/resource_plural/action (namespace + resource + action without ID)
      not id_segment?(first) and not id_segment?(second) ->
        resource = "#{first}.#{singularize(second)}"
        {resource, third}

      # /v1/resource_plural/id/action  (e.g. /v1/payment_intents/pi_123/confirm)
      id_segment?(second) ->
        resource = singularize(first)
        {resource, third}

      # /v1/resource_plural/search/... fallback
      true ->
        resource = singularize(first)
        {resource, third}
    end
  end

  # Check if a URL segment looks like a Stripe resource ID.
  # Stripe IDs are prefixed with known object type codes (cus_, pi_, seti_, etc.)
  # or are alphanumeric strings longer than 10 characters that aren't known action words.
  defp id_segment?(segment) do
    known_prefixes = ~w[cus_ pi_ seti_ pm_ re_ cs_ evt_ ch_ in_ sub_ prod_ price_ ii_ il_]

    Enum.any?(known_prefixes, &String.starts_with?(segment, &1)) or
      (String.length(segment) > 10 and segment =~ ~r/^[a-zA-Z0-9_]+$/ and
         segment not in known_action_words())
  end

  # Action words that appear as path segments but are NOT IDs.
  defp known_action_words do
    ~w[search confirm capture cancel expire attach detach verify refund close finalize
       retrieve create update delete list send mark_uncollectible void pay release]
  end

  # Derive CRUD operation from HTTP method when operating on a specific resource ID.
  defp derive_crud_operation(:get), do: "retrieve"
  defp derive_crud_operation(:post), do: "update"
  defp derive_crud_operation(:delete), do: "delete"
  defp derive_crud_operation(method), do: to_string(method)

  # Build stop metadata for webhook verification span.
  defp build_webhook_stop_metadata({:ok, _event}, path) do
    %{path: path, result: :ok, error_reason: nil}
  end

  defp build_webhook_stop_metadata({:error, reason}, path) do
    %{path: path, result: :error, error_reason: reason}
  end

  # Singularize a Stripe resource plural name to its canonical singular form.
  # Handles irregular plurals specific to Stripe's API naming conventions.
  defp singularize(plural) do
    case plural do
      "payment_intents" ->
        "payment_intent"

      "setup_intents" ->
        "setup_intent"

      "payment_methods" ->
        "payment_method"

      "checkout" ->
        "checkout"

      # Strip trailing "s" for regular English plurals:
      # customers -> customer, sessions -> session, refunds -> refund, etc.
      other ->
        if String.ends_with?(other, "s") do
          String.slice(other, 0..-2//1)
        else
          other
        end
    end
  end
end
