defmodule LatticeStripe.Json.Jason do
  @moduledoc false

  @behaviour LatticeStripe.Json

  @doc """
  Encodes `data` to a JSON string, raising `Jason.EncodeError` on failure.

  ## Example

      LatticeStripe.Json.Jason.encode!(%{"amount" => 2000})
      # => "{\\"amount\\":2000}"
  """
  @impl true
  def encode!(data), do: Jason.encode!(data)

  @doc """
  Decodes a JSON string to an Elixir term, raising `Jason.DecodeError` on failure.

  ## Example

      LatticeStripe.Json.Jason.decode!("{\\"id\\":\\"cus_123\\"}")
      # => %{"id" => "cus_123"}
  """
  @impl true
  def decode!(data), do: Jason.decode!(data)

  @doc """
  Encodes `data` to a JSON string, returning `{:ok, json}` or `{:error, error}`.

  Used by `Client.request/2` for graceful handling of non-encodable data.

  ## Example

      LatticeStripe.Json.Jason.encode(%{"amount" => 2000})
      # => {:ok, "{\\"amount\\":2000}"}
  """
  @impl true
  def encode(data) do
    Jason.encode(data)
  end

  @doc """
  Decodes a JSON string to an Elixir term, returning `{:ok, term}` or `{:error, error}`.

  Used by `Client.request/2` for graceful handling of non-JSON responses
  (e.g., HTML maintenance pages, empty bodies).

  ## Example

      LatticeStripe.Json.Jason.decode("{\\"id\\":\\"cus_123\\"}")
      # => {:ok, %{"id" => "cus_123"}}

      LatticeStripe.Json.Jason.decode("<html>maintenance</html>")
      # => {:error, %Jason.DecodeError{...}}
  """
  @impl true
  def decode(data) do
    Jason.decode(data)
  end
end
