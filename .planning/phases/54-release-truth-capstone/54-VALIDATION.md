---
phase: 54
slug: release-truth-capstone
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-27
---

# Phase 54 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix |
| **Config file** | `mix.exs` (`test_paths`, `elixirc_paths`) |
| **Quick run command** | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` |
| **Full suite command** | `mix test --warnings-as-errors` |
| **Estimated runtime** | ~90 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick docs_truth command when `docs_truth_test.exs` or public docs touched
- **After every plan wave:** Run full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 54-01-01 | 01 | 1 | REL-01 | — | Version string matches published intent | grep | `grep '@version "1.7.0"' mix.exs` | ✅ | ⬜ pending |
| 54-01-02 | 01 | 1 | REL-02 | — | CHANGELOG has 1.4–1.7 sections | grep | `grep -E '^## \[1\.[4567]\.0\]' CHANGELOG.md` | ✅ | ⬜ pending |
| 54-02-01 | 02 | 2 | REL-03 | T-54-01 | All install surfaces show `~> 1.7` | rg | `rg -l '~> 1\.7' README.md guides/{getting-started,cheatsheet.cheatmd,webhooks-thin-events,production-checklist,event-debugging,opentelemetry}.md` | ✅ | ⬜ pending |
| 54-03-01 | 03 | 2 | REL-03 | T-54-02 | docs_truth SSOT tests pass | unit | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 54-04-01 | 04 | 3 | REL-04 | T-54-03 | Package on Hex at 1.7.0 | manual | `mix hex.info lattice_stripe 1.7.0` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test stubs required.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Hex publish | REL-04 | Requires HEX_API_KEY and maintainer approval | Run preflight checklist, tag `v1.7.0`, `mix hex.publish --yes`, verify hex.pm |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or manual instructions
- [x] Sampling continuity: docs_truth after doc-touching tasks
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending execution
