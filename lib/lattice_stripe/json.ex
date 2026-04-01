defmodule LatticeStripe.Json do
  @moduledoc """
  JSON codec behaviour for LatticeStripe.

  The default implementation uses Jason. To use a different JSON library,
  implement this behaviour and pass `json_codec: MyCodec` to `Client.new!/1`.

  ## Example

      defmodule MyApp.JsonCodec do
        @behaviour LatticeStripe.Json

        @impl true
        def encode!(data), do: MyJsonLib.encode!(data)

        @impl true
        def decode!(data), do: MyJsonLib.decode!(data)
      end

      client = LatticeStripe.Client.new!(api_key: "sk_test_...", finch: MyFinch, json_codec: MyApp.JsonCodec)
  """

  @callback encode!(term()) :: binary()
  @callback decode!(binary()) :: term()
end
