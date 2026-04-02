---
phase: 02-error-handling-retry
plan: 01
subsystem: api
tags: [elixir, stripe, error-handling, json, protocol]

# Dependency graph
requires:
  - phase: 01-transport-client-configuration
    provides: LatticeStripe.Error struct with from_response/3, LatticeStripe.Json behaviour with encode!/decode!
provides:
  - Enriched Error struct with 5 new fields (param, decline_code, charge, doc_url, raw_body)
  - idempotency_error as new error type atom for 409 conflicts
  - String.Chars protocol on Error for string interpolation in logs
  - Structured message format "(type) status code message (request: req_id)"
  - Non-bang decode/1 and encode/1 callbacks on Json behaviour and Jason adapter
affects: [02-02, 02-03, client-request-retry-loop]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "defimpl String.Chars for exception struct — delegate to Exception.message/1"
    - "Non-bang behaviour callbacks returning {:ok, result} | {:error, exception} alongside bang variants"
    - "raw_body field on error struct as escape hatch for unstructured fields"

key-files:
  created: []
  modified:
    - lib/lattice_stripe/error.ex
    - lib/lattice_stripe/json.ex
    - lib/lattice_stripe/json/jason.ex
    - test/lattice_stripe/error_test.exs
    - test/lattice_stripe/json_test.exs

key-decisions:
  - "Error struct enriched additively — 5 new named fields + raw_body escape hatch (D-01)"
  - "Single Error struct with :idempotency_error atom type for 409 conflicts, not a separate exception (D-02)"
  - "String.Chars protocol delegates to Exception.message/1 for #{error} interpolation (D-03)"
  - "No Jason.Encoder on Error struct — prevents accidental serialization of raw_body/request_id (D-04)"
  - "Structured message format includes correlation ID for Stripe dashboard grep (D-05)"
  - "Json behaviour gains non-bang decode/1 and encode/1 for graceful non-JSON response handling (D-26)"

patterns-established:
  - "Error message format: (type) status code message (request: req_id) — grep-friendly, log-friendly"
  - "raw_body always set on from_response/3 — full decoded body preserved for debugging"
  - "Behaviour callbacks come in bang/non-bang pairs for flexible internal use"

requirements-completed:
  - ERRR-03
  - ERRR-04
  - ERRR-05
  - ERRR-06

# Metrics
duration: 15min
completed: 2026-04-02
---

# Phase 02 Plan 01: Error Struct Enrichment and Json Non-Bang Callbacks Summary

**10-field Error struct with idempotency_error type, String.Chars protocol, and 4-callback Json behaviour for graceful non-JSON response handling in the retry loop**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-02T15:44:00Z
- **Completed:** 2026-04-02T15:46:18Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Error struct enriched with :param, :decline_code, :charge, :doc_url, :raw_body fields — pattern-matchable and dot-accessible
- :idempotency_error added as 7th error type atom for 409 conflict detection
- String.Chars protocol enables "#{error}" interpolation in logs and strings
- Error message format upgraded to structured "(type) status code message (request: req_id)"
- from_response/3 now extracts all new fields and always preserves full raw_body
- Json behaviour extended with decode/1 and encode/1 (non-bang) for graceful failure handling
- Jason adapter implements all 4 callbacks
- 47 tests across both modules, all passing

## Task Commits

Each task was committed atomically:

1. **Task 1: Enrich Error struct, add idempotency_error type, String.Chars, update message format** - `33da331` (feat)
2. **Task 2: Add non-bang decode/1 and encode/1 to Json behaviour and Jason adapter** - `1666da4` (feat)

_Note: Both tasks used TDD (RED → GREEN) approach_

## Files Created/Modified

- `lib/lattice_stripe/error.ex` - Added 5 new fields, :idempotency_error type, updated message/1 format, updated from_response/3, added String.Chars impl
- `lib/lattice_stripe/json.ex` - Added @callback decode/1 and encode/1 with docs
- `lib/lattice_stripe/json/jason.ex` - Implemented decode/1 and encode/1 using Jason.decode/encode
- `test/lattice_stripe/error_test.exs` - Expanded from 13 to 29 tests covering all new behavior
- `test/lattice_stripe/json_test.exs` - Expanded from 8 to 18 tests covering non-bang variants and Mox contract

## Decisions Made

- Error struct enriched additively — old fields still work, new fields nil by default (backward compatible)
- raw_body is always set by from_response/3, even on fallback path — full body preserved for debugging
- :idempotency_error added before catch-all parse_type/1 clause (D-02)
- No Jason.Encoder on Error — security-first, prevents accidental serialization (D-04)
- Non-bang Json callbacks use {:ok, result} | {:error, exception} pattern consistent with Elixir idioms (D-26)

## Deviations from Plan

None — plan executed exactly as written. One minor compile-time fix was needed: test name containing `#{}` interpolation at module level caused compile error; renamed test to avoid the compile-time evaluation.

## Issues Encountered

- Test name `"'#{error}' interpolation..."` caused compile error because `error` variable was evaluated at module compile time. Renamed to `"string interpolation returns same as Exception.message(error)"`. Not a deviation — just a test naming adjustment.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Error struct is now ready for retry loop integration (Plan 03): :idempotency_error can be detected to skip retry, raw_body available for debugging non-JSON responses
- Json non-bang callbacks ready for graceful non-JSON body handling in Client.request/2
- MockJson Mox mock automatically gains decode/1 and encode/1 from updated behaviour — no test_helper.exs changes needed
- Plan 02 (RetryStrategy) can proceed in parallel — no dependencies on this plan's output beyond type atoms

---
*Phase: 02-error-handling-retry*
*Completed: 2026-04-02*
