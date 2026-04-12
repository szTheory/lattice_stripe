defmodule LatticeStripe.TestHelpers.TestClockTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestSupport

  alias LatticeStripe.{Error, List, Response}
  alias LatticeStripe.TestHelpers.TestClock

  setup :verify_on_exit!

  defp test_clock_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "clock_test_123",
        "object" => "test_helpers.test_clock",
        "created" => 1_712_900_000,
        "frozen_time" => 1_712_900_000,
        "deletes_after" => 1_713_500_000,
        "livemode" => false,
        "name" => "integration-test",
        "status" => "ready",
        "status_details" => nil
      },
      overrides
    )
  end

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

    test "@moduledoc documents absent operations (update, search)" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(TestClock)
      assert moduledoc =~ "Operations not supported"
      assert moduledoc =~ "update"
      assert moduledoc =~ "search"
    end
  end

  # ---------------------------------------------------------------------------
  # create/3
  # ---------------------------------------------------------------------------

  describe "create/3" do
    test "sends POST /v1/test_helpers/test_clocks and returns {:ok, %TestClock{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/test_helpers/test_clocks")
        assert req.body =~ "frozen_time=1712900000"
        assert req.body =~ "name=renewal-test"
        ok_response(test_clock_json(%{"name" => "renewal-test"}))
      end)

      assert {:ok, %TestClock{id: "clock_test_123", name: "renewal-test", status: :ready}} =
               TestClock.create(client, %{frozen_time: 1_712_900_000, name: "renewal-test"})
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{type: :invalid_request_error}} =
               TestClock.create(client, %{frozen_time: 1_712_900_000})
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve/3
  # ---------------------------------------------------------------------------

  describe "retrieve/3" do
    test "sends GET /v1/test_helpers/test_clocks/:id and decodes the response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/test_helpers/test_clocks/clock_test_123")
        ok_response(test_clock_json())
      end)

      assert {:ok, %TestClock{id: "clock_test_123"}} =
               TestClock.retrieve(client, "clock_test_123")
    end

    test "returns {:error, %Error{}} when not found" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = TestClock.retrieve(client, "clock_missing")
    end
  end

  # ---------------------------------------------------------------------------
  # list/3
  # ---------------------------------------------------------------------------

  describe "list/3" do
    test "sends GET /v1/test_helpers/test_clocks and returns typed %Response+List+TestClock{}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/test_helpers/test_clocks"
        ok_response(list_json([test_clock_json()], "/v1/test_helpers/test_clocks"))
      end)

      assert {:ok, %Response{data: %List{data: [%TestClock{id: "clock_test_123"}]}}} =
               TestClock.list(client, %{limit: 10})
    end

    test "returns {:error, %Error{}} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{}} = TestClock.list(client)
    end
  end

  # ---------------------------------------------------------------------------
  # delete/3
  # ---------------------------------------------------------------------------

  describe "delete/3" do
    test "sends DELETE /v1/test_helpers/test_clocks/:id and returns {:ok, %TestClock{deleted: true}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :delete
        assert String.ends_with?(req.url, "/v1/test_helpers/test_clocks/clock_test_123")

        ok_response(%{
          "id" => "clock_test_123",
          "object" => "test_helpers.test_clock",
          "deleted" => true
        })
      end)

      assert {:ok, %TestClock{id: "clock_test_123", deleted: true}} =
               TestClock.delete(client, "clock_test_123")
    end
  end

  # ---------------------------------------------------------------------------
  # stream!/3
  # ---------------------------------------------------------------------------

  describe "stream!/3" do
    test "lazily paginates and yields typed %TestClock{} items" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert req.url =~ "/v1/test_helpers/test_clocks"

        ok_response(%{
          "object" => "list",
          "data" => [test_clock_json(%{"id" => "clock_a"}), test_clock_json(%{"id" => "clock_b"})],
          "has_more" => false,
          "url" => "/v1/test_helpers/test_clocks"
        })
      end)

      items = TestClock.stream!(client, %{limit: 2}) |> Enum.to_list()
      assert length(items) == 2
      assert Enum.all?(items, &match?(%TestClock{}, &1))
      assert Enum.map(items, & &1.id) == ["clock_a", "clock_b"]
    end
  end

  # ---------------------------------------------------------------------------
  # Bang variants
  # ---------------------------------------------------------------------------

  describe "create!/3" do
    test "returns %TestClock{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(test_clock_json())
      end)

      assert %TestClock{id: "clock_test_123"} =
               TestClock.create!(client, %{frozen_time: 1_712_900_000})
    end

    test "raises %Error{} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        TestClock.create!(client, %{frozen_time: 1_712_900_000})
      end
    end
  end

  describe "retrieve!/3" do
    test "returns %TestClock{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(test_clock_json())
      end)

      assert %TestClock{id: "clock_test_123"} = TestClock.retrieve!(client, "clock_test_123")
    end
  end

  describe "list!/3" do
    test "returns %Response{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(list_json([test_clock_json()], "/v1/test_helpers/test_clocks"))
      end)

      assert %Response{data: %List{data: [%TestClock{}]}} = TestClock.list!(client)
    end
  end

  describe "delete!/3" do
    test "returns %TestClock{deleted: true} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(%{
          "id" => "clock_test_123",
          "object" => "test_helpers.test_clock",
          "deleted" => true
        })
      end)

      assert %TestClock{id: "clock_test_123", deleted: true} =
               TestClock.delete!(client, "clock_test_123")
    end
  end

  # ---------------------------------------------------------------------------
  # Absent operations (D-05 pattern — absence is the interface)
  # ---------------------------------------------------------------------------

  describe "absent operations" do
    test "update/3 is NOT exported (Stripe Test Clock API has no update)" do
      refute function_exported?(LatticeStripe.TestHelpers.TestClock, :update, 3)
      refute function_exported?(LatticeStripe.TestHelpers.TestClock, :update, 4)
    end

    test "search/2 is NOT exported (Stripe Test Clock API has no /search)" do
      refute function_exported?(LatticeStripe.TestHelpers.TestClock, :search, 2)
      refute function_exported?(LatticeStripe.TestHelpers.TestClock, :search, 3)
    end

    test "CRUD functions are exported" do
      assert function_exported?(TestClock, :create, 2)
      assert function_exported?(TestClock, :retrieve, 2)
      assert function_exported?(TestClock, :list, 1)
      assert function_exported?(TestClock, :stream!, 1)
      assert function_exported?(TestClock, :delete, 2)
      assert function_exported?(TestClock, :create!, 2)
      assert function_exported?(TestClock, :retrieve!, 2)
      assert function_exported?(TestClock, :list!, 1)
      assert function_exported?(TestClock, :delete!, 2)
    end

    test "advance/4 is exported" do
      assert function_exported?(TestClock, :advance, 4)
      assert function_exported?(TestClock, :advance!, 4)
    end
  end

  # ---------------------------------------------------------------------------
  # advance/4 (Plan 13-04)
  # ---------------------------------------------------------------------------

  describe "advance/4" do
    test "POSTs /v1/test_helpers/test_clocks/:id/advance with frozen_time param" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/test_helpers/test_clocks/clock_abc/advance")
        assert req.body =~ "frozen_time=1713086400"
        ok_response(test_clock_json(%{"id" => "clock_abc", "status" => "advancing"}))
      end)

      assert {:ok, %TestClock{id: "clock_abc", status: :advancing}} =
               TestClock.advance(client, "clock_abc", 1_713_086_400)
    end

    test "returns {:error, %Error{}} on HTTP failure" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert {:error, %Error{type: :invalid_request_error}} =
               TestClock.advance(client, "clock_abc", 1_713_086_400)
    end

    test "guards against non-binary id" do
      client = test_client()

      assert_raise FunctionClauseError, fn ->
        TestClock.advance(client, :not_binary, 1_713_086_400)
      end
    end

    test "guards against non-integer frozen_time" do
      client = test_client()

      assert_raise FunctionClauseError, fn ->
        TestClock.advance(client, "clock_abc", "not_int")
      end
    end
  end

  describe "advance!/4" do
    test "returns %TestClock{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        ok_response(test_clock_json(%{"id" => "clock_abc", "status" => "advancing"}))
      end)

      assert %TestClock{id: "clock_abc", status: :advancing} =
               TestClock.advance!(client, "clock_abc", 1_713_086_400)
    end

    test "raises %Error{} on error response" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert_raise Error, fn ->
        TestClock.advance!(client, "clock_abc", 1_713_086_400)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # advance_and_wait/4 (Plan 13-04)
  # ---------------------------------------------------------------------------

  # Helper: build the canned advance response (status: advancing).
  defp advancing_response(id \\ "clock_a") do
    ok_response(test_clock_json(%{"id" => id, "status" => "advancing"}))
  end

  defp ready_response(id \\ "clock_a") do
    ok_response(test_clock_json(%{"id" => id, "status" => "ready"}))
  end

  defp internal_failure_response(id \\ "clock_a") do
    ok_response(test_clock_json(%{"id" => id, "status" => "internal_failure"}))
  end

  describe "advance_and_wait/4 — happy path (zero-delay first poll)" do
    test "catches an already-ready clock without any sleep" do
      client = test_client()

      # 1st call: advance (returns :advancing)
      # 2nd call: retrieve (returns :ready, zero-delay first poll)
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert req.url =~ "/advance"
        advancing_response()
      end)

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/test_helpers/test_clocks/clock_a")
        ready_response()
      end)

      started = System.monotonic_time(:millisecond)

      assert {:ok, %TestClock{id: "clock_a", status: :ready}} =
               TestClock.advance_and_wait(client, "clock_a", 1_713_086_400)

      elapsed = System.monotonic_time(:millisecond) - started
      assert elapsed < 200, "zero-delay first poll should complete fast; got #{elapsed}ms"
    end
  end

  describe "advance_and_wait/4 — polling loop" do
    test "polls until ready (advancing, advancing, ready)" do
      client = test_client()

      # advance + 3 retrieves (2 advancing, 1 ready)
      expect(LatticeStripe.MockTransport, :request, fn _ -> advancing_response() end)
      expect(LatticeStripe.MockTransport, :request, fn _ -> advancing_response() end)
      expect(LatticeStripe.MockTransport, :request, fn _ -> advancing_response() end)
      expect(LatticeStripe.MockTransport, :request, fn _ -> ready_response() end)

      assert {:ok, %TestClock{status: :ready}} =
               TestClock.advance_and_wait(client, "clock_a", 1_713_086_400,
                 initial_interval: 500,
                 max_interval: 5_000,
                 multiplier: 1.5,
                 timeout: 30_000
               )
    end
  end

  describe "advance_and_wait/4 — timeout" do
    test "returns :test_clock_timeout when deadline exceeded (opts[:timeout]: 0)" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _ -> advancing_response() end)
      expect(LatticeStripe.MockTransport, :request, fn _ -> advancing_response() end)

      assert {:error,
              %Error{
                type: :test_clock_timeout,
                raw_body: %{
                  "clock_id" => "clock_a",
                  "last_status" => "advancing",
                  "attempts" => attempts,
                  "elapsed_ms" => elapsed
                }
              }} =
               TestClock.advance_and_wait(client, "clock_a", 1_713_086_400, timeout: 0)

      assert attempts >= 1
      assert is_integer(elapsed) and elapsed >= 0
    end
  end

  describe "advance_and_wait/4 — internal_failure" do
    test "returns :test_clock_failed on first :internal_failure (no retry)" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _ -> advancing_response() end)
      expect(LatticeStripe.MockTransport, :request, fn _ -> internal_failure_response() end)

      assert {:error,
              %Error{
                type: :test_clock_failed,
                raw_body: %{
                  "clock_id" => "clock_a",
                  "last_status" => "internal_failure",
                  "attempts" => 1
                }
              }} =
               TestClock.advance_and_wait(client, "clock_a", 1_713_086_400)
    end
  end

  describe "advance_and_wait/4 — HTTP failure propagates" do
    test "returns the underlying retrieve error unchanged" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _ -> advancing_response() end)

      expect(LatticeStripe.MockTransport, :request, fn _ ->
        {:ok,
         %{
           status: 429,
           headers: [{"request-id", "req_rl"}],
           body:
             Jason.encode!(%{
               "error" => %{"type" => "rate_limit_error", "message" => "slow down"}
             })
         }}
      end)

      assert {:error, %Error{type: :rate_limit_error}} =
               TestClock.advance_and_wait(client, "clock_a", 1_713_086_400)
    end

    test "returns :test_clock_failed NOT :test_clock_timeout if advance itself fails" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _ -> error_response() end)

      assert {:error, %Error{type: :invalid_request_error}} =
               TestClock.advance_and_wait(client, "clock_a", 1_713_086_400)
    end
  end

  describe "advance_and_wait!/4" do
    test "returns %TestClock{} on success" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _ -> advancing_response() end)
      expect(LatticeStripe.MockTransport, :request, fn _ -> ready_response() end)

      assert %TestClock{status: :ready} =
               TestClock.advance_and_wait!(client, "clock_a", 1_713_086_400)
    end

    test "raises on timeout" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _ -> advancing_response() end)
      expect(LatticeStripe.MockTransport, :request, fn _ -> advancing_response() end)

      assert_raise Error, ~r/test_clock_timeout|did not reach/, fn ->
        TestClock.advance_and_wait!(client, "clock_a", 1_713_086_400, timeout: 0)
      end
    end

    test "raises on internal_failure" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _ -> advancing_response() end)
      expect(LatticeStripe.MockTransport, :request, fn _ -> internal_failure_response() end)

      assert_raise Error, ~r/internal_failure/, fn ->
        TestClock.advance_and_wait!(client, "clock_a", 1_713_086_400)
      end
    end
  end

  describe "advance_and_wait/4 — telemetry" do
    test "emits :start and :stop events via :telemetry.span/3 on success" do
      client = test_client(telemetry_enabled: true)

      expect(LatticeStripe.MockTransport, :request, fn _ -> advancing_response() end)
      expect(LatticeStripe.MockTransport, :request, fn _ -> ready_response() end)

      handler_id = "advance-and-wait-ok-#{System.unique_integer()}"
      ref = make_ref()
      test_pid = self()

      :telemetry.attach_many(
        handler_id,
        [
          [:lattice_stripe, :test_clock, :advance_and_wait, :start],
          [:lattice_stripe, :test_clock, :advance_and_wait, :stop]
        ],
        fn name, measurements, metadata, _ ->
          send(test_pid, {ref, name, measurements, metadata})
        end,
        nil
      )

      assert {:ok, _} =
               TestClock.advance_and_wait(client, "clock_a", 1_713_086_400)

      assert_receive {^ref, [:lattice_stripe, :test_clock, :advance_and_wait, :start], _m1,
                      start_meta},
                     500

      assert start_meta.clock_id == "clock_a"
      assert start_meta.timeout == 60_000

      assert_receive {^ref, [:lattice_stripe, :test_clock, :advance_and_wait, :stop],
                      stop_measurements, stop_meta},
                     500

      assert stop_meta.clock_id == "clock_a"
      assert stop_meta.outcome == :ok
      assert stop_meta.status == :ready
      assert is_integer(stop_measurements.duration)

      :telemetry.detach(handler_id)
    end

    test "emits :stop with outcome: :error on timeout" do
      client = test_client(telemetry_enabled: true)

      expect(LatticeStripe.MockTransport, :request, fn _ -> advancing_response() end)
      expect(LatticeStripe.MockTransport, :request, fn _ -> advancing_response() end)

      handler_id = "advance-and-wait-err-#{System.unique_integer()}"
      ref = make_ref()
      test_pid = self()

      :telemetry.attach(
        handler_id,
        [:lattice_stripe, :test_clock, :advance_and_wait, :stop],
        fn name, measurements, metadata, _ ->
          send(test_pid, {ref, name, measurements, metadata})
        end,
        nil
      )

      assert {:error, %Error{type: :test_clock_timeout}} =
               TestClock.advance_and_wait(client, "clock_a", 1_713_086_400, timeout: 0)

      assert_receive {^ref, [:lattice_stripe, :test_clock, :advance_and_wait, :stop], _,
                      stop_meta},
                     500

      assert stop_meta.outcome == :ok or stop_meta.outcome == :error
      # The span wraps :ok return of the function; inside we return the error tuple,
      # so outcome should be :error per our build_stop_meta.
      assert stop_meta.outcome == :error
      assert stop_meta.error_type == :test_clock_timeout

      :telemetry.detach(handler_id)
    end

    test "does NOT emit events when client.telemetry_enabled is false" do
      client = test_client(telemetry_enabled: false)

      expect(LatticeStripe.MockTransport, :request, fn _ -> advancing_response() end)
      expect(LatticeStripe.MockTransport, :request, fn _ -> ready_response() end)

      handler_id = "advance-and-wait-off-#{System.unique_integer()}"
      ref = make_ref()
      test_pid = self()

      :telemetry.attach(
        handler_id,
        [:lattice_stripe, :test_clock, :advance_and_wait, :start],
        fn name, measurements, metadata, _ ->
          send(test_pid, {ref, name, measurements, metadata})
        end,
        nil
      )

      assert {:ok, _} =
               TestClock.advance_and_wait(client, "clock_a", 1_713_086_400)

      refute_receive {^ref, _, _, _}, 100

      :telemetry.detach(handler_id)
    end
  end

  describe "advance_and_wait/4 — export check" do
    test "advance_and_wait/4 and advance_and_wait!/4 ARE exported" do
      assert function_exported?(TestClock, :advance_and_wait, 4)
      assert function_exported?(TestClock, :advance_and_wait!, 4)
    end
  end
end
