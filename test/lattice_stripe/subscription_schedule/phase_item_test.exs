defmodule LatticeStripe.SubscriptionSchedule.PhaseItemTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.SubscriptionSchedule.PhaseItem

  describe "from_map/1" do
    test "returns nil for nil input" do
      assert PhaseItem.from_map(nil) == nil
    end

    test "decodes price, price_data, quantity, trial_data" do
      map = %{
        "billing_thresholds" => nil,
        "discounts" => [],
        "metadata" => %{"key" => "value"},
        "plan" => nil,
        "price" => "price_test123",
        "price_data" => %{
          "currency" => "usd",
          "product" => "prod_test",
          "recurring" => %{"interval" => "month"},
          "unit_amount" => 1000
        },
        "quantity" => 2,
        "tax_rates" => [],
        "trial_data" => %{"converts_to" => ["paid"]}
      }

      result = PhaseItem.from_map(map)

      assert %PhaseItem{} = result
      assert result.price == "price_test123"
      assert result.price_data["currency"] == "usd"
      assert result.price_data["recurring"]["interval"] == "month"
      assert result.quantity == 2
      assert result.metadata == %{"key" => "value"}
      assert result.trial_data == %{"converts_to" => ["paid"]}
      assert result.extra == %{}
    end

    test "puts unknown fields in :extra" do
      result =
        PhaseItem.from_map(%{
          "price" => "price_test123",
          "future_field" => "hello"
        })

      assert result.price == "price_test123"
      assert result.extra == %{"future_field" => "hello"}
    end

    test "struct has no :id field (regression guard — divergence from SubscriptionItem)" do
      refute Map.has_key?(Map.from_struct(%PhaseItem{}), :id)
      refute Map.has_key?(Map.from_struct(%PhaseItem{}), :object)
      refute Map.has_key?(Map.from_struct(%PhaseItem{}), :subscription)
      refute Map.has_key?(Map.from_struct(%PhaseItem{}), :created)
      refute Map.has_key?(Map.from_struct(%PhaseItem{}), :current_period_start)
      refute Map.has_key?(Map.from_struct(%PhaseItem{}), :current_period_end)
    end
  end
end
