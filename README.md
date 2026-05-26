# LatticeStripe

[![Hex.pm](https://img.shields.io/hexpm/v/lattice_stripe.svg)](https://hex.pm/packages/lattice_stripe)
[![CI](https://github.com/szTheory/lattice_stripe/actions/workflows/ci.yml/badge.svg)](https://github.com/szTheory/lattice_stripe/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/lattice_stripe)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **Release status:** The `1.3.x` line is the current published surface. This repo
> includes the shipped v1.3 production-coverage work: File/FileLink transport,
> Disputes, Credit Notes, Mandates, SetupAttempts, Quotes, recipes, and the
> Phoenix webhook quickstart. See [CHANGELOG.md](CHANGELOG.md).

A production-grade, idiomatic Elixir SDK for the Stripe API.

Full documentation available on [HexDocs](https://hexdocs.pm/lattice_stripe).

If you are evaluating how this fits into a real SaaS billing architecture, start with
[Guide: User Flows & JTBD](guides/user-flows-and-jtbd.md).

## Docs Ladder

Use the docs in this order:

- **README** for the repo-level surface map and route-by-intent overview
- **[Getting Started](guides/getting-started.md)** for first success with a live client and API call
- **[User Flows & JTBD](guides/user-flows-and-jtbd.md)** for "which Stripe path fits my SaaS?"
- **Canonical guides** for the surface you will actually ship
- **[Recipes](guides/recipes.md)** for compact job-to-primitive bridges
- **[Webhooks](guides/webhooks.md)**, **[Testing](guides/testing.md)**, and **[Error Handling](guides/error-handling.md)** for runtime truth and support posture

## Choose Your Route

- **I want first success fast**:
  [Getting Started](guides/getting-started.md), [Payments](guides/payments.md), [Checkout](guides/checkout.md)
- **I am evaluating recurring billing for a SaaS**:
  [User Flows & JTBD](guides/user-flows-and-jtbd.md), [Subscriptions](guides/subscriptions.md), [Customer Portal](guides/customer-portal.md), [Webhooks](guides/webhooks.md)
- **I need usage-based billing and reconciliation**:
  [Metering](guides/metering.md), [Webhooks](guides/webhooks.md), [Testing](guides/testing.md)
- **I run a marketplace or platform**:
  [Connect](guides/connect.md), [Connect Accounts](guides/connect-accounts.md), [Connect Money Movement](guides/connect-money-movement.md)
- **I am hardening ops and support paths**:
  [Error Handling](guides/error-handling.md), [Testing](guides/testing.md), [Webhooks](guides/webhooks.md)

## Installation

Add `lattice_stripe` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:lattice_stripe, "~> 1.3"}
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
- Structured, pattern-matchable errors: `:card_error`, `:auth_error`, `:rate_limit_error`, `:server_error`, and more
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
- [Guide: Subscriptions](guides/subscriptions.md) · [Guide: Credit Notes](guides/credit_notes.md) · [Guide: Metering](guides/metering.md) · [Guide: Customer Portal](guides/customer-portal.md)

### Operations and diagnostics

- Files and FileLinks — upload files to Stripe, manage shareable file links, and download binary content
- Disputes — retrieve/list, update metadata, stage evidence safely, submit evidence, and close disputes
- Mandates and SetupAttempts — inspect payment authorization state and SetupIntent failure history
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
- Phoenix-ready `Webhook.Plug` with raw-body capture and signature verification
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
  [Payments](https://hexdocs.pm/lattice_stripe/payments.html), [Checkout](https://hexdocs.pm/lattice_stripe/checkout.html), [Invoices](https://hexdocs.pm/lattice_stripe/invoices.html), [Credit Notes](https://hexdocs.pm/lattice_stripe/credit_notes.html), [Subscriptions](https://hexdocs.pm/lattice_stripe/subscriptions.html), [Customer Portal](https://hexdocs.pm/lattice_stripe/customer-portal.html), [Metering](https://hexdocs.pm/lattice_stripe/metering.html)
- **Connect**:
  [Connect](https://hexdocs.pm/lattice_stripe/connect.html), [Connect Accounts](https://hexdocs.pm/lattice_stripe/connect-accounts.html), [Connect Money Movement](https://hexdocs.pm/lattice_stripe/connect-money-movement.html)
- **Operations and DX**:
  [Webhooks](https://hexdocs.pm/lattice_stripe/webhooks.html), [Testing](https://hexdocs.pm/lattice_stripe/testing.html), [Error Handling](https://hexdocs.pm/lattice_stripe/error-handling.html), [Client Configuration](https://hexdocs.pm/lattice_stripe/client-configuration.html), [Performance](https://hexdocs.pm/lattice_stripe/performance.html), [Circuit Breaker](https://hexdocs.pm/lattice_stripe/circuit-breaker.html), [OpenTelemetry](https://hexdocs.pm/lattice_stripe/opentelemetry.html), [Telemetry](https://hexdocs.pm/lattice_stripe/telemetry.html), [API Stability](https://hexdocs.pm/lattice_stripe/api_stability.html), [Extending LatticeStripe](https://hexdocs.pm/lattice_stripe/extending-lattice-stripe.html), [Cheatsheet](https://hexdocs.pm/lattice_stripe/cheatsheet.html)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

MIT — see [LICENSE](LICENSE) for details.
