# LatticeStripe

[![Hex.pm](https://img.shields.io/hexpm/v/lattice_stripe.svg)](https://hex.pm/packages/lattice_stripe)
[![CI](https://github.com/szTheory/lattice_stripe/actions/workflows/ci.yml/badge.svg)](https://github.com/szTheory/lattice_stripe/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/lattice_stripe)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **Release status:** **`1.7.x`** ships as the current published line on Hex (capstone release **1.7.0**).
>
> - **1.4** — Adoption closure: flagship recipes, docs-truth baseline, discovery ladder
> - **1.5** — Thin-event webhooks: [`guides/webhooks-thin-events.md`](guides/webhooks-thin-events.md)
> - **1.6** — Tax: [`guides/tax.md`](guides/tax.md)
> - **1.7** — Charge list/search/update/capture (PI-first; no create) plus operator playbooks: [`guides/production-checklist.md`](guides/production-checklist.md), [`guides/event-debugging.md`](guides/event-debugging.md)
>
> **v1.x scope:** LatticeStripe is **feature-complete for its intended scope** — mainstream SaaS payments, billing, usage metering, Connect, tax calculation, webhooks, and operator diagnostics. Further **1.x** work is **maintenance and adoption-driven**: bugfixes, Stripe API drift, and narrow additions when real adopters need them. See [User Flows & JTBD](guides/user-flows-and-jtbd.md) for fit and [API Stability](guides/api_stability.md) for the semver contract.
>
> See [CHANGELOG.md](CHANGELOG.md#170).

A production-grade, idiomatic Elixir SDK for the Stripe API.

Full documentation available on [HexDocs](https://hexdocs.pm/lattice_stripe).

If you are evaluating how this fits into a real SaaS billing architecture, start with
[Guide: User Flows & JTBD](guides/user-flows-and-jtbd.md).

## v1.x scope

As of **1.7.0**, LatticeStripe is **feature-complete for its intended v1.x scope**: mainstream SaaS integrations — payments, billing, Connect, tax on custom flows, webhooks (including thin events), and production operator guides.

**Not in v1.x scope** (maintenance mode; additions only on adopter pull):

- **Specialist Stripe families:** Identity; Treasury; Issuing; Terminal; Financial Connections; Climate; Sigma; Reporting
- **Tax narrow follow-ups:** Tax Code lookup (`/v1/tax_codes`); Tax Transaction list (if Stripe adds the endpoint)

See [Scope](guides/scope.md) for boundaries, escape hatches, and how to request coverage.

## Docs Ladder

Use the docs in this order:

- **README** for the repo-level surface map and route-by-intent overview
- **[Getting Started](guides/getting-started.md)** for first success with a live client and API call
- **[User Flows & JTBD](guides/user-flows-and-jtbd.md)** for "which Stripe path fits my SaaS?"
- **[Scope](guides/scope.md)** for v1.x boundaries and deferred families
- **Canonical guides** for the surface you will actually ship
- **[Recipes](guides/recipes.md)** for compact job-to-primitive bridges
- **[Webhooks](guides/webhooks.md)**, **[Production Checklist](guides/production-checklist.md)**, **[Event Debugging](guides/event-debugging.md)**, **[Testing](guides/testing.md)**, and **[Error Handling](guides/error-handling.md)** for runtime truth and support posture

## Choose Your Route

- **I want first success fast**:
  [Getting Started](guides/getting-started.md), [Payments](guides/payments.md), [Checkout](guides/checkout.md)
- **I am evaluating recurring billing for a SaaS**:
  [User Flows & JTBD](guides/user-flows-and-jtbd.md), [Subscriptions](guides/subscriptions.md), [Customer Portal](guides/customer-portal.md), [Webhooks](guides/webhooks.md)
- **I need usage-based billing and reconciliation**:
  [Metering](guides/metering.md), [Webhooks](guides/webhooks.md), [Testing](guides/testing.md)
- **I calculate tax on custom payment flows (not only Checkout/Invoices)**:
  [Tax](guides/tax.md), [Payments](guides/payments.md), [Testing](guides/testing.md)
- **I run a marketplace or platform**:
  [Connect](guides/connect.md), [Connect Accounts](guides/connect-accounts.md), [Connect Money Movement](guides/connect-money-movement.md)
- **I am hardening ops and support paths**:
  [Production Checklist](guides/production-checklist.md), [Error Handling](guides/error-handling.md), [Testing](guides/testing.md), [Webhooks](guides/webhooks.md), [Webhooks: Thin Events](guides/webhooks-thin-events.md), [Event Debugging](guides/event-debugging.md)

## Installation

Add `lattice_stripe` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:lattice_stripe, "~> 1.7"}
  ]
end
```

## Quick Start

LatticeStripe uses [Finch](https://github.com/sneako/finch) for HTTP requests. Add it to your supervision tree in `application.ex`:

```elixir
children = [
  {Finch, name: MyApp.Finch}
]
```

Then create a client and make your first API call:

```elixir
client = LatticeStripe.Client.new!(
  api_key: "sk_test_...",
  finch: MyApp.Finch
)

{:ok, payment_intent} = LatticeStripe.PaymentIntent.create(client, %{
  "amount" => 2000,
  "currency" => "usd",
  "payment_method" => "pm_card_visa",
  "confirm" => true,
  "automatic_payment_methods" => %{"enabled" => true, "allow_redirects" => "never"}
})

IO.puts("PaymentIntent created: #{payment_intent.id}")
```

## Features

### Payments

- Customers, PaymentIntents, SetupIntents, PaymentMethods, Refunds, Checkout Sessions (payment / subscription / setup modes)
- Charge list/search/update/capture for support, audit, and Connect reconciliation — [Charge API](https://hexdocs.pm/lattice_stripe/LatticeStripe.Charge.html) (PI-first; no `create`)
- Structured, pattern-matchable errors: `:card_error`, `:authentication_error`, `:rate_limit_error`, `:api_error`, and more — [Guide: Error Handling](guides/error-handling.md)
- Auto-pagination — stream through large result sets lazily with Elixir Streams
- [Guide: Payments](guides/payments.md)

### Billing

- Invoices — create, finalize, pay, void, send, list, search
- Credit Notes — preview, create, void, and inspect/stream line items
- Quotes — create, finalize, accept/cancel, inspect/stream line items, and download PDFs
- Subscriptions with lifecycle verbs (cancel, resume, pause_collection, trial settings)
- Subscription Schedules for phased billing with proration guards
- Billing Metering — usage-based billing with `Meter`, `MeterEvent`, and `MeterEventAdjustment`; two-layer idempotency and pre-flight value guards
- Customer Portal — `BillingPortal.Session` for self-service portal URLs with 4 flow types (subscription_cancel, subscription_update, subscription_update_confirm, payment_method_update) and Inspect masking
- [Guide: Subscriptions](guides/subscriptions.md) · [Guide: Credit Notes](guides/credit_notes.md) · [Guide: Metering](guides/metering.md) · [Guide: Tax](guides/tax.md) · [Guide: Customer Portal](guides/customer-portal.md)

### Operations and diagnostics

- Files and FileLinks — upload files to Stripe, manage shareable file links, and download binary content
- Disputes — retrieve/list, update metadata, stage evidence safely, submit evidence, and close disputes
- Mandates and SetupAttempts — inspect payment authorization state and SetupIntent failure history
- Operator playbooks: [Production Checklist](guides/production-checklist.md) · [Event Debugging](guides/event-debugging.md)
- [Guide: Recipes](guides/recipes.md) · [Guide: Webhooks](guides/webhooks.md) · [Guide: Testing](guides/testing.md)

### Connect

- Connect accounts (Standard, Express, Custom) with onboarding AccountLinks
- Transfers, TransferReversals, Payouts, External Accounts
- Balance + BalanceTransactions for platform-fee reconciliation
- Per-client and per-request `stripe_account` for platform integrations
- [Guide: Connect](guides/connect.md)

### Platform

- Pluggable `Transport`, `Json`, and `RetryStrategy` behaviours — bring your own HTTP client
- Automatic retry with exponential backoff, respecting Stripe's `Stripe-Should-Retry` header
- Automatic idempotency-key generation and safe replay
- Telemetry events for every request, compatible with any monitoring stack
- Phoenix-ready `Webhook.Plug` snapshot path + thin-event (`/v2/events`) helpers for fetch-after-verify integration
- [Guide: Extending LatticeStripe](guides/extending-lattice-stripe.md)

## Compatibility

| Requirement | Version |
|-------------|---------|
| Elixir | >= 1.15 |
| Erlang/OTP | >= 26 |
| Stripe API | 2026-03-25.dahlia |

## Documentation

Full documentation with guides, examples, and API reference is available on
[HexDocs](https://hexdocs.pm/lattice_stripe).

Start here on HexDocs:

- [Getting Started](https://hexdocs.pm/lattice_stripe/getting-started.html)
- [User Flows & JTBD](https://hexdocs.pm/lattice_stripe/user-flows-and-jtbd.html)
- [Recipes](https://hexdocs.pm/lattice_stripe/recipes.html)

Canonical guide clusters:

- **Payments and billing primitives**:
  [Payments](https://hexdocs.pm/lattice_stripe/payments.html), [Checkout](https://hexdocs.pm/lattice_stripe/checkout.html), [Invoices](https://hexdocs.pm/lattice_stripe/invoices.html), [Credit Notes](https://hexdocs.pm/lattice_stripe/credit_notes.html), [Subscriptions](https://hexdocs.pm/lattice_stripe/subscriptions.html), [Customer Portal](https://hexdocs.pm/lattice_stripe/customer-portal.html), [Metering](https://hexdocs.pm/lattice_stripe/metering.html), [Tax](https://hexdocs.pm/lattice_stripe/tax.html), [Charge API](https://hexdocs.pm/lattice_stripe/LatticeStripe.Charge.html)
- **Connect**:
  [Connect](https://hexdocs.pm/lattice_stripe/connect.html), [Connect Accounts](https://hexdocs.pm/lattice_stripe/connect-accounts.html), [Connect Money Movement](https://hexdocs.pm/lattice_stripe/connect-money-movement.html)
- **Operations and DX**:
  [Webhooks](https://hexdocs.pm/lattice_stripe/webhooks.html), [Webhooks: Thin Events](https://hexdocs.pm/lattice_stripe/webhooks-thin-events.html), [Production Checklist](https://hexdocs.pm/lattice_stripe/production-checklist.html), [Event Debugging](https://hexdocs.pm/lattice_stripe/event-debugging.html), [Testing](https://hexdocs.pm/lattice_stripe/testing.html), [Error Handling](https://hexdocs.pm/lattice_stripe/error-handling.html), [Client Configuration](https://hexdocs.pm/lattice_stripe/client-configuration.html), [Performance](https://hexdocs.pm/lattice_stripe/performance.html), [Circuit Breaker](https://hexdocs.pm/lattice_stripe/circuit-breaker.html), [OpenTelemetry](https://hexdocs.pm/lattice_stripe/opentelemetry.html), [Telemetry](https://hexdocs.pm/lattice_stripe/telemetry.html), [API Stability](https://hexdocs.pm/lattice_stripe/api_stability.html), [Extending LatticeStripe](https://hexdocs.pm/lattice_stripe/extending-lattice-stripe.html), [Cheatsheet](https://hexdocs.pm/lattice_stripe/cheatsheet.html)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

MIT — see [LICENSE](LICENSE) for details.
