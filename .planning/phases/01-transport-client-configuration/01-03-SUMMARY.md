---
phase: 01-transport-client-configuration
plan: 03
subsystem: api
tags: [elixir, transport, behaviour, error-handling, stripe, mox]

# Dependency graph
requires:
  - phase: 01-transport-client-configuration
    provides: Scaffolded project with stubs for transport.ex and json.ex, Mox configured in test_helper.exs
provides:
  - Transport behaviour with request/1 callback, request_map/response_map typespecs
  - Request struct with method, path, params, opts fields as pure data
  - Error struct implementing Exception with 6 error types and from_response/3 parser
  - Comprehensive test coverage for all three modules (20 tests total)
affects: [finch-adapter, client-module, resource-modules, error-handling, retry-logic]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Transport behaviour: single request/1 callback with plain map in/out for easy mocking"
    - "Request struct as pure data: separate building from dispatch for testability"
    - "Error struct with typed :type atom field enabling clean pattern matching"
    - "Error.from_response/3: Stripe JSON -> typed struct with fallback to :api_error"
    - "TDD RED/GREEN cycle: failing tests committed before implementation"

key-files:
  created:
    - lib/lattice_stripe/request.ex
    - lib/lattice_stripe/error.ex
    - test/lattice_stripe/transport_test.exs
    - test/lattice_stripe/request_test.exs
    - test/lattice_stripe/error_test.exs
  modified:
    - lib/lattice_stripe/transport.ex

key-decisions:
  - "Transport behaviour uses single request/1 callback with plain map (not positional args) for simplest possible contract to mock and implement"
  - "Error.from_response/3 falls back to :api_error for both unknown type strings and non-standard response bodies"
  - "connection_error type included in Error struct for transport-level failures with nil status"

patterns-established:
  - "TDD RED/GREEN: tests written before implementation, confirmed failing before writing code"
  - "All test files use async: true for concurrent test execution"
  - "Error type atoms match Stripe's error type strings exactly (except unknown -> :api_error fallback)"

requirements-completed:
  - TRNS-01
  - TRNS-03

# Metrics
duration: 2min
completed: 2026-04-01
---

# Phase 01 Plan 03: Transport Behaviour, Request Struct, and Error Struct Summary

**Transport behaviour with typed request/1 callback, Request struct as pure data pipeline, and Error struct with Stripe error type parsing and pattern-matchable :type atoms**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-01T00:45:16Z
- **Completed:** 2026-04-01T00:47:52Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Expanded transport.ex stub into full behaviour with `@type request_map`, `@type response_map`, and `@callback request(request_map())` — the contract for all HTTP adapters and mocks
- Created request.ex with `defstruct` holding method, path, params (%{}), opts ([]) as pure data with no side effects
- Created error.ex with `defexception` implementing all 6 Stripe error types, `message/1` callback, and `from_response/3` parser that correctly handles standard Stripe error JSON plus graceful fallbacks

## Task Commits

1. **Task 1: Transport behaviour and Request struct with tests** - `192ddc9` (feat)
2. **Task 2: Error struct with Stripe error response parsing and tests** - `8438a4c` (feat)

**Plan metadata:** (see final commit below)

_Note: TDD tasks used RED phase (failing tests) then GREEN phase (implementation)._

## Files Created/Modified

- `lib/lattice_stripe/transport.ex` - HTTP transport behaviour with request_map/response_map typespecs and @callback request/1
- `lib/lattice_stripe/request.ex` - Request struct with method, path, params (%{}), opts ([]) as pure data
- `lib/lattice_stripe/error.ex` - Error defexception with 6 type atoms, message/1 callback, from_response/3 Stripe JSON parser
- `test/lattice_stripe/transport_test.exs` - 3 tests: behaviour callbacks, Mox mock success/error
- `test/lattice_stripe/request_test.exs` - 5 tests: defaults and field population
- `test/lattice_stripe/error_test.exs` - 12 tests: Exception behaviour, message format, parsing all error types, fallbacks, pattern matching

## Decisions Made

- Transport behaviour uses a single `request/1` callback receiving a plain map (not positional args like method/url/headers/body/opts) for the narrowest possible contract — one function to implement, one to mock via Mox
- `from_response/3` falls back to `:api_error` for both unknown type strings and non-standard response bodies, ensuring any HTTP error always returns a typed Error struct
- `connection_error` type added to the Error type union for transport-level failures where no HTTP response was received (nil status)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - deps.get required at start since worktree has fresh deps but that was expected environment setup.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Transport behaviour contract established: all Finch adapter and Client module work can build against this interface
- Request struct is ready for Client.request/2 to dispatch through transport
- Error struct with from_response/3 is ready for Client to wrap 4xx/5xx responses
- Mox mock (LatticeStripe.MockTransport) already configured in test_helper.exs from Plan 01 and tested here

---
*Phase: 01-transport-client-configuration*
*Completed: 2026-04-01*

## Self-Check: PASSED

- lib/lattice_stripe/transport.ex: FOUND
- lib/lattice_stripe/request.ex: FOUND
- lib/lattice_stripe/error.ex: FOUND
- test/lattice_stripe/transport_test.exs: FOUND
- test/lattice_stripe/request_test.exs: FOUND
- test/lattice_stripe/error_test.exs: FOUND
- .planning/phases/01-transport-client-configuration/01-03-SUMMARY.md: FOUND
- Commit 192ddc9: FOUND
- Commit 8438a4c: FOUND
