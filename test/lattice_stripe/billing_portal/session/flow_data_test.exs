defmodule LatticeStripe.BillingPortal.Session.FlowDataTest do
  use ExUnit.Case, async: true

  @moduletag :billing_portal

  alias LatticeStripe.Test.Fixtures.BillingPortal, as: Fixtures

  # ---------------------------------------------------------------------------
  # PORTAL-03 — FlowData.from_map/1 decode cases
  # Covers all 4 flow types + nil + unknown key capture in :extra.
  # Implemented in plan 21-02 (TDD: RED in 21-02 Wave 1, GREEN after FlowData
  # nested structs are created).
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    @tag :skip
    test "returns nil when given nil" do
      # PORTAL-03 nil case — implement in plan 21-02
      # alias LatticeStripe.BillingPortal.Session.FlowData
      # assert FlowData.from_map(nil) == nil
    end

    @tag :skip
    test "decodes payment_method_update flow" do
      # PORTAL-03 payment_method_update — implement in plan 21-02
      # flow_map = Fixtures.Session.with_payment_method_update_flow()["flow"]
      # result = FlowData.from_map(flow_map)
      # assert %FlowData{type: "payment_method_update"} = result
      # assert result.subscription_cancel == nil
      # assert result.subscription_update == nil
      # assert result.subscription_update_confirm == nil
    end

    @tag :skip
    test "decodes subscription_cancel flow" do
      # PORTAL-03 subscription_cancel — implement in plan 21-02
      # flow_map = Fixtures.Session.with_subscription_cancel_flow()["flow"]
      # result = FlowData.from_map(flow_map)
      # assert %FlowData{type: "subscription_cancel"} = result
      # assert %SubscriptionCancel{subscription: "sub_123"} = result.subscription_cancel
    end

    @tag :skip
    test "decodes subscription_update flow" do
      # PORTAL-03 subscription_update — implement in plan 21-02
      # flow_map = Fixtures.Session.with_subscription_update_flow()["flow"]
      # result = FlowData.from_map(flow_map)
      # assert %FlowData{type: "subscription_update"} = result
      # assert %SubscriptionUpdate{subscription: "sub_456"} = result.subscription_update
    end

    @tag :skip
    test "decodes subscription_update_confirm flow with items" do
      # PORTAL-03 subscription_update_confirm — implement in plan 21-02
      # flow_map = Fixtures.Session.with_subscription_update_confirm_flow()["flow"]
      # result = FlowData.from_map(flow_map)
      # assert %FlowData{type: "subscription_update_confirm"} = result
      # confirm = result.subscription_update_confirm
      # assert confirm.subscription == "sub_789"
      # assert [%{"id" => "si_123"}] = confirm.items
    end

    @tag :skip
    test "captures unknown keys into :extra without crashing" do
      # PORTAL-03 extra capture (forward-compat) — implement in plan 21-02
      # flow_map = %{"type" => "payment_method_update", "future_field" => "value"}
      # result = FlowData.from_map(flow_map)
      # assert result.extra == %{"future_field" => "value"}
    end

    @tag :skip
    test "unknown flow type lands in :extra via type field; does not crash" do
      # PORTAL-03 unknown type forward-compat — implement in plan 21-02
      # flow_map = %{"type" => "subscription_pause", "subscription_pause" => %{}}
      # result = FlowData.from_map(flow_map)
      # assert result.type == "subscription_pause"
      # assert result.extra == %{"subscription_pause" => %{}}
    end
  end
end
