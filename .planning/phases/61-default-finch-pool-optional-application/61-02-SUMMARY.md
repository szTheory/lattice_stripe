---
phase: 61-default-finch-pool-optional-application
plan: 02
subsystem: docs
tags: [docs, finch, dx, changelog]
status: complete
requires:
  - "61-01: LatticeStripe.Application default Finch pool + :finch default + start_default_finch opt-out"
provides:
  - "getting-started.md and client-configuration.md document the default LatticeStripe.Finch pool and optional :finch"
  - "start_default_finch: false opt-out documented for BYO-supervision consumers"
  - "CHANGELOG Unreleased entry for the additive default-pool feature"
affects:
  - guides/getting-started.md
  - guides/client-configuration.md
  - CHANGELOG.md
tech-stack:
  added: []
  patterns:
    - "Release-Please CHANGELOG: hand-authored ## [Unreleased] / ### Features section above latest release; no manual version/timestamp"
key-files:
  created: []
  modified:
    - guides/getting-started.md
    - guides/client-configuration.md
    - CHANGELOG.md
decisions:
  - "Documented D-04 (default pool exists, :finch optional, additive) and D-05 (start_default_finch: false opt-out) across both guides + CHANGELOG"
  - "Kept all existing finch: MyApp.Finch examples valid as explicit overrides; no mix.exs version bump (Release Please owns it)"
metrics:
  duration: ~10m
  completed: 2026-07-27
  tasks: 2
  files: 3
---

# Phase 61 Plan 02: Docs + CHANGELOG for Default Finch Pool Summary

Updated the getting-started and client-configuration guides plus the CHANGELOG so adopters learn a default `LatticeStripe.Finch` pool now ships automatically, `:finch` is optional (defaults to it), existing BYO-Finch wiring still works, and BYO-supervision users can opt out with `config :lattice_stripe, start_default_finch: false`.

## What Was Built

**Task 1 — Guide corrections (commit b234c41):**
- `guides/getting-started.md`:
  - "Creating a Client" now shows `api_key` as the only required option with `:finch` defaulting to the auto-started `LatticeStripe.Finch` pool; kept a second example with an explicit `finch: MyApp.Finch` override.
  - "Setting Up Finch" gained a callout that the default pool auto-starts (manual setup now optional) and documents the `start_default_finch: false` opt-out; the manual/BYO supervision instructions remain valid (the word "Finch" and supervision guidance preserved).
  - Updated two now-stale pitfalls ("no pool found" and "Client is a struct, not a process") to reflect the auto-started default pool.
- `guides/client-configuration.md`: "Required Options" reworded so `api_key` is the only required option and `:finch` is documented as optional-with-default (`LatticeStripe.Finch`), still overridable; added the `start_default_finch: false` opt-out callout; non-raising `Client.new/1` example no longer passes `finch:`.

**Task 2 — CHANGELOG entry (commit 42f1078):**
- Added a `## [Unreleased]` / `### Features` entry recording the additive, backwards-compatible default-pool change and the `start_default_finch: false` opt-out. No `mix.exs` version bump (Release Please manages the version/timestamp).

## Verification

- `mix test test/lattice_stripe/docs_truth_test.exs` — 48 tests, 0 failures (guide + CHANGELOG assertions preserved).
- `grep -in 'start_default_finch' guides/getting-started.md guides/client-configuration.md CHANGELOG.md` — opt-out documented in all three surfaces.
- Task 2 grep verify (`start_default_finch|default.*Finch pool|LatticeStripe.Finch` in CHANGELOG.md) — matches.

## Deviations from Plan

None to the task actions. One pre-existing gate issue documented below.

## Deferred Issues

- **`mix docs --warnings-as-errors` is NOT green — pre-existing, out of scope.** The plan listed this as a gate (SC-5, key_links). Verified by restoring both guides to their HEAD versions and re-running: the docs build already fails on HEAD, before any edit in this plan. The warnings come from unrelated sources — `documentation references file "../README.md" but it does not exist` (from `getting-started.md:20` and `guides/scope.md`, untouched here) and several `lib/*.ex` module doc references (`LatticeStripe.Builders.BillingPortal`, `LatticeStripe.Tax.TaxBreakdown.t()`, `LatticeStripe.Webhook.check_tolerance/2`). None reference this plan's prose edits. Per the scope boundary (only auto-fix issues directly caused by the current task), these were not touched. Recommend a follow-up quick task to fix the `../README.md` relative-link resolution and the hidden/undefined module doc references so the docs gate goes green.

## Known Stubs

None.

## Self-Check: PASSED

- guides/getting-started.md — FOUND (modified, committed b234c41)
- guides/client-configuration.md — FOUND (modified, committed b234c41)
- CHANGELOG.md — FOUND (modified, committed 42f1078)
- Commit b234c41 — FOUND
- Commit 42f1078 — FOUND
