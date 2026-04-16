defmodule LatticeStripe.Billing.MeterEventStreamTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Billing.MeterEventStream.Session
  alias LatticeStripe.Test.Fixtures.Metering

  describe "Session.from_map/1" do
    test "deserializes v2 session response into struct" do
      session = Session.from_map(Metering.MeterEventStreamSession.basic())

      assert %Session{} = session
      assert session.id == "mes_123"
      assert session.object == "v2.billing.meter_event_session"
      assert session.authentication_token == "tok_test_abc"
      assert session.created == 1_712_345_678
      assert session.expires_at == 1_712_346_578
      assert session.livemode == false
    end

    test "returns nil for nil input" do
      assert Session.from_map(nil) == nil
    end

    test "handles overrides in fixture" do
      session =
        Session.from_map(
          Metering.MeterEventStreamSession.basic(%{"livemode" => true})
        )

      assert session.livemode == true
      assert session.id == "mes_123"
    end
  end

  describe "Session Inspect masking" do
    setup do
      session = Session.from_map(Metering.MeterEventStreamSession.basic())
      %{session: session, rendered: inspect(session)}
    end

    test "renders with struct prefix", %{rendered: r} do
      assert r =~ "#LatticeStripe.Billing.MeterEventStream.Session<"
    end

    test "hides authentication_token value", %{rendered: r} do
      refute r =~ "tok_test_abc"
    end

    test "does not include authentication_token key", %{rendered: r} do
      refute r =~ "authentication_token:"
    end

    test "shows structural fields", %{rendered: r} do
      assert r =~ "id:"
      assert r =~ "object:"
      assert r =~ "created:"
      assert r =~ "expires_at:"
      assert r =~ "livemode:"
    end
  end
end
