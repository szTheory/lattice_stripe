---
phase: 29-changeset-style-param-builders
reviewed: 2026-04-16T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - lib/lattice_stripe/builders/subscription_schedule.ex
  - lib/lattice_stripe/builders/billing_portal.ex
  - mix.exs
  - test/lattice_stripe/builders/subscription_schedule_test.exs
  - test/lattice_stripe/builders/billing_portal_test.exs
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
status: issues_found
---

# Phase 29: Code Review Report

**Reviewed:** 2026-04-16T00:00:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Two builder modules are introduced: `LatticeStripe.Builders.SubscriptionSchedule` and
`LatticeStripe.Builders.BillingPortal`. Overall the design is clean — opaque accumulators,
nil-omitting `build/1`, atom-to-string conversion, and a clear two-mode API for
`SubscriptionSchedule`. Tests are comprehensive and correctly verify the public contract.

Two warnings were found, both in `subscription_schedule.ex`. The most impactful is an
inconsistency in date handling between the top-level builder and the phase sub-builder:
`stringify_date/1` is applied to the schedule's `start_date` but not to phase-level
`start_date` or `end_date`, meaning atom values (most notably `:now`) passed to
`phase_start_date/2` survive into the output map as bare atoms, which Stripe will reject.
A secondary warning is that `start_date/2` accepts any term (no type guard), so passing
an unrecognized atom (e.g., `:yesterday`) will compile cleanly but raise a cryptic
`FunctionClauseError` from inside `build/1` rather than at the call site.

One info item flags `fuse` being declared dev-only in `mix.exs` when the circuit-breaker
guide implies it is available to production users.

## Warnings

### WR-01: Phase-level date fields bypass `stringify_date/1` — atoms pass through raw

**File:** `lib/lattice_stripe/builders/subscription_schedule.ex:311-319`

**Issue:** `phase_build/1` emits `"start_date"` and `"end_date"` directly from the
struct fields without calling `stringify_date/1`. The top-level `build/1` does apply
`stringify_date/1` to the schedule's own `start_date` (line 164), but this conversion
is absent in `phase_build/1`. As a result, calling `phase_start_date(p, :now)` (which
the spec signature allows) stores the atom `:now` on the struct, and `phase_build/1`
emits `"start_date" => :now` — a bare atom — into the output map. The Stripe HTTP layer
will fail to serialize this and will either raise or send invalid JSON. The public docs
show `:now` as a valid top-level `start_date` value, creating a reasonable expectation
that it works at the phase level too.

**Fix:** Apply `stringify_date/1` to both date fields inside `phase_build/1`:

```elixir
# in phase_build/1, replace:
"start_date" => p.start_date,
# ...
"end_date" => p.end_date,

# with:
"start_date" => stringify_date(p.start_date),
# ...
"end_date" => stringify_date(p.end_date),
```

Add a test asserting that `phase_start_date(:now)` produces `"now"` in `phase_build/1`
output to lock in the behavior.

---

### WR-02: `start_date/2` accepts any term — `stringify_date/1` has no fallthrough clause

**File:** `lib/lattice_stripe/builders/subscription_schedule.ex:129,332-336`

**Issue:** `start_date/2` (line 129) has no guard on the `date` parameter, meaning any
value is accepted at the setter call site. However `stringify_date/1` only handles
`:now`, integers, binaries, and `nil`. An arbitrary atom (e.g., `:yesterday`) passes
through `start_date/2` successfully but crashes with a `FunctionClauseError` deep inside
`build/1`. The error message points into the private helper, giving the caller no
actionable context. The same gap exists for phase setters `phase_start_date/2` and
`phase_end_date/2` (lines 236, 224) if the fix from WR-01 is applied.

**Fix — option A (guard at setter):**

```elixir
@spec start_date(t(), :now | integer() | String.t()) :: t()
def start_date(%__MODULE__{} = b, :now), do: %{b | start_date: :now}
def start_date(%__MODULE__{} = b, date) when is_integer(date) or is_binary(date),
  do: %{b | start_date: date}
```

**Fix — option B (fallthrough in stringify_date):**

```elixir
defp stringify_date(v) when is_atom(v) and not is_nil(v), do: Atom.to_string(v)
```

Option A provides an earlier, clearer error; option B is more defensive and consistent
with how `to_string_if_atom/1` handles enum atoms elsewhere in the module. Choose based
on whether arbitrary atoms should be accepted (option B) or rejected (option A).

## Info

### IN-01: `fuse` declared dev-only but circuit-breaker guide implies runtime availability

**File:** `mix.exs:207`

**Issue:** `{:fuse, "~> 2.5", only: [:dev, :test]}` means `fuse` is not a transitive
dependency for library users in production. The guides list (`guides/circuit-breaker.md`
in the `extras` list, line 26) and the CLAUDE.md v1.2 roadmap include circuit-breaker
as a production feature. If the circuit-breaker implementation in `LatticeStripe` itself
calls into `fuse` at runtime, library users will encounter `UndefinedFunctionError` in
production (`:fuse` not started). If the feature is instead user-side only (users add
`fuse` themselves), the guide should say so, and the dev dep is fine.

**Fix:** Confirm intent, then either:
- Make it an optional runtime dep: `{:fuse, "~> 2.5", optional: true}` — so users who
  want circuit breaking add it, and the SDK's compile-time dependency is documented.
- Or remove it from `mix.exs` entirely and document in the guide that users must add
  `:fuse` themselves (if LatticeStripe does not call fuse directly).

---

_Reviewed: 2026-04-16T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
