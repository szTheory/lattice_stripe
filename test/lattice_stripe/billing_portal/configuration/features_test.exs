defmodule LatticeStripe.BillingPortal.Configuration.FeaturesTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.BillingPortal.Configuration.Features
  alias LatticeStripe.BillingPortal.Configuration.Features.{
    CustomerUpdate,
    PaymentMethodUpdate,
    SubscriptionCancel,
    SubscriptionUpdate
  }
  alias LatticeStripe.Test.Fixtures.BillingPortal

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert Features.from_map(nil) == nil
    end

    test "decodes customer_update into a CustomerUpdate struct" do
      map = BillingPortal.Configuration.basic()["features"]
      result = Features.from_map(map)
      assert %CustomerUpdate{} = result.customer_update
      assert result.customer_update.enabled == false
      assert result.customer_update.allowed_updates == []
    end

    test "decodes subscription_cancel into a SubscriptionCancel struct" do
      map = BillingPortal.Configuration.basic()["features"]
      result = Features.from_map(map)
      assert %SubscriptionCancel{} = result.subscription_cancel
      assert result.subscription_cancel.enabled == false
      assert result.subscription_cancel.mode == "at_period_end"
    end

    test "decodes subscription_update into a SubscriptionUpdate struct" do
      map = BillingPortal.Configuration.basic()["features"]
      result = Features.from_map(map)
      assert %SubscriptionUpdate{} = result.subscription_update
      assert result.subscription_update.enabled == false
      assert result.subscription_update.proration_behavior == "none"
    end

    test "decodes payment_method_update into a PaymentMethodUpdate struct" do
      map = BillingPortal.Configuration.basic()["features"]
      result = Features.from_map(map)
      assert %PaymentMethodUpdate{} = result.payment_method_update
      assert result.payment_method_update.enabled == false
    end

    test "keeps invoice_history as a raw map, not a struct" do
      map = BillingPortal.Configuration.basic()["features"]
      result = Features.from_map(map)
      assert result.invoice_history == %{"enabled" => true}
      refute is_struct(result.invoice_history)
    end

    test "captures unknown keys in extra" do
      map = %{
        "customer_update" => %{"enabled" => true, "allowed_updates" => []},
        "invoice_history" => %{"enabled" => true},
        "payment_method_update" => %{"enabled" => true},
        "subscription_cancel" => %{"enabled" => false},
        "subscription_update" => %{"enabled" => false},
        "future_feature" => %{"enabled" => true}
      }

      result = Features.from_map(map)
      assert result.extra == %{"future_feature" => %{"enabled" => true}}
    end

    test "returns empty extra when no unknown keys" do
      map = BillingPortal.Configuration.basic()["features"]
      result = Features.from_map(map)
      assert result.extra == %{}
    end
  end
end
