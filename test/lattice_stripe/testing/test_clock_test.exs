defmodule LatticeStripe.Testing.TestClockTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestSupport

  alias LatticeStripe.Testing.TestClock.Owner
  alias LatticeStripe.Testing.TestClockError

  setup :verify_on_exit!

  describe "TestClockError" do
    test "is an Exception with :message and :type" do
      err = %TestClockError{message: "bad", type: :metadata_limit}
      assert is_binary(Exception.message(err))
      assert err.type == :metadata_limit
    end

    test "can be raised with a string message" do
      assert_raise TestClockError, "bad", fn -> raise TestClockError, "bad" end
    end

    test "can be raised with a keyword list including :type" do
      assert_raise TestClockError, fn ->
        raise TestClockError, message: "bad", type: :no_client_bound
      end
    end
  end

  describe "Owner lifecycle" do
    test "start_owner!/0 returns a live pid" do
      pid = Owner.start_owner!()
      assert is_pid(pid)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "register/2 appends clock ids in registration order" do
      pid = Owner.start_owner!()
      :ok = Owner.register(pid, "clock_a")
      :ok = Owner.register(pid, "clock_b")
      :ok = Owner.register(pid, "clock_c")

      assert Owner.registered(pid) == ["clock_a", "clock_b", "clock_c"]
      GenServer.stop(pid)
    end

    test "cleanup/2 deletes each registered clock and stops the owner" do
      pid = Owner.start_owner!()
      :ok = Owner.register(pid, "clock_a")
      :ok = Owner.register(pid, "clock_b")

      client = test_client()

      expect(LatticeStripe.MockTransport, :request, 2, fn req ->
        assert req.method == :delete
        assert req.url =~ ~r|/v1/test_helpers/test_clocks/clock_[ab]|
        ok_response(%{
          "id" => "clock_a",
          "object" => "test_helpers.test_clock",
          "deleted" => true
        })
      end)

      assert :ok = Owner.cleanup(pid, client)
      refute Process.alive?(pid)
    end

    test "cleanup/2 swallows errors from individual delete calls" do
      pid = Owner.start_owner!()
      :ok = Owner.register(pid, "clock_x")

      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response()
      end)

      assert :ok = Owner.cleanup(pid, client)
      refute Process.alive?(pid)
    end

    test "cleanup/2 on empty owner stops the owner without any HTTP calls" do
      pid = Owner.start_owner!()
      client = test_client()

      # No Mox expectations — if cleanup called delete, Mox.verify_on_exit! would fail.
      assert :ok = Owner.cleanup(pid, client)
      refute Process.alive?(pid)
    end

    test "multiple owners are independent (async safety)" do
      pid_a = Owner.start_owner!()
      pid_b = Owner.start_owner!()

      :ok = Owner.register(pid_a, "clock_a1")
      :ok = Owner.register(pid_b, "clock_b1")

      assert Owner.registered(pid_a) == ["clock_a1"]
      assert Owner.registered(pid_b) == ["clock_b1"]

      GenServer.stop(pid_a)
      GenServer.stop(pid_b)
    end
  end
end
