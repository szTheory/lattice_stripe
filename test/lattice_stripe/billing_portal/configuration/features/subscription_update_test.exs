defmodule LatticeStripe.BillingPortal.Configuration.Features.SubscriptionUpdateTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.BillingPortal.Configuration.Features.SubscriptionUpdate

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert SubscriptionUpdate.from_map(nil) == nil
    end

    test "decodes all known fields correctly" do
      map = %{
        "enabled" => false,
        "billing_cycle_anchor" => nil,
        "default_allowed_updates" => [],
        "proration_behavior" => "none",
        "products" => [],
        "schedule_at_period_end" => nil,
        "trial_update_behavior" => nil
      }

      result = SubscriptionUpdate.from_map(map)
      assert result.enabled == false
      assert result.billing_cycle_anchor == nil
      assert result.default_allowed_updates == []
      assert result.proration_behavior == "none"
      assert result.trial_update_behavior == nil
    end

    test "products is on the struct, not in extra (Pitfall 1 regression guard)" do
      map = %{
        "enabled" => true,
        "products" => [%{"product" => "prod_123", "prices" => ["price_abc"]}]
      }

      result = SubscriptionUpdate.from_map(map)
      assert result.products == [%{"product" => "prod_123", "prices" => ["price_abc"]}]
      refute Map.has_key?(result.extra, "products")
    end

    test "schedule_at_period_end is on the struct, not in extra (Pitfall 1 regression guard)" do
      map = %{
        "enabled" => true,
        "schedule_at_period_end" => %{"enabled" => true}
      }

      result = SubscriptionUpdate.from_map(map)
      assert result.schedule_at_period_end == %{"enabled" => true}
      refute Map.has_key?(result.extra, "schedule_at_period_end")
    end

    test "decodes default_allowed_updates list" do
      map = %{
        "enabled" => true,
        "default_allowed_updates" => ["price", "quantity", "promotion_code"]
      }

      result = SubscriptionUpdate.from_map(map)
      assert result.default_allowed_updates == ["price", "quantity", "promotion_code"]
    end

    test "captures unknown keys in extra" do
      map = %{
        "enabled" => true,
        "proration_behavior" => "always_invoice",
        "future_field" => "future_value"
      }

      result = SubscriptionUpdate.from_map(map)
      assert result.extra == %{"future_field" => "future_value"}
    end

    test "returns empty extra when no unknown keys" do
      map = %{
        "enabled" => false,
        "billing_cycle_anchor" => nil,
        "default_allowed_updates" => [],
        "proration_behavior" => "none",
        "products" => [],
        "schedule_at_period_end" => nil,
        "trial_update_behavior" => nil
      }

      result = SubscriptionUpdate.from_map(map)
      assert result.extra == %{}
    end
  end
end
