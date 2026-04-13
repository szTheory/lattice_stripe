if Code.ensure_loaded?(Plug) do
  defmodule LatticeStripe.Webhook.CacheBodyReader do
    @moduledoc false

    @doc """
    Reads the request body and caches the raw bytes in `conn.private[:raw_body]`.

    This function is a drop-in replacement for `Plug.Conn.read_body/2` and is
    intended to be used as the `:body_reader` option for `Plug.Parsers`.

    After this function runs, `conn.private[:raw_body]` contains the raw body
    bytes that were read.
    """
    @spec read_body(Plug.Conn.t(), keyword()) ::
            {:ok, binary(), Plug.Conn.t()}
            | {:more, binary(), Plug.Conn.t()}
            | {:error, term()}
    def read_body(conn, opts) do
      case Plug.Conn.read_body(conn, opts) do
        {:ok, body, conn} ->
          conn = Plug.Conn.put_private(conn, :raw_body, body)
          {:ok, body, conn}

        {:more, body, conn} ->
          conn = Plug.Conn.put_private(conn, :raw_body, body)
          {:more, body, conn}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
