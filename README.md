# LatticeStripe

[![Hex.pm](https://img.shields.io/hexpm/v/lattice_stripe.svg)](https://hex.pm/packages/lattice_stripe)
[![CI](https://github.com/lattice-stripe/lattice_stripe/actions/workflows/ci.yml/badge.svg)](https://github.com/lattice-stripe/lattice_stripe/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/lattice_stripe)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A production-grade, idiomatic Elixir SDK for the Stripe API.

Full documentation available on [HexDocs](https://hexdocs.pm/lattice_stripe).

## Installation

Add `lattice_stripe` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:lattice_stripe, "~> 0.1"}
  ]
end
```

## Quick Start

Add Finch to your supervision tree in `application.ex`:

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

- **Payments** — Customer, PaymentIntent, SetupIntent, PaymentMethod, Refund
- **Checkout** — Checkout.Session (payment, subscription, and setup modes)
- **Webhooks** — Signature verification and Phoenix Plug integration
- **Auto-pagination** — Stream through large result sets lazily with Elixir Streams
- **Telemetry** — Request lifecycle events compatible with any monitoring stack
- **Configurable transport** — Finch by default; bring your own HTTP client via the Transport behaviour
- **Retry with backoff** — Automatic exponential backoff respecting Stripe's `Stripe-Should-Retry` header
- **Idempotency** — Automatic idempotency key generation and replay handling
- **Structured errors** — Pattern-matchable error types: `:card_error`, `:auth_error`, `:rate_limit_error`, `:server_error`, and more
- **Connect support** — Per-client and per-request `stripe_account` for platform integrations

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
