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

  # ---------------------------------------------------------------------------
  # GUARD-04 — check_summary_window!/2 alignment matrix (CONTEXT D-10)
  #
  # Stripe requires minute-aligned start_time/end_time on EVERY query, UTC-hour
  # alignment when value_grouping_window is "hour", and UTC-day alignment (00:00
  # UTC) when it is "day". Its error code for a violation is undocumented, so the
  # resulting 400 cannot be improved after the fact — only prevented.
  # ---------------------------------------------------------------------------

  # 60 * 29_227_000 and 60 * 29_228_440. Minute-aligned and deliberately NOT hour-
  # or day-aligned, so the hour and day cases below have something to catch.
  @minute_start 1_753_620_000
  @minute_end 1_753_706_400

  # 3_600 * 487_116 and 3_600 * 487_140. Hour-aligned, not day-aligned.
  @hour_start 1_753_617_600
  @hour_end 1_753_704_000

  # 86_400 * 20_297 and 86_400 * 20_298 — 00:00 UTC, so aligned for every divisor.
  @day_start 1_753_660_800
  @day_end 1_753_747_200

  describe "check_summary_window!/2 — GUARD-04 alignment matrix from CONTEXT D-10" do
    test "1. no window + minute-aligned timestamps → :ok" do
      assert :ok =
               Guards.check_summary_window!(
                 %{"start_time" => @minute_start, "end_time" => @minute_end},
                 "list/4"
               )
    end

    test "2. no window + start_time one second past a minute boundary → ArgumentError" do
      err =
        assert_raise ArgumentError, fn ->
          Guards.check_summary_window!(
            %{"start_time" => @minute_start + 1, "end_time" => @minute_end},
            "list/4"
          )
        end

      assert err.message =~ "start_time #{@minute_start + 1}"
      assert err.message =~ "minute boundary"
    end

    test "3. no window + end_time one second before a minute boundary → ArgumentError" do
      err =
        assert_raise ArgumentError, fn ->
          Guards.check_summary_window!(
            %{"start_time" => @minute_start, "end_time" => @minute_end - 1},
            "list/4"
          )
        end

      assert err.message =~ "end_time #{@minute_end - 1}"
    end

    test "4. hour window + hour-aligned timestamps → :ok" do
      assert :ok =
               Guards.check_summary_window!(
                 %{
                   "value_grouping_window" => "hour",
                   "start_time" => @hour_start,
                   "end_time" => @hour_end
                 },
                 "list/4"
               )
    end

    test "5. hour window + minute-aligned but not hour-aligned → ArgumentError" do
      err =
        assert_raise ArgumentError, fn ->
          Guards.check_summary_window!(
            %{
              "value_grouping_window" => "hour",
              "start_time" => @minute_start,
              "end_time" => @hour_end
            },
            "list/4"
          )
        end

      assert err.message =~ "UTC hour boundary"
      assert err.message =~ "3600"
    end

    test "6. day window + day-aligned timestamps → :ok" do
      assert :ok =
               Guards.check_summary_window!(
                 %{
                   "value_grouping_window" => "day",
                   "start_time" => @day_start,
                   "end_time" => @day_end
                 },
                 "list/4"
               )
    end

    test "7. day window + hour-aligned but not day-aligned → ArgumentError" do
      err =
        assert_raise ArgumentError, fn ->
          Guards.check_summary_window!(
            %{
              "value_grouping_window" => "day",
              "start_time" => @hour_start,
              "end_time" => @day_end
            },
            "list/4"
          )
        end

      assert err.message =~ "UTC day boundary (00:00 UTC)"
      assert err.message =~ "86400"
    end

    test "8a. the exact boundary passes for every divisor, on both keys" do
      for window <- [nil, "hour", "day"], key <- ["start_time", "end_time"] do
        assert :ok =
                 Guards.check_summary_window!(window_params(window, key, @day_start), "list/4")
      end
    end

    test "8b. boundary ±1 second raises for every divisor, on both keys" do
      for window <- [nil, "hour", "day"], key <- ["start_time", "end_time"], offset <- [1, -1] do
        assert_raise ArgumentError, fn ->
          Guards.check_summary_window!(window_params(window, key, @day_start + offset), "list/4")
        end
      end
    end

    # MANDATORY forward-compatibility hatch. Stripe extended this enum once
    # already (it gained "day" in mid-2024); a guard that rejected unknown values
    # would break every caller on the day Stripe extends it again. Asserted rather
    # than assumed, because it is a deliberate design property and not an accident
    # of control flow.
    test "9. an unrecognised window value passes through unguarded, however misaligned" do
      assert :ok =
               Guards.check_summary_window!(
                 %{
                   "value_grouping_window" => "week",
                   "start_time" => 1,
                   "end_time" => 2
                 },
                 "list/4"
               )
    end

    # MANDATORY division-of-responsibility hatch: require_param!/3 owns absence.
    test "10. an absent timestamp passes through unguarded" do
      assert :ok = Guards.check_summary_window!(%{"end_time" => @minute_end}, "list/4")
      assert :ok = Guards.check_summary_window!(%{"start_time" => @minute_start}, "list/4")
      assert :ok = Guards.check_summary_window!(%{}, "list/4")
    end

    # ...and Stripe's own type validation owns the wrong type.
    test "11. an unparseable timestamp passes through unguarded" do
      for value <- ["1753620001", 1_753_620_001.5, nil] do
        assert :ok =
                 Guards.check_summary_window!(
                   %{"start_time" => value, "end_time" => value},
                   "list/4"
                 )
      end
    end

    test "12. a non-map argument passes through unguarded" do
      assert :ok = Guards.check_summary_window!(:not_a_map, "list/4")
      assert :ok = Guards.check_summary_window!(nil, "list/4")
    end

    test "13. the message names the value, the rule, the cause, and both expressions" do
      err =
        assert_raise ArgumentError, fn ->
          Guards.check_summary_window!(
            %{
              "value_grouping_window" => "day",
              "start_time" => @day_start + 37,
              "end_time" => @day_end
            },
            "list/4"
          )
        end

      assert err.message =~ "LatticeStripe.Billing.MeterEventSummary.list/4"
      assert err.message =~ "start_time #{@day_start + 37}"
      assert err.message =~ "UTC day boundary (00:00 UTC)"
      assert err.message =~ "HTTP 400"
      assert err.message =~ "billing_cycle_anchor"
      assert err.message =~ "Integer.floor_div(start_time, 86400) * 86400"
      assert err.message =~ "-Integer.floor_div(-end_time, 86400) * 86400"
      assert err.message =~ "floor"
      assert err.message =~ "ceil"
    end

    # D-08's two message sets, from one arity-2 helper: the second argument carries
    # the caller's own fun/arity spelling.
    test "14. the message names whichever function the caller invoked" do
      err =
        assert_raise ArgumentError, fn ->
          Guards.check_summary_window!(
            %{"start_time" => @minute_start + 1, "end_time" => @minute_end},
            "stream!/4"
          )
        end

      assert err.message =~ "LatticeStripe.Billing.MeterEventSummary.stream!/4"
      refute err.message =~ "list/4"
    end

    test "15. first failure wins: both misaligned reports start_time" do
      err =
        assert_raise ArgumentError, fn ->
          Guards.check_summary_window!(
            %{"start_time" => @minute_start + 1, "end_time" => @minute_end + 1},
            "list/4"
          )
        end

      assert err.message =~ "start_time"
      refute err.message =~ "end_time #{@minute_end + 1}"
    end

    # D-10/D-11 refute set. No Dialyzer here, so `refute function_exported?` is the
    # only enforcement that no snapping helper was quietly added alongside the guard.
    test "16. the guard exists at arity 2 and no aligning helper exists at any arity" do
      Code.ensure_loaded!(Guards)

      assert function_exported?(Guards, :check_summary_window!, 2)

      refute function_exported?(Guards, :align_window, 1)
      refute function_exported?(Guards, :align_window, 2)
      refute function_exported?(Guards, :check_summary_window!, 1)
    end
  end

  # Builds a params map in which only `key` carries the value under test; the other
  # timestamp is 00:00 UTC and therefore aligned for every divisor.
  defp window_params(window, key, value) do
    %{"start_time" => @day_start, "end_time" => @day_end}
    |> Map.put(key, value)
    |> put_window(window)
  end

  defp put_window(params, nil), do: params
  defp put_window(params, window), do: Map.put(params, "value_grouping_window", window)
end
