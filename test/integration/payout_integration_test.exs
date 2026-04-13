defmodule LatticeStripe.PayoutIntegrationTest do
  @moduledoc """
  Integration tests for `LatticeStripe.Payout` against stripe-mock.

  Exercises the D-03 `expand: ["balance_transaction"]` path on cancel, and the
  full payout lifecycle surface. stripe-mock's state-machine enforcement is
  loose, so assertions target the wire shape rather than post-cancel state.
  """

  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.Payout
  alias LatticeStripe.Payout.TraceId

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

  test "create/3 returns a %Payout{} with optional TraceId struct", %{client: client} do
    assert {:ok, %Payout{id: id} = payout} =
             Payout.create(client, %{"amount" => 500, "currency" => "usd"})

    assert is_binary(id)

    if payout.trace_id do
      assert %TraceId{} = payout.trace_id
    end
  end

  test "retrieve/3 round-trips a payout id", %{client: client} do
    {:ok, %Payout{id: id}} =
      Payout.create(client, %{"amount" => 500, "currency" => "usd"})

    assert {:ok, %Payout{}} = Payout.retrieve(client, id)
  end

  test "update/4 with metadata returns %Payout{}", %{client: client} do
    {:ok, %Payout{id: id}} =
      Payout.create(client, %{"amount" => 500, "currency" => "usd"})

    assert {:ok, %Payout{}} =
             Payout.update(client, id, %{"metadata" => %{"phase" => "18"}})
  end

  test "list/3 returns wrapped list of payouts", %{client: client} do
    assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{data: data}}} =
             Payout.list(client, %{"limit" => 5})

    assert is_list(data)
    Enum.each(data, fn p -> assert %Payout{} = p end)
  end

  test "stream!/3 composes with Enum.take/2", %{client: client} do
    payouts = Payout.stream!(client, %{"limit" => 2}) |> Enum.take(5)
    assert is_list(payouts)
    Enum.each(payouts, fn p -> assert %Payout{} = p end)
  end

  test "cancel/3 ergonomic path with no params", %{client: client} do
    {:ok, %Payout{id: id}} =
      Payout.create(client, %{"amount" => 500, "currency" => "usd"})

    case Payout.cancel(client, id) do
      {:ok, %Payout{}} -> :ok
      {:error, %LatticeStripe.Error{type: :invalid_request_error}} -> :ok
    end
  end

  test "cancel/4 with expand: [\"balance_transaction\"] (D-03)", %{client: client} do
    {:ok, %Payout{id: id}} =
      Payout.create(client, %{"amount" => 500, "currency" => "usd"})

    case Payout.cancel(client, id, %{}, expand: ["balance_transaction"]) do
      {:ok, %Payout{}} -> :ok
      {:error, %LatticeStripe.Error{type: :invalid_request_error}} -> :ok
    end
  end

  test "reverse/4 with metadata", %{client: client} do
    {:ok, %Payout{id: id}} =
      Payout.create(client, %{"amount" => 500, "currency" => "usd"})

    case Payout.reverse(client, id, %{"metadata" => %{"reason" => "test"}}) do
      {:ok, %Payout{}} -> :ok
      {:error, %LatticeStripe.Error{type: :invalid_request_error}} -> :ok
    end
  end
end
