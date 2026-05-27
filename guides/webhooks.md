# Webhooks

Stripe webhooks are how your application learns what actually became true after an
API call. Your app can start a payment, subscription update, dispute workflow, or
quote flow, but webhooks confirm whether Stripe later accepted, finalized, failed,
or retried that work.

If you only keep one rule from this guide, keep this one:

**Your app starts work. Webhooks confirm reality.**

For Stripe's full event and delivery reference, see
[Stripe Webhooks](https://docs.stripe.com/webhooks).

## The raw-body invariant

Stripe signs the exact UTF-8 request body it sends. Signature verification fails if
your framework mutates the body before verification by parsing JSON, changing
whitespace, or re-encoding the bytes.

Stripe's signature troubleshooting guide reduces verification to three inputs:

1. the raw request body
2. the `Stripe-Signature` header
3. the correct endpoint secret

That is why the first job of your Phoenix integration is preserving the raw body
before `Plug.Parsers` transforms it. See
[Resolve webhook signature verification errors](https://docs.stripe.com/webhooks/signature).

## Canonical Phoenix quickstart

The recommended setup is to mount `LatticeStripe.Webhook.Plug` in `endpoint.ex`
before `Plug.Parsers`, gate it with `at:`, and dispatch to a handler module.

This path is the best default because it avoids extra parser configuration and keeps
raw-body handling explicit.

### 1. Mount `LatticeStripe.Webhook.Plug` before `Plug.Parsers`

```elixir
# lib/my_app_web/endpoint.ex

plug LatticeStripe.Webhook.Plug,
  at: "/webhooks/stripe",
  secret: {MyApp.BillingConfig, :stripe_webhook_secret, []},
  handler: MyApp.StripeWebhookHandler

plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  json_decoder: Jason
```

Use runtime secret resolution in public examples. `LatticeStripe.Webhook.Plug`
accepts a string, a list of strings for rotation, an MFA tuple, or a zero-arity
function:

```elixir
defmodule MyApp.BillingConfig do
  def stripe_webhook_secret do
    System.fetch_env!("STRIPE_WEBHOOK_SECRET")
  end
end
```

`at:` restricts the plug to one path. Requests to other paths pass through unchanged.
Non-`POST` requests to the webhook path return `405 Method Not Allowed`.

### 2. Implement a handler module

```elixir
defmodule MyApp.StripeWebhookHandler do
  @behaviour LatticeStripe.Webhook.Handler

  @impl true
  def handle_event(%LatticeStripe.Event{type: "payment_intent.succeeded"} = event) do
    payment_intent = event.data["object"]
    order_id = get_in(payment_intent, ["metadata", "order_id"])

    MyApp.Workers.fulfill_order(order_id, payment_intent["id"])
    :ok
  end

  @impl true
  def handle_event(%LatticeStripe.Event{type: "customer.subscription.updated"} = event) do
    subscription = event.data["object"]

    MyApp.Workers.sync_subscription(subscription["id"])
    :ok
  end

  @impl true
  def handle_event(%LatticeStripe.Event{type: "customer.subscription.deleted"} = event) do
    subscription = event.data["object"]

    MyApp.Workers.deprovision_account(subscription["id"])
    :ok
  end

  @impl true
  def handle_event(_event), do: :ok
end
```

Keep handlers thin. Enqueue or delegate the real work and return `:ok` quickly so
Stripe gets a `2xx` response before any slow application logic starts.

## What to do with the event

Use the immediate API response to continue the user's current interaction, but use the
webhook to decide what your system should persist as truth.

Examples:

- Fulfill an order from `payment_intent.succeeded`, not from a frontend redirect.
- Update local subscription state from `customer.subscription.updated` and
  `invoice.payment_failed`, not from a portal return URL.
- Treat dispute evidence submission as accepted only after the corresponding webhook
  or follow-up retrieval confirms the downstream state you care about.

## Local testing

Use the Stripe CLI to forward events to your local Phoenix server:

```bash
stripe listen --forward-to localhost:4000/webhooks/stripe
```

The CLI prints a `whsec_...` signing secret. Use that secret for local webhook
verification. It is different from a Dashboard-managed endpoint secret.

For application tests, `LatticeStripe.Testing.generate_webhook_payload/3` builds a
signed payload/header pair that passes `LatticeStripe.Webhook.construct_event/4`:

```elixir
alias LatticeStripe.Testing
alias LatticeStripe.Testing.Fixtures

@webhook_secret "whsec_test_secret"

{payload, sig_header} =
  Testing.generate_webhook_payload(
    "quote.accepted",
    Fixtures.Quote.accepted_quote_json(),
    secret: @webhook_secret
  )
```

See [Testing](testing.md) for the public fixture-builder surface.

## Advanced alternative: `CacheBodyReader` + router `forward`

Use this when your endpoint architecture requires `Plug.Parsers` to run before the
webhook route or when you want to keep webhook routing in `router.ex`.

Plug's docs describe `:body_reader` as the hook for preserving the raw body before it
is parsed and discarded. LatticeStripe ships a ready-made cache-body reader module
for that pattern.

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
  secret: fn -> System.fetch_env!("STRIPE_WEBHOOK_SECRET") end,
  handler: MyApp.StripeWebhookHandler
```

This path remains fully supported, but it is an advanced alternative, not the
primary quickstart.

## Troubleshooting

**Signature verification fails immediately**

- Confirm you are using the raw body, not a decoded JSON map.
- Confirm the `Stripe-Signature` header is present.
- Confirm the endpoint secret matches the environment sending the event.
- Do not mix Stripe CLI secrets with Dashboard endpoint secrets.

**`Plug.Parsers` consumed the body**

- Use the canonical endpoint-level mount before `Plug.Parsers`, or
- configure `body_reader: {LatticeStripe.Webhook.CacheBodyReader, :read_body, []}`.

**The endpoint is slow**

- Return `:ok` quickly.
- Push fulfillment, reconciliation, email, and external calls to background jobs.

**A browser redirect disagrees with your local state**

- Trust the webhook path, not the redirect.
- Redirects are user experience. Webhooks are state confirmation.

## See also

- [Checkout Signup and Portal Follow-Through](checkout-signup-and-portal.md)
- [Connect Platform Flow](connect-platform-flow.md)
- [Metering Runtime and Reconciliation](metering-runtime-and-reconciliation.md)
- [Quote to Billing Operator Flow](quote-to-billing-operator.md)
- [Testing](testing.md)
- [User Flows & JTBD](user-flows-and-jtbd.md)
- [Customer Portal](customer-portal.md)
- [Subscriptions](subscriptions.md)
- [Error Handling](error-handling.md)

## Thin events (`/v2/events`)

Stripe also delivers **thin events** to `/v2/event-destinations` endpoints.
A thin event payload carries only `{id, type, related_object}` — your app
fetches authoritative state after verification. See
[Webhooks: Thin Events](webhooks-thin-events.md) for the canonical Phoenix
pattern, fetch-after-verify idempotency, and rate-limit guidance.

When webhooks fail in production after setup, use
[Event Debugging](event-debugging.md) for the symptom spine — signature failures,
duplicate deliveries, and fetch-after-verify races.
