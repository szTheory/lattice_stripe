defmodule LatticeStripe.Account.RequirementsTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Account.Requirements
  alias LatticeStripe.Test.Fixtures.Account, as: AccountFixtures

  describe "from_map/1" do
    test "returns nil for nil input" do
      assert Requirements.from_map(nil) == nil
    end

    test "returns struct with all known fields nil and extra: %{} for empty map" do
      result = Requirements.from_map(%{})

      assert %Requirements{} = result
      assert result.currently_due == nil
      assert result.eventually_due == nil
      assert result.past_due == nil
      assert result.pending_verification == nil
      assert result.disabled_reason == nil
      assert result.current_deadline == nil
      assert result.errors == nil
      assert result.alternatives == nil
      assert result.extra == %{}
    end

    test "casts known fields correctly" do
      result = Requirements.from_map(%{
        "currently_due" => ["external_account"],
        "eventually_due" => ["external_account"],
        "past_due" => [],
        "pending_verification" => [],
        "disabled_reason" => nil,
        "current_deadline" => 1_702_678_400,
        "errors" => [],
        "alternatives" => []
      })

      assert result.currently_due == ["external_account"]
      assert result.eventually_due == ["external_account"]
      assert result.past_due == []
      assert result.pending_verification == []
      assert result.disabled_reason == nil
      assert result.current_deadline == 1_702_678_400
      assert result.errors == []
      assert result.alternatives == []
    end

    test "currently_due list field is preserved as a list" do
      result = Requirements.from_map(%{"currently_due" => ["item_a", "item_b", "item_c"]})
      assert result.currently_due == ["item_a", "item_b", "item_c"]
    end

    test "unknown fields land in :extra" do
      result = Requirements.from_map(%{"currently_due" => [], "zzz_new_field" => "future"})
      assert result.currently_due == []
      assert result.extra == %{"zzz_new_field" => "future"}
    end

    test "requirements and future_requirements both produce structurally-equivalent structs (D-01 reuse)" do
      account = AccountFixtures.basic()

      req_struct = Requirements.from_map(account["requirements"])
      future_req_struct = Requirements.from_map(account["future_requirements"])

      # Both are the same struct type — the single module is reused at both sites
      assert %Requirements{} = req_struct
      assert %Requirements{} = future_req_struct

      # Both have the same fields populated
      assert req_struct.currently_due == ["external_account"]
      assert future_req_struct.currently_due == []

      # Structural equivalence: both have all 8 known fields accessible
      assert Map.has_key?(Map.from_struct(req_struct), :alternatives)
      assert Map.has_key?(Map.from_struct(req_struct), :current_deadline)
      assert Map.has_key?(Map.from_struct(req_struct), :currently_due)
      assert Map.has_key?(Map.from_struct(req_struct), :disabled_reason)
      assert Map.has_key?(Map.from_struct(req_struct), :errors)
      assert Map.has_key?(Map.from_struct(req_struct), :eventually_due)
      assert Map.has_key?(Map.from_struct(req_struct), :past_due)
      assert Map.has_key?(Map.from_struct(req_struct), :pending_verification)
    end
  end
end
