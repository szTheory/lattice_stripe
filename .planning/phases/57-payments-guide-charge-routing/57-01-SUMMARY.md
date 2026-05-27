---
phase: 57-payments-guide-charge-routing
plan: 01
subsystem: testing
tags: [exunit, docs-truth, payments-guide, charge-routing, regression-locks]

requires:
  - phase: 56-release-truth-getting-started
    provides: dedicated describe-per-guide pattern in docs_truth_test.exs
provides:
  - "@stale_payments_api_patterns catalog for stale API copy-paste shapes"
  - "describe guides/payments.md with API example and Charge routing tests"
affects:
  - 57-02 (payments.md fixes to turn red tests green)
  - VERIFY-04 payments guide regression infrastructure

tech-stack:
  added: []
  patterns:
    - "Positive asserts plus refute loop over stale pattern list"
    - "PI-first ordering assert via :binary.match section indices"

key-files:
  created: []
  modified:
    - test/lattice_stripe/docs_truth_test.exs

key-decisions:
  - "Intentional red phase until Plan 02 updates guides/payments.md"

patterns-established:
  - "Payments guide locks mirror getting-started release-truth describe pattern"

requirements-completed: [VERIFY-04]

duration: 5min
completed: 2026-05-27
---

# Phase 57 Plan 01: VERIFY-04 Regression Locks Summary

**docs_truth describe for guides/payments.md locks atom statuses, search/3, and Charge reconciliation routing before guide prose fixes**

## Performance

- **Duration:** 5 min
- **Completed:** 2026-05-27
- **Tasks:** 3
- **Files modified:** 1

## Accomplishments

- Added `@stale_payments_api_patterns` with five stale string-status and search/2 shapes
- Created `describe "guides/payments.md"` with API example positive+refute test
- Added Charge reconciliation routing test with PI-first section ordering assert

## Task Commits

1. **Task 1–3: payments docs_truth locks** - `bbeee21` (test)

## Self-Check: PASSED

- `@stale_payments_api_patterns` present in docs_truth_test.exs
- `describe "guides/payments.md"` with both tests present
- `mix compile --warnings-as-errors` passes
