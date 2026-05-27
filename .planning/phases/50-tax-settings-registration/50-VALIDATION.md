---
phase: 50
slug: tax-settings-registration
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 50 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` (Mox already configured) |
| **Quick run command** | `mix test test/lattice_stripe/tax/settings_test.exs test/lattice_stripe/tax/registration_test.exs --no-start` |
| **Full suite command** | `mix test test/lattice_stripe/tax/ --no-start` |
| **Estimated runtime** | ~20 seconds |

---

## Sampling Rate

- **After every task commit:** Run task-level `<automated>` verify from PLAN.md
- **After every plan wave:** Run full `mix test test/lattice_stripe/tax/ --no-start`
- **Before `/gsd-verify-work`:** Full tax suite + `mix compile --warnings-as-errors` green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 50-01-01 | 01 | 1 | CONF-01 | T-50-01 | No fake ID in settings URL | unit | `mix test test/lattice_stripe/tax/settings_test.exs --no-start` | ⬜ W0 | ⬜ pending |
| 50-01-02 | 01 | 1 | CONF-02 | — | N/A | unit | same | ⬜ W0 | ⬜ pending |
| 50-02-01 | 02 | 2 | CONF-03 | — | N/A | unit | `mix test test/lattice_stripe/tax/registration_test.exs --no-start` | ⬜ W0 | ⬜ pending |
| 50-02-02 | 02 | 2 | CONF-04, ROADMAP SC#6 | — | N/A | grep+unit | `mix test test/lattice_stripe/tax/ --no-start` | ⬜ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements:
- [x] Mox `LatticeStripe.MockTransport`
- [x] `LatticeStripe.TestHelpers`
- [x] Phase 49 tax modules and fixture patterns

New files created by plans:
- `test/support/fixtures/tax_settings.ex`
- `test/support/fixtures/tax_registration.ex`

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
