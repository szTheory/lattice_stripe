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
- disputes, file evidence, and support workflows:
  this guide (§Dispute handling), [Webhooks](webhooks.md), [Testing](testing.md)
- payment authorization diagnostics (save-card failures):
  this guide (§Mandate and SetupAttempt diagnostics), [Payments](payments.md), [Testing](testing.md)
- support and failure handling:
  [Error Handling](error-handling.md), [Testing](testing.md)
- standalone Stripe Tax on custom payment flows:
  [Tax](tax.md), [Payments](payments.md), [Testing](testing.md)

The flagship recipe guides stay intentionally secondary to the canonical guides: use them
for the recommended operator path, then drop into the canonical surface guides for deeper
API detail and constraints.

## Dispute handling and evidence submission

### Job to be done

A cardholder disputed a charge and your app needs to inspect the dispute, upload
supporting files, stage evidence, submit when ready, and treat Stripe webhooks (or
later `retrieve/3`) as the source of truth for status changes.

### Recommended spine

1. **Retrieve** the dispute (`Dispute.retrieve/3`) when you learn the `dp_*` id from a
   webhook or support tooling.
2. **Upload** each evidence file with `LatticeStripe.File.create/3` (`purpose: "dispute_evidence"`).
   Files upload to Stripe's Files API (`client.files_base_url`, default
   `https://files.stripe.com`) — the same `Client` struct handles API and file uploads.
3. **Stage** text and file references with `Dispute.update_evidence/4` (always sends
   `submit: false` — safe to call repeatedly while drafting).
4. **Submit** once with `Dispute.submit_evidence/3` when the package is complete
   (**irreversible** — evidence locks for the bank review).
5. **Reconcile** via webhooks (`charge.dispute.created`, `charge.dispute.updated`,
   `charge.dispute.closed`) or polling `retrieve/3`; do not treat submit's synchronous
   response as your app's final ticketing state.

Optional: `Dispute.close/3` accepts the loss when you will not contest (also
irreversible).

### Key calls

```elixir
# 1. Inspect the dispute
{:ok, dispute} = LatticeStripe.Dispute.retrieve(client, dispute_id)

# 2. Upload evidence bytes (PDF, image, etc.) — returns a file_* id
evidence_bytes = File.read!("priv/support/receipt.pdf")

{:ok, evidence_file} =
  LatticeStripe.File.create(client, %{
    "purpose" => "dispute_evidence",
    "file" => evidence_bytes,
    "filename" => "receipt.pdf"
  })

# 3. Stage evidence (safe — does not submit to the bank)
{:ok, staged} =
  LatticeStripe.Dispute.update_evidence(client, dispute.id, %{
    "customer_name" => "Ada Lovelace",
    "product_description" => "Annual Pro plan",
    "uncategorized_file" => evidence_file.id,
    "uncategorized_text" => "Receipt attached via support portal"
  })

# You can call update_evidence/4 again to add fields before submitting.

# 4. Submit to the issuing bank (irreversible for evidence)
{:ok, submitted} = LatticeStripe.Dispute.submit_evidence(client, staged.id)
```

Use Stripe's [dispute evidence fields](https://docs.stripe.com/disputes/evidence) to pick
the right keys (`receipt`, `shipping_documentation`, `customer_communication`, etc.).
File-backed fields take a `file_*` id from `LatticeStripe.File.create/3`, not a raw path string.

### Webhook confirmation point

Treat `update_evidence/4` and `submit_evidence/3` as Stripe accepting your request, not
as the final story. Wire `charge.dispute.*` events through your existing webhook path
(see [Webhooks](webhooks.md)) and reconcile internal support state on `event.id`
idempotency. For delivery failures, see [Event Debugging](event-debugging.md).

### Read next

- [Webhooks](webhooks.md)
- [Event Debugging](event-debugging.md)
- [Testing](testing.md) — `LatticeStripe.Testing.dispute/1` and file fixtures
- [Credit Notes](credit_notes.md)

## Mandate and SetupAttempt diagnostics

### Job to be done

A customer tried to save a card or bank account with a SetupIntent and the flow failed,
stalled in `requires_action`, or succeeded but your support team needs to inspect
**why** Stripe recorded the authorization the way it did.

### Recommended spine

1. **Start from the SetupIntent id** (`seti_*`) from your app logs or a
   `setup_intent.*` webhook payload.
2. **List SetupAttempts** scoped to that intent — `setup_intent` is **required** in
   params; the SDK raises `ArgumentError` without it.
3. **Read `setup_error`** on the latest attempt for the structured failure code/message.
4. **Retrieve the Mandate** (`mandate_*`) when you need authorization status or
   customer acceptance details (`Mandate` is retrieve-only in LatticeStripe).

### Key calls

```elixir
setup_intent_id = "seti_123"

{:ok, resp} =
  LatticeStripe.SetupAttempt.list(client, %{"setup_intent" => setup_intent_id})

case List.first(resp.data.data) do
  %LatticeStripe.SetupAttempt{setup_error: %{code: code, message: msg}} ->
    IO.inspect({code, msg}, label: "latest setup failure")

  %LatticeStripe.SetupAttempt{status: status, payment_method: pm_id} ->
    IO.inspect({status, pm_id}, label: "latest attempt")

  nil ->
    :no_attempts_yet
end

# When you have a mandate id from the SetupIntent or PaymentMethod:
{:ok, mandate} = LatticeStripe.Mandate.retrieve(client, "mandate_123")

case mandate.status do
  :active -> :authorized
  other -> other
end
```

### Webhook confirmation point

`SetupAttempt` records are historical diagnostics — they explain what happened during
save attempts. Treat `setup_intent.succeeded` / `setup_intent.setup_failed` webhooks
(or a fresh `SetupIntent` retrieve) as the runtime truth for whether the customer's
payment method is attachable for off-session use.

### Read next

- [Payments](payments.md) — SetupIntent create/confirm flows
- [Webhooks](webhooks.md)
- [Error Handling](error-handling.md)
- [Testing](testing.md) — `Testing.Fixtures.Mandate`, `Testing.Fixtures.SetupAttempt`

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
