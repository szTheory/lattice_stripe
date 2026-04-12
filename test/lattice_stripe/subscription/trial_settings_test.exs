defmodule LatticeStripe.Subscription.TrialSettingsTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Subscription.TrialSettings

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert TrialSettings.from_map(nil) == nil
    end

    test "decodes end_behavior as a plain map" do
      ts =
        TrialSettings.from_map(%{
          "end_behavior" => %{"missing_payment_method" => "cancel"}
        })

      assert ts.end_behavior == %{"missing_payment_method" => "cancel"}
      assert ts.extra == %{}
    end

    test "collects unknown fields into :extra" do
      ts =
        TrialSettings.from_map(%{
          "end_behavior" => %{"missing_payment_method" => "pause"},
          "future_field" => true
        })

      assert ts.end_behavior == %{"missing_payment_method" => "pause"}
      assert ts.extra == %{"future_field" => true}
    end
  end

  describe "Inspect" do
    test "renders a compact #LatticeStripe.Subscription.TrialSettings<...> line" do
      ts = TrialSettings.from_map(%{"end_behavior" => %{"missing_payment_method" => "cancel"}})
      inspected = inspect(ts)

      assert inspected =~ "#LatticeStripe.Subscription.TrialSettings<"
      assert inspected =~ "end_behavior:"
      assert inspected =~ "missing_payment_method"
    end
  end
end
