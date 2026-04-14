defmodule LatticeStripe.BillingPortal.SessionTest do
  use ExUnit.Case, async: true

  # Mox, TestHelpers, Session, and Fixtures are referenced in skipped test
  # bodies below. Plan 21-03 will activate them when implementation lands.
  import Mox
  import LatticeStripe.TestHelpers

  @moduletag :billing_portal

  alias LatticeStripe.BillingPortal.Session
  alias LatticeStripe.Test.Fixtures.BillingPortal, as: Fixtures

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # PORTAL-01 / PORTAL-02 / PORTAL-06
  # create/3 and create!/3 — dispatches HTTP POST, returns %Session{}
  # stripe_account: opt threads via Mox (PORTAL-06 Connect header)
  # ---------------------------------------------------------------------------

  describe "create/3" do
    @tag :skip
    test "returns {:ok, %Session{}} on success" do
      # PORTAL-01 — implement in plan 21-03
      # Arrange: stub MockTransport to return Fixtures.BillingPortal.Session.basic()
      # Act: Session.create(client, %{"customer" => "cus_test123"})
      # Assert: {:ok, %Session{id: "bps_123", url: "https://billing.stripe.com/session/test_token"}}
    end

    @tag :skip
    test "returns {:error, %LatticeStripe.Error{}} on API error" do
      # PORTAL-01 error path — implement in plan 21-03
    end

    @tag :skip
    test "threads stripe_account: opt as Stripe-Account header" do
      # PORTAL-06 Connect — implement in plan 21-03
      # Verify MockTransport receives Stripe-Account: acct_123 header
    end
  end

  describe "create!/3" do
    @tag :skip
    test "returns %Session{} on success" do
      # PORTAL-02 — implement in plan 21-03
    end

    @tag :skip
    test "raises LatticeStripe.Error on API error" do
      # PORTAL-02 bang error path — implement in plan 21-03
    end
  end

  # ---------------------------------------------------------------------------
  # PORTAL-05
  # from_map/1 — decodes all 10 struct fields from string-keyed wire map
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    @tag :skip
    test "decodes all struct fields from basic fixture" do
      # PORTAL-05 — implement in plan 21-03
      # map = Fixtures.Session.basic()
      # session = Session.from_map(map)
      # assert %Session{id: "bps_123", object: "billing_portal.session", ...} = session
    end

    @tag :skip
    test "decodes flow field into %FlowData{} when present" do
      # PORTAL-05 / PORTAL-03 integration — implement in plan 21-03
      # map = Fixtures.Session.with_subscription_cancel_flow()
      # session = Session.from_map(map)
      # assert %FlowData{type: "subscription_cancel"} = session.flow
    end

    @tag :skip
    test "decodes flow as nil when absent" do
      # PORTAL-05 nil flow — implement in plan 21-03
    end
  end

  # ---------------------------------------------------------------------------
  # D-03 — Inspect allowlist masking
  # :url and :flow must NOT appear in inspect output
  # Visible fields: id, object, livemode, customer, configuration,
  #                 on_behalf_of, created, return_url, locale
  # ---------------------------------------------------------------------------

  describe "Inspect impl" do
    @tag :skip
    test "visible fields appear in inspect output" do
      # D-03 — implement in plan 21-03
      # session = Session.from_map(Fixtures.Session.basic())
      # inspected = inspect(session)
      # assert inspected =~ "id:"
      # assert inspected =~ "customer:"
      # assert inspected =~ "livemode:"
    end

    @tag :skip
    test "url is masked in inspect output" do
      # D-03 Inspect masking — implement in plan 21-03
      # session = Session.from_map(Fixtures.Session.basic())
      # refute inspect(session) =~ session.url
    end

    @tag :skip
    test "flow is masked in inspect output" do
      # D-03 Inspect masking for flow — implement in plan 21-03
      # session = Session.from_map(Fixtures.Session.with_subscription_cancel_flow())
      # refute inspect(session) =~ "FlowData"
    end
  end
end
