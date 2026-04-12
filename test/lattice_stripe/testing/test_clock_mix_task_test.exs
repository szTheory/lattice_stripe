defmodule LatticeStripe.Testing.TestClockMixTaskTest do
  use ExUnit.Case, async: false

  import Mox
  import LatticeStripe.TestSupport

  alias LatticeStripe.TestHelpers.TestClock
  alias Mix.Tasks.LatticeStripe.TestClock.Cleanup

  setup :verify_on_exit!

  defp clock_json(overrides) do
    Map.merge(
      %{
        "id" => "clock_old_1",
        "object" => "test_helpers.test_clock",
        "created" => System.system_time(:second) - 7_200,
        "frozen_time" => 1_712_900_000,
        "livemode" => false,
        "name" => "lattice_stripe_test",
        "status" => "ready",
        "status_details" => nil
      },
      overrides
    )
  end

  # ---------------------------------------------------------------
  # cleanup_tagged/2 on TestHelpers.TestClock
  # ---------------------------------------------------------------

  describe "cleanup_tagged/2" do
    test "returns matching candidates in delete: false mode (age filter)" do
      client = test_client()
      now = System.system_time(:second)
      old_clock = clock_json(%{"id" => "clock_old", "created" => now - 7200})
      new_clock = clock_json(%{"id" => "clock_new", "created" => now - 60})

      # stream! calls list which calls Client.request
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/test_helpers/test_clocks"
        ok_response(list_json([old_clock, new_clock], "/v1/test_helpers/test_clocks"))
      end)

      assert {:ok, candidates} =
               TestClock.cleanup_tagged(client, older_than_ms: 3_600_000, delete: false)

      assert length(candidates) == 1
      assert hd(candidates).id == "clock_old"
    end

    test "filters by name_prefix when provided" do
      client = test_client()
      now = System.system_time(:second)
      matched = clock_json(%{"id" => "clock_a", "created" => now - 7200, "name" => "lattice_stripe_test"})
      unmatched = clock_json(%{"id" => "clock_b", "created" => now - 7200, "name" => "other_clock"})

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([matched, unmatched], "/v1/test_helpers/test_clocks"))
      end)

      assert {:ok, candidates} =
               TestClock.cleanup_tagged(client,
                 older_than_ms: 3_600_000,
                 delete: false,
                 name_prefix: "lattice_stripe"
               )

      assert length(candidates) == 1
      assert hd(candidates).id == "clock_a"
    end

    test "delete: true returns deleted/failed counts" do
      client = test_client()
      now = System.system_time(:second)
      old1 = clock_json(%{"id" => "clock_d1", "created" => now - 7200})
      old2 = clock_json(%{"id" => "clock_d2", "created" => now - 7200})

      # First call: list (for stream!)
      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([old1, old2], "/v1/test_helpers/test_clocks"))
      end)

      # Delete calls: first succeeds, second fails
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :delete
        ok_response(%{"id" => "clock_d1", "object" => "test_helpers.test_clock", "deleted" => true})
      end)

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :delete
        error_response()
      end)

      assert {:ok, %{deleted: 1, failed: 1, total_matched: 2}} =
               TestClock.cleanup_tagged(client, older_than_ms: 3_600_000, delete: true)
    end

    test "returns empty list when no clocks match" do
      client = test_client()
      now = System.system_time(:second)
      recent = clock_json(%{"id" => "clock_new", "created" => now - 60})

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([recent], "/v1/test_helpers/test_clocks"))
      end)

      assert {:ok, []} =
               TestClock.cleanup_tagged(client, older_than_ms: 3_600_000, delete: false)
    end
  end

  # ---------------------------------------------------------------
  # Mix task unit functions
  # ---------------------------------------------------------------

  describe "parse_duration!/1" do
    test "parses seconds" do
      assert Cleanup.parse_duration!("30s") == 30_000
    end

    test "parses minutes" do
      assert Cleanup.parse_duration!("15m") == 900_000
    end

    test "parses hours" do
      assert Cleanup.parse_duration!("2h") == 7_200_000
    end

    test "parses days" do
      assert Cleanup.parse_duration!("7d") == 604_800_000
    end

    test "raises on invalid format" do
      assert_raise Mix.Error, ~r/Invalid --older-than/, fn ->
        Cleanup.parse_duration!("xyz")
      end
    end
  end

  describe "stripe_mock?/1" do
    test "detects localhost" do
      client = test_client(base_url: "http://localhost:12111")
      assert Cleanup.stripe_mock?(client)
    end

    test "detects 127.0.0.1" do
      client = test_client(base_url: "http://127.0.0.1:12111")
      assert Cleanup.stripe_mock?(client)
    end

    test "does not match real Stripe URLs" do
      client = test_client(base_url: "https://api.stripe.com")
      refute Cleanup.stripe_mock?(client)
    end
  end

  # ---------------------------------------------------------------
  # Mix task run/1 (integration-level)
  # ---------------------------------------------------------------

  describe "Mix task run/1" do
    test "requires --client" do
      assert_raise Mix.Error, ~r/--client/, fn ->
        Cleanup.run([])
      end
    end
  end
end
