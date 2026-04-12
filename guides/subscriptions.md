# Subscriptions

Stripe Subscriptions represent a customer's recurring charge against one or
more Prices. The LatticeStripe `Subscription` and `SubscriptionItem` modules
provide CRUD, lifecycle transitions, proration control, and search — all
pattern-matchable through typed structs.

See the [Stripe Subscriptions API](https://docs.stripe.com/api/subscriptions)
for the full object reference.

## Creating a subscription

A subscription needs a customer and at least one item pointing at a recurring
Price. Build the Price first (usually at deploy/seed time), then create the
subscription at signup.

```elixir
# At deploy: create Product + recurring Price once.
{:ok, product} = LatticeStripe.Product.create(client, %{"name" => "Pro Plan"})

{:ok, price} =
  LatticeStripe.Price.create(client, %{
    "product" => product.id,
    "currency" => "usd",
    "unit_amount" => 2000,
    "recurring" => %{"interval" => "month"}
  })

# At signup: create Customer + Subscription.
{:ok, customer} =
  LatticeStripe.Customer.create(client, %{"email" => "user@example.com"})

{:ok, sub} =
  LatticeStripe.Subscription.create(
    client,
    %{
      "customer" => customer.id,
      "items" => [%{"price" => price.id, "quantity" => 1}]
    },
    idempotency_key: "signup-#{user.id}"
  )
```

Pass `idempotency_key` in `opts` to make the create retriable. If the same key
is reused, Stripe returns the original subscription rather than creating a
duplicate.

## The subscription lifecycle

```
          (first payment fails permanently)
                    |
incomplete -------> incomplete_expired
    |
    v
trialing -----> active -----> past_due -----> unpaid
                  |              |
                  |            canceled
                  v
                paused
```

| Transition                    | Trigger                                                            |
| ----------------------------- | ------------------------------------------------------------------ |
| `incomplete → active`         | First payment succeeds                                             |
| `trialing → active`           | Trial period ends (driven by Stripe, not SDK)                      |
| `active → past_due`           | Payment attempt fails                                              |
| `past_due → unpaid/canceled`  | Dunning retries exhausted (driven by Stripe settings)              |
| `active → paused`             | `Subscription.pause_collection/5` (SDK-initiated)                  |
| `paused → active`             | `Subscription.resume/3` (SDK-initiated)                            |
| `active → canceled`           | `Subscription.cancel/3` or scheduled `cancel_at` (SDK/time-driven) |

## Lifecycle operations

### `update/4`

Pass any subscription field:

```elixir
Subscription.update(client, sub.id, %{
  "description" => "Upgraded to annual"
})
```

### `cancel/3` and `cancel/4`

`cancel/3` is a convenience for the common case (no params):

```elixir
Subscription.cancel(client, sub.id)
```

`cancel/4` accepts the full Stripe cancel params:

```elixir
Subscription.cancel(client, sub.id, %{
  "prorate" => true,
  "invoice_now" => true,
  "cancellation_details" => %{
    "comment" => "Customer requested via support"
  }
}, [])
```

To schedule a cancellation at the end of the current period, use `update/4`
with `cancel_at_period_end: true` — LatticeStripe deliberately does NOT expose
a separate `cancel_at` helper because it's a one-liner on `update`:

```elixir
Subscription.update(client, sub.id, %{"cancel_at_period_end" => true})
```

### `resume/3`

Resume a paused subscription:

```elixir
Subscription.resume(client, sub.id)
```

### `pause_collection/5`

Pause automatic invoice collection without canceling. The `behavior` argument
is a compile-time atom — only `:keep_as_draft`, `:mark_uncollectible`, and
`:void` are accepted. Any other atom raises `FunctionClauseError`.

```elixir
# Drafts are created but not finalized while paused.
Subscription.pause_collection(client, sub.id, :keep_as_draft)

# Drafts are created and immediately marked uncollectible.
Subscription.pause_collection(client, sub.id, :mark_uncollectible)

# Drafts are created and immediately voided.
Subscription.pause_collection(client, sub.id, :void)

# With a resumes_at timestamp:
Subscription.pause_collection(client, sub.id, :keep_as_draft, %{
  "pause_collection" => %{"resumes_at" => 1_800_000_000}
})
```

## Proration

When you change a subscription's items (swap a price, change quantity, add or
remove items), Stripe prorates charges by default. The default behavior may
surprise users who expect predictable billing.

For safety, configure your client with `require_explicit_proration: true`:

