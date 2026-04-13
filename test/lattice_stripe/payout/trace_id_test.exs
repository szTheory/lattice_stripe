defmodule LatticeStripe.Payout.TraceIdTest do
  use ExUnit.Case, async: true

  import LatticeStripe.Test.Fixtures.PayoutTraceId

  alias LatticeStripe.Payout.TraceId

  describe "cast/1" do
    test "returns %TraceId{} with status and value populated for supported rail" do
      trace_id = TraceId.cast(supported())

      assert %TraceId{status: "supported", value: "FED12345", extra: %{}} = trace_id
    end

    test "returns %TraceId{} with nil value when status is pending" do
      trace_id = TraceId.cast(pending())

      assert %TraceId{status: "pending", value: nil, extra: %{}} = trace_id
    end

    test "returns %TraceId{} for unsupported rail" do
      trace_id = TraceId.cast(unsupported())

      assert %TraceId{status: "unsupported", value: nil, extra: %{}} = trace_id
    end

    test "returns nil on nil input" do
      assert TraceId.cast(nil) == nil
    end

    test "preserves unknown future keys in :extra (F-001)" do
      trace_id =
        TraceId.cast(%{
          "status" => "supported",
          "value" => "FED12345",
          "future_key" => "yay",
          "another" => 42
        })

      assert trace_id.status == "supported"
      assert trace_id.value == "FED12345"
      assert trace_id.extra == %{"future_key" => "yay", "another" => 42}
    end

    test "pattern-match on status works as documented" do
      trace_id = TraceId.cast(supported())

      result =
        case trace_id do
          %TraceId{status: "supported", value: value} -> {:ok, value}
          %TraceId{status: "pending"} -> :pending
          %TraceId{status: _} -> :other
        end

      assert result == {:ok, "FED12345"}
    end

    test "handles missing keys as nil" do
      trace_id = TraceId.cast(%{})

      assert %TraceId{status: nil, value: nil, extra: %{}} = trace_id
    end
  end

  describe "module surface" do
    test "does not derive Jason.Encoder" do
      # Guard: Inspect + F-001 means we don't serialize back to JSON automatically.
      source = File.read!("lib/lattice_stripe/payout/trace_id.ex")
      refute source =~ "Jason.Encoder"
    end
  end
end
