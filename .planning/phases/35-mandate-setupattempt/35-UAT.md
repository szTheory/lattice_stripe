---
status: complete
mode: shift-left
phase: 35-mandate-setupattempt
source:
  - 35-01-SUMMARY.md
  - 35-02-SUMMARY.md
  - 35-VALIDATION.md
started: 2026-05-25T04:04:36Z
updated: 2026-05-25T06:14:22Z
human_steps_required: 0
automation_deferred: []
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

[testing complete]

## Tests

### 1. Mandate parser preserves typed nested data
expected: Mandate parsing should atomize bounded enums, preserve unknown fields in `extra`, and deserialize expandable payment methods without breaking object dispatch.
result: pass
evidence: `mix test test/lattice_stripe/object_types_test.exs --warnings-as-errors`

### 2. Object dispatch recognizes mandate and setup_attempt
expected: Object registry dispatch should recognize `mandate` and `setup_attempt`, keeping parser contracts and Payments docs grouping aligned.
result: pass
evidence: `mix test test/lattice_stripe/object_types_test.exs --warnings-as-errors`

### 3. SetupAttempt parser preserves forward compatibility
expected: `SetupAttempt.from_map/1` should keep payment snapshots raw where intended, model historical setup errors separately, and compile cleanly with the added structs.
result: pass
evidence: `mix compile --warnings-as-errors`

### 4. Mandate retrieve API stays read-only
expected: `LatticeStripe.Mandate.retrieve/3` and `retrieve!/3` should return typed mandate data and keep the resource surface retrieve-only.
result: pass
evidence: `mix test test/lattice_stripe/mandate_test.exs test/lattice_stripe/setup_attempt_test.exs --warnings-as-errors`

### 5. SetupAttempt local required-filter validation works
expected: `LatticeStripe.SetupAttempt.list/3` and `stream!/3` should require `"setup_intent"` before any network call and return typed paginated setup attempts when provided.
result: pass
evidence: `mix test test/lattice_stripe/mandate_test.exs test/lattice_stripe/setup_attempt_test.exs --warnings-as-errors`

### 6. SetupAttempt integration route sanity
expected: Integration coverage should verify that setup-attempt list and stream requests hit the correct Stripe endpoint when `stripe-mock` is available.
result: pass
evidence: `mix test --include integration test/integration/setup_attempt_integration_test.exs`

### 7. Read-Only Diagnostic Wording
expected: Reading the `LatticeStripe.Mandate` and `LatticeStripe.SetupAttempt` moduledocs should make it clear that these modules are inspection-oriented and do not expose create, update, or delete flows.
result: pass
evidence: `mix test test/lattice_stripe/mandate_test.exs test/lattice_stripe/setup_attempt_test.exs --warnings-as-errors`

### 8. SetupAttempt required-filter documentation
expected: The `LatticeStripe.SetupAttempt` docs and examples should clearly show that `"setup_intent"` is required and mention that missing it raises `ArgumentError` before any network request.
result: pass
evidence: `mix test test/lattice_stripe/mandate_test.exs test/lattice_stripe/setup_attempt_test.exs --warnings-as-errors`

## Summary

total: 8
passed: 8
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

None.
