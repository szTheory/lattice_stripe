defmodule LatticeStripe.Billing.MeterEventTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.Billing.MeterEvent
  alias LatticeStripe.Testing.Fixtures.MeterEvent, as: MeterEventFixture

  describe "from_map/1 (EVENT-05 minimal struct)" do
    test "round-trips all 6 known fields" do
      m = MeterEventFixture.meter_event_json()

      assert %MeterEvent{
               event_name: "api_call",
               identifier: "req_abc",
               payload: %{"stripe_customer_id" => "cus_test_123", "value" => "1"},
               timestamp: 1_712_345_678,
               created: 1_712_345_679,
               livemode: false
             } = MeterEvent.from_map(m)
    end

    test "struct has no :extra field (minimal per EVENT-05)" do
      refute Map.has_key?(%MeterEvent{}, :extra)
    end
  end

  describe "create/3 param validation" do
    # Minimal client satisfying enforce_keys — ArgumentError fires before
    # any transport or network call, so finch/transport values are irrelevant.
    defp minimal_client,
      do: %LatticeStripe.Client{api_key: "sk_test", finch: :test_finch}

    test "raises ArgumentError when event_name missing" do
      assert_raise ArgumentError, ~r/event_name/, fn ->
        MeterEvent.create(minimal_client(), %{"payload" => %{}})
      end
    end

    test "raises ArgumentError when payload missing" do
      assert_raise ArgumentError, ~r/payload/, fn ->
        MeterEvent.create(minimal_client(), %{"event_name" => "x"})
      end
    end
  end

  describe "create/3 payload pass-through (MTR-04)" do
    setup :verify_on_exit!

    # Observed at the transport, which is the only place the claim is provable.
    # `guides/metering.md` tells adopters they may attach arbitrary dimensions to
    # a payload; this is the proof that nothing between create/3 and the wire
    # filters, renames or reorders those keys.
    test "arbitrary dimension keys all reach the wire — create/3 filters nothing" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/billing/meter_events")

        # None of these three share a prefix with "value", so a plausible
        # allowlist would not contain them.
        assert req.body =~ "payload[region]=us-west-2"
        assert req.body =~ "payload[sku]=gpu-a100"
        assert req.body =~ "payload[tenant_tier]=enterprise"
        assert req.body =~ "payload[value]=0.000001"

        ok_response(MeterEventFixture.meter_event_json())
      end)

      assert {:ok, %MeterEvent{}} =
               MeterEvent.create(client, %{
                 "event_name" => "api_call",
                 "payload" => %{
                   "region" => "us-west-2",
                   "sku" => "gpu-a100",
                   "tenant_tier" => "enterprise",
                   "value" => "0.000001"
                 }
               })
    end
  end

  describe "Inspect masking (PII-01 / T-20-04 payload masking)" do
    setup do
      event = MeterEvent.from_map(MeterEventFixture.meter_event_json())
      %{event: event, rendered: inspect(event)}
    end

    test "renders with allowlist prefix", %{rendered: r} do
      assert r =~ "#LatticeStripe.Billing.MeterEvent<"
    end

    test "hides payload value", %{rendered: r} do
      refute r =~ "stripe_customer_id"
      refute r =~ "cus_test_123"
      refute r =~ ~s("value" => "1")
    end

    test "shows allowlist fields (event_name, identifier, timestamp, created, livemode)", %{
      rendered: r
    } do
      assert r =~ "event_name:"
      assert r =~ "identifier:"
      assert r =~ "timestamp:"
      assert r =~ "created:"
      assert r =~ "livemode:"
    end

    test "debugging escape hatch: struct field access returns payload", %{event: event} do
      assert event.payload == %{"stripe_customer_id" => "cus_test_123", "value" => "1"}
    end
  end

  describe "@doc async-ack explainer (GUARD-03 / T-20-02 async ack)" do
    test "create/3 @doc contains 'accepted for processing' phrase" do
      {:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(MeterEvent)

      create_doc =
        docs
        |> Enum.find(fn
          {{:function, :create, 3}, _, _, _, _} -> true
          _ -> false
        end)
        |> elem(3)
        |> Map.get("en")

      assert create_doc =~ "accepted for processing"
      assert create_doc =~ "v1.billing.meter.error_report_triggered"
      assert create_doc =~ "identifier"
      assert create_doc =~ "idempotency_key"
    end
  end
end
