---
phase: 13
plan: 06
subsystem: billing-test-clocks
tags: [wave3, testing, real_stripe, test_clock, case_template, live_stripe]
dependency_graph:
  requires:
    - "13-01 (Error whitelist, idempotency_key_prefix, TestSupport rename, :real_stripe exclusion)"
    - "13-02 (TestHelpers.TestClock struct + from_map/1 + A-13g metadata probe)"
    - "13-03 (TestHelpers.TestClock CRUD)"
    - "13-04 (advance/4, advance_and_wait/4, poll loop, telemetry)"
    - "13-05 (Testing.TestClock use-macro, Owner cleanup, Mix task)"
  provides:
    - "LatticeStripe.Testing.RealStripeCase CaseTemplate (test/support/)"
    - "Canonical first :real_stripe test (TestClock round-trip against live Stripe)"
    - ":real_stripe test tier pattern for phases 14-19"
  affects:
    - "Plan 13-07 (docs reference RealStripeCase and :real_stripe tier)"
    - "Phases 14-19 (copy test/real_stripe/test_clock_real_stripe_test.exs shape)"
tech_stack:
  added: []
  patterns:
    - "RealStripeCase CaseTemplate with env-var gate + sk_live_ safety guard"
    - "Dedicated Finch pool per CaseTemplate setup_all (LatticeStripe.RealStripeFinch)"
    - "Rescue-based clock cleanup in real_stripe tests to prevent account leak"
key_files:
  created:
    - "test/support/real_stripe_case.ex"
  modified:
    - "test/real_stripe/test_clock_real_stripe_test.exs (replaced Wave 0 stub)"
decisions:
  - "Used start_supervised Finch pool (LatticeStripe.RealStripeFinch) instead of lazy Process.whereis pattern, matching existing integration test convention"
  - "No metadata assertion in real_stripe test (A-13g: Stripe does not support metadata on test clocks, verified Plan 13-02)"
  - "Test calls TestHelpers.TestClock Backend directly (not Testing.TestClock use-macro) to avoid needing a dummy client module"
patterns_established:
  - "RealStripeCase: env-var gate with 4-branch case (nil, sk_live_, sk_test_, other) + CI flunk"
  - ":real_stripe test shape: create resource, exercise it, cleanup in rescue, assert deletion"
requirements_completed: [TEST-10]
metrics:
  duration: "~5 minutes"
  completed: "2026-04-12"
  tasks: 2
  files_touched: 2
  tests_added: 0
  tests_green: "4 properties, 810 tests, 0 failures (55 excluded)"
---

# Phase 13 Plan 06: RealStripeCase + Canonical :real_stripe Test Summary

**Shipped `LatticeStripe.Testing.RealStripeCase` CaseTemplate and the canonical first `:real_stripe` test -- a TestClock create/advance-30-days/delete round-trip against live Stripe test mode, establishing the test tier pattern for phases 14-19.**

## Performance

- **Duration:** ~5 minutes
- **Started:** 2026-04-12T04:05:11Z
- **Completed:** 2026-04-12
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `LatticeStripe.Testing.RealStripeCase` CaseTemplate with D-13i safety gate (sk_live_ guard, CI flunk, local skip)
- Canonical first `:real_stripe` test replacing Plan 01 stub -- exercises create, advance_and_wait (30 days), assert :ready, delete, assert gone
- Template established for phases 14-19 real_stripe tests

## Task Commits

Each task was committed atomically:

1. **Task 1: Create RealStripeCase CaseTemplate** - `613ccbd` (feat)
2. **Task 2: Canonical :real_stripe TestClock round-trip test** - `37cbe30` (feat)

## Files Created/Modified

- `test/support/real_stripe_case.ex` -- RealStripeCase CaseTemplate: env-var gate, sk_live_ safety, dedicated Finch pool, idempotency prefix
- `test/real_stripe/test_clock_real_stripe_test.exs` -- Replaced wave0 stub with full create/advance/delete round-trip test

## Decisions Made

1. **Finch pool pattern.** Used `start_supervised({Finch, name: LatticeStripe.RealStripeFinch})` in setup_all instead of the plan's lazy `Process.whereis` pattern. Matches the existing integration test convention (`LatticeStripe.IntegrationFinch`). Cleaner lifecycle management.

2. **No metadata assertion.** Plan 13-05 confirmed Stripe does NOT support metadata on test clocks (A-13g). The real_stripe test does not assert metadata presence. Clock is named `"lattice_stripe_real_stripe_canonical_test"` for Mix task backstop identification.

3. **Backend-direct calls.** Test uses `LatticeStripe.TestHelpers.TestClock` directly rather than the `Testing.TestClock` use-macro. Avoids needing a dummy client module just for this test. The Backend exercises `advance_and_wait/4` which is the feature being validated.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Replaced lazy Finch pool with start_supervised**
- **Found during:** Task 1 (RealStripeCase implementation)
- **Issue:** Plan suggested `Process.whereis` + lazy `Finch.start_link`, but codebase uses `start_supervised!` consistently in test setup_all blocks
- **Fix:** Used `start_supervised({Finch, name: LatticeStripe.RealStripeFinch})` matching the integration test pattern
- **Files modified:** `test/support/real_stripe_case.ex`
- **Commit:** `613ccbd`

---

**Total deviations:** 1 auto-fixed (Rule 3 blocking -- pattern consistency)
**Impact on plan:** Improved consistency with existing codebase patterns. No scope change.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. The :real_stripe test tier is gated by STRIPE_TEST_SECRET_KEY env var and excluded from default `mix test` runs.

## Threat Model Coverage

| Threat ID | Disposition | How this plan addresses it |
|-----------|-------------|----------------------------|
| T-13-19 (Elevation: accidental sk_live_) | mitigate | Non-negotiable flunk on sk_live_ prefix in RealStripeCase setup_all, before Client.new! |
| T-13-20 (Info disclosure: key in logs) | mitigate | Key never logged; Client struct does not print api_key |
| T-13-21 (DoS: leaked test clocks) | mitigate | Test deletes clock in both success and failure paths (rescue block) |
| T-13-22 (Tampering: CI skipping silently) | mitigate | setup_all flunks on missing key when CI=true |

## Next Phase Readiness

- Plan 13-07 (docs + CHANGELOG) can reference RealStripeCase and the :real_stripe test tier
- Phases 14-19 have a concrete template: copy `test/real_stripe/test_clock_real_stripe_test.exs`, replace Backend calls
- Phase 13 success criterion 4 (first @moduletag :real_stripe test) is MET
- TEST-10 requirement fully satisfied

## Self-Check: PASSED

- `test/support/real_stripe_case.ex` -- FOUND
- `test/real_stripe/test_clock_real_stripe_test.exs` -- FOUND
- Commit `613ccbd` (Task 1) -- FOUND
- Commit `37cbe30` (Task 2) -- FOUND
- 810 tests, 0 failures

---
*Phase: 13-billing-test-clocks*
*Completed: 2026-04-12*
