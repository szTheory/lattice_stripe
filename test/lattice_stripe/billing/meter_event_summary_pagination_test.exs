defmodule LatticeStripe.Billing.MeterEventSummaryPaginationTest do
  @moduledoc """
  MTR-02 — the pagination contract for `MeterEventSummary.stream!/4` (D-30).

  This lives in its own file rather than folding into `meter_event_summary_test.exs`,
  because pagination is the one part of this module that stripe-mock cannot prove: it
  returns a single synthetic item and ignores both `limit` and `starting_after`, so a
  green integration suite says nothing at all about the page seam. Mox at the transport
  is the only place these facts are observable (F-10).

  Two of the assertions here are tenancy boundaries rather than convenience checks, and
  the stakes differ from Phase 63's entitlements stream in a way worth stating plainly.
  Because `customer`, `start_time` and `end_time` are all *required*, a **total** drop of
  the base params makes Stripe answer 400 — loudly. The real hazard is a **partial** drop,
  which leaks undetectably: the returned summaries carry no `customer` field (F-02), so
  nothing downstream can compare what came back against what was asked for.

  The cursor state machine itself belongs to `LatticeStripe.List`; nothing here re-grows it
  (Phase 63 D-05). These tests observe the requests that machine emits.
  """

  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.Billing.MeterEventSummary
  alias LatticeStripe.Test.Fixtures.Metering

  setup :verify_on_exit!

  @meter_id "mtr_123"
  @summaries_url "/v1/billing/meters/mtr_123/event_summaries"

  # The three filters Stripe marks required (F-03). Timestamps are UTC day boundaries
  # (1_753_574_400 = 20296 * 86_400), which is what `value_grouping_window: "day"`
  # requires — a misaligned window is a different bug, tested elsewhere.
  @window %{
    "customer" => "cus_1",
    "start_time" => 1_753_574_400,
    "end_time" => 1_753_660_800
  }

  # The bucketed form. `value_grouping_window` is OPTIONAL, which is exactly why it is
  # the dangerous one to lose across the seam: dropping it does not 400, it silently
  # flips page 2 from per-day rows to a single whole-range aggregate.
  @bucketed_window Map.put(@window, "value_grouping_window", "day")

  # ---------------------------------------------------------------------------
  # Test Helpers
  # ---------------------------------------------------------------------------

  # Raw transport tuple, modelled on test/lattice_stripe/list_test.exs:26-45. The envelope
  # comes from `TestHelpers.list_json/3` rather than hand-built JSON — its third argument
  # exists for exactly this kind of test (Phase 63 D-28).
  defp summaries_response(items, has_more, url \\ @summaries_url) do
    {:ok,
     %{
       status: 200,
       headers: [{"request-id", "req_#{System.unique_integer([:positive])}"}],
       body: Jason.encode!(list_json(items, url, has_more))
     }}
  end

  defp server_error_response(status) do
    {:ok,
     %{
       status: status,
       headers: [{"request-id", "req_err_#{System.unique_integer([:positive])}"}],
       body:
         Jason.encode!(%{
           "error" => %{"type" => "api_error", "message" => "Server error", "code" => nil}
         })
     }}
  end

  # Ids carry the real `mtrusg_` prefix because the prefix is load-bearing for the
  # cursor-derivation assertion below.
  defp summary(id, overrides \\ %{}) do
    Metering.MeterEventSummary.basic(Map.merge(%{"id" => id}, overrides))
  end

  defp query_params(%{url: url}) do
    case URI.parse(url).query do
      nil -> %{}
      query -> URI.decode_query(query)
    end
  end

  defp request_path(%{url: url}), do: URI.parse(url).path

  # ---------------------------------------------------------------------------
  # MTR-02 — cursor derivation across the page seam (D-30 assertions 1, 7, 9)
  # ---------------------------------------------------------------------------

  describe "stream!/4 cursor derivation across the page seam" do
    test "page 2 request uses starting_after from the LAST id of page 1" do
      LatticeStripe.MockTransport
      |> expect(:request, fn req ->
        refute Map.has_key?(query_params(req), "starting_after")
        summaries_response([summary("mtrusg_a"), summary("mtrusg_b")], true)
      end)
      |> expect(:request, fn req ->
        # The seam is adjacent: the cursor is the LAST id of page 1, not the first, so
        # mtrusg_b is emitted exactly once and mtrusg_a is never re-fetched.
        assert query_params(req)["starting_after"] == "mtrusg_b"
        summaries_response([summary("mtrusg_c")], false)
      end)

      ids =
        test_client()
        |> MeterEventSummary.stream!(@meter_id, @window)
        |> Enum.map(& &1.id)

      assert ids == ["mtrusg_a", "mtrusg_b", "mtrusg_c"]
    end

    # D-30 assertion 9 / T-64-14 — MUTATION-CHECKED. Do not rename, do not fold into the
    # test above, and do not weaken to `refute cursor == nil`.
    #
    # `LatticeStripe.List` derives `_last_id` by matching a RAW map on the string key
    # "id". Type the page before that derivation runs and the match falls through to nil:
    # the next request goes out with no cursor at all, so pagination re-reads page 1 or
    # stops early, and NOTHING raises. Asserting the `mtrusg_` prefix rather than mere
    # non-nilness is what distinguishes a correctly-derived cursor from a wrong one.
    #
    # Phase 63 mutation-checked this identical failure on the entitlements summary
    # (STATE [63-04]): moving the typing step ahead of `List.from_json/3` failed exactly
    # one named test. Verified again here — see 64-06-SUMMARY.md.
    test "the starting_after cursor is derived from the raw maps before typing" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        summaries_response([summary("mtrusg_a"), summary("mtrusg_b")], true)
      end)
      |> expect(:request, fn req ->
        cursor = query_params(req)["starting_after"]

        assert is_binary(cursor)
        assert String.starts_with?(cursor, "mtrusg_")
        assert cursor == "mtrusg_b"

        summaries_response([summary("mtrusg_c")], false)
      end)

      summaries =
        test_client()
        |> MeterEventSummary.stream!(@meter_id, @window)
        |> Enum.to_list()

      assert length(summaries) == 3
    end

    # D-30 assertion 7. The page-1 body advertises a DIFFERENT path than the one the
    # resource module would reconstruct, so a page-2 request built from `path(meter_id)`
    # instead of the response's `url` fails here and only here.
    test "page 2 request path is taken from the page-1 response url, not rebuilt" do
      served_url = "/v1/billing/meters/mtr_served_by_stripe/event_summaries"

      LatticeStripe.MockTransport
      |> expect(:request, fn req ->
        assert request_path(req) == @summaries_url
        summaries_response([summary("mtrusg_a")], true, served_url)
      end)
      |> expect(:request, fn req ->
        assert request_path(req) == served_url
        summaries_response([summary("mtrusg_b")], false, served_url)
      end)

      summaries =
        test_client()
        |> MeterEventSummary.stream!(@meter_id, @window)
        |> Enum.to_list()

      assert length(summaries) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # MTR-02 — completeness, call counts, laziness and ordering
  # (D-30 assertions 3 and 4, plus the MTR-01 ordering edge)
  # ---------------------------------------------------------------------------

  describe "stream!/4 enumeration, call counts and laziness" do
    test "a two-page response yields every item from both pages as typed structs" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req ->
        summaries_response([summary("mtrusg_a"), summary("mtrusg_b")], true)
      end)
      |> expect(:request, fn _req -> summaries_response([summary("mtrusg_c")], false) end)

      summaries =
        test_client()
        |> MeterEventSummary.stream!(@meter_id, @bucketed_window)
        |> Enum.to_list()

      assert [
               %MeterEventSummary{id: "mtrusg_a"},
               %MeterEventSummary{id: "mtrusg_b"},
               %MeterEventSummary{id: "mtrusg_c"}
             ] = summaries
    end

    # D-30 assertion 3. `verify_on_exit!` is the call counter — three `expect/3`s and no
    # separate tally. A fourth call fails as "no expectation defined"; a missing third
    # fails on exit.
    test "streaming N pages makes exactly N transport calls" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req -> summaries_response([summary("mtrusg_a")], true) end)
      |> expect(:request, fn _req -> summaries_response([summary("mtrusg_b")], true) end)
      |> expect(:request, fn _req -> summaries_response([summary("mtrusg_c")], false) end)

      summaries =
        test_client()
        |> MeterEventSummary.stream!(@meter_id, @window)
        |> Enum.to_list()

      assert length(summaries) == 3
    end

    test "a single page with has_more false makes exactly one call" do
      expect(LatticeStripe.MockTransport, :request, 1, fn _req ->
        summaries_response([summary("mtrusg_a"), summary("mtrusg_b")], false)
      end)

      summaries =
        test_client()
        |> MeterEventSummary.stream!(@meter_id, @window)
        |> Enum.to_list()

      assert length(summaries) == 2
    end

    # A meter with no usage in the window is the normal state of a freshly-provisioned
    # customer, not an error: one call, an empty list, and no speculative page 2.
    test "an empty first page makes exactly one call and yields an empty list" do
      expect(LatticeStripe.MockTransport, :request, 1, fn _req ->
        summaries_response([], false)
      end)

      assert test_client()
             |> MeterEventSummary.stream!(@meter_id, @window)
             |> Enum.to_list() == []
    end

    # D-30 assertion 4 / T-64-07. The single `expect/3` IS the assertion: laziness must
    # survive the `Stream.map(&from_map/1)` composed on top of `List.stream!/2`, so an
    # early-terminating consumer never pays for page 2. A test that merely checked the
    # returned item count would pass even if page 2 had been fetched and discarded —
    # which is precisely the bug that makes the module's memory guidance untrue.
    test "Stream.take/2 on a two-page stream makes exactly ONE transport call" do
      expect(LatticeStripe.MockTransport, :request, 1, fn _req ->
        summaries_response([summary("mtrusg_a"), summary("mtrusg_b")], true)
      end)

      summaries =
        test_client()
        |> MeterEventSummary.stream!(@meter_id, @bucketed_window)
        |> Stream.take(1)
        |> Enum.to_list()

      assert [%MeterEventSummary{id: "mtrusg_a"}] = summaries
    end

    # MTR-01 ordering edge. Summaries are a time series; re-sorting or de-duplicating
    # them client-side would silently reorder a chart's buckets, and the page seam is
    # where an accidental re-sort would hide.
    test "items are emitted in wire order within a page and across the page seam" do
      page_1 = [
        summary("mtrusg_c", %{"start_time" => 1_753_574_400}),
        summary("mtrusg_a", %{"start_time" => 1_753_660_800})
      ]

      page_2 = [summary("mtrusg_b", %{"start_time" => 1_753_747_200})]

      LatticeStripe.MockTransport
      |> expect(:request, fn _req -> summaries_response(page_1, true) end)
      |> expect(:request, fn _req -> summaries_response(page_2, false) end)

      summaries =
        test_client()
        |> MeterEventSummary.stream!(@meter_id, @bucketed_window)
        |> Enum.to_list()

      # Deliberately NOT in id-sorted order: the library emits what the wire supplied.
      assert Enum.map(summaries, & &1.id) == ["mtrusg_c", "mtrusg_a", "mtrusg_b"]

      assert Enum.map(summaries, & &1.start_time) == [
               1_753_574_400,
               1_753_660_800,
               1_753_747_200
             ]
    end
  end

  # ---------------------------------------------------------------------------
  # MTR-02 — request scoping on pages the caller never constructs
  # (D-30 assertions 2, 5, 6 / T-64-02, T-64-03, T-64-04)
  # ---------------------------------------------------------------------------

  describe "stream!/4 request scoping on pages the caller never constructs" do
    # D-30 assertion 2 / T-64-03 — the phase's highest-value assertion, MUTATION-CHECKED.
    # Do not rename it, do not fold it into a generic pagination case, and do not collapse
    # the four checks into one combined comparison.
    #
    # Each filter is asserted SEPARATELY because the failure mode that matters is a
    # PARTIAL drop. A total drop makes Stripe answer 400 loudly. A partial drop is silent
    # and unfalsifiable downstream: the returned summaries carry no `customer` field at
    # all (F-02), so nothing can compare what came back against what was asked for. And
    # `value_grouping_window` is optional, so losing only that one does not error either —
    # page 2 quietly stops returning per-day rows and returns one whole-range aggregate
    # instead, producing a series with a single absurd outlier and no error anywhere.
    #
    # Verified load-bearing: zeroing `base_params` in `List.build_next_page_request/1`
    # fails this test. See 64-06-SUMMARY.md.
    test "page 2 preserves customer, start_time, end_time and value_grouping_window" do
      LatticeStripe.MockTransport
      |> expect(:request, fn req ->
        params = query_params(req)

        assert params["customer"] == "cus_1"
        assert params["start_time"] == "1753574400"
        assert params["end_time"] == "1753660800"
        assert params["value_grouping_window"] == "day"

        summaries_response([summary("mtrusg_a")], true)
      end)
      |> expect(:request, fn req ->
        params = query_params(req)

        assert params["customer"] == "cus_1"
        assert params["start_time"] == "1753574400"
        assert params["end_time"] == "1753660800"
        assert params["value_grouping_window"] == "day"

        # The cursor is carried in ADDITION to the filters, never instead of them.
        assert params["starting_after"] == "mtrusg_a"

        summaries_response([summary("mtrusg_b")], false)
      end)

      summaries =
        test_client()
        |> MeterEventSummary.stream!(@meter_id, @bucketed_window)
        |> Enum.to_list()

      assert length(summaries) == 2
    end

    # D-30 assertion 5 / T-64-02. This is an ACCESS-CONTROL assertion, not a convenience
    # one: a dropped `stripe-account` header on page 2 executes that read against the
    # PLATFORM account rather than the connected account, so half the series comes back
    # from the wrong books with nothing to indicate it.
    test "the stripe-account header carries to page 2" do
      LatticeStripe.MockTransport
      |> expect(:request, fn req ->
        assert {"stripe-account", "acct_connected"} in req.headers
        summaries_response([summary("mtrusg_a")], true)
      end)
      |> expect(:request, fn req ->
        assert {"stripe-account", "acct_connected"} in req.headers
        summaries_response([summary("mtrusg_b")], false)
      end)

      summaries =
        [stripe_account: "acct_connected"]
        |> test_client()
        |> MeterEventSummary.stream!(@meter_id, @window)
        |> Enum.to_list()

      assert length(summaries) == 2
    end

    test "a per-request stripe_account override also carries to page 2" do
      LatticeStripe.MockTransport
      |> expect(:request, fn req ->
        assert {"stripe-account", "acct_per_request"} in req.headers
        summaries_response([summary("mtrusg_a")], true)
      end)
      |> expect(:request, fn req ->
        assert {"stripe-account", "acct_per_request"} in req.headers
        summaries_response([summary("mtrusg_b")], false)
      end)

      summaries =
        test_client()
        |> MeterEventSummary.stream!(@meter_id, @window, stripe_account: "acct_per_request")
        |> Enum.to_list()

      assert length(summaries) == 2
    end

    # D-30 assertion 6 / T-64-04. Page 1's opts DO supply a key, so this proves the strip
    # at list.ex:267 rather than proving a key was never there in the first place.
    test "no idempotency-key is sent on page 2" do
      LatticeStripe.MockTransport
      |> expect(:request, fn req ->
        assert Enum.any?(req.headers, fn {k, _v} -> k == "idempotency-key" end)
        summaries_response([summary("mtrusg_a")], true)
      end)
      |> expect(:request, fn req ->
        # `LatticeStripe.List` deletes :idempotency_key from _opts when building a page
        # request. Assert the key is absent from the OUTGOING request, not from source.
        refute Enum.any?(req.headers, fn {k, _v} -> k == "idempotency-key" end)
        summaries_response([summary("mtrusg_b")], false)
      end)

      summaries =
        test_client()
        |> MeterEventSummary.stream!(@meter_id, @window, idempotency_key: "idem_123")
        |> Enum.to_list()

      assert length(summaries) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # MTR-02 — enumeration is complete or it fails loudly, never partial
  # (D-30 assertion 8)
  # ---------------------------------------------------------------------------

  describe "stream!/4 error propagation" do
    test "a 500 on page 2 raises LatticeStripe.Error out of the stream" do
      LatticeStripe.MockTransport
      |> expect(:request, fn _req -> summaries_response([summary("mtrusg_a")], true) end)
      |> expect(:request, fn _req -> server_error_response(500) end)

      assert_raise LatticeStripe.Error, fn ->
        test_client()
        |> MeterEventSummary.stream!(@meter_id, @window)
        |> Enum.to_list()
      end
    end

    # The raise must come from the SECOND fetch, not from a stream that never started:
    # page-1 items are emitted first. Messages are sent synchronously from the consuming
    # process, so `assert_received` needs no timeout and adds no timing dependency.
    test "page-1 items are emitted before the page-2 error surfaces" do
      parent = self()

      LatticeStripe.MockTransport
      |> expect(:request, fn _req -> summaries_response([summary("mtrusg_a")], true) end)
      |> expect(:request, fn _req -> server_error_response(500) end)

      assert_raise LatticeStripe.Error, fn ->
        test_client()
        |> MeterEventSummary.stream!(@meter_id, @window)
        |> Stream.each(&send(parent, {:emitted, &1.id}))
        |> Enum.to_list()
      end

      assert_received {:emitted, "mtrusg_a"}
    end
  end
end
