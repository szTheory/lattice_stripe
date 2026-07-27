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

  describe "start_default_finch opt-out (SC-4)" do
    # Assert on the boot-decision function in isolation rather than stopping and
    # restarting the already-booted real pool mid-suite (fragile per RESEARCH
    # Wave 0 Gaps). on_exit restores prior env so other tests are unaffected.
    setup do
      prior = Application.fetch_env(:lattice_stripe, :start_default_finch)

      on_exit(fn ->
        case prior do
          {:ok, value} -> Application.put_env(:lattice_stripe, :start_default_finch, value)
          :error -> Application.delete_env(:lattice_stripe, :start_default_finch)
        end
      end)

      :ok
    end

    test "default (unset) yields a single Finch child spec" do
      Application.delete_env(:lattice_stripe, :start_default_finch)
      children = LatticeStripe.Application.default_finch_children()

      assert [{Finch, opts}] = children
      assert opts[:name] == LatticeStripe.Finch
    end

    test "start_default_finch: true yields a single Finch child spec" do
      Application.put_env(:lattice_stripe, :start_default_finch, true)
      children = LatticeStripe.Application.default_finch_children()

      assert [{Finch, opts}] = children
      assert opts[:name] == LatticeStripe.Finch
    end

    test "start_default_finch: false yields an empty children list" do
      Application.put_env(:lattice_stripe, :start_default_finch, false)
      assert LatticeStripe.Application.default_finch_children() == []
    end
  end
end
