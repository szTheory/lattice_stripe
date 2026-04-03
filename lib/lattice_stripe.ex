defmodule LatticeStripe do
  @moduledoc """
  A production-grade, idiomatic Elixir SDK for the Stripe API.

  LatticeStripe provides a complete Stripe integration for Elixir applications —
  payments, webhooks, telemetry, and test helpers included.

  ## Quick Start

  Add LatticeStripe to your supervision tree, then create a client and make calls:

      # In your application supervisor:
      children = [
        {Finch, name: MyApp.Finch}
      ]

      # Create a client (once, at startup):
      client = LatticeStripe.Client.new!(
        api_key: "sk_test_...",
        finch: MyApp.Finch
      )

      # Charge a customer:
      {:ok, pi} = LatticeStripe.PaymentIntent.create(client, %{
        "amount" => 2000,
        "currency" => "usd"
      })

  ## Modules

  - `LatticeStripe.Client` — Create and configure API clients
  - `LatticeStripe.PaymentIntent` — Accept payments
  - `LatticeStripe.Customer` — Manage customers
  - `LatticeStripe.PaymentMethod` — Save and reuse payment instruments
  - `LatticeStripe.SetupIntent` — Save payment methods for future use
  - `LatticeStripe.Refund` — Issue refunds
  - `LatticeStripe.Checkout.Session` — Hosted payment pages
  - `LatticeStripe.Webhook` — Verify and handle incoming webhooks
  - `LatticeStripe.Telemetry` — Observability events
  - `LatticeStripe.Testing` — Test helpers for webhook simulation

  ## Error Handling

  All functions return `{:ok, result}` or `{:error, %LatticeStripe.Error{}}`.
  The `Error.type` field enables clean pattern matching:

      case LatticeStripe.Customer.create(client, params) do
        {:ok, customer} -> handle_success(customer)
        {:error, %LatticeStripe.Error{type: :card_error} = err} -> handle_card_error(err)
        {:error, %LatticeStripe.Error{type: :rate_limit_error}} -> handle_rate_limit()
        {:error, %LatticeStripe.Error{}} -> handle_error()
      end

  Bang variants (`create!/2`, `retrieve!/2`, etc.) raise `LatticeStripe.Error` on failure.
  """

  @stripe_api_version "2026-03-25.dahlia"

  @doc """
  Returns the Stripe API version this release of LatticeStripe is pinned to.

  This version is used as the default `Stripe-Version` header on all requests.
  Override per-client via the `:api_version` option in `LatticeStripe.Client.new!/1`,
  or per-request via the `:stripe_version` option in request opts.
  """
  @spec api_version() :: String.t()
  def api_version, do: @stripe_api_version
end
