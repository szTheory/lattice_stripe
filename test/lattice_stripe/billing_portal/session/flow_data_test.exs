defmodule LatticeStripe.BillingPortal.Session.FlowDataTest do
  use ExUnit.Case, async: true

  @moduletag :billing_portal

  alias LatticeStripe.Test.Fixtures.BillingPortal, as: Fixtures

  alias LatticeStripe.BillingPortal.Session.FlowData
  alias LatticeStripe.BillingPortal.Session.FlowData.AfterCompletion
  alias LatticeStripe.BillingPortal.Session.FlowData.SubscriptionCancel
  alias LatticeStripe.BillingPortal.Session.FlowData.SubscriptionUpdate
  alias LatticeStripe.BillingPortal.Session.FlowData.SubscriptionUpdateConfirm

  # ---------------------------------------------------------------------------
  # PORTAL-03 — FlowData sub-struct decode cases (Task 1: sub-modules)
  # ---------------------------------------------------------------------------

  describe "AfterCompletion.from_map/1" do
    test "returns nil when given nil" do
      assert AfterCompletion.from_map(nil) == nil
    end

    test "decodes redirect after_completion with unknown keys in :extra" do
      result =
        AfterCompletion.from_map(%{
          "type" => "redirect",
          "redirect" => %{"return_url" => "https://x"},
          "other" => "keep"
        })

      assert %AfterCompletion{
               type: "redirect",
               redirect: %{"return_url" => "https://x"},
               hosted_confirmation: nil,
               extra: %{"other" => "keep"}
             } = result
    end

    test "decodes hosted_confirmation after_completion" do
      result =
        AfterCompletion.from_map(%{
          "type" => "hosted_confirmation",
          "hosted_confirmation" => %{"custom_message" => "Thanks!"},
          "redirect" => nil
        })

      assert result.type == "hosted_confirmation"
      assert result.hosted_confirmation == %{"custom_message" => "Thanks!"}
      assert result.redirect == nil
      assert result.extra == %{}
    end
  end

  describe "SubscriptionCancel.from_map/1" do
    test "returns nil when given nil" do
      assert SubscriptionCancel.from_map(nil) == nil
    end

    test "decodes subscription and retention, no extra" do
      result =
        SubscriptionCancel.from_map(%{
          "subscription" => "sub_123",
          "retention" => %{"type" => "coupon_offer"}
        })

      assert %SubscriptionCancel{
               subscription: "sub_123",
               retention: %{"type" => "coupon_offer"},
               extra: %{}
             } = result
    end

    test "captures unknown keys into :extra" do
      result = SubscriptionCancel.from_map(%{"subscription" => "sub_123", "unknown" => "x"})
      assert result.subscription == "sub_123"
      assert result.extra == %{"unknown" => "x"}
    end
  end

  describe "SubscriptionUpdate.from_map/1" do
    test "returns nil when given nil" do
      assert SubscriptionUpdate.from_map(nil) == nil
    end

    test "decodes subscription field, captures extra" do
      result = SubscriptionUpdate.from_map(%{"subscription" => "sub_456", "unknown" => "x"})

      assert %SubscriptionUpdate{subscription: "sub_456", extra: %{"unknown" => "x"}} = result
    end
  end

  describe "SubscriptionUpdateConfirm.from_map/1" do
    test "returns nil when given nil" do
      assert SubscriptionUpdateConfirm.from_map(nil) == nil
    end

    test "decodes subscription, items, discounts" do
      result =
        SubscriptionUpdateConfirm.from_map(%{
          "subscription" => "sub_789",
          "items" => [%{"id" => "si_1"}],
          "discounts" => []
        })

      assert %SubscriptionUpdateConfirm{
               subscription: "sub_789",
               items: [%{"id" => "si_1"}],
               discounts: [],
               extra: %{}
             } = result
    end
  end

  # ---------------------------------------------------------------------------
  # PORTAL-03 — FlowData.from_map/1 decode cases (Task 2: parent module)
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert FlowData.from_map(nil) == nil
    end

    test "decodes payment_method_update flow" do
      flow_map = Fixtures.Session.with_payment_method_update_flow()["flow"]
      result = FlowData.from_map(flow_map)
      assert %FlowData{type: "payment_method_update"} = result
      assert result.subscription_cancel == nil
      assert result.subscription_update == nil
      assert result.subscription_update_confirm == nil
    end

    test "decodes subscription_cancel flow" do
      flow_map = Fixtures.Session.with_subscription_cancel_flow()["flow"]
      result = FlowData.from_map(flow_map)
      assert %FlowData{type: "subscription_cancel"} = result
      assert %SubscriptionCancel{subscription: "sub_123"} = result.subscription_cancel
    end

    test "decodes subscription_update flow" do
      flow_map = Fixtures.Session.with_subscription_update_flow()["flow"]
      result = FlowData.from_map(flow_map)
      assert %FlowData{type: "subscription_update"} = result
      assert %SubscriptionUpdate{subscription: "sub_456"} = result.subscription_update
    end

    test "decodes subscription_update_confirm flow with items" do
      flow_map = Fixtures.Session.with_subscription_update_confirm_flow()["flow"]
      result = FlowData.from_map(flow_map)
      assert %FlowData{type: "subscription_update_confirm"} = result
      confirm = result.subscription_update_confirm
      assert confirm.subscription == "sub_789"
      assert [%{"id" => "si_123"}] = confirm.items
    end

    test "captures unknown keys into :extra without crashing" do
      flow_map = %{"type" => "payment_method_update", "future_field" => "value"}
      result = FlowData.from_map(flow_map)
      assert result.extra == %{"future_field" => "value"}
    end

    test "unknown flow type lands in :extra via type field; does not crash" do
      flow_map = %{"type" => "subscription_pause", "subscription_pause" => %{}}
      result = FlowData.from_map(flow_map)
      assert result.type == "subscription_pause"
      assert result.extra == %{"subscription_pause" => %{}}
    end

    test "atom dot-access works end-to-end: subscription_cancel.subscription" do
      flow_map = Fixtures.Session.with_subscription_cancel_flow()["flow"]
      result = FlowData.from_map(flow_map)
      assert %FlowData{subscription_cancel: %SubscriptionCancel{subscription: "sub_123"}} = result
      assert result.subscription_cancel.subscription == "sub_123"
    end
  end
end
