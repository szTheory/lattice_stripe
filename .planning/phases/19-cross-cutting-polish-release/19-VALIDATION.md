---
phase: 19
slug: cross-cutting-polish-release
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-13
---

# Phase 19 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test --stale` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test --stale`
- **After every plan wave:** Run `mix test` (full suite)
- **Before `/gsd-verify-work`:** Full suite must be green + `mix docs` + `mix credo --strict` + `mix deps.audit`
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

*Populated by planner — each task in PLAN.md gets a row mapping task-id → automated command.*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | — | — | cross-cutting | — | N/A | — | — | — | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `test/lattice_stripe/readme_test.exs` — extracts and evaluates README Quick Start elixir fences (scoped to post-"Then create a client" blocks, skips `deps do` block)
- [ ] `test/support/readme_extractor.ex` (or inlined in readme_test.exs) — helper to parse fenced elixir blocks from README.md
- [ ] No new framework install needed — ExUnit already in place

*Existing stripe-mock + integration test infrastructure from prior phases covers Billing + Connect guide validation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ExDoc sidebar groups render correctly (Payments / Billing / Connect / Webhooks / Testing / Telemetry) | Success Criterion 2 | Visual inspection of generated HTML | `mix docs && open doc/index.html`; verify each group in left sidebar contains expected modules |
| README quickstart passes the 60-second test with current deps | Success Criterion 3 | Timed human walkthrough | Fresh shell, follow README steps literally, measure wall-clock from `mix new` to first successful API call |
| Release Please PR merges cleanly and publishes v1.0.0 to Hex | Success Criterion 5 | Requires merging into main and GitHub Actions release workflow | Merge release-please PR, confirm GH Release created, confirm `mix hex.info lattice_stripe` shows 1.0.0 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers readme_test.exs extractor
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter after planner fills Per-Task Verification Map

**Approval:** pending
