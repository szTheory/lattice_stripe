---
phase: 77-adopter-edge-profiles-and-ci
plan: 01
subsystem: testing
tags: [elixir, phoenix, mox, github-actions, adopter]
requires:
  - phase: 76-phoenix-adopter-core-flow
    provides: Shared Phoenix host, synthetic Mox transport, signed/tampered webhook proof
provides:
  - Independently selectable B2B invoice success and structured-error contract tests
  - Required Phoenix adopter CI job on Elixir 1.19 / OTP 28
  - Profile selectors and synthetic-proof boundary in the adopter README
affects: [77-02, 77-03, adopter-ci]
actuals:
  tokens: 1896
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns:
    - Synthetic PhoenixAdopter.MockTransport verifies public SDK request and decode behavior
    - Focused ExUnit profile files run independently inside the shared host app
key-files:
  created:
    - test_apps/phoenix_adopter/test/b2b_invoice_profile_test.exs
  modified:
    - test_apps/phoenix_adopter/README.md
    - .github/workflows/ci.yml
decisions:
  - Keep the off-Stripe invoice field request scoped to API version 2026-05-27.dahlia.
  - Keep adopter proof synthetic; do not claim live delivery or durable reconciliation.
metrics:
  duration: 4min
  completed: 2026-09-24
  commits: 2
  plan_head_before: da74bdccab97573cb3dc005a1da7adde6871f26f
status: complete
requirements-completed: [ADOPT-03, ADOPT-04, ADOPT-05]
coverage:
  - id: D1
    description: Versioned typed Invoice retrieval exposes amount_paid_off_stripe through the adopter transport.
    requirement: ADOPT-03
    verification:
      - kind: integration
        ref: test_apps/phoenix_adopter/test/b2b_invoice_profile_test.exs#versioned invoice retrieval exposes typed off-Stripe amount
        status: pass
      - kind: other
        ref: Nested lock check and warnings-as-errors adopter suite (5 tests, 0 failures)
        status: pass
    human_judgment: false
  - id: D2
    description: Synthetic invalid invoice response returns the stable structured SDK error.
    requirement: ADOPT-04
    verification:
      - kind: integration
        ref: test_apps/phoenix_adopter/test/b2b_invoice_profile_test.exs#invalid invoice retrieval returns structured SDK error
        status: pass
      - kind: other
        ref: Focused B2B profile test (2 tests, 0 failures)
        status: pass
      - kind: integration
        ref: test_apps/phoenix_adopter/test/core_flow_test.exs#signed completion event and modified body rejection
        status: pass
    human_judgment: false
  - id: D3
    description: Phoenix adopter CI resolves the nested lockfile, runs the full suite on Elixir 1.19 / OTP 28, and is required by ci-gate.
    requirement: ADOPT-05
    verification:
      - kind: other
        ref: actionlint .github/workflows/ci.yml
        status: pass
      - kind: other
        ref: Local structural checks for adopter job, nested commands, ci-gate dependency, result variable, and required-lane loop
        status: pass
    human_judgment: false
  - id: D4
    description: README names all three profile selectors, the full suite command, and the synthetic evidence boundary.
    verification:
      - kind: other
        ref: README profile selector and synthetic boundary checks
        status: pass
    human_judgment: false
---

# Phase 77 Plan 01: B2B Invoice Adopter Proof Summary

**Versioned invoice retrieval, structured SDK errors, and a required synthetic Phoenix adopter CI lane.**

## Performance

- Duration: 4 min
- Started: 2026-09-24T15:13:51Z
- Completed: 2026-09-24T15:17:22Z
- Tasks: 2
- Files modified: 3

## Accomplishments

- Added an independently runnable B2B profile that checks the exact stripe-version header and typed amount_paid / amount_paid_off_stripe values.
- Added a synthetic HTTP 400 case that asserts LatticeStripe.Error type and status.
- Added a secret-free Elixir 1.19 / OTP 28 adopter job and made it a required ci-gate dependency.
- Documented all three planned profile commands, the nested lockfile command, and the distinction between synthetic SDK proof and durable reconciliation.

## Task Commits

1. Task 1: Prove versioned typed Invoice retrieval and add CI lane — 1c95a44
2. Task 2: Assert structured Invoice error and document profile selection — 0192e17

## Files Created/Modified

- test_apps/phoenix_adopter/test/b2b_invoice_profile_test.exs — Synthetic versioned typed Invoice success and structured error tests.
- .github/workflows/ci.yml — Required Phoenix adopter job and ci-gate checks.
- test_apps/phoenix_adopter/README.md — Focused profile selectors and synthetic scope.

## Decisions Made

- The amount_paid_off_stripe fixture uses request API version 2026-05-27.dahlia; the SDK default remains unchanged.
- The profile proves request, decode, and error contracts only. It does not claim live Stripe behavior or durable billing reconciliation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking environment issue] Redirected Hex's registry cache to the writable temporary directory**

- Found during: Task 1 verification
- Issue: The default Hex cache under ~/.hex was not writable, so the lock check stopped before tests ran.
- Fix: Re-ran the same lock check and test commands with HEX_HOME=/private/tmp/lattice-stripe-hex.
- Files modified: None
- Verification: Nested lock check and full suite passed (5 tests, 0 failures).
- Committed in: No code change required.

Total deviations: 1 auto-fixed (Rule 3). Verification used the same commands with a writable cache location; implementation scope did not change.

## Issues Encountered

- Dependency resolution generated nested deps/ and _build/ output; both were removed after verification. Pre-existing .planning/config.json, .planning/state.json, and .gsd/ changes were left untouched.
- The CI workflow passes local actionlint and structural checks. Remote CI has not yet run, so no remote success is claimed.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Plans 77-02 and 77-03 can add their usage and Connect test files at the paths documented in the adopter README. The complete adopter command remains mix test from test_apps/phoenix_adopter.

## Self-Check: PASSED

- Summary and all three implementation files exist.
- Task commits 1c95a44 and 0192e17 are present in git history.
