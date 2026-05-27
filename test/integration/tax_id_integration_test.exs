defmodule LatticeStripe.Integration.TaxIdTest do
  @moduledoc """
  Integration tests for `LatticeStripe.TaxId` against stripe-mock.

  Validates wire-level correctness for both URL families:
  `/v1/tax_ids` and `/v1/customers/:id/tax_ids`.

  Run stripe-mock before these tests:

      docker run --rm -p 12111:12111 stripe/stripe-mock:latest
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  import LatticeStripe.TestHelpers

  alias LatticeStripe.{Customer, TaxId}

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
    {:ok, client: test_integration_client()}
  end

  describe "top-level TaxId CRUD round-trip" do
    test "create → retrieve → list → delete on /v1/tax_ids", %{client: client} do
      {:ok, tax_id} =
        TaxId.create(client, %{
          "type" => "eu_vat",
          "value" => "DE#{System.unique_integer([:positive])}"
        })

      assert %TaxId{id: id} = tax_id
      assert is_binary(id)

      {:ok, fetched} = TaxId.retrieve(client, id)
      assert fetched.id == id

      {:ok, resp} = TaxId.list(client, %{"limit" => "5"})
      assert Enum.all?(resp.data.data, &match?(%TaxId{}, &1))

      {:ok, deleted} = TaxId.delete(client, id)
      assert %TaxId{deleted: true} = deleted
    end
  end

  describe "customer-nested TaxId CRUD round-trip" do
    test "create → retrieve → list → delete on /v1/customers/:id/tax_ids", %{client: client} do
      {:ok, %Customer{id: customer_id}} =
        Customer.create(client, %{
          "email" => "tax-id-#{System.unique_integer([:positive])}@example.com"
        })

      {:ok, tax_id} =
        TaxId.create(client, customer_id, %{
          "type" => "eu_vat",
          "value" => "DE#{System.unique_integer([:positive])}"
        })

      assert %TaxId{id: id, customer: ^customer_id} = tax_id

      {:ok, fetched} = TaxId.retrieve(client, customer_id, id)
      assert fetched.id == id

      {:ok, resp} = TaxId.list(client, customer_id, %{"limit" => "5"})
      assert Enum.all?(resp.data.data, &match?(%TaxId{}, &1))

      {:ok, deleted} = TaxId.delete(client, customer_id, id)
      assert %TaxId{deleted: true} = deleted
    end
  end
end
