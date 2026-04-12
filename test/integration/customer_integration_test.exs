defmodule LatticeStripe.CustomerIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestSupport

  @moduletag :integration

  alias LatticeStripe.{Customer, Error}

  # Guard: check stripe-mock connectivity before running any tests in this module.
  # If stripe-mock is not running on localhost:12111, all tests are skipped via
  # the invalid-setup mechanism. Start the Finch pool for real HTTP requests.
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

  test "create/3 returns a Customer struct", %{client: client} do
    {:ok, customer} =
      Customer.create(client, %{"email" => "integration@test.com", "name" => "Integration Test"})

    assert %Customer{} = customer
    assert is_binary(customer.id)
    assert customer.id != nil
  end

  test "retrieve/3 returns the same customer by id", %{client: client} do
    {:ok, created} =
      Customer.create(client, %{"email" => "retrieve@test.com", "name" => "Retrieve Test"})

    {:ok, retrieved} = Customer.retrieve(client, created.id)

    assert %Customer{} = retrieved
    assert retrieved.id == created.id
  end

  test "update/4 returns an updated Customer struct", %{client: client} do
    {:ok, created} =
      Customer.create(client, %{"email" => "update@test.com", "name" => "Update Test"})

    {:ok, updated} = Customer.update(client, created.id, %{"name" => "Updated"})

    assert %Customer{} = updated
    assert updated.id == created.id
  end

  test "delete/3 returns Customer with deleted: true", %{client: client} do
    {:ok, created} =
      Customer.create(client, %{"email" => "delete@test.com", "name" => "Delete Test"})

    {:ok, deleted} = Customer.delete(client, created.id)

    assert %Customer{deleted: true} = deleted
  end

  test "list/3 returns a Response with a List", %{client: client} do
    {:ok, resp} = Customer.list(client)

    assert %LatticeStripe.Response{} = resp
    assert %LatticeStripe.List{} = resp.data
  end

  # stripe-mock returns a stub for any ID — invalid ID errors can only be tested against real Stripe
  @tag :skip
  test "retrieve/3 with invalid id returns error", %{client: client} do
    {:error, error} = Customer.retrieve(client, "nonexistent_id_999")

    assert %Error{type: :invalid_request_error} = error
  end
end
