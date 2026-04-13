defmodule LatticeStripe.Transport.Finch do
  @moduledoc false

  @behaviour LatticeStripe.Transport

  @doc """
  Executes an HTTP request using Finch.

  This is the default `LatticeStripe.Transport` implementation. It translates
  the transport request map into a `Finch.build/4` call, then dispatches via
  `Finch.request/3`.

  ## Parameters

  - `request_map` - A map with keys:
    - `method` - HTTP method atom (`:get`, `:post`, `:delete`)
    - `url` - Full URL string (e.g., `"https://api.stripe.com/v1/customers"`)
    - `headers` - List of `{name, value}` string tuples
    - `body` - Request body string or `nil` (for GET requests)
    - `opts` - Keyword list that must include:
      - `:finch` - Name atom of a running Finch pool (required)
      - `:timeout` - Receive timeout in milliseconds (default: 30_000)

  ## Returns

  - `{:ok, %{status: integer, headers: list, body: binary}}` on success
  - `{:error, exception}` on network failure (e.g., connection refused, timeout)

  ## Example

      LatticeStripe.Transport.Finch.request(%{
        method: :get,
        url: "https://api.stripe.com/v1/customers/cus_123",
        headers: [{"authorization", "Bearer sk_test_..."}],
        body: nil,
        opts: [finch: MyApp.Finch, timeout: 30_000]
      })
      # => {:ok, %{status: 200, headers: [...], body: "{\\"id\\":\\"cus_123\\",...}"}}
  """
  @impl true
  def request(%{method: method, url: url, headers: headers, body: body, opts: opts}) do
    finch_name = Keyword.fetch!(opts, :finch)
    timeout = Keyword.get(opts, :timeout, 30_000)

    method
    |> Finch.build(url, headers, body)
    |> Finch.request(finch_name, receive_timeout: timeout)
    |> case do
      {:ok, %Finch.Response{status: status, headers: headers, body: body}} ->
        {:ok, %{status: status, headers: headers, body: body}}

      {:error, exception} ->
        {:error, exception}
    end
  end
end
