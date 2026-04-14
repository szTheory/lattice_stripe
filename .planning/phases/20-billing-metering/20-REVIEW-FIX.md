---
phase: 20-billing-metering
fixed_at: 2026-04-14T00:00:00Z
review_path: .planning/phases/20-billing-metering/20-REVIEW.md
iteration: 2
findings_in_scope: 7
fixed: 6
skipped: 1
status: partial
---

# Phase 20: Code Review Fix Report

**Fixed at:** 2026-04-14
**Source review:** .planning/phases/20-billing-metering/20-REVIEW.md
**Iteration:** 2

**Summary:**
- Findings in scope: 7 (2 warning + 5 info, fix_scope=all)
- Fixed: 6 (WR-01, WR-02 in iteration 1; IN-01, IN-02, IN-04, IN-05 in iteration 2)
- Skipped: 1 (IN-03 — false positive)

This report supersedes the iteration-1 report. Iteration 1 addressed the two
warnings (WR-01, WR-02); iteration 2 addresses the four actionable Info
findings and documents the IN-03 false-positive skip.

## Fixed Issues

### WR-01: `check_proration_required/2` crashes on non-map params

**Files modified:** `lib/lattice_stripe/billing/guards.ex`
**Commit:** a347ee5
**Iteration:** 1
**Applied fix:** Added `when is_map(params)` guard to the existing true-branch
clause and introduced a fallthrough clause that returns
`{:error, %Error{type: :proration_required}}` with an updated message noting
params must be a map. Prevents `BadMapError` when callers accidentally pass
`nil`, keyword lists, or lists. Verified with `mix compile
--warnings-as-errors` and `mix test
test/lattice_stripe/billing/meter_guards_test.exs` (8 tests, 0 failures).

### WR-02: `:ok = Guards.check_meter_value_settings!(params)` is a hidden MatchError trap

**Files modified:** `lib/lattice_stripe/billing/meter.ex`, `lib/lattice_stripe/billing/meter_event_adjustment.ex`
**Commit:** 295f8ed
**Iteration:** 1
**Applied fix:** Dropped the `:ok =` prefix at both call sites (`meter.ex:98`
and `meter_event_adjustment.ex:52`), trusting the bang-guard contract (raise on
error, return on success). Removes fragile coupling that would crash with
`MatchError` if a future guard branch ever returns a non-`:ok` success
sentinel. Verified with `mix compile --warnings-as-errors` and `mix test
test/lattice_stripe/billing/meter_test.exs
test/lattice_stripe/billing/meter_event_adjustment_test.exs` (38 tests, 0
failures).

### IN-01: `Billing.Meter.update/4` docstring claims "only display_name is mutable" but doesn't enforce

**Files modified:** `lib/lattice_stripe/billing/meter.ex`
**Commit:** f2e8c04
**Iteration:** 2
**Applied fix:** Softened the `@doc` for `Meter.update/4` from the absolute
"Only `display_name` is mutable per Stripe API docs" to a forward-compatible
framing: "At time of writing, Stripe only mutates `display_name`; other keys
in `params` are passed through to the API for forward compatibility." This
aligns the docstring with the pure pass-through behavior and avoids silent
rot if Stripe later exposes additional mutable fields. Kept the compile-time
warning variant out of scope — the softened wording is the low-risk option
the reviewer explicitly offered. Verified with `mix compile
--warnings-as-errors` and `mix test test/lattice_stripe/billing/meter_test.exs`
(28 tests, 0 failures).

### IN-02: `MeterEventAdjustment.create/3` duplicates the cancel-presence check

**Files modified:** `lib/lattice_stripe/billing/meter_event_adjustment.ex`
**Commit:** 1981cca
**Iteration:** 2
**Applied fix:** Removed the redundant `Resource.require_param!(params,
"cancel", ...)` call from `create/3`. `Guards.check_adjustment_cancel_shape!/1`
already has a fallthrough clause that raises `ArgumentError` with a more
informative message when `cancel` is missing or misshapen, so the earlier
require_param! was dead overlap. Added an inline comment explaining that
shape validation is delegated to the guard. Kept the `event_name`
require_param! call since it is not covered elsewhere. Verified with `mix
compile --warnings-as-errors` and `mix test
test/lattice_stripe/billing/meter_event_adjustment_test.exs` (10 tests, 0
failures).

### IN-04: `verify_meter_endpoints.exs` silently succeeds without exit code

**Files modified:** `scripts/verify_meter_endpoints.exs`
**Commit:** bd0eb38
**Iteration:** 2
**Applied fix:** Made the exit branch symmetric by adding an explicit `else
System.halt(0)` arm to the final `if failures > 0 do ... end` block. Before
the fix, the success path relied on implicit script exit, which `mix run`
does not propagate reliably, so a regression could slip through CI. Now the
script always terminates via `System.halt/1`, matching the header comment's
"Exit 0 when all succeed" promise. Verified by re-reading the file (line
125 now contains `System.halt(0)`). Did not execute the script because it
requires a running stripe-mock; the edit is a single-line control-flow
change and Tier 1 verification is sufficient.

### IN-05: `guides/metering.md` references GUARD-02 for payload masking but the guard is an Inspect protocol, not a Billing.Guards function

**Files modified:** `test/lattice_stripe/billing/meter_event_test.exs`, `lib/lattice_stripe/billing/guards.ex`
**Commit:** 0017b27
**Iteration:** 2
**Applied fix:** Two-part reconciliation:

1. Renamed the test describe block from `"Inspect masking (GUARD-02 /
   T-20-04 payload masking)"` to `"Inspect masking (PII-01 / T-20-04 payload
   masking)"` in `meter_event_test.exs:44`. PII-01 is a fresh, unambiguous
   tag for the Inspect-protocol-based masking, avoiding the conflict with
   GUARD-02's true meaning (the `@doc` contract on `MeterEvent.create/3`).
2. Added a discoverability comment block at the top of `billing/guards.ex`
   mapping GUARD-01, GUARD-02, and GUARD-03 to their respective enforcement
   sites, and calling out that PII masking lives in `meter_event.ex` as an
   Inspect protocol, not here. This gives readers grep-searching for
   `GUARD-0N` a single entry point that explains the numbering scheme.

`guides/metering.md` itself already uses GUARD-01 → GUARD-03 correctly and
does not textually reference GUARD-02, so no guide edit was needed. Verified
with `mix compile --warnings-as-errors` and `mix test
test/lattice_stripe/billing/meter_event_test.exs
test/lattice_stripe/billing/meter_guards_test.exs` (17 tests, 0 failures).

## Skipped Issues

### IN-03: Integration test uses double-nested `list_resp.data.data`

**File:** `test/lattice_stripe/billing/meter_integration_test.exs:57`
**Reason:** skipped — false positive. The gap-closure verification for this
phase confirmed `list_resp.data.data` is the correct navigation, not a typo.
`list_resp` is a `%LatticeStripe.Response{}`; `list_resp.data` is a
`%LatticeStripe.List{}` (the list envelope wrapper, not a plain list); and
`list_resp.data.data` is the actual array of decoded structs. The reviewer
misread the shape. The existing assertion accurately reflects the documented
`Response -> List` wrapping pattern used across all `list/2` endpoints. No
change applied.
**Original issue:** Reviewer flagged `assert is_list(list_resp.data.data)` as
a typo and brittle navigation. Reality: it is the canonical pattern and
changing it would break the envelope contract.

---

_Fixed: 2026-04-14_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
