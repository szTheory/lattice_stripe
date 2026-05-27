---
phase: 52
slug: charge-surface-expansion
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 52 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/charge_test.exs test/lattice_stripe/charge/ --warnings-as-errors` |
| **Full suite command** | `mix test --exclude integration --warnings-as-errors` |
| **Estimated runtime** | ~15 seconds (unit); +5s with integration |

---

## Sampling Rate

- **After every task commit:** Run quick run command when task touches Charge tests; `mix compile --warnings-as-errors` when task touches `charge.ex`
- **After every plan wave:** Run full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 52-01-01 | 01 | 1 | CHRG-01..04 | T-52-01 / — | PII fields remain hidden in Inspect | unit | `mix compile --warnings-as-errors` | ✅ | ⬜ pending |
| 52-01-02 | 01 | 1 | CHRG-05 | T-52-01 / — | Moduledoc does not claim retrieve-only | unit | `grep -c retrieve-only lib/lattice_stripe/charge.ex` (expect 0) | ✅ | ⬜ pending |
| 52-02-01 | 02 | 2 | CHRG-01..04 | T-52-02 / — | Mox asserts correct HTTP method/path | unit | `mix test test/lattice_stripe/charge/ --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 52-02-02 | 02 | 2 | CHRG-05 | T-52-02 / — | Export matrix + create/cancel refute | unit | `mix test test/lattice_stripe/charge_test.exs:module_surface --warnings-as-errors` | ✅ | ⬜ pending |
| 52-03-01 | 03 | 2 | CHRG-05 | T-52-01 / — | docs-truth grep locks moduledoc | unit | `mix test test/lattice_stripe/docs_truth_test.exs --only "Charge"` | ✅ | ⬜ pending |
| 52-03-02 | 03 | 2 | CHRG-05 | — | stripe-mock routing smoke | integration | `mix test test/integration/charge_integration_test.exs --include integration` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements:

- [x] `test/lattice_stripe/charge_test.exs` — retrieve/from_map/Inspect + D-06 block to replace
- [x] `test/support/fixtures/charge.ex` — Mox response fixtures
- [x] `test/lattice_stripe/payment_intent_test.exs` — wire-test pattern reference
- [x] Mox + MockTransport configured in `test/test_helper.exs`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| stripe-mock capture lifecycle | CHRG-04 | stripe-mock is stateless | Optional local run of integration test after Docker up |

All phase behaviors have automated verification for routing/decode; lifecycle semantics are explicitly out of scope per CONTEXT D-04.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
