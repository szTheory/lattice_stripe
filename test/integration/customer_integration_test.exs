defmodule LatticeStripe.CustomerIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{Customer, Error}

  setup_all do
    case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
        {:ok, stripe_mock_available: true}

      {:error, _} ->
        {:ok, stripe_mock_available: false}
    end
  end

  setup %{stripe_mock_available: available} do
    if available do
      {:ok, client: test_integration_client()}
    else
      {:ok, client: nil}
    end
  end

  test "create/3 returns a Customer struct", %{stripe_mock_available: available, client: client} do
    if not available, do: ExUnit.skip("stripe-mock not running on localhost:12111")

    {:ok, customer} =
      Customer.create(client, %{"email" => "integration@test.com", "name" => "Integration Test"})

    assert %Customer{} = customer
    assert is_binary(customer.id)
    assert customer.id != nil
  end

  test "retrieve/3 returns the same customer by id",
       %{stripe_mock_available: available, client: client} do
    if not available, do: ExUnit.skip("stripe-mock not running on localhost:12111")

    {:ok, created} =
      Customer.create(client, %{"email" => "retrieve@test.com", "name" => "Retrieve Test"})

    {:ok, retrieved} = Customer.retrieve(client, created.id)

    assert %Customer{} = retrieved
    assert retrieved.id == created.id
  end

  test "update/4 returns an updated Customer struct",
       %{stripe_mock_available: available, client: client} do
    if not available, do: ExUnit.skip("stripe-mock not running on localhost:12111")

    {:ok, created} =
      Customer.create(client, %{"email" => "update@test.com", "name" => "Update Test"})

    {:ok, updated} = Customer.update(client, created.id, %{"name" => "Updated"})

    assert %Customer{} = updated
    assert updated.id == created.id
  end

  test "delete/3 returns Customer with deleted: true",
       %{stripe_mock_available: available, client: client} do
    if not available, do: ExUnit.skip("stripe-mock not running on localhost:12111")

    {:ok, created} =
      Customer.create(client, %{"email" => "delete@test.com", "name" => "Delete Test"})

    {:ok, deleted} = Customer.delete(client, created.id)

    assert %Customer{deleted: true} = deleted
  end

  test "list/3 returns a Response with a List", %{
    stripe_mock_available: available,
    client: client
  } do
    if not available, do: ExUnit.skip("stripe-mock not running on localhost:12111")

    {:ok, resp} = Customer.list(client)

    assert %LatticeStripe.Response{} = resp
    assert %LatticeStripe.List{} = resp.data
  end

  test "retrieve/3 with invalid id returns error",
       %{stripe_mock_available: available, client: client} do
    if not available, do: ExUnit.skip("stripe-mock not running on localhost:12111")

    {:error, error} = Customer.retrieve(client, "nonexistent_id_999")

    assert %Error{type: :invalid_request_error} = error
  end
end
