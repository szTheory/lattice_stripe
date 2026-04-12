---
phase: 09
slug: testing-infrastructure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-03
---

# Phase 09 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | test/test_helper.exs |
| **Quick run command** | `mix test` |
| **Full suite command** | `mix test --include integration` |
| **Estimated runtime** | ~5 seconds (unit), ~15 seconds (with integration) |

---

## Sampling Rate

- **After every task commit:** Run `mix test`
- **After every plan wave:** Run `mix test --include integration` (if stripe-mock available)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 09-01-01 | 01 | 1 | TEST-01 | integration | `mix test test/integration/ --include integration` | ❌ W0 | ⬜ pending |
| 09-01-02 | 01 | 1 | TEST-02,TEST-03 | unit | `mix test test/lattice_stripe/` | ✅ | ⬜ pending |
| 09-02-01 | 02 | 2 | TEST-04 | unit | `mix test test/lattice_stripe/testing_test.exs` | ❌ W0 | ⬜ pending |
| 09-02-02 | 02 | 2 | TEST-05 | task | `mix ci` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/integration/` directory — integration test files for stripe-mock
- [ ] `test/lattice_stripe/testing_test.exs` — tests for public Testing module
- [ ] ExUnit configure exclude: [:integration] in test_helper.exs

*Existing infrastructure covers most phase requirements — Mox, fixtures, TestHelpers already established.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| stripe-mock Docker startup | TEST-01 | Requires Docker runtime | `docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest` then `mix test --include integration` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
