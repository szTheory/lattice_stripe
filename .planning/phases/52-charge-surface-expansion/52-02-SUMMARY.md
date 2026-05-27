---
phase: 52-charge-surface-expansion
plan: 02
subsystem: testing
tags: [stripe, charge, mox, exunit, elixir]

requires:
  - phase: 52-charge-surface-expansion
    plan: 01
    provides: Charge list/search/update/capture implementation on /v1/charges
provides:
  - Mox-at-Transport wire tests under test/lattice_stripe/charge/ for list, search, update, capture
  - TaxId-style dual module surface contract (positive exports + create/cancel refutes)
affects:
  - 52-03 (docs_truth_test and integration smokes)

tech-stack:
  added: []
  patterns:
    - "Per-operation wire test modules under test/lattice_stripe/charge/ mirroring PaymentIntent URL assertions"
    - "TaxId-style describe module surface with positive matrix and negative create/cancel refutes (D-03)"

key-files:
  created:
    - test/lattice_stripe/charge/list_test.exs
    - test/lattice_stripe/charge/search_test.exs
    - test/lattice_stripe/charge/update_test.exs
    - test/lattice_stripe/charge/capture_test.exs
  modified:
    - test/lattice_stripe/charge_test.exs

key-decisions:
  - "Wire tests split by operation under test/lattice_stripe/charge/ rather than monolithic charge_test.exs"
  - "D-06 retrieve-only negative-only block replaced with D-03 dual contract (assert exports + refute create/cancel)"

patterns-established:
  - "Charge.ListTest/SearchTest/UpdateTest/CaptureTest modules with MockTransport path assertions"
  - "Module surface positive matrix covers stream! and search_stream! arities 1-3 / 2-3 per defaults"

requirements-completed: [CHRG-01, CHRG-02, CHRG-03, CHRG-04, CHRG-05]

duration: 2min
completed: 2026-05-27
---

# Phase 52 Plan 02: Charge Wire Tests and Surface Contract Summary

**Mox wire tests prove GET/POST routing for Charge list/search/update/capture on `/v1/charges`, and charge_test.exs now uses a TaxId-style dual module-surface contract instead of the D-06 retrieve-only negative block.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-27T17:42:30Z
- **Completed:** 2026-05-27T17:44:23Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added four async wire-test modules under `test/lattice_stripe/charge/` covering list/list!/stream!, search/search!/search_stream!, update/update!, and capture/capture! with MockTransport URL and body assertions
- Replaced eight-test `describe "module surface (D-06 retrieve-only)"` block with two-test TaxId-style contract: positive export matrix for expanded surface, negative refutes for create/cancel at arities 2–4 (and bang variants)
- Full charge test suite green: 44 tests across `charge_test.exs` and `charge/` subdirectory

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Mox wire tests in test/lattice_stripe/charge/** - `d7e257f` (test)
2. **Task 2: Replace D-06 retrieve-only module surface block with TaxId-style contract** - `8076d54` (test)

**Plan metadata:** `22dcd78` (docs: complete plan)

## Files Created/Modified

- `test/lattice_stripe/charge/list_test.exs` - GET `/v1/charges`, limit param, list!/stream! bang and stream cases
- `test/lattice_stripe/charge/search_test.exs` - GET `/v1/charges/search`, search!/search_stream!
- `test/lattice_stripe/charge/update_test.exs` - POST update with metadata/description, update! success/error
- `test/lattice_stripe/charge/capture_test.exs` - POST `/capture` with optional amount, capture! success/error
- `test/lattice_stripe/charge_test.exs` - TaxId-style `describe "module surface"` dual contract

## Decisions Made

None - followed plan as specified (PaymentIntent wire-test template, TaxId dual-contract pattern).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for **52-03**: `docs_truth_test.exs` grep block and integration smokes against stripe-mock
- Roadmap criterion 6 satisfied: integration-style Mox wire tests under `test/lattice_stripe/charge/`

## Self-Check: PASSED

- `test/lattice_stripe/charge/list_test.exs`, `search_test.exs`, `update_test.exs`, `capture_test.exs` exist
- `grep 'D-06 retrieve-only' test/lattice_stripe/charge_test.exs` exits 1
- `grep 'describe "module surface"' test/lattice_stripe/charge_test.exs` exits 0
- `grep '/v1/charges/search'` and `grep '/capture'` pass on search/capture test files
- `git log --oneline --grep="52-02"` shows `d7e257f`, `8076d54`
- `mix test test/lattice_stripe/charge_test.exs test/lattice_stripe/charge/ --warnings-as-errors` — 44 tests, 0 failures

---
*Phase: 52-charge-surface-expansion*
*Completed: 2026-05-27*
