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
    {opts, _, _} = OptionParser.parse(args, strict: [summary: :boolean])
    summary_only? = Keyword.get(opts, :summary, false)
    Mix.Task.run("app.start")

    case LatticeStripe.Drift.run(opts) do
      {:ok, %{drift_count: 0} = result} ->
        if result.new_resources != [] do
          emit_report(result, summary_only?)
          System.halt(1)
        else
          Mix.shell().info("No drift detected. @known_fields are up to date.")
        end

      {:ok, result} ->
        emit_report(result, summary_only?)
        System.halt(1)

      {:error, reason} ->
        Mix.raise("Drift check failed: #{inspect(reason)}")
    end
  end

  defp emit_report(result, true), do: Mix.shell().info(LatticeStripe.Drift.format_summary(result))
  defp emit_report(result, false), do: Mix.shell().info(LatticeStripe.Drift.format_report(result))
end
