# LatticeStripe

[![Hex.pm](https://img.shields.io/hexpm/v/lattice_stripe.svg)](https://hex.pm/packages/lattice_stripe)
[![CI](https://github.com/szTheory/lattice_stripe/actions/workflows/ci.yml/badge.svg)](https://github.com/szTheory/lattice_stripe/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/lattice_stripe)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **What's new in v1.0** — LatticeStripe 1.0 ships with full Billing (Invoices, Subscriptions, Schedules) and Connect (Accounts, Transfers, Payouts, Balance) coverage. See the [v1.0 highlights in CHANGELOG](CHANGELOG.md#100).

A production-grade, idiomatic Elixir SDK for the Stripe API.

Full documentation available on [HexDocs](https://hexdocs.pm/lattice_stripe).

## Installation

Add `lattice_stripe` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:lattice_stripe, "~> 0.2"}
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
- Subscriptions with lifecycle verbs (cancel, resume, pause_collection, trial settings)
- Subscription Schedules for phased billing with proration guards
- [Guide: Subscriptions](guides/subscriptions.md)

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

Guides available:

- [Getting Started](https://hexdocs.pm/lattice_stripe/getting-started.html)
- [Client Configuration](https://hexdocs.pm/lattice_stripe/client-configuration.html)
- [Payments](https://hexdocs.pm/lattice_stripe/payments.html)
- [Checkout](https://hexdocs.pm/lattice_stripe/checkout.html)
- [Webhooks](https://hexdocs.pm/lattice_stripe/webhooks.html)
- [Error Handling](https://hexdocs.pm/lattice_stripe/error-handling.html)
- [Testing](https://hexdocs.pm/lattice_stripe/testing.html)
- [Telemetry](https://hexdocs.pm/lattice_stripe/telemetry.html)
- [Extending LatticeStripe](https://hexdocs.pm/lattice_stripe/extending-lattice-stripe.html)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

MIT — see [LICENSE](LICENSE) for details.
