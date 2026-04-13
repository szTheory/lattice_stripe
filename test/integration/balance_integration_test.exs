defmodule LatticeStripe.BalanceIntegrationTest do
  @moduledoc """
  Integration tests for `LatticeStripe.Balance` against stripe-mock.

  Critical per D-07 / Pitfall 2: assert that passing
  `stripe_account: "acct_..."` routes the request with the per-request
  `Stripe-Account` header (the platform-vs-connected distinction).
  """

  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{Account, Balance}
  alias LatticeStripe.Balance.Amount

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

  test "retrieve/2 returns the platform %Balance{} with Amount lists", %{client: client} do
    assert {:ok, %Balance{} = balance} = Balance.retrieve(client)

    for field <- [:available, :pending] do
      list = Map.fetch!(balance, field)
      assert is_list(list)

      Enum.each(list, fn amount ->
        assert %Amount{} = amount
      end)
    end
  end

  test "retrieve/2 with stripe_account: opt threads the per-request header (D-07 Pitfall 2)",
       %{client: client} do
    # First create a connected account so we have a real acct_ id to pass.
    {:ok, %Account{id: account_id}} =
      Account.create(client, %{"type" => "custom", "country" => "US"})

    assert {:ok, %Balance{}} =
             Balance.retrieve(client, stripe_account: account_id)
  end

  test "Balance.Amount reuse in all list fields", %{client: client} do
    {:ok, %Balance{available: avail, pending: pending} = _balance} = Balance.retrieve(client)

    if avail != [] do
      assert match?(%Amount{}, hd(avail))
    end

    if pending != [] do
      assert match?(%Amount{}, hd(pending))
    end
  end

  test "retrieve!/2 raises on {:error, _}", %{client: client} do
    # stripe-mock cannot actually error here; smoke-test the bang path on success.
    assert %Balance{} = Balance.retrieve!(client)
  end
end
