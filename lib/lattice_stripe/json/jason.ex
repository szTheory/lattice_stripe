defmodule LatticeStripe.Json.Jason do
  @moduledoc """
  Default JSON codec using Jason.

  Implements the `LatticeStripe.Json` behaviour using Jason, the Elixir
  ecosystem standard for JSON encoding/decoding.
  """

  @behaviour LatticeStripe.Json

  @impl true
  def encode!(data), do: Jason.encode!(data)

  @impl true
  def decode!(data), do: Jason.decode!(data)
end
