---
phase: 13
plan: 02
subsystem: billing-test-clocks
tags: [wave1, struct, test_clock, d03_atomization, a13g_metadata_probe]
dependency_graph:
  requires:
    - "13-01 (Error type whitelist, idempotency_key_prefix, TestSupport rename, real_stripe exclusion, wave-0 stubs)"
  provides:
    - "LatticeStripe.TestHelpers.TestClock struct + @type t"
    - "TestHelpers.TestClock.from_map/1 decoder (used by Plan 13-03 CRUD)"
    - "D-03 atomize_status whitelist (:ready, :advancing, :internal_failure) with forward-compat pass-through"
    - "A-13g metadata probe finding — metadata NOT supported on test clocks (affects Plan 13-05 cleanup strategy)"
  affects:
    - "Plan 13-03 (CRUD) — uses from_map/1 via Resource.unwrap_singular/unwrap_list"
    - "Plan 13-04 (advance + advance_and_wait) — returns this struct"
    - "Plan 13-05 (Testing.TestClock) — cleanup strategy must fall back from metadata marker to Owner-only + age-based Mix task"
tech_stack:
  added: []
  patterns:
    - "Phase 12 Product struct template (defstruct + @known_fields + from_map + atomize_*)"
    - "D-03 whitelist atomization — no String.to_atom, unknown values stay as String.t() (T-13-05 mitigation)"
    - "Unknown fields land in extra via Map.drop(map, @known_fields) (T-13-06 accept, forward-compat)"
key_files:
  created:
    - "lib/lattice_stripe/test_helpers/test_clock.ex"
  modified:
    - "test/lattice_stripe/test_helpers/test_clock_test.exs (replaced Wave 0 stub with 19 real unit tests)"
  deleted: []
decisions:
  - "A-13g resolved: metadata NOT supported on POST /v1/test_helpers/test_clocks (verified via Stripe OpenAPI spec + stripe-mock). Plan 13-05 must fall back from the D-13g marker strategy to Owner-only tracking + age-based Mix task cleanup."
  - "TestHelpers.TestClock struct intentionally omits :metadata — reflects Stripe's actual API surface."
  - "Struct-only scope: NO CRUD functions this plan (Plan 13-03), NO advance functions this plan (Plan 13-04). Phase 12 Product template was copied verbatim except the CRUD block was deliberately omitted."
metrics:
  duration: "~9 minutes"
  completed: "2026-04-11"
  tasks: 2
  files_touched: 2
  tests_added: 19
  tests_green: "729 tests, 0 failures (53 excluded)"
---

# Phase 13 Plan 02: TestHelpers.TestClock Struct Summary

