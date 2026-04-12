defmodule LatticeStripe.TestHelpers.TestClockTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.TestHelpers.TestClock

  describe "from_map/1" do
    test "decodes a minimal test clock" do
      c =
        TestClock.from_map(%{
          "id" => "clock_abc",
          "object" => "test_helpers.test_clock",
          "status" => "ready"
        })

      assert c.id == "clock_abc"
      assert c.object == "test_helpers.test_clock"
      assert c.status == :ready
    end

    test "decodes a fully-populated test clock" do
      c =
        TestClock.from_map(%{
          "id" => "clock_abc",
          "object" => "test_helpers.test_clock",
          "created" => 1_712_900_000,
          "deletes_after" => 1_713_500_000,
          "frozen_time" => 1_713_000_000,
          "livemode" => false,
          "name" => "my-clock",
          "status" => "advancing",
          "status_details" => %{"nested" => "info"}
        })

      assert c.id == "clock_abc"
      assert c.created == 1_712_900_000
      assert c.deletes_after == 1_713_500_000
      assert c.frozen_time == 1_713_000_000
      assert c.livemode == false
      assert c.name == "my-clock"
      assert c.status == :advancing
      assert c.status_details == %{"nested" => "info"}
    end

    test "defaults object to test_helpers.test_clock when absent" do
      c = TestClock.from_map(%{"id" => "clock_x"})
      assert c.object == "test_helpers.test_clock"
    end

    test "deleted defaults to false" do
      c = TestClock.from_map(%{})
      assert c.deleted == false
    end

    test "unknown fields land in extra" do
      c = TestClock.from_map(%{"id" => "clock_x", "future_field" => 42, "another" => "x"})
      assert c.extra == %{"future_field" => 42, "another" => "x"}
    end
  end

  describe "D-03 atomize_status/1 (via from_map/1)" do
    test "ready string to :ready atom" do
      assert TestClock.from_map(%{"status" => "ready"}).status == :ready
    end

    test "advancing string to :advancing atom" do
      assert TestClock.from_map(%{"status" => "advancing"}).status == :advancing
    end

    test "internal_failure string to :internal_failure atom" do
      assert TestClock.from_map(%{"status" => "internal_failure"}).status == :internal_failure
    end

    test "nil status stays nil" do
      assert TestClock.from_map(%{}).status == nil
    end

    test "forward compat: unknown status passes through as raw string (not String.to_atom!)" do
      assert TestClock.from_map(%{"status" => "future_unknown_state"}).status ==
               "future_unknown_state"
    end
  end

  describe "struct surface" do
    test "defstruct has all documented fields" do
      fields = %TestClock{} |> Map.from_struct() |> Map.keys() |> MapSet.new()

      for f <- [
            :id,
            :object,
            :created,
            :deletes_after,
            :frozen_time,
            :livemode,
            :name,
            :status,
            :status_details,
            :deleted,
            :extra
          ] do
        assert f in fields, "missing field #{inspect(f)}"
      end
    end

    test "object defaults to test_helpers.test_clock" do
      assert %TestClock{}.object == "test_helpers.test_clock"
    end

    test "deleted defaults to false" do
      assert %TestClock{}.deleted == false
    end

    test "extra defaults to empty map" do
      assert %TestClock{}.extra == %{}
    end

    test "metadata field is NOT part of the struct (A-13g: Stripe does not expose it for test clocks)" do
      fields = %TestClock{} |> Map.from_struct() |> Map.keys()
      refute :metadata in fields
    end
  end

  describe "documentation" do
    test "@moduledoc mentions the 100-clock account limit" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(TestClock)
      assert moduledoc =~ "100"
      assert moduledoc =~ "account"
    end

    test "@moduledoc references the Testing.TestClock user-facing helper" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(TestClock)
      assert moduledoc =~ "LatticeStripe.Testing.TestClock"
    end

    test "@moduledoc documents the deletion cascade" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(TestClock)
      assert moduledoc =~ "cascade" or moduledoc =~ "Cascade"
    end

    test "@moduledoc documents A-13g metadata finding" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(TestClock)
      assert moduledoc =~ "metadata" or moduledoc =~ "Metadata"
    end
  end
end
