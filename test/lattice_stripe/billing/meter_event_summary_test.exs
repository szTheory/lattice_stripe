defmodule LatticeStripe.Billing.MeterEventSummaryTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.Billing.MeterEventSummary
  alias LatticeStripe.Test.Fixtures.Metering

  setup :verify_on_exit!

  @meter_id "mtr_123"

  # The three filters Stripe marks `required: true` (F-03). Every happy-path call
  # below carries all three, because a call missing any of them never reaches the
  # transport at all — see the "pre-network guards" block.
  @window %{
    "customer" => "cus_1",
    "start_time" => 1_753_620_000,
    "end_time" => 1_753_706_400
  }

  # ---------------------------------------------------------------------------
  # MTR-01 — list/4
  # ---------------------------------------------------------------------------

  describe "MeterEventSummary.list/4" do
    test "GETs the parent-scoped /v1/billing/meters/:id/event_summaries path" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/billing/meters/mtr_123/event_summaries"

        ok_response(Metering.MeterEventSummary.list_response())
      end)

      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{} = list}} =
               MeterEventSummary.list(test_client(), @meter_id, @window)

      assert [%MeterEventSummary{id: "mtrusg_123"}] = list.data
    end

    test "places customer, start_time and end_time on the wire as query params" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "customer=cus_1"
        assert req.url =~ "start_time=1753620000"
        assert req.url =~ "end_time=1753706400"

        ok_response(Metering.MeterEventSummary.list_response())
      end)

      assert {:ok, %LatticeStripe.Response{}} =
               MeterEventSummary.list(test_client(), @meter_id, @window)
    end

    test "places value_grouping_window on the wire when supplied" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "value_grouping_window=day"

        ok_response(Metering.MeterEventSummary.list_response())
      end)

      params = Map.put(@window, "value_grouping_window", "day")

      assert {:ok, %LatticeStripe.Response{}} =
               MeterEventSummary.list(test_client(), @meter_id, params)
    end

    # MTR-01/empty edge. A meter with no usage in the window is the normal state of
    # a freshly-provisioned customer, not an error — and an empty page must decode to
    # `[]`, never `nil`, or every caller has to nil-guard a list.
    test "decodes an empty data array to an empty list, never nil" do
      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Metering.MeterEventSummary.list_response([]))
      end)

      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{} = list}} =
               MeterEventSummary.list(test_client(), @meter_id, @window)

      assert list.data == []
      assert list.has_more == false
    end

    # MTR-01/ordering edge. Summaries are a time series; re-sorting or de-duplicating
    # them client-side would silently reorder a chart's buckets.
    test "preserves Stripe's wire ordering exactly" do
      items = [
        Metering.MeterEventSummary.basic(%{"id" => "mtrusg_a", "start_time" => 1_753_620_000}),
        Metering.MeterEventSummary.basic(%{"id" => "mtrusg_b", "start_time" => 1_753_706_400}),
        Metering.MeterEventSummary.basic(%{"id" => "mtrusg_c", "start_time" => 1_753_792_800})
      ]

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Metering.MeterEventSummary.list_response(items))
      end)

      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{} = list}} =
               MeterEventSummary.list(test_client(), @meter_id, @window)

      assert Enum.map(list.data, & &1.id) == ["mtrusg_a", "mtrusg_b", "mtrusg_c"]
    end
  end

  # ---------------------------------------------------------------------------
  # MTR-01 — from_map/1 (decode)
  # ---------------------------------------------------------------------------

  describe "MeterEventSummary.from_map/1" do
    test "populates all seven wire fields" do
      assert %MeterEventSummary{
               id: "mtrusg_123",
               object: "billing.meter_event_summary",
               start_time: 1_753_620_000,
               end_time: 1_753_706_400,
               meter: "mtr_123",
               livemode: false
             } = MeterEventSummary.from_map(Metering.MeterEventSummary.basic())
    end

    # F-05: `aggregated_value` is a JSON number. Rounding or coercing it to an
    # integer here would silently change a bill.
    test "keeps aggregated_value a float — never rounded, never coerced" do
      summary = MeterEventSummary.from_map(Metering.MeterEventSummary.basic())

      assert is_float(summary.aggregated_value)
      assert summary.aggregated_value == 42.5
    end

    test "returns nil for nil" do
      assert MeterEventSummary.from_map(nil) == nil
    end

    # D-07 idempotency clause.
    test "is idempotent — an already-decoded struct passes through unchanged" do
      once = MeterEventSummary.from_map(Metering.MeterEventSummary.basic())

      assert MeterEventSummary.from_map(once) == once
    end

    test "captures unrecognised wire keys in :extra rather than dropping them" do
      summary =
        MeterEventSummary.from_map(
          Metering.MeterEventSummary.basic(%{"refreshed_at" => "2026-07-28T00:00:00Z"})
        )

      assert summary.extra == %{"refreshed_at" => "2026-07-28T00:00:00Z"}
      refute Map.has_key?(Map.from_struct(summary), :refreshed_at)
    end
  end

  # ---------------------------------------------------------------------------
  # F-02 — the deliberate absence, encoded as design rather than accident
  # ---------------------------------------------------------------------------

  describe "struct shape" do
    test "has no :customer key — the customer is an input, never an output" do
      refute Map.has_key?(%MeterEventSummary{}, :customer)
    end
  end

  # ---------------------------------------------------------------------------
  # D-08 / D-09 — every guard fires BEFORE any transport call.
  #
  # No Mox expectation is set anywhere in this block. `verify_on_exit!` therefore
  # proves each raise happened pre-network: had the request escaped, MockTransport
  # would have raised "no expectation defined" instead of the ArgumentError asserted.
  # ---------------------------------------------------------------------------

  describe "pre-network guards" do
    test "list/4 raises on a nil meter id" do
      assert_raise ArgumentError,
                   "LatticeStripe.Billing.MeterEventSummary.list/4 requires a non-empty meter id",
                   fn -> MeterEventSummary.list(test_client(), nil, @window) end
    end

    test "list/4 raises on an empty-string meter id" do
      assert_raise ArgumentError,
                   "LatticeStripe.Billing.MeterEventSummary.list/4 requires a non-empty meter id",
                   fn -> MeterEventSummary.list(test_client(), "", @window) end
    end

    test "list/4 raises when customer is missing" do
      assert_raise ArgumentError,
                   "LatticeStripe.Billing.MeterEventSummary.list/4 requires a customer param",
                   fn ->
                     MeterEventSummary.list(
                       test_client(),
                       @meter_id,
                       Map.delete(@window, "customer")
                     )
                   end
    end

    test "list/4 raises when start_time is missing" do
      assert_raise ArgumentError,
                   "LatticeStripe.Billing.MeterEventSummary.list/4 requires a start_time param",
                   fn ->
                     MeterEventSummary.list(
                       test_client(),
                       @meter_id,
                       Map.delete(@window, "start_time")
                     )
                   end
    end

    # Note the article: `an end_time`, mirroring Billing.Meter.create/3's existing
    # "requires an event_name param". The D-10 message format is a verbatim lock.
    test "list/4 raises when end_time is missing" do
      assert_raise ArgumentError,
                   "LatticeStripe.Billing.MeterEventSummary.list/4 requires an end_time param",
                   fn ->
                     MeterEventSummary.list(
                       test_client(),
                       @meter_id,
                       Map.delete(@window, "end_time")
                     )
                   end
    end

    test "first failure wins: all three filters missing reports customer" do
      assert_raise ArgumentError,
                   "LatticeStripe.Billing.MeterEventSummary.list/4 requires a customer param",
                   fn -> MeterEventSummary.list(test_client(), @meter_id, %{}) end
    end

    test "first failure wins: the meter id is checked before any param" do
      assert_raise ArgumentError,
                   "LatticeStripe.Billing.MeterEventSummary.list/4 requires a non-empty meter id",
                   fn -> MeterEventSummary.list(test_client(), nil, %{}) end
    end

    # require_param!/3 checks key PRESENCE, not emptiness (resource.ex:118-124),
    # and reads string keys only. An atom-keyed params map bypasses the guard and
    # fails at Stripe instead.
    test "the param guards check presence, not emptiness" do
      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(Metering.MeterEventSummary.list_response())
      end)

      params = %{"customer" => "", "start_time" => nil, "end_time" => nil}

      assert {:ok, %LatticeStripe.Response{}} =
               MeterEventSummary.list(test_client(), @meter_id, params)
    end
  end
end
