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

  # ---------------------------------------------------------------
  # Testing.TestClock module-level
  # ---------------------------------------------------------------

  describe "cleanup_marker/0" do
    test "returns the documented marker tuple" do
      assert LatticeStripe.Testing.TestClock.cleanup_marker() ==
               {"lattice_stripe_test_clock", "v1"}
    end
  end

  # ---------------------------------------------------------------
  # use-macro compile-time validation
  # ---------------------------------------------------------------

  describe "use-macro compile-time validation" do
    test "raises KeyError on missing :client option" do
      assert_raise KeyError, fn ->
        Code.compile_string("""
        defmodule TestFailMissing#{System.unique_integer([:positive])} do
          use LatticeStripe.Testing.TestClock, []
        end
        """)
      end
    end

    test "raises CompileError on non-atom :client option" do
      assert_raise CompileError, fn ->
        Code.compile_string("""
        defmodule TestFailBadClient#{System.unique_integer([:positive])} do
          use LatticeStripe.Testing.TestClock, client: "not_a_module"
        end
        """)
      end
    end

    test "compiles with a valid atom :client" do
      # Compiling a module with `use` at runtime proves the macro accepts
      # a valid module atom and injects the expected helper function.
      # We use Module.concat to get the fully-qualified Elixir module name.
      suffix = System.unique_integer([:positive])
      full_name = Module.concat([:"TestUseMacroCompile#{suffix}"])

      modules =
        Code.compile_string("""
        defmodule TestUseMacroCompile#{suffix} do
          use LatticeStripe.Testing.TestClock, client: SomeTestModule
        end
        """)

      {^full_name, binary} = Enum.find(modules, fn {m, _} -> m == full_name end)
      :code.load_binary(full_name, ~c"nofile", binary)

      assert function_exported?(full_name, :__lattice_test_clock_client__, 0)
      assert apply(full_name, :__lattice_test_clock_client__, []) == SomeTestModule
    end
  end

  # ---------------------------------------------------------------
  # Helper function tests (with process dict client binding)
  # ---------------------------------------------------------------

  # We bind the client in process dict for these tests, simulating
  # what the use-macro setup would do in a real CaseTemplate.

  defp clock_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "clock_test_helper",
        "object" => "test_helpers.test_clock",
        "created" => 1_712_900_000,
        "frozen_time" => 1_712_900_000,
        "livemode" => false,
        "name" => "lattice_stripe_test",
        "status" => "ready",
        "status_details" => nil
      },
      overrides
    )
  end

  defp customer_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "cus_test_abc",
        "object" => "customer",
        "email" => "test@example.com"
      },
      overrides
    )
  end

  defp bind_client! do
    client = test_client()
    Process.put(:__lattice_stripe_bound_client__, client)
    client
  end

  defp cleanup_owner do
    case Process.get(:__lattice_stripe_test_clock_owner__) do
      pid when is_pid(pid) ->
        if Process.alive?(pid), do: GenServer.stop(pid)
        Process.delete(:__lattice_stripe_test_clock_owner__)

      _ ->
        :ok
    end
  end

  describe "test_clock/1" do
    setup do
      bind_client!()
      on_exit(fn -> cleanup_owner() end)
      :ok
    end

    test "creates a clock and registers it with the owner" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.ends_with?(req.url, "/v1/test_helpers/test_clocks")
        assert req.body =~ "name=lattice_stripe_test"
        ok_response(clock_json())
      end)

      clock = LatticeStripe.Testing.TestClock.test_clock()

      assert clock.id == "clock_test_helper"
      assert clock.status == :ready

      owner = Process.get(:__lattice_stripe_test_clock_owner__)
      assert Owner.registered(owner) == ["clock_test_helper"]
    end

    test "accepts :frozen_time and :name opts" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.body =~ "frozen_time=1700000000"
        assert req.body =~ "name=my-custom"
        ok_response(clock_json(%{"frozen_time" => 1_700_000_000, "name" => "my-custom"}))
      end)

      clock =
        LatticeStripe.Testing.TestClock.test_clock(
          frozen_time: 1_700_000_000,
          name: "my-custom"
        )

      assert clock.frozen_time == 1_700_000_000
    end

    test "does NOT send metadata to Stripe (A-13g)" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        refute req.body =~ "metadata"
        refute req.body =~ "lattice_stripe_test_clock"
        ok_response(clock_json())
      end)

      _clock = LatticeStripe.Testing.TestClock.test_clock()
    end
  end

  describe "test_clock/1 per-call client override" do
    setup do
      # Bind a bogus client to process dict
      bogus = test_client(api_key: "sk_test_bogus")
      Process.put(:__lattice_stripe_bound_client__, bogus)
      on_exit(fn -> cleanup_owner() end)
      :ok
    end

    test "client: override wins over compile-time binding" do
      override_client = test_client(api_key: "sk_test_override")

      expect(LatticeStripe.MockTransport, :request, fn req ->
        # The authorization header should use the override key
        auth = Enum.find(req.headers, fn {k, _v} -> k == "authorization" end)
        assert {_, "Bearer sk_test_override"} = auth
        ok_response(clock_json())
      end)

      _clock = LatticeStripe.Testing.TestClock.test_clock(client: override_client)
    end
  end

  describe "advance/2 unit_opts parser" do
    setup do
      bind_client!()
      on_exit(fn -> cleanup_owner() end)
      :ok
    end

    defp expect_advance_and_wait!(expected_frozen_time) do
      # First call: advance POST
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert req.url =~ "/advance"
        assert req.body =~ "frozen_time=#{expected_frozen_time}"
        ok_response(clock_json(%{"status" => "advancing", "frozen_time" => expected_frozen_time}))
      end)

      # Second call: retrieve poll (returns ready immediately)
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        ok_response(clock_json(%{"status" => "ready", "frozen_time" => expected_frozen_time}))
      end)
    end

    test "seconds" do
      expect_advance_and_wait!(1_712_900_060)

      clock = %LatticeStripe.TestHelpers.TestClock{
        id: "clock_test_helper",
        frozen_time: 1_712_900_000
      }

      result = LatticeStripe.Testing.TestClock.advance(clock, seconds: 60)
      assert result.status == :ready
    end

    test "minutes" do
      expect_advance_and_wait!(1_712_900_300)

      clock = %LatticeStripe.TestHelpers.TestClock{
        id: "clock_test_helper",
        frozen_time: 1_712_900_000
      }

      result = LatticeStripe.Testing.TestClock.advance(clock, minutes: 5)
      assert result.status == :ready
    end

    test "hours" do
      expect_advance_and_wait!(1_712_907_200)

      clock = %LatticeStripe.TestHelpers.TestClock{
        id: "clock_test_helper",
        frozen_time: 1_712_900_000
      }

      result = LatticeStripe.Testing.TestClock.advance(clock, hours: 2)
      assert result.status == :ready
    end

    test "days" do
      expected = 1_712_900_000 + 30 * 86_400
      expect_advance_and_wait!(expected)

      clock = %LatticeStripe.TestHelpers.TestClock{
        id: "clock_test_helper",
        frozen_time: 1_712_900_000
      }

      result = LatticeStripe.Testing.TestClock.advance(clock, days: 30)
      assert result.status == :ready
    end

    test "to: DateTime" do
      dt = ~U[2026-05-11 00:00:00Z]
      expected = DateTime.to_unix(dt)
      expect_advance_and_wait!(expected)

      clock = %LatticeStripe.TestHelpers.TestClock{
        id: "clock_test_helper",
        frozen_time: 1_712_900_000
      }

      result = LatticeStripe.Testing.TestClock.advance(clock, to: dt)
      assert result.status == :ready
    end

    test "raises on :months (A-13d)" do
      clock = %LatticeStripe.TestHelpers.TestClock{
        id: "c1",
        frozen_time: 1000
      }

      assert_raise ArgumentError, ~r/months.*not supported/, fn ->
        LatticeStripe.Testing.TestClock.advance(clock, months: 1)
      end
    end

    test "raises on :years (A-13d)" do
      clock = %LatticeStripe.TestHelpers.TestClock{
        id: "c1",
        frozen_time: 1000
      }

      assert_raise ArgumentError, ~r/years.*not supported/, fn ->
        LatticeStripe.Testing.TestClock.advance(clock, years: 1)
      end
    end

    test "raises on empty unit_opts" do
      clock = %LatticeStripe.TestHelpers.TestClock{
        id: "c1",
        frozen_time: 1000
      }

      assert_raise ArgumentError, ~r/must contain one of/, fn ->
        LatticeStripe.Testing.TestClock.advance(clock, [])
      end
    end

    test "raises on non-DateTime :to value" do
      clock = %LatticeStripe.TestHelpers.TestClock{
        id: "c1",
        frozen_time: 1000
      }

      assert_raise ArgumentError, ~r/:to must be a DateTime/, fn ->
        LatticeStripe.Testing.TestClock.advance(clock, to: "not a datetime")
      end
    end
  end

  describe "freeze/1" do
    setup do
      bind_client!()
      on_exit(fn -> cleanup_owner() end)
      :ok
    end

    test "calls advance_and_wait! with the current frozen_time (no-op advance)" do
      # advance POST with frozen_time = current (42)
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert req.url =~ "/advance"
        assert req.body =~ "frozen_time=42"
        ok_response(clock_json(%{"status" => "advancing", "frozen_time" => 42}))
      end)

      # retrieve poll returns ready
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        ok_response(clock_json(%{"status" => "ready", "frozen_time" => 42}))
      end)

      clock = %LatticeStripe.TestHelpers.TestClock{
        id: "clock_test_helper",
        frozen_time: 42
      }

      result = LatticeStripe.Testing.TestClock.freeze(clock)
      assert result.status == :ready
    end
  end

  describe "create_customer/2,3 (D-13h)" do
    setup do
      bind_client!()
      on_exit(fn -> cleanup_owner() end)
      :ok
    end

    test "auto-injects test_clock: clock.id into params" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert req.url =~ "/v1/customers"
        assert req.body =~ "test_clock=clock_abc"
        ok_response(customer_json())
      end)

      clock = %LatticeStripe.TestHelpers.TestClock{
        id: "clock_abc",
        frozen_time: 1000
      }

      customer = LatticeStripe.Testing.TestClock.create_customer(clock)
      assert customer.id == "cus_test_abc"
    end

    test "preserves user-supplied params alongside the injected test_clock" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.body =~ "test_clock=clock_abc"
        assert req.body =~ "email=user"
        ok_response(customer_json(%{"email" => "user@test.com"}))
      end)

      clock = %LatticeStripe.TestHelpers.TestClock{
        id: "clock_abc",
        frozen_time: 1000
      }

      customer =
        LatticeStripe.Testing.TestClock.create_customer(clock, %{email: "user@test.com"})

      assert customer.email == "user@test.com"
    end

    test "accepts keyword list params" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.body =~ "test_clock=clock_abc"
        assert req.body =~ "name=Jane"
        ok_response(customer_json())
      end)

      clock = %LatticeStripe.TestHelpers.TestClock{
        id: "clock_abc",
        frozen_time: 1000
      }

      _customer = LatticeStripe.Testing.TestClock.create_customer(clock, name: "Jane")
    end
  end

  describe "with_test_clock/1 setup callback" do
    setup do
      bind_client!()
      on_exit(fn -> cleanup_owner() end)
      :ok
    end

    test "returns {:ok, context} with :test_clock injected" do
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert req.url =~ "/v1/test_helpers/test_clocks"
        ok_response(clock_json())
      end)

      assert {:ok, context} =
               LatticeStripe.Testing.TestClock.with_test_clock(%{foo: :bar})

      assert context.foo == :bar
      assert %LatticeStripe.TestHelpers.TestClock{} = context.test_clock
      assert context.test_clock.id == "clock_test_helper"
    end
  end

  describe "client resolution" do
    test "raises TestClockError when no client bound and none passed" do
      # Ensure clean process dict
      Process.delete(:__lattice_stripe_bound_client__)
      Process.delete(:__lattice_stripe_test_clock_owner__)

      assert_raise TestClockError, ~r/No LatticeStripe client is bound/, fn ->
        LatticeStripe.Testing.TestClock.test_clock()
      end
    end
  end
end
