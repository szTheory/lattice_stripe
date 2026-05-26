# Quote to Billing Operator Flow

Use this guide when sales or operations needs one concrete path for turning a quote into
downstream billing work without pretending quote acceptance settles the whole billing
story.

This is a workflow playbook, not a second API reference. It shows one bounded operator
path, keeps the proof boundary at the action point where overconfidence usually starts,
and routes you back to the canonical billing guides for deeper surface detail.

## Why this is the recommended operator path

The strongest default is:

1. Create the quote.
2. Finalize it so the customer can act on it.
3. Accept it with the explicit `Quote.accept/3` step.
4. Inspect the returned quote for one downstream reference in this order:
   `invoice`, `subscription`, `subscription_schedule`.
5. Retrieve at most one linked resource.
6. Hand durable follow-through truth to webhooks and any later authoritative reads.

That gives serious evaluators a real next operator move while keeping the SDK boundary
honest.

## The quote-to-billing spine

```text
Quote.create
  -> Quote.finalize
  -> Quote.accept
  -> inspect invoice | subscription | subscription_schedule
  -> retrieve one linked downstream resource if present
  -> webhook-confirmed billing follow-through
```

## 1. Create the quote from the billing shape you want to propose

```elixir
{:ok, quote} =
  LatticeStripe.Quote.create(client, %{
    "customer" => customer_id,
    "line_items" => [
      %{
        "price_data" => %{
          "currency" => "usd",
          "product_data" => %{"name" => "Pro annual"},
          "unit_amount" => 24_000,
          "recurring" => %{"interval" => "year"}
        },
        "quantity" => 1
      }
    ]
  })
```

The create response tells you Stripe accepted the draft quote request. It does not tell
you anything yet about downstream invoice, subscription, or provisioning truth.

## 2. Finalize the quote before the customer acts on it

```elixir
{:ok, finalized_quote} = LatticeStripe.Quote.finalize(client, quote.id, %{})
```

This is the right place to stop and let your application hand the quote to the operator
or customer path you already own. The guide does not invent a second sharing or UI layer.

## 3. Accept the quote with the explicit transition verb

```elixir
{:ok, accepted_quote} = LatticeStripe.Quote.accept(client, finalized_quote.id)
```

Accepting a quote proves Stripe accepted the quote transition. It does **not** prove that
invoice payment, subscription activation, provisioning, or customer-visible billing state
is fully settled.

## 4. Inspect the returned quote for one bounded downstream reference

Check the accepted quote in this order:

1. `invoice`
2. `subscription`
3. `subscription_schedule`

```elixir
downstream_ref =
  cond do
    is_binary(accepted_quote.invoice) ->
      {:invoice, accepted_quote.invoice}

    is_binary(accepted_quote.subscription) ->
      {:subscription, accepted_quote.subscription}

    is_binary(accepted_quote.subscription_schedule) ->
      {:subscription_schedule, accepted_quote.subscription_schedule}

    true ->
      :none
  end
```

Do not assume every accepted quote yields the same downstream object type. The result
depends on the quote shape and the Stripe billing path it triggers.

## 5. Retrieve at most one linked downstream resource

One concrete retrieval step is enough for the operator path:

```elixir
case downstream_ref do
  {:invoice, invoice_id} ->
    {:ok, invoice} = LatticeStripe.Invoice.retrieve(client, invoice_id)
    invoice

  {:subscription, subscription_id} ->
    {:ok, subscription} = LatticeStripe.Subscription.retrieve(client, subscription_id)
    subscription

  {:subscription_schedule, schedule_id} ->
    {:ok, schedule} = LatticeStripe.SubscriptionSchedule.retrieve(client, schedule_id)
    schedule

  :none ->
    nil
end
```

That retrieval is for bounded operator inspection, not for inventing a read-after-write
guarantee that the whole downstream billing lifecycle is now closed.

## 6. Hand durable follow-through truth to webhooks

After acceptance, the durable billing story still belongs to webhook-confirmed events and
later authoritative reads for the exact workflow you operate.

- Use invoice events for payment and collection truth.
- Use subscription events for lifecycle and status truth.
- Use your local job or operator flow to decide what downstream follow-up matters.

The important boundary is simple: `Quote.accept/3` tells you Stripe accepted the quote
transition now. Webhooks and follow-up reads tell you what became true downstream.

## 7. Keep the guide boundary honest

This guide stops before entitlement logic, dunning policy, local provisioning rules,
operator UI ownership, or app-level billing orchestration. LatticeStripe gives you the
Quote primitives and typed downstream retrieval surfaces. Your application still owns the
workflow that reacts to them.

## Read next

- [Invoices](invoices.md)
- [Subscriptions](subscriptions.md)
- [Webhooks](webhooks.md)
- [Recipes](recipes.md)
- [LatticeStripe.Quote](LatticeStripe.Quote.html)
