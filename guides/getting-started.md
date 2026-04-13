# Getting Started

LatticeStripe is a production-grade Elixir SDK for the Stripe API. This guide walks you
through installation, setup, and your first API call — from zero to a working PaymentIntent
in just a few minutes.

## Installation

Add `lattice_stripe` to your dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:lattice_stripe, "~> 0.1"},
    {:finch, "~> 0.21"}
  ]
end
```

Then fetch your dependencies:

```
$ mix deps.get
```

> **Note:** Finch is listed separately here to make it explicit. LatticeStripe declares Finch
> as a dependency, but listing it in your app's `mix.exs` lets you configure the version you want.

## Setting Up Finch

LatticeStripe uses [Finch](https://hex.pm/packages/finch) as its HTTP client. Finch is a
connection-pooling HTTP library built on Mint — the modern standard for HTTP in Elixir.

You need to start a Finch pool in your application's supervision tree. Add it to
`lib/my_app/application.ex`:

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Finch HTTP client for LatticeStripe
      {Finch, name: MyApp.Finch},

      # ... your other children
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

The `name:` option is an atom that identifies this pool. You'll pass the same atom when
creating a LatticeStripe client.

> **Non-OTP scripts:** If you're writing a one-off script (not a full OTP application),
> start Finch manually before making API calls:
>
> ```elixir
> {:ok, _} = Finch.start_link(name: MyApp.Finch)
> ```

## Creating a Client

LatticeStripe is configured through a plain struct — no global state, no config files.
Create a client with your Stripe API key and your Finch pool name:

```elixir
client = LatticeStripe.Client.new!(
  api_key: "sk_test_YOUR_STRIPE_TEST_KEY",
  finch: MyApp.Finch
)
```

Both `api_key` and `finch` are required. Everything else has sensible defaults.

**Where to get your API keys:** Log in to the [Stripe Dashboard](https://dashboard.stripe.com/apikeys).
Use `sk_test_...` keys in development — they don't charge real cards.

### Storing the Client

The client is a plain `%LatticeStripe.Client{}` struct. There's no process behind it —
you can store it anywhere that makes sense for your app:

```elixir
# As a module attribute (simple, read-only)
defmodule MyApp.Stripe do
  @client LatticeStripe.Client.new!(
    api_key: Application.fetch_env!(:my_app, :stripe_api_key),
    finch: MyApp.Finch
  )

  def client, do: @client
end
```

Or create it at runtime and pass it through your function calls. The struct is safe to
share across processes.

## Your First API Call

With a client in hand, you can make Stripe API calls. Let's create a PaymentIntent — the
core object for accepting payments in Stripe's modern payment flow:

```elixir
{:ok, intent} = LatticeStripe.PaymentIntent.create(client, %{
  "amount" => 2000,
  "currency" => "usd"
})

IO.puts("Created PaymentIntent: #{intent.id}")
IO.puts("Amount: $#{intent.amount / 100}")
IO.puts("Status: #{intent.status}")
```

Run this and you'll see output like:

```
Created PaymentIntent: pi_3OzqKZ2eZvKYlo2C1FRzQc8s
Amount: $20.0
Status: requires_payment_method
```

A few things to note:
- **Amount is in cents.** `2000` means $20.00 USD. Always use the smallest currency unit.
- **The response is a struct.** `intent` is a `%LatticeStripe.PaymentIntent{}` — all fields
  are accessible as atoms.
- **Test mode is safe.** Using `sk_test_...` keys means no real charges happen.

## Handling Errors

All LatticeStripe functions return `{:ok, result}` on success or `{:error, %LatticeStripe.Error{}}` on failure. Pattern match on the result to handle errors gracefully:

```elixir
case LatticeStripe.PaymentIntent.create(client, %{
  "amount" => 2000,
  "currency" => "usd"
}) do
  {:ok, intent} ->
    IO.puts("Created PaymentIntent: #{intent.id}")

  {:error, %LatticeStripe.Error{type: :card_error} = err} ->
    IO.puts("Card declined: #{err.message}")
    IO.puts("Decline code: #{err.decline_code}")

  {:error, %LatticeStripe.Error{type: :rate_limit_error}} ->
    IO.puts("Too many requests — back off and retry")

  {:error, %LatticeStripe.Error{type: :authentication_error}} ->
    IO.puts("Invalid API key — check your credentials")

  {:error, %LatticeStripe.Error{} = err} ->
    IO.puts("Stripe error: #{err.message} (#{err.type})")
end
```

The `LatticeStripe.Error` struct contains:
- `type` — atom like `:card_error`, `:invalid_request_error`, `:authentication_error`, `:rate_limit_error`, `:api_error`
- `message` — human-readable description
- `code` — Stripe error code (e.g., `"card_declined"`)
- `param` — the invalid parameter, for validation errors
- `status` — the HTTP status code
- `request_id` — Stripe's request ID, useful for support tickets

### Bang Variants

If you'd rather raise on error than pattern match, every function has a bang variant:

```elixir
# Raises LatticeStripe.Error if the call fails
intent = LatticeStripe.PaymentIntent.create!(client, %{
  "amount" => 2000,
  "currency" => "usd"
})
```

Use the `!` variants in scripts and places where you want to fail loudly. Use the
non-bang variants in production code where you need to handle errors gracefully.

## Next Steps

Now that you've made your first API call, explore the rest of LatticeStripe:

- **[Client Configuration](client-configuration.html)** — All client options, per-request
  overrides, multiple clients, Stripe Connect.
- **[Payments](payments.html)** — Full payment lifecycle: customers, PaymentIntents,
  confirmation, capture, refunds, idempotency.
- **[Checkout](checkout.html)** — Stripe's hosted payment page. Payment, subscription, and
  setup modes.
- **[Webhooks](webhooks.html)** — Signature verification, Phoenix Plug setup, event handling.

## Common Pitfalls

**Finch must be started before making API calls.**
If you see `(Finch.Error) no pool found` errors, Finch isn't in your supervision tree or
hasn't started yet. Make sure `{Finch, name: MyApp.Finch}` is in your `children` list in
`application.ex`.

**Amount is in cents, not dollars.**
`2000` means $20.00 USD, not $2,000. This is a very common mistake that produces confusing
results. The Stripe API always uses the smallest unit of the currency (cents for USD,
pence for GBP, etc.).

**Use test mode keys (`sk_test_...`) in development.**
Test keys start with `sk_test_`. Live keys start with `sk_live_`. Never use live keys in
development or CI — test mode keys can't charge real cards, so mistakes are harmless.

**Client is a struct, not a process.**
You don't need to start a GenServer or add LatticeStripe to your supervision tree (beyond
Finch). Just create the struct and pass it around. It's safe to share across processes.

**Validation errors raise, not return `{:error, ...}`.**
If you pass invalid options to `Client.new!`, it raises `NimbleOptions.ValidationError`
immediately. This catches typos and misconfiguration at startup, not at request time.

## Next steps

- See [Subscriptions](subscriptions.md) for recurring billing and dunning lifecycles.
- See [Connect](connect.md) for marketplace and platform use cases.
