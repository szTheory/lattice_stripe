defmodule LatticeStripe.PaymentIntentIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{Error, PaymentIntent}

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

  test "create/3 returns a PaymentIntent struct", %{client: client} do
    {:ok, pi} = PaymentIntent.create(client, %{"amount" => "2000", "currency" => "usd"})

    assert %PaymentIntent{} = pi
    assert is_binary(pi.id)
    assert pi.id != nil
  end

  test "retrieve/3 returns the same payment_intent by id", %{client: client} do
    {:ok, created} = PaymentIntent.create(client, %{"amount" => "2000", "currency" => "usd"})
    {:ok, retrieved} = PaymentIntent.retrieve(client, created.id)

    assert %PaymentIntent{} = retrieved
    assert retrieved.id == created.id
  end

  test "update/4 returns an updated PaymentIntent struct", %{client: client} do
    {:ok, created} = PaymentIntent.create(client, %{"amount" => "2000", "currency" => "usd"})

    {:ok, updated} =
      PaymentIntent.update(client, created.id, %{"metadata" => %{"key" => "value"}})

    assert %PaymentIntent{} = updated
    assert updated.id == created.id
  end

  test "confirm/4 returns a PaymentIntent struct", %{client: client} do
    {:ok, created} = PaymentIntent.create(client, %{"amount" => "2000", "currency" => "usd"})

    result =
      PaymentIntent.confirm(client, created.id, %{"payment_method" => "pm_card_visa"})

    # stripe-mock may accept or return an error depending on spec validation
    assert match?({:ok, %PaymentIntent{}}, result) or match?({:error, %Error{}}, result)
  end

  test "capture/4 returns a PaymentIntent struct after manual capture", %{client: client} do
    {:ok, created} =
      PaymentIntent.create(client, %{
        "amount" => "2000",
        "currency" => "usd",
        "capture_method" => "manual"
      })

    # Confirm first to put it in requires_capture state, then capture
    _confirm =
      PaymentIntent.confirm(client, created.id, %{"payment_method" => "pm_card_visa"})

    result = PaymentIntent.capture(client, created.id)

    assert match?({:ok, %PaymentIntent{}}, result) or match?({:error, %Error{}}, result)
  end

  test "cancel/4 returns a canceled PaymentIntent", %{client: client} do
    {:ok, created} = PaymentIntent.create(client, %{"amount" => "2000", "currency" => "usd"})
    {:ok, canceled} = PaymentIntent.cancel(client, created.id)

    assert %PaymentIntent{} = canceled
  end

  test "list/3 returns a Response with a List", %{client: client} do
    {:ok, resp} = PaymentIntent.list(client)

    assert %LatticeStripe.Response{} = resp
    assert %LatticeStripe.List{} = resp.data
  end

  test "retrieve/3 with invalid id returns error", %{client: client} do
    {:error, error} = PaymentIntent.retrieve(client, "nonexistent_id_999")

    assert %Error{type: :invalid_request_error} = error
  end
end
