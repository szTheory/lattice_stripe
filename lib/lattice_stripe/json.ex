defmodule LatticeStripe.Json do
  @moduledoc """
  JSON codec behaviour for LatticeStripe.

  The default implementation uses Jason. To use a different JSON library,
  implement this behaviour and pass `json_codec: MyCodec` to `Client.new!/1`.

  ## Bang vs. Non-Bang Callbacks

  This behaviour provides both bang (`!`) and non-bang variants for encoding and
  decoding. The non-bang variants (`encode/1` and `decode/1`) are used internally
  for graceful error handling — for example, when a Stripe response body is not
  valid JSON (e.g., an HTML maintenance page). They return `{:ok, result}` or
  `{:error, exception}` without raising.

  ## Example

      defmodule MyApp.JsonCodec do
        @behaviour LatticeStripe.Json

        @impl true
        def encode!(data), do: MyJsonLib.encode!(data)

        @impl true
        def decode!(data), do: MyJsonLib.decode!(data)

        @impl true
        def encode(data), do: MyJsonLib.encode(data)

        @impl true
        def decode(data), do: MyJsonLib.decode(data)
      end

      client = LatticeStripe.Client.new!(api_key: "sk_test_...", finch: MyFinch, json_codec: MyApp.JsonCodec)
  """

  @callback encode!(term()) :: binary()
  @callback decode!(binary()) :: term()

  @doc """
  Encodes `data` to JSON, returning `{:ok, binary}` on success or `{:error, exception}` on failure.
  """
  @callback encode(term()) :: {:ok, binary()} | {:error, Exception.t()}

  @doc """
  Decodes `data` from JSON, returning `{:ok, term}` on success or `{:error, exception}` on failure.
  """
  @callback decode(binary()) :: {:ok, term()} | {:error, Exception.t()}
end
