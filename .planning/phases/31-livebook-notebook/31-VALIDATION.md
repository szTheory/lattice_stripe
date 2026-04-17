---
phase: 31
slug: livebook-notebook
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 31 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) — but no new test files for this phase |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `ls notebooks/stripe_explorer.livemd && grep -c "```elixir" notebooks/stripe_explorer.livemd` |
| **Full suite command** | `mix test --include integration` |
| **Estimated runtime** | ~2 seconds (file existence only; manual notebook execution for full validation) |

---

## Sampling Rate

- **After every task commit:** Run `ls notebooks/stripe_explorer.livemd && head -50 notebooks/stripe_explorer.livemd`
- **After every plan wave:** Manual notebook execution against stripe-mock
- **Before `/gsd-verify-work`:** Full manual walkthrough — open in LiveBook, run all cells
- **Max feedback latency:** 2 seconds (file checks); manual review at wave boundaries

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 31-01-01 | 01 | 1 | DX-05 | — | N/A | file check | `test -f notebooks/stripe_explorer.livemd` | ❌ W0 | ⬜ pending |
| 31-01-02 | 01 | 1 | DX-05 | — | N/A | content check | `grep -q "Mix.install" notebooks/stripe_explorer.livemd` | ❌ W0 | ⬜ pending |
| 31-01-03 | 01 | 1 | DX-05 | — | N/A | content check | `grep -q "kino" notebooks/stripe_explorer.livemd` | ❌ W0 | ⬜ pending |
| 31-01-04 | 01 | 1 | DX-05 | — | N/A | content check | `grep -q "PaymentIntent" notebooks/stripe_explorer.livemd` | ❌ W0 | ⬜ pending |
| 31-01-05 | 01 | 1 | DX-05 | — | N/A | content check | `grep -q "Subscription" notebooks/stripe_explorer.livemd` | ❌ W0 | ⬜ pending |
| 31-01-06 | 01 | 1 | DX-05 | — | N/A | content check | `grep -q "MeterEvent" notebooks/stripe_explorer.livemd` | ❌ W0 | ⬜ pending |
| 31-01-07 | 01 | 1 | DX-05 | — | N/A | content check | `grep -q "BillingPortal.Session" notebooks/stripe_explorer.livemd` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `notebooks/` directory — needs creation (does not exist)
- [ ] No ExUnit test files needed — this phase is content authoring only

*Existing test infrastructure covers all project-level requirements. Phase 31 validation is file existence + content checks.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| All cells execute in LiveBook | DX-05 SC-1 | LiveBook is an external runtime, not invocable from CI | Open `notebooks/stripe_explorer.livemd` in LiveBook, start stripe-mock, run all cells sequentially |
| Explanatory prose between sections | DX-05 SC-2 | Subjective content quality | Read the notebook and verify Markdown sections exist between code cells |
| Kino widgets render correctly | DX-05 SC-3 | Visual rendering in LiveBook UI | Open in LiveBook, verify Input/DataTable/Tree widgets display |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 2s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
