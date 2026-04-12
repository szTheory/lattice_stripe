defmodule LatticeStripe.Invoice.AutomaticTaxTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Invoice.AutomaticTax

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert AutomaticTax.from_map(nil) == nil
    end

    test "parses a full map with all fields" do
      map = %{
        "enabled" => true,
        "status" => "complete",
        "liability" => %{"type" => "self"}
      }

      result = AutomaticTax.from_map(map)

      assert %AutomaticTax{} = result
      assert result.enabled == true
      assert result.status == "complete"
      assert result.liability == %{"type" => "self"}
    end

    test "returns nil for missing keys" do
      result = AutomaticTax.from_map(%{})

      assert result.enabled == nil
      assert result.status == nil
      assert result.liability == nil
    end

    test "parses partial map" do
      result = AutomaticTax.from_map(%{"enabled" => false})

      assert result.enabled == false
      assert result.status == nil
    end

    test "parses status with all valid Stripe values" do
      for status <- ["requires_location_inputs", "complete", "failed"] do
        result = AutomaticTax.from_map(%{"enabled" => true, "status" => status})
        assert result.status == status
      end
    end
  end
end
