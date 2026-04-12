---
phase: 02-error-handling-retry
plan: "02"
subsystem: http-client
tags: [retry, exponential-backoff, elixir, stripe, behaviour, nimbleoptions]

# Dependency graph
requires:
  - phase: 01-transport-client-configuration
    provides: Transport behaviour, Config NimbleOptions schema, Client struct with max_retries

provides:
  - LatticeStripe.RetryStrategy behaviour with retry?/2 callback and context type
  - LatticeStripe.RetryStrategy.Default implementation (Stripe SDK conventions)
  - Config schema updated with retry_strategy field (atom, default RetryStrategy.Default)
  - Config schema max_retries default changed from 0 to 2
  - Client struct updated with retry_strategy field

affects:
  - 02-03-PLAN (Client retry loop will call RetryStrategy.Default.retry?/2)
  - Any plan integrating with Client.request/2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Behaviour + default adapter: RetryStrategy follows Transport/Json pattern"
    - "Context as plain map (not struct) for behaviour inputs: open for future key additions"
    - "stripe_should_retry pre-parsed by caller into context map (not read from headers inside strategy)"

key-files:
  created:
    - lib/lattice_stripe/retry_strategy.ex
    - test/lattice_stripe/retry_strategy_test.exs
  modified:
    - lib/lattice_stripe/config.ex
    - lib/lattice_stripe/client.ex
    - test/lattice_stripe/config_test.exs

key-decisions:
  - "stripe_should_retry is pre-parsed into context map by the retry loop caller, not read from headers inside the strategy — keeps strategy pure"
  - "RetryStrategy behaviour and Default implementation live in same file per D-07"
  - "max_retries default changed from 0 to 2 (Stripe SDK convention: 3 total attempts)"
  - "409 Idempotency conflicts are non-retriable — retrying same key with different params hits the same conflict"

patterns-established:
  - "RetryStrategy.Default.retry?/2 is a pure function: given context map, returns {:retry, delay_ms} | :stop"
  - "Exponential backoff: min(500 * 2^(attempt-1), 5000) jittered to 50-100% of calculated value"

requirements-completed:
  - RTRY-01
  - RTRY-02
  - RTRY-05
  - RTRY-06

# Metrics
duration: 3min
completed: "2026-04-02"
---

# Phase 02 Plan 02: RetryStrategy Behaviour and Default Implementation Summary

**RetryStrategy behaviour with Default implementation: Stripe-Should-Retry authoritative, Retry-After capped at 5s, exponential backoff with jitter, 409 non-retriable**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-02T11:43:52Z
- **Completed:** 2026-04-02T11:46:38Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Defined `LatticeStripe.RetryStrategy` behaviour with `retry?/2` callback and typed context map
- Implemented `LatticeStripe.RetryStrategy.Default` following Stripe SDK conventions: Stripe-Should-Retry header authoritative, Retry-After respected with 5s cap, retry 429/500+/connection errors, stop on 4xx including 409
- Updated Config and Client to include `retry_strategy` field (module atom, defaults to Default) and changed `max_retries` default from 0 to 2
- 22 unit tests covering all retry signals, backoff mechanics, jitter bounds, and cap behavior

## Task Commits

Each task was committed atomically:

1. **Task 1: Create RetryStrategy behaviour and Default implementation (TDD)** - `f2394e7` (feat)
2. **Task 2: Update Config schema with retry_strategy field and max_retries default change** - `f3df360` (feat)

## Files Created/Modified

- `lib/lattice_stripe/retry_strategy.ex` - RetryStrategy behaviour + Default implementation (two modules in one file)
- `test/lattice_stripe/retry_strategy_test.exs` - 22 pure unit tests for Default strategy
- `lib/lattice_stripe/config.ex` - Added retry_strategy field to NimbleOptions schema, changed max_retries default to 2
- `lib/lattice_stripe/client.ex` - Added retry_strategy to defstruct and @type t, changed max_retries default to 2
- `test/lattice_stripe/config_test.exs` - Added 4 new tests for retry_strategy field and updated max_retries assertion

## Decisions Made

- `stripe_should_retry` is a pre-parsed boolean in the context map (not read from raw response headers inside the strategy) — keeps the strategy a pure function; the retry loop caller does header parsing before passing context
- Behaviour and Default live in the same file (`retry_strategy.ex`) per D-07; no submodule directory needed for v1
- `max_retries: 2` (3 total attempts) matches Stripe Ruby/Python/Node SDK convention per D-13 and D-28

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

Minor: Initial implementation read `stripe_should_retry` from raw response headers inside the strategy, but the plan's behavior tests pass a pre-parsed boolean in the context map. Fixed immediately by reading `Map.get(context, :stripe_should_retry)` instead of parsing headers again.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `RetryStrategy.Default.retry?/2` is ready for Plan 03's Client retry loop to call
- Config and Client structs have `retry_strategy` field — Plan 03 reads it from the client
- `max_retries: 2` is now the default — Plan 03 retry loop should respect this field
- All 65 tests across retry_strategy, config, and client pass cleanly

---
*Phase: 02-error-handling-retry*
*Completed: 2026-04-02*
