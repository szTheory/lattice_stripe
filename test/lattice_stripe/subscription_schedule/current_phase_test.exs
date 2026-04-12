defmodule LatticeStripe.SubscriptionSchedule.CurrentPhaseTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.SubscriptionSchedule.CurrentPhase

  describe "from_map/1" do
    test "returns nil for nil input" do
      assert CurrentPhase.from_map(nil) == nil
    end

    test "decodes start_date and end_date" do
      result = CurrentPhase.from_map(%{"start_date" => 1_700_000_000, "end_date" => 1_702_678_400})

      assert %CurrentPhase{start_date: 1_700_000_000, end_date: 1_702_678_400, extra: %{}} = result
    end

    test "puts unknown fields in :extra" do
      result =
        CurrentPhase.from_map(%{
          "start_date" => 1_700_000_000,
          "end_date" => 1_702_678_400,
          "future_field" => "hello"
        })

      assert result.start_date == 1_700_000_000
      assert result.end_date == 1_702_678_400
      assert result.extra == %{"future_field" => "hello"}
    end
  end
end
