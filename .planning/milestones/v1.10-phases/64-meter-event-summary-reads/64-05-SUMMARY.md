---
phase: 64-meter-event-summary-reads
plan: 05
subsystem: api
tags: [stripe, billing, metering, meter-event-summary, guards, validation, elixir, mox]

# Dependency graph
requires:
  - phase: 64-meter-event-summary-reads
    provides: "64-03's list/4 and stream!/4 with their id guard and three require_param! calls, and the ## Timestamp alignment moduledoc section written to receive a raise sentence"
  - phase: 20-billing-meters
    provides: "LatticeStripe.Billing.Guards, its numbered discoverability comment block, and check_meter_value_settings!/1 as the message and total-fallback shape template"
provides:
  - "LatticeStripe.Billing.Guards.check_summary_window!/2 — a pre-network ArgumentError on a start_time or end_time misaligned to the divisor implied by value_grouping_window (GUARD-04, MTR-01)"
  - "Two call sites in MeterEventSummary.list/4 and stream!/4, each naming its own function in the message"
  - "The GUARD-04 entry in guards.ex's numbered block, making the guard findable alongside GUARD-01 through GUARD-03"
  - "The raise sentence the ## Timestamp alignment moduledoc section was left waiting for by 64-03"
affects: [64-06-pagination-proof, 64-07-metering-guide, 64-08-docs-gate, 64-09-artifact-inventory]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A guard whose pass-through cases are named hatches with inline rationale, not accidents of control flow — each is asserted by its own test so a later contributor cannot 'fix' it"
    - "One arity-2 guard serving two callers, the second argument carrying the caller's fun/arity so one helper yields two message sets (the validate_id!/2 pattern, applied again)"
    - "An error message that prints the arithmetic and refuses to apply it — floor and ceil shown side by side, neither chosen"

key-files:
  created: []
  modified:
    - lib/lattice_stripe/billing/guards.ex
    - lib/lattice_stripe/billing/meter_event_summary.ex
    - test/lattice_stripe/billing/meter_guards_test.exs
    - test/lattice_stripe/billing/meter_event_summary_test.exs

key-decisions:
  - "The absent-window case computes divisor 60 rather than skipping: Stripe states the minute rule on start_time and end_time themselves, independently of the value_grouping_window clause, so it applies to every query"
  - "Both pass-through hatches are implemented as explicit clauses with inline comments naming which hatch they are and why, because a guard that silently passes reads like a bug to the next contributor"
  - "The guard is the LAST of the five pre-network raises, so a missing timestamp reports as missing rather than being swallowed by the non-integer hatch"
  - "A pre-existing test and a moduledoc example both paired a \"day\" window with merely minute-aligned timestamps — both were corrected to 00:00 UTC values rather than the guard being weakened"
  - "No Stripe error code for misalignment is named or matched anywhere: that code is undocumented, which is the reason the guard exists"

patterns-established:
  - "Pattern 1: forward-compatibility hatches are asserted by a named test, not assumed — an unrecognised enum value passing through is a design property with a test that says so"
  - "Pattern 2: the ±1 boundary matrix is written as a single flat comprehension over (window, key, offset), keeping credo nesting at one level while covering twelve cases"
  - "Pattern 3: a wiring test for a deferred-execution function calls it inside assert_raise WITHOUT consuming the result, with a comment saying why consuming would prove the wrong thing"

requirements-completed: [MTR-01]

