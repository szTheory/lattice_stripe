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

  alias LatticeStripe.{Config, Error, Request, Response}
  alias LatticeStripe.Client.{Executor, RequestBuilder}

  @enforce_keys [:api_key]
  defstruct [
    :api_key,
    :finch,
    :stripe_account,
    base_url: "https://api.stripe.com",
    files_base_url: "https://files.stripe.com",
    api_version: "2026-03-25.dahlia",
    transport: LatticeStripe.Transport.Finch,
    json_codec: LatticeStripe.Json.Jason,
    retry_strategy: LatticeStripe.RetryStrategy.Default,
    timeout: 30_000,
    operation_timeouts: nil,
    max_retries: 2,
    telemetry_enabled: true,
    require_explicit_proration: false
  ]

  @typedoc """
  A configured LatticeStripe client.

  Created via `new!/1` or `new/1`. Pass this struct to every API call.
  It is a plain struct with no process state — safe to share across processes.

  - `api_key` - Stripe secret key (`sk_test_...` or `sk_live_...`)
  - `finch` - Name of the Finch pool for HTTP requests. Defaults to
    `LatticeStripe.Finch` (started automatically at boot). Guaranteed non-`nil`
    only when the struct is built via `new!/1`/`new/1` (which run
    `LatticeStripe.Config.validate!/1`); a bare `struct!/2` bypasses the default
  - `stripe_account` - Connected account ID for Stripe Connect platforms, or `nil`
  - `base_url` - Stripe API base URL (default: `"https://api.stripe.com"`)
  - `files_base_url` - Stripe Files API base URL for uploads (default: `"https://files.stripe.com"`)
  - `api_version` - Stripe API version header (default: `"2026-03-25.dahlia"`)
  - `transport` - Transport module implementing `LatticeStripe.Transport`
  - `json_codec` - JSON codec module implementing `LatticeStripe.Json`
  - `retry_strategy` - Retry strategy module implementing `LatticeStripe.RetryStrategy`
  - `timeout` - Default request timeout in milliseconds (default: `30_000`)
  - `operation_timeouts` - Per-operation timeout overrides in milliseconds (keys: `:list`, `:search`, `:create`, `:retrieve`, `:update`, `:delete`, `:upload`, `:download`), or `nil` to use `timeout` for all operations
  - `max_retries` - Max retry attempts after initial failure (default: `2`)
  - `telemetry_enabled` - Whether to emit telemetry events (default: `true`)
  - `require_explicit_proration` - When `true`, proration-sensitive operations require explicit `proration_behavior` param (default: `false`)
  """
  @type t :: %__MODULE__{
          api_key: String.t(),
          finch: atom(),
          stripe_account: String.t() | nil,
          base_url: String.t(),
          files_base_url: String.t(),
          api_version: String.t(),
          transport: module(),
          json_codec: module(),
          retry_strategy: module(),
          timeout: pos_integer(),
          operation_timeouts: %{atom() => pos_integer()} | nil,
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

  ## Optional Options

  - `:finch` - Name atom of a running Finch pool (e.g., `MyApp.Finch`). Defaults
    to `LatticeStripe.Finch`, started automatically at application boot.

  See `LatticeStripe.Config` for the full schema with defaults and documentation.

  ## Example

      # Zero-config — uses the default LatticeStripe.Finch pool:
      client = LatticeStripe.Client.new!(api_key: "sk_test_...")

      # Or bring your own pool:
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
    {transport_request, idempotency_key, max_retries} = RequestBuilder.build(client, req)

    LatticeStripe.Telemetry.request_span(client, req, idempotency_key, fn ->
      Executor.request(client, transport_request, req.method, idempotency_key, max_retries)
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

  @doc """
  Sends a multipart/form-data upload request to the Stripe Files API.

  Used internally by `LatticeStripe.File.create/3`. Accepts raw file binary,
  encodes it as multipart/form-data via `MultipartEncoder`, and sends to
  `client.files_base_url`.

  Returns `{:ok, %Response{}}` with JSON-decoded file data on success,
  or `{:error, %Error{}}` on failure. Reuses the standard retry loop and
  telemetry pipeline.

  ## Parameters

    - `client` - A configured `%Client{}`
    - `file_binary` - Raw binary file content (e.g., result of `File.read!/1`)
    - `params` - Map with `"purpose"` (required), optionally `"filename"` (default: `"upload"`) and `"file_link_data"`
    - `opts` - Per-request overrides (`:api_key`, `:stripe_version`, `:stripe_account`, `:timeout`, `:idempotency_key`, `:max_retries`, `:boundary`)

  """
  @spec upload(t(), binary(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def upload(%__MODULE__{} = client, file_binary, params, opts \\ [])
      when is_binary(file_binary) do
    {transport_request, telemetry_request, idempotency_key, max_retries} =
      RequestBuilder.build_upload(client, file_binary, params, opts)

    LatticeStripe.Telemetry.request_span(client, telemetry_request, idempotency_key, fn ->
      Executor.request(client, transport_request, :post, idempotency_key, max_retries)
    end)
  end

  @doc """
  Bang variant of `upload/4`. Raises `LatticeStripe.Error` on failure.
  """
  @spec upload!(t(), binary(), map(), keyword()) :: Response.t()
  def upload!(%__MODULE__{} = client, file_binary, params, opts \\ []) do
    case upload(client, file_binary, params, opts) do
      {:ok, response} -> response
      {:error, error} -> raise error
    end
  end

  @doc """
  Downloads binary content from a Stripe URL, skipping JSON decode on success.

  Returns raw binary in `%Response{data: binary}` on 2xx responses. Error responses
  (4xx/5xx) are still JSON-decoded into `{:error, %Error{}}`.

  Used by `Quote.pdf/3` and any endpoint returning non-JSON binary content.

  ## Parameters

    - `client` - A configured `%Client{}`
    - `path` - URL path (e.g., `"/v1/quotes/qt_123/pdf"`)
    - `opts` - Per-request overrides (`:api_key`, `:stripe_version`, `:stripe_account`, `:timeout`, `:max_retries`)

  """
  @spec download(t(), String.t(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def download(%__MODULE__{} = client, path, opts \\ []) when is_binary(path) do
    {transport_request, telemetry_request, max_retries} =
      RequestBuilder.build_download(client, path, opts)

    LatticeStripe.Telemetry.request_span(client, telemetry_request, nil, fn ->
      Executor.download(client, transport_request, :get, nil, max_retries)
    end)
  end

  @doc """
  Bang variant of `download/2`. Raises `LatticeStripe.Error` on failure.
  """
  @spec download!(t(), String.t(), keyword()) :: Response.t()
  def download!(%__MODULE__{} = client, path, opts \\ []) do
    case download(client, path, opts) do
      {:ok, response} -> response
      {:error, error} -> raise error
    end
  end
end
