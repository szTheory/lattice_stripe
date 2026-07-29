defmodule LatticeStripe.ApiSurfaceLockTest do
  @moduledoc """
  Gates the committed public API surface lock.

  This runs as an ExUnit test rather than a separate CI job so it inherits the full
  Elixir 1.15 / 1.17 / 1.19 matrix for free. That matters more than it looks: the whole
  design rests on the snapshot being byte-identical across Elixir versions, and this is
  what proves it on every PR. `mix lattice_stripe.api_surface` is the same logic behind a
  CLI, for the `--update` path that a test cannot offer.
  """
  use ExUnit.Case, async: true

  alias LatticeStripe.ApiSurface

  test "the committed lock file exists" do
    assert File.exists?(ApiSurface.lock_path()),
           "#{ApiSurface.lock_path()} is missing — the surface check has nothing to gate against."
  end

  test "the compiled public API surface matches the committed lock" do
    # Without the optional :plug dependency two public modules do not compile and this
    # would report a false breaking change. Fail on the cause, not the symptom.
    ApiSurface.assert_complete_build!()

    expected = ApiSurface.lock_path() |> File.read!() |> ApiSurface.parse()
    actual = ApiSurface.lines()

    case ApiSurface.diff(expected, actual) do
      {[], []} -> :ok
      {removed, added} -> flunk(ApiSurface.format_diff(removed, added))
    end
  end

  test "the lock never admits a module compiled from test/support" do
    # elixirc_paths(:test) compiles test/support into the SAME OTP app, so
    # :application.get_key(:modules) returns test-only modules and only the source-path
    # filter keeps them out. Today every test/support module happens to be
    # `@moduledoc false`, which would mask a regression here — so this asserts the filter
    # itself, against the day someone adds a test-support module with a real @moduledoc.
    refute Enum.any?(ApiSurface.lines(), &String.contains?(&1, ".TestSupport.")),
           "a test/support module entered the public API surface lock"
  end

  test "the lock never admits a module documented as internal" do
    # Spot-check against the "NOT public API" list published in guides/api_stability.md.
    # If one of these appears, it lost its `@moduledoc false` and just became something
    # adopters may depend on.
    lines = ApiSurface.lines()

    for internal <- [
          "LatticeStripe.ObjectTypes",
          "LatticeStripe.FormEncoder",
          "LatticeStripe.Resource",
          "LatticeStripe.Transport.Finch",
          "LatticeStripe.Json.Jason",
          "LatticeStripe.RetryStrategy.Default",
          "LatticeStripe.Drift",
          "LatticeStripe.ApiSurface"
        ] do
      refute "#{internal} module" in lines,
             "#{internal} is documented as internal but entered the public surface lock — " <>
               "it lost its `@moduledoc false`."
    end
  end

  test "regenerating the lock is idempotent" do
    # A non-idempotent generator produces spurious diffs, which trains reviewers to ignore
    # this file — the exact failure mode the lock exists to avoid.
    once = ApiSurface.render()
    assert once == ApiSurface.render()

    # And what render/0 writes must round-trip through parse/1 unchanged, or `--update`
    # would produce a file that immediately fails `--check`.
    assert ApiSurface.parse(once) == ApiSurface.lines()
  end

  test "protocol implementations are part of the locked surface" do
    # Several structs carry a `defimpl Inspect` purely to redact PII. Dropping one is
    # invisible in a normal review and silently starts leaking card and account data into
    # logs, so the impls are locked explicitly rather than inferred.
    lines = ApiSurface.lines()

    assert Enum.any?(lines, &String.ends_with?(&1, " impl Inspect")),
           "no protocol implementations captured — impl_lines/0 has regressed"

    assert "LatticeStripe.TaxId.Verification impl Inspect" in lines
  end
end
