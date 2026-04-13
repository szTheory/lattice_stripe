defmodule LatticeStripe.BalanceTransactionIntegrationTest do
  @moduledoc """
  Integration tests for `LatticeStripe.BalanceTransaction` against stripe-mock.

  Exercises the reconciliation surface: retrieve, list, payout filter, and
  the `fee_details` decoding into `%BalanceTransaction.FeeDetail{}`.
  """

  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.BalanceTransaction
  alias LatticeStripe.BalanceTransaction.FeeDetail

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

  test "retrieve/3 returns a %BalanceTransaction{} with fee_details list", %{client: client} do
    assert {:ok, %BalanceTransaction{} = bt} =
             BalanceTransaction.retrieve(client, "txn_test")

    assert is_list(bt.fee_details) or is_nil(bt.fee_details)

    if is_list(bt.fee_details) do
      Enum.each(bt.fee_details, fn fd -> assert %FeeDetail{} = fd end)
    end
  end

  test "list/3 returns wrapped list of balance transactions", %{client: client} do
    assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{data: data}}} =
             BalanceTransaction.list(client, %{"limit" => 5})

    assert is_list(data)
    Enum.each(data, fn bt -> assert %BalanceTransaction{} = bt end)
  end

  test "list/3 with payout filter", %{client: client} do
    assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{data: data}}} =
             BalanceTransaction.list(client, %{"payout" => "po_test", "limit" => 5})

    assert is_list(data)
  end

  test "stream!/3 composes with Enum.take/2", %{client: client} do
    bts = BalanceTransaction.stream!(client, %{"limit" => 2}) |> Enum.take(5)
    assert is_list(bts)
    Enum.each(bts, fn bt -> assert %BalanceTransaction{} = bt end)
  end

  test "reconciliation pattern: filter fee_details by type", %{client: client} do
    {:ok, %BalanceTransaction{} = bt} = BalanceTransaction.retrieve(client, "txn_test")

    app_fees =
      case bt.fee_details do
        list when is_list(list) -> Enum.filter(list, &(&1.type == "application_fee"))
        _ -> []
      end

    assert is_list(app_fees)
  end
end
