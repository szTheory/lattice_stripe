# LatticeStripe

[![Hex.pm](https://img.shields.io/hexpm/v/lattice_stripe.svg)](https://hex.pm/packages/lattice_stripe)
[![CI](https://github.com/szTheory/lattice_stripe/actions/workflows/ci.yml/badge.svg)](https://github.com/szTheory/lattice_stripe/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/lattice_stripe)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **Current release:** **`2.1.x`** on [Hex](https://hex.pm/packages/lattice_stripe) — see [CHANGELOG](CHANGELOG.md#210) for what shipped since 2.0.0. Evaluating fit? Start with [User Flows & JTBD][user-flows-and-jtbd].

A production-grade, idiomatic Elixir SDK for the Stripe API.

Full documentation available on [HexDocs](https://hexdocs.pm/lattice_stripe).

If you are evaluating how this fits into a real SaaS billing architecture, start with
[Guide: User Flows & JTBD][user-flows-and-jtbd].

## v1.x scope

As of **1.7.0**, LatticeStripe is **feature-complete for its intended v1.x scope**: mainstream SaaS integrations — payments, billing, Connect, tax on custom flows, webhooks (including thin events), and production operator guides.

**Not in v1.x scope** (maintenance mode; additions only on adopter pull):

- **Specialist Stripe families:** Identity; Treasury; Issuing; Terminal; Financial Connections; Climate; Sigma; Reporting
- **Tax narrow follow-ups:** Tax Code lookup (`/v1/tax_codes`); Tax Transaction list (if Stripe adds the endpoint)

See [Scope][scope] for boundaries, escape hatches, and how to request coverage.
See [API Stability][api-stability] for the semver contract.

## Docs Ladder

Use the docs in this order:

- **README** for the repo-level surface map and route-by-intent overview
- **[Getting Started][getting-started]** for first success with a live client and API call
- **[User Flows & JTBD][user-flows-and-jtbd]** for "which Stripe path fits my SaaS?"
- **[Scope][scope]** for v1.x boundaries and deferred families
- **Canonical guides** for the surface you will actually ship
- **[Recipes][recipes]** for compact job-to-primitive bridges
- **[Webhooks][webhooks]**, **[Production Checklist][production-checklist]**, **[Event Debugging][event-debugging]**, **[Testing][testing]**, and **[Error Handling][error-handling]** for runtime truth and support posture

## Choose Your Route

- **I want first success fast**:
  [Getting Started][getting-started], [Payments][payments], [Checkout][checkout]
- **I am evaluating recurring billing for a SaaS**:
  [User Flows & JTBD][user-flows-and-jtbd], [Subscriptions][subscriptions], [Customer Portal][customer-portal], [Webhooks][webhooks]
- **I need usage-based billing and reconciliation**:
  [Metering][metering], [Webhooks][webhooks], [Testing][testing]
- **I calculate tax on custom payment flows (not only Checkout/Invoices)**:
  [Tax][tax], [Payments][payments], [Testing][testing]
- **I run a marketplace or platform**:
  [Connect][connect], [Connect Accounts][connect-accounts], [Connect Money Movement][connect-money-movement]
- **I am hardening ops and support paths**:
  [Production Checklist][production-checklist], [Error Handling][error-handling], [Testing][testing], [Webhooks][webhooks], [Webhooks: Thin Events][webhooks-thin-events], [Event Debugging][event-debugging]

## Installation

Add `lattice_stripe` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:lattice_stripe, "~> 2.1"}
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
- Structured, pattern-matchable errors: `:card_error`, `:authentication_error`, `:rate_limit_error`, `:api_error`, and more — [Guide: Error Handling][error-handling]
- Auto-pagination — stream through large result sets lazily with Elixir Streams
- [Guide: Payments][payments]

### Billing

- Invoices — create, finalize, pay, void, send, list, search
- Credit Notes — preview, create, void, and inspect/stream line items
- Quotes — create, finalize, accept/cancel, inspect/stream line items, and download PDFs
- Subscriptions with lifecycle verbs (cancel, resume, pause_collection, trial settings)
- Subscription Schedules for phased billing with proration guards
- Billing Metering — usage-based billing with `Meter`, `MeterEvent`, and `MeterEventAdjustment`; two-layer idempotency and pre-flight value guards
- Customer Portal — `BillingPortal.Session` for self-service portal URLs with 4 flow types (subscription_cancel, subscription_update, subscription_update_confirm, payment_method_update) and Inspect masking
- [Guide: Subscriptions][subscriptions] · [Guide: Credit Notes][credit-notes] · [Guide: Metering][metering] · [Guide: Tax][tax] · [Guide: Customer Portal][customer-portal]

### Operations and diagnostics

- Files and FileLinks — upload files to Stripe, manage shareable file links, and download binary content
- Disputes — retrieve/list, update metadata, stage evidence safely, submit evidence, and close disputes
- Mandates and SetupAttempts — inspect payment authorization state and SetupIntent failure history
- Operator playbooks: [Production Checklist][production-checklist] · [Event Debugging][event-debugging]
- [Guide: Recipes][recipes] · [Guide: Webhooks][webhooks] · [Guide: Webhooks: Thin Events][webhooks-thin-events] · [Guide: Testing][testing]
- Full ops guide ladder: [Docs Ladder](#docs-ladder) and [User Flows & JTBD][user-flows-and-jtbd] (Job 7)

### Connect

- Connect accounts (Standard, Express, Custom) with onboarding AccountLinks
- Transfers, TransferReversals, Payouts, External Accounts
- Balance + BalanceTransactions for platform-fee reconciliation
- Per-client and per-request `stripe_account` for platform integrations
- [Guide: Connect][connect]

### Platform

- Pluggable `Transport`, `Json`, and `RetryStrategy` behaviours — bring your own HTTP client
- Automatic retry with exponential backoff, respecting Stripe's `Stripe-Should-Retry` header
- Automatic idempotency-key generation and safe replay
- Telemetry events for every request, compatible with any monitoring stack
- Phoenix-ready `Webhook.Plug` snapshot path + thin-event (`/v2/events`) helpers for fetch-after-verify integration
- [Guide: Extending LatticeStripe][extending-lattice-stripe]

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

- [Getting Started][getting-started]
- [User Flows & JTBD][user-flows-and-jtbd]
- [Recipes][recipes]

Canonical guide clusters:

- **Payments and billing primitives**:
  [Payments][payments], [Checkout][checkout], [Invoices][invoices], [Credit Notes][credit-notes], [Subscriptions][subscriptions], [Customer Portal][customer-portal], [Metering][metering], [Tax][tax], [Charge API](https://hexdocs.pm/lattice_stripe/LatticeStripe.Charge.html)
- **Connect**:
  [Connect][connect], [Connect Accounts][connect-accounts], [Connect Money Movement][connect-money-movement]
- **Operations and DX**:
  [Webhooks][webhooks], [Webhooks: Thin Events][webhooks-thin-events], [Production Checklist][production-checklist], [Event Debugging][event-debugging], [Testing][testing], [Error Handling][error-handling], [Client Configuration][client-configuration], [Performance][performance], [Circuit Breaker][circuit-breaker], [OpenTelemetry][opentelemetry], [Telemetry][telemetry], [API Stability][api-stability], [Extending LatticeStripe][extending-lattice-stripe], [Cheatsheet][cheatsheet]

## Contributing

See [CONTRIBUTING.md](https://github.com/szTheory/lattice_stripe/blob/main/CONTRIBUTING.md) for development setup and guidelines.

## License

MIT — see [LICENSE](LICENSE) for details.

<!-- HexDocs guide links (README is not an ExDoc extra; use HexDocs URLs for hex.pm + GitHub portability) -->
[getting-started]: https://hexdocs.pm/lattice_stripe/getting-started.html
[user-flows-and-jtbd]: https://hexdocs.pm/lattice_stripe/user-flows-and-jtbd.html
[scope]: https://hexdocs.pm/lattice_stripe/scope.html
[api-stability]: https://hexdocs.pm/lattice_stripe/api_stability.html
[recipes]: https://hexdocs.pm/lattice_stripe/recipes.html
[payments]: https://hexdocs.pm/lattice_stripe/payments.html
[checkout]: https://hexdocs.pm/lattice_stripe/checkout.html
[subscriptions]: https://hexdocs.pm/lattice_stripe/subscriptions.html
[customer-portal]: https://hexdocs.pm/lattice_stripe/customer-portal.html
[metering]: https://hexdocs.pm/lattice_stripe/metering.html
[tax]: https://hexdocs.pm/lattice_stripe/tax.html
[connect]: https://hexdocs.pm/lattice_stripe/connect.html
[connect-accounts]: https://hexdocs.pm/lattice_stripe/connect-accounts.html
[connect-money-movement]: https://hexdocs.pm/lattice_stripe/connect-money-movement.html
[production-checklist]: https://hexdocs.pm/lattice_stripe/production-checklist.html
[event-debugging]: https://hexdocs.pm/lattice_stripe/event-debugging.html
[webhooks]: https://hexdocs.pm/lattice_stripe/webhooks.html
[webhooks-thin-events]: https://hexdocs.pm/lattice_stripe/webhooks-thin-events.html
[testing]: https://hexdocs.pm/lattice_stripe/testing.html
[error-handling]: https://hexdocs.pm/lattice_stripe/error-handling.html
[credit-notes]: https://hexdocs.pm/lattice_stripe/credit_notes.html
[extending-lattice-stripe]: https://hexdocs.pm/lattice_stripe/extending-lattice-stripe.html
[invoices]: https://hexdocs.pm/lattice_stripe/invoices.html
[client-configuration]: https://hexdocs.pm/lattice_stripe/client-configuration.html
[performance]: https://hexdocs.pm/lattice_stripe/performance.html
[circuit-breaker]: https://hexdocs.pm/lattice_stripe/circuit-breaker.html
[opentelemetry]: https://hexdocs.pm/lattice_stripe/opentelemetry.html
[telemetry]: https://hexdocs.pm/lattice_stripe/telemetry.html
[cheatsheet]: https://hexdocs.pm/lattice_stripe/cheatsheet.html
