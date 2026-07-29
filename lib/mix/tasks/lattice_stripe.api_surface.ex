defmodule Mix.Tasks.LatticeStripe.ApiSurface do
  @moduledoc """
  Checks — or regenerates — the committed public API surface lock.

  `priv/api/current.txt` is the mechanical form of the semver contract written in
  `guides/api_stability.md`: every module under `lib/` without `@moduledoc false`, plus its
  public functions (every callable arity, including those reachable through default
  arguments), struct field names, types, behaviour callbacks, and protocol implementations.

  A line removed from the lock is a breaking change. A line added is a feature.

  ## Usage

      # Verify the compiled surface matches the committed lock (the default):
      mix lattice_stripe.api_surface
      mix lattice_stripe.api_surface --check

      # Accept the current surface and rewrite the lock (local development only):
      mix lattice_stripe.api_surface --update

  ## Exit codes

    * `0`   — the compiled public surface matches the lock
    * `100` — surface violation: the lock and the code disagree
    * `101` — the tool could not run (missing lock file, incomplete build, bad flags)

  Distinct codes so CI can tell "the API changed" from "the check itself broke" — a
  distinction almost no comparable tool makes, and the one that decides whether a red build
  means *review this* or *fix the tooling*.

  ## `--update` is refused when `CI` is set

  The one safety property that survived in the ecosystem survey of these tools is that the
  regenerator is simply unavailable in the gating environment. Where regeneration is
  possible in CI, it eventually becomes the reflex, and the gate stops gating.
  """

  use Mix.Task

  alias LatticeStripe.ApiSurface

  @shortdoc "Check or regenerate the public API surface lock"

  @exit_violation 100
  @exit_tool_failure 101

  @impl Mix.Task
  def run(args) do
    {opts, _rest, invalid} =
      OptionParser.parse(args, strict: [check: :boolean, update: :boolean])

    if invalid != [] do
      bail("unrecognised option(s): #{inspect(Enum.map(invalid, &elem(&1, 0)))}")
    end

    Mix.Task.run("app.start")

    try do
      ApiSurface.assert_complete_build!()
    rescue
      e -> bail(Exception.message(e))
    end

    case {Keyword.get(opts, :update, false), Keyword.get(opts, :check, false)} do
      {true, true} -> bail("--check and --update are mutually exclusive")
      {true, false} -> update()
      {false, _} -> check()
    end
  end

  defp update do
    if System.get_env("CI") do
      bail("""
      --update is not available in CI.

      The lock is a tripwire; regenerating it here would silence the very change it exists
      to surface. Make the decision locally, with the diff in front of you, and commit the
      result alongside the code change.
      """)
    end

    path = ApiSurface.lock_path()
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, ApiSurface.render())

    Mix.shell().info("""
    Wrote #{path} (#{length(ApiSurface.lines())} entries).

    Read `git diff #{path}` before committing. Every removed line is a breaking change for
    someone who has already shipped against it.
    """)
  end

  defp check do
    path = ApiSurface.lock_path()

    unless File.exists?(path) do
      bail("#{path} does not exist, so there is nothing to check against.")
    end

    expected = path |> File.read!() |> ApiSurface.parse()
    actual = ApiSurface.lines()

    case ApiSurface.diff(expected, actual) do
      {[], []} ->
        Mix.shell().info("Public API surface matches #{path} (#{length(actual)} entries).")

      {removed, added} ->
        Mix.shell().error(ApiSurface.format_diff(removed, added))
        System.halt(@exit_violation)
    end
  end

  defp bail(message) do
    Mix.shell().error("lattice_stripe.api_surface: " <> message)
    System.halt(@exit_tool_failure)
  end
end
