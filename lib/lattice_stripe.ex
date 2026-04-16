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

  @doc """
  Pre-establishes Finch connections to the Stripe API.

  Call this in your `Application.start/2` callback after starting Finch and creating
  a client. It sends a lightweight `GET /v1/` request through the configured transport,
  establishing the TLS handshake and HTTP connection. Subsequent API calls skip the
  handshake latency.

  Returns `{:ok, :warmed}` on any HTTP response (including Stripe's expected 404 from
  `GET /v1/` — the TLS handshake is what matters). Only transport-level failures
  (network unreachable, timeout) return `{:error, reason}`.

  ## Example

      def start(_type, _args) do
        children = [
          {Finch, name: MyApp.Finch}
        ]
        {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one)

        client = LatticeStripe.Client.new!(
          api_key: System.fetch_env!("STRIPE_SECRET_KEY"),
          finch: MyApp.Finch
        )
        case LatticeStripe.warm_up(client) do
          {:ok, :warmed} -> :ok
          {:error, reason} ->
            require Logger
            Logger.warning("Stripe connection warm-up failed: \#{inspect(reason)}")
        end

        {:ok, sup}
      end
  """
  @spec warm_up(LatticeStripe.Client.t()) :: {:ok, :warmed} | {:error, term()}
  def warm_up(%LatticeStripe.Client{} = client) do
    url = client.base_url <> "/v1/"

    transport_request = %{
      method: :get,
      url: url,
      headers: [{"authorization", "Bearer #{client.api_key}"}],
      body: nil,
      opts: [finch: client.finch, timeout: client.timeout]
    }

    case client.transport.request(transport_request) do
      {:ok, _response} -> {:ok, :warmed}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Pre-establishes Finch connections to the Stripe API, raising on failure.

  Same as `warm_up/1` but raises `RuntimeError` if the transport connection fails.
  Returns `:warmed` on success.

  ## Example

      # In Application.start/2 when warm-up failure should crash startup:
      :warmed = LatticeStripe.warm_up!(client)
  """
  @spec warm_up!(LatticeStripe.Client.t()) :: :warmed
  def warm_up!(%LatticeStripe.Client{} = client) do
    case warm_up(client) do
      {:ok, :warmed} -> :warmed
      {:error, reason} -> raise "Stripe connection warm-up failed: #{inspect(reason)}"
    end
  end
end
