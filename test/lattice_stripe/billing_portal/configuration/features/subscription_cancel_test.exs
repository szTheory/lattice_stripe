defmodule LatticeStripe.BillingPortal.Configuration.Features.SubscriptionCancelTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.BillingPortal.Configuration.Features.SubscriptionCancel

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert SubscriptionCancel.from_map(nil) == nil
    end

    test "decodes all known fields correctly" do
      map = %{
        "enabled" => false,
        "mode" => "at_period_end",
        "proration_behavior" => "none",
        "cancellation_reason" => %{"enabled" => false, "options" => []}
      }

      result = SubscriptionCancel.from_map(map)
      assert result.enabled == false
      assert result.mode == "at_period_end"
      assert result.proration_behavior == "none"
    end

    test "cancellation_reason is on the struct, not in extra (Pitfall 1 regression guard)" do
      map = %{
        "enabled" => true,
        "mode" => "immediately",
        "proration_behavior" => "always_invoice",
        "cancellation_reason" => %{"enabled" => false, "options" => []}
      }

      result = SubscriptionCancel.from_map(map)
      assert result.cancellation_reason == %{"enabled" => false, "options" => []}
      refute Map.has_key?(result.extra, "cancellation_reason")
    end

    test "cancellation_reason with options list is preserved as-is" do
      map = %{
        "enabled" => true,
        "cancellation_reason" => %{
          "enabled" => true,
          "options" => ["customer_service", "low_quality", "missing_features"]
        }
      }

      result = SubscriptionCancel.from_map(map)
      assert result.cancellation_reason == %{
               "enabled" => true,
               "options" => ["customer_service", "low_quality", "missing_features"]
             }
    end

    test "captures unknown keys in extra" do
      map = %{
        "enabled" => true,
        "mode" => "immediately",
        "proration_behavior" => "none",
        "cancellation_reason" => nil,
        "future_field" => "future_value"
      }

      result = SubscriptionCancel.from_map(map)
      assert result.extra == %{"future_field" => "future_value"}
    end

    test "returns empty extra when no unknown keys" do
      map = %{
        "enabled" => false,
        "mode" => "at_period_end",
        "proration_behavior" => "none",
        "cancellation_reason" => nil
      }

      result = SubscriptionCancel.from_map(map)
      assert result.extra == %{}
    end

    test "handles nil field values gracefully" do
      map = %{
        "enabled" => nil,
        "mode" => nil,
        "proration_behavior" => nil,
        "cancellation_reason" => nil
      }

      result = SubscriptionCancel.from_map(map)
      assert result.enabled == nil
      assert result.mode == nil
      assert result.proration_behavior == nil
      assert result.cancellation_reason == nil
    end
  end
end
