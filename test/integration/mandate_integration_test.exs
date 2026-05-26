defmodule LatticeStripe.MandateIntegrationTest do
  @moduledoc """
  Integration tests for `LatticeStripe.Mandate` against stripe-mock.

  These assertions prove request routing and typed decode sanity only.
  `stripe-mock` does not model full Mandate lifecycle semantics or persisted
  Stripe state.
  """

  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.Mandate

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

  test "retrieve/3 returns a typed %Mandate{} with a binary id", %{client: client} do
    assert {:ok, %Mandate{id: id} = mandate} =
             Mandate.retrieve(client, "mandate_test1234567890abc")

    assert is_binary(id)
    assert String.starts_with?(id, "mandate_")
    assert %Mandate{} = mandate
  end
end
