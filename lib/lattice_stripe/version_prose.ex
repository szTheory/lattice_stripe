defmodule LatticeStripe.VersionProse do
  @moduledoc false

  # The published version appears in prose on surfaces that `release-please` does not touch:
  # install snippets and release-status lines in the README and guides. `release-please`
  # bumps only `mix.exs` and `CHANGELOG.md`, and its `extra-files` updaters cannot express
  # what these surfaces need — the install pin is `~> MAJOR.MINOR` (no patch), which none of
  # the `x-release-please-{version,major,minor,patch}` annotations produce, and the pins live
  # inside fenced code blocks where an HTML-comment annotation would render literally.
  #
  # So the sync happens here instead, driven off `mix.exs` — the same source of truth
  # `docs_truth_test.exs` derives its expectations from. That test is the gate; this module
  # is the fixer. Keeping both on one derivation is what stops them disagreeing.
  #
  # Every rewrite below is anchored to a specific line shape rather than applied globally,
  # because `CHANGELOG.md` contains historical pins under past release headings that must
  # keep their original values. A blanket substitution would silently rewrite release history.

  @install_surfaces [
    "README.md",
    "guides/getting-started.md",
    "guides/cheatsheet.cheatmd",
    "guides/webhooks-thin-events.md",
    "guides/production-checklist.md",
    "guides/event-debugging.md",
    "guides/opentelemetry.md"
  ]

  # Lines carrying "the currently published line is X.Y.x", plus the CHANGELOG anchor they
  # link to. Matched by their semantic prefix so the rewrite cannot wander onto another line.
  @release_status_surfaces ["README.md", "guides/getting-started.md"]
  @release_status_prefixes ["**Current release:**", "**Current Hex line:**"]

  # Only the top-of-file publishing note. Everything below it is history.
  @changelog "CHANGELOG.md"
  @changelog_note_prefix "> **Publishing note:**"

  @doc "All files this module may rewrite."
  def surfaces do
    Enum.uniq(@install_surfaces ++ @release_status_surfaces ++ [@changelog])
  end

  @doc "The version prose is derived from, e.g. `\"2.0.0\"`."
  def version, do: LatticeStripe.MixProject.project()[:version]

  @doc "`MAJOR.MINOR`, the form used by install pins and release-status lines."
  def major_minor do
    [major, minor | _] = String.split(version(), ".")
    "#{major}.#{minor}"
  end

  @doc """
  The CHANGELOG anchor for the release that opened the current minor line.

  `2.0.0` and `1.7.13` become `200` and `170` respectively — the anchor of the `MAJOR.MINOR.0`
  heading, not of the current patch. That is deliberate and matches what these lines already
  link to: the release-status prose describes the whole `MAJOR.MINOR.x` line, so it points at
  where that line began rather than at whichever patch happens to be newest.
  """
  def changelog_anchor, do: String.replace(major_minor(), ".", "") <> "0"

  @doc "The install snippet every public surface must show."
  def install_snippet, do: ~s({:lattice_stripe, "~> #{major_minor()}"})

  @doc """
  The version the current *minor line* is measured against.

  Read from the compare link on the `MAJOR.MINOR.0` CHANGELOG heading — the same entry
  `changelog_anchor/0` points at. For `1.7.13` that is the `1.7.0` heading
  (`/compare/v1.1.0...v1.7.0`), giving `"1.1.0"`; for `2.0.0` it is the `2.0.0` heading
  (`/compare/v1.7.13...v2.0.0`), giving `"1.7.13"`.

  Deliberately *not* the immediate predecessor. The release-status prose describes the whole
  `MAJOR.MINOR.x` line and links to where that line began, so "shipped since" has to name the
  same boundary — otherwise a patch release would rewrite it to something the linked entry
  does not describe.

  Returns `nil` when no compare link is parseable — the first release, or a hand-written
  heading. Callers leave the prose untouched in that case; a wrong "since" is worse than a
  stale one.
  """
  def previous_version(changelog \\ nil) do
    content = changelog || File.read!(@changelog)
    line_start = Regex.escape("#{major_minor()}.0")
    pattern = ~r{/compare/v(\d+\.\d+\.\d+)\.\.\.v#{line_start}\b}

    case Regex.run(pattern, content) do
      [_, previous] -> previous
      nil -> nil
    end
  end

  @doc "Rewrites `content` for `path`. Pure — takes and returns a string."
  def render(path, content, previous \\ :from_changelog) do
    previous = if previous == :from_changelog, do: previous_version(), else: previous

    content
    |> rewrite_install_pin(path)
    |> rewrite_release_status(path, previous)
    |> rewrite_changelog_note(path)
  end

  defp rewrite_install_pin(content, path) when path in @install_surfaces do
    String.replace(content, ~r/\{:lattice_stripe, "~> \d+\.\d+"\}/, install_snippet())
  end

  defp rewrite_install_pin(content, _path), do: content

  defp rewrite_release_status(content, path, previous) when path in @release_status_surfaces do
    map_lines(content, fn line ->
      if String.contains?(line, @release_status_prefixes) do
        line
        |> String.replace(~r/`\d+\.\d+\.x`/, "`#{major_minor()}.x`")
        |> String.replace(~r/(CHANGELOG\.md)#\d+/, "\\1##{changelog_anchor()}")
        |> rewrite_since(previous)
      else
        line
      end
    end)
  end

  defp rewrite_release_status(content, _path, _previous), do: content

  defp rewrite_since(line, nil), do: line

  defp rewrite_since(line, previous) do
    # \g{1}, not \1: the replacement is followed immediately by a digit, and "\1" <> "1.7.13"
    # parses as backreference 11 — which silently swallowed the prose the first time around.
    String.replace(line, ~r/(shipped since )\d+\.\d+\.\d+/, "\\g{1}#{previous}")
  end

  defp rewrite_changelog_note(content, @changelog) do
    map_lines(content, fn line ->
      if String.starts_with?(line, @changelog_note_prefix) do
        String.replace(line, ~r/\{:lattice_stripe, "~> \d+\.\d+"\}/, install_snippet())
      else
        line
      end
    end)
  end

  defp rewrite_changelog_note(content, _path), do: content

  # Splitting on "\n" and rejoining preserves a trailing newline, because the final split
  # element is "" and rejoins as-is.
  defp map_lines(content, fun) do
    content |> String.split("\n") |> Enum.map_join("\n", fun)
  end

  @doc """
  Returns `{path, current, rendered}` for every surface whose prose has drifted.

  An empty list means every surface already matches `mix.exs`.
  """
  def drift do
    for path <- surfaces(),
        current = File.read!(path),
        rendered = render(path, current),
        rendered != current,
        do: {path, current, rendered}
  end

  @doc "Rewrites every drifted surface in place. Returns the paths written."
  def update! do
    for {path, _current, rendered} <- drift() do
      File.write!(path, rendered)
      path
    end
  end
end
