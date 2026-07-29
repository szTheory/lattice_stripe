# Upgrading from 1.1 to 1.7

If you pinned `{:lattice_stripe, "~> 1.1"}` and are moving to `~> 1.7`, this
guide is your map to everything that landed in between: the handful of behavior
changes you must check, then the large additive surface you now get for free.

> #### Scope: this guide stops at 1.7 {: .warning}
>
> The current Hex line is **2.x**. This guide covers the `1.1 → 1.7` leg only, and
> every version reference in it — including the `~> 1.7` pin below — is deliberate
> history, not a recommendation to pin there.
>
> Going all the way to 2.x? Do this leg first, then read the
> [CHANGELOG](CHANGELOG.md) entry for **2.0.0**. There is exactly one breaking
> change in 2.0, and it is confined to the testing surface: public test-fixture
> builders were renamed to the `<object>_json` convention (for example
> `MeterEvent.basic/1` became `meter_event_json/1`). It affects your test suite,
> never your production code paths.

> #### Do I need to change anything? {: .info}
>
> **Almost certainly not.** If your code only ever compared a resource's finite
> `status` field as a string, or pattern-matched an `expand:`-ed association as
> a raw map, read Part 2 — there are exactly **three** things to check.
> Everything else since 1.1 is *new surface*: your existing code keeps working
> unchanged.

## Update your dependency

Bump the version in your `mix.exs` and run `mix deps.get`:

```elixir
{:lattice_stripe, "~> 1.7"}
```

Adopters pinned to `~> 1.1` resolve to `1.7`.

**You no longer need to wire a Finch pool.** LatticeStripe now ships an optional
application that starts a default Finch pool (`LatticeStripe.Finch`) at boot,
and the `:finch` option defaults to it — so you can call Stripe without
configuring a pool yourself. This is additive and backwards-compatible: if you
already pass `:finch` or start your own pool, nothing changes. BYO-supervision
users who run their own pool can disable the default to avoid a duplicate idle
pool:

```elixir
# config/config.exs
config :lattice_stripe, start_default_finch: false
```

## Are you affected? (Behavior changes)

