defmodule LatticeStripe.Invoice.StatusTransitionsTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Invoice.StatusTransitions

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert StatusTransitions.from_map(nil) == nil
    end

    test "parses a full map with all fields" do
      map = %{
        "finalized_at" => 1_700_000_000,
        "marked_uncollectible_at" => 1_700_000_100,
        "paid_at" => 1_700_000_200,
        "voided_at" => nil
      }

      result = StatusTransitions.from_map(map)

      assert %StatusTransitions{} = result
      assert result.finalized_at == 1_700_000_000
      assert result.marked_uncollectible_at == 1_700_000_100
      assert result.paid_at == 1_700_000_200
      assert result.voided_at == nil
    end

    test "returns nil for missing keys" do
      result = StatusTransitions.from_map(%{})

      assert result.finalized_at == nil
      assert result.marked_uncollectible_at == nil
      assert result.paid_at == nil
      assert result.voided_at == nil
    end

    test "parses partial map" do
      result = StatusTransitions.from_map(%{"finalized_at" => 1_000_000})

      assert result.finalized_at == 1_000_000
      assert result.paid_at == nil
    end
  end
end
