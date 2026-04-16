defmodule LatticeStripe.BillingPortal.Configuration.Features.CustomerUpdateTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.BillingPortal.Configuration.Features.CustomerUpdate

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert CustomerUpdate.from_map(nil) == nil
    end

    test "decodes all known fields correctly" do
      map = %{
        "allowed_updates" => [],
        "enabled" => false
      }

      result = CustomerUpdate.from_map(map)
      assert result.allowed_updates == []
      assert result.enabled == false
    end

    test "decodes allowed_updates list" do
      map = %{
        "allowed_updates" => ["email", "address", "shipping", "phone", "tax_id"],
        "enabled" => true
      }

      result = CustomerUpdate.from_map(map)
      assert result.allowed_updates == ["email", "address", "shipping", "phone", "tax_id"]
      assert result.enabled == true
    end

    test "captures unknown keys in extra" do
      map = %{
        "allowed_updates" => ["email"],
        "enabled" => true,
        "future_field" => "future_value"
      }

      result = CustomerUpdate.from_map(map)
      assert result.extra == %{"future_field" => "future_value"}
    end

    test "returns empty extra when no unknown keys" do
      map = %{
        "allowed_updates" => [],
        "enabled" => false
      }

      result = CustomerUpdate.from_map(map)
      assert result.extra == %{}
    end

    test "handles nil field values gracefully" do
      map = %{
        "allowed_updates" => nil,
        "enabled" => nil
      }

      result = CustomerUpdate.from_map(map)
      assert result.allowed_updates == nil
      assert result.enabled == nil
    end
  end
end