Exactly **three** genuine behavior changes shipped between 1.1 and 1.7. Each is
below with a bold **"Affected if:"** predicate so you can confirm safety in
under two minutes. If none of the three predicates match your code, you have no
migration work — skip to [Part 3](#what-s-new-since-1-1-additive).

> #### Breaking change: expanded fields return typed structs {: .warning}
>
> **Affected if:** you pass `expand:` and pattern-match the expanded
> association as a raw map (e.g. `%{"id" => id}`).
>
> ⚠ Action required if: you match an expanded field as a map — change the match
> to the typed struct. If you never pass `expand:`, you are unaffected;
> unexpanded fields are still string IDs.

```elixir
# Before (1.1):
{:ok, %PaymentIntent{customer: %{"id" => id}}} =
  PaymentIntent.retrieve(client, id, expand: ["customer"])

# After (1.7):
{:ok, %PaymentIntent{customer: %Customer{id: id}}} =
  PaymentIntent.retrieve(client, id, expand: ["customer"])
```

**Changed (1.3):** when you pass `expand:`, the response now contains a fully
typed struct (e.g. `%Customer{}`) instead of a raw map. Fields you did not
expand remain string IDs, unchanged. This applies to all resource modules — see
`LatticeStripe.PaymentIntent.retrieve/3` as the representative example.

> #### Breaking change: finite `status` fields return atoms {: .warning}
>
> **Affected if:** you compare a resource's finite `status` field against a
> string (e.g. `pi.status == "succeeded"`).
>
> ⚠ Action required if: you compare a finite `status` as a string — switch to
> the atom. Unknown or future status values still pass through as raw strings
> for forward-compatibility.

```elixir
# Before (1.1):
if pi.status == "succeeded" do ...

# After (1.7):
if pi.status == :succeeded do ...
```

**Changed (1.3):** all resource modules with a documented finite `status` field
now return atoms (`:active`, `:succeeded`, …) from `from_map/1`. Affected
modules: PaymentIntent, Subscription, SubscriptionSchedule, Charge, Refund,
SetupIntent, Payout, BalanceTransaction, BankAccount, Checkout.Session,
Billing.Meter, Account.Capability. The old
`LatticeStripe.Billing.Meter.status_atom/1` and
`LatticeStripe.Account.Capability.status_atom/1` helpers are now deprecated —
read `.status` directly off the struct.

> #### Breaking change: `tolerance: 0` disables the staleness check {: .warning}
>
> **Affected if:** you set `tolerance: 0` when verifying webhook signatures in
> tests. Previously it always returned `{:error, :timestamp_expired}`; now it
> disables the timestamp staleness check, as the docstring has always
> documented.
>
> ⚠ Action required if: test-only — you relied on `tolerance: 0` erroring.
> **Never set `tolerance: 0` in production; it removes replay-attack
> protection.**

```elixir
# Before (1.1): tolerance: 0 always errored
{:error, :timestamp_expired} =
  LatticeStripe.Webhook.verify_signature(payload, sig_header, secret, tolerance: 0)

# After (1.7): tolerance: 0 disables the staleness check
{:ok, _event} =
  LatticeStripe.Webhook.verify_signature(payload, sig_header, secret, tolerance: 0)
```

**Changed (1.5):** the private check_tolerance/2 clause was reconciled with the
long-documented `LatticeStripe.Webhook.verify_signature/4` contract, and
`m:LatticeStripe.Webhook.Plug`'s `:tolerance` schema was relaxed from
`:pos_integer` to `:non_neg_integer` so the "set 0 to disable" lever is
reachable through the Plug. Negative tolerances are still rejected at `init/1`.

## What's new since 1.1 (additive)

> #### Net-new surface — nothing here breaks {: .info}
>
> Everything below shipped between 1.1 and 1.7 as *additive* surface. None of
> it changes existing behavior, so there is nothing to migrate — these are
> capabilities you can adopt when you need them.

✅ Additive — no changes needed. Surfaces are grouped by family to mirror the
HexDocs sidebar. Each entry shows the minimum "Now:" call and routes to its
canonical guide or module docs for full coverage.

### Payments

**Disputes** — retrieve and manage chargeback disputes and evidence.

```elixir
# Not available in 1.1 → Now (1.7):
{:ok, dispute} = LatticeStripe.Dispute.retrieve(client, "dp_123")
# => {:ok, %LatticeStripe.Dispute{}}
```

See `LatticeStripe.Dispute.retrieve/3` and `m:LatticeStripe.Dispute`.

### Billing

**Credit Notes** — issue post-invoice credits and refunds.

```elixir
# Not available in 1.1 → Now (1.7):
{:ok, credit_note} =
  LatticeStripe.CreditNote.create(client, %{
    "invoice" => "in_123",
    "lines" => [
      %{"type" => "invoice_line_item", "invoice_line_item" => "il_1", "quantity" => 1}
    ]
  })
# => {:ok, %LatticeStripe.CreditNote{}}
```

See `LatticeStripe.CreditNote.create/3` and [credit_notes.md](credit_notes.md).

**Quotes** — draft, finalize, and accept quotes that convert into invoices or
subscriptions.

```elixir
# Not available in 1.1 → Now (1.7):
{:ok, quote} =
  LatticeStripe.Quote.create(client, %{
    "customer" => "cus_123",
    "line_items" => [%{"price" => "price_123", "quantity" => 1}]
  })
# => {:ok, %LatticeStripe.Quote{}}
```

See `LatticeStripe.Quote.create/3` and
[quote-to-billing-operator.md](quote-to-billing-operator.md).

#### Customer portal configurations (the headline upgrade)

`BillingPortal.Configuration` is the surface most likely to have brought you
here. It lets you control **server-side** what customers can do in the Stripe
billing portal — including whether and how they can cancel a subscription.
Create a configuration, then thread its id into a portal session:

```elixir
# Not available in 1.1 → Now (1.7): server-controlled portal behavior.
{:ok, config} =
  LatticeStripe.BillingPortal.Configuration.create(client, %{
    "business_profile" => %{"headline" => "Manage your subscription"},
    "features" => %{
      "invoice_history" => %{"enabled" => true},
      "subscription_cancel" => %{"enabled" => true, "mode" => "at_period_end"}
    }
  })

{:ok, session} =
  LatticeStripe.BillingPortal.Session.create(client, %{
    "customer" => "cus_123",
    "configuration" => config.id,
    "return_url" => "https://example.com/account"
  })

# session.url is the hosted portal link to redirect the customer to.
```

**Why this matters:** a server-controlled `subscription_cancel` feature closes
the self-serve portal-cancel / dunning-bypass gap — you decide the cancel mode
(`at_period_end` vs. immediate) instead of inheriting portal defaults. See
`LatticeStripe.BillingPortal.Configuration.create/3`,
`LatticeStripe.BillingPortal.Session.create/3`, and
[customer-portal.md](customer-portal.md#wire-a-configuration-into-sessions) for
full field coverage.

### Tax

Stripe Tax landed as a full family: calculate tax, record and reverse
transactions, and manage account settings, jurisdiction registrations, and tax
IDs.

```elixir
# Not available in 1.1 → Now (1.7):
{:ok, calc} =
  LatticeStripe.Tax.Calculation.create(client, %{
    "currency" => "usd",
    "line_items" => [%{"amount" => 1000, "reference" => "sku_1"}],
    "customer_details" => %{"address" => %{"country" => "US"}}
  })
# => {:ok, %LatticeStripe.Tax.Calculation{}}
```

See `LatticeStripe.Tax.Calculation.create/3`,
`LatticeStripe.Tax.Transaction.create_from_calculation/3`,
`LatticeStripe.Tax.Settings.retrieve/2`,
`LatticeStripe.Tax.Registration.create/3`, `LatticeStripe.TaxId.create/4`, and
[tax.md](tax.md).

### Webhooks

**Thin events** — the modern webhook path: verify a lightweight notification,
then fetch the full object with fetch-after-verify idempotency.

```elixir
# Not available in 1.1 → Now (1.7):
{:ok, notification} =
  LatticeStripe.Webhook.parse_event_notification(payload, sig_header, secret, [])
# => {:ok, %LatticeStripe.EventNotification{}}
```

See `LatticeStripe.Webhook.parse_event_notification/4`,
`m:LatticeStripe.EventNotification`, and
[webhooks-thin-events.md](webhooks-thin-events.md).

### Connect

**Charge list & search** — enumerate and query charges for support, audit, and
Connect reconciliation. `PaymentIntent` remains the payment-initiation path.

```elixir
# Not available in 1.1 → Now (1.7):
{:ok, page} = LatticeStripe.Charge.list(client, %{"limit" => 10})
{:ok, hits} = LatticeStripe.Charge.search(client, %{"query" => "amount>1000"})
# => {:ok, %LatticeStripe.Response{}}
```

See `LatticeStripe.Charge.list/3`, `LatticeStripe.Charge.search/3`, and
`m:LatticeStripe.Charge`.

**Payouts** — move funds to your bank account or a connected account.

```elixir
# Not available in 1.1 → Now (1.7):
{:ok, payout} =
  LatticeStripe.Payout.create(client, %{"amount" => 1000, "currency" => "usd"})
# => {:ok, %LatticeStripe.Payout{}}
```

See `LatticeStripe.Payout.create/3` and `m:LatticeStripe.Payout`.

**Balance transactions** — inspect the ledger entry behind any balance movement.

```elixir
# Not available in 1.1 → Now (1.7):
{:ok, txn} = LatticeStripe.BalanceTransaction.retrieve(client, "txn_123")
# => {:ok, %LatticeStripe.BalanceTransaction{}}
```

See `LatticeStripe.BalanceTransaction.retrieve/3` and
`m:LatticeStripe.BalanceTransaction`.

### Testing

**Test clocks** — drive subscription time forward deterministically in tests.
Lead with the ExUnit ergonomics; drop to the raw resource API when you need
direct control.

```elixir
# Not available in 1.1 → Now (1.7):
defmodule MyApp.BillingTest do
  use MyApp.StripeCase, async: true
  setup :with_test_clock

  test "sub renews after 30 days", %{test_clock: clock} do
    customer = create_customer(clock, email: "a@b.c")
    advance(clock, days: 30)
  end
end
```

See `m:LatticeStripe.Testing.TestClock` for the `use`-macro and `advance/2`
ergonomics, and `LatticeStripe.TestHelpers.TestClock.create/3` for the raw
resource calls.

**Fixtures** — typed and signed fixtures for the v1.3+ resource families, so you
can build structs and webhook payloads without hitting Stripe.

```elixir
# Not available in 1.1 → Now (1.7):
dispute = LatticeStripe.Testing.dispute(%{"id" => "dp_1", "status" => "needs_response"})
```

See `m:LatticeStripe.Testing.Fixtures` for the raw builders,
`LatticeStripe.Testing.dispute/1` and its sibling wrappers, and
[testing.md](testing.md).

## Version-by-version reference

A scannable summary of what broke and what was added in each release between 1.1
and 1.7. Full detail lives in the [CHANGELOG](../CHANGELOG.md#170).

| Version | Broke | Added |
|---------|-------|-------|
| **1.3** | Expanded fields return typed structs; finite `status` fields return atoms (status_atom/1 deprecated) | Disputes, Credit Notes, Quotes, Mandates, SetupAttempts, File/FileLink, testing fixtures |
| **1.5** | `tolerance: 0` disables the staleness check (was: always errored) — test-only | Thin-event webhooks (parse_event_notification/4, EventNotification) |
| **1.6** | — | Stripe Tax family (Tax.Calculation, Tax.Transaction, Tax.Settings, Tax.Registration, TaxId) |
| **1.7** | — | Charge list / search / update / capture; operator playbooks; default Finch pool |

The three **Broke** rows are the three behavior changes covered in Part 2;
everything in the **Added** columns is net-new surface from Part 3.
