defmodule LatticeStripe.Billing.MeterIntegrationTest do
  use ExUnit.Case, async: false
  @moduletag :integration

  alias LatticeStripe.Billing.{Meter, MeterEvent, MeterEventAdjustment}
  alias LatticeStripe.Client

  # Guard: check stripe-mock connectivity before running any tests in this module.
  # If stripe-mock is not running on localhost:12111, all tests are skipped.
  setup_all do
    case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
        :ok

      {:error, _} ->
        raise "stripe-mock not running on localhost:12111 — start with: docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest"
    end
  end

  setup do
    client =
      Client.new!(
        api_key: "sk_test_123",
        base_url: System.get_env("STRIPE_MOCK_URL") || "http://localhost:12111",
        finch: LatticeStripe.IntegrationFinch,
        transport: LatticeStripe.Transport.Finch,
        telemetry_enabled: false,
        max_retries: 0
      )

    %{client: client}
  end

  # TEST-05: Full lifecycle against stripe-mock.
  # stripe-mock is stateless — state transitions (active→inactive) are NOT
  # asserted. Only the return shape (%Meter{}) is checked for each verb.
  test "full lifecycle: create → retrieve → update → list → deactivate → reactivate", %{client: client} do
    event_name = "api_call_#{System.unique_integer([:positive])}"

    {:ok, %Meter{id: id}} =
      Meter.create(client, %{
        "display_name" => "API Calls",
        "event_name" => event_name,
        "default_aggregation" => %{"formula" => "sum"},
        "customer_mapping" => %{
          "event_payload_key" => "stripe_customer_id",
          "type" => "by_id"
        },
        "value_settings" => %{"event_payload_key" => "value"}
      })

    assert is_binary(id)

    # TEST-05 (metering side) — report an event through the meter we just created.
    # stripe-mock is stateless: we assert {:ok, %MeterEvent{}} shape only, NOT
    # that the event was persisted against any customer. The point of this test
    # is that the HTTP call round-trips through LatticeStripe.Billing.MeterEvent
    # and decodes via from_map/1 without raising or returning an error tuple.
    event_identifier = "req_#{System.unique_integer([:positive])}"

    assert {:ok, %MeterEvent{}} =
             MeterEvent.create(client, %{
               "event_name" => event_name,
               "payload" => %{"stripe_customer_id" => "cus_test_123", "value" => "1"},
               "identifier" => event_identifier
             })

    # TEST-05 continued — adjust the event we just reported, using the exact
    # cancel.identifier nested shape enforced by Guards.check_adjustment_cancel_shape!/1.
    # Shape-only assertion: stripe-mock does not enforce the 24-hour window or
    # verify the identifier exists.
    assert {:ok, %MeterEventAdjustment{}} =
             MeterEventAdjustment.create(client, %{
               "event_name" => event_name,
               "type" => "cancel",
               "cancel" => %{"identifier" => event_identifier}
             })

    {:ok, %Meter{}} = Meter.retrieve(client, id)
    {:ok, %Meter{}} = Meter.update(client, id, %{"display_name" => "API Calls v2"})

    {:ok, list_resp} = Meter.list(client, %{"limit" => 3})
    assert is_list(list_resp.data.data)

    {:ok, %Meter{}} = Meter.deactivate(client, id)
    {:ok, %Meter{}} = Meter.reactivate(client, id)
  end
end
