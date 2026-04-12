defmodule LatticeStripe.Subscription.CancellationDetailsTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Subscription.CancellationDetails

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert CancellationDetails.from_map(nil) == nil
    end

    test "decodes all known fields" do
      details =
        CancellationDetails.from_map(%{
          "reason" => "cancellation_requested",
          "feedback" => "too_expensive",
          "comment" => "sensitive comment text"
        })

      assert details.reason == "cancellation_requested"
      assert details.feedback == "too_expensive"
      assert details.comment == "sensitive comment text"
      assert details.extra == %{}
    end

    test "collects unknown fields into :extra" do
      details =
        CancellationDetails.from_map(%{
          "reason" => "payment_failed",
          "future_field" => 42
        })

      assert details.reason == "payment_failed"
      assert details.extra == %{"future_field" => 42}
    end
  end

  describe "Inspect" do
    test "masks the comment field to avoid leaking PII" do
      details =
        CancellationDetails.from_map(%{
          "reason" => "cancellation_requested",
          "feedback" => "too_expensive",
          "comment" => "sensitive comment text"
        })

      inspected = inspect(details)

      refute inspected =~ "sensitive comment text"
      assert inspected =~ "[FILTERED]"
      assert inspected =~ "#LatticeStripe.Subscription.CancellationDetails<"
    end

    test "shows nil comment as nil (no FILTERED marker)" do
      details = CancellationDetails.from_map(%{"reason" => "other"})
      inspected = inspect(details)

      refute inspected =~ "[FILTERED]"
      assert inspected =~ "comment: nil"
    end
  end
end
