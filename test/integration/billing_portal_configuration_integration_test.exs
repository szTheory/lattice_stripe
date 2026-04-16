defmodule LatticeStripe.BillingPortal.ConfigurationIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration
  @moduletag :billing_portal

  alias LatticeStripe.BillingPortal.Configuration

  setup_all do
    case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
        :ok

      {:error, _} ->
        raise "stripe-mock not running on localhost:12111 -- start with: docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest"
    end
  end

  setup do
    {:ok, client: test_integration_client()}
  end

  test "full lifecycle: create -> retrieve -> update -> list", %{client: client} do
    {:ok, %Configuration{id: id} = config} =
      Configuration.create(client, %{
        "business_profile" => %{"headline" => "Test Portal"},
        "features" => %{
          "customer_update" => %{"enabled" => true, "allowed_updates" => ["email"]},
          "invoice_history" => %{"enabled" => true},
          "payment_method_update" => %{"enabled" => false},
          "subscription_cancel" => %{"enabled" => false},
          "subscription_update" => %{
            "enabled" => false,
            "default_allowed_updates" => [],
            "products" => [],
            "proration_behavior" => "none"
          }
        }
      })

    assert is_binary(id)
    assert config.object == "billing_portal.configuration"
    assert %Configuration.Features{} = config.features

    # Retrieve
    assert {:ok, %Configuration{id: ^id}} = Configuration.retrieve(client, id)

    # Update
    assert {:ok, %Configuration{}} = Configuration.update(client, id, %{"name" => "Updated"})

    # List
    {:ok, list_resp} = Configuration.list(client)
    assert is_list(list_resp.data.data)
  end
end
