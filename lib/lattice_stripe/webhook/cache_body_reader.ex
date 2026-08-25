if Code.ensure_loaded?(Plug) do
  defmodule LatticeStripe.Webhook.CacheBodyReader do
    @moduledoc """
    Preserves a Stripe webhook request's exact raw body while `Plug.Parsers` reads it.

    This module is available only when your application includes `:plug`; LatticeStripe
    keeps the module behind an optional-Plug compile guard.

    Prefer mounting `LatticeStripe.Webhook.Plug` before `Plug.Parsers` for a Stripe
    endpoint. Use this reader only as an advanced alternative when endpoint ordering
    cannot change and `Plug.Parsers` must run first.

    Configure it as `Plug.Parsers`' `:body_reader` callback. Every successful call
    returns the same tag and current chunk as `Plug.Conn.read_body/2`. After its
    terminal `{:ok, body, conn}` result, `conn.private[:raw_body]` contains the exact
    complete request-body binary in its original byte order.

    ## Retention and scope

    A parser-level body reader retains another copy of each request body for the
    connection lifetime. Scope it narrowly to the webhook route where possible: raw
    bodies can contain PII and must not be logged wholesale. This reader is not for
    multipart parsing.
    """

    @doc """
    Reads the current request-body chunk and caches raw bytes in
    `conn.private[:raw_body]`.

    This function is a drop-in replacement for `Plug.Conn.read_body/2` and is
    intended to be used as the `:body_reader` option for `Plug.Parsers`.

    After a terminal `{:ok, body, conn}` result, `conn.private[:raw_body]` contains
    the exact complete body. On `{:more, body, conn}`, the private value contains all
    chunks read so far. The fixed `:raw_body` key is intentionally not configurable.
    """
    @spec read_body(Plug.Conn.t(), keyword()) ::
            {:ok, binary(), Plug.Conn.t()}
            | {:more, binary(), Plug.Conn.t()}
            | {:error, term()}
    def read_body(conn, opts) do
      case Plug.Conn.read_body(conn, opts) do
        {:ok, body, conn} ->
          conn = cache_body(conn, body)
          {:ok, body, conn}

        {:more, body, conn} ->
          conn = cache_body(conn, body)
          {:more, body, conn}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp cache_body(conn, body) do
      raw_body = Map.get(conn.private, :raw_body, "") <> body
      Plug.Conn.put_private(conn, :raw_body, raw_body)
    end
  end
end
