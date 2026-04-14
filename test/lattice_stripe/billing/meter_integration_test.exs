defmodule LatticeStripe.Billing.MeterIntegrationTest do
  use ExUnit.Case, async: false
  @moduletag :integration

  alias LatticeStripe.Client
  alias LatticeStripe.Billing.Meter

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
    {:ok, %Meter{id: id}} =
      Meter.create(client, %{
        "display_name" => "API Calls",
        "event_name" => "api_call_#{System.unique_integer([:positive])}",
        "default_aggregation" => %{"formula" => "sum"},
        "customer_mapping" => %{
          "event_payload_key" => "stripe_customer_id",
          "type" => "by_id"
        },
        "value_settings" => %{"event_payload_key" => "value"}
      })

    assert is_binary(id)

    {:ok, %Meter{}} = Meter.retrieve(client, id)
    {:ok, %Meter{}} = Meter.update(client, id, %{"display_name" => "API Calls v2"})

    {:ok, list_resp} = Meter.list(client, %{"limit" => 3})
    assert is_list(list_resp.data.data)

    {:ok, %Meter{}} = Meter.deactivate(client, id)
    {:ok, %Meter{}} = Meter.reactivate(client, id)
  end
end
