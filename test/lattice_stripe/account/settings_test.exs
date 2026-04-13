defmodule LatticeStripe.Account.SettingsTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Account.Settings
  alias LatticeStripe.Test.Fixtures.Account, as: AccountFixtures

  describe "from_map/1" do
    test "returns nil for nil input" do
      assert Settings.from_map(nil) == nil
    end

    test "returns struct with all known fields nil and extra: %{} for empty map" do
      result = Settings.from_map(%{})

      assert %Settings{} = result
      assert result.branding == nil
      assert result.card_payments == nil
      assert result.dashboard == nil
      assert result.payments == nil
      assert result.payouts == nil
      assert result.extra == %{}
    end

    test "sub-objects (branding, payouts, etc.) remain as plain maps — NOT converted to structs" do
      result = Settings.from_map(%{
        "branding" => %{"icon" => nil, "primary_color" => "#ff0000"},
        "payouts" => %{"schedule" => %{"interval" => "daily"}}
      })

      assert is_map(result.branding)
      assert is_map(result.payouts)
      refute is_struct(result.branding)
      refute is_struct(result.payouts)
    end

    test "D-01 depth cap regression: settings.payouts is a map, not a struct" do
      result = AccountFixtures.basic()["settings"] |> Settings.from_map()

      assert is_map(result.payouts)
      refute is_struct(result.payouts)
      assert result.payouts["schedule"]["interval"] == "daily"
    end

    test "unknown top-level sub-objects land in :extra" do
      result = Settings.from_map(%{"dashboard" => %{"display_name" => "Test"}, "zzz_new_setting" => %{"value" => true}})

      assert is_map(result.dashboard)
      assert result.extra == %{"zzz_new_setting" => %{"value" => true}}
    end

    test "full fixture round-trip: all known sub-objects populated as plain maps" do
      result = AccountFixtures.basic()["settings"] |> Settings.from_map()

      assert %Settings{} = result
      assert is_map(result.branding)
      assert is_map(result.card_payments)
      assert is_map(result.dashboard)
      assert is_map(result.payments)
      assert is_map(result.payouts)
      assert result.extra == %{}
    end
  end
end
