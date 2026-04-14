---
phase: 20-billing-metering
reviewed: 2026-04-14T00:00:00Z
depth: standard
files_reviewed: 23
files_reviewed_list:
  - guides/error-handling.md
  - guides/metering.md
  - guides/subscriptions.md
  - guides/telemetry.md
  - guides/testing.md
  - guides/webhooks.md
  - lib/lattice_stripe/billing/guards.ex
  - lib/lattice_stripe/billing/meter.ex
  - lib/lattice_stripe/billing/meter/customer_mapping.ex
  - lib/lattice_stripe/billing/meter/default_aggregation.ex
  - lib/lattice_stripe/billing/meter/status_transitions.ex
  - lib/lattice_stripe/billing/meter/value_settings.ex
  - lib/lattice_stripe/billing/meter_event.ex
  - lib/lattice_stripe/billing/meter_event_adjustment.ex
  - lib/lattice_stripe/billing/meter_event_adjustment/cancel.ex
  - mix.exs
  - scripts/verify_meter_endpoints.exs
  - test/lattice_stripe/billing/meter_event_adjustment_test.exs
  - test/lattice_stripe/billing/meter_event_test.exs
  - test/lattice_stripe/billing/meter_guards_test.exs
  - test/lattice_stripe/billing/meter_integration_test.exs
  - test/lattice_stripe/billing/meter_test.exs
  - test/support/fixtures/metering.ex
findings:
  critical: 0
  warning: 2
  info: 5
  total: 7
status: issues_found
---

# Phase 20: Code Review Report

**Reviewed:** 2026-04-14
**Depth:** standard
**Files Reviewed:** 23
**Status:** issues_found

## Summary

Phase 20 delivers the Billing Metering stack (`Meter`, `MeterEvent`,
`MeterEventAdjustment`) plus two pre-flight guards (GUARD-01 value_settings,
GUARD-03 adjustment cancel shape) and a 620-line metering guide. The code
is cohesive, follows established Phase 15/17 patterns (string-keyed wire
format, `from_map/1` decoders, `extra: %{}` forward-compatibility escape
hatches, bang variants, resource-module layering), and is well-tested with
an 8-case guard matrix, Inspect masking tests, MockTransport happy-path
tests, and a stripe-mock lifecycle integration test.

No critical security or correctness issues found. The PII-masking Inspect
protocol on `MeterEvent` is implemented correctly (allowlist-only). The
guards fail-fast before hitting the network, matching their docstrings.
The two-layer idempotency story is documented in both module doc and
guide.

Two warnings are raised around defensive-programming gaps that could surface
as cryptic MatchError/FunctionClauseError at call sites. Five info items
note small polish opportunities (docstring drift, redundant field access,
duplicated validation, integration-test brittleness).

## Warnings

### WR-01: `check_proration_required/2` crashes on non-map params

**File:** `lib/lattice_stripe/billing/guards.ex:20-39`
**Issue:** `check_proration_required(%Client{require_explicit_proration: true}, params)`
has no `is_map(params)` guard and unconditionally calls `params["subscription_details"]`
and `Map.has_key?(params, "proration_behavior")` inside `has_proration_behavior?/1`.
If a caller ever passes a non-map (`nil`, keyword list, or list accidentally),
`Map.has_key?/2` raises `BadMapError`, producing a confusing stack trace that
points inside `Guards`, not the caller. Every other public guard in this file
either pattern-matches a map in the function head (`check_meter_value_settings!/1`,
`check_adjustment_cancel_shape!/1`) or has an explicit fallthrough. This one
silently assumes map-ness.

**Fix:** Add a matching head that returns `:ok` (or raises `ArgumentError`)
when params is not a map, consistent with `check_meter_value_settings!/1`'s
`def check_meter_value_settings!(_non_map), do: :ok` pattern:

```elixir
def check_proration_required(%Client{require_explicit_proration: true}, params)
    when is_map(params) do
  # ...existing body...
end

def check_proration_required(%Client{require_explicit_proration: true}, _params) do
  {:error,
   %Error{
     type: :proration_required,
     message: "proration_behavior is required; params must be a map"
   }}
end
```

### WR-02: `:ok = Guards.check_meter_value_settings!(params)` is a hidden MatchError trap

**File:** `lib/lattice_stripe/billing/meter.ex:98` and `lib/lattice_stripe/billing/meter_event_adjustment.ex:52`
**Issue:** Both call sites wrap the guard with `:ok = Guards.check_*(...)`. Today
every non-raising branch of both guards returns the literal `:ok`, so the match
succeeds. However, the bang-guard contract is "raise on error, return `:ok` on
success" — the pattern match adds zero value and creates a fragile coupling:
if a future guard branch ever returns, say, `{:ok, :warned}` (a natural
evolution for the `formula == "count"` Logger.warning branch), both call sites
crash with a `MatchError` inside a resource module, which is a surprising
regression surface for a guard refactor.

