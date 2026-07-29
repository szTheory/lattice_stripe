# Getting Started

LatticeStripe is a production-grade Elixir SDK for the Stripe API. This guide walks you
through installation, setup, and your first API call — from zero to a working PaymentIntent
in just a few minutes.

## Installation

Add `lattice_stripe` to your dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:lattice_stripe, "~> 2.1"},
    {:finch, "~> 0.21"}
  ]
end
```

> **Current Hex line:** **`2.1.x`** published on Hex — see [README](https://github.com/szTheory/lattice_stripe#readme) and [CHANGELOG](../CHANGELOG.md#210).

Then fetch your dependencies:

```
$ mix deps.get
```

> **Note:** Finch is listed separately here to make it explicit. LatticeStripe declares Finch
> as a dependency, but listing it in your app's `mix.exs` lets you configure the version you want.

## Setting Up Finch

LatticeStripe uses [Finch](https://hex.pm/packages/finch) as its HTTP client. Finch is a
connection-pooling HTTP library built on Mint — the modern standard for HTTP in Elixir.

> **A default pool starts automatically.** As of the default-pool change, LatticeStripe ships
> an optional `LatticeStripe.Application` that starts a `LatticeStripe.Finch` pool in its own
> supervision tree at boot. You don't have to start a pool yourself — `:finch` defaults to this
> `LatticeStripe.Finch` pool. The manual setup below is now **optional**: use it when you want
> your own named pool (custom pool sizing, sharing one pool across libraries, or full control of
> your supervision tree).
>
> **Already start your own Finch pool?** You can prevent the default pool from starting (so you
> don't run a duplicate idle pool) by adding to your config:
>
> ```elixir
> config :lattice_stripe, start_default_finch: false
> ```

If you want your own pool instead of (or in addition to) the default, start a Finch pool in your
application's supervision tree. Add it to `lib/my_app/application.ex`:

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
The only required option is your Stripe API key:

```elixir
# :finch defaults to the auto-started LatticeStripe.Finch pool
client = LatticeStripe.Client.new!(
  api_key: "sk_test_YOUR_STRIPE_TEST_KEY"
)
```

Only `api_key` is required. `:finch` now defaults to the auto-started `LatticeStripe.Finch`
pool, so you can omit it. If you run your own named pool, pass it explicitly to override the
default:

```elixir
client = LatticeStripe.Client.new!(
  api_key: "sk_test_YOUR_STRIPE_TEST_KEY",
  finch: MyApp.Finch
)
```

Everything else has sensible defaults.

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
Status: :requires_payment_method
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

## Read Next After First Success

You have a working client and a successful first call. Pick the next guide by the job
you are trying to ship:

- **I need the bigger SaaS map**:
  [User Flows & JTBD](user-flows-and-jtbd.md) for route-by-intent guidance across billing,
  metering, Connect, and support flows.
- **I am moving from one payment to recurring billing**:
  [Subscriptions](subscriptions.md) for lifecycle control and
  [Customer Portal](customer-portal.md) for self-serve plan or payment-method changes.
- **I need hosted payments or hosted subscription signup**:
  [Checkout](checkout.md) for Stripe-hosted payment, setup, and subscription flows.
- **I need async truth before I provision or fulfill**:
  [Webhooks](webhooks.md) because API responses tell you what Stripe accepted now, while
  webhooks confirm what became true.
- **I need usage-based billing**:
  [Metering](metering.md) for meter definitions, hot-path event reporting, and reconciliation.
- **I run a marketplace or platform**:
  [Connect](connect.md) for the high-level model, then
  [Connect Accounts](connect-accounts.md) and
  [Connect Money Movement](connect-money-movement.md).
- **I am hardening support and local confidence**:
  [Testing](testing.md), [Error Handling](error-handling.md), and
  [Client Configuration](client-configuration.md).

## Common Pitfalls

**Custom Finch pools must be started before making API calls.**
The default `LatticeStripe.Finch` pool starts automatically, so the common case just works. But
if you pass your own pool name (`finch: MyApp.Finch`) that pool must be running. If you see
`(Finch.Error) no pool found` errors, your named Finch pool isn't in your supervision tree or
hasn't started yet — make sure `{Finch, name: MyApp.Finch}` is in your `children` list in
`application.ex`. (If you disabled the default pool with
`config :lattice_stripe, start_default_finch: false`, you must start a pool yourself.)

**Amount is in cents, not dollars.**
`2000` means $20.00 USD, not $2,000. This is a very common mistake that produces confusing
results. The Stripe API always uses the smallest unit of the currency (cents for USD,
pence for GBP, etc.).

**Use test mode keys (`sk_test_...`) in development.**
Test keys start with `sk_test_`. Live keys start with `sk_live_`. Never use live keys in
development or CI — test mode keys can't charge real cards, so mistakes are harmless.

**Client is a struct, not a process.**
You don't need to start a GenServer or add LatticeStripe to your supervision tree. The default
`LatticeStripe.Finch` pool starts on its own, so unless you bring your own named pool there's
nothing to wire. Just create the struct and pass it around. It's safe to share across processes.

**Validation errors raise, not return `{:error, ...}`.**
If you pass invalid options to `Client.new!`, it raises `NimbleOptions.ValidationError`
immediately. This catches typos and misconfiguration at startup, not at request time.
