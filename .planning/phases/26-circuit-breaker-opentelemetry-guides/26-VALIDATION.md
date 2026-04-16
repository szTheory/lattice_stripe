---
phase: 26
slug: circuit-breaker-opentelemetry-guides
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 26 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/guides/` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/guides/`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 26-01-01 | 01 | 1 | PERF-02 | — | N/A | manual | Guide content review | ❌ W0 | ⬜ pending |
| 26-01-02 | 01 | 1 | PERF-02 | — | N/A | integration | `mix test --only fuse_integration` | ❌ W0 | ⬜ pending |
| 26-02-01 | 02 | 1 | DX-04 | — | N/A | manual | Guide content review | ❌ W0 | ⬜ pending |
| 26-02-02 | 02 | 1 | DX-04 | — | N/A | integration | `mix test --only otel_integration` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/lattice_stripe/guides/circuit_breaker_guide_test.exs` — fuse integration test stubs
- [ ] `test/lattice_stripe/guides/opentelemetry_guide_test.exs` — OTel integration test stubs

*Existing test infrastructure covers framework needs. Only new test files needed for guide example verification.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Circuit breaker prose explains state machine | PERF-02 SC-2 | Content quality, not code behavior | Read guide, verify closed/open/half-open explained in prose |
| OTel guide shows Honeycomb + Datadog configs | DX-04 SC-3 | Configuration accuracy, not runtime behavior | Read guide, verify both backend examples present with complete config |
| :fuse not-bundled explanation present | PERF-02 SC-2 | Content presence, not code behavior | Read guide, verify explanation of why :fuse is user-side |
| ExDoc guide placement correct | DX-04 | Visual layout, not code behavior | Run `mix docs`, verify guides appear in nav |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
