---
phase: "75"
slug: "typed-contract-updates"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-24"
---

# Phase 75 — Validation Strategy

> Draft only. No candidate is currently eligible, so field-specific checks cannot yet be defined honestly.

## Test Infrastructure

| Property | Value |
|---|---|
| Framework | ExUnit (existing repository suite) |
| Config file | `test/test_helper.exs` |
| Quick run command | Not applicable until a field and resource are selected |
| Full suite command | `mix ci` after implementation is eligible |
| Estimated runtime | Not measured in this research run |

## Sampling Rate

- After each future decoder/test task: run the focused resource test file.
- After the implementation wave: run the relevant compatibility checks and full suite.
- Before phase verification: require all planned automated checks to pass.
- Feedback latency: to be set after an eligible implementation plan exists.

## Per-Task Verification Map

No implementation tasks are currently eligible. Do not add placeholder tests for hypothetical fields. After the Phase 74 evidence gate passes, map DRIFT-02/03/04 to the exact field, resource, focused decoder test, API-surface compatibility check, and documentation/version check selected by the plan.

## Wave 0 Requirements

- [ ] Recover a successful exact-path drift inventory or dated exact-path artifact.
- [ ] Identify an immutable GA OpenAPI snapshot and verify at least one candidate's exact schema path, stable source, minimum API version, and response/event availability.
- [ ] Record fixture provenance before field-specific test design.

These are source-evidence preconditions, not test-infrastructure gaps. Current `mix lattice_stripe.check_drift` cannot run in this environment because Mix startup fails with a PubSub socket `:eperm` error.

## Manual-Only Verifications

No field-specific manual check is justified yet. Any eventual live Stripe behavior claim would need separately scoped evidence; decoder fixtures alone prove only decoding behavior.

## Validation Sign-Off

- [ ] All implementation tasks have executable verification.
- [ ] Wave 0 evidence gate is complete.
- [ ] Sampling continuity is established from the selected plan.
- [ ] `nyquist_compliant: true` set after eligible work has a real validation map.

**Approval:** pending evidence qualification
