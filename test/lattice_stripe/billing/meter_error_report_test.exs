defmodule LatticeStripe.Billing.MeterErrorReportTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Billing.MeterErrorReport.{ErrorType, Reason, SampleError}

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
end
