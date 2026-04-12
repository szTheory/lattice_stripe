# Invoices

LatticeStripe provides full Invoice lifecycle management — from creating draft invoices to
collecting payment. This guide walks through the common workflows, collection methods, and
pitfalls.

For the Stripe object reference, see the
[Stripe Invoice API](https://docs.stripe.com/api/invoices).

## The Invoice Workflow

The canonical workflow for manually managed invoices follows four steps:

1. Create a **draft invoice** with `auto_advance: false`
2. Add **line items** via `InvoiceItem.create/3`
3. **Finalize** the invoice with `Invoice.finalize/4` — locks line items, moves to `open`
4. **Collect payment** with `Invoice.pay/4`

```elixir
client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

# Step 1 — Create a draft invoice
# Always set auto_advance: false for manually managed invoices (see Auto-Advance section)
{:ok, invoice} = LatticeStripe.Invoice.create(client, %{
  "customer" => "cus_OtVFqSomeStripeId",
  "auto_advance" => false,
  "collection_method" => "charge_automatically",
  "description" => "Consulting services — Q1 2026"
})

IO.puts("Draft invoice #{invoice.id}, status: #{invoice.status}")
# Draft invoice in_3PxYZ2eZvKYlo2C1FRzQc8s, status: draft

# Step 2 — Add items to the draft invoice
{:ok, _item} = LatticeStripe.InvoiceItem.create(client, %{
  "customer" => "cus_OtVFqSomeStripeId",
  "invoice" => invoice.id,
  "amount" => 15_000,
  "currency" => "usd",
  "description" => "Architecture review"
})

{:ok, _item2} = LatticeStripe.InvoiceItem.create(client, %{
  "customer" => "cus_OtVFqSomeStripeId",
  "invoice" => invoice.id,
  "amount" => 35_000,
  "currency" => "usd",
  "description" => "Implementation (7h @ $50/h)"
})

# Step 3 — Finalize: locks line items, transitions draft -> open
{:ok, open_invoice} = LatticeStripe.Invoice.finalize(client, invoice.id)

IO.puts("Finalized: #{open_invoice.status}, amount due: $#{open_invoice.amount_due / 100}")
# Finalized: open, amount due: $500.00

# Step 4 — Pay the invoice against the customer's default payment method
{:ok, paid_invoice} = LatticeStripe.Invoice.pay(client, open_invoice.id)

IO.puts("Status: #{paid_invoice.status}")
# Status: paid
```

The Invoice status machine:

```
draft --> (finalize) --> open --> (pay) --> paid
                           |
                         (void) --> void
                           |
                   (mark_uncollectible) --> uncollectible
```

## Collection Methods

Stripe invoices support two collection methods, set at creation time via `"collection_method"`:

**`:charge_automatically`** — Stripe charges the customer's default payment method automatically
when the invoice is paid. This is the default.

```elixir
{:ok, invoice} = LatticeStripe.Invoice.create(client, %{
  "customer" => "cus_OtVFqSomeStripeId",
  "auto_advance" => false,
  "collection_method" => "charge_automatically"
})
```

**`:send_invoice`** — Stripe emails the invoice to the customer. The customer pays via a
hosted Stripe payment page. Requires `days_until_due`.

```elixir
{:ok, invoice} = LatticeStripe.Invoice.create(client, %{
  "customer" => "cus_OtVFqSomeStripeId",
  "auto_advance" => false,
  "collection_method" => "send_invoice",
  "days_until_due" => 30
})

# After finalization, send the email to the customer
{:ok, _} = LatticeStripe.Invoice.finalize(client, invoice.id)
{:ok, sent} = LatticeStripe.Invoice.send_invoice(client, invoice.id)

IO.puts("Sent. Customer visits: #{sent.hosted_invoice_url}")
```

> **Note:** `send_invoice` without `days_until_due` returns a Stripe validation error.
> Always include it when using this collection method.

## Auto-Advance Behavior

**This is the most common footgun with Stripe invoices.**

When `auto_advance` is `true` (or omitted), Stripe automatically finalizes the draft invoice
after approximately 1 hour. This means if you create a draft, add items over the next 2 hours,
Stripe may already finalize the invoice before you're done — and you can no longer add items to
a finalized invoice.

LatticeStripe emits a telemetry warning when `Invoice.create/3` is called and the returned
invoice has `auto_advance: true`:

```elixir
# Attach the default logger in your application.ex start/2 callback:
LatticeStripe.Telemetry.attach_default_logger()

# Now any invoice created without explicit auto_advance: false will emit:
# [warning] Invoice in_xxx created with auto_advance: true — Stripe will auto-finalize in
#           ~1 hour. Set auto_advance: false for draft invoices you plan to modify.
{:ok, _invoice} = LatticeStripe.Invoice.create(client, %{
  "customer" => "cus_xxx"
  # auto_advance omitted — will log a warning
})
```

**Recommendation:** Always pass `"auto_advance" => false` when creating invoices you plan to
modify before collecting payment.

```elixir
# Safe — no auto-finalization warning
{:ok, invoice} = LatticeStripe.Invoice.create(client, %{
  "customer" => "cus_xxx",
  "auto_advance" => false
})
```

## Working with Invoice Items

InvoiceItems are the mechanism for adding charges to a draft invoice before finalization.
Each `InvoiceItem.create/3` call creates a standalone billable line attached to the target
invoice.

```elixir
# Create an InvoiceItem with a fixed amount
{:ok, item} = LatticeStripe.InvoiceItem.create(client, %{
  "customer" => "cus_OtVFqSomeStripeId",
  "invoice" => invoice.id,
  "amount" => 5000,
  "currency" => "usd",
  "description" => "One-time setup fee"
})

IO.puts("Created #{item.id}")
# Created ii_3PxYZ2eZvKYlo2C1aAbBcCdD

# Create an InvoiceItem referencing an existing Price
{:ok, item2} = LatticeStripe.InvoiceItem.create(client, %{
  "customer" => "cus_OtVFqSomeStripeId",
  "invoice" => invoice.id,
  "price" => "price_H5ggYwtDq4fbrJ",
  "quantity" => 3
})
```

### InvoiceItem vs Invoice Line Item

These are different things:

| | `InvoiceItem` | `Invoice.LineItem` |
|---|---|---|
| **ID prefix** | `ii_...` | `il_...` |
| **Resource path** | `/v1/invoiceitems` | N/A — read-only |
| **Mutable?** | Yes (until finalized) | No |
| **How accessed** | `InvoiceItem.create/3`, `.retrieve/3`, etc. | `Invoice.list_line_items/4` |
| **Purpose** | Add charges to a draft | Rendered rows on a finalized invoice |

After finalization, use `Invoice.list_line_items/4` to read the locked line items:

```elixir
{:ok, resp} = LatticeStripe.Invoice.list_line_items(client, invoice.id)
line_items = resp.data.data

Enum.each(line_items, fn li ->
  IO.puts("#{li.description}: #{li.amount}")
end)
```

### `price` vs `price_data`

You can reference an existing Price by ID or pass inline pricing without a pre-created Price:

```elixir
# Reference existing Price
LatticeStripe.InvoiceItem.create(client, %{
  "customer" => "cus_xxx",
  "invoice" => invoice.id,
  "price" => "price_H5ggYwtDq4fbrJ"
})

# Or pass inline price_data (no pre-created Price needed)
LatticeStripe.InvoiceItem.create(client, %{
  "customer" => "cus_xxx",
  "invoice" => invoice.id,
  "price_data" => %{
    "currency" => "usd",
    "product" => "prod_OtVFqSomeStripeId",
    "unit_amount" => 2500
  }
})
```

### Item Limit

Stripe enforces a limit of 250 line items per invoice. For large invoices, consider summarizing
charges at the description level rather than creating one item per unit.

## Draft Invoice Management

Draft invoices support full mutation before finalization:

```elixir
# Update metadata or description on a draft
{:ok, updated} = LatticeStripe.Invoice.update(client, invoice.id, %{
  "description" => "Updated: Consulting services — Q1 2026",
  "metadata" => %{"project_id" => "proj_789"}
})

# Update an InvoiceItem (draft only)
{:ok, _} = LatticeStripe.InvoiceItem.update(client, item.id, %{
  "amount" => 6000,
  "description" => "One-time setup fee (revised)"
})

# Remove an InvoiceItem (draft only)
{:ok, _} = LatticeStripe.InvoiceItem.delete(client, item.id)

# Delete the entire draft invoice (only works on drafts)
{:ok, deleted_invoice} = LatticeStripe.Invoice.delete(client, invoice.id)
IO.puts("Deleted: #{deleted_invoice.deleted}")
# Deleted: true
```

Once finalized, all of the above operations fail. To cancel a finalized invoice, use
`Invoice.void/4` instead of `Invoice.delete/3`.

## Action Verbs

After finalization, drive the invoice through its lifecycle:

### Finalize

Transitions draft → open. Locks line items. Generates the hosted invoice URL.

```elixir
{:ok, open_invoice} = LatticeStripe.Invoice.finalize(client, invoice.id)

IO.puts("Status: #{open_invoice.status}")
# Status: open
IO.puts("Hosted page: #{open_invoice.hosted_invoice_url}")
```

### Pay

Attempts payment for an open invoice.

```elixir
# Charge the customer's default payment method
{:ok, paid} = LatticeStripe.Invoice.pay(client, invoice.id)

# Pay out-of-band (mark as paid without charging via Stripe)
{:ok, paid} = LatticeStripe.Invoice.pay(client, invoice.id, %{
  "paid_out_of_band" => true
})

# Pay with a specific payment method
{:ok, paid} = LatticeStripe.Invoice.pay(client, invoice.id, %{
  "payment_method" => "pm_card_visa"
})
```

### Void

Cancels an open invoice permanently. The invoice stays visible in Stripe but can no longer
be collected.

```elixir
{:ok, voided} = LatticeStripe.Invoice.void(client, invoice.id)

IO.puts("Status: #{voided.status}")
# Status: void
```

### Mark Uncollectible

Marks an open invoice as uncollectible — Stripe treats the amount as a write-off.

```elixir
{:ok, result} = LatticeStripe.Invoice.mark_uncollectible(client, invoice.id)

IO.puts("Status: #{result.status}")
# Status: uncollectible
```

### Send Invoice

Sends the invoice email to the customer (only applicable for `send_invoice` collection method):

```elixir
{:ok, sent} = LatticeStripe.Invoice.send_invoice(client, invoice.id)

IO.puts("Sent. Customer visits: #{sent.hosted_invoice_url}")
```

All action verbs follow `{:ok, %Invoice{}} | {:error, %LatticeStripe.Error{}}` and have bang
variants (`finalize!/4`, `pay!/4`, `void!/4`, `send_invoice!/4`, `mark_uncollectible!/4`).

## Proration Preview

Before confirming a subscription change that affects the billing amount, preview what the
next invoice will look like using `Invoice.upcoming/3` or `Invoice.create_preview/3`.

```elixir
# Preview what the next invoice looks like for a subscription upgrade
{:ok, preview} = LatticeStripe.Invoice.upcoming(client, %{
  "customer" => "cus_xxx",
  "subscription" => "sub_xxx",
  "subscription_items" => [%{"id" => "si_xxx", "price" => "price_new"}],
  "subscription_proration_behavior" => "create_prorations"
})

# preview.id is nil — this is a preview, not a persisted invoice
IO.inspect(preview.id)
# nil

# preview.lines contains the projected line items
Enum.each(preview.lines.data, fn line ->
  IO.puts("#{line.description}: #{line.amount}")
end)
```

> **Deprecation:** Stripe is deprecating `upcoming` in favor of `create_preview`. Use
> `Invoice.create_preview/3` for new integrations.

```elixir
# Preferred: create_preview uses the new endpoint
{:ok, preview} = LatticeStripe.Invoice.create_preview(client, %{
  "customer" => "cus_xxx",
  "subscription_details" => %{
    "items" => [%{"id" => "si_xxx", "price" => "price_new"}],
    "proration_behavior" => "create_prorations"
  }
})
```

### Strict Proration Mode

For SaaS applications where accidental proration can cause unexpected billing, configure the
client to require an explicit `proration_behavior` in all preview requests:

```elixir
client = LatticeStripe.Client.new!(
  api_key: "sk_live_...",
  finch: MyApp.Finch,
  require_explicit_proration: true
)

# Without proration_behavior, the guard returns an error before making a network call
case LatticeStripe.Invoice.upcoming(client, %{"customer" => "cus_xxx"}) do
  {:error, %LatticeStripe.Error{type: :proration_required} = err} ->
    IO.puts("Proration behavior required: #{err.message}")

  {:ok, preview} ->
    # proration_behavior was present — proceed
    IO.inspect(preview.amount_due)
end
```

This is purely a client-side guard — no network call is made when the guard fires.

## Subscription-Generated Invoices

Stripe automatically creates invoices for subscriptions at each billing period. The
`billing_reason` field tells you why an invoice was created:

| Value | Meaning |
|-------|---------|
| `:subscription_cycle` | Regular billing period renewal |
| `:subscription_create` | Initial invoice on subscription creation |
| `:subscription_update` | Mid-cycle proration invoice |
| `:subscription_threshold` | Usage-based threshold billing |
| `:manual` | Created via API call |

These invoices follow the same lifecycle (`draft → open → paid`) but are created and
finalized automatically. You generally don't need to call `finalize/4` or `pay/4` for
subscription invoices — Stripe handles them.

To list invoices for a specific subscription:

```elixir
{:ok, resp} = LatticeStripe.Invoice.list(client, %{
  "subscription" => "sub_xxx"
})

invoices = resp.data.data
Enum.each(invoices, fn inv ->
  IO.puts("#{inv.id} — #{inv.billing_reason}: #{inv.status}")
end)
```

To search by status across all invoices:

```elixir
{:ok, resp} = LatticeStripe.Invoice.search(client, %{
  "query" => "status:'open'"
})

open_invoices = resp.data.data
IO.puts("Open invoices: #{length(open_invoices)}")
```

## Testing Invoices with Test Clocks

Use Stripe Test Clocks to simulate the passage of time in your test environment. This is
especially useful for verifying that invoices are created, finalized, and paid on the expected
schedule for subscription customers.

```elixir
# Create a test clock
{:ok, clock} = LatticeStripe.TestClock.create(client, %{
  "frozen_time" => DateTime.utc_now() |> DateTime.to_unix()
})

# Create a customer anchored to the test clock
{:ok, customer} = LatticeStripe.Customer.create(client, %{
  "email" => "alice@example.com",
  "test_clock" => clock.id
})

# Create a subscription for the customer
{:ok, _sub} = LatticeStripe.Subscription.create(client, %{
  "customer" => customer.id,
  "items" => [%{"price" => "price_xxx"}]
})

# Advance the clock past the billing date
one_month_later = clock.frozen_time + 31 * 86_400
{:ok, _} = LatticeStripe.TestClock.advance(client, clock.id, %{
  "frozen_time" => one_month_later
})

# Verify that Stripe created and paid the subscription invoice
{:ok, resp} = LatticeStripe.Invoice.list(client, %{
  "customer" => customer.id,
  "status" => "paid"
})

IO.puts("Paid invoices found: #{length(resp.data.data)}")
```

See the [Billing Test Clocks guide](https://docs.stripe.com/billing/testing/test-clocks) for
full details on advancing time and simulating billing events.

## Listing and Searching

### List with Filters

```elixir
# List all open invoices for a customer
{:ok, resp} = LatticeStripe.Invoice.list(client, %{
  "customer" => "cus_OtVFqSomeStripeId",
  "status" => "open",
  "limit" => 10
})

invoices = resp.data.data
IO.puts("Found #{length(invoices)} open invoices")
```

### Auto-Pagination with Streams

For large datasets, use `stream!/2` to auto-paginate without loading everything into memory:

```elixir
# Sum all paid invoice amounts for a customer in the last 90 days
ninety_days_ago = DateTime.utc_now() |> DateTime.add(-90 * 86_400, :second) |> DateTime.to_unix()

total =
  client
  |> LatticeStripe.Invoice.stream!(%{
    "customer" => "cus_xxx",
    "status" => "paid",
    "created" => %{"gte" => ninety_days_ago}
  })
  |> Stream.map(fn inv -> inv.amount_paid end)
  |> Enum.sum()

IO.puts("Total collected: $#{total / 100}")
```

### Search

```elixir
{:ok, resp} = LatticeStripe.Invoice.search(client, %{
  "query" => "status:'open' AND customer:'cus_OtVFqSomeStripeId'"
})

results = resp.data.data
```

> **Note:** Stripe's Search API has eventual consistency. Newly created invoices may not
> appear in search results for a few seconds. For real-time lookups, use `list/3` with
> filters or `retrieve/3` by ID. See
> [Stripe Search docs](https://docs.stripe.com/search).

## Common Pitfalls

**Always set `auto_advance: false` for draft invoices.**
Stripe automatically finalizes drafts after ~1 hour by default. If you forget, you'll find
your draft is already open before you finish adding items. LatticeStripe logs a warning when
you create an invoice without explicit `auto_advance: false` — don't ignore it.

**You cannot add items to a finalized invoice.**
`InvoiceItem.create/3` requires the target invoice to be in draft status. Once `finalize/4`
is called, the line items are locked. Plan your workflow accordingly: add all items first,
then finalize.

**`send_invoice` without `days_until_due` is a validation error.**
When using `collection_method: "send_invoice"`, always include `"days_until_due"` at creation
time. Stripe will return an error if it's missing when you try to send.

**`delete/3` only works on draft invoices.**
If you've already finalized, you cannot delete the invoice. Use `Invoice.void/4` to cancel
an open invoice. Voided invoices remain visible in the Stripe Dashboard with `status: void`.

**Don't check `invoice.status` to decide which action to call.**
The `status` field on a retrieved struct is a snapshot of that moment. Stripe is the
authority on current state. Call the action verb and handle the error if the invoice is in
an unexpected state — don't build an in-process state machine around it.

**InvoiceItem IDs start with `ii_`, Invoice Line Item IDs start with `il_`.**
They are different resources. Use `InvoiceItem` functions to manage charges on draft invoices.
Use `Invoice.list_line_items/4` to read the rendered rows after finalization.

**Subscription-generated invoices don't need manual finalization.**
If an invoice has `billing_reason` of `:subscription_cycle`, Stripe auto-finalizes and
auto-pays it. Only manually created invoices with `auto_advance: false` need you to call
`finalize/4` and `pay/4`.
