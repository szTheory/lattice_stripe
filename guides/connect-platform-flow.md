# Connect Platform Flow

Use this guide when you are building a platform where one payment usually belongs to
one connected account and you want the shortest truthful path from onboarding to money
movement.

This is a workflow playbook, not a second API reference. It teaches one recommended
spine first, keeps the webhook-owned truth explicit, and routes you back to the
canonical Connect guides when you need deeper surface detail.

## Why this is the default Connect spine

For most new platforms, the strongest default is:

1. Create or reuse an Express connected account.
2. Create an onboarding `AccountLink`.
3. Redirect immediately to the bearer URL.
4. Charge with destination-charge `PaymentIntent` parameters.
5. Reconcile fees, transfers, and payouts from webhook-confirmed truth.

That path is the best default when one payment belongs to one connected account because
it keeps Stripe-hosted onboarding, platform fee collection, and seller routing aligned
without jumping straight into separate ledger orchestration.

**Your app starts the flow. Webhooks confirm reality.**

## The recommended platform spine

```text
create or reuse Express account
  -> AccountLink.create(account_onboarding)
  -> redirect to Stripe-hosted onboarding
  -> account.updated webhook confirms capability/account truth
  -> PaymentIntent.create with destination-charge fields
  -> charge.succeeded / application_fee.created / payout.* webhooks
  -> local reconciliation and operator follow-through
```

## 1. Start with an Express connected account

Express is the right default when you want Stripe-hosted onboarding and dashboard access
without taking on Custom-account compliance responsibility.

```elixir
{:ok, account} =
  LatticeStripe.Account.create(client, %{
    "type" => "express",
    "country" => "US",
    "email" => "seller@example.test"
  })
```

If the seller already has an `acct_*` you trust locally, reuse it. Do not create a new
connected account every time someone retries onboarding.

## 2. Create the onboarding link and redirect immediately

Keep the Phoenix action thin: create the `AccountLink`, then redirect to the returned
URL immediately.

```elixir
def start_connect_onboarding(conn, _params) do
  client = MyApp.Stripe.client()
  seller = conn.assigns.current_seller

  account_id = seller.stripe_account_id || create_express_account!(client, seller).id

  {:ok, link} =
    LatticeStripe.AccountLink.create(client, %{
      "account" => account_id,
      "type" => "account_onboarding",
      "refresh_url" => "https://example.com/connect/refresh",
      "return_url" => "https://example.com/connect/return"
    })

  redirect(conn, external: link.url)
end
```

`link.url` is a short-lived bearer credential. Redirect immediately. Do not log it,
store it, or send it through telemetry.

If the user returns to your `refresh_url`, create a fresh `AccountLink` and redirect
again. The redirect handler is UX only. Durable account and capability truth still
belongs to `account.updated` webhook handling.

## 3. Create destination charges when one payment belongs to one seller

When the platform charges the customer and the funds should route to one connected
account, destination charges are the clearest default.

```elixir
{:ok, payment_intent} =
  LatticeStripe.PaymentIntent.create(client, %{
    "amount" => 5_000,
    "currency" => "usd",
    "payment_method_types" => ["card"],
    "application_fee_amount" => 500,
    "transfer_data" => %{"destination" => account_id},
    "on_behalf_of" => account_id,
    "transfer_group" => "ORDER_42"
  })
```

Those Connect fields are load-bearing:

- `application_fee_amount` sets the platform fee.
- `transfer_data.destination` routes funds to the connected account.
- `on_behalf_of` keeps the merchant-of-record semantics explicit.
- `transfer_group` gives you a stable reconciliation handle if later work needs it.

Use the synchronous response to continue the current interaction. Do not treat it as the
final truth for payment success, fee collection, or payout completion.

## 4. Keep payout and reconciliation truth webhook-owned

The operational story is not finished when the charge request succeeds. Treat webhook
events as the durable truth for what actually happened:

- `account.updated` for onboarding, capability, and requirements changes
- `charge.succeeded` for payment success
- `application_fee.created` for fee collection
- `transfer.*` for connected-balance movement
- `payout.*` for money leaving a Stripe balance

```elixir
defmodule MyApp.StripeWebhookHandler do
  @behaviour LatticeStripe.Webhook.Handler

  @impl true
  def handle_event(%LatticeStripe.Event{type: "account.updated"} = event) do
    MyApp.Connect.sync_account_state(event.data["object"]["id"])
    :ok
  end

  @impl true
  def handle_event(%LatticeStripe.Event{type: "charge.succeeded"} = event) do
    MyApp.Payments.enqueue_reconciliation(event.data["object"]["id"])
    :ok
  end

  @impl true
  def handle_event(_event), do: :ok
end
```

Polling or a redirect return page is not the authority path here. Preserve the raw-body
invariant in Phoenix and let webhook-confirmed state drive your local projection.

## 5. `Transfer` and `Payout` are not the same operation

This distinction matters early:

- `Transfer` moves funds from the platform Stripe balance to a connected Stripe balance.
- `Payout` moves funds from a Stripe balance to a bank account or debit card.

If your team collapses those into one idea, reconciliation and support workflows get
confusing fast. Keep the connected-balance step and the bank-settlement step separate in
your docs, code, and operator language.

## 6. Switch patterns when the default no longer matches the product

Use separate charges and transfers instead of destination charges when:

- one payment must split across multiple connected accounts
- seller assignment is delayed until after the original charge
- transfer timing must be decoupled from the original charge

That is a bounded switch, not a co-equal default. Start with destination charges when
one payment belongs to one seller and only move to separate charges and transfers when
the product shape actually demands it.

## 7. Keep the guide boundary honest

This guide stops before ledger design, entitlement rules, dunning policy, payout-ops
software, or platform product ownership. LatticeStripe gives you the Stripe primitives
and Connect-specific request shapes. Your application still owns the local workflow and
support decisions around them.

## Read next

- [Connect](connect.md)
- [Connect Accounts](connect-accounts.md)
- [Connect Money Movement](connect-money-movement.md)
- [Webhooks](webhooks.md)
- [Error Handling](error-handling.md)
