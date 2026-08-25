---
phase: 67-dx-hardening-milestone-doc-close
plan: "01"
subsystem: api
tags: [elixir, stripe, error-handling, retry-after, documentation]
requires:
  - phase: 66-product-feature-attachment
    provides: Current public API and documentation baseline
provides:
  - Ordered, duplicate-preserving final response headers on LatticeStripe.Error
  - Strict uncapped Retry-After convenience metadata and safe consumer guidance
affects: [phase-67-plan-05, api-surface-lock, docs-convergence]
tech-stack:
  added: []
  patterns: [response-evidence propagation, strict local retry-after parsing, docs-truth safety lock]
key-files:
  created: []
  modified:
    - lib/lattice_stripe/error.ex
    - lib/lattice_stripe/client.ex
    - test/lattice_stripe/error_test.exs
    - test/lattice_stripe/client_test.exs
    - test/lattice_stripe/docs_truth_test.exs
    - guides/error-handling.md
key-decisions:
  - "Error metadata preserves raw response header tuples and derives only a strict, uncapped decimal-seconds convenience value."
  - "Consumer retry scheduling remains application-owned; Phoenix callers enqueue delayed work instead of blocking request processes."
patterns-established:
  - "Public response evidence follows the final retry attempt while retry strategy context receives the same header list."
requirements-completed: [DX-02]
coverage:
  - id: D1
    description: "Error exposes ordered duplicate-preserving headers, case-insensitive all-value lookup, and strict uncapped Retry-After metadata."
    requirement: DX-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/error_test.exs#Error response metadata"
        status: pass
    human_judgment: false
  - id: D2
    description: "JSON, non-JSON, download, connection, and exhausted-retry paths preserve correct final HTTP evidence without changing retry policy."
    requirement: DX-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/client_test.exs#request/2 retry loop and download/2"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/retry_strategy_test.exs"
        status: pass
    human_judgment: false
  - id: D3
    description: "Error-handling guidance keeps Retry-After handling uncapped, privacy-bounded, and non-blocking for Phoenix consumers."
    requirement: DX-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/docs_truth_test.exs#error handling guide keeps Retry-After evidence policy bounded and non-blocking"
        status: pass
    human_judgment: false
duration: 5min
completed: 2026-08-25
status: complete
---

# Phase 67 Plan 01: Final Response Error Evidence Summary

**Final Stripe HTTP failures now expose faithful ordered headers and a strict uncapped Retry-After fact, while consumer scheduling stays explicitly outside the SDK.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-08-25T17:46:46Z
- **Completed:** 2026-08-25T17:51:55Z
- **Tasks:** 3/3 (including the recorded locked-contract confirmation)
- **Files modified:** 6

## Accomplishments

- Added `Error.headers`, `Error.retry_after`, `Error.get_header/2`, and compatible `Error.from_response/4` / `/3` construction.
- Propagated response metadata through decoded, non-JSON, download, retry, and connection paths, retaining final-attempt evidence.
- Added strict parser, repeatability, concurrency, and safe-adopter guidance behavior locks.

## Task Commits

1. **Task 2 RED: tracer tests** — `da7b6e8` (`test`)
2. **Task 2 GREEN: response metadata tracer** — `dd13608` (`feat`)
3. **Task 3 RED: strict parser tests** — `a277363` (`test`)
4. **Task 3 GREEN: parser and guidance** — `824f429` (`feat`)
5. **Task 3 Rule 2: guidance truth lock** — `307ccd7` (`test`)

## Files Created/Modified

- `lib/lattice_stripe/error.ex` — Public response metadata, lookup, compatibility constructor, and strict parser.
- `lib/lattice_stripe/client.ex` — Header propagation into decoded and non-JSON HTTP errors.
- `test/lattice_stripe/error_test.exs` — Parser, idempotency, and concurrency proofs.
- `test/lattice_stripe/client_test.exs` — Final retry, non-JSON, download, and connection evidence proofs.
- `test/lattice_stripe/docs_truth_test.exs` — Non-blocking, privacy-bounded guidance lock.
- `guides/error-handling.md` — Consumer-owned delayed-work guidance and response-evidence examples.

## Decisions Made

- Implemented the pre-approved D-01/D-02/D-04 public Error shape without alternatives.
- Kept raw headers intact and parsed only a strict decimal-seconds convenience value; no retry timing, queue, sleep, or rate-limit policy changed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added a docs-truth lock for safety guidance**
- **Found during:** Task 3
- **Issue:** The guide's privacy and non-blocking constraints had no executable regression proof.
- **Fix:** Added a narrow `docs_truth_test.exs` assertion for the response-evidence section.
- **Files modified:** `test/lattice_stripe/docs_truth_test.exs`
- **Verification:** Focused test suite passed (218 tests).
- **Committed in:** `307ccd7`

**Total deviations:** 1 auto-fixed (Rule 2)

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The additive Error surface and guidance are ready for the API/docs convergence work in later Phase 67 plans.

## Self-Check: PASSED
