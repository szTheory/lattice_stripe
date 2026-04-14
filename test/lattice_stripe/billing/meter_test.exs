defmodule LatticeStripe.Billing.MeterTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.Billing.Meter

  alias LatticeStripe.Billing.Meter.{
    CustomerMapping,
    DefaultAggregation,
    StatusTransitions,
    ValueSettings
  }

  alias LatticeStripe.Test.Fixtures.Metering

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # Nested struct tests from Plan 20-02 (preserved)
  # ---------------------------------------------------------------------------

  describe "DefaultAggregation.from_map/1" do
    test "round-trips formula string" do
      assert %DefaultAggregation{formula: "sum"} =
               DefaultAggregation.from_map(%{"formula" => "sum"})
    end

    test "handles nil" do
      assert DefaultAggregation.from_map(nil) == nil
    end

    test "handles empty map" do
      assert %DefaultAggregation{formula: nil} = DefaultAggregation.from_map(%{})
    end

    test "has no :extra field" do
      refute Map.has_key?(%DefaultAggregation{}, :extra)
    end
  end

  describe "ValueSettings.from_map/1" do
    test "round-trips event_payload_key" do
      assert %ValueSettings{event_payload_key: "tokens"} =
               ValueSettings.from_map(%{"event_payload_key" => "tokens"})
    end

    test "handles nil" do
      assert ValueSettings.from_map(nil) == nil
    end

    test "has no :extra field" do
      refute Map.has_key?(%ValueSettings{}, :extra)
    end
  end

  describe "CustomerMapping.from_map/1" do
    test "round-trips known fields" do
      assert %CustomerMapping{
               event_payload_key: "stripe_customer_id",
               type: "by_id",
               extra: extra
             } =
               CustomerMapping.from_map(%{
                 "event_payload_key" => "stripe_customer_id",
                 "type" => "by_id"
               })

      assert extra == %{}
    end

    test "captures unknown fields in :extra" do
      assert %CustomerMapping{extra: %{"future_field" => 1}} =
               CustomerMapping.from_map(%{
                 "event_payload_key" => "k",
                 "type" => "by_id",
                 "future_field" => 1
               })
    end

    test "handles nil" do
      assert CustomerMapping.from_map(nil) == nil
    end
  end

  describe "StatusTransitions.from_map/1" do
    test "round-trips deactivated_at" do
      assert %StatusTransitions{deactivated_at: 1_712_400_000, extra: %{}} =
               StatusTransitions.from_map(%{"deactivated_at" => 1_712_400_000})
    end

    test "captures unknown transitions in :extra" do
      assert %StatusTransitions{extra: %{"frozen_at" => 99}} =
               StatusTransitions.from_map(%{"deactivated_at" => nil, "frozen_at" => 99})
    end

    test "handles nil" do
      assert StatusTransitions.from_map(nil) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Billing.Meter.from_map/1 — full round-trip from fixture
  # ---------------------------------------------------------------------------

  describe "Meter.from_map/1" do
    test "decodes basic fixture into %Meter{} with all nested structs populated" do
      result = Meter.from_map(Metering.Meter.basic())

      assert %Meter{
               id: "mtr_123",
               object: "billing.meter",
               display_name: "API Calls",
               event_name: "api_call",
               status: "active",
               livemode: false,
               created: 1_712_345_678,
               updated: 1_712_345_678
             } = result

      assert %DefaultAggregation{formula: "sum"} = result.default_aggregation

      assert %CustomerMapping{event_payload_key: "stripe_customer_id", type: "by_id"} =
               result.customer_mapping

      assert %ValueSettings{event_payload_key: "value"} = result.value_settings
      assert %StatusTransitions{deactivated_at: nil} = result.status_transitions
      assert result.extra == %{}
    end

    test "captures unknown top-level fields in :extra" do
      result = Meter.from_map(Metering.Meter.basic(%{"future_field" => "x"}))
      assert result.extra == %{"future_field" => "x"}
    end
  end

  # ---------------------------------------------------------------------------
  # Billing.Meter.status_atom/1
  # ---------------------------------------------------------------------------

  describe "Meter.status_atom/1" do
    test "returns :active for \"active\"" do
      assert :active = Meter.status_atom("active")
    end

    test "returns :inactive for \"inactive\"" do
      assert :inactive = Meter.status_atom("inactive")
    end

    test "returns :unknown for nil" do
      assert :unknown = Meter.status_atom(nil)
    end

    test "returns :unknown for empty string" do
      assert :unknown = Meter.status_atom("")
    end

    test "returns :unknown for unknown string" do
      assert :unknown = Meter.status_atom("frozen")
    end
  end

  # ---------------------------------------------------------------------------
  # Meter.create/3 — require_param! validation (no network hit)
  # ---------------------------------------------------------------------------

  describe "Meter.create/3 require_param!" do
    test "raises ArgumentError when display_name missing" do
      client = test_client()

      assert_raise ArgumentError, ~r/display_name/, fn ->
        Meter.create(client, %{
          "event_name" => "api_call",
          "default_aggregation" => %{"formula" => "sum"}
        })
      end
    end

    test "raises ArgumentError when event_name missing" do
      client = test_client()

      assert_raise ArgumentError, ~r/event_name/, fn ->
        Meter.create(client, %{
          "display_name" => "API Calls",
          "default_aggregation" => %{"formula" => "sum"}
        })
      end
    end

    test "raises ArgumentError when default_aggregation missing" do
      client = test_client()

      assert_raise ArgumentError, ~r/default_aggregation/, fn ->
        Meter.create(client, %{
          "display_name" => "API Calls",
          "event_name" => "api_call"
        })
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Meter.create/3 — guard integration (guard fires before network)
  # ---------------------------------------------------------------------------

  describe "Meter.create/3 guard integration" do
    test "raises ArgumentError when sum formula + empty value_settings (guard fires before network)" do
      client = test_client()

      # No MockTransport expectation — guard raises before Resource.request/6 is called
      assert_raise ArgumentError, ~r/value_settings\.event_payload_key/, fn ->
        Meter.create(client, %{
          "display_name" => "API Calls",
          "event_name" => "api_call",
          "default_aggregation" => %{"formula" => "sum"},
          "value_settings" => %{}
        })
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Meter.create/3 — happy path via MockTransport
  # ---------------------------------------------------------------------------

  describe "Meter.create/3" do
    test "sends POST /v1/billing/meters and returns {:ok, %Meter{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/billing/meters")
        ok_response(Metering.Meter.basic())
      end)

      assert {:ok, %Meter{id: "mtr_123"}} =
               Meter.create(client, %{
                 "display_name" => "API Calls",
                 "event_name" => "api_call",
                 "default_aggregation" => %{"formula" => "sum"}
               })
    end
  end

  # ---------------------------------------------------------------------------
  # Meter.retrieve/3
  # ---------------------------------------------------------------------------

  describe "Meter.retrieve/3" do
    test "sends GET /v1/billing/meters/:id and returns {:ok, %Meter{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/billing/meters/mtr_123")
        ok_response(Metering.Meter.basic())
      end)

      assert {:ok, %Meter{id: "mtr_123"}} = Meter.retrieve(client, "mtr_123")
    end
  end

  # ---------------------------------------------------------------------------
  # Meter.deactivate/3 + reactivate/3
  # ---------------------------------------------------------------------------

  describe "Meter.deactivate/3" do
    test "sends POST /v1/billing/meters/:id/deactivate and returns {:ok, %Meter{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/billing/meters/mtr_123/deactivate")
        ok_response(Metering.Meter.deactivated())
      end)

      assert {:ok, %Meter{id: "mtr_123", status: "inactive"}} =
               Meter.deactivate(client, "mtr_123")
    end
  end

  describe "Meter.reactivate/3" do
    test "sends POST /v1/billing/meters/:id/reactivate and returns {:ok, %Meter{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/billing/meters/mtr_123/reactivate")
        ok_response(Metering.Meter.basic())
      end)

      assert {:ok, %Meter{id: "mtr_123", status: "active"}} = Meter.reactivate(client, "mtr_123")
    end
  end
end
