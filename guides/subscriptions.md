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

## Subscription Schedules

A Subscription Schedule defines a phased billing timeline. Each phase
specifies the prices, quantities, proration behavior, and trial settings
for a slice of time. When a phase ends, the schedule automatically
transitions to the next.

Use schedules for flows like:

- Free trial → discounted intro price → full price
- Annual → monthly transition
- Step-up pricing as usage grows
- Contract-based fixed-term subscriptions

See the [Stripe Subscription Schedules API](https://docs.stripe.com/api/subscription_schedules)
for the full object reference.

### When to use a Subscription Schedule

Reach for a schedule when you need _deterministic_ future billing changes
at known dates. For ad-hoc changes driven by user actions (upgrades,
cancellations), use `LatticeStripe.Subscription.update/4` directly.

### Creation modes

Stripe accepts two mutually-exclusive parameter shapes on create.

**Mode 1: from_subscription**

Convert an existing Subscription into a schedule whose first phase
captures the subscription's current state.

```elixir
LatticeStripe.SubscriptionSchedule.create(client, %{
  "from_subscription" => "sub_1234567890"
})
```

**Mode 2: customer + phases**

Build a new schedule from scratch with an explicit phase timeline.

```elixir
LatticeStripe.SubscriptionSchedule.create(client, %{
  "customer" => "cus_1234567890",
  "start_date" => "now",
  "end_behavior" => "release",
  "phases" => [
    %{
      "items" => [%{"price" => "price_intro", "quantity" => 1}],
      "iterations" => 3,
      "proration_behavior" => "create_prorations"
    },
    %{
      "items" => [%{"price" => "price_full", "quantity" => 1}],
      "iterations" => 12
    }
  ]
})
```

Mixing `from_subscription` with `customer`/`phases` in a single call
raises a Stripe 400 that surfaces as
`{:error, %LatticeStripe.Error{type: :invalid_request_error}}`.
LatticeStripe does not client-side-validate the mode — Stripe's own error
message is already actionable.

### cancel vs release

Two different ways to end phased billing.

**`cancel/4`** terminates BOTH the schedule AND the underlying
Subscription. Both entities move to `canceled` status.

```elixir
LatticeStripe.SubscriptionSchedule.cancel(client, sched.id, %{
  "invoice_now" => true,
  "prorate" => true
})
```

**`release/4`** detaches the schedule from its Subscription. The
Subscription remains active and billable but is no longer phase-governed
— subsequent configuration changes must go through
`LatticeStripe.Subscription.update/4` directly. **This is irreversible.**

```elixir
LatticeStripe.SubscriptionSchedule.release(client, sched.id)
```

Use `release/4` when you want to graduate a subscription off a phased
plan into a flat ongoing subscription. Use `cancel/4` when you want to
end billing entirely.

Both dispatch `POST` to `/v1/subscription_schedules/:id/{cancel,release}`
— not `DELETE` (which is what `LatticeStripe.Subscription.cancel/4` uses).
This difference matters if you're reading wire logs.

### Proration on update

When a client has `require_explicit_proration: true`, `update/4` requires
`proration_behavior` at either the top level of `params` OR inside any
element of `params["phases"][]`:

```elixir
LatticeStripe.SubscriptionSchedule.update(client, sched.id, %{
  "phases" => [
    %{
      "items" => [%{"price" => "price_full"}],
      "proration_behavior" => "create_prorations"
    }
  ]
})
```

Stripe does NOT accept `proration_behavior` at `phases[].items[]` — only
at top-level and per-phase. The guard reflects this wire shape and does
not walk deeper. If your Phase 15 Subscription mutations worked, your
Phase 16 Schedule mutations use the same mental model — just one level
deeper into `phases[]`.

### Webhook-driven state transitions

As with Subscriptions (Phase 15), **drive your application state from
webhook events, not from SDK responses**. An SDK response reflects the
state at the moment of the call, but Stripe may transition the schedule
moments later (phase boundaries, billing failures, automatic release,
etc.).

Wire `subscription_schedule.created`, `subscription_schedule.updated`,
`subscription_schedule.canceled`, `subscription_schedule.released`, and
`subscription_schedule.aborted` into your webhook handler via
`LatticeStripe.Webhook`.

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
