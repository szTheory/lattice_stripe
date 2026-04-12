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

    test "advance/4 and advance_and_wait/4 are NOT exported yet (Plan 04)" do
      # These land in Plan 13-04; this plan ships CRUD only.
      refute function_exported?(LatticeStripe.TestHelpers.TestClock, :advance, 4)
      refute function_exported?(LatticeStripe.TestHelpers.TestClock, :advance_and_wait, 4)
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
  end
end
