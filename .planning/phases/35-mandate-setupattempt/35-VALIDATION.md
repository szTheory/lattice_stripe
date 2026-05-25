---
phase: 35
slug: mandate-setupattempt
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-24
---

# Phase 35 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Mox for unit tests and `stripe-mock` for integration |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/object_types_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | ~20 seconds |

---

## Sampling Rate

- **After every task commit:** Run the task-local unit command declared in the plan
- **After Plan 01 / Wave 1:** Run `mix test test/lattice_stripe/object_types_test.exs --warnings-as-errors` and `mix compile --warnings-as-errors`
- **After Plan 02 / Wave 2:** Run `mix test test/lattice_stripe/mandate_test.exs test/lattice_stripe/setup_attempt_test.exs --warnings-as-errors`
- **Before `$gsd-verify-work`:** Run `mix test test/lattice_stripe/mandate_test.exs test/lattice_stripe/setup_attempt_test.exs test/integration/setup_attempt_integration_test.exs` and then `mix ci`
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 35-01-01 | 01 | 1 | AUTH-01 | T-35-01 | Mandate nested structs preserve unknown fields in `extra` and atomize only bounded enums | unit | `mix test test/lattice_stripe/object_types_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 35-01-02 | 01 | 1 | AUTH-01, AUTH-02 | T-35-02 | `mandate` and `setup_attempt` registry dispatch stays aligned with Payments docs grouping and fixture contracts | unit | `mix test test/lattice_stripe/object_types_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 35-01-03 | 01 | 1 | AUTH-02 | T-35-03 | `SetupAttempt.from_map/1` keeps payment snapshots raw, models historical errors separately, and preserves forward compatibility | compile | `mix compile --warnings-as-errors` | ✅ | ⬜ pending |
| 35-02-01 | 02 | 2 | AUTH-01 | T-35-04 | `Mandate.retrieve/3` stays retrieve-only and docs keep the diagnostic/read-only posture explicit | unit | `mix test test/lattice_stripe/mandate_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 35-02-02 | 02 | 2 | AUTH-02 | T-35-05 | `SetupAttempt.list/3` and `stream!/3` require `"setup_intent"` locally and route to the correct Stripe endpoint | unit | `mix test test/lattice_stripe/setup_attempt_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 35-02-03 | 02 | 2 | AUTH-02 | T-35-06 | Integration coverage proves list/stream behavior against `stripe-mock` while preserving the real required-filter contract in fixture names and comments | integration | `mix test test/lattice_stripe/setup_attempt_test.exs test/integration/setup_attempt_integration_test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/support/fixtures/mandate.ex` — mandate fixture maps covering `customer_acceptance`, `single_use`, `multi_use`, and expandable `payment_method`
- [ ] `test/support/fixtures/setup_attempt.ex` — setup-attempt and nested `setup_error` fixtures, including expanded payment method examples
- [ ] `test/lattice_stripe/mandate_test.exs` — retrieve request-shape, parser, and bang helper coverage
- [ ] `test/lattice_stripe/setup_attempt_test.exs` — list/stream validation, parser, enum atomization, and historical-error coverage
- [ ] `test/integration/setup_attempt_integration_test.exs` — route sanity for `list/3` and `stream!/3` against `stripe-mock`

*Existing ExUnit, Mox, and `stripe-mock` infrastructure covers all framework requirements.*

---

## Documentation Verification

| Behavior | Requirement | Test Type | Automated Command |
|----------|-------------|-----------|-------------------|
| Read-only diagnostic wording in `Mandate` and `SetupAttempt` moduledocs | AUTH-01, AUTH-02 | unit | `mix test test/lattice_stripe/mandate_test.exs test/lattice_stripe/setup_attempt_test.exs --warnings-as-errors` |
| `SetupAttempt` required-filter documentation | AUTH-02 | unit | `mix test test/lattice_stripe/mandate_test.exs test/lattice_stripe/setup_attempt_test.exs --warnings-as-errors` |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references
- [x] No watch-mode flags
- [x] Feedback latency < 20s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-24
