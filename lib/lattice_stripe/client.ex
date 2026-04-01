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

  alias LatticeStripe.{Config, Error, FormEncoder, Request}

  @version Mix.Project.config()[:version]

  @enforce_keys [:api_key, :finch]
  defstruct [
    :api_key,
    :finch,
    :stripe_account,
    base_url: "https://api.stripe.com",
    api_version: "2025-12-18.acacia",
    transport: LatticeStripe.Transport.Finch,
    json_codec: LatticeStripe.Json.Jason,
    timeout: 30_000,
    max_retries: 0,
    telemetry_enabled: true
  ]

  @type t :: %__MODULE__{
          api_key: String.t(),
          finch: atom(),
          stripe_account: String.t() | nil,
          base_url: String.t(),
          api_version: String.t(),
          transport: module(),
          json_codec: module(),
          timeout: pos_integer(),
          max_retries: non_neg_integer(),
          telemetry_enabled: boolean()
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
  Dispatches a `Request` through the client's configured transport.

  Builds the full request with all required headers, encodes params, calls
  the transport, decodes the response JSON, and returns either `{:ok, map}`
  on success or `{:error, %Error{}}` on failure.

  Wraps the transport call in a `:telemetry.span/3` for observability (unless
  `telemetry_enabled: false` on the client).

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `request` - A `%LatticeStripe.Request{}` struct

  ## Returns

  - `{:ok, decoded_body}` - Decoded JSON map from a 2xx response
  - `{:error, %LatticeStripe.Error{}}` - Structured error from 4xx/5xx or transport failure
  """
  @spec request(t(), Request.t()) :: {:ok, map()} | {:error, Error.t()}
  def request(%__MODULE__{} = client, %Request{} = req) do
    effective_api_key = Keyword.get(req.opts, :api_key, client.api_key)
    effective_api_version = Keyword.get(req.opts, :stripe_version, client.api_version)
    effective_timeout = Keyword.get(req.opts, :timeout, client.timeout)

    effective_stripe_account =
      Keyword.get(req.opts, :stripe_account, client.stripe_account)

    idempotency_key = Keyword.get(req.opts, :idempotency_key)
    expand = Keyword.get(req.opts, :expand, [])

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
      opts: transport_opts
    }

    if client.telemetry_enabled do
      :telemetry.span(
        [:lattice_stripe, :request],
        %{method: req.method, path: req.path},
        fn ->
          result = do_request(client, transport_request)
          {result, telemetry_stop_metadata(result)}
        end
      )
    else
      do_request(client, transport_request)
    end
  end

  # Build headers list from request parameters.
  defp build_headers(method, api_key, api_version, stripe_account, idempotency_key) do
    base_headers = [
      {"authorization", "Bearer #{api_key}"},
      {"stripe-version", api_version},
      {"user-agent", "LatticeStripe/#{@version} elixir/#{System.version()}"},
      {"accept", "application/json"}
    ]

    headers = maybe_add_content_type(base_headers, method)
    headers = maybe_add_stripe_account(headers, stripe_account)
    headers = maybe_add_idempotency_key(headers, idempotency_key)
    headers
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
  defp do_request(client, transport_request) do
    case client.transport.request(transport_request) do
      {:ok, %{status: status, headers: resp_headers, body: body}} ->
        request_id = extract_request_id(resp_headers)
        decoded = client.json_codec.decode!(body)

        if status in 200..299 do
          {:ok, decoded}
        else
          {:error, Error.from_response(status, decoded, request_id)}
        end

      {:error, reason} ->
        {:error,
         %Error{
           type: :connection_error,
           message: inspect(reason)
         }}
    end
  end

  # Extract the request-id header value (case-insensitive).
  defp extract_request_id(headers) do
    headers
    |> Enum.find_value(fn {name, value} ->
      if String.downcase(name) == "request-id", do: value
    end)
  end

  # Build stop metadata for telemetry span based on result.
  defp telemetry_stop_metadata({:ok, _decoded}), do: %{status: :ok}

  defp telemetry_stop_metadata({:error, %Error{type: :connection_error}}) do
    %{status: :error, error_type: :connection_error}
  end

  defp telemetry_stop_metadata({:error, %Error{status: status, type: type}}) do
    %{status: :error, http_status: status, error_type: type}
  end
end
