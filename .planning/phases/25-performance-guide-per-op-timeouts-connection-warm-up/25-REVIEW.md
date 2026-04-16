---
phase: 25-performance-guide-per-op-timeouts-connection-warm-up
reviewed: 2026-04-16T20:01:30Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - lib/lattice_stripe/client.ex
  - lib/lattice_stripe/config.ex
  - lib/lattice_stripe.ex
  - test/lattice_stripe/client_test.exs
  - test/lattice_stripe/config_test.exs
  - test/lattice_stripe/warm_up_test.exs
  - guides/performance.md
  - mix.exs
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
status: issues_found
---

# Phase 25: Code Review Report

**Reviewed:** 2026-04-16T20:01:30Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Phase 25 adds per-operation timeouts (`operation_timeouts`), connection warm-up
(`warm_up/1` and `warm_up!/1`), and the `guides/performance.md` documentation.
The implementation is generally solid — the three-tier timeout precedence chain,
operation classification, and warm-up contract are all correct. Test coverage is
thorough and uses Mox correctly throughout.

Two warnings require attention: `warm_up!/1` raises a plain `RuntimeError` while
every other bang variant in the library raises `LatticeStripe.Error`, breaking the
documented error API contract; and `client_user_agent_json/0` hard-codes a `Jason`
call that bypasses the pluggable `json_codec`, silently failing if a non-Jason codec
is configured. Three info items cover: the compile-time `Mix.Project.config()` call
(fragile when consumed as a dependency), the absence of validation for unknown
`operation_timeouts` keys (silent typo footgun), and one commented-out doc asset
reference in `mix.exs`.

## Warnings

### WR-01: `warm_up!/1` raises `RuntimeError` instead of `LatticeStripe.Error`

**File:** `lib/lattice_stripe.ex:136`
**Issue:** `warm_up!/1` raises a plain `RuntimeError` on transport failure, while
every other bang variant (`new!/1`, `request!/2`, and all resource module bangs)
raises `LatticeStripe.Error`. Callers who rescue `LatticeStripe.Error` will not
catch warm-up failures. The module-level docstring says "Bang variants raise
`LatticeStripe.Error` on failure", which makes this an undocumented exception to
the contract.
**Fix:** Raise a `LatticeStripe.Error` with `type: :connection_error`:

```elixir
def warm_up!(%LatticeStripe.Client{} = client) do
  case warm_up(client) do
    {:ok, :warmed} -> :warmed
    {:error, reason} ->
      raise %LatticeStripe.Error{
        type: :connection_error,
        message: "Stripe connection warm-up failed: #{inspect(reason)}"
      }
  end
end
```

The warm-up test at `test/lattice_stripe/warm_up_test.exs:109` asserts
`assert_raise RuntimeError` and will need updating to match.

---

### WR-02: `client_user_agent_json/0` hard-codes `Jason` instead of using the configured `json_codec`

**File:** `lib/lattice_stripe/client.ex:433`
**Issue:** `Jason.encode!()` is called directly in `client_user_agent_json/0`,
bypassing the `json_codec` behaviour the library uses everywhere else. If a caller
configures a custom `json_codec` that is not Jason (the architecture explicitly
supports this), and Jason is somehow not available (e.g., excluded from a future
stripped build), this function will crash or encode incorrectly. More concretely,
it creates a silent coupling to Jason that contradicts the pluggable-codec design
decision documented in CLAUDE.md.
**Fix:** Pass the client (or the codec module) into the function and encode through
the codec:

```elixir
defp client_user_agent_json(json_codec) do
  %{
    "bindings_version" => @version,
    "lang" => "elixir",
    "lang_version" => System.version(),
    "publisher" => "lattice_stripe",
    "otp_version" => System.otp_release()
  }
  |> json_codec.encode!()
end
```

And in `build_headers/5`, thread `client.json_codec` through:

```elixir
{"x-stripe-client-user-agent", client_user_agent_json(client.json_codec)},
```

(Note: `build_headers/5` would need a 6th argument, or receive the full client
struct, or the UA JSON can be computed once in `request/2` and passed down.)

## Info

### IN-01: `Mix.Project.config()` called at compile time in a library module

**File:** `lib/lattice_stripe/client.ex:49`
**Issue:** `@version Mix.Project.config()[:version]` resolves correctly when
compiling the library itself, but when the library is consumed as a dependency
`Mix.Project.config()` returns the *host application's* project config, not
LatticeStripe's. In Elixir, `Mix.Project` in a dependency context refers to the
currently-loaded project at compile time of the dependency, which is typically
correct during `mix compile` of the dep. However, this is a well-known footgun:
if the library is compiled in the host app's context (e.g., `mix deps.compile`
without isolation), the version will be `nil` or the host app's version, causing
the `User-Agent` header to read `LatticeStripe/` (missing version).
**Fix:** Use `Application.spec/2` instead, which reads from the compiled `.app`
file and works correctly at both compile time and runtime regardless of context:

```elixir
@version Application.spec(:lattice_stripe, :vsn) |> to_string()
```

This is the idiomatic approach for library self-version detection.

---

### IN-02: Unknown `operation_timeouts` keys silently fall through to `client.timeout`

**File:** `lib/lattice_stripe/config.ex:74-87`
**Issue:** The `operation_timeouts` schema accepts any atom key (`:map, :atom,
:pos_integer`). A typo such as `%{lists: 60_000}` (note the `s`) will pass
validation without error and silently have no effect — the list operation will
use `client.timeout` instead of the intended value. Users have no feedback that
the key was unrecognized.
**Fix:** Either document the "silent fallback" behavior explicitly in the option
doc (low effort), or add a custom validator that rejects keys outside the known
set:

```elixir
operation_timeouts: [
  type: {:or, [{:map, :atom, :pos_integer}, nil]},
  default: nil,
  doc: """
  ...
  Unknown keys are silently ignored and fall back to `timeout`. Valid keys are:
  `:list`, `:search`, `:create`, `:retrieve`, `:update`, `:delete`.
  """,
  # Optional: add custom validator to reject unknown keys
]
```

At minimum the doc should warn about this so users are not confused when a
misspelled key has no effect.

---

### IN-03: Commented-out logo reference in `mix.exs`

**File:** `mix.exs:23`
**Issue:** `# logo: "assets/logo.png",  # Add when logo asset is created` is
commented-out code in the `docs:` configuration. This is a minor maintenance
item — either the asset should be created or the line should be removed.
**Fix:** Create `assets/logo.png` and uncomment the line, or remove the comment
entirely if a logo is not planned for v1.2.

---

_Reviewed: 2026-04-16T20:01:30Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
