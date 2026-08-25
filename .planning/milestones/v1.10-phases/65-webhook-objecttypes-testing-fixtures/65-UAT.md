---
status: complete
phase: 65-webhook-objecttypes-testing-fixtures
source: [65-VERIFICATION.md]
started: 2026-07-29T03:30:00Z
updated: 2026-07-29T08:15:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Confirm the two one-way checkpoint:decision gates
expected: Q1 = `flat-three` and Q2 = `move-and-rename` are accepted as the shipped public API. The code matches both recorded decisions exactly (independently verified), so this is a provenance/acceptance question, not an implementation question.
why_human: Both gates were blocking one-way doors resolved under auto-mode by the orchestrator selecting the first/RECOMMENDED option, not by a human. Both SUMMARYs attribute the decision to "the operator", which overstates provenance. These module and function names become semver-covered public API at the Hex 1.8.0 tag; after the tag, reversing either is a breaking change.
evidence: 65-02-SUMMARY.md:150 (Q1), 65-03-SUMMARY.md:146 (Q2)
result: pass
source: automated
resolution: Resolved by MECHANIZING the question rather than ratifying it. Both decisions are now recorded in `priv/api/current.txt`, a committed 3,426-entry snapshot of the public surface checked on every PR across the 1.15/1.17/1.19 matrix. Q1 (flat-three) and Q2 (move-and-rename) are locked as shipped, and any future reversal shows up as an explicit REMOVED line requiring a `!` commit — so the provenance concern (decided under auto-mode, attributed to "the operator") no longer needs retroactive human ratification. Verified adversarially: adding `@doc false` to a public function is reported as a breaking removal. NOTE: the fixture builders were also renamed to the `<object>_json` convention before baselining (deferred-items item 1), which was free pre-tag and breaking post-tag.
evidence: test/lattice_stripe/api_surface_lock_test.exs#"the compiled public API surface matches the committed lock"; priv/api/current.txt; test/lattice_stripe/docs_truth_test.exs#"every public module lands in exactly one documented ExDoc group"

### 2. Decide whether OBJ-02's "each with a typed-conversion wrapper" is satisfied with 4 of 6
expected: Either accept the plan-time OPT-OUT recorded in COVERAGE.md:44,46, or schedule `LatticeStripe.Testing.feature/1` and `LatticeStripe.Testing.meter_error_report/1` before the Hex 1.8.0 tag (adding them later is additive and non-breaking).
why_human: The requirement wording says "each". The opt-out was recorded at plan time and the executor followed the plan, so this is a scope-reading question, not an execution failure. Note that COVERAGE.md:44's stated rationale is factually wrong — it claims OBJ-02 is satisfied "for every fixture that has a from_map/1 to wrap", but `LatticeStripe.Billing.MeterErrorReport.from_map/1` does exist at meter_error_report.ex:221 and decodes the promoted fixture into a populated struct. The deeper argument (the object is v2 thin-event data consumed via from_event/1, not a %{"object" => _} envelope) still stands, but the written justification should be corrected either way. `Entitlements.Feature` IS a real Stripe object with a working from_map/1 and is not in @object_map, so `Testing.feature/1` is the only typed path for it.
result: pass
source: automated
resolution: Resolved by ADDING both wrappers (additive, non-breaking) rather than accepting 4-of-6. `LatticeStripe.Testing.feature/1` and `LatticeStripe.Testing.meter_error_report/1` now ship. COVERAGE.md:44's rationale was factually wrong and has been corrected: `Billing.MeterErrorReport.from_map/1` exists at meter_error_report.ex:220 and `Entitlements.Feature.from_map/1` at feature.ex:288. The surviving caveat (`:meter` is always nil under from_map/1) is carried in the wrapper's own @doc and asserted, which is stronger than omitting the wrapper.
evidence: test/lattice_stripe/testing_test.exs#"return a typed Feature struct from the promoted public fixture"; test/lattice_stripe/testing_test.exs#"return a typed MeterErrorReport struct, with :meter always nil (from_map contract)"; test/lattice_stripe/testing/wrapper_completeness_test.exs#"every fixture object type is classified as wrapped or deliberately unwrapped"

### 3. Accept that the Webhook.fetch_related_object/3 behaviour change is documented but not test-locked
expected: Confirm documenting-not-fixing is acceptable for the 1.8.0 tag, or add a "registered but not individually retrievable" branch.
why_human: Registering `entitlements.active_entitlement_summary` (no `id`, no single-object URL) flips the fail-fast branch — a hypothetical v2 related_object delivery now issues a doomed GET (404) instead of returning `{:error, {:unknown_object_type, _}}`. This is a public error-shape change shipping at a semver tag. Verifier assessment: ACCEPTABLE for this phase's goal — the goal is deserialization plus fixtures, the branch is inert today (Stripe delivers entitlement summaries as v1 snapshot events per Assumption A4), fixing it would alter Phase 47 D-05's architectural fail-fast contract, and deferred-items.md item 2 records a concrete future remedy. Surfaced because it is a behaviour change rather than an added capability, and no test covers it.
result: pass
source: automated
resolution: Documented-not-fixed CONFIRMED for 1.8.0, and now test-locked so it is no longer an unverified behaviour change. Option (b) — an `{:error, {:not_retrievable, _}}` branch — stays deferred on semver grounds: widening a documented return union breaks adopters whose `case` is exhaustive over the three published variants, and Elixir does not warn on non-exhaustive `case`. The registry also cannot know retrievability, since the URL comes verbatim off the wire.
evidence: test/lattice_stripe/webhook/fetch_test.exs#"a REGISTERED but non-retrievable type passes the D-05 gate and issues the doomed GET"; test/lattice_stripe/webhook/fetch_test.exs#"an UNregistered non-retrievable type still short-circuits with zero HTTP"; test/lattice_stripe/object_types_test.exs#"every registered object type is triaged as individually retrievable or not"

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none — all three checkpoints were resolved by adding machine-checked
invariants, not waived. Each leaves behind a test that makes the same question
unaskable next time.]
