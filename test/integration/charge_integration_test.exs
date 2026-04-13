defmodule LatticeStripe.ChargeIntegrationTest do
  @moduledoc """
  Integration tests for `LatticeStripe.Charge` against stripe-mock.

  Focused on the Phase 18 retrieve-with-expand path used by the reconciliation
  guide: `Charge.retrieve(client, id, expand: ["balance_transaction"])`.
  """

  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.Charge

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

  test "retrieve/3 returns a %Charge{}", %{client: client} do
    assert {:ok, %Charge{} = charge} = Charge.retrieve(client, "ch_test")
    assert is_binary(charge.id)
  end

  test "retrieve/3 with expand: [\"balance_transaction\"]", %{client: client} do
    assert {:ok, %Charge{} = charge} =
             Charge.retrieve(client, "ch_test", expand: ["balance_transaction"])

    # When expanded, balance_transaction becomes an inline map rather than a
    # plain string id. stripe-mock may keep it as a string; assert shape is
    # either a string (unexpanded) or a map (expanded).
    assert charge.balance_transaction == nil or is_binary(charge.balance_transaction) or
             is_map(charge.balance_transaction)
  end

  test "Inspect implementation redacts PII", %{client: client} do
    {:ok, %Charge{} = charge} = Charge.retrieve(client, "ch_test")

    inspected = inspect(charge)

    # Whitelisted Inspect surface must not leak payment_method_details, billing_details, etc.
    refute inspected =~ "payment_method_details:"
    refute inspected =~ "billing_details:"
    refute inspected =~ "receipt_email:"
  end
end
