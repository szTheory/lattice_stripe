defmodule LatticeStripe.Integration.TestClockTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.TestHelpers.TestClock

  # Guard: check stripe-mock connectivity before running any tests in this module.
  # If stripe-mock is not running on localhost:12111, raise with a clear message.
  # Start the Finch pool for real HTTP requests.
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

  describe "TestClock CRUD round-trip against stripe-mock" do
    # NOTE: DO NOT assert polling/advance semantics here.
    # stripe-mock returns a static fixture for /advance, so the polling loop
    # is never exercised. Polling (advance + polling helper) is covered by
    # Mox unit tests in Plan 13-04 and the :real_stripe test in Plan 13-06.

    test "create → retrieve → list → delete", %{client: client} do
      frozen = System.system_time(:second)

      {:ok, created} =
        TestClock.create(client, %{
          "frozen_time" => frozen,
          "name" => "integration-test"
        })

      assert %TestClock{} = created
      assert is_binary(created.id)

      {:ok, fetched} = TestClock.retrieve(client, created.id)
      assert %TestClock{} = fetched
      assert fetched.id == created.id

      {:ok, resp} = TestClock.list(client, %{"limit" => "5"})
      assert %LatticeStripe.Response{} = resp
      assert %LatticeStripe.List{} = resp.data
      assert is_list(resp.data.data)
      assert Enum.all?(resp.data.data, &match?(%TestClock{}, &1))

      {:ok, deleted} = TestClock.delete(client, created.id)
      assert %TestClock{} = deleted
    end

    test "stream!/3 lazily paginates typed %TestClock{} items", %{client: client} do
      stream = TestClock.stream!(client, %{"limit" => "2"})
      first_three = Enum.take(stream, 3)
      assert Enum.all?(first_three, &match?(%TestClock{}, &1))
    end
  end
end
