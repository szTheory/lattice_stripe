defmodule LatticeStripe.Client do
  @moduledoc """
  The main entry point for making Stripe API requests.

  `Client` is a plain struct (no GenServer, no global state) that holds all
  configuration for a Stripe integration. Create one at application startup
  and pass it explicitly to every API call.

  ## Quick Start

      client = LatticeStripe.Client.new!(
        api_key: "sk_test_...",
        finch: MyApp.Finch
      )

      request = %LatticeStripe.Request{method: :get, path: "/v1/customers/cus_123"}
      {:ok, customer} = LatticeStripe.Client.request(client, request)

  ## Multiple Clients

  You can run multiple clients with different keys simultaneously — useful for
  Stripe Connect platforms managing sub-accounts:

      platform_client = LatticeStripe.Client.new!(api_key: "sk_live_platform", finch: MyApp.Finch)
      connect_client = LatticeStripe.Client.new!(
        api_key: "sk_live_platform",
        finch: MyApp.Finch,
        stripe_account: "acct_connected_account"
      )

  ## Per-Request Overrides

  Pass `opts` in a `Request` struct to override client defaults for a single call:

      request = %LatticeStripe.Request{
        method: :post,
        path: "/v1/charges",
        params: %{amount: 1000, currency: "usd", source: "tok_visa"},
        opts: [
          idempotency_key: "charge-unique-key-123",
          stripe_account: "acct_connected",
          timeout: 10_000
        ]
      }
  """

  alias LatticeStripe.{Config, Error, FormEncoder, List, Request, Response}

  @version Mix.Project.config()[:version]

  @enforce_keys [:api_key, :finch]
  defstruct [
    :api_key,
    :finch,
    :stripe_account,
    base_url: "https://api.stripe.com",
    api_version: "2026-03-25.dahlia",
    transport: LatticeStripe.Transport.Finch,
    json_codec: LatticeStripe.Json.Jason,
    retry_strategy: LatticeStripe.RetryStrategy.Default,
    timeout: 30_000,
    max_retries: 2,
    telemetry_enabled: true,
    require_explicit_proration: false
  ]

  @typedoc """
  A configured LatticeStripe client.

  Created via `new!/1` or `new/1`. Pass this struct to every API call.
  It is a plain struct with no process state — safe to share across processes.

  - `api_key` - Stripe secret key (`sk_test_...` or `sk_live_...`)
  - `finch` - Name of the Finch pool started in your supervision tree
  - `stripe_account` - Connected account ID for Stripe Connect platforms, or `nil`
  - `base_url` - Stripe API base URL (default: `"https://api.stripe.com"`)
  - `api_version` - Stripe API version header (default: `"2026-03-25.dahlia"`)
  - `transport` - Transport module implementing `LatticeStripe.Transport`
  - `json_codec` - JSON codec module implementing `LatticeStripe.Json`
  - `retry_strategy` - Retry strategy module implementing `LatticeStripe.RetryStrategy`
  - `timeout` - Default request timeout in milliseconds (default: `30_000`)
  - `max_retries` - Max retry attempts after initial failure (default: `2`)
  - `telemetry_enabled` - Whether to emit telemetry events (default: `true`)
  - `require_explicit_proration` - When `true`, proration-sensitive operations require explicit `proration_behavior` param (default: `false`)
  """
  @type t :: %__MODULE__{
          api_key: String.t(),
          finch: atom(),
          stripe_account: String.t() | nil,
          base_url: String.t(),
          api_version: String.t(),
          transport: module(),
          json_codec: module(),
          retry_strategy: module(),
          timeout: pos_integer(),
          max_retries: non_neg_integer(),
          telemetry_enabled: boolean(),
          require_explicit_proration: boolean()
        }

  @doc """
  Creates a new `%Client{}` struct, raising on invalid options.

  Validates options using `LatticeStripe.Config.validate!/1`. Raises
  `NimbleOptions.ValidationError` with a descriptive message if any option
  is invalid or a required option is missing.

  ## Required Options

  - `:api_key` - Your Stripe API key (e.g., `"sk_test_..."`)
  - `:finch` - Name atom of a running Finch pool (e.g., `MyApp.Finch`)

  ## Optional Options

  See `LatticeStripe.Config` for the full schema with defaults and documentation.

  ## Example

      client = LatticeStripe.Client.new!(api_key: "sk_test_...", finch: MyApp.Finch)
  """
  @spec new!(keyword()) :: t()
  def new!(opts) do
    validated = Config.validate!(opts)
    struct!(__MODULE__, validated)
  end

  @doc """
  Creates a new `%Client{}` struct, returning `{:ok, client}` or `{:error, error}`.

  Like `new!/1` but returns a result tuple instead of raising.

  ## Example

      case LatticeStripe.Client.new(api_key: "sk_test_...", finch: MyApp.Finch) do
        {:ok, client} -> client
        {:error, error} -> raise error
      end
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, NimbleOptions.ValidationError.t()}
  def new(opts) do
    case Config.validate(opts) do
      {:ok, validated} -> {:ok, struct!(__MODULE__, validated)}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Dispatches a `Request` through the client's configured transport with automatic retries.

  Builds the full request with all required headers, encodes params, calls
  the transport, decodes the response JSON, and returns either `{:ok, map}`
  on success or `{:error, %Error{}}` on failure.

  POST requests automatically get an `idk_ltc_`-prefixed UUID v4 idempotency key
  to make retries safe. The same key is reused across all retry attempts.
  User-provided `:idempotency_key` in `opts` takes precedence over auto-generation.

  Wraps the transport call(s) in a `:telemetry.span/3` for observability (unless
  `telemetry_enabled: false` on the client). Per-retry events are emitted as
  `[:lattice_stripe, :request, :retry]`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `request` - A `%LatticeStripe.Request{}` struct

  ## Returns

  - `{:ok, %LatticeStripe.Response{}}` - Response struct wrapping decoded data with metadata.
    `data` is a `%LatticeStripe.List{}` for list/search endpoints, or a plain map for singular resources.
  - `{:error, %LatticeStripe.Error{}}` - Structured error from 4xx/5xx or transport failure
  """
  @spec request(t(), Request.t()) :: {:ok, Response.t()} | {:error, Error.t()}
  def request(%__MODULE__{} = client, %Request{} = req) do
    effective_api_key = Keyword.get(req.opts, :api_key, client.api_key)
    effective_api_version = Keyword.get(req.opts, :stripe_version, client.api_version)
    effective_timeout = Keyword.get(req.opts, :timeout, client.timeout)
    effective_stripe_account = Keyword.get(req.opts, :stripe_account, client.stripe_account)
    effective_max_retries = Keyword.get(req.opts, :max_retries, client.max_retries)
    expand = Keyword.get(req.opts, :expand, [])

    # Resolve idempotency key ONCE before retry loop so all retry attempts share the same key (D-21).
    # Auto-generate for POST requests; user-provided key takes precedence (D-18, D-19).
    idempotency_key = resolve_idempotency_key(req.method, req.opts)

    params = merge_expand(req.params, expand)

    {url, body} = build_url_and_body(client.base_url, req.method, req.path, params)

    headers =
      build_headers(
        req.method,
        effective_api_key,
        effective_api_version,
        effective_stripe_account,
        idempotency_key
      )

    transport_opts = [finch: client.finch, timeout: effective_timeout]

    transport_request = %{
      method: req.method,
      url: url,
      headers: headers,
      body: body,
      opts: transport_opts,
      _params: params,
      _req_opts: req.opts
    }

    LatticeStripe.Telemetry.request_span(client, req, idempotency_key, fn ->
      do_request_with_retries(
        client,
        transport_request,
        req.method,
        idempotency_key,
        effective_max_retries
      )
    end)
  end

  @doc """
  Like `request/2`, but raises `LatticeStripe.Error` on failure.

  Retries are attempted first. Only raises after all retries are exhausted.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `request` - A `%LatticeStripe.Request{}` struct

  ## Returns

  - `%LatticeStripe.Response{}` on success (raises `LatticeStripe.Error` on failure)
  - Raises `LatticeStripe.Error` on failure (after retries exhausted)
  """
  @spec request!(t(), Request.t()) :: Response.t()
  def request!(%__MODULE__{} = client, %Request{} = req) do
    case request(client, req) do
      {:ok, result} -> result
      {:error, %Error{} = error} -> raise error
    end
  end

  # Resolve the idempotency key for a request.
  # User-provided key takes precedence. Auto-generates for POST only (D-18, D-19).
  defp resolve_idempotency_key(method, opts) do
    user_key = Keyword.get(opts, :idempotency_key)

    cond do
      user_key != nil -> user_key
      method == :post -> generate_idempotency_key()
      true -> nil
    end
  end

  # Generate a UUID v4 with the idk_ltc_ prefix (D-19, D-20).
  # Uses :crypto.strong_rand_bytes/1 — same approach as Ecto.UUID.
  defp generate_idempotency_key do
    "idk_ltc_" <> uuid4()
  end

  defp uuid4 do
    <<a::48, _::4, b::12, _::2, c::62>> = :crypto.strong_rand_bytes(16)

    <<a::48, 4::4, b::12, 2::2, c::62>>
    |> encode_uuid()
  end

  defp encode_uuid(<<a::32, b::16, c::16, d::16, e::48>>) do
    [
      Base.encode16(<<a::32>>, case: :lower),
      "-",
      Base.encode16(<<b::16>>, case: :lower),
      "-",
      Base.encode16(<<c::16>>, case: :lower),
      "-",
      Base.encode16(<<d::16>>, case: :lower),
      "-",
      Base.encode16(<<e::48>>, case: :lower)
    ]
    |> IO.iodata_to_binary()
  end

  # Entry point for retry loop — starts with attempt 1, total_attempts 1.
  # Returns {result, total_attempts} so telemetry can record attempt count.
  defp do_request_with_retries(client, transport_request, method, idempotency_key, max_retries) do
    do_request_with_retries(
      client,
      transport_request,
      method,
      idempotency_key,
      max_retries,
      _attempt = 1,
      _total_attempts = 1
    )
  end

  defp do_request_with_retries(
         client,
         transport_request,
         method,
         idempotency_key,
         max_retries,
         attempt,
         total_attempts
       ) do
    case do_request(client, transport_request) do
      {:ok, _} = success ->
        {success, total_attempts}

      {:error, %Error{} = error, resp_headers} = _failure ->
        retry_state = %{
          method: method,
          idempotency_key: idempotency_key,
          max_retries: max_retries,
          attempt: attempt,
          total_attempts: total_attempts
        }

        maybe_retry(client, transport_request, retry_state, error, resp_headers)
    end
  end

  # Handle retry decision after a failed request attempt.
  # retry_state bundles {method, idempotency_key, max_retries, attempt, total_attempts}
  # to keep arity within Credo limits.
  defp maybe_retry(client, transport_request, retry_state, error, resp_headers) do
    %{attempt: attempt, total_attempts: total_attempts} = retry_state

    if attempt <= retry_state.max_retries do
      # Parse Stripe-Should-Retry from response headers before building context (D-09).
      stripe_should_retry = parse_stripe_should_retry(resp_headers)

      context = %{
        error: error,
        status: error.status,
        headers: resp_headers,
        stripe_should_retry: stripe_should_retry,
        method: retry_state.method,
        idempotency_key: retry_state.idempotency_key
      }

      apply_retry_decision(client, transport_request, retry_state, error, context)
    else
      {{:error, error}, total_attempts}
    end
  end

  # Apply the retry strategy decision: sleep and recurse, or stop.
  defp apply_retry_decision(client, transport_request, retry_state, error, context) do
    %{
      method: method,
      idempotency_key: idk,
      max_retries: max,
      attempt: attempt,
      total_attempts: total
    } = retry_state

    case client.retry_strategy.retry?(attempt, context) do
      {:retry, delay_ms} ->
        LatticeStripe.Telemetry.emit_retry(
          client,
          method,
          transport_request.url,
          error,
          attempt,
          delay_ms
        )

        # D-15: Process.sleep for retry delays; BEAM handles thousands of sleeping processes
        Process.sleep(delay_ms)

        do_request_with_retries(
          client,
          transport_request,
          method,
          idk,
          max,
          attempt + 1,
          total + 1
        )

      :stop ->
        {{:error, error}, total}
    end
  end

  # Build headers list from request parameters.
  defp build_headers(method, api_key, api_version, stripe_account, idempotency_key) do
    base_headers = [
      {"authorization", "Bearer #{api_key}"},
      {"stripe-version", api_version},
      {"user-agent",
       "LatticeStripe/#{@version} elixir/#{System.version()} otp/#{System.otp_release()}"},
      {"x-stripe-client-user-agent", client_user_agent_json()},
      {"accept", "application/json"}
    ]

    headers = maybe_add_content_type(base_headers, method)
    headers = maybe_add_stripe_account(headers, stripe_account)
    headers = maybe_add_idempotency_key(headers, idempotency_key)
    headers
  end

  defp client_user_agent_json do
    %{
      "bindings_version" => @version,
      "lang" => "elixir",
      "lang_version" => System.version(),
      "publisher" => "lattice_stripe",
      "otp_version" => System.otp_release()
    }
    |> Jason.encode!()
  end

  defp maybe_add_content_type(headers, method) when method in [:post, :put, :patch] do
    [{"content-type", "application/x-www-form-urlencoded"} | headers]
  end

  defp maybe_add_content_type(headers, _method), do: headers

  defp maybe_add_stripe_account(headers, nil), do: headers

  defp maybe_add_stripe_account(headers, stripe_account) do
    [{"stripe-account", stripe_account} | headers]
  end

  defp maybe_add_idempotency_key(headers, nil), do: headers

  defp maybe_add_idempotency_key(headers, key) do
    [{"idempotency-key", key} | headers]
  end

  # Build URL and body based on HTTP method.
  # POST/PUT/PATCH: URL is plain, params go in body.
  # GET/DELETE: params go as query string, body is nil.
  defp build_url_and_body(base_url, method, path, params) when method in [:post, :put, :patch] do
    url = base_url <> path
    body = FormEncoder.encode(params)
    {url, body}
  end

  defp build_url_and_body(base_url, _method, path, params) do
    encoded = FormEncoder.encode(params)

    url =
      if encoded == "" do
        base_url <> path
      else
        base_url <> path <> "?" <> encoded
      end

    {url, nil}
  end

  # Merge expand list into params using indexed bracket notation.
  defp merge_expand(params, []), do: params

  defp merge_expand(params, expand) when is_list(expand) do
    expand_map =
      expand
      |> Enum.with_index()
      |> Enum.into(%{}, fn {v, i} -> {i, v} end)

    Map.put(params, "expand", expand_map)
  end

  # Execute the transport request and decode the response.
  # Returns {:ok, %Response{}} | {:error, error, resp_headers} — the 3-tuple variant
  # keeps response headers available internally for the retry loop to inspect
  # (e.g., Stripe-Should-Retry, Retry-After) without leaking them to the public API.
  defp do_request(client, transport_request) do
    params = Map.get(transport_request, :_params, %{})
    req_opts = Map.get(transport_request, :_req_opts, [])

    case client.transport.request(transport_request) do
      {:ok, %{status: status, headers: resp_headers, body: body}} ->
        decode_response(client, status, resp_headers, body, params, req_opts)

      {:error, reason} ->
        {:error,
         %Error{
           type: :connection_error,
           message: inspect(reason)
         }, []}
    end
  end

  # Decode the HTTP response body and build the appropriate result tuple.
  defp decode_response(client, status, resp_headers, body, params, req_opts) do
    request_id = extract_request_id(resp_headers)

    case client.json_codec.decode(body) do
      {:ok, decoded} ->
        build_decoded_response(status, decoded, request_id, resp_headers, params, req_opts)

      {:error, _decode_error} ->
        # Non-JSON response (D-27): HTML maintenance page, empty body, etc.
        # Produce a structured error rather than crashing.
        build_non_json_error(status, body, request_id, resp_headers)
    end
  end

  # Build response for successfully decoded JSON.
  # Detects list/search_result objects and wraps them in %List{} with params/opts threading.
  defp build_decoded_response(status, decoded, request_id, resp_headers, params, req_opts) do
    if status in 200..299 do
      data =
        case decoded["object"] do
          type when type in ["list", "search_result"] ->
            List.from_json(decoded, params, req_opts)

          _ ->
            decoded
        end

      {:ok, %Response{data: data, status: status, headers: resp_headers, request_id: request_id}}
    else
      {:error, Error.from_response(status, decoded, request_id), resp_headers}
    end
  end

  # Build a structured error for non-JSON responses (D-27).
  defp build_non_json_error(status, body, request_id, resp_headers) do
    truncated = truncate_body(body, 500)

    error = %Error{
      type: :api_error,
      code: nil,
      message: "Non-JSON response from Stripe API (HTTP #{status})",
      status: status,
      request_id: request_id,
      raw_body: %{"_raw" => truncated}
    }

    {:error, error, resp_headers}
  end

  # Truncate body to max bytes, appending "..." if truncated.
  # Used for non-JSON responses so raw_body doesn't balloon memory.
  defp truncate_body(nil, _max), do: ""
  defp truncate_body("", _max), do: ""
  defp truncate_body(body, max) when byte_size(body) <= max, do: body
  defp truncate_body(body, max), do: binary_part(body, 0, max) <> "..."

  # Extract the request-id header value (case-insensitive).
  defp extract_request_id(headers) do
    headers
    |> Enum.find_value(fn {name, value} ->
      if String.downcase(name) == "request-id", do: value
    end)
  end

  # Parse the Stripe-Should-Retry header into a boolean or nil (D-09).
  # Stripe sends "true" or "false" as strings.
  defp parse_stripe_should_retry(headers) do
    value =
      Enum.find_value(headers, fn {k, v} ->
        if String.downcase(k) == "stripe-should-retry", do: v
      end)

    case value do
      "true" -> true
      "false" -> false
      _ -> nil
    end
  end
end
