defmodule LatticeStripe.Builders.SubscriptionScheduleTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Builders.SubscriptionSchedule, as: SSBuilder

  @moduletag :subscription_schedule

  describe "new/0" do
    test "returns an opaque struct" do
      result = SSBuilder.new()
      assert is_struct(result)
    end
  end

  describe "build/1" do
    test "customer/2 sets customer field" do
      params =
        SSBuilder.new()
        |> SSBuilder.customer("cus_123")
        |> SSBuilder.build()

      assert params["customer"] == "cus_123"
    end

    test "customer-mode schedule with one phase" do
      params =
        SSBuilder.new()
        |> SSBuilder.customer("cus_123")
        |> SSBuilder.start_date("now")
        |> SSBuilder.end_behavior(:release)
        |> SSBuilder.add_phase(
             SSBuilder.phase_new()
             |> SSBuilder.phase_items([%{"price" => "price_abc", "quantity" => 1}])
             |> SSBuilder.phase_iterations(12)
             |> SSBuilder.phase_proration_behavior(:create_prorations)
             |> SSBuilder.phase_build()
           )
        |> SSBuilder.build()

      assert params["customer"] == "cus_123"
      assert params["start_date"] == "now"
      assert params["end_behavior"] == "release"
      assert [phase] = params["phases"]
      assert phase["iterations"] == 12
      assert phase["proration_behavior"] == "create_prorations"
      assert [%{"price" => "price_abc", "quantity" => 1}] = phase["items"]
    end

    test "nil fields are omitted from build/1 output" do
      params =
        SSBuilder.new()
        |> SSBuilder.customer("cus_123")
        |> SSBuilder.build()

      assert Map.has_key?(params, "customer")
      refute Map.has_key?(params, "from_subscription")
      refute Map.has_key?(params, "start_date")
      refute Map.has_key?(params, "end_behavior")
    end

    test "atom enum values are stringified -- end_behavior(:release) produces 'release'" do
      params =
        SSBuilder.new()
        |> SSBuilder.end_behavior(:release)
        |> SSBuilder.build()

      assert params["end_behavior"] == "release"
      refute params["end_behavior"] == :release
    end

    test "start_date(:now) produces 'now', start_date(integer) produces integer" do
      params_now =
        SSBuilder.new()
        |> SSBuilder.start_date(:now)
        |> SSBuilder.build()

      assert params_now["start_date"] == "now"

      params_int =
        SSBuilder.new()
        |> SSBuilder.start_date(1_700_000_000)
        |> SSBuilder.build()

      assert params_int["start_date"] == 1_700_000_000
    end

    test "from_subscription/2 mode -- build/1 produces correct map" do
      params =
        SSBuilder.new()
        |> SSBuilder.from_subscription("sub_123")
        |> SSBuilder.build()

      assert params["from_subscription"] == "sub_123"
    end

    test "empty phases list is omitted from build/1 output" do
      params =
        SSBuilder.new()
        |> SSBuilder.customer("cus_123")
        |> SSBuilder.build()

      refute Map.has_key?(params, "phases")
    end
  end

  describe "phase sub-builder" do
    test "phase_new/0 returns a struct" do
      result = SSBuilder.phase_new()
      assert is_struct(result)
    end

    test "phase_build/1 produces a string-keyed map" do
      result = SSBuilder.phase_new() |> SSBuilder.phase_build()
      assert is_map(result)
      assert not is_struct(result)
    end

    test "phase_items/2, phase_iterations/2, phase_proration_behavior/2 set fields in phase_build/1" do
      phase =
        SSBuilder.phase_new()
        |> SSBuilder.phase_items([%{"price" => "price_abc", "quantity" => 1}])
        |> SSBuilder.phase_iterations(6)
        |> SSBuilder.phase_proration_behavior(:create_prorations)
        |> SSBuilder.phase_build()

      assert phase["iterations"] == 6
      assert phase["proration_behavior"] == "create_prorations"
      assert [%{"price" => "price_abc", "quantity" => 1}] = phase["items"]
    end

    test "phase nil fields are omitted from phase_build/1 output" do
      phase =
        SSBuilder.phase_new()
        |> SSBuilder.phase_iterations(3)
        |> SSBuilder.phase_build()

      assert phase["iterations"] == 3
      refute Map.has_key?(phase, "start_date")
      refute Map.has_key?(phase, "end_date")
      refute Map.has_key?(phase, "currency")
    end

    test "phase atom values stringified -- proration_behavior and trial_continuation" do
      phase =
        SSBuilder.phase_new()
        |> SSBuilder.phase_proration_behavior(:create_prorations)
        |> SSBuilder.phase_trial_continuation(:resume)
        |> SSBuilder.phase_build()

      assert phase["proration_behavior"] == "create_prorations"
      assert phase["trial_continuation"] == "resume"
    end
  end

  describe "add_phase/2" do
    test "add_phase/2 accepts phase_build/1 output (plain map)" do
      built_phase = SSBuilder.phase_new() |> SSBuilder.phase_iterations(1) |> SSBuilder.phase_build()

      params =
        SSBuilder.new()
        |> SSBuilder.customer("cus_123")
        |> SSBuilder.add_phase(built_phase)
        |> SSBuilder.build()

      assert [phase] = params["phases"]
      assert phase["iterations"] == 1
    end

    test "add_phase/2 accepts %Phase{} struct directly and calls phase_build/1 internally" do
      phase_struct =
        SSBuilder.phase_new()
        |> SSBuilder.phase_iterations(5)

      params =
        SSBuilder.new()
        |> SSBuilder.customer("cus_123")
        |> SSBuilder.add_phase(phase_struct)
        |> SSBuilder.build()

      assert [phase] = params["phases"]
      assert phase["iterations"] == 5
    end

    test "multiple add_phase/2 calls append phases in order" do
      phase1 = SSBuilder.phase_new() |> SSBuilder.phase_iterations(1) |> SSBuilder.phase_build()
      phase2 = SSBuilder.phase_new() |> SSBuilder.phase_iterations(2) |> SSBuilder.phase_build()
      phase3 = SSBuilder.phase_new() |> SSBuilder.phase_iterations(3) |> SSBuilder.phase_build()

      params =
        SSBuilder.new()
        |> SSBuilder.customer("cus_123")
        |> SSBuilder.add_phase(phase1)
        |> SSBuilder.add_phase(phase2)
        |> SSBuilder.add_phase(phase3)
        |> SSBuilder.build()

      assert [p1, p2, p3] = params["phases"]
      assert p1["iterations"] == 1
      assert p2["iterations"] == 2
      assert p3["iterations"] == 3
    end
  end
end
