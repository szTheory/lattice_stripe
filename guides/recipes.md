# Recipes

This guide is a compact bridge between [User Flows & JTBD](user-flows-and-jtbd.md)
and the deeper resource guides. It stays library-scoped on purpose: the goal is to
show which LatticeStripe calls usually matter, where the webhook confirmation point
lives, and which guide to read next.

Use it when you already know the job you are trying to ship but still want the canonical
guide for the deeper API and runtime truth:

- recurring billing and self-serve changes:
  [Checkout Signup and Portal Follow-Through](checkout-signup-and-portal.md),
  [Subscriptions](subscriptions.md), [Customer Portal](customer-portal.md),
  [Webhooks](webhooks.md)
- usage-based billing and reconciliation:
  [Metering Runtime and Reconciliation](metering-runtime-and-reconciliation.md),
  [Metering](metering.md), [Webhooks](webhooks.md), [Testing](testing.md)
- platform onboarding and money movement:
  [Connect Platform Flow](connect-platform-flow.md), [Connect](connect.md),
  [Connect Accounts](connect-accounts.md), [Connect Money Movement](connect-money-movement.md)
- quote-driven billing follow-through:
  [Quote to Billing Operator Flow](quote-to-billing-operator.md), [Invoices](invoices.md),
  [Subscriptions](subscriptions.md), [Webhooks](webhooks.md)
- support and failure handling:
  [Error Handling](error-handling.md), [Testing](testing.md)
- standalone Stripe Tax on custom payment flows:
  [Tax](tax.md), [Payments](payments.md), [Testing](testing.md)

The flagship recipe guides stay intentionally secondary to the canonical guides: use them
for the recommended operator path, then drop into the canonical surface guides for deeper
API detail and constraints.

## Dispute handling and evidence submission

### Job to be done

A cardholder disputed a charge and your app needs to inspect the dispute, attach
evidence, and treat Stripe's follow-up webhook or retrieval as the source of truth.

### Key calls

```elixir
{:ok, dispute} = LatticeStripe.Dispute.retrieve(client, dispute_id)

{:ok, staged} =
  LatticeStripe.Dispute.update_evidence(client, dispute.id, %{
    "customer_name" => "Ada Lovelace",
    "product_description" => "Annual Pro plan",
    "receipt" => file_id
  })

{:ok, submitted} = LatticeStripe.Dispute.submit_evidence(client, staged.id)
```

### Webhook confirmation point

Treat the synchronous update calls as Stripe accepting your request, not as the final
story. Use your webhook path to reconcile the follow-up dispute state your app cares
about, especially if internal ticketing, support notes, or fulfillment state must
change with the dispute lifecycle.

### Read next

- [Credit Notes](credit_notes.md)
- [Webhooks](webhooks.md)
- [Testing](testing.md)

## Credit issuance and invoice adjustment

### Job to be done

Your team needs to reduce a finalized invoice after support review, preview the effect,
then create the credit note and react to the downstream billing truth.

### Key calls

```elixir
{:ok, preview} =
  LatticeStripe.CreditNote.preview(client, %{
    "invoice" => invoice_id,
    "lines" => [
      %{
        "type" => "custom_line_item",
        "description" => "Goodwill credit",
        "quantity" => 1,
        "unit_amount" => 500
      }
    ]
  })

{:ok, credit_note} =
  LatticeStripe.CreditNote.create(client, %{
    "invoice" => invoice_id,
    "lines" => [
      %{
        "type" => "custom_line_item",
        "description" => "Goodwill credit",
        "quantity" => 1,
        "unit_amount" => 500
      }
    ]
  })
```

### Webhook confirmation point

The preview and create calls tell you Stripe accepted the request. Your application
should still use webhook-driven invoice and customer-balance events to decide what is
authoritative for customer communication, entitlement rollback, or finance workflows.

### Read next

- [Credit Notes](credit_notes.md)
- [Invoices](invoices.md)
- [Webhooks](webhooks.md)

## Quote-to-invoice flow

### Job to be done

Sales or ops wants to build a quote, finalize it, let the customer accept it, and
then react when Stripe turns that accepted quote into downstream billing objects.

### Key calls

```elixir
{:ok, quote} =
  LatticeStripe.Quote.create(client, %{
    "customer" => customer_id,
    "line_items" => [
      %{
        "price_data" => %{
          "currency" => "usd",
          "product_data" => %{"name" => "Pro annual"},
          "unit_amount" => 2_000,
          "recurring" => %{"interval" => "month"}
        },
        "quantity" => 1
      }
    ]
  })

{:ok, open_quote} = LatticeStripe.Quote.finalize(client, quote.id)
{:ok, accepted_quote} = LatticeStripe.Quote.accept(client, open_quote.id)
```

### Webhook confirmation point

Quote acceptance is the beginning of the downstream billing transition, not the final
state your app should trust on its own. Confirm invoice, subscription, or payment
follow-through from your webhook handlers and any follow-up retrievals you need for
the exact product workflow.

### Read next

- [Quote to Billing Operator Flow](quote-to-billing-operator.md)
- [Invoices](invoices.md)
- [Webhooks](webhooks.md)
- [User Flows & JTBD](user-flows-and-jtbd.md)

## Connect platform onboarding and destination charges

### Job to be done

You are building a marketplace or platform that needs the shortest truthful path from
seller onboarding to charging on behalf of one connected account.

### Key calls

```elixir
{:ok, account} =
  LatticeStripe.Account.create(client, %{
    "type" => "express",
    "country" => "US",
    "email" => "seller@example.test"
  })

{:ok, link} =
  LatticeStripe.AccountLink.create(client, %{
    "account" => account.id,
    "type" => "account_onboarding",
    "refresh_url" => "https://example.com/connect/refresh",
    "return_url" => "https://example.com/connect/return"
  })

{:ok, payment_intent} =
  LatticeStripe.PaymentIntent.create(client, %{
    "amount" => 5_000,
    "currency" => "usd",
    "application_fee_amount" => 500,
    "transfer_data" => %{"destination" => account.id},
    "on_behalf_of" => account.id,
    "transfer_group" => "ORDER_42"
  })
```

### Webhook confirmation point

Treat the onboarding redirect and destination-charge response as Stripe accepting the
request now, not as durable platform truth. Use `account.updated`, `charge.*`,
`application_fee.*`, `transfer.*`, and `payout.*` events to confirm what became true.

### Read next

- [Connect Platform Flow](connect-platform-flow.md)
- [Connect](connect.md)
- [Connect Accounts](connect-accounts.md)
- [Connect Money Movement](connect-money-movement.md)
- [Webhooks](webhooks.md)
