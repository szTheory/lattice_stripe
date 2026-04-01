defmodule LatticeStripe.Transport.Finch do
  @moduledoc """
  Default HTTP transport using Finch.

  Translates the `LatticeStripe.Transport` contract into `Finch.build/5`
  and `Finch.request/3` calls.

  ## Prerequisites

  Add Finch to your supervision tree:

      children = [
        {Finch, name: MyApp.Finch}
      ]

  Then pass the pool name to your client:

      LatticeStripe.Client.new!(api_key: "sk_test_...", finch: MyApp.Finch)
  """

  @behaviour LatticeStripe.Transport

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
