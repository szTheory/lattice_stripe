# Payments

This guide walks through the complete payment lifecycle in LatticeStripe — from creating
a customer to confirming a payment to issuing refunds. For an overview of Stripe's payment
model, see the [Stripe Payments documentation](https://docs.stripe.com/payments).

## Creating a Customer

Customers let you associate payments, subscriptions, and payment methods with a person or
business. Creating a customer before charging is recommended — it enables features like
saving payment methods and listing past charges.

```elixir
{:ok, customer} = LatticeStripe.Customer.create(client, %{
  "email" => "alice@example.com",
  "name" => "Alice Johnson",
  "phone" => "+1-555-123-4567",
  "metadata" => %{
    "user_id" => "usr_123",
    "plan" => "pro"
  }
})

IO.puts("Created customer: #{customer.id}")
# Created customer: cus_OtVFqSomeStripeId
```

`metadata` is a hash of up to 50 key/value string pairs. Use it to link Stripe objects
back to your own data model — it shows up in the Stripe Dashboard and is returned on
every fetch.

### Retrieving and Updating Customers

```elixir
# Retrieve a customer by ID
{:ok, customer} = LatticeStripe.Customer.retrieve(client, "cus_OtVFqSomeStripeId")

# Update the customer's name and metadata
{:ok, updated} = LatticeStripe.Customer.update(client, customer.id, %{
  "name" => "Alice Smith",
  "metadata" => %{"plan" => "enterprise"}
})
```

## Creating a PaymentIntent

A [PaymentIntent](https://docs.stripe.com/api/payment_intents) represents your intent to
collect payment from a customer. It tracks the lifecycle of the payment and handles
retries, 3D Secure authentication, and more.

```elixir
{:ok, intent} = LatticeStripe.PaymentIntent.create(client, %{
  "amount" => 4999,
  "currency" => "usd",
  "customer" => customer.id,
  "description" => "Pro plan subscription",
  "metadata" => %{"order_id" => "ord_456"}
})

IO.puts("PaymentIntent #{intent.id} — status: #{intent.status}")
# PaymentIntent pi_3OzqKZ2eZvKYlo2C1FRzQc8s — status: requires_payment_method
```

**Amount is always in the smallest currency unit.** For USD, that's cents: `4999` = $49.99.
For JPY (zero-decimal currency), `4999` = ¥4,999.

### Automatic vs. Manual Confirmation

By default, Stripe expects you to confirm the PaymentIntent from your client-side
(frontend) code using Stripe.js. For server-side confirmation (e.g., backend-only flows
or Stripe Connect), use `confirmation_method: "manual"`:

```elixir
{:ok, intent} = LatticeStripe.PaymentIntent.create(client, %{
  "amount" => 4999,
  "currency" => "usd",
  "confirmation_method" => "manual",
  "payment_method" => "pm_card_visa"
})
```

## Confirming a PaymentIntent

For manually-confirmed PaymentIntents, call `confirm/3` to attempt payment:

```elixir
case LatticeStripe.PaymentIntent.confirm(client, intent.id, %{
  "payment_method" => "pm_card_visa"
}) do
  {:ok, confirmed} ->
    case confirmed.status do
      "succeeded" ->
        IO.puts("Payment succeeded!")

      "requires_action" ->
        IO.puts("3D Secure required — redirect to: #{confirmed.next_action["redirect_to_url"]["url"]}")

      other ->
        IO.puts("Unexpected status: #{other}")
    end

  {:error, %LatticeStripe.Error{type: :card_error} = err} ->
    IO.puts("Card declined: #{err.message}")
    IO.puts("Decline code: #{err.decline_code}")
end
```

The PaymentIntent status machine:
- `requires_payment_method` → attach a payment method
- `requires_confirmation` → call `confirm/3`
- `requires_action` → customer must complete authentication (e.g., 3D Secure)
- `processing` → payment is being processed (async)
- `succeeded` → payment successful
- `canceled` → terminal state

## Capturing a PaymentIntent (Manual Capture)

If you need to authorize a payment now but capture funds later — for example, when
fulfillment happens after checkout — create the PaymentIntent with
`capture_method: "manual"`:

```elixir
# Step 1: Authorize (hold funds on the card, don't capture yet)
{:ok, intent} = LatticeStripe.PaymentIntent.create(client, %{
  "amount" => 4999,
  "currency" => "usd",
  "payment_method" => "pm_card_visa",
  "capture_method" => "manual",
  "confirm" => true
})

IO.puts("Authorized: #{intent.status}")
# Authorized: requires_capture

# (Later, once the order ships or service is fulfilled)

# Step 2: Capture the authorized funds
{:ok, captured} = LatticeStripe.PaymentIntent.capture(client, intent.id)
IO.puts("Captured: #{captured.status}")
# Captured: succeeded
```

You can also capture a partial amount:

```elixir
{:ok, captured} = LatticeStripe.PaymentIntent.capture(client, intent.id, %{
  "amount_to_capture" => 2500  # Capture only $25.00 instead of $49.99
})
```

Uncaptured authorizations automatically expire after 7 days (or 2 days for some card
networks). See [Stripe's capture docs](https://docs.stripe.com/payments/capture-later).

## Canceling a PaymentIntent

Cancel a PaymentIntent that hasn't succeeded or been captured yet:

```elixir
{:ok, canceled} = LatticeStripe.PaymentIntent.cancel(client, intent.id, %{
  "cancellation_reason" => "abandoned"
})

IO.puts("Status: #{canceled.status}")
# Status: canceled
```

Valid cancellation reasons: `"duplicate"`, `"fraudulent"`, `"requested_by_customer"`,
`"abandoned"`. The `canceled` status is terminal — you cannot revive a canceled
PaymentIntent.

## Listing and Searching

### Listing with Filters

```elixir
# List recent PaymentIntents for a specific customer
{:ok, resp} = LatticeStripe.PaymentIntent.list(client, %{
  "customer" => customer.id,
  "limit" => 10
})

intents = resp.data.data
IO.puts("Found #{length(intents)} PaymentIntents")
```

### Auto-Pagination with Streams

For large datasets, use `stream!/2` to lazily auto-paginate through all results without
loading everything into memory at once:

```elixir
# Process all succeeded PaymentIntents in the last 30 days
client
|> LatticeStripe.PaymentIntent.stream!(%{"created" => %{"gte" => thirty_days_ago}})
|> Stream.filter(fn intent -> intent.status == "succeeded" end)
|> Stream.map(fn intent -> intent.amount end)
|> Enum.sum()
|> then(fn total -> IO.puts("Total revenue: $#{total / 100}") end)
```

`stream!/2` fetches pages lazily — it only makes an HTTP request when the stream needs more
items. This is memory-efficient for exporting large datasets.

### Search

Use `search/2` for full-text search across PaymentIntents:

```elixir
{:ok, resp} = LatticeStripe.PaymentIntent.search(client, %{
  "query" => "metadata['order_id']:'ord_456'"
})

results = resp.data.data
```

> **Note:** Stripe's Search API has eventual consistency. Newly created objects may not
> appear in search results immediately. For real-time lookups, use `list/3` with filters or
> `retrieve/3` by ID. See [Stripe Search docs](https://docs.stripe.com/search).

## Refunding a Payment

To return funds to a customer, create a Refund referencing the original PaymentIntent:

### Full Refund

```elixir
{:ok, refund} = LatticeStripe.Refund.create(client, %{
  "payment_intent" => intent.id,
  "reason" => "requested_by_customer"
})

IO.puts("Refund #{refund.id} — status: #{refund.status}")
# Refund re_3OzqKZ2eZvKYlo2C1FRzQc8s — status: succeeded
```

### Partial Refund

Specify an `amount` to refund only part of the original charge:

```elixir
# Refund $10.00 of a $49.99 payment
{:ok, refund} = LatticeStripe.Refund.create(client, %{
  "payment_intent" => intent.id,
  "amount" => 1000
})
```

### Refund Reasons

Valid reasons: `"duplicate"`, `"fraudulent"`, `"requested_by_customer"`. The reason affects
how the refund appears in the Stripe Dashboard and any reporting. Omitting the reason is
also valid.

### Listing Refunds

```elixir
{:ok, resp} = LatticeStripe.Refund.list(client, %{
  "payment_intent" => intent.id
})

refunds = resp.data.data
```

## Working with Idempotency Keys

Idempotency keys make retries safe. If a network failure causes you to lose the response
from a `create` call, you can retry with the same key — Stripe will return the original
result rather than creating a duplicate.

LatticeStripe automatically generates a UUID-based idempotency key for every POST request.
The key is reused across all retry attempts for that request, so automatic retries are
always safe.

For operations tied to your own IDs — where you want to guarantee "this specific payment
was created exactly once" — provide your own key:

```elixir
{:ok, intent} = LatticeStripe.PaymentIntent.create(client, %{
  "amount" => 4999,
  "currency" => "usd",
  "customer" => customer.id
},
  idempotency_key: "payment-intent-order-#{order.id}"
)
```

If you call this again with the same `order.id` (e.g., after a server restart), Stripe
returns the original PaymentIntent rather than creating a new one — you can't accidentally
double-charge a customer.

**Key uniqueness rules:**
- Keys must be unique per API endpoint (not globally)
- Reusing a key with different parameters returns a 409 error
- Keys expire after 24 hours — after that, a new request with the same key starts fresh
- For automatic retries, the same key is reused — don't generate a new key per attempt

## Common Pitfalls

**Amount is in the smallest currency unit (cents for USD).**
`4999` means $49.99, not $4,999. Always think in cents when working with Stripe. This is
the single most common mistake when integrating Stripe for the first time.

**PaymentIntent status machine — transitions only go one direction.**
You can't capture a canceled PaymentIntent. You can't confirm an already-succeeded one.
Always check `intent.status` before performing an action, and handle the case where the
intent is in an unexpected state.

**Idempotency keys must be unique per distinct request.**
If you want to create two different payments for the same customer on the same order, use
different keys (e.g., include a line item ID). Reusing a key with different params returns
a 409 conflict, not a new payment.

**Automatic confirmation vs. manual confirmation.**
By default, Stripe uses "automatic" confirmation, which expects your frontend (Stripe.js)
to confirm the payment. If you're building a server-side-only flow, set
`confirmation_method: "manual"` so you can confirm from your backend. Getting this wrong
leads to `requires_confirmation` status that never resolves.

**Search API has eventual consistency.**
Newly created objects may not appear in search results for up to a few seconds. Don't use
search for real-time workflows — use `retrieve/3` or `list/3` with filters instead. See
[Stripe's search documentation](https://docs.stripe.com/search) for consistency guarantees.
