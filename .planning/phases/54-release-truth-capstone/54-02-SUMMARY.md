---
phase: 54-release-truth-capstone
plan: 02
subsystem: release
tags: [docs, readme, install]

requires:
  - phase: 54-01
    provides: mix.exs 1.7.0
provides:
  - Lockstep ~> 1.7 on seven public install surfaces
  - README milestone release-status and HexDocs tax + Charge links
affects: [54-03]

key-files:
  modified: [README.md, guides/getting-started.md, guides/cheatsheet.cheatmd, guides/webhooks-thin-events.md, guides/opentelemetry.md]

requirements-completed: [REL-03]

duration: 3min
completed: 2026-05-27
---

# Phase 54 Plan 02 Summary

**Flipped all public install anchors to `~> 1.7` and refreshed README release narrative with v1.4–v1.7 milestone bullets plus Tax and Charge HexDocs links.**

## Task Commits

1. **Task 1–2: Install flip + README release/HexDocs** - `29bfc69`

## Self-Check: PASSED

- All 7 surfaces contain `{:lattice_stripe, "~> 1.7"}`
- README contains tax.html and Charge.html links
