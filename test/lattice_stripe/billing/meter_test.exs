defmodule LatticeStripe.Billing.MeterTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Billing.Meter.{CustomerMapping, DefaultAggregation, StatusTransitions, ValueSettings}

  describe "DefaultAggregation.from_map/1" do
    test "round-trips formula string" do
      assert %DefaultAggregation{formula: "sum"} =
               DefaultAggregation.from_map(%{"formula" => "sum"})
    end

    test "handles nil" do
      assert DefaultAggregation.from_map(nil) == nil
    end

    test "handles empty map" do
      assert %DefaultAggregation{formula: nil} = DefaultAggregation.from_map(%{})
    end

    test "has no :extra field" do
      refute Map.has_key?(%DefaultAggregation{}, :extra)
    end
  end

  describe "ValueSettings.from_map/1" do
    test "round-trips event_payload_key" do
      assert %ValueSettings{event_payload_key: "tokens"} =
               ValueSettings.from_map(%{"event_payload_key" => "tokens"})
    end

    test "handles nil" do
      assert ValueSettings.from_map(nil) == nil
    end

    test "has no :extra field" do
      refute Map.has_key?(%ValueSettings{}, :extra)
    end
  end

  describe "CustomerMapping.from_map/1" do
    test "round-trips known fields" do
      assert %CustomerMapping{event_payload_key: "stripe_customer_id", type: "by_id", extra: extra} =
               CustomerMapping.from_map(%{
                 "event_payload_key" => "stripe_customer_id",
                 "type" => "by_id"
               })

      assert extra == %{}
    end

    test "captures unknown fields in :extra" do
      assert %CustomerMapping{extra: %{"future_field" => 1}} =
               CustomerMapping.from_map(%{
                 "event_payload_key" => "k",
                 "type" => "by_id",
                 "future_field" => 1
               })
    end

    test "handles nil" do
      assert CustomerMapping.from_map(nil) == nil
    end
  end

  describe "StatusTransitions.from_map/1" do
    test "round-trips deactivated_at" do
      assert %StatusTransitions{deactivated_at: 1_712_400_000, extra: %{}} =
               StatusTransitions.from_map(%{"deactivated_at" => 1_712_400_000})
    end

    test "captures unknown transitions in :extra" do
      assert %StatusTransitions{extra: %{"frozen_at" => 99}} =
               StatusTransitions.from_map(%{"deactivated_at" => nil, "frozen_at" => 99})
    end

    test "handles nil" do
      assert StatusTransitions.from_map(nil) == nil
    end
  end
end
