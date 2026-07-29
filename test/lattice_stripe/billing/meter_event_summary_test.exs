defmodule LatticeStripe.Billing.MeterEventSummaryTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.Billing.MeterEventSummary
  alias LatticeStripe.Testing.Fixtures.MeterEventSummary, as: MeterEventSummaryFixture

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

        ok_response(MeterEventSummaryFixture.list_response())
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

        ok_response(MeterEventSummaryFixture.list_response())
      end)

      assert {:ok, %LatticeStripe.Response{}} =
               MeterEventSummary.list(test_client(), @meter_id, @window)
    end

    # The timestamps here are 00:00 UTC (86_400 * 20_297 and * 20_298) rather than
    # @window's merely minute-aligned pair, because a "day" window with @window's
    # timestamps is exactly what GUARD-04 refuses to send.
    test "places value_grouping_window on the wire when supplied" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.url =~ "value_grouping_window=day"

        ok_response(MeterEventSummaryFixture.list_response())
      end)

      params = %{
        "customer" => "cus_1",
        "start_time" => 1_753_660_800,
        "end_time" => 1_753_747_200,
        "value_grouping_window" => "day"
      }

      assert {:ok, %LatticeStripe.Response{}} =
               MeterEventSummary.list(test_client(), @meter_id, params)
    end

    # MTR-01/empty edge. A meter with no usage in the window is the normal state of
    # a freshly-provisioned customer, not an error — and an empty page must decode to
    # `[]`, never `nil`, or every caller has to nil-guard a list.
    test "decodes an empty data array to an empty list, never nil" do
      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(MeterEventSummaryFixture.list_response([]))
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
        MeterEventSummaryFixture.basic(%{"id" => "mtrusg_a", "start_time" => 1_753_620_000}),
        MeterEventSummaryFixture.basic(%{"id" => "mtrusg_b", "start_time" => 1_753_706_400}),
        MeterEventSummaryFixture.basic(%{"id" => "mtrusg_c", "start_time" => 1_753_792_800})
      ]

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(MeterEventSummaryFixture.list_response(items))
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
             } = MeterEventSummary.from_map(MeterEventSummaryFixture.basic())
    end

    # F-05: `aggregated_value` is a JSON number. Rounding or coercing it to an
    # integer here would silently change a bill.
    test "keeps aggregated_value a float — never rounded, never coerced" do
      summary = MeterEventSummary.from_map(MeterEventSummaryFixture.basic())

      assert is_float(summary.aggregated_value)
      assert summary.aggregated_value == 42.5
    end

    test "returns nil for nil" do
      assert MeterEventSummary.from_map(nil) == nil
    end

    # D-07 idempotency clause.
    test "is idempotent — an already-decoded struct passes through unchanged" do
      once = MeterEventSummary.from_map(MeterEventSummaryFixture.basic())

      assert MeterEventSummary.from_map(once) == once
    end

    test "captures unrecognised wire keys in :extra rather than dropping them" do
      summary =
        MeterEventSummary.from_map(
          MeterEventSummaryFixture.basic(%{"refreshed_at" => "2026-07-28T00:00:00Z"})
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
        ok_response(MeterEventSummaryFixture.list_response())
      end)

      params = %{"customer" => "", "start_time" => nil, "end_time" => nil}

      assert {:ok, %LatticeStripe.Response{}} =
               MeterEventSummary.list(test_client(), @meter_id, params)
    end

    # D-08's second message set. The arity in the message must name the function
    # the caller actually invoked — a `stream!/4` call that reports `list/4` sends
    # the reader to the wrong doc page.
    #
    # Every test below calls `stream!/4` WITHOUT consuming the returned stream.
    # That is the assertion: `Stream.resource/3` defers its start function, so a
    # guard placed anywhere but first would not raise until the first `Enum` step,
    # far from the call site. No Mox expectation is set, so `verify_on_exit!` also
    # proves nothing reached the transport.
    test "stream!/4 raises on a nil meter id at call time, before any Enum step" do
      assert_raise ArgumentError,
                   "LatticeStripe.Billing.MeterEventSummary.stream!/4 requires a non-empty meter id",
                   fn -> MeterEventSummary.stream!(test_client(), nil, @window) end
    end

    test "stream!/4 raises on an empty-string meter id at call time" do
      assert_raise ArgumentError,
                   "LatticeStripe.Billing.MeterEventSummary.stream!/4 requires a non-empty meter id",
                   fn -> MeterEventSummary.stream!(test_client(), "", @window) end
    end

    test "stream!/4 raises when customer is missing, at call time" do
      assert_raise ArgumentError,
                   "LatticeStripe.Billing.MeterEventSummary.stream!/4 requires a customer param",
                   fn -> MeterEventSummary.stream!(test_client(), @meter_id, %{}) end
    end

    test "stream!/4 raises when start_time is missing" do
      assert_raise ArgumentError,
                   "LatticeStripe.Billing.MeterEventSummary.stream!/4 requires a start_time param",
                   fn ->
                     MeterEventSummary.stream!(
                       test_client(),
                       @meter_id,
                       Map.delete(@window, "start_time")
                     )
                   end
    end

    test "stream!/4 raises when end_time is missing" do
      assert_raise ArgumentError,
                   "LatticeStripe.Billing.MeterEventSummary.stream!/4 requires an end_time param",
                   fn ->
                     MeterEventSummary.stream!(
                       test_client(),
                       @meter_id,
                       Map.delete(@window, "end_time")
                     )
                   end
    end
  end

  # ---------------------------------------------------------------------------
  # MTR-01 — list!/4
  # ---------------------------------------------------------------------------

  describe "MeterEventSummary.list!/4" do
    test "returns the %Response{} directly rather than an {:ok, _} tuple" do
      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(MeterEventSummaryFixture.list_response())
      end)

      assert %LatticeStripe.Response{data: %LatticeStripe.List{} = list} =
               MeterEventSummary.list!(test_client(), @meter_id, @window)

      assert [%MeterEventSummary{id: "mtrusg_123"}] = list.data
    end

    test "raises LatticeStripe.Error when Stripe rejects the call" do
      expect(LatticeStripe.MockTransport, :request, fn _req -> error_response() end)

      assert_raise LatticeStripe.Error, fn ->
        MeterEventSummary.list!(test_client(), @meter_id, @window)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # MTR-02 — stream!/4
  #
  # Multi-page cursor behaviour is proven separately against the transport; this
  # block proves only that the delegation is wired and yields decoded structs.
  # ---------------------------------------------------------------------------

  describe "MeterEventSummary.stream!/4" do
    test "yields decoded %MeterEventSummary{} structs across a single page" do
      items = [
        MeterEventSummaryFixture.basic(%{"id" => "mtrusg_a"}),
        MeterEventSummaryFixture.basic(%{"id" => "mtrusg_b"})
      ]

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/billing/meters/mtr_123/event_summaries"

        ok_response(MeterEventSummaryFixture.list_response(items))
      end)

      summaries =
        test_client()
        |> MeterEventSummary.stream!(@meter_id, @window)
        |> Enum.to_list()

      assert [%MeterEventSummary{id: "mtrusg_a"}, %MeterEventSummary{id: "mtrusg_b"}] = summaries
    end
  end

  # ---------------------------------------------------------------------------
  # D-31 — structural surface lock. With no Dialyzer and documentation-only
  # typespecs, `refute function_exported?` is the ONLY enforcement of public
  # surface shape in this project.
  # ---------------------------------------------------------------------------

  describe "module surface" do
    # F-04: there is exactly one path, `GET /v1/billing/meters/:id/event_summaries`.
    # Stripe serves no get-by-summary-id route, so there is nothing to retrieve.
    test "does not export retrieve — Stripe serves no GET /{summary_id}" do
      refute function_exported?(MeterEventSummary, :retrieve, 2)
      refute function_exported?(MeterEventSummary, :retrieve, 3)
    end

    test "does not export write verbs — the endpoint is GET only" do
      refute function_exported?(MeterEventSummary, :create, 2)
      refute function_exported?(MeterEventSummary, :create, 3)
      refute function_exported?(MeterEventSummary, :update, 3)
      refute function_exported?(MeterEventSummary, :update, 4)
      refute function_exported?(MeterEventSummary, :delete, 2)
      refute function_exported?(MeterEventSummary, :delete, 3)
    end

    # Refuted at 1, 2 AND 3, not at the top arity alone: with two defaulted
    # arguments a lower arity would otherwise slip through unnoticed (Phase 63
    # STATE [63-02]).
    test "stream! has no non-bang twin — auto-pagination raises, it does not return tuples" do
      refute function_exported?(MeterEventSummary, :stream, 1)
      refute function_exported?(MeterEventSummary, :stream, 2)
      refute function_exported?(MeterEventSummary, :stream, 3)
    end

    # Encodes the D-10 rejection structurally. This library will not choose floor
    # versus ceil for the caller, because that choice changes which usage the
    # window includes — a business decision, not a formatting one.
    test "does not export a window-aligning helper" do
      refute function_exported?(MeterEventSummary, :align_window, 2)
    end

    # These arities exist via default arguments, and refuting any of them would be
    # incorrect — the shipped surface is genuinely `list/2..4`, `list!/2..4` and
    # `stream!/2..4` (D-31's explicit warning).
    test "exports the shipped read surface at every defaulted arity" do
      assert function_exported?(MeterEventSummary, :list, 2)
      assert function_exported?(MeterEventSummary, :list, 3)
      assert function_exported?(MeterEventSummary, :list, 4)
      assert function_exported?(MeterEventSummary, :list!, 2)
      assert function_exported?(MeterEventSummary, :list!, 3)
      assert function_exported?(MeterEventSummary, :list!, 4)
      assert function_exported?(MeterEventSummary, :stream!, 2)
      assert function_exported?(MeterEventSummary, :stream!, 3)
      assert function_exported?(MeterEventSummary, :stream!, 4)
      assert function_exported?(MeterEventSummary, :from_map, 1)
    end
  end
end
