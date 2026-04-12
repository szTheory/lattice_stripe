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

    test "unknown fields land in :extra rather than being silently dropped" do
      result =
        AutomaticTax.from_map(%{
          "enabled" => true,
          "status" => "complete",
          "future_field" => "hello",
          "another_new_field" => %{"nested" => 1}
        })

      assert result.enabled == true
      assert result.status == "complete"

      assert result.extra == %{
               "future_field" => "hello",
               "another_new_field" => %{"nested" => 1}
             }
    end

    test "extra defaults to empty map when no unknown fields" do
      result = AutomaticTax.from_map(%{"enabled" => true})
      assert result.extra == %{}
    end
  end

  describe "Inspect" do
    test "hides empty :extra for compact output" do
      inspected = inspect(AutomaticTax.from_map(%{"enabled" => true, "status" => "complete"}))

      assert inspected =~ "#LatticeStripe.Invoice.AutomaticTax<"
      assert inspected =~ "enabled: true"
      assert inspected =~ ~s(status: "complete")
      refute inspected =~ "extra:"
    end

    test "shows :extra when non-empty" do
      inspected =
        inspect(AutomaticTax.from_map(%{"enabled" => true, "future_field" => "hello"}))

      assert inspected =~ "extra:"
      assert inspected =~ "future_field"
    end
  end
end
