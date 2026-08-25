---
phase: 67-dx-hardening-milestone-doc-close
plan: "04"
subsystem: payments
tags: [elixir, stripe, charge, payment-intent, exdoc, documentation-testing]
requires:
  - phase: 67-dx-hardening-milestone-doc-close
    provides: Existing Charge mutation-absence contract and Phase 67 documentation hardening context
provides:
  - Permanent PaymentIntent-first Charge initiation policy in the Charge moduledoc and payments reconciliation guide section
  - Exact direct-server PaymentIntent example with browser/client-SDK and customer-action/SCA boundary
  - Deterministic bounded documentation tests for policy ownership, repeatability, and parallel readers
affects: [67-05, charge-api, payments-guide, docs-truth]
tech-stack:
  added: []
  patterns: [bounded ExDoc source extraction, section-scoped documentation truth, deterministic Task.async_stream file readers]
key-files:
  created: []
  modified:
    - lib/lattice_stripe/charge.ex
    - guides/payments.md
    - test/lattice_stripe/docs_truth_test.exs
key-decisions:
  - "Keep the complete permanent Charge policy in exactly two consumer-facing regions: the Charge moduledoc and the payments guide's Charge reconciliation section."
  - "Describe the absent Charge API as its function name plus arity so ExDoc stays warning-free while the rendered guidance remains explicit."
patterns-established:
  - "Documentation contracts extract only the relevant module or guide section and test content there, never broad repository prose."
requirements-completed: [DOC-02]
coverage:
  - id: D-10-D-11
    description: "The two canonical Charge policy regions state the permanent absent mutation API, PaymentIntent-first direct server example, and resulting Charge reconciliation route."
    requirement: DOC-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/docs_truth_test.exs#Charge policy is complete in its two canonical documentation regions"
        status: pass
      - kind: other
        ref: "mix docs --warnings-as-errors"
        status: pass
    human_judgment: false
  - id: D-12
    description: "Both canonical policy regions distinguish direct server confirmation from browser/client-SDK confirmation and retain customer-action/SCA guidance."
    requirement: DOC-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/docs_truth_test.exs#Charge policy is complete in its two canonical documentation regions"
        status: pass
    human_judgment: false
  - id: D-13-D-14
    description: "Bounded documentation ownership and existing structural Charge mutation refutations prevent unrelated prose or a new mutation API from satisfying the policy."
    requirement: DOC-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/docs_truth_test.exs#only the canonical regions own the complete Charge policy"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/charge_test.exs"
        status: pass
    human_judgment: false
  - id: DOC-02-fallbacks
    description: "Repeated and parallel bounded readers observe byte-identical Charge policy content."
    requirement: DOC-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/docs_truth_test.exs#canonical Charge policy extraction is repeatable and parallel-reader stable"
        status: pass
    human_judgment: false
duration: 6min
completed: 2026-08-25
status: complete
---

# Phase 67 Plan 04: PaymentIntent-first Charge Policy Summary

**Charge creation guidance now permanently routes adopters to PaymentIntent creation, with a precise direct-server example and an explicit browser/SCA boundary.**

## Performance

- **Duration:** 6 min
- **Completed:** 2026-08-25
- **Tasks:** 2/2
- **Files modified:** 3

## Accomplishments

- Published the permanent Charge read/reconciliation policy only in the Charge moduledoc and `## Charge reconciliation` section.
- Added the exact `4_999` USD server-side PaymentIntent example and clarified that browser/client-SDK confirmation can still require customer action or SCA.
- Added section-scoped docs-truth contracts for canonical ownership, repeatability, and concurrent bounded reads while preserving Charge mutation refutations.

## Task Commits

1. **Task 1 RED: scoped Charge policy regression** — `c368932` (`test`)
2. **Task 1 GREEN: publish permanent PaymentIntent-first policy** — `faa36ff` (`feat`)
3. **Task 2: stable canonical policy ownership proofs** — `e4983ec` (`test`)
4. **Task 1 follow-up: warning-free ExDoc absent-API wording** — `353cf17` (`fix`)

## Files Created/Modified

- `lib/lattice_stripe/charge.ex` — Documents the permanent read/reconciliation boundary, direct server-side PaymentIntent creation, and SCA caveat.
- `guides/payments.md` — Makes the same canonical Charge reconciliation route actionable for adopters.
- `test/lattice_stripe/docs_truth_test.exs` — Extracts bounded policy regions and proves content, ownership, repeatability, and parallel-reader stability.

## Decisions Made

- The full policy belongs only to the Charge moduledoc and the bounded guide section; README remains a compact routing cue.
- The absent API is written as the fully qualified function plus a separately typeset arity so ExDoc does not emit an unresolved-link warning.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Prevented unresolved ExDoc links to the intentionally absent API**
- **Found during:** Task 1 verification
- **Issue:** Formatting `LatticeStripe.Charge.create/3` as an inline documentation reference made strict ExDoc generation fail because the function intentionally does not exist.
- **Fix:** Kept the explicit fully qualified function and arity in consumer prose without emitting an unresolved ExDoc reference; updated the bounded test to lock that rendered wording.
- **Files modified:** `lib/lattice_stripe/charge.ex`, `guides/payments.md`, `test/lattice_stripe/docs_truth_test.exs`
- **Verification:** `mix test test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/charge_test.exs --warnings-as-errors` and `mix docs --warnings-as-errors`
- **Committed in:** `353cf17`

**Total deviations:** 1 auto-fixed (Rule 1: documentation build failure).
**Impact on plan:** The policy remains explicit and strict documentation generation is green.

## Issues Encountered

None beyond the resolved ExDoc link-formatting issue above.

## User Setup Required

None.

## Next Phase Readiness

Plan 67-05 can rely on bounded executable evidence for DOC-02 during its strict convergence gate.

## Self-Check: PASSED

- Confirmed all three declared production/test files exist.
- Confirmed task commits `c368932`, `faa36ff`, `e4983ec`, and `353cf17` exist.
- No stubs, skipped tests, or unrun verification remain.
