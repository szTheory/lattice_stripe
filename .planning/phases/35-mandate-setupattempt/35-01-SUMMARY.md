---
phase: 35-mandate-setupattempt
plan: "01"
subsystem: payments
tags:
  - stripe
  - mandates
  - setup-attempts
  - parsers
  - fixtures
requires:
  - phase: 05-setupintents-paymentmethods
    provides: setup-domain parser, pagination, and required-param validation patterns
provides:
  - typed mandate parser contracts and nested mandate structs
  - typed setup-attempt parser contract with dedicated historical setup-error struct
  - object registration for mandate and setup_attempt
  - reusable mandate and setup-attempt fixtures for phase 35 tests
affects:
  - Phase 35 plan 02 resource implementation
  - Payments docs navigation
tech-stack:
  added: []
  patterns:
    - explicit known-field parsing with forward-compatible extra preservation
    - selective nested typing with raw maps for polymorphic payment snapshots
key-files:
  created:
    - lib/lattice_stripe/mandate.ex
    - lib/lattice_stripe/mandate/customer_acceptance.ex
    - lib/lattice_stripe/mandate/single_use.ex
    - lib/lattice_stripe/setup_attempt.ex
    - lib/lattice_stripe/setup_attempt/setup_error.ex
    - test/support/fixtures/mandate.ex
    - test/support/fixtures/setup_attempt.ex
  modified:
    - lib/lattice_stripe/object_types.ex
    - mix.exs
    - test/lattice_stripe/object_types_test.exs
key-decisions:
  - "Mandate keeps only customer_acceptance and single_use as typed nested structs; multi_use and payment_method_details remain raw maps."
  - "SetupAttempt.setup_error is modeled as a dedicated nested struct instead of reusing LatticeStripe.Error so successful responses stay semantically distinct from request failures."
patterns-established:
  - "Mandate and SetupAttempt follow the project’s parser-first resource layering: typed from_map/1 before public API verbs."
  - "ObjectTypes and Payments ExDoc grouping are extended in-place rather than creating new registries or docs buckets."
requirements-completed:
  - AUTH-01
  - AUTH-02
duration: 6min
completed: 2026-05-24
---

# Phase 35 Plan 01 Summary

**Mandate and SetupAttempt parser contracts with selective nested typing, object dispatch registration, and reusable fixtures for the read-only phase 35 resource surface.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-05-24T18:30:00Z
- **Completed:** 2026-05-24T18:36:00Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments

- Added `%LatticeStripe.Mandate{}` plus `%Mandate.CustomerAcceptance{}` and `%Mandate.SingleUse{}` with enum atomization and expandable payment-method parsing.
- Added `%LatticeStripe.SetupAttempt{}` plus `%SetupAttempt.SetupError{}` with historical-error semantics and selective expandable parsing.
- Registered `mandate` and `setup_attempt` in `ObjectTypes`, placed the new modules in the Payments ExDoc group, and added mergeable fixture helpers for both resources.

## Task Commits

No task commits were created in this run because the worktree already contained unrelated local changes. The completed files remain tracked in the current working tree.

## Files Created/Modified

- `lib/lattice_stripe/mandate.ex` - Mandate parser baseline with enum atomization and expandable payment-method handling
- `lib/lattice_stripe/mandate/customer_acceptance.ex` - typed customer-acceptance nested struct
- `lib/lattice_stripe/mandate/single_use.ex` - typed single-use nested struct
- `lib/lattice_stripe/setup_attempt.ex` - SetupAttempt parser baseline with setup-error and expandable parsing
- `lib/lattice_stripe/setup_attempt/setup_error.ex` - historical nested setup-error struct
- `test/support/fixtures/mandate.ex` - mandate payload helpers
- `test/support/fixtures/setup_attempt.ex` - setup-attempt payload helpers, including historical setup-error cases
- `lib/lattice_stripe/object_types.ex` - object dispatch registration for mandate and setup_attempt
- `mix.exs` - Payments ExDoc group placement for new phase 35 modules
- `test/lattice_stripe/object_types_test.exs` - dispatch assertions for mandate and setup_attempt

## Decisions Made

- Kept `payment_method_details` and other broad payment snapshots as raw maps so Phase 35 stays selective and forward-compatible rather than over-modeling Stripe’s polymorphic branches.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 02 can now add the public retrieve/list APIs directly on top of the typed parsers, fixtures, and registry entries created here.

---
*Phase: 35-mandate-setupattempt*
*Completed: 2026-05-24*
