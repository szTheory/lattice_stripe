defmodule LatticeStripe.TransferIntegrationTest do
  @moduledoc """
  Integration tests for `LatticeStripe.Transfer` against stripe-mock.
  Asserts wire shape: URL, verb, request body, Response/List unwrap.
  """

  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.Transfer

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

  test "create/3 returns a %Transfer{} with id", %{client: client} do
    assert {:ok, %Transfer{id: id} = transfer} =
             Transfer.create(client, %{
               "amount" => 1000,
               "currency" => "usd",
               "destination" => "acct_test"
             })

    assert is_binary(id)
    assert is_list(transfer.reversals)
  end

  test "retrieve/3 round-trips a transfer id", %{client: client} do
    {:ok, %Transfer{id: id}} =
      Transfer.create(client, %{
        "amount" => 1000,
        "currency" => "usd",
        "destination" => "acct_test"
      })

    assert {:ok, %Transfer{}} = Transfer.retrieve(client, id)
  end

  test "update/4 with metadata returns %Transfer{}", %{client: client} do
    {:ok, %Transfer{id: id}} =
      Transfer.create(client, %{
        "amount" => 1000,
        "currency" => "usd",
        "destination" => "acct_test"
      })

    assert {:ok, %Transfer{}} =
             Transfer.update(client, id, %{"metadata" => %{"source" => "phase18"}})
  end

  test "list/3 returns wrapped list of transfers", %{client: client} do
    assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{data: data}}} =
             Transfer.list(client, %{"limit" => 5})

    assert is_list(data)
    Enum.each(data, fn t -> assert %Transfer{} = t end)
  end

  test "stream!/3 composes with Enum.take/2", %{client: client} do
    transfers = Transfer.stream!(client, %{"limit" => 2}) |> Enum.take(5)
    assert is_list(transfers)
    Enum.each(transfers, fn t -> assert %Transfer{} = t end)
  end

  test "separate-charge-and-transfer params shape (transfer_group)", %{client: client} do
    # CNCT-03: exercise the params shape for the separate-charge-and-transfer
    # idiom. stripe-mock ignores `source_transaction` validity but must accept
    # the params shape.
    assert {:ok, %Transfer{}} =
             Transfer.create(client, %{
               "amount" => 1200,
               "currency" => "usd",
               "destination" => "acct_test",
               "transfer_group" => "ORDER_42",
               "source_transaction" => "ch_test_123"
             })
  end
end
