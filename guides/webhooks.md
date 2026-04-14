# Webhooks

Stripe sends webhook events to notify your application about asynchronous activity —
payment succeeded, subscription renewed, refund created, and hundreds of other events.
This guide covers everything you need to receive and process Stripe webhooks in your
Elixir application.

For the full event catalog and delivery semantics, see the
[Stripe Webhooks documentation](https://docs.stripe.com/webhooks).

## Overview

Stripe sends webhooks as HTTP POST requests with a JSON body and a `Stripe-Signature`
header. Your endpoint must:

1. Read the **raw, unmodified** request body (before any JSON parsing)
2. Verify the signature using your webhook signing secret
3. Process the event
4. Return a `2xx` response quickly (Stripe retries on non-2xx responses)

LatticeStripe provides two ways to handle this:

- **`LatticeStripe.Webhook.Plug`** — The recommended approach. Handles raw body reading,
  signature verification, and event dispatch automatically.
- **`LatticeStripe.Webhook.construct_event/4`** — A pure function for manual integration
  with any web framework.

## Signature Verification

Every webhook from Stripe includes a `Stripe-Signature` header. Verifying this signature
confirms the payload came from Stripe and hasn't been tampered with.

To verify manually (without the Plug):

```elixir
# Read the raw request body BEFORE parsing it as JSON
raw_body = read_raw_body(conn)
sig_header = Plug.Conn.get_req_header(conn, "stripe-signature") |> List.first()
secret = System.fetch_env!("STRIPE_WEBHOOK_SECRET")

case LatticeStripe.Webhook.construct_event(raw_body, sig_header, secret) do
  {:ok, %LatticeStripe.Event{} = event} ->
    handle_event(event)
    send_resp(conn, 200, "")

  {:error, :missing_header} ->
    send_resp(conn, 400, "Missing Stripe-Signature header")

  {:error, :timestamp_expired} ->
    send_resp(conn, 400, "Webhook too old — possible replay attack")

  {:error, :no_matching_signature} ->
    send_resp(conn, 400, "Invalid signature")

  {:error, _reason} ->
    send_resp(conn, 400, "Signature verification failed")
end
```

Webhook secrets start with `whsec_`. Get yours from the
[Stripe Dashboard](https://dashboard.stripe.com/webhooks) after creating a webhook endpoint,
or from the [Stripe CLI](https://docs.stripe.com/stripe-cli) when running locally.

### Tolerance Window

By default, `construct_event/4` rejects webhooks older than 300 seconds (5 minutes).
This prevents replay attacks — an attacker can't capture a valid webhook and resend it later.

Override the tolerance window if your servers have clock skew:

```elixir
LatticeStripe.Webhook.construct_event(raw_body, sig_header, secret,
  tolerance: 600  # Accept webhooks up to 10 minutes old
)
```

## Using the Webhook Plug

`LatticeStripe.Webhook.Plug` is the recommended way to handle webhooks in a Phoenix
application. It handles raw body reading, signature verification, and event dispatch in
a single, well-tested plug.

There are two mounting strategies depending on your application structure.

### Option A: Mount Before Plug.Parsers (Simpler)

Mount the plug in `endpoint.ex` **before** `Plug.Parsers`. The plug reads the raw body
before parsers consume it, then passes non-matching requests through:

```elixir
# lib/my_app_web/endpoint.ex

# Mount BEFORE Plug.Parsers
plug LatticeStripe.Webhook.Plug,
  at: "/webhooks/stripe",
  secret: System.fetch_env!("STRIPE_WEBHOOK_SECRET"),
  handler: MyApp.StripeWebhookHandler

# Normal parsers (Webhook.Plug has already handled its path)
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  json_decoder: Jason
```

The `at:` option restricts the plug to a specific path. Requests to other paths pass
through to the next plug unchanged. Non-POST requests to the webhook path return
`405 Method Not Allowed`.

### Option B: CacheBodyReader + Router Forward

Mount `Plug.Parsers` with `CacheBodyReader` as the body reader, then forward the webhook
route in your router. This approach works well when you need `Plug.Parsers` to run before
the webhook plug (e.g., for other middleware):

```elixir
# lib/my_app_web/endpoint.ex

plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  json_decoder: Jason,
  body_reader: {LatticeStripe.Webhook.CacheBodyReader, :read_body, []}
```

```elixir
# lib/my_app_web/router.ex

forward "/webhooks/stripe", LatticeStripe.Webhook.Plug,
  secret: System.fetch_env!("STRIPE_WEBHOOK_SECRET"),
  handler: MyApp.StripeWebhookHandler
```

`CacheBodyReader` stashes the raw request bytes in `conn.private[:raw_body]` before
`Plug.Parsers` discards them. `Webhook.Plug` reads from that key automatically.

## Implementing a Handler

Create a module that implements the `LatticeStripe.Webhook.Handler` behaviour:

```elixir
defmodule MyApp.StripeWebhookHandler do
  @behaviour LatticeStripe.Webhook.Handler

  @impl true
  def handle_event(%LatticeStripe.Event{type: "payment_intent.succeeded"} = event) do
    payment_intent = event.data["object"]
    order_id = get_in(payment_intent, ["metadata", "order_id"])

    MyApp.Orders.fulfill(order_id, payment_intent["id"])
    :ok
  end

  def handle_event(%LatticeStripe.Event{type: "checkout.session.completed"} = event) do
    session = event.data["object"]
    customer_id = session["customer"]

    MyApp.Subscriptions.activate(customer_id)
    :ok
  end

  def handle_event(%LatticeStripe.Event{type: "customer.subscription.deleted"} = event) do
    subscription = event.data["object"]

    MyApp.Subscriptions.cancel(subscription["customer"])
    :ok
  end

  def handle_event(%LatticeStripe.Event{type: "invoice.payment_failed"} = event) do
    invoice = event.data["object"]

    MyApp.Billing.send_payment_failed_email(invoice["customer_email"])
    :ok
  end

  # Catch-all: return :ok for events you don't handle explicitly
  # This prevents errors for new Stripe event types
  def handle_event(_event), do: :ok
end
```

### Additional event types

Beyond the payment and checkout events shown above, Connect and Billing
platforms will want to handle these event families. Match on
`event.type` with the same pattern as the examples above:

- `account.updated` — Connect account capability or requirements changes
- `account.application.authorized` — Connect OAuth authorization
- `invoice.payment_succeeded` / `invoice.payment_failed` — Billing lifecycle
- `customer.subscription.created` / `customer.subscription.deleted` — Subscription lifecycle
- `v1.billing.meter.error_report_triggered` — Metering async errors; see [metering.md](metering.md#reconciliation-via-webhooks)

### Handler Return Values

The plug inspects your handler's return value and sends the appropriate HTTP response:

| Return value | HTTP response |
|---|---|
| `:ok` | `200 ""` |
| `{:ok, _}` | `200 ""` |
| `:error` | `400 ""` |
| `{:error, _}` | `400 ""` |
| anything else | raises `RuntimeError` |

Return `:ok` to acknowledge the event. Stripe considers any `2xx` response a successful
delivery. Return `:error` (or raise) to signal failure — Stripe will retry the webhook
according to its [retry schedule](https://docs.stripe.com/webhooks#retries).

### Processing Events Asynchronously

Stripe requires your webhook endpoint to respond within a few seconds. For time-consuming
operations (database queries, sending emails, calling external APIs), acknowledge immediately
and process in the background:

```elixir
def handle_event(%LatticeStripe.Event{type: "payment_intent.succeeded"} = event) do
  # Enqueue work and return immediately
  MyApp.Worker.enqueue(:fulfill_order, %{payment_intent: event.data["object"]})
  :ok
end
```

## Raw Body Caching

The core challenge with webhook signature verification is that Stripe signs the **raw
request body**. Most web frameworks — Phoenix included — parse the JSON body via
`Plug.Parsers` and discard the original bytes. By the time your controller or plug runs,
the raw body is gone.

There are two solutions:

### Solution 1: Mount before Plug.Parsers (Option A above)

The plug reads the raw body itself before parsers run. The simplest approach — no
configuration changes to `Plug.Parsers`.

### Solution 2: CacheBodyReader (Option B above)

Configure `Plug.Parsers` to cache the raw bytes:

```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  json_decoder: Jason,
  body_reader: {LatticeStripe.Webhook.CacheBodyReader, :read_body, []}
```

`CacheBodyReader.read_body/2` is a drop-in replacement for `Plug.Conn.read_body/2`. It
reads the body normally and stashes a copy in `conn.private[:raw_body]`. The Webhook Plug
reads from that key when available.

## Dynamic Secrets

Storing secrets at compile time can be risky — they end up in your BEAM bytecode. LatticeStripe
supports several patterns for runtime secret resolution.

### MFA Tuple (Recommended)

Resolve the secret at call time using a module-function-args tuple:

```elixir
plug LatticeStripe.Webhook.Plug,
  at: "/webhooks/stripe",
  secret_mfa: {MyApp.Config, :stripe_webhook_secret, []},
  handler: MyApp.StripeWebhookHandler
```

```elixir
defmodule MyApp.Config do
  def stripe_webhook_secret do
    System.fetch_env!("STRIPE_WEBHOOK_SECRET")
  end
end
```

> **Note:** The plug option is `secret_mfa:` (not `secret:`) when passing an MFA tuple
> via the plug macro. Alternatively, pass an MFA tuple or a zero-arity function directly
> to the `:secret` option:

```elixir
plug LatticeStripe.Webhook.Plug,
  at: "/webhooks/stripe",
  secret: {MyApp.Config, :stripe_webhook_secret, []},
  handler: MyApp.StripeWebhookHandler
```

### Zero-Arity Function

```elixir
plug LatticeStripe.Webhook.Plug,
  at: "/webhooks/stripe",
  secret: fn -> System.fetch_env!("STRIPE_WEBHOOK_SECRET") end,
  handler: MyApp.StripeWebhookHandler
```

### Secret Rotation

During webhook secret rotation, you can accept both the old and new secret simultaneously
by passing a list:

```elixir
plug LatticeStripe.Webhook.Plug,
  at: "/webhooks/stripe",
  secret: ["whsec_old_secret_...", "whsec_new_secret_..."],
  handler: MyApp.StripeWebhookHandler
```

Verification succeeds if the payload matches **any** secret in the list. Once rotation is
complete, remove the old secret from the list.

## Phoenix Integration Example

Here's a complete Phoenix endpoint setup with CacheBodyReader:

```elixir
# lib/my_app_web/endpoint.ex
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  # ... socket and static file plugs ...

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  # Configure Plug.Parsers with CacheBodyReader to preserve raw body
  # for Stripe webhook signature verification
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library(),
    body_reader: {LatticeStripe.Webhook.CacheBodyReader, :read_body, []}

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  plug MyAppWeb.Router
end
```

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  # Webhook endpoint — no auth pipeline, no CSRF
  forward "/webhooks/stripe", LatticeStripe.Webhook.Plug,
    secret: {MyApp.Config, :stripe_webhook_secret, []},
    handler: MyApp.StripeWebhookHandler

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
    # ...
  end

  # ... rest of your routes
end
```

### Testing Webhooks Locally

Use the [Stripe CLI](https://docs.stripe.com/stripe-cli) to forward events to your local
server:

```bash
stripe listen --forward-to localhost:4000/webhooks/stripe
```

The CLI prints a webhook signing secret (starting with `whsec_`) — use it as
`STRIPE_WEBHOOK_SECRET` for local development. This secret is different from your
production webhook secret.

### Testing in Your Test Suite

LatticeStripe provides `LatticeStripe.Webhook.generate_test_signature/3` to produce a
valid `Stripe-Signature` header for test payloads (and `LatticeStripe.Testing.generate_webhook_payload/3`
for building event payloads when you need both):

```elixir
# In your ExUnit tests
test "handles payment_intent.succeeded webhook" do
  secret = "whsec_test_secret"
  payload = Jason.encode!(%{
    "id" => "evt_123",
    "type" => "payment_intent.succeeded",
    "data" => %{"object" => %{"id" => "pi_123", "amount" => 2000}}
  })

  sig_header = LatticeStripe.Webhook.generate_test_signature(payload, secret)

  conn =
    build_conn()
    |> put_req_header("stripe-signature", sig_header)
    |> put_req_header("content-type", "application/json")
    |> assign(:raw_body, payload)
    |> post("/webhooks/stripe", payload)

  assert conn.status == 200
end
```

## Common Pitfalls

**Raw body must be preserved for signature verification.**
`Plug.Parsers` reads and discards the raw body. If you mount `Webhook.Plug` after
`Plug.Parsers` without `CacheBodyReader`, the raw body is gone and signature verification
will fail with `(MatchError) no match of right hand side value: ""`. Use either Option A
(mount before parsers) or Option B (CacheBodyReader).

**`CacheBodyReader` must be configured before `Plug.Parsers` runs.**
The `body_reader:` option in `Plug.Parsers` is what triggers `CacheBodyReader`. Don't
add `CacheBodyReader` as a separate plug — it only works as a `:body_reader` option.

**Webhook secrets start with `whsec_` — don't confuse with API keys.**
API keys start with `sk_live_` or `sk_test_`. Webhook signing secrets start with `whsec_`.
They are completely different. Using an API key as a webhook secret will cause every
signature verification to fail.

**Return `200` quickly — do heavy processing asynchronously.**
Stripe considers any response that takes longer than a few seconds a failure and will retry.
If your handler does database queries, sends emails, or calls other APIs, enqueue the work
and return `:ok` immediately. Use a job queue like Oban for background processing.

**Test with `LatticeStripe.Webhook.generate_test_signature/3` in your test suite.**
Don't hardcode HMAC values in tests — they'll break if you change the payload. Use
`generate_test_signature/3` to produce a valid signature for any test payload. The test
signature respects the 5-minute tolerance window by default.

**The catch-all handler clause is important.**
Stripe adds new event types regularly. If you don't have a catch-all `handle_event(_event), do: :ok`
clause, new event types will cause function clause errors that result in 500 responses and
Stripe retries.

## See also

- [Error Handling](error-handling.md) — retry semantics and error signalling from handlers
- [Connect Accounts](connect-accounts.md) — `account.updated` and capability event patterns
- [Subscriptions](subscriptions.md) — `customer.subscription.*` lifecycle events
