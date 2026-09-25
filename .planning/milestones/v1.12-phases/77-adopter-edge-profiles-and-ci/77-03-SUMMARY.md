---
phase: 77-adopter-edge-profiles-and-ci
plan: 03
subsystem: testing
tags: [elixir, phoenix, stripe-connect, mox, adopter]

requires:
  - phase: 77-01
    provides: Shared Phoenix adopter host and MockTransport
provides:
  - Independently selectable Connect tenant-context profile
  - Typed Balance request routing and account-header suppression proof
affects: [phase-77-adopter, connect, ci]

actuals:
  tokens: 710
  tasks: 2
  commits: 1
plan_head_before: a1f86b3bdb05dd4caf479f1eaad4dbc323c9e163
commits: 1

tech-stack:
  added: []
  patterns: [request-scoped Connect account context, synthetic typed transport response]

key-files:
  created: [test_apps/phoenix_adopter/test/connect_context_profile_test.exs]
  modified: []

key-decisions:
  - "Use one explicit Client for sequential Balance reads so request-scoped tenant routing is observable without mutable global state."
  - "Treat the passing local complete-suite command as evidence; remote CI status remains unobserved."

patterns-established:
  - "Assert the complete Stripe-Account header set at the injected transport boundary for each request."
  - "Decode synthetic responses into public typed Balance structs in adopter profile tests."

requirements-completed: [ADOPT-03, ADOPT-04, ADOPT-05]
coverage:
  - id: D1
    description: "Two connected-account Balance reads on one Client use only the account selected for each request and decode to typed Balance values."
    requirement: ADOPT-03
    verification:
      - kind: unit
        ref: "test_apps/phoenix_adopter/test/connect_context_profile_test.exs#connected balances use only their per-request tenant header (mix test test/connect_context_profile_test.exs: 2 tests, 0 failures)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Explicit per-request nil omits the client account header, and a following request on the same Client uses only its selected account."
    requirement: ADOPT-04
    verification:
      - kind: unit
        ref: "test_apps/phoenix_adopter/test/connect_context_profile_test.exs#nil request context suppresses client account without contaminating next request (mix test test/connect_context_profile_test.exs: 2 tests, 0 failures)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The complete synthetic adopter suite, including core/webhook, B2B, usage, and Connect tests, passes under the CI warnings-as-errors command."
    requirement: ADOPT-05
    verification:
      - kind: integration
        ref: "cd test_apps/phoenix_adopter && mix test --warnings-as-errors (9 tests, 0 failures)"
        status: pass
    human_judgment: false

duration: 2min
completed: 2026-09-24
status: complete
---

# Phase 77 Plan 03: Connect Context Profile Summary

**One shared adopter Client now proves typed Balance reads follow each request's selected connected account and that explicit nil suppresses the client default.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-09-24T15:30:00Z
- **Completed:** 2026-09-24T15:32:05Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Added the independently runnable Connect context profile with synthetic Mox responses and typed `%LatticeStripe.Balance{}` assertions.
- Verified sequential reads for two accounts on one Client send exactly the selected `stripe-account` header, without leaking the other account value.
- Verified `stripe_account: nil` suppresses a client-level account and the subsequent request remains correctly scoped.
- Ran the full nested suite, including core signed/tampered webhook coverage, B2B, usage, and Connect profiles, with warnings as errors.

## Task Commits

1. **Task 1: Route two typed Balance reads to two accounts through one Client** - `a7c7dce` (test)
2. **Task 2: Prove explicit account suppression and finish the complete adopter gate** - covered by `a7c7dce` (test)

## Files Created/Modified

- `test_apps/phoenix_adopter/test/connect_context_profile_test.exs` - Sequential account routing, explicit nil suppression, and typed Balance decoding assertions.

## Decisions Made

- Followed the plan's fixed synthetic account IDs and one-Client request-scoped routing contract; no application authorization or compliance behavior is asserted.
- Preserved the spec-less edge-probe assumptions as flagged and unresolved: ADOPT-03 contract classification, ADOPT-04 tenant-authorization scope, and ADOPT-05 remote CI status. The tests establish the selected transport contract and local suite evidence only.

## Deviations from Plan

None - plan executed as specified.

## Issues Encountered

- The first focused test attempt found the nested app dependencies absent. `mix deps.get --check-locked` initially could not persist Hex's cache under the sandboxed home directory; rerunning with `HEX_HOME=/private/tmp/lattice-stripe-hex` resolved the already-locked dependencies successfully. Both test commands then passed. Generated nested `_build/` and `deps/` directories were removed after verification.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The Connect profile is ready for the phase verifier alongside plans 77-01 and 77-02. Remote CI status was not observed and is not claimed.

## Self-Check: PASSED

- Connect profile file exists and its test commit is present (`a7c7dce`).
- Focused profile: 2 tests, 0 failures.
- Complete nested suite with `--warnings-as-errors`: 9 tests, 0 failures.
- No stubs or new security-relevant runtime surface were introduced; tests use fixed synthetic accounts and the existing mocked transport.

---
*Phase: 77-adopter-edge-profiles-and-ci*
*Completed: 2026-09-24*
