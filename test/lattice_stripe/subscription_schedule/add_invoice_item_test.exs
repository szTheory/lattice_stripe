defmodule LatticeStripe.SubscriptionSchedule.AddInvoiceItemTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.SubscriptionSchedule.AddInvoiceItem

  describe "from_map/1" do
    test "returns nil for nil input" do
      assert AddInvoiceItem.from_map(nil) == nil
    end

    test "decodes price and period" do
      map = %{
        "discounts" => [],
        "metadata" => %{},
        "period" => %{"start" => 1_700_000_000, "end" => 1_702_678_400},
        "price" => "price_setup_fee",
        "price_data" => nil,
        "quantity" => 1,
        "tax_rates" => []
      }

      result = AddInvoiceItem.from_map(map)

      assert %AddInvoiceItem{} = result
      assert result.price == "price_setup_fee"
      assert result.period == %{"start" => 1_700_000_000, "end" => 1_702_678_400}
      assert result.quantity == 1
      assert result.extra == %{}
    end

    test "puts unknown fields in :extra" do
      result =
        AddInvoiceItem.from_map(%{
          "price" => "price_setup_fee",
          "future_field" => "hello"
        })

      assert result.price == "price_setup_fee"
      assert result.extra == %{"future_field" => "hello"}
    end
  end
end
