---
phase: 10
slug: documentation-guides
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-03
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) + mix docs |
| **Config file** | test/test_helper.exs |
| **Quick run command** | `mix docs --warnings-as-errors` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix docs --warnings-as-errors`
- **After every plan wave:** Run `mix ci`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | DOCS-03 | build | `mix docs --warnings-as-errors` | ✅ | ⬜ pending |
| 10-01-02 | 01 | 1 | DOCS-05 | build | `mix docs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 10-01-03 | 01 | 1 | DOCS-04 | manual | manual review | N/A | ⬜ pending |
| 10-02-01 | 02 | 1 | DOCS-01 | build | `mix docs --warnings-as-errors` | ✅ | ⬜ pending |
| 10-02-02 | 02 | 1 | DOCS-02 | build | `mix docs --warnings-as-errors` | ✅ | ⬜ pending |
| 10-02-03 | 02 | 1 | DOCS-06 | lint | `mix credo --strict` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `guides/` directory — all 9 .md + 1 .cheatmd files must exist before mix docs can validate
- [ ] `CHANGELOG.md` — must exist before being listed in extras
- [ ] mix.exs `docs` config updated with extras list pointing to guide files

*Wave 0 creates file scaffolding so `mix docs --warnings-as-errors` can run on every subsequent commit.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| README quickstart < 60s | DOCS-04 | Requires human following steps | Fresh project: copy quickstart, run commands, time to first API call |
| Guide readability & tone | DOCS-05 | Subjective quality assessment | Read each guide, verify tutorial style with real code examples |
| Code comments on non-obvious logic | DOCS-06 | Requires domain judgment | Review Stripe-specific code for inline comments with input/output shapes |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
