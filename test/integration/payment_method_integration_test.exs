defmodule LatticeStripe.PaymentMethodIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{Customer, Error, PaymentMethod}

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

  defp card_params do
    %{
      "type" => "card",
      "card" => %{
        "number" => "4242424242424242",
        "exp_month" => "12",
        "exp_year" => "2030",
        "cvc" => "123"
      }
    }
  end

  test "create/3 returns a PaymentMethod struct", %{client: client} do
    {:ok, pm} = PaymentMethod.create(client, card_params())

    assert %PaymentMethod{} = pm
    assert is_binary(pm.id)
    assert pm.id != nil
  end

  test "retrieve/3 returns the same payment_method by id", %{client: client} do
    {:ok, created} = PaymentMethod.create(client, card_params())
    {:ok, retrieved} = PaymentMethod.retrieve(client, created.id)

    assert %PaymentMethod{} = retrieved
    assert retrieved.id == created.id
  end

  test "update/4 returns an updated PaymentMethod struct", %{client: client} do
    {:ok, created} = PaymentMethod.create(client, card_params())

    {:ok, updated} =
      PaymentMethod.update(client, created.id, %{"metadata" => %{"key" => "value"}})

    assert %PaymentMethod{} = updated
    assert updated.id == created.id
  end

  test "attach/4 attaches payment method to customer", %{client: client} do
    {:ok, pm} = PaymentMethod.create(client, card_params())
    {:ok, customer} = Customer.create(client, %{"email" => "attach@test.com"})

    result = PaymentMethod.attach(client, pm.id, %{"customer" => customer.id})

    assert match?({:ok, %PaymentMethod{}}, result) or match?({:error, %Error{}}, result)
  end

  test "detach/3 detaches payment method from customer", %{client: client} do
    {:ok, pm} = PaymentMethod.create(client, card_params())
    {:ok, customer} = Customer.create(client, %{"email" => "detach@test.com"})
    _attach = PaymentMethod.attach(client, pm.id, %{"customer" => customer.id})

    result = PaymentMethod.detach(client, pm.id)

    assert match?({:ok, %PaymentMethod{}}, result) or match?({:error, %Error{}}, result)
  end

  test "list/3 returns a Response with a List", %{client: client} do
    {:ok, customer} = Customer.create(client, %{"email" => "list@test.com"})

    {:ok, resp} =
      PaymentMethod.list(client, %{"customer" => customer.id, "type" => "card"})

    assert %LatticeStripe.Response{} = resp
    assert %LatticeStripe.List{} = resp.data
  end

  test "retrieve/3 with invalid id returns error", %{client: client} do
    {:error, error} = PaymentMethod.retrieve(client, "nonexistent_id_999")

    assert %Error{type: :invalid_request_error} = error
  end
end
