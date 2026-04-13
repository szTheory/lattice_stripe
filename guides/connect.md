# Connect

> Conceptual overview of Stripe Connect in LatticeStripe. For account lifecycle
> deep-dive see [Connect Accounts](connect-accounts.md). For money movement
> see [Connect Money Movement](connect-money-movement.md).

Stripe Connect is the API for platforms that create and manage payments on
behalf of other businesses — marketplaces, SaaS billing platforms, booking
engines, payment facilitators. LatticeStripe ships complete Connect support:
account onboarding, acting on behalf of connected accounts, Transfers,
Payouts, Balance, and platform-fee reconciliation.

This page is the conceptual landing spot — it answers "what kind of Connect
platform am I building, and which charge pattern do I use?". The
implementation detail lives in the two deep-dive guides linked above.

## Standard, Express, and Custom

Stripe offers three account types. Picking the right one is primarily a
product decision, not a technical one — all three use the same
`LatticeStripe.Account` module.

| Type         | Who owns the dashboard                   | Platform responsibility                  | Typical fit                          |
| ------------ | ---------------------------------------- | ---------------------------------------- | ------------------------------------ |
| **Standard** | The connected account (full Stripe UI)   | Minimal — Stripe handles compliance      | Two-sided marketplaces, SaaS add-ons |
| **Express**  | Stripe-hosted, platform-branded          | Light — onboarding via `AccountLink`     | Most platforms (recommended default) |
| **Custom**   | None — platform builds its own UI        | Heavy — KYC, disputes, compliance        | White-label PSPs, embedded finance   |

For new platforms, **Express** is the right default. It gives you a
Stripe-hosted onboarding flow with your branding, handles KYC for you, and
still lets the connected account manage disputes and payouts through the
Stripe-hosted Express dashboard.

## Charge patterns

Connect platforms pick one of three charge patterns depending on who the
merchant of record is and who holds the funds. LatticeStripe uses the same
`LatticeStripe.PaymentIntent` module for all three — the pattern is a
matter of which Connect-specific fields you include on the create call.

### Direct charges

The connected account is the merchant of record. The platform sets the
`Stripe-Account` header and the charge is created directly on the
connected account's ledger.

```elixir
LatticeStripe.PaymentIntent.create(platform_client, %{
  "amount" => 5000,
  "currency" => "usd",
  "payment_method_types" => ["card"],
  "application_fee_amount" => 500
}, stripe_account: "acct_connected")
```

### Destination charges

The platform is the merchant of record and Stripe automatically transfers
a portion to the connected account. Most platforms start here.

```elixir
LatticeStripe.PaymentIntent.create(platform_client, %{
  "amount" => 5000,
  "currency" => "usd",
  "application_fee_amount" => 500,
  "transfer_data" => %{"destination" => "acct_connected"},
  "on_behalf_of" => "acct_connected"
})
```

### Separate charges and transfers

The platform takes the full charge, then issues one or more `Transfer`
calls to fan out funds to N connected accounts. Required when a single
order splits across multiple merchants.

```elixir
{:ok, pi} = LatticeStripe.PaymentIntent.create(platform_client, %{
  "amount" => 5000, "currency" => "usd",
  "payment_method" => "pm_card_visa", "confirm" => true,
  "transfer_group" => "ORDER_42"
})

LatticeStripe.Transfer.create(platform_client, %{
  "amount" => 2000, "currency" => "usd",
  "destination" => "acct_merchant_a",
  "transfer_group" => "ORDER_42",
  "source_transaction" => pi.latest_charge
})
```

See [Connect Money Movement](connect-money-movement.md#separate-charges-and-transfers)
for the full fan-out pattern including `source_transaction` semantics.

## Money-flow diagram

```text
          Customer card
                │
                ▼
      ┌──────────────────┐
      │  Platform Stripe │
      │     balance      │
      └──────────────────┘
         │           │
 application_fee   transfer / transfer_data
         │           │
         ▼           ▼
  Platform keeps   Connected account
         │           balance
         │           │
         │           ▼
         │    Payout (external account)
         │           │
         ▼           ▼
   Platform bank   Merchant bank
```

The platform sits between the customer's card network and the connected
account's bank. Every Connect flow is some arrangement of: charge lands
on a balance, optional transfer to a connected balance, payout to an
external account.

## Capabilities model

A connected account does not automatically have all Stripe features
enabled. Each feature (accepting cards, receiving transfers, issuing cards,
etc.) is represented by a **capability**. Capabilities progress through
three states: `inactive → pending → active`. Platforms request
capabilities via `LatticeStripe.Account.update/4` and drive application
state from `account.updated` webhook events — never from SDK responses.

See [Connect Accounts › Handling capabilities](connect-accounts.md#handling-capabilities)
for the capability request idiom and the `Capability.status_atom/1`
helper.

## Where to go next

- [Connect Accounts](connect-accounts.md) — create accounts, run the
  onboarding link flow, handle capabilities, reject accounts
- [Connect Money Movement](connect-money-movement.md) — Transfers,
  Payouts, Balance, destination charges, platform-fee reconciliation
- [Webhooks](webhooks.md) — `account.updated`,
  `account.application.authorized`, `transfer.*`, `payout.*` event
  handling
