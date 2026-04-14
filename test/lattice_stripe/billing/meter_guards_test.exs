defmodule LatticeStripe.Billing.MeterGuardsTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  alias LatticeStripe.Billing.Guards

  describe "check_meter_value_settings!/1 — 8-case matrix from CONTEXT D-01" do
    test "1. sum + no value_settings → :ok" do
      assert :ok =
               Guards.check_meter_value_settings!(%{
                 "default_aggregation" => %{"formula" => "sum"}
               })
    end

    test "2. sum + valid value_settings → :ok" do
      assert :ok =
               Guards.check_meter_value_settings!(%{
                 "default_aggregation" => %{"formula" => "sum"},
                 "value_settings" => %{"event_payload_key" => "tokens"}
               })
    end

    test "3. sum + empty map value_settings → ArgumentError" do
      assert_raise ArgumentError, ~r/value_settings\.event_payload_key/, fn ->
        Guards.check_meter_value_settings!(%{
          "default_aggregation" => %{"formula" => "sum"},
          "value_settings" => %{}
        })
      end
    end

    test "4. sum + empty string event_payload_key → ArgumentError" do
      assert_raise ArgumentError, ~r/value_settings\.event_payload_key/, fn ->
        Guards.check_meter_value_settings!(%{
          "default_aggregation" => %{"formula" => "sum"},
          "value_settings" => %{"event_payload_key" => ""}
        })
      end
    end

    test "5. last + nil event_payload_key → ArgumentError" do
      assert_raise ArgumentError, ~r/value_settings\.event_payload_key/, fn ->
        Guards.check_meter_value_settings!(%{
          "default_aggregation" => %{"formula" => "last"},
          "value_settings" => %{"event_payload_key" => nil}
        })
      end
    end

    test "6. count + value_settings → Logger.warning + :ok" do
      log =
        capture_log(fn ->
          assert :ok =
                   Guards.check_meter_value_settings!(%{
                     "default_aggregation" => %{"formula" => "count"},
                     "value_settings" => %{"event_payload_key" => "x"}
                   })
        end)

      assert log =~ "value_settings is ignored"
    end

    test "7. count + no value_settings → :ok silent" do
      log =
        capture_log(fn ->
          assert :ok =
                   Guards.check_meter_value_settings!(%{
                     "default_aggregation" => %{"formula" => "count"}
                   })
        end)

      refute log =~ "value_settings"
    end

    test "8. atom-keyed params bypass the guard (no-op)" do
      assert :ok =
               Guards.check_meter_value_settings!(%{
                 default_aggregation: %{formula: :sum}
               })
    end
  end
end
