defmodule LatticeStripe.Billing.MeterEventStreamIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :skip
  # stripe-mock does not support v2 billing endpoints (meter_event_session,
  # meter_event_stream). Both POST /v2/billing/meter_event_session and
  # POST /v2/billing/meter_event_stream return 404 "Unrecognized request URL"
  # from stripe-mock v0.197.0 (which serves v1 OpenAPI spec only).
  #
  # Test shape is verified via Mox in meter_event_stream_test.exs.
  # Unskip when stripe-mock adds v2 endpoint support.

  alias LatticeStripe.{Client, Billing.MeterEventStream}
  alias LatticeStripe.Billing.MeterEventStream.Session

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

  test "session create + event send lifecycle", %{client: client} do
    assert {:ok, %Session{authentication_token: token}} =
             MeterEventStream.create_session(client)

    assert is_binary(token)

    events = [
      %{
        "event_name" => "api_call",
        "payload" => %{"stripe_customer_id" => "cus_123", "value" => "1"}
      }
    ]

    assert {:ok, _} =
             MeterEventStream.send_events(client, %Session{
               authentication_token: token,
               expires_at: System.system_time(:second) + 900
             }, events)
  end
end
