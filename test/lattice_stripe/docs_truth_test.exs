defmodule LatticeStripe.DocsTruthTest do
  use ExUnit.Case, async: true

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
    assert "guides/connect.md" in groups["Canonical Guides"]
    assert "guides/webhooks.md" in groups["Operations & DX"]
    assert "guides/testing.md" in groups["Operations & DX"]
    assert "guides/error-handling.md" in groups["Operations & DX"]
  end

  test "readme routes evaluators into the guide ladder and published 1.3 line" do
    readme = File.read!("README.md")

    assert readme =~ "guides/user-flows-and-jtbd.md"
    assert readme =~ "guides/subscriptions.md"
    assert readme =~ "guides/customer-portal.md"
    assert readme =~ "guides/metering.md"
    assert readme =~ "guides/connect.md"
    assert readme =~ "guides/webhooks.md"
    assert readme =~ "guides/testing.md"
    assert readme =~ "guides/error-handling.md"
    assert readme =~ "https://hexdocs.pm/lattice_stripe/recipes.html"
    assert readme =~ "{:lattice_stripe, \"~> 1.3\"}"
    refute readme =~ "What's new in v1.1"
  end

  test "getting started branches from first success into high-leverage guides" do
    getting_started = File.read!("guides/getting-started.md")

    assert getting_started =~ "{:lattice_stripe, \"~> 1.3\"}"
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

  test "cheatsheet keeps the published 1.3 install truth" do
    cheatsheet = File.read!("guides/cheatsheet.cheatmd")

    assert cheatsheet =~ "{:lattice_stripe, \"~> 1.3\"}"
  end

  test "changelog records the shipped 1.3 release truth" do
    changelog = File.read!("CHANGELOG.md")

    assert changelog =~ "## [1.3.0]"
    assert changelog =~ "shipped `1.3.x` surface"
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
end
