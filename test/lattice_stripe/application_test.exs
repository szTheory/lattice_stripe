defmodule LatticeStripe.ApplicationTest do
  # async: false — asserts on the process-global default Finch pool and toggles
  # application env, which must not race with other async test files.
  use ExUnit.Case, async: false

  alias LatticeStripe.Client

  describe "default Finch pool (end-to-end)" do
    test "the LatticeStripe.Finch pool is running after application boot" do
      pid = Process.whereis(LatticeStripe.Finch)
      assert is_pid(pid)
    end

    test "Client.new!/1 with no :finch resolves to the default LatticeStripe.Finch pool" do
      client = Client.new!(api_key: "sk_test_x")
      assert %Client{} = client
      assert client.finch == LatticeStripe.Finch
    end
  end
end
