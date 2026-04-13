defmodule LatticeStripe.Account.BusinessProfileTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Account.BusinessProfile
  alias LatticeStripe.Test.Fixtures.Account, as: AccountFixtures

  describe "from_map/1" do
    test "returns nil for nil input" do
      assert BusinessProfile.from_map(nil) == nil
    end

    test "returns struct with all known fields nil and extra: %{} for empty map" do
      result = BusinessProfile.from_map(%{})

      assert %BusinessProfile{} = result
      assert result.mcc == nil
      assert result.name == nil
      assert result.url == nil
      assert result.support_email == nil
      assert result.extra == %{}
    end

    test "casts known fields from string-keyed map" do
      result = BusinessProfile.from_map(%{"name" => "Acme", "url" => "https://acme.test"})

      assert result.name == "Acme"
      assert result.url == "https://acme.test"
      assert result.extra == %{}
    end

    test "puts unknown fields into :extra" do
      result = BusinessProfile.from_map(%{"name" => "Acme", "zzz_unknown" => "keepme"})

      assert result.name == "Acme"
      assert result.extra == %{"zzz_unknown" => "keepme"}
    end

    test "full fixture round-trip: known fields populated and zzz_forward_compat_field in :extra" do
      bp_map = AccountFixtures.basic()["business_profile"]
      result = BusinessProfile.from_map(bp_map)

      assert %BusinessProfile{} = result
      assert result.name == "Acme Corp"
      assert result.support_email == "support@acme.test"
      assert result.url == "https://acme.test"
      assert result.mcc == "5734"
      assert Map.has_key?(result.extra, "zzz_forward_compat_field")
      assert result.extra["zzz_forward_compat_field"] == "extra_value_in_business_profile"
    end

    test "support_phone and support_url are cast correctly" do
      result = BusinessProfile.from_map(%{
        "support_phone" => "+15555550100",
        "support_url" => "https://support.acme.test"
      })

      assert result.support_phone == "+15555550100"
      assert result.support_url == "https://support.acme.test"
    end

    test "monthly_estimated_revenue is cast as map (nested object)" do
      result = BusinessProfile.from_map(%{
        "monthly_estimated_revenue" => %{"amount" => 10_000, "currency" => "usd"}
      })

      assert result.monthly_estimated_revenue == %{"amount" => 10_000, "currency" => "usd"}
    end
  end
end
