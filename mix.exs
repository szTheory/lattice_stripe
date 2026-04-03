defmodule LatticeStripe.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/lattice-stripe/lattice_stripe"

  def project do
    [
      app: :lattice_stripe,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      name: "LatticeStripe",
      description: "A production-grade, idiomatic Elixir SDK for the Stripe API",
      source_url: @source_url,
      docs: [
        main: "LatticeStripe",
        extras: ["README.md"]
      ],
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Runtime dependencies
      {:finch, "~> 0.19"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.0"},
      {:nimble_options, "~> 1.0"},
      {:plug_crypto, "~> 2.0"},
      {:plug, "~> 1.16", optional: true},

      # Dev/test dependencies
      {:mox, "~> 1.2", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
