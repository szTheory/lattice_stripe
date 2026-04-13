# Checkout

[Stripe Checkout](https://docs.stripe.com/payments/checkout) is Stripe's hosted payment
page. Instead of building a custom payment form, you create a Checkout Session and redirect
your customer to Stripe's hosted URL. Stripe handles the payment UI, card validation,
3D Secure authentication, and more.

Checkout supports three modes:
- **payment** — one-time payment
- **subscription** — recurring billing
- **setup** — save a payment method without charging

## Payment Mode

Use `"mode" => "payment"` for one-time purchases. You define the products and quantities
using `line_items`, each referencing a [Price](https://docs.stripe.com/api/prices) object
you've created in Stripe.

```elixir
{:ok, session} = LatticeStripe.Checkout.Session.create(client, %{
  "mode" => "payment",
  "success_url" => "https://example.com/success?session_id={CHECKOUT_SESSION_ID}",
  "cancel_url" => "https://example.com/cancel",
  "line_items" => [
    %{"price" => "price_1OzqKZ2eZvKYlo2CHQkCGK7T", "quantity" => 1}
  ]
})

# Redirect the customer to session.url — the Stripe-hosted payment page
IO.puts("Redirect to: #{session.url}")
```

The `{CHECKOUT_SESSION_ID}` template in `success_url` is replaced by Stripe with the
actual session ID when the customer is redirected back. Use it to retrieve the completed
session:

```elixir
def handle_success(conn, %{"session_id" => session_id}) do
  {:ok, session} = LatticeStripe.Checkout.Session.retrieve(client, session_id)
  fulfill_order(session)
  render(conn, :success)
end
```

> **Important:** Don't rely on the redirect to confirm payment. Use webhooks to listen
> for `checkout.session.completed` — the redirect can be skipped or manipulated. See
> [Webhooks](webhooks.html) for setup.

### Ad-Hoc Line Items (Price Data)

If you don't have pre-created Price objects, you can define line items inline using
`price_data`:

```elixir
{:ok, session} = LatticeStripe.Checkout.Session.create(client, %{
  "mode" => "payment",
  "success_url" => "https://example.com/success",
  "cancel_url" => "https://example.com/cancel",
  "line_items" => [
    %{
      "price_data" => %{
        "currency" => "usd",
        "product_data" => %{"name" => "LatticeStripe Pro License"},
        "unit_amount" => 4900
      },
      "quantity" => 1
    }
  ]
})
```

### Pre-Filling Customer Information

Pass an existing customer ID to pre-fill their email and saved payment methods:

```elixir
{:ok, session} = LatticeStripe.Checkout.Session.create(client, %{
  "mode" => "payment",
  "customer" => "cus_OtVFqSomeStripeId",
  "success_url" => "https://example.com/success",
  "cancel_url" => "https://example.com/cancel",
  "line_items" => [
    %{"price" => "price_...", "quantity" => 1}
  ]
})
```

## Subscription Mode

Use `"mode" => "subscription"` to set up recurring billing. The line items should
reference prices with `recurring` intervals. See
[Subscriptions](subscriptions.md) for lifecycle management of the resulting
subscription object (trials, proration, cancellation):

```elixir
{:ok, session} = LatticeStripe.Checkout.Session.create(client, %{
  "mode" => "subscription",
  "success_url" => "https://example.com/success?session_id={CHECKOUT_SESSION_ID}",
  "cancel_url" => "https://example.com/cancel",
  "line_items" => [
    %{
      "price" => "price_1OzqKZ2eZvKYlo2CHmonthly",  # A recurring price object
      "quantity" => 1
    }
  ]
})
```

After a successful checkout, Stripe creates a Subscription and a recurring PaymentIntent.
Listen for the `checkout.session.completed` webhook to provision access, then
`customer.subscription.updated` and `invoice.payment_succeeded` to manage ongoing billing.

### Subscription with Trial

```elixir
{:ok, session} = LatticeStripe.Checkout.Session.create(client, %{
  "mode" => "subscription",
  "success_url" => "https://example.com/success",
  "cancel_url" => "https://example.com/cancel",
  "subscription_data" => %{
    "trial_period_days" => 14
  },
  "line_items" => [
    %{"price" => "price_monthly", "quantity" => 1}
  ]
})
```

## Setup Mode

Use `"mode" => "setup"` to collect and save a customer's payment method without charging
them immediately. This is useful for:
- Setting up a payment method before a subscription starts
- Adding a backup payment method
- Capturing payment details for future invoicing

```elixir
{:ok, session} = LatticeStripe.Checkout.Session.create(client, %{
  "mode" => "setup",
  "success_url" => "https://example.com/payment-method-saved",
  "cancel_url" => "https://example.com/cancel",
  "customer" => "cus_OtVFqSomeStripeId"
})
```

After setup, the `checkout.session.completed` webhook contains a `setup_intent` field with
the ID of the resulting SetupIntent. Use it to retrieve the saved PaymentMethod:

```elixir
def handle_setup_complete(event) do
  session = event.data["object"]
  setup_intent_id = session["setup_intent"]

  {:ok, setup_intent} = LatticeStripe.SetupIntent.retrieve(client, setup_intent_id)
  payment_method_id = setup_intent.payment_method

  # Attach this payment method to the customer and set as default
  LatticeStripe.PaymentMethod.attach(client, payment_method_id, %{
    "customer" => session["customer"]
  })
end
```

## Retrieving Sessions

Retrieve a session by ID to check its status and access payment details:

```elixir
{:ok, session} = LatticeStripe.Checkout.Session.retrieve(client, "cs_test_...")
IO.puts("Status: #{session.status}")
IO.puts("Payment status: #{session.payment_status}")
```

### Expanding Fields

Some fields on a Checkout Session require explicit expansion. For example, to get line
items inline (rather than making a separate request):

```elixir
{:ok, session} = LatticeStripe.Checkout.Session.retrieve(client, "cs_test_...",
  expand: ["line_items"]
)

# session.line_items is now populated
```

## Listing Sessions

```elixir
{:ok, resp} = LatticeStripe.Checkout.Session.list(client, %{
  "limit" => 20,
  "customer" => "cus_OtVFqSomeStripeId"
})

sessions = resp.data.data
IO.puts("Found #{length(sessions)} sessions")
```

### Auto-Pagination with Streams

For processing large numbers of sessions:

```elixir
client
|> LatticeStripe.Checkout.Session.stream!(%{"created" => %{"gte" => thirty_days_ago}})
|> Stream.filter(fn s -> s.payment_status == "paid" end)
|> Enum.each(&send_receipt/1)
```

## Expiring Sessions

A Checkout Session stays open for 24 hours by default. If you need to cancel an open
session before it expires — for example, when a user abandons it or an item goes out
of stock — call `Session.expire/3`:

```elixir
{:ok, expired} = LatticeStripe.Checkout.Session.expire(client, "cs_test_...")
IO.puts("Status: #{expired.status}")
# Status: expired
```

Expired sessions cannot be reopened. Create a new session if you need to retry.

## Listing Line Items

Retrieve the line items for a completed session — useful for building receipts or order
summaries:

```elixir
{:ok, resp} = LatticeStripe.Checkout.Session.list_line_items(client, session.id)
items = resp.data.data  # [%LatticeStripe.Checkout.LineItem{}, ...]

Enum.each(items, fn item ->
  IO.puts("#{item.description}: #{item.amount_total} #{item.currency} x#{item.quantity}")
end)
```

For large numbers of line items, use the stream variant:

```elixir
client
|> LatticeStripe.Checkout.Session.stream_line_items!(session.id)
|> Enum.each(&process_line_item/1)
```

## Common Pitfalls

**`success_url` and `cancel_url` are required for all modes.**
Omitting them produces an `ArgumentError` before the request is even sent. Both must be
absolute URLs (starting with `https://`).

**`mode` must be `"payment"`, `"subscription"`, or `"setup"` — validated pre-network.**
LatticeStripe validates the `mode` parameter before making any HTTP request. An invalid
or missing mode raises `ArgumentError` immediately — you won't see this as a Stripe API
error.

**Session URLs expire after 24 hours.**
The `session.url` is only valid for 24 hours. Don't cache it. If a customer clicks a
stale link, redirect them through your checkout flow again to create a fresh session.

**Use webhooks to confirm payment completion — don't rely on the redirect.**
Customers can close their browser before being redirected to `success_url`, or the
redirect URL can fail. The only reliable way to know a payment succeeded is the
`checkout.session.completed` webhook event. See [Webhooks](webhooks.html).

**Subscription mode requires a recurring price, not a one-time price.**
If you use a one-time price with `"mode" => "subscription"`, Stripe returns a 400 error.
Create a Price with `"recurring" => %{"interval" => "month"}` for subscription line items.

## See also

- [Payments](payments.md) — PaymentIntent-based flows when you need full control
- [Subscriptions](subscriptions.md) — lifecycle management after subscription-mode checkout
- [Webhooks](webhooks.md) — `checkout.session.completed` confirmation handling
