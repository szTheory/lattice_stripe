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

  @stale_release_status_claims [
    "1.3.x` line is the current published",
    "1.3.x line is the current published"
  ]

  @stale_payments_only_patterns [
    "\"succeeded\" ->",
    "\"requires_action\" ->"
  ]

  # Payment-flow cluster: fixing one canonical guide must audit siblings (payments ↔ checkout).
  @payment_flow_guides ["guides/payments.md", "guides/checkout.md"]

  @shared_payment_flow_stale_patterns [
    ~s/intent.status == "succeeded"/,
    ~s/payment_status == "paid"/,
    "Use `search/2`",
    "PaymentIntent.search(client, %{"
  ]

  # Portal-flow cluster: portal session flows ↔ subscription lifecycle/proration.
  @portal_flow_guides ["guides/customer-portal.md", "guides/subscriptions.md"]

  @shared_portal_flow_stale_patterns [
    "customer-portal.html",
    "subscriptions.html"
  ]

  # Connect cluster: conceptual overview ↔ account lifecycle ↔ money movement.
  @connect_flow_guides [
    "guides/connect.md",
    "guides/connect-accounts.md",
    "guides/connect-money-movement.md"
  ]

  @shared_connect_stale_patterns [
    "connect.html",
    "connect-accounts.html",
    "connect-money-movement.html"
  ]

  # Webhook cluster: snapshot webhooks ↔ thin events.
  @webhook_flow_guides ["guides/webhooks.md", "guides/webhooks-thin-events.md"]

  @shared_webhook_stale_patterns [
    "webhooks.html",
    "webhooks-thin-events.html"
  ]

  @stale_payments_api_patterns @stale_payments_only_patterns ++
                                 @shared_payment_flow_stale_patterns

  @stale_checkout_api_patterns @shared_payment_flow_stale_patterns

  @stale_readme_error_atoms [
    ":auth_error",
    ":server_error"
  ]

  defp expected_install_snippet do
    [major, minor | _] = String.split(LatticeStripe.MixProject.project()[:version], ".")
    "{:lattice_stripe, \"~> #{major}.#{minor}\"}"
  end

  defp current_release_line do
    [major, minor | _] = String.split(LatticeStripe.MixProject.project()[:version], ".")
    "#{major}.#{minor}.x"
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
    assert "guides/scope.md" in extras
    assert "guides/scope.md" in groups["Start Here"]
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

  describe "guides/getting-started.md" do
    test "release-status prose matches current Hex surface" do
      getting_started = File.read!("guides/getting-started.md")
      release_line = current_release_line()

      assert getting_started =~ release_line,
             "release-status prose drifted from mix.exs version — expected #{release_line}"

      assert getting_started =~ "current published" or
               getting_started =~ "published line" or
               getting_started =~ "published Hex" or
               getting_started =~ "published on Hex",
             "release-status prose missing published-surface semantic anchor"

      for claim <- @stale_release_status_claims do
        refute getting_started =~ claim,
               "stale release claim #{inspect(claim)} in getting-started"
      end

      refute getting_started =~ "unreleased work from `main`",
             "getting-started still steers adopters to git dependency from main"
    end

    test "branches from first success into high-leverage guides" do
      getting_started = File.read!("guides/getting-started.md")

      assert getting_started =~ "user-flows-and-jtbd.md"
      assert getting_started =~ "subscriptions.md"
      assert getting_started =~ "customer-portal.md"
      assert getting_started =~ "metering.md"
      assert getting_started =~ "connect.md"
      assert getting_started =~ "webhooks.md"
      assert getting_started =~ "testing.md"
      assert getting_started =~ "error-handling.md"
    end
  end

  describe "guides/payments.md" do
    test "canonical API examples use atom statuses and search/3" do
      payments = File.read!("guides/payments.md")

      assert payments =~ ":succeeded ->"
      assert payments =~ ":requires_action ->"
      assert payments =~ "intent.status == :succeeded"
      assert payments =~ "search/3"
      assert payments =~ "PaymentIntent.search(client, \""

      for pattern <- @stale_payments_api_patterns do
        refute payments =~ pattern,
               "stale API pattern #{inspect(pattern)} in payments.md"
      end
    end

    test "search example closes the Elixir fence before the Search API note" do
      payments = File.read!("guides/payments.md")

      assert payments =~ "results = resp.data.data\n```\n\n> **Note:** Stripe's Search API"
      refute payments =~ "results = resp.data.data\n\n> **Note:**"
    end

    test "routes Charge reconciliation after PaymentIntent flows" do
      payments = File.read!("guides/payments.md")

      assert payments =~ "## Charge reconciliation"
      assert payments =~ "LatticeStripe.Charge.list"
      assert payments =~ "LatticeStripe.Charge.search"
      assert payments =~ "LatticeStripe.Charge.update"
      assert payments =~ "LatticeStripe.Charge.capture"
      assert payments =~ "list/3"
      assert payments =~ "search/3"

      {creating_idx, _} = :binary.match(payments, "## Creating a PaymentIntent")
      {charge_idx, _} = :binary.match(payments, "## Charge reconciliation")
      assert creating_idx < charge_idx
    end
  end

  describe "guides/customer-portal.md" do
    test "documents programmatic BillingPortal.Configuration" do
      portal = File.read!("guides/customer-portal.md")

      assert portal =~ "BillingPortal.Configuration"
      assert portal =~ "create/3"
      refute portal =~ "managed via the Stripe Dashboard in v1.1"
      refute portal =~ "is in the Stripe Dashboard, not per-session params"
    end

    test "portal configurations section covers programmatic CRUD lifecycle" do
      portal = File.read!("guides/customer-portal.md")

      assert portal =~ "## Portal configurations (programmatic CRUD)"
      assert portal =~ "Configuration.create"
      assert portal =~ "Configuration.update"
      assert portal =~ "Configuration.retrieve"
      assert portal =~ "Configuration.list"
      assert portal =~ ~s/"active" => false/
      assert portal =~ "is_default"
      assert portal =~ "hexdocs.pm/lattice_stripe/LatticeStripe.BillingPortal.Configuration.html"
    end

    test "cross-links subscription lifecycle and proration with .md siblings" do
      portal = File.read!("guides/customer-portal.md")

      assert portal =~ "subscriptions.md#lifecycle-operations"
      assert portal =~ "subscriptions.md#proration"
      refute portal =~ "subscriptions.html#"
    end
  end

  describe "guides/checkout.md" do
    test "canonical API examples use atom statuses" do
      checkout = File.read!("guides/checkout.md")

      assert checkout =~ "Status values:"
      assert checkout =~ "%LatticeStripe.Checkout.Session{}"
      assert checkout =~ "payment_status == :paid"
      assert checkout =~ ":paid"

      for pattern <- @stale_checkout_api_patterns do
        refute checkout =~ pattern,
               "stale API pattern #{inspect(pattern)} in checkout.md"
      end
    end
  end

  describe "README.md" do
    test "error taxonomy matches Error module atoms" do
      readme = File.read!("README.md")

      assert readme =~ ":authentication_error"
      assert readme =~ ":api_error"
      assert readme =~ ":card_error"

      for atom <- @stale_readme_error_atoms do
        refute readme =~ atom,
               "stale error atom #{inspect(atom)} in README.md"
      end
    end

    test "guide links use HexDocs URLs not relative guides/*.md paths" do
      readme = File.read!("README.md")

      refute readme =~ ~r/\]\(guides\/[^)]+\.md/,
             "README guide links must use HexDocs URLs for hex.pm portability"
    end
  end

  test "operator guides route Charge update/capture to payments reconciliation" do
    checklist = File.read!("guides/production-checklist.md")
    debugging = File.read!("guides/event-debugging.md")

    assert checklist =~ "Charge.update/4"
    assert checklist =~ "Charge.capture/4"
    assert checklist =~ "payments.md#charge-reconciliation"

    assert debugging =~ "Charge.update/4"
    assert debugging =~ "Charge.capture/4"
    assert debugging =~ "payments.md#charge-reconciliation"
  end

  test "readme routes evaluators into the guide ladder" do
    readme = File.read!("README.md")

    assert readme =~ "hexdocs.pm/lattice_stripe/user-flows-and-jtbd.html"
    assert readme =~ "hexdocs.pm/lattice_stripe/subscriptions.html"
    assert readme =~ "hexdocs.pm/lattice_stripe/customer-portal.html"
    assert readme =~ "hexdocs.pm/lattice_stripe/metering.html"
    assert readme =~ "hexdocs.pm/lattice_stripe/tax.html"
    assert readme =~ "hexdocs.pm/lattice_stripe/connect.html"
    assert readme =~ "hexdocs.pm/lattice_stripe/webhooks.html"
    assert readme =~ "hexdocs.pm/lattice_stripe/testing.html"
    assert readme =~ "hexdocs.pm/lattice_stripe/error-handling.html"
    assert readme =~ "https://hexdocs.pm/lattice_stripe/recipes.html"
    refute readme =~ "What's new in v1.1"
  end

  describe "v1.x stop signal and scope boundaries" do
    test "readme publishes stop signal and deferred scope anchors" do
      readme = File.read!("README.md")

      assert readme =~ "feature-complete for its intended v1.x scope"
      assert readme =~ "maintenance mode" or readme =~ "maintenance and adoption-driven"
      assert readme =~ "hexdocs.pm/lattice_stripe/user-flows-and-jtbd.html"
      assert readme =~ "hexdocs.pm/lattice_stripe/api_stability.html"
      assert readme =~ "## v1.x scope"
      assert readme =~ "Identity"
      assert readme =~ "Reporting"

      refute readme =~ ~r/complete Stripe SDK/i
      refute readme =~ ~r/all endpoints/i
    end

    test "guides/scope.md is the canonical deferred-scope contract" do
      scope = File.read!("guides/scope.md")

      assert scope =~ "Identity"
      assert scope =~ "Reporting" or scope =~ "Sigma"
      assert scope =~ "adopter pull" or scope =~ "maintenance mode"
      assert scope =~ "Client.request"
      assert scope =~ "entitled?"
      assert scope =~ "entitlements.md"
    end
  end

  test "readme release block and hexdocs clusters reflect v1.7 surface" do
    readme = File.read!("README.md")

    assert readme =~ current_release_line()
    assert readme =~ "hexdocs.pm/lattice_stripe/tax.html"
    assert readme =~ "LatticeStripe.Charge.html"
    assert readme =~ "hexdocs.pm/lattice_stripe/webhooks-thin-events.html"
    assert readme =~ "hexdocs.pm/lattice_stripe/production-checklist.html"
    assert readme =~ "hexdocs.pm/lattice_stripe/event-debugging.html"

    for claim <- @stale_release_status_claims do
      refute readme =~ claim, "stale release claim #{inspect(claim)} in README"
    end
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
    assert jtbd =~ "[Recipes](recipes.md)"
    assert jtbd =~ "Adopter-owned depth"
    assert jtbd =~ "mandate-and-setupattempt-diagnostics"
    refute jtbd =~ "complete end-to-end recipes that stitch"
    refute jtbd =~ "Still missing"

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

  describe "guides/subscriptions.md" do
    test "documents Product and Price catalog strategy" do
      guide = File.read!("guides/subscriptions.md")

      assert guide =~ "## Product and Price catalog strategy"
      assert guide =~ "LatticeStripe.Product.create"
      assert guide =~ "LatticeStripe.Price.create"
      assert guide =~ "lookup_key"
      assert guide =~ "catalog setup"
    end

    test "cross-links customer portal cancel and update flows with .md siblings" do
      guide = File.read!("guides/subscriptions.md")

      assert guide =~ "customer-portal.md#canceling-a-subscription"
      assert guide =~ "customer-portal.md#updating-a-subscription"
      refute guide =~ "customer-portal.html#"
    end
  end

  describe "guides/recipes.md" do
    test "mandate recipe documents SetupAttempt list and Mandate retrieve diagnostics" do
      recipes = File.read!("guides/recipes.md")

      assert recipes =~ "## Mandate and SetupAttempt diagnostics"
      assert recipes =~ "LatticeStripe.SetupAttempt.list"
      assert recipes =~ "setup_intent"
      assert recipes =~ "LatticeStripe.Mandate.retrieve"
      assert recipes =~ "setup_error"
    end

    test "dispute recipe documents File upload through evidence submit spine" do
      recipes = File.read!("guides/recipes.md")

      assert recipes =~ "LatticeStripe.File.create"
      assert recipes =~ "dispute_evidence"
      assert recipes =~ "LatticeStripe.Dispute.update_evidence"
      assert recipes =~ "LatticeStripe.Dispute.submit_evidence"
      assert recipes =~ "uncategorized_file"
      assert recipes =~ "charge.dispute.created"
      assert recipes =~ "submit: false"
      assert recipes =~ "irreversible"
    end
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

  test "entitlements guide locks ExDoc placement, content anchors, cross-links, and moduledocs" do
    root = Path.expand("../..", __DIR__)
    guide = File.read!("guides/entitlements.md")
    docs = docs_config()
    groups = docs[:groups_for_extras] |> Map.new()

    # Both halves of the registration: a guide in a group but absent from extras:
    # is silently dropped from the build, so neither assertion is redundant.
    assert "guides/entitlements.md" in docs[:extras]
    assert "guides/entitlements.md" in groups["Canonical Guides"]

    entitlements_group = docs[:groups_for_modules][:Entitlements]
    assert LatticeStripe.Entitlements.ActiveEntitlement in entitlements_group
    assert LatticeStripe.Entitlements.ActiveEntitlementSummary in entitlements_group
    assert LatticeStripe.Entitlements.Feature in entitlements_group

    assert guide =~ "Scope boundary"
    assert guide =~ "entitled?"
    assert guide =~ "fail closed"
    assert guide =~ "stream_entitlements!"
    assert guide =~ "archived"
    assert guide =~ "lookup_key"

    assert guide =~ "error-handling.md"
    assert guide =~ "metering.md" or guide =~ "customer-portal.md"

    # An adopter who reads "shipped in vX" searches hex.pm for exactly that
    # string. GSD milestone labels are two-part (v1.10) and are not Hex
    # releases; published versions are three-part semver. The label leaked into
    # this line once already, so lock the shape rather than the literal — the
    # version legitimately changes, the number of parts does not.
    [[_, claimed_version]] = Regex.scan(~r/shipped in v(\d+(?:\.\d+)*)/, guide)
    assert claimed_version =~ ~r/^\d+\.\d+\.\d+$/

    entitlements_lib = Path.join(root, "lib/lattice_stripe/entitlements")
    active_entitlement = File.read!(Path.join(entitlements_lib, "active_entitlement.ex"))
    summary = File.read!(Path.join(entitlements_lib, "active_entitlement_summary.ex"))
    feature = File.read!(Path.join(entitlements_lib, "feature.ex"))

    for source <- [active_entitlement, summary, feature] do
      assert source =~ "guides/entitlements.md"
    end

    # The gate fence. `entitled?` is asserted PRESENT here and never denied: the
    # helper's absence is already proven structurally by the export locks in
    # active_entitlement_test.exs, and the name has to stay greppable in prose so a
    # contributor who searches for it lands on the reason it is absent.
    assert active_entitlement =~ "gate"
    assert active_entitlement =~ "fail closed"
    assert active_entitlement =~ "stream!/3"
    assert active_entitlement =~ "entitled?"

    # The summary object carries no id property, so the struct has no :id field.
    assert summary =~ "no top-level"

    # The archiving vocabulary split: field `active`, filter `archived`, sense inverted.
    assert feature =~ "## Archiving"
    assert feature =~ "immutable"
  end

  test "the promoted entitlements fixture keeps its ExDoc placement and guide mention" do
    docs = docs_config()

    # A module absent from its group is silently dropped from the published docs, so an
    # adopter reading HexDocs would never learn the fixture exists — the promotion out of
    # test/support/ would buy nothing. Structural, not decorative.
    testing_group = docs[:groups_for_modules][:Testing]
    assert LatticeStripe.Testing.Fixtures.Entitlements in testing_group

    guide = File.read!("guides/testing.md")
    assert guide =~ "LatticeStripe.Testing.Fixtures.Entitlements"
    assert guide =~ "active_entitlement/1"
  end

  test "the promoted meter fixtures keep their ExDoc placement and guide mention" do
    docs = docs_config()

    # A module absent from its group is silently dropped from the published docs, so an
    # adopter reading HexDocs would never learn the fixture exists — the promotion out of
    # test/support/ would buy nothing. Structural, not decorative.
    testing_group = docs[:groups_for_modules][:Testing]
    assert LatticeStripe.Testing.Fixtures.MeterEvent in testing_group
    assert LatticeStripe.Testing.Fixtures.MeterEventSummary in testing_group
    assert LatticeStripe.Testing.Fixtures.MeterErrorReport in testing_group

    guide = File.read!("guides/testing.md")
    assert guide =~ "LatticeStripe.Testing.Fixtures.MeterEvent"
    assert guide =~ "LatticeStripe.Testing.Fixtures.MeterEventSummary"
    assert guide =~ "LatticeStripe.Testing.Fixtures.MeterErrorReport"
    assert guide =~ "meter_event/1"
  end

  test "metering guide and the Phase 64 metering modules keep their ExDoc placement" do
    docs = docs_config()
    groups = docs[:groups_for_extras] |> Map.new()

    # Both halves of the registration: a guide listed in a group but absent from
    # extras is silently dropped from the build, so neither assertion is
    # redundant. The guide gained major new sections this phase and a silent drop
    # would take them with it.
    assert "guides/metering.md" in docs[:extras]
    assert "guides/metering.md" in groups["Canonical Guides"]

    # A module absent from its group is silently dropped from the published docs,
    # so an adopter reading HexDocs would never learn these exist. Structural
    # assertion only — this is the sole docs-truth addition this phase, and
    # deliberately not a prose grep.
    metering_group = docs[:groups_for_modules][:"Billing Metering"]

    assert LatticeStripe.Billing.MeterEventSummary in metering_group
    assert LatticeStripe.Billing.MeterErrorReport in metering_group
    assert LatticeStripe.Billing.MeterErrorReport.Reason in metering_group
    assert LatticeStripe.Billing.MeterErrorReport.ErrorType in metering_group
    assert LatticeStripe.Billing.MeterErrorReport.SampleError in metering_group
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
    assert changelog =~ "Publishing note:"
    assert changelog =~ "Release Please"
  end

  test "CHANGELOG.md documents tolerance: 0 reconciliation under v1.5" do
    # A future "fix it to be stricter" PR that silently drops the migration
    # note MUST fail this grep test. The inline source comment + this test +
    # the function-boundary test + the Plug-boundary test together triangulate
    # the decision so the drift cannot silently come back.
    changelog = File.read!("CHANGELOG.md")

    assert changelog =~ ~r/##\s*\[?1\.5/
    assert changelog =~ "tolerance: 0"
    assert changelog =~ "timestamp_expired" or changelog =~ "staleness"
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
    # locks the new "Thin events (/v2/events)" closing section in webhooks.md
    assert webhooks =~ "thin event"

    # README discovery route
    readme = File.read!("README.md")
    assert readme =~ "hexdocs.pm/lattice_stripe/webhooks-thin-events.html"

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
    assert readme =~ "hexdocs.pm/lattice_stripe/production-checklist.html"
    assert readme =~ "hexdocs.pm/lattice_stripe/event-debugging.html"
    assert readme =~ "Files and FileLinks"
    assert readme =~ "Disputes"
    assert readme =~ "Mandates"
    assert jtbd =~ "production-checklist.md"
    assert jtbd =~ "event-debugging.md"
    assert jtbd =~ "recipes.md"
    assert jtbd =~ "File.create" or jtbd =~ "update_evidence"
    assert jtbd =~ "Mandate and SetupAttempt diagnostics"
    assert webhooks =~ "event-debugging.md"
    assert errors =~ "production-checklist.md"
    assert errors =~ "event-debugging.md"
    assert testing =~ "event-debugging.md"
  end

  @planning_artifact_patterns [
    ~r/Phase \d+/,
    ~r/Plans? \d+-\d+/,
    ~r/\bD-\d+\b/,
    ~r/\bGUARD-\d+\b/,
    ~r/docs_truth_test/
  ]

  @guide_paths Path.wildcard("guides/*.{md,cheatmd}")

  test "canonical guides have balanced markdown fences" do
    alias LatticeStripe.DocsTruth.Fence

    for path <- @guide_paths do
      Fence.assert_balanced_fences!(path, File.read!(path))
    end
  end

  test "payment-flow sibling guides reject shared stale API patterns" do
    for path <- @payment_flow_guides, pattern <- @shared_payment_flow_stale_patterns do
      refute File.read!(path) =~ pattern,
             "stale API pattern #{inspect(pattern)} in #{path} (payment-flow cluster)"
    end
  end

  test "portal-flow sibling guides reject shared stale inter-guide .html links" do
    for path <- @portal_flow_guides, pattern <- @shared_portal_flow_stale_patterns do
      refute File.read!(path) =~ pattern,
             "stale inter-guide .html #{inspect(pattern)} in #{path} (portal-flow cluster)"
    end
  end

  test "connect-flow sibling guides reject shared stale inter-guide .html links" do
    for path <- @connect_flow_guides, pattern <- @shared_connect_stale_patterns do
      refute File.read!(path) =~ pattern,
             "stale inter-guide .html #{inspect(pattern)} in #{path} (connect-flow cluster)"
    end
  end

  test "connect-flow sibling guides cross-link the cluster" do
    connect = File.read!("guides/connect.md")
    accounts = File.read!("guides/connect-accounts.md")
    money = File.read!("guides/connect-money-movement.md")

    assert connect =~ "connect-accounts.md"
    assert connect =~ "connect-money-movement.md"
    assert accounts =~ "connect.md"
    assert accounts =~ "connect-money-movement.md"
    assert money =~ "connect.md"
    assert money =~ "connect-accounts.md"
  end

  test "webhook-flow sibling guides reject shared stale inter-guide .html links" do
    for path <- @webhook_flow_guides, pattern <- @shared_webhook_stale_patterns do
      refute File.read!(path) =~ pattern,
             "stale inter-guide .html #{inspect(pattern)} in #{path} (webhook-flow cluster)"
    end
  end

  test "webhook-flow sibling guides cross-link snapshot and thin-event guides" do
    snapshot = File.read!("guides/webhooks.md")
    thin = File.read!("guides/webhooks-thin-events.md")

    assert snapshot =~ "webhooks-thin-events.md"
    assert thin =~ "webhooks.md"
    assert snapshot =~ "Thin events"
    assert thin =~ "parse_event_notification"
  end

  test "canonical guides omit GSD planning artifact vocabulary" do
    for path <- @guide_paths do
      content = File.read!(path)

      for pattern <- @planning_artifact_patterns do
        refute content =~ pattern,
               "planning artifact #{inspect(pattern)} found in #{path}"
      end
    end
  end

  test "canonical guides use .md for inter-guide links (not .html siblings)" do
    inter_guide_html =
      ~r/\]\((?!https?:)(?!#)[^)]+\.html\)/

    for path <- @guide_paths do
      content = File.read!(path)

      refute content =~ inter_guide_html,
             "inter-guide .html link in #{path} — use .md for GitHub + HexDocs"
    end
  end

  test "guides omit malformed backtick-wrapped module URLs" do
    for path <- @guide_paths do
      content = File.read!(path)

      refute content =~ ~r/\]\(`[A-Za-z0-9_.]+`\)/,
             "malformed module link in #{path}"
    end
  end

  test "CHANGELOG header omits internal planning and test-harness vocabulary" do
    # First ~100 lines ship on HexDocs as the Changelog extra.
    header =
      "CHANGELOG.md"
      |> File.read!()
      |> String.split("\n")
      |> Enum.take(100)
      |> Enum.join("\n")

    refute header =~ ~r/Phase \d+/
    refute header =~ "docs_truth_test"
  end

  test "cheatsheet documents list pagination on Response.data" do
    cheatsheet = File.read!("guides/cheatsheet.cheatmd")

    assert cheatsheet =~ "resp.data.data"
    assert cheatsheet =~ "resp.data.has_more"
    refute cheatsheet =~ "result.has_more"
  end

  test "customer-portal See also links BillingPortal.Session on HexDocs" do
    guide = File.read!("guides/customer-portal.md")

    assert guide =~ "hexdocs.pm/lattice_stripe/LatticeStripe.BillingPortal.Session.html"
    refute guide =~ ~r/\]\(`LatticeStripe/
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