coverage:
  - id: D1
    description: "check_summary_window!/2 raises ArgumentError before any network call when start_time or end_time is not aligned to the divisor implied by value_grouping_window (60 / 3600 / 86400)"
    requirement: "MTR-01"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_guards_test.exs#2. no window + start_time one second past a minute boundary → ArgumentError"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_guards_test.exs#5. hour window + minute-aligned but not hour-aligned → ArgumentError"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_guards_test.exs#7. day window + hour-aligned but not day-aligned → ArgumentError"
        status: pass
    human_judgment: false
  - id: D2
    description: "The boundary edge holds on both sides for every divisor: the exact boundary passes, boundary±1 raises, on both start_time and end_time"
    requirement: "MTR-01"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_guards_test.exs#8a. the exact boundary passes for every divisor, on both keys"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_guards_test.exs#8b. boundary ±1 second raises for every divisor, on both keys"
        status: pass
    human_judgment: false
  - id: D3
    description: "Both mandatory pass-through hatches hold: an unrecognised value_grouping_window value, and an absent or non-integer timestamp, pass unguarded"
    requirement: "MTR-01"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_guards_test.exs#9. an unrecognised window value passes through unguarded, however misaligned"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_guards_test.exs#10. an absent timestamp passes through unguarded"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_guards_test.exs#11. an unparseable timestamp passes through unguarded"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_guards_test.exs#12. a non-map argument passes through unguarded"
        status: pass
    human_judgment: false
  - id: D4
    description: "The message names the offending value, the rule, the real-world cause, and both the floor and ceil expressions without choosing between them"
    requirement: "MTR-01"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_guards_test.exs#13. the message names the value, the rule, the cause, and both expressions"
        status: pass
      - kind: other
        ref: "mix run -e 'rescue e -> IO.puts(e.message)' — message reviewed verbatim against CONTEXT lines 370-383"
        status: pass
    human_judgment: true
    rationale: "Whether the microcopy actually lands for a reader meeting it cold at 3am is not mechanically checkable. The substring assertions prove the five required elements are present, not that the paragraph reads well."
  - id: D5
    description: "The guard is called from both list/4 and stream!/4, after the require_param! block and before %Request{}, and the message names whichever function the caller invoked"
    requirement: "MTR-01"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_guards_test.exs#list/4 raises on a misaligned window, naming list/4, before any request"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_guards_test.exs#stream!/4 raises at call time on a misaligned window, naming stream!/4"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_guards_test.exs#a missing required filter is reported before the window alignment"
        status: pass
      - kind: other
        ref: "grep -c 'check_summary_window!' lib/lattice_stripe/billing/meter_event_summary.ex => 2"
        status: pass
    human_judgment: false
  - id: D6
    description: "No auto-aligning helper exists at any arity — D-10/D-11's rejection is encoded structurally, not only in prose"
    requirement: "MTR-01"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_guards_test.exs#16. the guard exists at arity 2 and no aligning helper exists at any arity"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#stream! has no non-bang twin — auto-pagination raises, it does not return tuples (64-03's align_window refutation, still green)"
        status: pass
    human_judgment: false

# Metrics
duration: 11min
completed: 2026-07-28
status: complete
---

# Phase 64 Plan 05: GUARD-04 Window Alignment Summary

**A caller who passes a subscription's raw period boundaries to `list/4` or `stream!/4` now gets an `ArgumentError` before the socket opens — naming the offending value, the boundary it missed, why their input was almost certainly never aligned in the first place, and both ways to fix it — instead of an HTTP 400 whose error code Stripe does not document.**

## Performance

- **Duration:** ~11 min
- **Started:** 2026-07-28T23:53:00Z
- **Completed:** 2026-07-29T00:04:30Z
- **Tasks:** 2 of 2
- **Files modified:** 4

## Accomplishments

