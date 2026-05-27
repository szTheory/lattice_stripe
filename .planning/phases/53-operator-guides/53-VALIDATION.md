---
phase: 53
slug: operator-guides
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-27
---

# Phase 53 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `mix.exs` test alias |
| **Quick run command** | `mix test test/lattice_stripe/docs_truth_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~5–15 seconds (docs_truth); ~2–5 min (full) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/docs_truth_test.exs`
- **After every plan wave:** Run `mix test test/lattice_stripe/docs_truth_test.exs`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 53-01-all | 01 | 1 | OPS-01 | — | Checklist guide with locked anchors | docs-truth (partial) | manual read + line count | ⬜ pending |
| 53-02-all | 02 | 1 | OPS-02 | — | Debugging guide with locked anchors | docs-truth (partial) | manual read + line count | ⬜ pending |
| 53-03-all | 03 | 2 | OPS-01, OPS-02 | — | ExDoc + README + JTBD + reverse links | docs-truth (partial) | `mix test .../docs_truth_test.exs` | ⬜ pending |
| 53-04-all | 04 | 2 | OPS-01, OPS-02 | — | Full docs-truth lock set | integration | `mix test .../docs_truth_test.exs` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements:
- [x] `test/lattice_stripe/docs_truth_test.exs` — Phase 48 pattern
- [x] ExUnit via `mix test`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Guide readability / line count | OPS-01, OPS-02 | Subjective prose quality | Spot-check ~180–220 and ~220–280 line targets |

---

## Validation Sign-Off

- [x] All tasks have automated verify via docs_truth_test.exs (plan 04)
- [x] Sampling continuity: docs_truth after each plan
- [x] Wave 0 covers all MISSING references — N/A
- [x] No watch-mode flags
- [x] Feedback latency < 30s for docs_truth subset
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
