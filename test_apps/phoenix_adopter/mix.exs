defmodule PhoenixAdopter.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_adopter,
      version: "0.1.0",
      elixir: ">= 1.15.0",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger], mod: {PhoenixAdopter.Application, []}]
  end

  defp deps do
    lattice_stripe_dep =
      case System.get_env("MIX_LATTICE_STRIPE_HEX_VERSION") do
        nil ->
          {:lattice_stripe, path: "../../"}

        version ->
          unless Regex.match?(~r/\A[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?\z/, version) do
            raise "MIX_LATTICE_STRIPE_HEX_VERSION must be an exact semantic version"
          end

          {:lattice_stripe, version}
      end

    [
      lattice_stripe_dep,
      {:phoenix, "~> 1.8.0"},
      {:plug, "~> 1.16"},
      {:mox, "~> 1.2", only: :test}
    ]
  end
end
