---
phase: 56
slug: release-truth-getting-started
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 56 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` |
| **Full suite command** | `mix test --warnings-as-errors` |
| **Estimated runtime** | ~2–5 seconds (docs_truth only) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors`
- **After every plan wave:** Run `mix test --warnings-as-errors`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 56-01-01 | 01 | 1 | TRUTH-02 | T-56-01 | SSOT helpers derive from mix.exs, not hardcoded | unit | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 56-01-02 | 01 | 1 | TRUTH-02 | T-56-02 | getting-started describe has prose + cross-link tests | unit | same | ✅ | ⬜ pending |
| 56-01-03 | 01 | 1 | TRUTH-02 | T-56-01 | README release test uses SSOT helpers | unit | same | ✅ | ⬜ pending |
| 56-02-01 | 02 | 2 | TRUTH-01 | T-56-03 | getting-started prose matches Hex 1.7.x surface | unit | same | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — no Wave 0 stubs needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| HexDocs rendered appearance | TRUTH-01 | ExDoc HTML not exercised in CI | Optional: `mix docs && open doc/index.html` to confirm blockquote renders after release |

*Primary verification is grep-based docs_truth — manual HexDocs check is optional.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