```elixir
strict_client = LatticeStripe.Client.new!(
  api_key: "sk_live_...",
  finch: MyApp.Finch,
  require_explicit_proration: true
)
```

With this flag, LatticeStripe rejects any subscription mutation that does not
carry an explicit `"proration_behavior"` value. The guard detects the param
at any of three locations:

1. **Top level of params:**

   ```elixir
   Subscription.update(strict_client, sub.id, %{
     "proration_behavior" => "create_prorations",
     "items" => [%{"id" => si_id, "quantity" => 2}]
   })
   ```

2. **Inside `subscription_details`** (used by `Invoice.create_preview/3`):

   ```elixir
   Subscription.update(strict_client, sub.id, %{
     "subscription_details" => %{"proration_behavior" => "create_prorations"},
     "items" => [%{"id" => si_id, "quantity" => 2}]
   })
   ```

3. **Inside any element of the `items[]` array:**

   ```elixir
   Subscription.update(strict_client, sub.id, %{
     "items" => [
       %{"id" => si_id, "quantity" => 2, "proration_behavior" => "create_prorations"}
     ]
   })
   ```

If none of the three locations carries `"proration_behavior"`, the SDK returns
`{:error, %LatticeStripe.Error{type: :proration_required}}` without ever
hitting the network. Valid values are `"create_prorations"`, `"always_invoice"`,
and `"none"`.

## SubscriptionItem operations

`LatticeStripe.SubscriptionItem` gives you direct CRUD on individual items.
Use it when you want to add, remove, or change a single line without touching
the rest of the subscription.

```elixir
# Add a new item to an existing subscription.
{:ok, item} = SubscriptionItem.create(client, %{
  "subscription" => sub.id,
  "price" => addon_price.id,
  "quantity" => 1
})

# Change quantity with explicit proration.
{:ok, item} = SubscriptionItem.update(client, item.id, %{
  "quantity" => 3,
  "proration_behavior" => "create_prorations"
})

# Remove with no proration.
{:ok, _} = SubscriptionItem.delete(client, item.id, %{
  "proration_behavior" => "none"
}, [])
```

> #### `list/3` requires the `subscription` param {: .warning}
>
> `SubscriptionItem.list/3` and `SubscriptionItem.stream!/2` both require a
> `"subscription"` key in params. Unfiltered listing is an antipattern — it
> returns items across all subscriptions, which is rarely what you want.
> Calling them with an empty params map raises `ArgumentError` immediately.

## Webhooks own state transitions

> **Important:** The response from any SDK call reflects Stripe's state at the moment of that call. Subscription state transitions (trial ending, payment failing, subscription canceling at period end, dunning retries) are driven by Stripe's internal billing engine, not by SDK calls. **Always drive your application state from webhook events, not from SDK responses.**
>
> LatticeStripe provides `LatticeStripe.Webhook` for signature verification.
> Wire these events into your handler:
>
> - `customer.subscription.updated`
> - `customer.subscription.deleted`
> - `invoice.payment_failed`
> - `invoice.payment_succeeded`

For example, don't set `user.active = true` based on `Subscription.create/3`'s
return value — set it when you receive `customer.subscription.updated` with
`status: "active"`. The SDK call might succeed while the first payment is
still pending; the webhook is the authoritative signal.

## Telemetry

No new telemetry events were added for Subscriptions — subscription state
transitions belong to webhook handlers. LatticeStripe emits the general
`[:lattice_stripe, :request, :start | :stop | :exception]` events for every
HTTP call, including Subscription and SubscriptionItem mutations. See the
[Telemetry guide](telemetry.md) for handler examples.

If you need to observe business-level subscription state, attach to the
`customer.subscription.*` and `invoice.*` webhook events in your application,
not to SDK telemetry.

## PII and logging

`Inspect` on `%LatticeStripe.Subscription{}` deliberately hides:

- `customer` — shown as `has_customer?: true | false`
- `payment_settings` — shown as `has_payment_settings?`
- `default_payment_method` — shown as `has_default_payment_method?`
- `latest_invoice` — shown as `has_latest_invoice?`

`%LatticeStripe.Subscription.CancellationDetails{}` masks the `comment` field
as `"[FILTERED]"` in its `Inspect` output, since customer-provided comments
may contain personal information. The raw value remains accessible via
`struct.comment` for code that explicitly needs it — just avoid logging it.

Similarly, `%LatticeStripe.SubscriptionItem{}` masks `metadata` and
`billing_thresholds` as `:present` markers when populated.
