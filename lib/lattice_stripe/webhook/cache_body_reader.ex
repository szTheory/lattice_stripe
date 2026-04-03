if Code.ensure_loaded?(Plug) do
  defmodule LatticeStripe.Webhook.CacheBodyReader do
    @moduledoc """
    Body reader that caches the raw request body for webhook signature verification.

    Stripe signs the **raw, unmodified request body** using HMAC-SHA256. Most
    frameworks (Phoenix included) parse the body via `Plug.Parsers`, which reads
    and discards the raw bytes. By the time your controller or Plug runs, the
    original body is gone — and signature verification fails.

    `CacheBodyReader` solves this by acting as a drop-in body reader for
    `Plug.Parsers`. It reads the body normally, then stashes the raw bytes in
    `conn.private[:raw_body]` before returning. `LatticeStripe.Webhook.Plug`
    reads from that private key automatically.

    ## Setup

    In your Phoenix `endpoint.ex`, configure `Plug.Parsers` to use
    `CacheBodyReader` as the body reader:

        plug Plug.Parsers,
          parsers: [:urlencoded, :multipart, :json],
          pass: ["*/*"],
          json_decoder: Jason,
          body_reader: {LatticeStripe.Webhook.CacheBodyReader, :read_body, []}

    Then mount the webhook plug in your router:

        forward "/webhooks/stripe", LatticeStripe.Webhook.Plug,
          secret: System.fetch_env!("STRIPE_WEBHOOK_SECRET"),
          handler: MyApp.StripeHandler

    ## Alternative: Mount before Plug.Parsers

    If you cannot use `CacheBodyReader` (e.g., conflicting body reader config),
    mount `LatticeStripe.Webhook.Plug` before `Plug.Parsers` in your endpoint.
    The plug falls back to `Plug.Conn.read_body/2` directly when
    `conn.private[:raw_body]` is not set.

        # endpoint.ex — mount BEFORE plug Plug.Parsers
        plug LatticeStripe.Webhook.Plug,
          at: "/webhooks/stripe",
          secret: System.fetch_env!("STRIPE_WEBHOOK_SECRET"),
          handler: MyApp.StripeHandler

        plug Plug.Parsers,
          parsers: [:json],
          pass: ["application/json"],
          json_decoder: Jason
    """

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
