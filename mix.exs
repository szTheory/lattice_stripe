defmodule LatticeStripe.MixProject do
  use Mix.Project

  @version "2.2.0"
  @source_url "https://github.com/szTheory/lattice_stripe"

  def project do
    [
      app: :lattice_stripe,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [summary: [threshold: 80]],
      deps: deps(),
      name: "LatticeStripe",
      description: "A production-grade, idiomatic Elixir SDK for the Stripe API",
      source_url: @source_url,
      docs: [
        main: "getting-started",
        source_url: @source_url,
        source_ref: docs_source_ref(),
        # logo: "assets/logo.png",  # Add when logo asset is created
        extras: [
          "guides/getting-started.md",
          "guides/user-flows-and-jtbd.md",
          "guides/scope.md",
          "guides/checkout-signup-and-portal.md",
          "guides/connect-platform-flow.md",
          "guides/metering-runtime-and-reconciliation.md",
          "guides/quote-to-billing-operator.md",
          "guides/client-configuration.md",
          "guides/production-checklist.md",
          "guides/event-debugging.md",
          "guides/performance.md",
          "guides/circuit-breaker.md",
          "guides/opentelemetry.md",
          "guides/payments.md",
          "guides/checkout.md",
          "guides/credit_notes.md",
          "guides/invoices.md",
          "guides/metering.md",
          "guides/tax.md",
          "guides/subscriptions.md",
          "guides/connect.md",
          "guides/connect-accounts.md",
          "guides/connect-money-movement.md",
          "guides/customer-portal.md",
          "guides/entitlements.md",
          "guides/webhooks.md",
          "guides/webhooks-thin-events.md",
          "guides/error-handling.md",
          "guides/testing.md",
          "guides/recipes.md",
          "guides/telemetry.md",
          "guides/api_stability.md",
          "guides/extending-lattice-stripe.md",
          "guides/cheatsheet.cheatmd",
          "guides/upgrading-1-1-to-1-7.md",
          "CHANGELOG.md"
        ],
        groups_for_extras: [
          {"Start Here",
           [
             "guides/getting-started.md",
             "guides/user-flows-and-jtbd.md",
             "guides/scope.md",
             "guides/recipes.md"
           ]},
          {"Flagship Recipes",
           [
             "guides/checkout-signup-and-portal.md",
             "guides/connect-platform-flow.md",
             "guides/metering-runtime-and-reconciliation.md",
             "guides/quote-to-billing-operator.md"
           ]},
          {"Canonical Guides",
           [
             "guides/payments.md",
             "guides/checkout.md",
             "guides/invoices.md",
             "guides/credit_notes.md",
             "guides/subscriptions.md",
             "guides/customer-portal.md",
             "guides/entitlements.md",
             "guides/metering.md",
             "guides/tax.md",
             "guides/connect.md",
             "guides/connect-accounts.md",
             "guides/connect-money-movement.md"
           ]},
          {"Operations & DX",
           [
             "guides/client-configuration.md",
             "guides/production-checklist.md",
             "guides/webhooks.md",
             "guides/webhooks-thin-events.md",
             "guides/event-debugging.md",
             "guides/error-handling.md",
             "guides/testing.md",
             "guides/performance.md",
             "guides/circuit-breaker.md",
             "guides/opentelemetry.md",
             "guides/telemetry.md",
             "guides/api_stability.md",
             "guides/extending-lattice-stripe.md",
             "guides/cheatsheet.cheatmd"
           ]},
          {"Upgrading", ["guides/upgrading-1-1-to-1-7.md"]},
          {"Changelog", ["CHANGELOG.md"]}
        ],
        # Regex patterns, not enumerated module lists. ExDoc performs ZERO validation of
        # groups_for_modules entries (deps/ex_doc/lib/ex_doc/config.ex:240-268): a phantom
        # atom naming a module that does not exist simply never matches, silently. That is
        # how `LatticeStripe.Testing.TestClock.Error` sat here undetected while the real
        # module, TestClockError, fell out of the sidebar. Patterns self-file new modules
        # and cannot go stale the same way.
        #
        # The ($|\.) anchor is LOAD-BEARING. It is what keeps sibling prefixes apart
        # without ordering hacks: `Billing($|\.)` deliberately does not match
        # BillingPortal.Session, and likewise Tax/TaxId, Transfer/TransferReversal,
        # Balance/BalanceTransaction, File/FileLink, Invoice/InvoiceItem,
        # Account/AccountLink, Subscription/SubscriptionItem. Each such sibling is listed
        # explicitly in its own alternation. An unanchored prefix would mis-group all eight.
        #
        # Matching is first-match-wins, so order matters. Coverage — every public module in
        # at least one group — is asserted by the totality test in docs_truth_test.exs;
        # ExDoc itself would silently dump an unmatched module into a generic "Modules"
        # bucket. Note ExDoc also auto-appends "Deprecated" and "Exceptions" groups after
        # these (config.ex:72-77).
        groups_for_modules: [
          "Client & Configuration": [
            LatticeStripe,
            LatticeStripe.Application,
            LatticeStripe.Client,
            LatticeStripe.Batch,
            LatticeStripe.Config,
            LatticeStripe.Error,
            LatticeStripe.Response,
            LatticeStripe.List,
            LatticeStripe.Request
          ],
          Payments: [
            ~r/^LatticeStripe\.(PaymentIntent|PaymentMethod|Customer|Mandate|SetupAttempt|SetupIntent|Refund|Dispute|Charge|Card)($|\.)/
          ],
          Checkout: [~r/^LatticeStripe\.Checkout($|\.)/],
          "Customer Portal": [~r/^LatticeStripe\.BillingPortal($|\.)/],
          "Billing Metering": [~r/^LatticeStripe\.Billing($|\.)/],
          Entitlements: [
            LatticeStripe.Product.Feature,
            ~r/^LatticeStripe\.Entitlements($|\.)/
          ],
          Billing: [
            ~r/^LatticeStripe\.(Invoice|InvoiceItem|CreditNote|Quote|Subscription|SubscriptionItem|SubscriptionSchedule|Coupon|Price|Product|PromotionCode)($|\.)/
          ],
          Tax: [~r/^LatticeStripe\.(Tax|TaxId)($|\.)/],
          Connect: [
            ~r/^LatticeStripe\.(Account|AccountLink|LoginLink|BankAccount|ExternalAccount|Transfer|TransferReversal|Payout|Balance|BalanceTransaction)($|\.)/
          ],
          Files: [~r/^LatticeStripe\.(File|FileLink)($|\.)/],
          Webhooks: [~r/^LatticeStripe\.(Webhook|Event|EventNotification)($|\.)/],
          Telemetry: [~r/^LatticeStripe\.Telemetry($|\.)/],
          Testing: [~r/^LatticeStripe\.(Testing|TestHelpers)($|\.)/],
          "Param Builders": [~r/^LatticeStripe\.Builders($|\.)/],
          # Renamed from "Internals": these three behaviours are what
          # guides/api_stability.md already calls designed-in extension points, so the old
          # name contradicted the guide.
          "Extension Points": [~r/^LatticeStripe\.(Transport|Json|RetryStrategy)($|\.)/],
          "Mix Tasks": [~r/^Mix\.Tasks\./]
        ]
      ],
      package: package(),
      aliases: aliases()
    ]
  end

  def application do
    [
      mod: {LatticeStripe.Application, []},
      extra_applications: [:logger]
    ]
  end

  def cli do
    [preferred_envs: [ci: :test]]
  end

  defp docs_source_ref do
    if String.ends_with?(@version, "-dev"), do: "main", else: "v#{@version}"
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
      files: ["lib", "priv/api", "mix.exs", "README.md", "CHANGELOG.md", "LICENSE"]
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
        "lattice_stripe.api_surface --check",
        "lattice_stripe.version_prose --check",
        "docs --warnings-as-errors"
      ]
    ]
  end
end
