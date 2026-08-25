defmodule LatticeStripe.Application do
  @moduledoc """
  Optional OTP application for LatticeStripe.

  Starts a default Finch pool named `LatticeStripe.Finch` so callers can make
  live Stripe API calls without manually starting and wiring a Finch pool.
  `LatticeStripe.Client` options default `:finch` to this pool name, so
  `LatticeStripe.Client.new!(api_key: "sk_test_...")` works with no further setup.

  This module is registered as the application callback via
  `mod: {LatticeStripe.Application, []}` in `mix.exs`, so the default pool boots
  automatically when the `:lattice_stripe` application starts.

  ## Disabling the default pool

  If you already manage your own Finch pool (or your own supervision tree
  entirely), disable the default pool startup so you don't run a duplicate idle
  pool:

      config :lattice_stripe, start_default_finch: false

  Pass your own pool name via `finch:` when creating a client — this works whether
  or not the default pool is running:

      LatticeStripe.Client.new!(api_key: "sk_test_...", finch: MyApp.Finch)

  ## Overriding the default pool configuration

  The default pool uses Finch's own connection defaults. To override pool sizing
  without opting out of the default pool entirely:

      config :lattice_stripe, default_finch_pools: %{default: [size: 100, count: 4]}
  """

  use Application

  @default_pool_name LatticeStripe.Finch

  @impl true
  def start(_type, _args) do
    Supervisor.start_link(default_finch_children(),
      strategy: :one_for_one,
      name: LatticeStripe.Supervisor
    )
  end

  @doc false
  # Builds the supervised children list. Reads the opt-out toggle once at boot
  # (infrastructure config, not per-request business logic). Exposed for testing
  # the opt-out decision branch in isolation.
  def default_finch_children do
    if Application.get_env(:lattice_stripe, :start_default_finch, true) do
      [{Finch, name: @default_pool_name, pools: default_pools()}]
    else
      []
    end
  end

  # This sensible default is overridable via app config. Finch's own defaults
  # (%{default: [size: 50, count: 1]}) apply when this is unset.
  defp default_pools do
    Application.get_env(:lattice_stripe, :default_finch_pools, %{})
  end
end
