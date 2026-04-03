---
phase: 7
slug: webhooks
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-03
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/webhook_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/webhook_test.exs`
- **After every plan wave:** Run `mix test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 1 | WHBK-01 | unit | `mix test test/lattice_stripe/webhook/signature_test.exs` | ❌ W0 | ⬜ pending |
| 07-01-02 | 01 | 1 | WHBK-02 | unit | `mix test test/lattice_stripe/webhook/event_test.exs` | ❌ W0 | ⬜ pending |
| 07-01-03 | 01 | 1 | WHBK-03 | unit | `mix test test/lattice_stripe/webhook/signature_test.exs` | ❌ W0 | ⬜ pending |
| 07-02-01 | 02 | 2 | WHBK-04 | unit | `mix test test/lattice_stripe/webhook/plug_test.exs` | ❌ W0 | ⬜ pending |
| 07-02-02 | 02 | 2 | WHBK-05 | unit | `mix test test/lattice_stripe/webhook/plug_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/lattice_stripe/webhook/signature_test.exs` — stubs for WHBK-01, WHBK-03
- [ ] `test/lattice_stripe/webhook/event_test.exs` — stubs for WHBK-02
- [ ] `test/lattice_stripe/webhook/plug_test.exs` — stubs for WHBK-04, WHBK-05

*Existing infrastructure covers test framework — ExUnit is stdlib.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Timing-safe comparison resistance | WHBK-01 | Timing attacks require statistical analysis | Verify `Plug.Crypto.secure_compare/2` is used (grep check) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
