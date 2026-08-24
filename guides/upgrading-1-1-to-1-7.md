# Upgrading from 1.1 to 1.7

If you pinned `{:lattice_stripe, "~> 1.1"}` and are moving to `~> 1.7`, use
this guide to answer one question first: **does my existing application need a
code change?** It then routes you to the additive capabilities that became
available in this historical interval.

> #### Scope: this guide stops at 1.7 {: .warning}
>
> This guide covers the `1.1 → 1.7` leg only. The `~> 1.7` pin below is
> deliberate history, not a recommendation for a current installation.
>
> Continuing to 2.x? Complete this leg, then read the
> [2.0.0 CHANGELOG entry](../CHANGELOG.md#200) and the current
> [Getting Started](getting-started.md) and
> [Client Configuration](client-configuration.md) guides. Those guides own
> setup advice after this boundary.

## Update your dependency

Bump the version in `mix.exs` and run `mix deps.get`:

```elixir
{:lattice_stripe, "~> 1.7"}
```

Adopters pinned to `~> 1.1` resolve to `1.7`. Retain your existing client and
Finch setup for this historical leg.

## Two-minute mandatory migration checklist

There are exactly three caller-visible behavior changes between 1.1 and 1.7.
Check each affected-user predicate before exploring optional additions.

> #### Breaking change: expanded fields return typed structs {: .warning}
>
> **Affected if:** you pass `expand:` and pattern-match the expanded
> association as a raw map (for example, `%{"id" => id}`).
>
> Change the match to the typed struct. If you never pass `expand:`, you are
> unaffected; unexpanded fields are still string IDs.

```elixir
# Before (1.1):
{:ok, %PaymentIntent{customer: %{"id" => id}}} =
  PaymentIntent.retrieve(client, id, expand: ["customer"])

# After (1.7):
{:ok, %PaymentIntent{customer: %Customer{id: id}}} =
  PaymentIntent.retrieve(client, id, expand: ["customer"])
```

When expanded, associated resources now arrive as typed structs such as
`%Customer{}`. See `LatticeStripe.PaymentIntent.retrieve/3` for the
representative retrieval call.

> #### Breaking change: finite `status` fields return atoms {: .warning}
>
> **Affected if:** you compare a resource's finite `status` field against a
> string (for example, `pi.status == "succeeded"`).
>
> Switch the comparison to the atom. Unknown or future status values still pass
> through as strings for forward compatibility.

```elixir
# Before (1.1):
if pi.status == "succeeded" do ...

# After (1.7):
if pi.status == :succeeded do ...
```

Affected finite-status resources include PaymentIntent, Subscription, Charge,
Refund, SetupIntent, Payout, BalanceTransaction, and Checkout.Session.

> #### Breaking change: `tolerance: 0` disables the staleness check {: .warning}
>
> **Affected if:** you set `tolerance: 0` when verifying webhook signatures in
> tests. It now disables the timestamp staleness check, matching the documented
> contract.
>
> This is a test-only escape hatch. **Never set `tolerance: 0` in production; it
> removes replay-attack protection.**

```elixir
# Before (1.1): tolerance: 0 always errored
{:error, :timestamp_expired} =
  LatticeStripe.Webhook.verify_signature(payload, sig_header, secret, tolerance: 0)

# After (1.7): tolerance: 0 disables the staleness check
{:ok, _event} =
  LatticeStripe.Webhook.verify_signature(payload, sig_header, secret, tolerance: 0)
```

### If none apply

You have **no code migration** for this leg. Your existing integration remains
compatible. Before deployment, run your application test suite so its Stripe
calls, webhook handling, and any pattern matches exercise the upgraded
dependency in your own configuration.

## Optional additions by job

> #### Net-new surface — nothing here breaks {: .info}
>
> Everything below is optional. Start with the application job you need to do,
> use the minimum call to establish the integration, and follow the canonical
> guide for the complete workflow.

### Payments and payment setup

| Need | Surface | Minimum call | Canonical next step |
|---|---|---|---|
| Resolve a chargeback | `LatticeStripe.Dispute` | `Dispute.retrieve/3` | `m:LatticeStripe.Dispute` |
| Upload dispute evidence | `LatticeStripe.File` and `LatticeStripe.FileLink` | `LatticeStripe.File.create/3`, then `LatticeStripe.FileLink.create/3` | [Recipes](recipes.md) |
| Inspect a payment mandate | `LatticeStripe.Mandate` | `Mandate.retrieve/3` | `m:LatticeStripe.Mandate` |
| Audit SetupIntent attempts | `LatticeStripe.SetupAttempt` | `SetupAttempt.list/3` | `m:LatticeStripe.SetupAttempt` |
| Search or reconcile charges | `LatticeStripe.Charge` | `Charge.list/3` or `Charge.search/3` | [Payments](payments.md) |

### Billing and self-service

| Need | Surface | Minimum call | Canonical next step |
|---|---|---|---|
| Issue a post-invoice credit | `LatticeStripe.CreditNote` | `CreditNote.create/3` | [Credit Notes](credit_notes.md) |
| Prepare a quote for billing | `LatticeStripe.Quote` | `Quote.create/3` | [Quote to Billing Operator](quote-to-billing-operator.md) |
| Control customer portal cancellation behavior | `LatticeStripe.BillingPortal.Configuration` and `Session` | `Configuration.create/3`, then `Session.create/3` with `config.id` | [Customer Portal](customer-portal.md#wire-a-configuration-into-sessions) |

Create a portal configuration before creating a hosted session. The configuration
is the policy; the session carries its id to the customer-facing portal.

```elixir
{:ok, config} =
  LatticeStripe.BillingPortal.Configuration.create(client, %{
    "features" => %{"subscription_cancel" => %{"enabled" => true}}
  })

{:ok, session} =
  LatticeStripe.BillingPortal.Session.create(client, %{
    "customer" => "cus_123",
    "configuration" => config.id,
    "return_url" => "https://example.com/account"
  })
```

### Tax

| Need | Surface | Minimum call | Canonical next step |
|---|---|---|---|
| Calculate tax before charging | `LatticeStripe.Tax.Calculation` | `Tax.Calculation.create/3` | [Tax](tax.md) |
| Record or reverse a tax transaction | `LatticeStripe.Tax.Transaction` | `Tax.Transaction.create_from_calculation/3` | [Tax](tax.md) |
| Read account tax settings | `LatticeStripe.Tax.Settings` | `Tax.Settings.retrieve/2` | [Tax](tax.md) |
| Register tax obligations | `LatticeStripe.Tax.Registration` | `Tax.Registration.create/3` | [Tax](tax.md) |
| Attach a customer tax ID | `LatticeStripe.TaxId` | `TaxId.create/4` | [Tax](tax.md) |

The Tax guide owns jurisdiction, address, and reversal details; this guide only
identifies the family and the first safe call.

### Webhooks and operations

| Need | Surface | Minimum call | Canonical next step |
|---|---|---|---|
| Verify then fetch authoritative thin-event state | `LatticeStripe.EventNotification` | `Webhook.parse_event_notification/4`, then `Webhook.fetch_event/3` | [Webhooks: Thin Events](webhooks-thin-events.md) |
| Reconcile a bank payout | `LatticeStripe.Payout` | `Payout.retrieve/3` | `m:LatticeStripe.Payout` |
| Inspect the ledger behind a movement | `LatticeStripe.BalanceTransaction` | `BalanceTransaction.retrieve/3` | `m:LatticeStripe.BalanceTransaction` |

For thin events, verification proves the notification came from Stripe; fetch the
event before treating event payload state as authoritative.

```elixir
with {:ok, notification} <-
       LatticeStripe.Webhook.parse_event_notification(payload, sig_header, secret, []),
     {:ok, event} <- LatticeStripe.Webhook.fetch_event(client, notification, []) do
  process_authoritative_event(event)
end
```

### Testing

| Need | Surface | Minimum call | Canonical next step |
|---|---|---|---|
| Create a raw Stripe test clock | `LatticeStripe.TestHelpers.TestClock` | `TestHelpers.TestClock.create/3` | [Testing](testing.md) |
| Advance billing time ergonomically | `LatticeStripe.Testing.TestClock` | `Testing.TestClock.advance/2` | [Testing](testing.md) |
| Build typed resource or webhook fixtures | `LatticeStripe.Testing.Fixtures` | a builder such as `Testing.dispute/1` | [Testing](testing.md) |

Use the Testing guide for setup and isolation; these names are the 1.7 public
testing surface, not a replacement for its full workflow.

## Version-by-version appendix

Use this appendix for chronology after deciding required migration work and
optional capability adoption.

| Version | Behavior change | Additions |
|---|---|---|
| **1.3** | Expanded fields return typed structs; finite `status` fields return atoms | Dispute, CreditNote, Quote, Mandate, SetupAttempt, File, FileLink, testing fixtures |
| **1.5** | `tolerance: 0` disables the staleness check in tests | EventNotification and `parse_event_notification/4` |
| **1.6** | — | Tax.Calculation, Tax.Transaction, Tax.Settings, Tax.Registration, TaxId |
| **1.7** | — | Charge list/search, BillingPortal.Configuration, Payout, BalanceTransaction, TestHelpers.TestClock, Testing.TestClock, Testing.Fixtures |

For the authoritative release record, see the [CHANGELOG](../CHANGELOG.md#170).
