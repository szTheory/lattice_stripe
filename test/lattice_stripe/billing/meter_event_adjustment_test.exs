defmodule LatticeStripe.Billing.MeterEventAdjustmentTest do
  use ExUnit.Case, async: true
  alias LatticeStripe.Billing.Guards
  alias LatticeStripe.Billing.MeterEventAdjustment
  alias LatticeStripe.Billing.MeterEventAdjustment.Cancel
  alias LatticeStripe.Test.Fixtures.Metering

  describe "from_map/1 round-trip (EVENT-04 / T-20-03 cancel.identifier shape)" do
    test "decodes nested cancel.identifier into %Cancel{identifier: ...}, NOT top-level" do
      m = Metering.MeterEventAdjustment.basic()
      adj = MeterEventAdjustment.from_map(m)

      # MUST be a nested Cancel struct, not top-level, not a raw map
      assert %MeterEventAdjustment{
               id: "mea_123",
               event_name: "api_call",
               cancel: %Cancel{identifier: "req_abc"}
             } = adj

      # Regression guards — T-20-03 shape trap
      refute Map.has_key?(adj, :identifier)
      refute is_map(adj.cancel) and not is_struct(adj.cancel, Cancel)
    end

    test "Cancel.from_map round-trips identifier string" do
      assert %Cancel{identifier: "req_xyz"} =
               Cancel.from_map(%{"identifier" => "req_xyz"})
    end

    test "Cancel.from_map(nil) returns nil" do
      assert Cancel.from_map(nil) == nil
    end

    test "Cancel struct has no :extra (minimal)" do
      refute Map.has_key?(%Cancel{}, :extra)
    end
  end

  describe "create/3 cancel shape guard (GUARD-03)" do
    setup do
      %{client: %LatticeStripe.Client{api_key: "sk_test_xxx", finch: :test_finch}}
    end

    test "raises ArgumentError when cancel missing", %{client: client} do
      assert_raise ArgumentError, ~r/cancel/, fn ->
        MeterEventAdjustment.create(client, %{"event_name" => "api_call"})
      end
    end

    test "raises ArgumentError when identifier put at top level (T-20-03 trap)", %{client: client} do
      assert_raise ArgumentError, ~r/cancel/, fn ->
        MeterEventAdjustment.create(client, %{
          "event_name" => "api_call",
          "identifier" => "req_abc"
        })
      end
    end

    test "raises ArgumentError when cancel.id used instead of cancel.identifier", %{
      client: client
    } do
      assert_raise ArgumentError, ~r/identifier/, fn ->
        MeterEventAdjustment.create(client, %{
          "event_name" => "api_call",
          "cancel" => %{"id" => "req_abc"}
        })
      end
    end

    test "raises ArgumentError when cancel.event_id used", %{client: client} do
      assert_raise ArgumentError, ~r/identifier/, fn ->
        MeterEventAdjustment.create(client, %{
          "event_name" => "api_call",
          "cancel" => %{"event_id" => "req_abc"}
        })
      end
    end
  end

  describe "Guards.check_adjustment_cancel_shape!/1" do
    test "accepts correct nested shape" do
      assert :ok =
               Guards.check_adjustment_cancel_shape!(%{
                 "cancel" => %{"identifier" => "req_abc"}
               })
    end

    test "rejects empty identifier" do
      assert_raise ArgumentError, fn ->
        Guards.check_adjustment_cancel_shape!(%{"cancel" => %{"identifier" => ""}})
      end
    end
  end
end
