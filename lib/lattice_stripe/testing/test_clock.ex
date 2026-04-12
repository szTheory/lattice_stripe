defmodule LatticeStripe.Testing.TestClock do
  @moduledoc """
  ExUnit ergonomics for Stripe Test Clocks.

  This module provides a `use`-macro that users opt into from their own
  `ExUnit.CaseTemplate`. It wraps `LatticeStripe.TestHelpers.TestClock`
  with automatic per-test cleanup (via a lightweight GenServer Owner),
  automatic customer-to-clock linkage (closing the silent-correctness
  footgun of forgetting `test_clock:` on `Customer.create/2`), and a
  human-friendly `advance/2` that takes time units.

  ## Usage

      defmodule MyApp.StripeCase do
        use ExUnit.CaseTemplate

        using do
          quote do
            use LatticeStripe.Testing.TestClock, client: MyApp.StripeClient
          end
        end
      end

      defmodule MyApp.BillingTest do
        use MyApp.StripeCase, async: true
        setup :with_test_clock

        test "sub renews after 30 days", %{test_clock: clock} do
          customer = create_customer(clock, email: "a@b.c")
          {:ok, sub} = MyApp.Billing.subscribe(customer, "price_monthly")
          advance(clock, days: 30)
          assert {:ok, %{status: "active"}} = MyApp.Billing.get_subscription(sub.id)
        end
      end

  ## Client contract

  The module passed as `:client` must be either:

  - A `%LatticeStripe.Client{}` struct directly, or
  - A module atom that exposes a public `stripe_client/0` function returning
    a `%LatticeStripe.Client{}`.

  Every helper also accepts a per-call `:client` option (a `%Client{}` struct)
  that wins over the compile-time binding. This supports multi-account tests.

  ## Cleanup strategy

  Every clock created via `test_clock/1` is registered with a per-test
  `LatticeStripe.Testing.TestClock.Owner` GenServer. On test exit
  (including crash / assertion failure), the Owner deletes each
  registered clock via `LatticeStripe.TestHelpers.TestClock.delete/3`.
  Stripe's delete cascades to attached Customers and Subscriptions.

  For SIGKILL / BEAM crash / CI timeout scenarios that bypass `on_exit`,
  the `mix lattice_stripe.test_clock.cleanup` task backstops by deleting
  test clocks older than a configurable threshold.

  ## Metadata marker (A-13g caveat)

  Stripe's Test Clock API does **not** support `metadata` on create
  (verified via OpenAPI spec and stripe-mock on 2026-04-11). This means
  the Mix task cleanup backstop uses **age-based filtering only** and
  cannot distinguish LatticeStripe-managed clocks from user-created ones.
  The primary cleanup path (Owner + `on_exit`) is unaffected.

  If Stripe adds metadata support in the future, this module will be
  updated to tag clocks with a marker for precise Mix task filtering.

  ## Supported advance units (v1)

  `advance/2` accepts: `:seconds`, `:minutes`, `:hours`, `:days`, or `:to`
  (absolute `DateTime`). Passing `:months` or `:years` raises
  `ArgumentError` -- Elixir 1.15 (the project minimum) has no calendar
  shift helper, and month-length arithmetic is fiddly. For month/year
  advancement, use:

      advance(clock, to: DateTime.utc_now() |> DateTime.add(86_400 * 30, :second))

  ## Customer-to-clock linkage (D-13h)

  `create_customer/2,3` auto-injects `test_clock: clock.id` into the
  customer creation params. This closes the silent-correctness footgun
  where forgetting `test_clock:` means the customer runs on real time
  and clock advances have no effect. Users who bypass this wrapper and
  call `LatticeStripe.Customer.create/2` directly are responsible for
  injecting the `test_clock` param themselves.
  """

  alias LatticeStripe.TestHelpers.TestClock, as: Backend
  alias LatticeStripe.Testing.TestClock.Owner
  alias LatticeStripe.Testing.TestClockError

  # Internal identifier for documentation purposes. Not sent to Stripe
  # because the Test Clock API does not support metadata (A-13g).
  @cleanup_marker {"lattice_stripe_test_clock", "v1"}

  @doc false
  def cleanup_marker, do: @cleanup_marker

  # -------------------------------------------------------------------
  # __using__ macro
  # -------------------------------------------------------------------

  @doc false
  defmacro __using__(opts) do
    client = Keyword.fetch!(opts, :client)

    # In a macro, module aliases arrive as {:__aliases__, _, segments} AST
    # tuples, not as literal atoms. Validate that the value is either a
    # literal atom or an alias tuple; reject everything else.
    unless is_atom(client) or match?({:__aliases__, _, _}, client) do
      raise CompileError,
        description:
          "LatticeStripe.Testing.TestClock requires :client to be a module atom " <>
            "(e.g., MyApp.StripeClient), got: #{inspect(client)}"
    end

    quote do
      import LatticeStripe.Testing.TestClock,
        only: [
          test_clock: 0,
          test_clock: 1,
          advance: 2,
          freeze: 1,
          freeze: 2,
          create_customer: 2,
          create_customer: 3,
          with_test_clock: 1
        ]

      @__lattice_test_clock_client__ unquote(client)

      @doc false
      def __lattice_test_clock_client__, do: @__lattice_test_clock_client__
    end
  end

  # -------------------------------------------------------------------
  # Public helpers
  # -------------------------------------------------------------------

  @doc """
  Creates a test clock and registers it for automatic cleanup.

  ## Options

  - `:frozen_time` -- unix timestamp integer (default: current system time)
  - `:name` -- human-readable name (default: `"lattice_stripe_test"`)
  - `:client` -- per-call client override (`%LatticeStripe.Client{}`)

  ## Example

      clock = test_clock(frozen_time: ~U[2026-01-01 00:00:00Z] |> DateTime.to_unix())
  """
  def test_clock(opts \\ []) do
    client = resolve_client!(opts)
    owner = ensure_owner!(client)

    params = %{
      frozen_time: Keyword.get(opts, :frozen_time, System.system_time(:second)),
      name: Keyword.get(opts, :name, "lattice_stripe_test")
    }

    {:ok, clock} = Backend.create(client, params)
    :ok = Owner.register(owner, clock.id)
    clock
  end

  @doc """
  Advances a test clock by a given unit, waiting until `:ready`.

  ## Supported units (v1)

  - `[seconds: N]`
  - `[minutes: N]`
  - `[hours: N]`
  - `[days: N]`
  - `[to: %DateTime{}]` -- absolute target

  `[months: N]` and `[years: N]` raise `ArgumentError` -- Elixir 1.15 has
  no calendar shift helper. Use `[to: DateTime]` with hand-computed month
  math if needed.

  ## Example

      advance(clock, days: 30)
  """
  def advance(clock, unit_opts) when is_list(unit_opts) do
    client = resolve_client!(unit_opts)
    new_frozen_time = compute_frozen_time!(clock, unit_opts)
    Backend.advance_and_wait!(client, clock.id, new_frozen_time)
  end

  @doc """
  Waits for a test clock to reach `:ready` at its current `frozen_time`.
  Useful after out-of-band clock ops.
  """
  def freeze(clock, opts \\ []) do
    client = resolve_client!(opts)
    Backend.advance_and_wait!(client, clock.id, clock.frozen_time)
  end

  @doc """
  Creates a customer attached to the given test clock.

  Wraps `LatticeStripe.Customer.create/2` and auto-injects
  `test_clock: clock.id` into the params. This closes the D-13h
  silent-correctness footgun of forgetting `test_clock:` and having
  the customer run on real time.

  ## Example

      customer = create_customer(clock, email: "a@b.c")
  """
  def create_customer(clock, params \\ %{}, opts \\ []) do
    client = resolve_client!(opts)

    merged_params =
      params
      |> Enum.into(%{})
      |> Map.put(:test_clock, clock.id)

    {:ok, customer} = LatticeStripe.Customer.create(client, merged_params)
    customer
  end

  @doc """
  ExUnit setup callback. Creates a test clock and injects it into the
  context as `:test_clock`.

  ## Usage

      setup :with_test_clock

      test "sub renews", %{test_clock: clock} do
        ...
      end
  """
  def with_test_clock(context) do
    clock = test_clock([])
    {:ok, Map.put(context, :test_clock, clock)}
  end

  # -------------------------------------------------------------------
  # Private: unit parsing, client resolution, owner management
  # -------------------------------------------------------------------

  defp compute_frozen_time!(clock, unit_opts) do
    cond do
      Keyword.has_key?(unit_opts, :to) ->
        case Keyword.fetch!(unit_opts, :to) do
          %DateTime{} = dt -> DateTime.to_unix(dt)
          other -> raise ArgumentError, ":to must be a DateTime, got #{inspect(other)}"
        end

      Keyword.has_key?(unit_opts, :months) or Keyword.has_key?(unit_opts, :years) ->
        raise ArgumentError,
              ":months and :years are not supported in v1 (Elixir 1.15 has no calendar shift helper). " <>
                "Use `advance(clock, to: DateTime.add(clock_dt, N, :day))` or similar."

      true ->
        delta =
          cond do
            n = Keyword.get(unit_opts, :seconds) -> n
            n = Keyword.get(unit_opts, :minutes) -> n * 60
            n = Keyword.get(unit_opts, :hours) -> n * 3_600
            n = Keyword.get(unit_opts, :days) -> n * 86_400
            true ->
              raise ArgumentError,
                    "advance/2 unit_opts must contain one of :seconds, :minutes, :hours, :days, :to " <>
                      "-- got #{inspect(unit_opts)}"
          end

        (clock.frozen_time || System.system_time(:second)) + delta
    end
  end

  defp resolve_client!(opts) do
    case Keyword.get(opts, :client) do
      %LatticeStripe.Client{} = client ->
        client

      nil ->
        case Process.get(:__lattice_stripe_bound_client__) do
          nil ->
            raise TestClockError,
              message:
                "No LatticeStripe client is bound. Either " <>
                  "`use LatticeStripe.Testing.TestClock, client: MyApp.StripeClient` " <>
                  "in your CaseTemplate, or pass `client:` per call.",
              type: :no_client_bound

          %LatticeStripe.Client{} = client ->
            client

          mod when is_atom(mod) ->
            apply(mod, :stripe_client, [])
        end

      mod when is_atom(mod) ->
        apply(mod, :stripe_client, [])
    end
  end

  defp ensure_owner!(client) do
    case Process.get(:__lattice_stripe_test_clock_owner__) do
      nil ->
        owner = Owner.start_owner!()
        Process.put(:__lattice_stripe_test_clock_owner__, owner)

        ExUnit.Callbacks.on_exit(fn ->
          Owner.cleanup(owner, client)
        end)

        owner

      owner when is_pid(owner) ->
        owner
    end
  end
end
