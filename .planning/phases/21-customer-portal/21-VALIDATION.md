---
phase: 21
slug: customer-portal
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-14
---

# Phase 21 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/billing_portal/` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~30 seconds (full); ~5 seconds (portal subset) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/billing_portal/`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | ⬜ pending |

*Populated by planner. Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/lattice_stripe/billing_portal/session_test.exs` — unit stubs for PORTAL-01..06
- [ ] `test/integration/billing_portal/session_integration_test.exs` — stripe-mock integration stubs

*Planner fills in per plan wave 0.*

---

## Manual-Only Verifications

*All phase behaviors should have automated verification via ExUnit + stripe-mock. If the planner identifies any manual-only items (e.g., real Stripe dashboard portal rendering), list them here.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
