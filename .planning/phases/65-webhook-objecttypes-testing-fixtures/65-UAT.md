---
status: testing
phase: 65-webhook-objecttypes-testing-fixtures
source: [65-VERIFICATION.md]
started: 2026-07-29T03:30:00Z
updated: 2026-07-29T03:30:00Z
---

## Current Test

number: 1
name: Confirm the two one-way checkpoint:decision gates resolved under auto-mode
expected: |
  Q1 = flat-three: exactly three meter fixtures public and FLAT at depth 3
  (Testing.Fixtures.MeterEvent / .MeterEventSummary / .MeterErrorReport); Meter,
  MeterEventAdjustment and MeterEventStreamSession stay private.
  Q2 = move-and-rename: customer/payment_intent/subscription MOVED with no private
  twin, Subscription.basic/1 renamed to subscription_json/1.
awaiting: user response

## Tests

### 1. Confirm the two one-way checkpoint:decision gates
expected: Q1 = `flat-three` and Q2 = `move-and-rename` are accepted as the shipped public API. The code matches both recorded decisions exactly (independently verified), so this is a provenance/acceptance question, not an implementation question.
why_human: Both gates were blocking one-way doors resolved under auto-mode by the orchestrator selecting the first/RECOMMENDED option, not by a human. Both SUMMARYs attribute the decision to "the operator", which overstates provenance. These module and function names become semver-covered public API at the Hex 1.8.0 tag; after the tag, reversing either is a breaking change.
evidence: 65-02-SUMMARY.md:150 (Q1), 65-03-SUMMARY.md:146 (Q2)
result: [pending]

### 2. Decide whether OBJ-02's "each with a typed-conversion wrapper" is satisfied with 4 of 6
expected: Either accept the plan-time OPT-OUT recorded in COVERAGE.md:44,46, or schedule `LatticeStripe.Testing.feature/1` and `LatticeStripe.Testing.meter_error_report/1` before the Hex 1.8.0 tag (adding them later is additive and non-breaking).
why_human: The requirement wording says "each". The opt-out was recorded at plan time and the executor followed the plan, so this is a scope-reading question, not an execution failure. Note that COVERAGE.md:44's stated rationale is factually wrong — it claims OBJ-02 is satisfied "for every fixture that has a from_map/1 to wrap", but `LatticeStripe.Billing.MeterErrorReport.from_map/1` does exist at meter_error_report.ex:221 and decodes the promoted fixture into a populated struct. The deeper argument (the object is v2 thin-event data consumed via from_event/1, not a %{"object" => _} envelope) still stands, but the written justification should be corrected either way. `Entitlements.Feature` IS a real Stripe object with a working from_map/1 and is not in @object_map, so `Testing.feature/1` is the only typed path for it.
result: [pending]

### 3. Accept that the Webhook.fetch_related_object/3 behaviour change is documented but not test-locked
expected: Confirm documenting-not-fixing is acceptable for the 1.8.0 tag, or add a "registered but not individually retrievable" branch.
why_human: Registering `entitlements.active_entitlement_summary` (no `id`, no single-object URL) flips the fail-fast branch — a hypothetical v2 related_object delivery now issues a doomed GET (404) instead of returning `{:error, {:unknown_object_type, _}}`. This is a public error-shape change shipping at a semver tag. Verifier assessment: ACCEPTABLE for this phase's goal — the goal is deserialization plus fixtures, the branch is inert today (Stripe delivers entitlement summaries as v1 snapshot events per Assumption A4), fixing it would alter Phase 47 D-05's architectural fail-fast contract, and deferred-items.md item 2 records a concrete future remedy. Surfaced because it is a behaviour change rather than an added capability, and no test covers it.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