**One-liner:** Shipped the `LatticeStripe.TestHelpers.TestClock` struct + `from_map/1` decoder + D-03 `atomize_status/1` whitelist on top of the Phase 12 Product template, and definitively resolved the A-13g metadata probe (NOT supported — Plan 05's cleanup strategy must fall back).

## Scope

Plan 13-02 establishes the struct skeleton that every downstream Test Clock function in Phase 13 will return. The struct is deliberately CRUD-free — `create/retrieve/list/stream!/delete` land in Plan 13-03, and `advance/advance_and_wait` land in Plan 13-04. This plan also answers the A-13g open question from phase research: whether Stripe exposes `metadata` on test clocks, which gates Plan 13-05's cleanup marker strategy.

## Tasks Executed

| # | Task                                                                       | Commit    | Files                                                                                    |
| - | -------------------------------------------------------------------------- | --------- | ---------------------------------------------------------------------------------------- |
| 1 | A-13g metadata probe (OpenAPI spec + stripe-mock)                          | `6704386` | (no code — finding captured in commit message)                                           |
| 2 | TDD RED: real unit tests replacing Wave 0 stub                             | `609bd4a` | `test/lattice_stripe/test_helpers/test_clock_test.exs`                                   |
| 2 | TDD GREEN: TestHelpers.TestClock struct + from_map + atomize_status        | `c3b07b6` | `lib/lattice_stripe/test_helpers/test_clock.ex`                                          |

## Metadata probe (A-13g)

**Finding: metadata NOT SUPPORTED on Stripe Test Clocks.**

Two independent sources confirm this:

1. **Stripe OpenAPI spec** (`https://raw.githubusercontent.com/stripe/openapi/master/openapi/spec3.sdk.json`, fetched 2026-04-11):
   - `POST /v1/test_helpers/test_clocks` request body (`application/x-www-form-urlencoded`) schema properties: `["expand", "frozen_time", "name"]` — **no `metadata`**.
   - `components.schemas["test_helpers.test_clock"]` properties: `["created", "deletes_after", "frozen_time", "id", "livemode", "name", "object", "status", "status_details"]` — **no `metadata`**.

2. **stripe-mock probe** (`stripe/stripe-mock:latest`, image digest `sha256:7c8bf1c22699719bb493334d9f3356b8f741c3795ab0c07cb716e856c0bc3296`):
   - `POST /v1/test_helpers/test_clocks` with `metadata[lattice_stripe_test_clock]=v1` returns HTTP 400:
     ```json
     {"error":{"message":"Request validation error: validator ... failed: additional properties are not allowed","type":"invalid_request_error"}}
     ```
   - Same request without `metadata` succeeds and returns a canonical test_clock object with no `metadata` field.

**Implication for Plan 13-05.** The D-13g marker strategy (tag clocks with `metadata.lattice_stripe_test_clock=v1` for post-hoc cleanup via a Mix task) is **NOT viable**. Plan 13-05 must fall back to:

- **Owner-only tracking** — `LatticeStripe.Testing.TestClock` registers each created clock with a per-test ExUnit owner process that deletes on test exit (handles the 99% happy path).
- **Age-based Mix task cleanup** — `mix lattice_stripe.test_clock.cleanup` deletes clocks by name prefix (e.g., `lattice-test-*`) and/or `created` timestamp threshold as a SIGKILL/crash safety net, not by tag.

The planner/orchestrator should revisit Plan 13-05 in Wave 2 to reflect this. **This plan does NOT modify Plan 13-05.**

**Consequence in Task 2's output.** The TestClock struct intentionally omits `:metadata` from both `@known_fields` and `defstruct`. The `@moduledoc` records the probe finding and points downstream to the Plan 13-05 fallback. A specific test asserts `refute :metadata in fields` so future attempts to add `:metadata` without new API evidence will fail loudly.

## Verification

- `mix compile --warnings-as-errors` — clean
- `mix test test/lattice_stripe/test_helpers/test_clock_test.exs` — **19 tests, 0 failures**
- `mix test` — **4 properties, 729 tests, 0 failures (53 excluded)** (up from 711 in Plan 13-01 → +18 tests; 13-01 counted the stub as 1 so net add is 18 real tests replacing 1 stub)
- All 13 acceptance grep checks pass (module name, `from_map`, all three `atomize_status` clauses, `extra: %{}`, object default, 100-limit moduledoc mention, NO `def create`, NO `def advance`)

## Deviations from Plan

**None — plan executed exactly as written.**

The plan instructed: "if Task 1's probe said metadata is unsupported, REMOVE `metadata` from the `@known_fields` list and the defstruct below." That instruction was followed. No other adjustments were needed.

No authentication gates. No architectural decisions. No out-of-scope discoveries. No CLAUDE.md-driven adjustments (the file's constraints — minimal deps, no Dialyzer, Elixir 1.15+, Jason/Finch/Plug stack — are all respected; this plan adds zero dependencies and zero modules outside the pre-declared file list).

## Known Stubs

None. This plan *eliminates* one of the Wave 0 stubs (`test/lattice_stripe/test_helpers/test_clock_test.exs`) by replacing it with 19 real assertions. The other two Wave 0 stubs (`test/lattice_stripe/testing/test_clock_test.exs`, `test/real_stripe/test_clock_real_stripe_test.exs`) remain pending for Plans 13-05 and 13-06 respectively, as documented in Plan 13-01's summary.

## Threat Model Coverage

| Threat ID | Disposition | How this plan addresses it |
|-----------|-------------|----------------------------|
| T-13-05 (DoS: atom table growth) | mitigate | `atomize_status/1` is whitelist-based with explicit clauses for `"ready"`, `"advancing"`, `"internal_failure"`, `nil`. All other binaries pass through as raw `String.t()`. No `String.to_atom/1`. Unit-tested with `"future_unknown_state"` → string pass-through. |
| T-13-06 (Tampering: unexpected fields in API response) | accept | `from_map/1` uses `Map.drop(map, @known_fields)` to sink unknown keys into `extra: %{}`. Unit-tested with `"future_field" => 42` assertion. Forward-compatible with any future Stripe schema addition. |

No new threat surface introduced. No `threat_flag:` entries.

## Self-Check: PASSED

- `lib/lattice_stripe/test_helpers/test_clock.ex` — FOUND
- `test/lattice_stripe/test_helpers/test_clock_test.exs` — FOUND (replaced, not created)
- Commit `6704386` (Task 1 probe) — FOUND in `git log`
- Commit `609bd4a` (TDD RED) — FOUND in `git log`
- Commit `c3b07b6` (TDD GREEN) — FOUND in `git log`
- 19 unit tests green
- Full suite: 729 tests, 0 failures
