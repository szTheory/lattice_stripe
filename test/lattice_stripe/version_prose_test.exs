defmodule LatticeStripe.VersionProseTest do
  @moduledoc """
  Guards the version-prose sync.

  The shipped repo is asserted to be in sync (same claim `docs_truth_test.exs` makes, from
  the other direction). The rest of these tests pin the *rewrite rules* against inputs that
  are not currently in the repo, because the expensive failure here is not drift — it is a
  rewrite that corrupts something it should not have touched, which no green build would
  reveal until it reached Hex.
  """
  use ExUnit.Case, async: true

  alias LatticeStripe.VersionProse

  test "every shipped surface is already in sync with mix.exs" do
    assert VersionProse.drift() == [],
           """
           Version prose drifted from mix.exs (#{VersionProse.version()}).
           Fix with: mix lattice_stripe.version_prose --update
           """
  end

  test "derives the pin from mix.exs rather than hardcoding it" do
    [major, minor | _] = String.split(VersionProse.version(), ".")

    assert VersionProse.major_minor() == "#{major}.#{minor}"
    assert VersionProse.install_snippet() == ~s({:lattice_stripe, "~> #{major}.#{minor}"})
  end

  test "the changelog anchor points at the release that opened the current minor line" do
    # "2.0.0" -> "200" and "1.7.13" -> "170": the MAJOR.MINOR.0 heading, never the patch.
    # Deriving from the full version instead yields "1713", which is a dead link.
    assert VersionProse.changelog_anchor() ==
             String.replace(VersionProse.major_minor(), ".", "") <> "0"

    refute VersionProse.changelog_anchor() =~ ~r/\d{4,}/
  end

  describe "install pin rewrite" do
    test "replaces any major.minor pin on an install surface" do
      out = VersionProse.render("README.md", ~s(    {:lattice_stripe, "~> 1.3"}\n))
      assert out == "    #{VersionProse.install_snippet()}\n"
    end

    test "leaves surfaces that are not install surfaces alone" do
      line = ~s(    {:lattice_stripe, "~> 1.3"}\n)
      assert VersionProse.render("guides/tax.md", line) == line
    end
  end

  describe "CHANGELOG safety" do
    # The regression this module is most likely to cause: a blanket substitution rewriting
    # the install pins recorded under past release headings, silently falsifying history.
    test "rewrites the publishing note but never historical entries" do
      content = """
      # Changelog

      > **Publishing note:** Releases are published automatically. Install: `{:lattice_stripe, "~> 0.9"}`.

      ## [0.9.0](https://example.com) (2020-01-01)

      **Upgrading from 0.8.x:** Update your dependency to `{:lattice_stripe, "~> 0.9"}`.
      """

      lines = "CHANGELOG.md" |> VersionProse.render(content) |> String.split("\n")
      note = Enum.find(lines, &String.starts_with?(&1, "> **Publishing note:**"))
      historical = Enum.find(lines, &String.starts_with?(&1, "**Upgrading from"))

      assert note =~ VersionProse.install_snippet()
      refute note =~ ~s({:lattice_stripe, "~> 0.9"})
      assert historical =~ ~s({:lattice_stripe, "~> 0.9"})
    end
  end

  describe "release-status rewrite" do
    test "updates the version and the changelog anchor together" do
      line = "> **Current release:** **`1.7.x`** on Hex — see [CHANGELOG](CHANGELOG.md#170).\n"
      out = VersionProse.render("README.md", line)

      assert out =~ "`#{VersionProse.major_minor()}.x`"
      assert out =~ "CHANGELOG.md##{VersionProse.changelog_anchor()}"
    end

    test "rewrites the 'shipped since' boundary without eating the surrounding prose" do
      # Regression: the replacement is immediately followed by a digit, so "\\1" parsed as
      # backreference 11 and deleted the text instead of substituting it.
      line =
        "> **Current release:** **`1.7.x`** — see [CHANGELOG](CHANGELOG.md#170) " <>
          "for what shipped since 0.4.0. Evaluating fit?\n"

      out = VersionProse.render("README.md", line, "1.2.3")

      assert out =~ "for what shipped since 1.2.3. Evaluating fit?"
      refute out =~ "0.4.0"
    end

    test "leaves the 'shipped since' boundary alone when it cannot be derived" do
      line = "> **Current release:** **`1.7.x`** for what shipped since 0.4.0.\n"
      assert VersionProse.render("README.md", line, nil) =~ "shipped since 0.4.0"
    end

    test "derives the boundary from the MAJOR.MINOR.0 heading, not the newest release" do
      changelog = """
      ## [9.4.2](https://github.com/x/y/compare/v9.4.1...v9.4.2) (2026-01-02)
      ## [9.4.0](https://github.com/x/y/compare/v8.0.0...v9.4.0) (2026-01-01)
      """

      # major_minor() comes from mix.exs, so this only asserts the selection rule when the
      # fixture's line matches the shipped one; otherwise it must decline rather than guess.
      expected = if VersionProse.major_minor() == "9.4", do: "8.0.0", else: nil
      assert VersionProse.previous_version(changelog) == expected
    end

    test "ignores lines without the release-status prefix" do
      # A version-shaped string elsewhere in the README must survive untouched.
      line = "Some prose mentioning `1.3.x` and [CHANGELOG](CHANGELOG.md#130).\n"
      assert VersionProse.render("README.md", line) == line
    end
  end

  test "rendering is idempotent on every shipped surface" do
    for path <- VersionProse.surfaces() do
      content = File.read!(path)
      once = VersionProse.render(path, content)

      assert VersionProse.render(path, once) == once,
             "#{path} is rewritten differently on a second pass"
    end
  end

  test "rendering preserves a trailing newline" do
    assert VersionProse.render("README.md", "no version here\n") == "no version here\n"
  end
end
