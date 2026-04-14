defmodule LatticeStripe.BillingPortal.SessionTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  @moduletag :billing_portal

  alias LatticeStripe.BillingPortal.Session
  alias LatticeStripe.BillingPortal.Session.FlowData
  alias LatticeStripe.Test.Fixtures.BillingPortal, as: Fixtures

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # PORTAL-01 / PORTAL-02 / PORTAL-06
  # create/3 and create!/3 — dispatches HTTP POST, returns %Session{}
  # stripe_account: opt threads via Mox (PORTAL-06 Connect header)
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "returns {:ok, %Session{}} on success" do
      client = test_client()
      fixture = Fixtures.Session.basic()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(fixture)
      end)

      assert {:ok, %Session{id: "bps_123", customer: "cus_test123"}} =
               Session.create(client, %{"customer" => "cus_test123"})
    end

    test "returns {:error, %LatticeStripe.Error{}} on API error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %LatticeStripe.Error{}} =
               Session.create(client, %{"customer" => "cus_test123"})
    end

    test "raises ArgumentError pre-network when customer param is missing" do
      client = test_client()

      # Mox verify_on_exit! will confirm no transport call was made
      assert_raise ArgumentError, ~r/requires a customer param/, fn ->
        Session.create(client, %{})
      end
    end

    test "raises via Guards pre-network when flow_data is malformed" do
      client = test_client()

      params = %{
        "customer" => "cus_123",
        "flow_data" => %{"type" => "subscription_cancel"}
      }

      assert_raise ArgumentError, ~r/subscription_cancel\.subscription/, fn ->
        Session.create(client, params)
      end
    end

    test "threads stripe_account: opt as Stripe-Account header" do
      client = test_client()
      fixture = Fixtures.Session.basic()

      expect(LatticeStripe.MockTransport, :request, fn req_map ->
        assert {"stripe-account", "acct_test"} in req_map.headers
        ok_response(fixture)
      end)

      assert {:ok, %Session{}} =
               Session.create(client, %{"customer" => "cus_test123"},
                 stripe_account: "acct_test"
               )
    end
  end

  describe "create!/3" do
    test "returns %Session{} on success" do
      client = test_client()
      fixture = Fixtures.Session.basic()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(fixture)
      end)

      assert %Session{id: "bps_123"} =
               Session.create!(client, %{"customer" => "cus_test123"})
    end

    test "raises LatticeStripe.Error on API error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise LatticeStripe.Error, fn ->
        Session.create!(client, %{"customer" => "cus_test123"})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PORTAL-05
  # from_map/1 — decodes all 11 struct fields from string-keyed wire map
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "decodes all struct fields from basic fixture" do
      map = Fixtures.Session.basic()
      session = Session.from_map(map)

      assert %Session{
               id: "bps_123",
               object: "billing_portal.session",
               customer: "cus_test123",
               url: "https://billing.stripe.com/session/test_token",
               return_url: "https://example.com/account",
               configuration: "bpc_123",
               on_behalf_of: nil,
               locale: nil,
               created: 1_712_345_678,
               livemode: false,
               flow: nil
             } = session
    end

    test "decodes flow field into %FlowData{} when present" do
      map = Fixtures.Session.with_subscription_cancel_flow()
      session = Session.from_map(map)

      assert %FlowData{type: "subscription_cancel"} = session.flow
      assert session.flow.subscription_cancel.subscription == "sub_123"
    end

    test "decodes flow as nil when absent" do
      map = Fixtures.Session.basic(%{"flow" => nil})
      session = Session.from_map(map)
      assert session.flow == nil
    end

    test "returns nil when given nil" do
      assert Session.from_map(nil) == nil
    end

    test "captures unknown keys into :extra" do
      map = Fixtures.Session.basic(%{"unknown_future_field" => "some_value"})
      session = Session.from_map(map)
      assert session.extra == %{"unknown_future_field" => "some_value"}
    end
  end

  # ---------------------------------------------------------------------------
  # D-03 — Inspect allowlist masking
  # :url and :flow must NOT appear in inspect output
  # Visible fields: id, object, livemode, customer, configuration,
  #                 on_behalf_of, created, return_url, locale
  # ---------------------------------------------------------------------------

  describe "Inspect impl" do
    test "visible fields appear in inspect output" do
      session = Session.from_map(Fixtures.Session.basic())
      output = inspect(session)

      assert output =~ "#LatticeStripe.BillingPortal.Session<"
      assert output =~ "id:"
      assert output =~ "customer:"
      assert output =~ "livemode:"
      assert output =~ "return_url:"
    end

    test "masks :url and :flow in Inspect output" do
      session = %Session{
        id: "bps_123",
        object: "billing_portal.session",
        livemode: false,
        customer: "cus_test",
        url: "https://billing.stripe.com/secret_abc",
        return_url: "https://example.com",
        created: 123,
        flow: %FlowData{type: "subscription_cancel"}
      }

      output = inspect(session)

      assert output =~ "#LatticeStripe.BillingPortal.Session<"
      assert output =~ "id: \"bps_123\""
      assert output =~ "customer: \"cus_test\""
      refute output =~ session.url
      refute output =~ "FlowData"
      refute output =~ "secret_abc"
    end

    test "url is masked in inspect output" do
      session = Session.from_map(Fixtures.Session.basic())
      refute inspect(session) =~ session.url
    end

    test "flow is masked in inspect output" do
      session = Session.from_map(Fixtures.Session.with_subscription_cancel_flow())
      refute inspect(session) =~ "FlowData"
    end
  end
end
