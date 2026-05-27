defmodule LatticeStripe.DocsTruthTest do
  use ExUnit.Case, async: true

  @install_surfaces [
    "README.md",
    "guides/getting-started.md",
    "guides/cheatsheet.cheatmd",
    "guides/webhooks-thin-events.md",
    "guides/production-checklist.md",
    "guides/event-debugging.md",
    "guides/opentelemetry.md"
  ]

  @stale_install_pins ["1.1", "1.2", "1.3", "1.5"]

  defp expected_install_snippet do
    [major, minor | _] = String.split(LatticeStripe.MixProject.project()[:version], ".")
    "{:lattice_stripe, \"~> #{major}.#{minor}\"}"
  end

  defp docs_config do
    LatticeStripe.MixProject.project()[:docs]
  end

  test "exdoc keeps the primary public truth surfaces published" do
    docs = docs_config()
    extras = docs[:extras]
    groups = docs[:groups_for_extras] |> Map.new()

    assert docs[:main] == "getting-started"
    assert "guides/getting-started.md" in extras
    assert "guides/cheatsheet.cheatmd" in extras
    assert "CHANGELOG.md" in extras
    assert "guides/recipes.md" in extras
    assert "guides/checkout-signup-and-portal.md" in extras
    assert "guides/connect-platform-flow.md" in extras
    assert "guides/metering-runtime-and-reconciliation.md" in extras
    assert "guides/quote-to-billing-operator.md" in extras
    assert Map.has_key?(groups, "Start Here")
    assert Map.has_key?(groups, "Flagship Recipes")
    assert Map.has_key?(groups, "Canonical Guides")
    assert Map.has_key?(groups, "Operations & DX")
    assert "guides/getting-started.md" in groups["Start Here"]
    assert "guides/user-flows-and-jtbd.md" in groups["Start Here"]
    assert "guides/recipes.md" in groups["Start Here"]
    assert "guides/checkout-signup-and-portal.md" in groups["Flagship Recipes"]
    assert "guides/connect-platform-flow.md" in groups["Flagship Recipes"]
    assert "guides/metering-runtime-and-reconciliation.md" in groups["Flagship Recipes"]
    assert "guides/quote-to-billing-operator.md" in groups["Flagship Recipes"]
    assert "guides/subscriptions.md" in groups["Canonical Guides"]
    assert "guides/customer-portal.md" in groups["Canonical Guides"]
    assert "guides/metering.md" in groups["Canonical Guides"]
    assert "guides/tax.md" in extras
    assert "guides/tax.md" in groups["Canonical Guides"]
    assert "guides/connect.md" in groups["Canonical Guides"]
    assert "guides/webhooks.md" in groups["Operations & DX"]
    # D-03 sub-decision 3C — new v1.5 trust rail extension to Operations & DX
    assert "guides/webhooks-thin-events.md" in extras
    assert "guides/webhooks-thin-events.md" in groups["Operations & DX"]
    assert "guides/production-checklist.md" in extras
    assert "guides/production-checklist.md" in groups["Operations & DX"]
    assert "guides/event-debugging.md" in extras
    assert "guides/event-debugging.md" in groups["Operations & DX"]
    assert "guides/testing.md" in groups["Operations & DX"]
    assert "guides/error-handling.md" in groups["Operations & DX"]
  end

  test "public install line matches mix.exs and all install surfaces" do
    snippet = expected_install_snippet()

    for path <- @install_surfaces do
      assert File.read!(path) =~ snippet, "expected #{snippet} in #{path}"
    end
  end

  test "no stale lattice_stripe install pins on public surfaces" do
    for path <- @install_surfaces, pin <- @stale_install_pins do
      refute File.read!(path) =~ "{:lattice_stripe, \"~> #{pin}\"}",
             "stale pin ~> #{pin} in #{path}"
    end
  end

  test "readme routes evaluators into the guide ladder" do
    readme = File.read!("README.md")

    assert readme =~ "guides/user-flows-and-jtbd.md"
    assert readme =~ "guides/subscriptions.md"
    assert readme =~ "guides/customer-portal.md"
    assert readme =~ "guides/metering.md"
    assert readme =~ "guides/tax.md"
    assert readme =~ "guides/connect.md"
    assert readme =~ "guides/webhooks.md"
    assert readme =~ "guides/testing.md"
    assert readme =~ "guides/error-handling.md"
    assert readme =~ "https://hexdocs.pm/lattice_stripe/recipes.html"
    refute readme =~ "What's new in v1.1"
  end

  test "readme release block and hexdocs clusters reflect v1.7 surface" do
    readme = File.read!("README.md")

    assert readme =~ "1.7"
    assert readme =~ "hexdocs.pm/lattice_stripe/tax.html"
    assert readme =~ "LatticeStripe.Charge.html"
    assert readme =~ "webhooks-thin-events.md"
    assert readme =~ "production-checklist.md"
    assert readme =~ "event-debugging.md"
    refute readme =~ "1.3.x` line is the current published"
  end

  test "getting started branches from first success into high-leverage guides" do
    getting_started = File.read!("guides/getting-started.md")

    refute getting_started =~ "{:lattice_stripe, \"~> 1.2\"}"
    assert getting_started =~ "user-flows-and-jtbd.md"
    assert getting_started =~ "subscriptions.md"
    assert getting_started =~ "customer-portal.md"
    assert getting_started =~ "metering.md"
    assert getting_started =~ "connect.md"
    assert getting_started =~ "webhooks.md"
    assert getting_started =~ "testing.md"
    assert getting_started =~ "error-handling.md"
  end

  test "jtbd and recipes stay task-first routing layers into canonical guides" do
    jtbd = File.read!("guides/user-flows-and-jtbd.md")
    recipes = File.read!("guides/recipes.md")

    assert jtbd =~ "Use this guide as a routing layer"
    assert jtbd =~ "subscriptions.md"
    assert jtbd =~ "customer-portal.md"
    assert jtbd =~ "checkout-signup-and-portal.md"
    assert jtbd =~ "metering.md"
    assert jtbd =~ "metering-runtime-and-reconciliation.md"
    assert jtbd =~ "connect-platform-flow.md"
    assert jtbd =~ "connect.md"
    assert jtbd =~ "quote-to-billing-operator.md"
    assert jtbd =~ "webhooks.md"
    assert jtbd =~ "testing.md"
    assert jtbd =~ "tax.md"

    assert recipes =~ "canonical"
    assert recipes =~ "checkout-signup-and-portal.md"
    assert recipes =~ "connect-platform-flow.md"
    assert recipes =~ "subscriptions.md"
    assert recipes =~ "customer-portal.md"
    assert recipes =~ "metering-runtime-and-reconciliation.md"
    assert recipes =~ "metering.md"
    assert recipes =~ "quote-to-billing-operator.md"
    assert recipes =~ "webhooks.md"
    assert recipes =~ "testing.md"
    assert recipes =~ "error-handling.md"
    assert recipes =~ "tax.md"
  end

  test "tax guide locks ExDoc placement, content anchors, cross-links, and moduledocs" do
    root = Path.expand("../..", __DIR__)
    tax_guide = File.read!("guides/tax.md")
    docs = docs_config()
    groups = docs[:groups_for_extras] |> Map.new()

    assert "guides/tax.md" in docs[:extras]
    assert "guides/tax.md" in groups["Canonical Guides"]

    assert tax_guide =~ "Calculation.create"
    assert tax_guide =~ "create_from_calculation"
    assert tax_guide =~ "create_reversal"
    assert tax_guide =~ "Invoice.AutomaticTax"
    assert tax_guide =~ "out of SDK scope"
    assert tax_guide =~ "90"
    assert tax_guide =~ "expires_at" or tax_guide =~ "days"
    assert tax_guide =~ "reference"
    assert tax_guide =~ "globally" or tax_guide =~ "unique"
    assert tax_guide =~ "country_options"
    assert tax_guide =~ "Tax.Settings"
    assert tax_guide =~ "Tax.Registration"

    assert tax_guide =~ "testing.md"
    assert tax_guide =~ "error-handling.md"
    assert tax_guide =~ "payments.md"

    jtbd = File.read!("guides/user-flows-and-jtbd.md")
    recipes = File.read!("guides/recipes.md")
    payments = File.read!("guides/payments.md")
    assert jtbd =~ "tax.md"
    assert recipes =~ "tax.md"
    assert payments =~ "tax.md"

    calc = File.read!(Path.join(root, "lib/lattice_stripe/tax/calculation.ex"))
    txn = File.read!(Path.join(root, "lib/lattice_stripe/tax/transaction.ex"))
    settings = File.read!(Path.join(root, "lib/lattice_stripe/tax/settings.ex"))
    registration = File.read!(Path.join(root, "lib/lattice_stripe/tax/registration.ex"))
    tax_id = File.read!(Path.join(root, "lib/lattice_stripe/tax_id.ex"))

    for source <- [calc, txn, settings, registration, tax_id] do
      assert source =~ "guides/tax.md"
    end

    assert calc =~ "90"
    assert calc =~ "days" or calc =~ "expires_at"
    assert calc =~ "Invoice.AutomaticTax"
    assert calc =~ "out of SDK scope"
    assert calc =~ "LatticeStripe.Tax.Transaction"

    assert txn =~ "reference"
    assert txn =~ "globally" or txn =~ "unique"
    assert txn =~ "create_from_calculation"
    assert txn =~ "create_reversal"
    assert txn =~ "Invoice.AutomaticTax"
    assert txn =~ "LatticeStripe.Tax.Calculation"

    assert settings =~ "singleton"
    assert settings =~ "tax_code"
    assert settings =~ "LatticeStripe.Tax.Calculation"
    assert settings =~ "Invoice.AutomaticTax"
    assert settings =~ "stripe_account"

    assert registration =~ "tax authorities"
    assert registration =~ "country_options"
    assert registration =~ "LatticeStripe.Tax.Settings"
    assert registration =~ "LatticeStripe.Tax.Calculation"
    assert registration =~ "Invoice.AutomaticTax"
    assert registration =~ "out of SDK scope"
    assert registration =~ "stream!"

    assert tax_id =~ "/v1/tax_ids"
    assert tax_id =~ "customers"
    assert tax_id =~ "Invoice.AutomaticTax"
  end

  test "Charge @moduledoc reflects expanded PI-first surface" do
    source = File.read!("lib/lattice_stripe/charge.ex")

    # Positive: expanded surface + PI-first + Connect anchor
    assert source =~ "PaymentIntent"
    assert source =~ "list/3"
    assert source =~ "search/3"
    assert source =~ "update/4"
    assert source =~ "capture/4"
    assert source =~ "application_fee"

    # Negative: stale retrieve-only language must not return
    refute source =~ "retrieve-only"
    refute source =~ "Only three public functions"
    refute source =~ "never directly manipulated"
  end

  test "flagship guides are published and cross-linked through the docs graph" do
    checkout_recipe = File.read!("guides/checkout-signup-and-portal.md")
    connect_recipe = File.read!("guides/connect-platform-flow.md")
    metering_recipe = File.read!("guides/metering-runtime-and-reconciliation.md")
    quote_recipe = File.read!("guides/quote-to-billing-operator.md")
    checkout = File.read!("guides/checkout.md")
    connect = File.read!("guides/connect.md")
    connect_accounts = File.read!("guides/connect-accounts.md")
    connect_money = File.read!("guides/connect-money-movement.md")
    portal = File.read!("guides/customer-portal.md")
    metering = File.read!("guides/metering.md")
    webhooks = File.read!("guides/webhooks.md")
    testing = File.read!("guides/testing.md")
    errors = File.read!("guides/error-handling.md")

    assert checkout_recipe =~ "webhooks"
    assert checkout_recipe =~ "payment_method_update"
    assert checkout_recipe =~ "subscription_cancel"
    assert checkout_recipe =~ "session.url"
    assert checkout_recipe =~ "Read next"

    assert connect_recipe =~ "Express"
    assert connect_recipe =~ "AccountLink"
    assert connect_recipe =~ "destination charges"
    assert connect_recipe =~ "application_fee_amount"
    assert connect_recipe =~ "transfer_group"
    assert connect_recipe =~ "Transfer"
    assert connect_recipe =~ "Payout"
    assert connect_recipe =~ "webhook"
    assert connect_recipe =~ "Read next"

    assert metering_recipe =~ "identifier"
    assert metering_recipe =~ "idempotency_key"
    assert metering_recipe =~ "MeterEventAdjustment"
    assert metering_recipe =~ "accepted for processing"
    assert metering_recipe =~ "Read next"

    assert quote_recipe =~ "Quote.create"
    assert quote_recipe =~ "Quote.finalize"
    assert quote_recipe =~ "Quote.accept"
    assert quote_recipe =~ "invoice"
    assert quote_recipe =~ "subscription_schedule"
    assert quote_recipe =~ "accepted the quote transition"
    assert quote_recipe =~ "webhooks"
    assert quote_recipe =~ "Read next"

    assert checkout =~ "checkout-signup-and-portal.md"
    assert connect =~ "connect-platform-flow.md"
    assert connect_accounts =~ "connect-platform-flow.md"
    assert connect_money =~ "connect-platform-flow.md"
    assert portal =~ "checkout-signup-and-portal.md"
    assert metering =~ "metering-runtime-and-reconciliation.md"
    assert webhooks =~ "checkout-signup-and-portal.md"
    assert webhooks =~ "connect-platform-flow.md"
    assert webhooks =~ "metering-runtime-and-reconciliation.md"
    assert webhooks =~ "quote-to-billing-operator.md"
    assert testing =~ "metering-runtime-and-reconciliation.md"
    assert errors =~ "metering-runtime-and-reconciliation.md"
  end

  test "changelog records the shipped 1.7 release truth" do
    changelog = File.read!("CHANGELOG.md")

    assert changelog =~ "## [1.7.0]"
    assert changelog =~ "included in 1.7.0"
    assert changelog =~ "last version published"
  end

  test "CHANGELOG.md documents WEBFIX-01 reconciliation under v1.5" do
    # WEBFIX-01 / Phase 47 D-03 regression-prevention contract: a future
    # "fix it to be stricter" PR that silently drops the CHANGELOG entry
    # MUST fail this grep test. The inline source comment + this test +
    # the function-boundary test + the Plug-boundary test together
    # triangulate the decision so the drift cannot silently come back.
    changelog = File.read!("CHANGELOG.md")

    assert changelog =~ "WEBFIX-01"
    assert changelog =~ ~r/##\s*\[?1\.5/
  end

  test "webhooks-thin-events guide locks the thin-event adopter contract" do
    guide = File.read!("guides/webhooks-thin-events.md")

    # Function names — the helper surface the guide teaches
    assert guide =~ "parse_event_notification"
    assert guide =~ "fetch_event"
    assert guide =~ "fetch_related_object"

    # Verify-error atoms — locks the verification-vs-payload-shape failure boundary
    assert guide =~ ":no_matching_signature"
    assert guide =~ ":timestamp_expired"
    # Typed-error footguns specific to thin-event helpers
    assert guide =~ ":no_related_object"
    assert guide =~ ":unknown_object_type"

    # Rate-limit phrasing — both substrings required (REQUIREMENTS.md GUIDE-03)
    assert guide =~ "100 req/s"
    assert guide =~ "90/s"

    # Idempotency anchor (GUIDE-03)
    assert guide =~ "event.id"

    # Connect routing anchor (GUIDE-03)
    assert guide =~ "event.context"

    # Canonical truth anchor (Phase 44 D-14)
    assert guide =~ "Webhooks confirm"

    # Canonical surface name
    assert guide =~ "/v2/events"

    # Verification-vs-payload-shape failure boundary phrasing (GUIDE-03)
    assert guide =~ "verification"
    assert guide =~ "payload shape"
  end

  test "webhooks-thin-events guide is cross-linked from README/JTBD/webhooks.md" do
    # D-03 sub-decision 3D cross-link graph: the new v1.5 guide must be
    # reachable from README hardening-ops route, JTBD Start Here Runtime
    # route + Job 7 Read next, AND linked back from the parent webhooks.md
    # guide. Forward edges from the new guide (webhooks.md / testing.md /
    # error-handling.md) are locked here in lockstep. Drift in any of these
    # surfaces fails CI and is the canonical signal that a discovery wire
    # snapped silently.

    # Forward links FROM the new guide
    thin = File.read!("guides/webhooks-thin-events.md")
    assert thin =~ "webhooks.md"
    assert thin =~ "testing.md"
    assert thin =~ "error-handling.md"

    # Reverse link from parent webhook guide
    webhooks = File.read!("guides/webhooks.md")
    assert webhooks =~ "webhooks-thin-events.md"
    assert webhooks =~ "thin event"  # locks the new "Thin events (/v2/events)" closing section in webhooks.md

    # README discovery route
    readme = File.read!("README.md")
    assert readme =~ "webhooks-thin-events.md"

    # JTBD discovery ladder (Start Here Runtime route + Job 7 Read next)
    jtbd = File.read!("guides/user-flows-and-jtbd.md")
    assert jtbd =~ "webhooks-thin-events.md"
  end

  test "production-checklist guide locks the operator pre-launch contract" do
    guide = File.read!("guides/production-checklist.md")

    assert guide =~ "Production Stripe integrations fail at boundaries"
    assert guide =~ "Client.new!"
    assert guide =~ "Webhook.Plug"
    assert guide =~ "request_id"
    assert guide =~ "Your app starts work. Webhooks confirm reality."
    assert guide =~ "idempotency" or guide =~ "Idempotency"
    assert guide =~ "Finch" or guide =~ "supervision"
    assert guide =~ "telemetry" or guide =~ "Telemetry"
    assert guide =~ "result record"
    assert guide =~ "PaymentIntent"
    assert guide =~ "client-configuration.md"
    assert guide =~ "webhooks.md"
    assert guide =~ "event-debugging.md"
  end

  test "event-debugging guide locks the webhook diagnostic contract" do
    guide = File.read!("guides/event-debugging.md")

    assert guide =~ "Debug from the delivery boundary inward"
    assert guide =~ ":no_matching_signature"
    assert guide =~ ":timestamp_expired"
    assert guide =~ "request_id"
    assert guide =~ "event.id"
    assert guide =~ "fetch_event" or guide =~ "fetch_event/"
    assert guide =~ "at-least-once" or guide =~ "at least once"
    assert guide =~ "result record"
    assert guide =~ "webhooks-thin-events.md"
    assert guide =~ "webhooks.md"
  end

  test "operator guides are cross-linked from README/JTBD/sibling guides" do
    checklist = File.read!("guides/production-checklist.md")
    debugging = File.read!("guides/event-debugging.md")
    readme = File.read!("README.md")
    jtbd = File.read!("guides/user-flows-and-jtbd.md")
    webhooks = File.read!("guides/webhooks.md")
    errors = File.read!("guides/error-handling.md")
    testing = File.read!("guides/testing.md")

    assert checklist =~ "event-debugging.md"
    assert debugging =~ "production-checklist.md"
    assert readme =~ "production-checklist.md"
    assert readme =~ "event-debugging.md"
    assert jtbd =~ "production-checklist.md"
    assert jtbd =~ "event-debugging.md"
    assert webhooks =~ "event-debugging.md"
    assert errors =~ "production-checklist.md"
    assert errors =~ "event-debugging.md"
    assert testing =~ "event-debugging.md"
  end

  test "Webhook.Plug @moduledoc documents tolerance: 0 testing-only semantics" do
    # WR-04 closure (Phase 47 deferred → Phase 48 D-03 3E): the Plug
    # @moduledoc Configuration Options section must surface the tolerance: 0
    # testing-only escape hatch. HexDocs renders this @moduledoc as the
    # landing page for the Plug; without this lock, drift here would silently
    # stop showing the contract on the page adopters actually read first.
    # Four-surface triangulation: inline check_tolerance/2 comment + Plug
    # schema doc: string + CHANGELOG WEBFIX-01 entry + this @moduledoc — all
    # four must be silenced simultaneously for the contract to silently regress.
    source = File.read!("lib/lattice_stripe/webhook/plug.ex")
    assert source =~ ~r/@moduledoc.*tolerance.*0.*testing only/s
  end
end
