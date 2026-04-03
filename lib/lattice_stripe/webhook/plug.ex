if Code.ensure_loaded?(Plug) do
  defmodule LatticeStripe.Webhook.Plug do
    @moduledoc """
    Phoenix Plug for Stripe webhook signature verification and event dispatch.

    `LatticeStripe.Webhook.Plug` verifies the `Stripe-Signature` header on incoming
    webhook requests, constructs a typed `%LatticeStripe.Event{}`, and either assigns
    it to the connection (pass-through mode) or dispatches it to your handler module.

    ## Mounting Strategies

    ### Option A: Endpoint-level with `at:` path matching

    Mount the plug in `endpoint.ex` before `Plug.Parsers`, using the `at:` option
    to restrict it to a specific path. The plug intercepts matching requests and
    passes everything else through.

        # endpoint.ex
        plug LatticeStripe.Webhook.Plug,
          at: "/webhooks/stripe",
          secret: System.fetch_env!("STRIPE_WEBHOOK_SECRET"),
          handler: MyApp.StripeHandler

        plug Plug.Parsers,
          parsers: [:json],
          pass: ["application/json"],
          json_decoder: Jason

    ### Option B: Router-level via `forward` (with CacheBodyReader)

    Mount after `Plug.Parsers` using `Plug.Parsers` + `CacheBodyReader` so the raw
    body is preserved. Then forward in your router:

        # endpoint.ex
        plug Plug.Parsers,
          parsers: [:urlencoded, :multipart, :json],
          pass: ["*/*"],
          json_decoder: Jason,
          body_reader: {LatticeStripe.Webhook.CacheBodyReader, :read_body, []}

        # router.ex
        forward "/webhooks/stripe", LatticeStripe.Webhook.Plug,
          secret: System.fetch_env!("STRIPE_WEBHOOK_SECRET"),
          handler: MyApp.StripeHandler

    ## Operation Modes

    ### Handler mode (recommended)

    When a `:handler` module is configured, the plug dispatches the verified event
    to `handler.handle_event/1` and sends the HTTP response:

    - Handler returns `:ok` or `{:ok, _}` → responds `200 ""`
    - Handler returns `:error` or `{:error, _}` → responds `400 ""`
    - Handler raises → exception propagates (not caught)
    - Handler returns anything else → raises `RuntimeError`

        plug LatticeStripe.Webhook.Plug,
          secret: "whsec_...",
          handler: MyApp.StripeHandler

    ### Pass-through mode

    Without a `:handler`, the plug assigns the verified event to
    `conn.assigns.stripe_event` and passes the connection to the next plug or
    controller. Your controller reads the event and sends its own response.

        plug LatticeStripe.Webhook.Plug,
          secret: "whsec_...",
          at: "/webhooks/stripe"

        # In your controller:
        def webhook(conn, _params) do
          event = conn.assigns.stripe_event
          handle_event(event)
          send_resp(conn, 200, "ok")
        end

    ## Raw Body Requirement

    Stripe signs the **raw, unmodified request body**. Most frameworks parse the
    body and discard the original bytes. Two solutions:

    1. **Mount before `Plug.Parsers`** using `at:` — the plug reads the body
       directly before parsers consume it.
    2. **Use `CacheBodyReader`** — configure `Plug.Parsers` to cache the raw bytes
       in `conn.private[:raw_body]`. See `LatticeStripe.Webhook.CacheBodyReader`.

    ## Secret Resolution

    The `:secret` option supports runtime resolution to avoid compile-time secrets:

        # Static string (simple)
        secret: "whsec_..."

        # List of strings (secret rotation — any match succeeds)
        secret: ["whsec_old...", "whsec_new..."]

        # MFA tuple (resolved at call time)
        secret: {MyApp.Config, :stripe_webhook_secret, []}

        # Zero-arity function (resolved at call time)
        secret: fn -> System.fetch_env!("STRIPE_WEBHOOK_SECRET") end

    ## Configuration Options

    - `:secret` (required) — Webhook signing secret. See "Secret Resolution" above.
    - `:handler` — Module implementing `LatticeStripe.Webhook.Handler`. If omitted,
      runs in pass-through mode.
    - `:at` — Mount path (e.g., `"/webhooks/stripe"`). When set, the plug only
      processes requests matching this path; other paths pass through. Non-POST
      requests to this path return `405 Method Not Allowed`.
    - `:tolerance` — Maximum age of the webhook timestamp in seconds (default: 300).
    """

    @behaviour Plug

    alias LatticeStripe.Webhook

    @schema NimbleOptions.new!(
              secret: [
                type: {:or, [:string, {:list, :string}, :mfa, {:fun, 0}]},
                required: true,
                doc:
                  "Webhook signing secret(s). String, list of strings, {M,F,A} tuple, or zero-arity function."
              ],
              handler: [
                type: {:or, [:atom, nil]},
                default: nil,
                doc: "Module implementing LatticeStripe.Webhook.Handler. Dispatches to handle_event/1."
              ],
              at: [
                type: {:or, [:string, nil]},
                default: nil,
                doc:
                  "Mount path (e.g., \"/webhooks/stripe\"). When omitted, processes all POST requests."
              ],
              tolerance: [
                type: :pos_integer,
                default: 300,
                doc: "Max age of webhook timestamp in seconds."
              ]
            )

    @doc """
    Validates and normalizes plug options at compile/mount time.

    Raises `NimbleOptions.ValidationError` if options are invalid.
    """
    @impl Plug
    def init(opts) do
      validated = NimbleOptions.validate!(opts, @schema)

      path_info =
        case Keyword.get(validated, :at) do
          nil -> nil
          at -> String.split(at, "/", trim: true)
        end

      validated |> Map.new() |> Map.put(:path_info, path_info)
    end

    @doc """
    Processes the connection through webhook verification.

    Routes based on HTTP method and path (when `at:` is configured):

    - POST to matching path (or any path when `at:` is nil) → verify and handle
    - Non-POST to matching path → 405 Method Not Allowed
    - Any request to non-matching path → pass through
    """
    @impl Plug

    # POST + at: path set + path matches → handle
    def call(%Plug.Conn{method: "POST", path_info: path_info} = conn, %{path_info: path_info} = opts)
        when path_info != nil do
      handle_webhook(conn, opts)
    end

    # POST + no at: path (process all POSTs)
    def call(%Plug.Conn{method: "POST"} = conn, %{path_info: nil} = opts) do
      handle_webhook(conn, opts)
    end

    # Non-POST + at: path matches → 405
    def call(%Plug.Conn{path_info: path_info} = conn, %{path_info: path_info})
        when path_info != nil do
      conn
      |> Plug.Conn.put_resp_header("allow", "POST")
      |> Plug.Conn.send_resp(405, "Method Not Allowed")
      |> Plug.Conn.halt()
    end

    # Non-POST + no at: path → pass through
    def call(conn, %{path_info: nil}), do: conn

    # Path doesn't match → pass through
    def call(conn, _opts), do: conn

    # ---------------------------------------------------------------------------
    # Private helpers
    # ---------------------------------------------------------------------------

    # Reads the raw body, verifies the signature, and either assigns the event
    # or dispatches to the configured handler.
    defp handle_webhook(conn, opts) do
      secret = resolve_secret(opts.secret)
      raw_body = get_raw_body(conn)
      sig_header = Plug.Conn.get_req_header(conn, "stripe-signature") |> List.first()

      case Webhook.construct_event(raw_body, sig_header, secret, tolerance: opts.tolerance) do
        {:ok, event} ->
          conn = Plug.Conn.assign(conn, :stripe_event, event)

          case opts.handler do
            nil ->
              # Pass-through mode: assign event and continue pipeline
              conn

            handler ->
              # Handler mode: dispatch and send HTTP response
              result = handler.handle_event(event)
              dispatch_result(conn, result)
          end

        {:error, _reason} ->
          conn
          |> Plug.Conn.send_resp(400, "")
          |> Plug.Conn.halt()
      end
    end

    # Sends the appropriate HTTP response based on handler return value.
    defp dispatch_result(conn, :ok) do
      conn |> Plug.Conn.send_resp(200, "") |> Plug.Conn.halt()
    end

    defp dispatch_result(conn, {:ok, _}) do
      conn |> Plug.Conn.send_resp(200, "") |> Plug.Conn.halt()
    end

    defp dispatch_result(conn, :error) do
      conn |> Plug.Conn.send_resp(400, "") |> Plug.Conn.halt()
    end

    defp dispatch_result(conn, {:error, _}) do
      conn |> Plug.Conn.send_resp(400, "") |> Plug.Conn.halt()
    end

    defp dispatch_result(_conn, result) do
      raise RuntimeError,
            "Expected handle_event/1 to return :ok | {:ok, term} | :error | {:error, term}, got: #{inspect(result)}"
    end

    # Resolves MFA tuples and zero-arity functions to their secret values.
    # Static strings and lists are returned as-is.
    defp resolve_secret({mod, fun, args}), do: apply(mod, fun, args)
    defp resolve_secret(fun) when is_function(fun, 0), do: fun.()
    defp resolve_secret(secret), do: secret

    # Reads the raw request body for HMAC verification.
    # Checks conn.private[:raw_body] first (set by CacheBodyReader or a prior
    # read). Falls back to Plug.Conn.read_body/1 for the mount-before-parsers
    # strategy. Returns empty string if body cannot be read.
    defp get_raw_body(conn) do
      case conn.private[:raw_body] do
        nil ->
          case Plug.Conn.read_body(conn) do
            {:ok, body, _conn} -> body
            _ -> ""
          end

        body ->
          body
      end
    end
  end
end
