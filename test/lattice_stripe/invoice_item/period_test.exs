defmodule LatticeStripe.InvoiceItem.PeriodTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.InvoiceItem.Period

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert Period.from_map(nil) == nil
    end

    test "parses a full map with start and end" do
      map = %{"start" => 1_700_000_000, "end" => 1_702_000_000}
      result = Period.from_map(map)

      assert %Period{} = result
      assert result.start == 1_700_000_000
      assert result.end == 1_702_000_000
    end

    test "returns nil for missing keys" do
      result = Period.from_map(%{})

      assert result.start == nil
      assert result.end == nil
    end

    test "parses partial map" do
      result = Period.from_map(%{"start" => 1_000_000})

      assert result.start == 1_000_000
      assert result.end == nil
    end
  end
end
