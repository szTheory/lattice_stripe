defmodule LatticeStripe.MixProject do
  use Mix.Project

  @version "1.1.0"
  @source_url "https://github.com/szTheory/lattice_stripe"

  def project do
    [
      app: :lattice_stripe,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      name: "LatticeStripe",
      description: "A production-grade, idiomatic Elixir SDK for the Stripe API",
      source_url: @source_url,
      docs: [
        main: "getting-started",
        source_url: @source_url,
        source_ref: "v#{@version}",
        # logo: "assets/logo.png",  # Add when logo asset is created
        extras: [
          "guides/getting-started.md",
          "guides/client-configuration.md",
          "guides/performance.md",
          "guides/circuit-breaker.md",
          "guides/opentelemetry.md",
          "guides/payments.md",
          "guides/checkout.md",
          "guides/invoices.md",
          "guides/metering.md",
          "guides/subscriptions.md",
          "guides/connect.md",
          "guides/connect-accounts.md",
          "guides/connect-money-movement.md",
          "guides/customer-portal.md",
          "guides/webhooks.md",
          "guides/error-handling.md",
          "guides/testing.md",
          "guides/telemetry.md",
          "guides/api_stability.md",
          "guides/extending-lattice-stripe.md",
          "guides/cheatsheet.cheatmd",
          "CHANGELOG.md"
        ],
        groups_for_extras: [
          Guides: Path.wildcard("guides/*.{md,cheatmd}"),
          Changelog: ["CHANGELOG.md"]
        ],
        groups_for_modules: [
          "Client & Configuration": [
            LatticeStripe,
            LatticeStripe.Client,
            LatticeStripe.Batch,
            LatticeStripe.Config,
            LatticeStripe.Error,
            LatticeStripe.Response,
            LatticeStripe.List,
            LatticeStripe.Request
          ],
          Payments: [
            LatticeStripe.PaymentIntent,
            LatticeStripe.Customer,
            LatticeStripe.PaymentMethod,
            LatticeStripe.SetupIntent,
            LatticeStripe.Refund
          ],
          Checkout: [
            LatticeStripe.Checkout.Session,
            LatticeStripe.Checkout.LineItem
          ],
          Billing: [
            LatticeStripe.Invoice,
            LatticeStripe.Invoice.LineItem,
            LatticeStripe.Invoice.StatusTransitions,
            LatticeStripe.Invoice.AutomaticTax,
            LatticeStripe.InvoiceItem,
            LatticeStripe.InvoiceItem.Period,
            LatticeStripe.Subscription,
            LatticeStripe.Subscription.CancellationDetails,
            LatticeStripe.Subscription.PauseCollection,
            LatticeStripe.Subscription.TrialSettings,
            LatticeStripe.SubscriptionItem,
            LatticeStripe.SubscriptionSchedule,
            LatticeStripe.SubscriptionSchedule.Phase,
            LatticeStripe.SubscriptionSchedule.CurrentPhase,
            LatticeStripe.SubscriptionSchedule.PhaseItem,
            LatticeStripe.SubscriptionSchedule.AddInvoiceItem
          ],
          "Customer Portal": [
            LatticeStripe.BillingPortal.Session,
            LatticeStripe.BillingPortal.Session.FlowData,
            LatticeStripe.BillingPortal.Session.FlowData.AfterCompletion,
            LatticeStripe.BillingPortal.Session.FlowData.SubscriptionCancel,
            LatticeStripe.BillingPortal.Session.FlowData.SubscriptionUpdate,
            LatticeStripe.BillingPortal.Session.FlowData.SubscriptionUpdateConfirm,
            LatticeStripe.BillingPortal.Configuration,
            LatticeStripe.BillingPortal.Configuration.Features,
            LatticeStripe.BillingPortal.Configuration.Features.CustomerUpdate,
            LatticeStripe.BillingPortal.Configuration.Features.PaymentMethodUpdate,
            LatticeStripe.BillingPortal.Configuration.Features.SubscriptionCancel,
            LatticeStripe.BillingPortal.Configuration.Features.SubscriptionUpdate
          ],
          "Billing Metering": [
            LatticeStripe.Billing.Meter,
            LatticeStripe.Billing.Meter.DefaultAggregation,
            LatticeStripe.Billing.Meter.CustomerMapping,
            LatticeStripe.Billing.Meter.ValueSettings,
            LatticeStripe.Billing.Meter.StatusTransitions,
            LatticeStripe.Billing.MeterEvent,
            LatticeStripe.Billing.MeterEventAdjustment,
            LatticeStripe.Billing.MeterEventAdjustment.Cancel
          ],
          Connect: [
            LatticeStripe.Account,
            LatticeStripe.Account.BusinessProfile,
            LatticeStripe.Account.Capability,
            LatticeStripe.Account.Company,
            LatticeStripe.Account.Individual,
            LatticeStripe.Account.Requirements,
            LatticeStripe.Account.Settings,
            LatticeStripe.Account.TosAcceptance,
            LatticeStripe.AccountLink,
            LatticeStripe.LoginLink,
            LatticeStripe.BankAccount,
            LatticeStripe.Card,
            LatticeStripe.ExternalAccount,
            LatticeStripe.ExternalAccount.Unknown,
            LatticeStripe.Transfer,
            LatticeStripe.TransferReversal,
            LatticeStripe.Payout,
            LatticeStripe.Payout.TraceId,
            LatticeStripe.Balance,
            LatticeStripe.Balance.Amount,
            LatticeStripe.Balance.SourceTypes,
            LatticeStripe.BalanceTransaction,
            LatticeStripe.BalanceTransaction.FeeDetail,
            LatticeStripe.Charge
          ],
          Webhooks: [
            LatticeStripe.Webhook,
            LatticeStripe.Webhook.Plug,
            LatticeStripe.Webhook.Handler,
            LatticeStripe.Webhook.SignatureVerificationError,
            LatticeStripe.Event
          ],
          Telemetry: [
            LatticeStripe.Telemetry
          ],
          Testing: [
            LatticeStripe.Testing,
            LatticeStripe.Testing.TestClock,
            LatticeStripe.Testing.TestClock.Owner,
            LatticeStripe.Testing.TestClock.Error
          ],
          Internals: [
            LatticeStripe.Transport,
            LatticeStripe.Transport.Finch,
            LatticeStripe.Json,
            LatticeStripe.Json.Jason,
            LatticeStripe.RetryStrategy,
            LatticeStripe.RetryStrategy.Default,
            LatticeStripe.FormEncoder,
            LatticeStripe.Resource,
            LatticeStripe.Billing.Guards
          ]
        ]
      ],
      package: package(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [preferred_envs: [ci: :test]]
  end

  defp deps do
    [
      # Runtime dependencies
      {:finch, "~> 0.21"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.0"},
      {:nimble_options, "~> 1.0"},
      {:plug_crypto, "~> 2.0"},
      {:plug, "~> 1.16", optional: true},

      # Dev/test dependencies
      {:mox, "~> 1.2", only: :test},
      {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:fuse, "~> 2.5", only: [:dev, :test]},
      {:opentelemetry_exporter, "~> 1.8", only: [:dev, :test]},
      {:opentelemetry, "~> 1.5", only: [:dev, :test]},
      {:opentelemetry_api, "~> 1.4", only: [:dev, :test]}
    ]
  end

  defp package do
    [
      name: "lattice_stripe",
      description: "A production-grade, idiomatic Elixir SDK for the Stripe API",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "HexDocs" => "https://hexdocs.pm/lattice_stripe"
      },
      files: ["lib", "mix.exs", "README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      ci: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "test",
        "docs --warnings-as-errors"
      ]
    ]
  end
end
