defmodule Mix.Tasks.LatticeStripe.VersionProse do
  @moduledoc """
  Checks — or rewrites — the published version strings in the README, guides, and CHANGELOG.

  The version appears in prose on surfaces `release-please` does not update: the
  `{:lattice_stripe, "~> MAJOR.MINOR"}` install snippets and the "current release" lines.
  `test/lattice_stripe/docs_truth_test.exs` derives its expectations from `mix.exs`, so when
  the version is bumped without these surfaces following, CI fails. This task is the fixer
  for that failure.

  ## Usage

      # Verify every surface matches mix.exs (the default):
      mix lattice_stripe.version_prose
      mix lattice_stripe.version_prose --check

      # Rewrite drifted surfaces from mix.exs:
      mix lattice_stripe.version_prose --update

  ## Exit codes

    * `0`   — every surface matches `mix.exs`
    * `100` — prose drifted from `mix.exs`
    * `101` — the tool could not run (bad flags, unreadable surface)

  Same convention as `mix lattice_stripe.api_surface`, so CI can tell "the content is wrong"
  from "the check itself broke".

  ## Why this is safe to run in CI

  Unlike the API surface lock, `--update` here is *not* a way to silence a real problem. The
  version in `mix.exs` is the single source of truth and `release-please` owns it; this task
  only propagates that value outward. There is no judgement call to launder, so the release
  workflow runs `--update` on the release branch automatically.
  """

  use Mix.Task

  alias LatticeStripe.VersionProse

  @shortdoc "Check or rewrite published version strings in docs"

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

    case {Keyword.get(opts, :update, false), Keyword.get(opts, :check, false)} do
      {true, true} -> bail("--check and --update are mutually exclusive")
      {true, false} -> update()
      {false, _} -> check()
    end
  end

  defp update do
    case safe_update() do
      [] ->
        Mix.shell().info("Version prose already matches mix.exs (#{VersionProse.version()}).")

      paths ->
        Mix.shell().info("""
        Rewrote #{length(paths)} surface(s) to #{VersionProse.version()}:

        #{Enum.map_join(paths, "\n", &"  #{&1}")}
        """)
    end
  end

  defp check do
    case safe_drift() do
      [] ->
        Mix.shell().info("Version prose matches mix.exs (#{VersionProse.version()}).")

      drifted ->
        Mix.shell().error("""
        Version prose drifted from mix.exs (#{VersionProse.version()}).

        Expected install snippet: #{VersionProse.install_snippet()}

        Drifted surface(s):
        #{Enum.map_join(drifted, "\n", fn {path, _, _} -> "  #{path}" end)}

        Fix with:

            mix lattice_stripe.version_prose --update
        """)

        System.halt(@exit_violation)
    end
  end

  defp safe_drift do
    VersionProse.drift()
  rescue
    e in File.Error -> bail(Exception.message(e))
  end

  defp safe_update do
    VersionProse.update!()
  rescue
    e in File.Error -> bail(Exception.message(e))
  end

  defp bail(message) do
    Mix.shell().error("lattice_stripe.version_prose: " <> message)
    System.halt(@exit_tool_failure)
  end
end
