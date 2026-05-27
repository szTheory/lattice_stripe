---
phase: 55
slug: milestone-closure-v1-x-stop-signal
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 55 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `mix.exs` test paths |
| **Quick run command** | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` |
| **Full suite command** | `mix test --warnings-as-errors` |
| **Estimated runtime** | ~2s (docs_truth); full suite variable |

---

## Sampling Rate

- **After every task commit:** Run docs_truth when README, guides, or `docs_truth_test.exs` changed
- **After every plan wave:** Run full `docs_truth_test.exs` + `mix compile --warnings-as-errors`
- **Before `/gsd-verify-work`:** docs_truth green; `55-VERIFICATION.md` populated
- **Max feedback latency:** 30 seconds (docs_truth only)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 55-01-01 | 01 | 1 | CLOSE-01 | — | N/A | file | `test -f .planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md` | ✅ W0 | ⬜ pending |
| 55-01-02 | 01 | 1 | CLOSE-01 | T-55-01 | Honest status vocabulary | grep | `rg 'accepted-external-verification' .planning/phases/41.1` | ✅ W0 | ⬜ pending |
| 55-02-01 | 02 | 2 | CLOSE-02 | — | N/A | file | `test -f guides/scope.md` | ❌ W0 | ⬜ pending |
| 55-02-02 | 02 | 2 | CLOSE-02 | T-55-02 | No false completeness claims | unit | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` | ✅ W0 | ⬜ pending |
| 55-03-01 | 03 | 2 | CLOSE-01/02 | T-55-03 | REL-04 verified before REL [x] | manual | `mix hex.info lattice_stripe` shows 1.7.0 | — | ⬜ pending |
| 55-04-01 | 04 | 3 | CLOSE-01/02 | — | N/A | file | `test -f .planning/phases/55-milestone-closure-v1-x-stop-signal/55-VERIFICATION.md` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements:

- [x] `test/lattice_stripe/docs_truth_test.exs` — extend in plan 55-04
- [x] ExUnit via `mix test`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| REL-04 Hex publish | D-05a | External registry | Run `mix hex.info lattice_stripe` or check hex.pm before marking REL-* `[x]` |
| 41.1 retirement tone | CLOSE-01 | Prose quality | Read retirement append; confirm no "verified in sandbox" |
| Milestone close-ready | D-05b | Planning judgment | STATE `status: close_ready`; next step audit-milestone |

---

## Nyquist Compliance

- Dimension 8 satisfied when all automated rows are ✅ and `55-VERIFICATION.md` documents grep evidence.
