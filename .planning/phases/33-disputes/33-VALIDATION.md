---
phase: 33
slug: disputes
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-17
---

# Phase 33 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/dispute_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/dispute_test.exs`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 33-01-01 | 01 | 1 | DISP-06 | — | N/A | unit | `mix test test/lattice_stripe/dispute_test.exs` | ❌ W0 | ⬜ pending |
| 33-01-02 | 01 | 1 | DISP-07 | — | N/A | unit | `mix test test/lattice_stripe/dispute_test.exs` | ❌ W0 | ⬜ pending |
| 33-02-01 | 02 | 1 | DISP-01 | — | N/A | unit | `mix test test/lattice_stripe/dispute_test.exs` | ❌ W0 | ⬜ pending |
| 33-02-02 | 02 | 1 | DISP-02 | — | N/A | unit | `mix test test/lattice_stripe/dispute_test.exs` | ❌ W0 | ⬜ pending |
| 33-02-03 | 02 | 1 | DISP-03, DISP-04 | — | submit key stripped from evidence map | unit | `mix test test/lattice_stripe/dispute_test.exs` | ❌ W0 | ⬜ pending |
| 33-02-04 | 02 | 1 | DISP-05 | — | N/A | unit | `mix test test/lattice_stripe/dispute_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/lattice_stripe/dispute_test.exs` — stubs for DISP-01 through DISP-07
- [ ] `test/support/fixtures/dispute_fixtures.ex` — dispute JSON fixture helpers

*Existing test infrastructure (ExUnit, Mox, test_helper.exs) covers all framework requirements.*

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
