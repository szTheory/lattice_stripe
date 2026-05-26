defmodule LatticeStripe.SetupAttemptIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.SetupAttempt

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

  test "list/3 returns a Response with a List", %{client: client} do
    {:ok, resp} = SetupAttempt.list(client, %{"setup_intent" => "seti_test1234567890abc"})

    assert %LatticeStripe.Response{} = resp
    assert %LatticeStripe.List{} = resp.data
  end

  test "stream!/3 returns SetupAttempt structs", %{client: client} do
    attempts =
      SetupAttempt.stream!(client, %{"setup_intent" => "seti_test1234567890abc"})
      |> Enum.take(3)

    assert attempts != []
    assert Enum.all?(attempts, &match?(%SetupAttempt{}, &1))
  end

  test "stream!/3 missing setup_intent still raises locally", %{client: client} do
    assert_raise ArgumentError, ~r/requires a "setup_intent" key/, fn ->
      SetupAttempt.stream!(client, %{}) |> Enum.to_list()
    end
  end
end
