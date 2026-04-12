---
phase: 5
slug: setupintents-paymentmethods
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-02
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test --only phase5` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test --only phase5`
- **After every plan wave:** Run `mix test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | SINT-01 | unit | `mix test test/lattice_stripe/setup_intent_test.exs` | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 1 | SINT-02 | unit | `mix test test/lattice_stripe/setup_intent_test.exs` | ❌ W0 | ⬜ pending |
| 05-01-03 | 01 | 1 | SINT-03 | unit | `mix test test/lattice_stripe/setup_intent_test.exs` | ❌ W0 | ⬜ pending |
| 05-01-04 | 01 | 1 | SINT-04 | unit | `mix test test/lattice_stripe/setup_intent_test.exs` | ❌ W0 | ⬜ pending |
| 05-01-05 | 01 | 1 | SINT-05 | unit | `mix test test/lattice_stripe/setup_intent_test.exs` | ❌ W0 | ⬜ pending |
| 05-01-06 | 01 | 1 | SINT-06 | unit | `mix test test/lattice_stripe/setup_intent_test.exs` | ❌ W0 | ⬜ pending |
| 05-02-01 | 02 | 1 | PMTH-01 | unit | `mix test test/lattice_stripe/payment_method_test.exs` | ❌ W0 | ⬜ pending |
| 05-02-02 | 02 | 1 | PMTH-02 | unit | `mix test test/lattice_stripe/payment_method_test.exs` | ❌ W0 | ⬜ pending |
| 05-02-03 | 02 | 1 | PMTH-03 | unit | `mix test test/lattice_stripe/payment_method_test.exs` | ❌ W0 | ⬜ pending |
| 05-02-04 | 02 | 1 | PMTH-04 | unit | `mix test test/lattice_stripe/payment_method_test.exs` | ❌ W0 | ⬜ pending |
| 05-02-05 | 02 | 1 | PMTH-05 | unit | `mix test test/lattice_stripe/payment_method_test.exs` | ❌ W0 | ⬜ pending |
| 05-02-06 | 02 | 1 | PMTH-06 | unit | `mix test test/lattice_stripe/payment_method_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/lattice_stripe/setup_intent_test.exs` — stubs for SINT-01 through SINT-06
- [ ] `test/lattice_stripe/payment_method_test.exs` — stubs for PMTH-01 through PMTH-06
- [ ] Verify `test/support` is in `elixirc_paths` for `:test` env

*Existing test infrastructure (ExUnit, Mox) covers framework needs.*

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
