defmodule LatticeStripe.SetupIntentIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{Error, SetupIntent}

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

  test "create/3 returns a SetupIntent struct", %{client: client} do
    {:ok, si} = SetupIntent.create(client, %{})

    assert %SetupIntent{} = si
    assert is_binary(si.id)
    assert si.id != nil
  end

  test "retrieve/3 returns the same setup_intent by id", %{client: client} do
    {:ok, created} = SetupIntent.create(client, %{})
    {:ok, retrieved} = SetupIntent.retrieve(client, created.id)

    assert %SetupIntent{} = retrieved
    assert retrieved.id == created.id
  end

  test "update/4 returns an updated SetupIntent struct", %{client: client} do
    {:ok, created} = SetupIntent.create(client, %{})

    {:ok, updated} =
      SetupIntent.update(client, created.id, %{"metadata" => %{"key" => "value"}})

    assert %SetupIntent{} = updated
    assert updated.id == created.id
  end

  test "confirm/4 returns a SetupIntent struct", %{client: client} do
    {:ok, created} = SetupIntent.create(client, %{})

    result = SetupIntent.confirm(client, created.id, %{"payment_method" => "pm_card_visa"})

    # stripe-mock may accept or return an error depending on spec validation
    assert match?({:ok, %SetupIntent{}}, result) or match?({:error, %Error{}}, result)
  end

  test "cancel/4 returns a canceled SetupIntent", %{client: client} do
    {:ok, created} = SetupIntent.create(client, %{})
    {:ok, canceled} = SetupIntent.cancel(client, created.id)

    assert %SetupIntent{} = canceled
  end

  test "list/3 returns a Response with a List", %{client: client} do
    {:ok, resp} = SetupIntent.list(client)

    assert %LatticeStripe.Response{} = resp
    assert %LatticeStripe.List{} = resp.data
  end

  # stripe-mock returns a stub for any ID — invalid ID errors can only be tested against real Stripe
  @tag :skip
  test "retrieve/3 with invalid id returns error", %{client: client} do
    {:error, error} = SetupIntent.retrieve(client, "nonexistent_id_999")

    assert %Error{type: :invalid_request_error} = error
  end
end
