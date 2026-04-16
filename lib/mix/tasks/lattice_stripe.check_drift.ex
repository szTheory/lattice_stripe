defmodule Mix.Tasks.LatticeStripe.CheckDrift do
  @moduledoc """
  Compares Stripe's published OpenAPI specification against LatticeStripe's
  `@known_fields` module attributes and reports any drift.

  Downloads the latest `spec3.json` from the `stripe/openapi` GitHub
  repository and checks every module registered in
  `LatticeStripe.ObjectTypes` for field additions (in spec, not in
  `@known_fields`) and field removals (in `@known_fields`, not in spec).

  Also reports Stripe object types present in the spec that have no
  corresponding entry in the ObjectTypes registry.

  ## Usage

      # Check for drift (downloads spec on each run):
      mix lattice_stripe.check_drift

  ## Exit codes

  - `0` -- no drift detected; all `@known_fields` match the spec
  - `1` -- drift detected; report printed to stdout
  """

  use Mix.Task

  @shortdoc "Check for Stripe API drift against @known_fields"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [])
    Mix.Task.run("app.start")

    case LatticeStripe.Drift.run(opts) do
      {:ok, %{drift_count: 0} = result} ->
        # No per-module drift. May still have new_resources (informational).
        if result.new_resources != [] do
          Mix.shell().info(LatticeStripe.Drift.format_report(result))
        else
          Mix.shell().info("No drift detected. @known_fields are up to date.")
        end

      {:ok, result} ->
        # drift_count > 0 -- actual drift found
        Mix.shell().info(LatticeStripe.Drift.format_report(result))
        System.halt(1)

      {:error, reason} ->
        Mix.raise("Drift check failed: #{inspect(reason)}")
    end
  end
end
