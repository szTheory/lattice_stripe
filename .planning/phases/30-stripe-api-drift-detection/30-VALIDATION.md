---
phase: 30
slug: stripe-api-drift-detection
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 30 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/drift_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds (drift tests only); ~120 seconds (full suite) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/drift_test.exs`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 30-01-01 | 01 | 1 | DX-06 | — | N/A | unit | `mix test test/lattice_stripe/drift_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/lattice_stripe/drift_test.exs` — stubs for DX-06 drift detection tests
- [ ] `test/fixtures/openapi/` — fixture spec snippets for deterministic testing

*Existing ExUnit infrastructure covers framework requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| GitHub Actions cron workflow triggers weekly | DX-06 | CI cron scheduling cannot be tested in unit tests | Verify `.github/workflows/drift.yml` has valid `schedule: cron` syntax and correct job steps |
| Issue creation/update on drift detection | DX-06 | Requires GitHub API authentication | Verify workflow uses `gh issue create` with proper deduplication logic |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
