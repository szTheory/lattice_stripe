defmodule LatticeStripe.Invoice.LineItemTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Invoice.LineItem

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert LineItem.from_map(nil) == nil
    end

    test "parses a full map with all known fields" do
      map = %{
        "id" => "il_test123",
        "object" => "line_item",
        "amount" => 2000,
        "amount_excluding_tax" => 2000,
        "currency" => "usd",
        "description" => "1 seat of Pro Plan",
        "discount_amounts" => [],
        "discountable" => true,
        "discounts" => [],
        "invoice" => "in_test123",
        "invoice_item" => "ii_test456",
        "livemode" => false,
        "metadata" => %{},
        "period" => %{"start" => 1_700_000_000, "end" => 1_702_000_000},
        "plan" => nil,
        "price" => %{"id" => "price_xxx"},
        "proration" => false,
        "proration_details" => nil,
        "quantity" => 1,
        "subscription" => "sub_test789",
        "subscription_item" => "si_test000",
        "tax_amounts" => [],
        "tax_rates" => [],
        "type" => "subscription",
        "unit_amount_excluding_tax" => "2000"
      }

      result = LineItem.from_map(map)

      assert %LineItem{} = result
      assert result.id == "il_test123"
      assert result.object == "line_item"
      assert result.amount == 2000
      assert result.currency == "usd"
      assert result.description == "1 seat of Pro Plan"
      assert result.invoice_item == "ii_test456"
      assert result.proration == false
      assert result.type == "subscription"
      assert result.extra == %{}
    end

    test "captures unknown fields in extra map" do
      map = %{
        "id" => "il_test123",
        "object" => "line_item",
        "unknown_future_field" => "some_value",
        "another_unknown" => 42
      }

      result = LineItem.from_map(map)

      assert result.id == "il_test123"
      assert result.extra == %{"unknown_future_field" => "some_value", "another_unknown" => 42}
    end

    test "defaults object to line_item when missing" do
      result = LineItem.from_map(%{"id" => "il_xxx"})
      assert result.object == "line_item"
    end

    test "returns nil for missing known fields" do
      result = LineItem.from_map(%{})

      assert result.id == nil
      assert result.amount == nil
      assert result.currency == nil
      assert result.extra == %{}
    end

    test "extra is empty map when all fields are known" do
      map = %{"id" => "il_xxx", "object" => "line_item"}
      result = LineItem.from_map(map)
      assert result.extra == %{}
    end
  end

  describe "Inspect protocol" do
    test "inspect output does not show extra when empty" do
      item = LineItem.from_map(%{"id" => "il_xxx", "object" => "line_item", "amount" => 500})
      output = inspect(item)
      refute output =~ "extra:"
    end

    test "inspect output shows extra when non-empty" do
      item =
        LineItem.from_map(%{
          "id" => "il_xxx",
          "object" => "line_item",
          "unknown_field" => "val"
        })

      output = inspect(item)
      assert output =~ "extra:"
    end
  end
end