**Fix:** Drop the `:ok =` prefix — the guard's documented contract already
guarantees the flow. Either:

```elixir
# Option A — trust the bang contract, ignore the return
Billing.Guards.check_meter_value_settings!(params)
```

Or if you want belt-and-suspenders, use `_ = `:

```elixir
_ = Billing.Guards.check_meter_value_settings!(params)
```

Apply the same change at `meter_event_adjustment.ex:52` for
`check_adjustment_cancel_shape!/1`.

## Info

### IN-01: `Billing.Meter.update/4` docstring claims "only display_name is mutable" but doesn't enforce

**File:** `lib/lattice_stripe/billing/meter.ex:133-143`
**Issue:** The `@doc` says "Only `display_name` is mutable per Stripe API docs"
but the function is a pure pass-through — any params map reaches Stripe. The
docstring reads like a contract but is only a comment. If Stripe later allows
additional fields, the docstring rots silently.

**Fix:** Either add a compile-time warning about extra keys:

```elixir
@allowed_update_fields ~w(display_name)
# ...
extra = Map.keys(params) -- @allowed_update_fields
if extra != [], do: Logger.warning("Billing.Meter.update/4: ignoring keys not currently mutable by Stripe: #{inspect(extra)}")
```

Or soften the docstring to "At time of writing, Stripe only mutates
`display_name`; other keys are passed through for forward compatibility."

### IN-02: `MeterEventAdjustment.create/3` duplicates the cancel-presence check

**File:** `lib/lattice_stripe/billing/meter_event_adjustment.ex:48-52`
**Issue:** `Resource.require_param!(params, "cancel", ...)` already raises
`ArgumentError` when `"cancel"` is missing. The next line
`Guards.check_adjustment_cancel_shape!(params)` also has a fallthrough clause
that raises when `"cancel"` is missing (`meter_event_adjustment.ex` guard
line 145-150). The first check is dead overlap; only the guard's shape check
(nested identifier) is non-redundant.

**Fix:** Drop `Resource.require_param!(params, "cancel", ...)` since
`check_adjustment_cancel_shape!/1` covers both "missing `cancel`" and "wrong
shape" with a more informative error message. Keep the `event_name` require_param
call.

### IN-03: Integration test uses double-nested `list_resp.data.data`

**File:** `test/lattice_stripe/billing/meter_integration_test.exs:57`
**Issue:** `assert is_list(list_resp.data.data)` — the double `.data.data`
navigation (Response.data → List.data) reads as a typo and is brittle if the
Response/List types change. It also only asserts list-ness, not correctness
of items.

**Fix:** Extract the inner list with an alias or use a more explicit accessor:

```elixir
{:ok, %LatticeStripe.Response{data: %LatticeStripe.List{data: meters}}} =
  Meter.list(client, %{"limit" => 3})
assert is_list(meters)
```

### IN-04: `verify_meter_endpoints.exs` silently succeeds without exit code

**File:** `scripts/verify_meter_endpoints.exs:121-125`
**Issue:** Script `System.halt(1)` on failure but has no explicit `System.halt(0)`
on success. Since `mix run` doesn't propagate a script's implicit exit status
reliably, CI could miss a regression if invoked via `mix run`. Minor, but the
comment header promises "Exit 0 when all succeed".

**Fix:** Add an explicit `System.halt(0)` after the success branch, or make
the script exit structure symmetric:

```elixir
if failures > 0 do
  IO.puts("#{failures} endpoint(s) FAILED ...")
  System.halt(1)
else
  System.halt(0)
end
```

### IN-05: `guides/metering.md` references GUARD-02 for payload masking but the guard is an Inspect protocol, not a Billing.Guards function

**File:** `guides/metering.md:500-533` and `test/lattice_stripe/billing/meter_event_test.exs:44`
**Issue:** The guide frames the payload-hiding Inspect protocol as "GUARD-02 /
T-20-04" and `meter_event_test.exs` labels its describe block `"Inspect masking
(GUARD-02 / T-20-04 payload masking)"`. However, `Billing.Guards` has only
GUARD-01 (`check_meter_value_settings!/1`) and GUARD-03
(`check_adjustment_cancel_shape!/1`) — there is no GUARD-02 function in the
module. Readers grep-searching for `GUARD-02` will find a test label pointing
at a module where it doesn't exist. This is documentation/test labeling drift,
not a bug, but it's confusing.

**Fix:** Either rename the Inspect-masking tag (e.g. "PII-01: MeterEvent payload
masking") or add a `# GUARD-02: Inspect-protocol-based PII masking, see
meter_event.ex defimpl` comment in `billing/guards.ex` to make the numbering
scheme discoverable from one entry point.

---

_Reviewed: 2026-04-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
