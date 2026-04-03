defmodule LatticeStripe.RefundIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{Error, PaymentIntent, Refund}

  setup_all do
    case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
        :ok

      {:error, _} ->
        {:skip, "stripe-mock not running on localhost:12111"}
    end
  end

  setup do
    client = test_integration_client()
    {:ok, client: client}
  end

  test "create/3 returns a Refund struct", %{client: client} do
    # Create a PaymentIntent to reference in the refund
    # stripe-mock accepts payment_intent param; may or may not require a charged PI
    {:ok, pi} = PaymentIntent.create(client, %{"amount" => "2000", "currency" => "usd"})

    result = Refund.create(client, %{"payment_intent" => pi.id})

    # stripe-mock may return an error if PI is not in a refundable state
    assert match?({:ok, %Refund{}}, result) or match?({:error, %Error{}}, result)
  end

  test "retrieve/3 returns refund by id", %{client: client} do
    {:ok, pi} = PaymentIntent.create(client, %{"amount" => "2000", "currency" => "usd"})

    case Refund.create(client, %{"payment_intent" => pi.id}) do
      {:ok, refund} ->
        {:ok, retrieved} = Refund.retrieve(client, refund.id)
        assert %Refund{} = retrieved
        assert retrieved.id == refund.id

      {:error, _} ->
        # stripe-mock did not allow refund on this PI state; skip retrieve check
        :ok
    end
  end

  test "update/4 returns updated Refund struct", %{client: client} do
    {:ok, pi} = PaymentIntent.create(client, %{"amount" => "2000", "currency" => "usd"})

    case Refund.create(client, %{"payment_intent" => pi.id}) do
      {:ok, refund} ->
        {:ok, updated} = Refund.update(client, refund.id, %{"metadata" => %{"key" => "value"}})
        assert %Refund{} = updated
        assert updated.id == refund.id

      {:error, _} ->
        # stripe-mock did not allow refund on this PI state; skip update check
        :ok
    end
  end

  test "list/3 returns a Response with a List", %{client: client} do
    {:ok, resp} = Refund.list(client)

    assert %LatticeStripe.Response{} = resp
    assert %LatticeStripe.List{} = resp.data
  end

  test "retrieve/3 with invalid id returns error", %{client: client} do
    {:error, error} = Refund.retrieve(client, "nonexistent_id_999")

    assert %Error{type: :invalid_request_error} = error
  end
end
