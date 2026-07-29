defmodule LatticeStripe.ApiSurface do
  @moduledoc false
  # Mechanical enforcement of the semver contract already written in prose in
  # guides/api_stability.md: public module names, public function name/arity, public struct
  # field names, public types and callbacks, and protocol implementations.
  #
  # "Public" means: compiled from lib/, AND not `@moduledoc false`. That is the exact rule
  # guides/api_stability.md states, so this module does not invent policy — it makes an
  # existing policy checkable.
  #
  # See Mix.Tasks.LatticeStripe.ApiSurface and the "Public API surface lock" section of
  # CONTRIBUTING.md. This module is itself `@moduledoc false`, so it excludes itself, the
  # same way LatticeStripe.Drift does.

  @lock_path "priv/api/current.txt"

  # Only these doc-chunk kinds are part of the surface. `:function` and `:macro` get their
  # default-argument arities expanded; the rest are recorded at their declared arity.
  @kinds [:function, :macro, :type, :callback, :macrocallback]

  @header """
  # LatticeStripe public API surface lock
  #
  # *** DO NOT REGENERATE THIS FILE TO MAKE A FAILING BUILD GREEN ***
  #
  # This file is a tripwire, not a formality. Regenerating it to clear a failure silences
  # the break rather than fixing it, and hands the mess to whoever next tries to work out
  # why an adopter's code stopped compiling. If a check against this file failed and you
  # did not mean to change the public API, the right move is to change the code back.
  #
  # It records everything guides/api_stability.md puts under semver: every module under
  # lib/ without `@moduledoc false`, plus its public functions (every callable arity,
  # including those reachable through default arguments), struct field names, types,
  # behaviour callbacks, and protocol implementations.
  #
  # A REMOVED line is a breaking change. An ADDED line is a feature.
  #
  # Sorted with a single comparator; regeneration is idempotent.
  """

  def lock_path, do: @lock_path

  @doc "Full lock-file body: header comments, then every entry line."
  def render, do: @header <> "\n" <> Enum.join(lines(), "\n") <> "\n"

  @doc "The compiled public surface as a deterministically ordered list of entry lines."
  def lines do
    module_lines =
      public_modules()
      |> Enum.sort_by(&inspect/1)
      |> Enum.flat_map(&module_lines/1)

    # One comparator over the whole file. Roslyn's three competing orderings are the
    # cautionary tale; a single sort keeps regeneration idempotent and diffs minimal.
    Enum.sort(module_lines ++ impl_lines())
  end

  @doc "Parses a lock-file body back into entry lines (comments and blanks dropped)."
  def parse(body) do
    body
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
  end

  @doc "Returns `{removed, added}` — lines present only in `expected`, and only in `actual`."
  def diff(expected, actual) do
    e = MapSet.new(expected)
    a = MapSet.new(actual)

    {Enum.reject(expected, &MapSet.member?(a, &1)), Enum.reject(actual, &MapSet.member?(e, &1))}
  end

  @doc """
  Raises if the build is missing optionally-compiled public modules.

  `lib/lattice_stripe/webhook/plug.ex` and `webhook/cache_body_reader.ex` are wrapped in
  `if Code.ensure_loaded?(Plug)`. Without the optional `:plug` dependency they do not
  compile, the snapshot silently loses two public modules, and the check reports a false
  breaking change. Fail on the cause instead of the symptom.
  """
  def assert_complete_build! do
    unless Code.ensure_loaded?(LatticeStripe.Webhook.Plug) do
      raise """
      LatticeStripe.Webhook.Plug is not compiled, so the optional :plug dependency was
      unavailable at compile time and the API surface snapshot would be incomplete.

      Run `mix deps.get && mix compile` and try again.
      """
    end
  end

  # ── enumeration ─────────────────────────────────────────────────────────────────────

  # elixirc_paths(:test) compiles test/support into the SAME OTP application, and
  # `cli: [preferred_envs: [ci: :test]]` means `mix ci` runs this in :test. Without the
  # source-path filter a test-support module with a real @moduledoc would silently enter
  # the public lock.
  defp lib_modules do
    {:ok, modules} = :application.get_key(:lattice_stripe, :modules)
    lib = Path.expand("lib") <> "/"

    Enum.filter(modules, fn module ->
      Code.ensure_loaded!(module)

      source =
        module.module_info(:compile)
        |> Keyword.fetch!(:source)
        |> to_string()
        |> Path.expand()

      String.starts_with?(source, lib)
    end)
  end

  defp public_modules do
    Enum.filter(lib_modules(), fn module ->
      case Code.fetch_docs(module) do
        # :hidden covers `@moduledoc false` plus every defimpl and defprotocol shim.
        {:docs_v1, _, _, _, :hidden, _, _} -> false
        {:docs_v1, _, _, _, :none, _, _} -> false
        {:docs_v1, _, _, _, _, _, _} -> true
        {:error, reason} -> raise "no Docs chunk for #{inspect(module)}: #{inspect(reason)}"
      end
    end)
  end

  defp module_lines(module) do
    name = inspect(module)
    {:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(module)

    ["#{name} module"] ++ field_lines(module, name) ++ Enum.flat_map(docs, &entry_lines(name, &1))
  end

  defp field_lines(module, name) do
    if function_exported?(module, :__struct__, 0) do
      module.__info__(:struct)
      |> Enum.map(&"#{name} field #{&1.field}")
    else
      []
    end
  end

  # `doc == :hidden` covers `@doc false`, the compiler-generated `__struct__/0,1`, and
  # `@impl`-annotated callbacks carrying no explicit `@doc`.
  defp entry_lines(name, {{kind, fun, arity}, _anno, _signature, doc, meta})
       when kind in @kinds and doc != :hidden do
    # Read ONLY :defaults and the presence of :deprecated. The metadata map is
    # Elixir-version dependent — 1.19 adds :source_annos — so serializing it wholesale, or
    # the anno, or the signature, would make the lock differ across the 1.15/1.17/1.19 CI
    # matrix on day one. Argument names are not part of the contract either.
    suffix = if Map.has_key?(meta, :deprecated), do: " deprecated", else: ""

    if kind in [:function, :macro] do
      # The docs chunk stores the max arity plus a :defaults count. Expanding it means
      # deleting a default value shows up as a REMOVED callable arity, which is a real
      # break no other mechanism catches structurally.
      for a <- (arity - Map.get(meta, :defaults, 0))..arity,
          do: "#{name} #{kind} #{fun}/#{a}#{suffix}"
    else
      ["#{name} #{kind} #{fun}/#{arity}#{suffix}"]
    end
  end

  defp entry_lines(_name, _entry), do: []

  # Protocol impls are :hidden as modules, so they need their own line type. Losing a
  # `defimpl Inspect` silently un-redacts PII into logs — exactly the kind of break that is
  # invisible in a normal diff.
  defp impl_lines do
    for module <- lib_modules(), function_exported?(module, :__impl__, 1) do
      "#{inspect(module.__impl__(:for))} impl #{inspect(module.__impl__(:protocol))}"
    end
  end

  # ── reporting ───────────────────────────────────────────────────────────────────────

  @max_shown 50

  @doc """
  Human-readable drift report.

  Deliberately does NOT print the regeneration command. aya's `re-run with --bless`,
  Jest's `-u` and Kotlin BCV's "You can run :apiDump" are three independent natural
  experiments in the same failure: naming the escape hatch in the error message trains
  contributors to reach for it reflexively, and the gate stops gating.
  """
  def format_diff(removed, added) do
    """
    The public API surface no longer matches #{@lock_path}.

    #{section("REMOVED — these are BREAKING changes", "  - ", removed)}#{section("ADDED — these are new public API", "  + ", added)}
    If you did NOT intend to change the public API, this is the bug — restore what moved.
    Common accidental causes: renaming a function, deleting a default argument value,
    removing a struct field, adding `@moduledoc false` or `@doc false` to something
    adopters already use, or dropping a `defimpl Inspect` (which silently un-redacts PII).

    If you DID intend it, see "Public API surface lock" in CONTRIBUTING.md for how to
    record the change. Anything under REMOVED needs a `!` commit and a note in
    guides/api_stability.md.
    """
  end

  defp section(_title, _prefix, []), do: ""

  defp section(title, prefix, entries) do
    shown = Enum.take(entries, @max_shown)
    truncated = length(entries) - length(shown)

    body = Enum.map_join(shown, "\n", &(prefix <> &1))

    tail =
      if truncated > 0,
        do: "\n  [#{truncated} more line(s) truncated]",
        else: ""

    "#{title} (#{length(entries)}):\n#{body}#{tail}\n\n"
  end
end
