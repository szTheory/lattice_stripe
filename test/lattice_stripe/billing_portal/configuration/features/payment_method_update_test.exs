defmodule LatticeStripe.BillingPortal.Configuration.Features.PaymentMethodUpdateTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.BillingPortal.Configuration.Features.PaymentMethodUpdate

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert PaymentMethodUpdate.from_map(nil) == nil
    end

    test "decodes all known fields correctly" do
      map = %{
        "enabled" => false,
        "payment_method_configuration" => nil
      }

      result = PaymentMethodUpdate.from_map(map)
      assert result.enabled == false
      assert result.payment_method_configuration == nil
    end

    test "decodes payment_method_configuration ID" do
      map = %{
        "enabled" => true,
        "payment_method_configuration" => "pmc_123"
      }

      result = PaymentMethodUpdate.from_map(map)
      assert result.enabled == true
      assert result.payment_method_configuration == "pmc_123"
    end

    test "captures unknown keys in extra" do
      map = %{
        "enabled" => true,
        "payment_method_configuration" => nil,
        "future_field" => "future_value"
      }

      result = PaymentMethodUpdate.from_map(map)
      assert result.extra == %{"future_field" => "future_value"}
    end

    test "returns empty extra when no unknown keys" do
      map = %{
        "enabled" => false,
        "payment_method_configuration" => nil
      }

      result = PaymentMethodUpdate.from_map(map)
      assert result.extra == %{}
    end

    test "handles nil field values gracefully" do
      map = %{
        "enabled" => nil,
        "payment_method_configuration" => nil
      }

      result = PaymentMethodUpdate.from_map(map)
      assert result.enabled == nil
      assert result.payment_method_configuration == nil
    end
  end
end
