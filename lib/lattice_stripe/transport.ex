defmodule LatticeStripe.Transport do
  @moduledoc """
  HTTP transport behaviour for LatticeStripe.

  The default transport is a Finch-based adapter shipped with
  LatticeStripe (internal). To use a different HTTP client, implement
  this behaviour and pass `transport: MyTransport` to `Client.new!/1`.

  ## Example

      defmodule MyApp.Transport do
        @behaviour LatticeStripe.Transport

        @impl true
        def request(%{method: method, url: url, headers: headers, body: body, opts: opts}) do
          # Your HTTP client call here
          {:ok, %{status: 200, headers: [], body: "..."}}
        end
      end

  ## Contract

  The callback receives a plain map with these keys:
  - `method` - HTTP method atom (`:get`, `:post`, `:delete`)
  - `url` - Full URL string (`"https://api.stripe.com/v1/customers"`)
  - `headers` - List of `{name, value}` string tuples
  - `body` - Request body string or `nil`
  - `opts` - Keyword list with transport-specific options (e.g., `finch: MyFinch, timeout: 30_000`)

  Returns `{:ok, response_map}` or `{:error, reason}` where response_map has:
  - `status` - HTTP status integer
  - `headers` - List of `{name, value}` string tuples
  - `body` - Response body string
  """

  @type request_map :: %{
          method: atom(),
          url: String.t(),
          headers: [{String.t(), String.t()}],
          body: binary() | nil,
          opts: keyword()
        }

  @type response_map :: %{
          status: pos_integer(),
          headers: [{String.t(), String.t()}],
          body: binary()
        }

  @callback request(request_map()) :: {:ok, response_map()} | {:error, term()}
end
