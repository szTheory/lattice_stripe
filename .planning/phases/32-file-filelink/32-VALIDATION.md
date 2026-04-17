---
phase: 32
slug: file-filelink
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 32 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test --only phase32` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test --only phase32`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 32-01-01 | 01 | 1 | FILE-04 | — | N/A | unit | `mix test test/lattice_stripe/multipart_encoder_test.exs` | ❌ W0 | ⬜ pending |
| 32-01-02 | 01 | 1 | FILE-04 | — | N/A | unit | `mix test test/lattice_stripe/client_upload_test.exs` | ❌ W0 | ⬜ pending |
| 32-01-03 | 01 | 1 | FILE-05 | — | N/A | unit | `mix test test/lattice_stripe/client_download_test.exs` | ❌ W0 | ⬜ pending |
| 32-02-01 | 02 | 2 | FILE-01 | — | N/A | unit | `mix test test/lattice_stripe/file_test.exs` | ❌ W0 | ⬜ pending |
| 32-02-02 | 02 | 2 | FILE-02 | — | N/A | unit | `mix test test/lattice_stripe/file_test.exs` | ❌ W0 | ⬜ pending |
| 32-02-03 | 02 | 2 | FILE-03 | — | N/A | unit | `mix test test/lattice_stripe/file_link_test.exs` | ❌ W0 | ⬜ pending |
| 32-03-01 | 03 | 3 | FILE-01..05 | — | N/A | integration | `mix test test/integration/` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- Existing infrastructure covers all phase requirements. ExUnit, Mox, and stripe-mock integration test setup are all in place from prior phases.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| stripe-mock multipart acceptance | FILE-04 | Requires running Docker stripe-mock | Start stripe-mock, run `mix test test/integration/` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
