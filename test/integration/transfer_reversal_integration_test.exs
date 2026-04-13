defmodule LatticeStripe.TransferReversalIntegrationTest do
  @moduledoc """
  Integration tests for `LatticeStripe.TransferReversal` against stripe-mock.
  """

  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{Transfer, TransferReversal}

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
    client = test_integration_client()

    {:ok, %Transfer{id: transfer_id}} =
      Transfer.create(client, %{
        "amount" => 1000,
        "currency" => "usd",
        "destination" => "acct_test"
      })

    {:ok, client: client, transfer_id: transfer_id}
  end

  test "create/4 returns a %TransferReversal{}", %{client: client, transfer_id: tid} do
    assert {:ok, %TransferReversal{id: id}} =
             TransferReversal.create(client, tid, %{"amount" => 100})

    assert is_binary(id)
  end

  test "retrieve/4 round-trips a reversal id", %{client: client, transfer_id: tid} do
    {:ok, %TransferReversal{id: rid}} =
      TransferReversal.create(client, tid, %{"amount" => 100})

    assert {:ok, %TransferReversal{}} = TransferReversal.retrieve(client, tid, rid)
  end

  test "list/4 returns wrapped list of reversals", %{client: client, transfer_id: tid} do
    assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{data: data}}} =
             TransferReversal.list(client, tid, %{"limit" => 5})

    assert is_list(data)
    Enum.each(data, fn r -> assert %TransferReversal{} = r end)
  end

  test "stream!/4 composes with Enum.take/2", %{client: client, transfer_id: tid} do
    rs = TransferReversal.stream!(client, tid, %{"limit" => 2}) |> Enum.take(3)
    assert is_list(rs)
    Enum.each(rs, fn r -> assert %TransferReversal{} = r end)
  end
end
