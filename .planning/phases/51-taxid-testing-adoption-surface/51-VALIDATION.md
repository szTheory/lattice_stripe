---
phase: 51
slug: taxid-testing-adoption-surface
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 51 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` (Mox already configured) |
| **Quick run command** | `mix test test/lattice_stripe/tax_id_test.exs test/lattice_stripe/tax_object_types_expand_test.exs --no-start` |
| **Full suite command** | `mix test test/lattice_stripe/tax/ test/lattice_stripe/tax_id_test.exs test/lattice_stripe/tax_object_types_expand_test.exs test/lattice_stripe/docs_truth_test.exs --no-start` |
| **Estimated runtime** | ~35 seconds |

---

## Sampling Rate

- **After every task commit:** Run task-level `<automated>` verify from PLAN.md
- **After every plan wave:** Run wave-appropriate test slice from RESEARCH.md
- **Before `/gsd-verify-work`:** Full tax + docs-truth + compile green
- **Max feedback latency:** 35 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 51-01-01 | 01 | 1 | TAXID-01..04 | T-51-01 | Both URL paths implemented | unit | `mix test test/lattice_stripe/tax_id_test.exs --no-start` | ⬜ W0 | ⬜ pending |
| 51-02-01 | 02 | 2 | DX-02 | — | Public fixtures parse via from_map | unit | `mix test test/lattice_stripe/tax/calculation_transaction_test.exs --no-start` | ⬜ W0 | ⬜ pending |
| 51-02-02 | 02 | 2 | DX-01 | T-51-02 | Expand deserializes typed structs | unit | `mix test test/lattice_stripe/tax_object_types_expand_test.exs --no-start` | ⬜ W0 | ⬜ pending |
| 51-03-01 | 03 | 3 | DX-04 | — | Guide in ExDoc extras | grep | `mix test test/lattice_stripe/docs_truth_test.exs --no-start` (partial) | ⬜ W0 | ⬜ pending |
| 51-04-01 | 04 | 4 | DX-05 | — | Moduledoc anchors locked | grep | `mix test test/lattice_stripe/docs_truth_test.exs --no-start` | ⬜ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements:
- [x] Mox `LatticeStripe.MockTransport`
- [x] `LatticeStripe.TestHelpers`
- [x] Phase 49–50 Tax modules and internal fixtures
- [x] `docs_truth_test.exs` Phase 48 contract

New files created by plans:
- `lib/lattice_stripe/tax_id.ex`
- `lib/lattice_stripe/testing/fixtures/tax_*.ex`
- `guides/tax.md`
- `test/lattice_stripe/tax_object_types_expand_test.exs`

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 35s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