- **`Billing.Guards.check_summary_window!/2` ships.** It cases `params["value_grouping_window"]` to a divisor — 60 when absent, 3600 for `"hour"`, 86400 for `"day"` — then checks `start_time` and then `end_time`, raising on the first failure. The absent-window case is **60, not a skip**: Stripe states the minute rule on `start_time` and `end_time` themselves, independently of the window clause, so it governs every query whether bucketed or not.
- **Both mandatory hatches are explicit clauses with inline rationale, and both are asserted by name.** An unrecognised window value returns `:ok` without checking anything (Stripe added `"day"` to that enum in mid-2024; a closed guard would have broken every caller on the day it was extended). An absent or non-integer timestamp is skipped (`require_param!/3` owns absence, Stripe's own type validation owns the wrong type). Each carries a comment saying which hatch it is, because a guard that silently passes reads like a bug to the next contributor.
- **The message prints the arithmetic and refuses to apply it.** It names the parameter and value, the boundary missed, that Stripe answers with HTTP 400, that `current_period_start`/`current_period_end` derive from `billing_cycle_anchor` and are almost never aligned — then shows floor and ceil side by side and states that the library will not choose, because the choice changes which usage the window covers. `Integer.floor_div/2` throughout, not `div/2`, which truncates toward zero and rounds the wrong way for negative inputs.
- **Wired into both entry points at the correct position** — after the three `require_param!` calls and before `%Request{}`, matching `meter.ex:111`. Both orderings are load-bearing and both are tested: a missing timestamp still reports as *missing* rather than being swallowed by the non-integer hatch, and in `stream!/4` the raise still precedes the deferred stream construction.
- **One arity-2 helper, two message sets.** Each call site passes its own `fun/arity`, exactly as `validate_id!/2` does, so `stream!/4` reports `stream!/4` and no second helper was grown. Asserted with a `refute err.message =~ "list/4"`.
- **A 17-case matrix plus 8 wiring tests.** All three divisors, both sides of the boundary on both keys, both hatches, the first-failure ordering, both message sets, and a structural refutation that `align_window` exists at no arity.
- **The moduledoc section 64-03 left waiting got its sentence** — two sentences added ahead of the existing **"This library will not align them for you"** paragraph, with no restructuring and no incidence figure.

## Key Decisions

### The unrecognised-window hatch is asserted, not assumed

The plan called this out and it is worth recording why the distinction matters. A guard that returns `:ok` for `"week"` looks identical, in the source, to a guard with a hole in it. The difference between design and defect lives in a test name — `"9. an unrecognised window value passes through unguarded, however misaligned"` — and in the comment on the `nil ->` clause. Without both, the first contributor to notice the gap closes it, and the library breaks on the day Stripe extends the enum a second time.

### The pre-existing day-window test was corrected, not the guard weakened

`meter_event_summary_test.exs:55` ("places `value_grouping_window` on the wire when supplied") paired `"day"` with `@window`'s merely minute-aligned timestamps — a combination the new guard correctly refuses. The same pairing existed in the moduledoc's hour-bucket example, which built on the total example's params.

Both were the *test fixture and the docs* being wrong, not the guard: `1_753_620_000` is not 00:00 UTC and Stripe would have rejected that call with a 400. Both were moved to `86_400 * 20_297` and `* 20_298`, with a comment in the test saying why. Weakening the guard to accommodate a fixture that encoded an invalid call would have been the wrong direction, and it would have removed exactly the protection the phase exists to add.

### No incidence figure, no Stripe error code

Neither the guard's `@doc`, its message, nor the moduledoc says how often this trap fires (D-12: the mechanism is verified, the frequency is not). Nothing anywhere in the diff names or pattern-matches a Stripe error code for misalignment (F-07/O-03) — that code being undocumented is precisely the reason the 400 cannot be improved after the fact and must be prevented instead.

## Deviations from Plan

### 1. [Rule 3 - Blocking] `deps/` was absent in a fresh worktree

- **Found during:** the first `mix test` run, before Task 1's RED gate
- **Issue:** `mix test` refused to run — fourteen dependencies "not available".
- **Fix:** ran `mix deps.get`, which the phase gates explicitly permit when `deps/` is missing.
- **`mix.lock` is byte-identical afterward.** SHA-1 `a701e073ebeb1f7740f8c97ae162181cc004a17b` before and after; `git status --short` reports no change to it. No dependency was added, updated or substituted.
- **Files modified:** none

### 2. [Rule 1 - Bug] A pre-existing test and a moduledoc example encoded a call Stripe would reject

- **Found during:** Task 2, at the first full run of `test/lattice_stripe/billing/`
- **Issue:** `meter_event_summary_test.exs:55` built `Map.put(@window, "value_grouping_window", "day")` where `@window`'s timestamps are minute-aligned but not day-aligned, so the new guard raised. `meter_event_summary.ex`'s moduledoc had the same latent defect: its `"hour"` example was `Map.put(params, ...)` over the total example's params, which are not hour-aligned either.
- **Fix:** both moved to 00:00 UTC timestamps (`1_753_660_800` / `1_753_747_200`), with a comment in the test recording why those values and not `@window`'s. `@window` itself was left alone — it is correct for every un-windowed call, which is what the other twelve tests in that file make.
- **Files modified:** `test/lattice_stripe/billing/meter_event_summary_test.exs`, `lib/lattice_stripe/billing/meter_event_summary.ex`
- **Commit:** `9870f18`

No other deviations. No architectural changes, no authentication gates, no auto-fix attempt limit reached.

## Verification

All gates run at commit `9870f18`. `mix ci` was **not** run — per the phase gates it is red at clean HEAD on 42 pre-existing ExDoc warnings.

| Gate | Result |
|------|--------|
| `mix test test/lattice_stripe/billing/meter_guards_test.exs test/lattice_stripe/billing/guards_test.exs` | 43 tests, 0 failures |
| `mix test test/lattice_stripe/billing/` | 184 tests, 0 failures, 1 skipped |
| `mix test` | **2289 tests, 0 failures, 1 skipped** (204 excluded) — base was 2264; threshold was >= 2188 |
| `mix format --check-formatted` | exit 0 |
| `mix compile --force --warnings-as-errors` | exit 0 |
| `mix credo --strict` | 2285 mods/funs, **no issues** |
| `mix docs` | exit 0, **42 warnings** (== baseline, never up), **0** naming `guards.ex` or `meter_event_summary.ex` |
| `grep -c 'check_summary_window!' lib/.../meter_event_summary.ex` | 2 |
| `grep -c 'GUARD-04' lib/.../guards.ex` | 1 |
| `function_exported?(Guards, :align_window, 1 \| 2)` | `false`, `false` |

The pre-existing retry-telemetry flake at `test/lattice_stripe/client_test.exs:912` did not fire in this plan's full-suite run.

### Success criteria

- [x] The alignment matrix covers all three divisors, both sides of each boundary, and both mandatory hatches.
- [x] The guard is called from exactly two sites, each naming its own function in the message.
- [x] No auto-aligning helper exists at any arity, asserted structurally.
- [x] No Stripe error code for misalignment is named or matched anywhere in the source.

## Known Stubs

None. No placeholder values, no TODO/FIXME, no skipped tests introduced. The one skipped test in the suite is pre-existing and unrelated to metering.

## Threat Flags

None. This plan added no network endpoint, auth path, file access pattern or schema change — it only refuses to make a request the library was previously willing to make.

Register dispositions: **T-64-12** (a misaligned window silently returning a wrong total) is mitigated by the raise, deliberately without auto-correction. **T-64-13** (a guard rejecting a future valid enum value) is mitigated by the unrecognised-window hatch, asserted by a named test rather than left implicit. **T-64-01** (`meter_id` interpolation) is unchanged and still first in both entry points, now additionally asserted by an ordering test in this plan's wiring block. **T-64-SC** holds: zero packages installed, `mix.lock` byte-identical.

## For Next Phase

- **64-06 (pagination proof)** — heads up, and this is the one thing that could bite: any params map you build with `"value_grouping_window" => "hour"` or `"day"` must now carry **aligned** timestamps or `stream!/4` raises before your Mox expectation is ever reached. Use `1_753_660_800` / `1_753_747_200` (both 00:00 UTC, valid for every divisor). D-30 assertion 2 specifically pairs a window with page-2 base-params preservation, so it is the assertion most likely to hit this.
- **64-07 (metering guide)** — the guard exists and the guide may now describe it in the present tense. Its message is the canonical wording; do not paraphrase the floor/ceil arithmetic differently in prose. Still no incidence figure (D-12).
- **64-08 (docs gate)** — `mix docs` baseline is unchanged at 42, and `guards.ex` contributes none. `Billing.Guards` is `@moduledoc false`, so `check_summary_window!/2`'s `@doc` never reaches HexDocs; the user-facing statement of the rule lives in `MeterEventSummary`'s moduledoc, which is where the docs gate should check for it.
- **64-09 (artifact inventory)** — the phase's guard inventory is now GUARD-01 through GUARD-04, all four discoverable from the numbered block at the top of `guards.ex`.

## Self-Check: PASSED

- `lib/lattice_stripe/billing/guards.ex` — FOUND
- `lib/lattice_stripe/billing/meter_event_summary.ex` — FOUND
- `test/lattice_stripe/billing/meter_guards_test.exs` — FOUND
- `test/lattice_stripe/billing/meter_event_summary_test.exs` — FOUND
- `.planning/phases/64-meter-event-summary-reads/64-05-SUMMARY.md` — FOUND
- Commit `901e0d6` (test/RED, Task 1) — FOUND
- Commit `e97ffdc` (feat/GREEN, Task 1) — FOUND
- Commit `78023cc` (test/RED, Task 2) — FOUND
- Commit `9870f18` (feat/GREEN, Task 2) — FOUND

## TDD Gate Compliance

Both tasks ran the full cycle and both gate sequences are present in git log in order:

- **Task 1:** `test(64-05)` at `901e0d6` — RED, 17 new tests, 17 failures, every one an `UndefinedFunctionError` on the not-yet-written `check_summary_window!/2`. Then `feat(64-05)` at `e97ffdc` — GREEN, 43 tests, 0 failures.
- **Task 2:** `test(64-05)` at `78023cc` — RED, 8 new tests, 3 failures (the three that assert the new raise). The other five were green at RED and correctly so: they assert ordering already owned by 64-03's guards and happy-path calls that must keep working, which are regression locks rather than gated behavior, and each would have failed had the wiring been placed wrongly. Then `feat(64-05)` at `9870f18` — GREEN, full suite 2289 tests, 0 failures.

No REFACTOR commits: neither implementation needed cleanup, and an empty refactor commit would be noise. No test passed unexpectedly during either RED gate for behavior the task was meant to add.
