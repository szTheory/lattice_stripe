defmodule LatticeStripe.Billing.MeterErrorReportTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Billing.MeterErrorReport
  alias LatticeStripe.Billing.MeterErrorReport.{ErrorType, Reason, SampleError}
  alias LatticeStripe.Event
  alias LatticeStripe.Test.Fixtures.Metering.MeterErrorReport, as: Fixture

  # ---------------------------------------------------------------------------
  # SampleError — the leaf, and the module's whole point: `request_identifier`
  # is the idempotency key of the failing MeterEvent.create/3 call (F-15, N-04).
  # ---------------------------------------------------------------------------

  describe "SampleError.from_map/1" do
    test "resolves error_message and the join key from request.identifier" do
      sample =
        SampleError.from_map(%{
          "error_message" => "Customer mapping key stripe_customer_id not found in payload.",
          "request" => %{"identifier" => "idk_ltc_abc"}
        })

      assert %SampleError{} = sample

      assert sample.error_message ==
               "Customer mapping key stripe_customer_id not found in payload."

      assert sample.request_identifier == "idk_ltc_abc"
    end

    test "returns nil for nil" do
      assert SampleError.from_map(nil) == nil
    end

    test "tolerates an absent request object and leaves request_identifier nil" do
      sample = SampleError.from_map(%{"error_message" => "boom"})

      assert sample.error_message == "boom"
      assert sample.request_identifier == nil
    end

    test "falls back to the alternate idempotency_key spelling under request" do
      sample = SampleError.from_map(%{"request" => %{"idempotency_key" => "idk_legacy"}})

      assert sample.request_identifier == "idk_legacy"
    end

    test "prefers the documented identifier spelling when both are present" do
      sample =
        SampleError.from_map(%{
          "request" => %{"identifier" => "idk_documented", "idempotency_key" => "idk_legacy"}
        })

      assert sample.request_identifier == "idk_documented"
    end

    test "tolerates a nil request object" do
      sample = SampleError.from_map(%{"error_message" => "boom", "request" => nil})

      assert sample.request_identifier == nil
    end
  end

  # ---------------------------------------------------------------------------
  # ErrorType — one row per failing error code, with a sampled subset of the
  # failures underneath it.
  # ---------------------------------------------------------------------------

  describe "ErrorType.from_map/1" do
    test "fans sample_errors out into typed SampleError structs" do
      error_type =
        ErrorType.from_map(%{
          "code" => "meter_event_no_customer_defined",
          "error_count" => 2,
          "sample_errors" => [
            %{"error_message" => "first", "request" => %{"identifier" => "idk_1"}},
            %{"error_message" => "second", "request" => %{"identifier" => "idk_2"}}
          ]
        })

      assert %ErrorType{} = error_type
      assert error_type.error_count == 2
      assert [%SampleError{} = first, %SampleError{} = second] = error_type.sample_errors
      assert first.request_identifier == "idk_1"
      assert second.request_identifier == "idk_2"

      # `code` is a String, never an atom — the enum is open and demonstrably
      # growing, and atoms are never garbage collected on the BEAM (D-18).
      assert is_binary(error_type.code)
    end

    test "returns nil for nil" do
      assert ErrorType.from_map(nil) == nil
    end

    test "yields the empty list — not nil — when sample_errors is absent" do
      error_type = ErrorType.from_map(%{"code" => "no_meter", "error_count" => 900})

      assert error_type.sample_errors == []
    end

    test "decodes the high-volume shape: error_count 900 with an empty sample list" do
      error_type =
        ErrorType.from_map(%{
          "code" => "no_meter",
          "error_count" => 900,
          "sample_errors" => []
        })

      assert error_type.sample_errors == []
      assert error_type.error_count == 900
    end
  end

  # ---------------------------------------------------------------------------
  # Reason — the grouping level. Stripe supplies error_count here AND on each
  # error type, which is why this library ships no counting helpers.
  # ---------------------------------------------------------------------------

  describe "Reason.from_map/1" do
    test "fans error_types out into typed ErrorType structs" do
      reason =
        Reason.from_map(%{
          "error_count" => 3,
          "error_types" => [
            %{"code" => "no_meter", "error_count" => 1, "sample_errors" => []},
            %{"code" => "archived_meter", "error_count" => 2, "sample_errors" => []}
          ]
        })

      assert %Reason{} = reason
      assert reason.error_count == 3

      assert [%ErrorType{code: "no_meter"}, %ErrorType{code: "archived_meter"}] =
               reason.error_types
    end

    test "returns nil for nil" do
      assert Reason.from_map(nil) == nil
    end

    test "yields the empty list — not nil — when error_types is absent" do
      reason = Reason.from_map(%{"error_count" => 1})

      assert reason.error_types == []
    end
  end

  # ---------------------------------------------------------------------------
  # MeterErrorReport.from_map/1 — the low-level constructor. It sees only
  # `data`, so it structurally cannot know which meter failed.
  # ---------------------------------------------------------------------------

  describe "from_map/1" do
    test "decodes all four data fields from the published payload" do
      report = MeterErrorReport.from_map(Fixture.basic())

      assert %MeterErrorReport{} = report
      assert report.developer_message_summary == "There are 902 invalid events"
      assert %Reason{} = report.reason
      assert report.validation_start == "2024-09-26T17:46:10.000Z"
      assert report.validation_end == "2024-09-26T17:46:20.000Z"
    end

    test "validation timestamps round-trip as binaries, not Unix integers" do
      report = MeterErrorReport.from_map(Fixture.basic())

      # v2 event timestamps are RFC3339 strings. One official SDK types them as
      # integers; that is wrong and is deliberately not copied here.
      assert is_binary(report.validation_start)
      assert is_binary(report.validation_end)
    end

    test "returns nil for nil" do
      assert MeterErrorReport.from_map(nil) == nil
    end

    test "is idempotent on an already-decoded struct" do
      report = MeterErrorReport.from_map(Fixture.basic())

      assert MeterErrorReport.from_map(report) == report
    end

    test "leaves :meter nil — the meter id is not in data (asserted contract)" do
      # Not an incidental. `data` never names the meter; only the event
      # envelope's related_object does. from_map/1 therefore cannot know it,
      # and inventing a lookup here would be a lie.
      assert MeterErrorReport.from_map(Fixture.basic()).meter == nil
    end

    test "puts unrecognised top-level keys in :extra rather than dropping them" do
      report =
        MeterErrorReport.from_map(Fixture.basic(%{"future_field" => "surprise"}))

      assert report.extra == %{"future_field" => "surprise"}
    end

    test "navigates fully typed all the way down to a request identifier" do
      report = MeterErrorReport.from_map(Fixture.basic())

      assert [%ErrorType{} = first | _rest] = report.reason.error_types
      assert [%SampleError{} = sample | _] = first.sample_errors
      assert sample.request_identifier == "cb447754-6880-45c2-8f2f-ef19b6ce81e9"
    end

    test "code decodes as a String — the enum is open and must never be atomized" do
      # A closed union would fail to deserialize the next code Stripe adds, and
      # Stripe has already retired one value this repository still documents.
      report = MeterErrorReport.from_map(Fixture.basic())
      [%ErrorType{code: code} | _] = report.reason.error_types

      assert is_binary(code)
    end

    test "tolerates a nil reason" do
      report = MeterErrorReport.from_map(Fixture.basic(%{"reason" => nil}))

      assert report.reason == nil
    end
  end

  # ---------------------------------------------------------------------------
  # from_event/1 — the primary constructor, and the ONLY one that can populate
  # :meter, because the meter id lives in the event envelope (D-16, F-14).
  # ---------------------------------------------------------------------------

  describe "from_event/1" do
    test "lifts the meter id from the event's related object" do
      event = Event.from_map(Fixture.event())
      report = MeterErrorReport.from_event(event)

      assert report.meter == Fixture.meter_id()
    end

    test "differs from from_map/1 in :meter and nothing else" do
      event = Event.from_map(Fixture.event())

      from_event = MeterErrorReport.from_event(event)
      from_map = MeterErrorReport.from_map(Fixture.basic())

      assert %{from_event | meter: nil} == from_map
    end

    test "tolerates a wholly absent related_object — the no_meter_found shape" do
      # v1.billing.meter.no_meter_found shares this payload byte-for-byte and
      # carries no related_object at all (F-17, N-06).
      event = Event.from_map(Fixture.no_meter_found_event())

      assert event.related_object == nil

      report = MeterErrorReport.from_event(event)

      assert report.meter == nil
      assert %Reason{} = report.reason
    end

    test "raises a directive ArgumentError when the event carries no data" do
      # This is the signature of passing a *delivered webhook body* rather than
      # a fetched event — the documented trap. Without this clause the caller
      # gets a bare BadMapError from a struct update, which names neither the
      # cause nor the fix.
      event = Event.from_map(Map.delete(Fixture.event(), "data"))

      assert_raise ArgumentError, ~r/fetch_event/, fn ->
        MeterErrorReport.from_event(event)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Public surface shape. With no Dialyzer in this project and typespecs
  # documentation-only, a refutation block is the ONLY enforcement of public
  # surface shape available (D-31).
  # ---------------------------------------------------------------------------

  describe "module surface" do
    test "ships no read or write verbs — no endpoint serves this payload" do
      # Not a gap to apologize for. Stripe has no /v1/billing/meter_error_reports
      # collection and no billing.meter_error_report object; this payload arrives
      # only as the `data` of an event, so there is nothing to list, retrieve or
      # create it from (F-11, D-21).
      refute function_exported?(MeterErrorReport, :list, 2)
      refute function_exported?(MeterErrorReport, :list, 3)
      refute function_exported?(MeterErrorReport, :retrieve, 2)
      refute function_exported?(MeterErrorReport, :retrieve, 3)
      refute function_exported?(MeterErrorReport, :create, 2)
      refute function_exported?(MeterErrorReport, :create, 3)
    end

    test "exports exactly the two constructors" do
      assert function_exported?(MeterErrorReport, :from_map, 1)
      assert function_exported?(MeterErrorReport, :from_event, 1)
    end

    test "ships no grouping or counting helpers — the wire supplies them" do
      # Stripe groups by error_types and supplies error_count at both levels.
      refute function_exported?(MeterErrorReport, :group_by_code, 1)
      refute function_exported?(MeterErrorReport, :error_count, 1)
    end
  end
end
