---
phase: 25-performance-guide-per-op-timeouts-connection-warm-up
plan: "03"
subsystem: documentation
tags: [docs, performance, finch, pool-sizing, operation-timeouts, warm-up, exdoc]
dependency_graph:
  requires: [25-01, 25-02]
  provides: [guides/performance.md, PERF-01]
  affects: [mix.exs]
tech_stack:
  added: []
  patterns: [ExDoc extras list, guide authoring]
key_files:
  created:
    - guides/performance.md
  modified:
    - mix.exs
decisions:
  - "D-07: guides/performance.md with 6 sections: Pool Sizing, Supervision Tree, Per-Operation Timeouts, Connection Warm-Up, Benchmarking, Common Pitfalls"
  - "D-08: guides/performance.md added to mix.exs extras list after guides/client-configuration.md"
metrics:
  duration: "~8 minutes"
  completed: "2026-04-16T19:59:18Z"
  tasks_completed: 2
  files_created: 1
  files_modified: 1
---

# Phase 25 Plan 03: Performance Guide Summary

Production performance guide (`guides/performance.md`) with 6 sections covering Finch pool sizing, per-operation timeouts, and connection warm-up; wired into ExDoc via mix.exs extras list.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create guides/performance.md with all 6 sections | d60725b | guides/performance.md (created, 286 lines) |
| 2 | Add guides/performance.md to mix.exs extras and verify ExDoc | 424c889 | mix.exs |

## What Was Built

**guides/performance.md** — 286-line production guide with 6 sections per D-07:

1. **Pool Sizing** — Explains HTTP/1.1 pool semantics (`size` * `count` = max concurrent requests). Three concrete Finch configs: conservative (`size: 10, count: 1` = 10 concurrent), standard (`size: 25, count: 2` = 50 concurrent), high-throughput (`size: 50, count: 4` = 200 concurrent).

2. **Supervision Tree** — Complete `Application.start/2` example with production pool sizing, client creation, and graceful `warm_up/1` call using `Logger.warning` on failure.

3. **Per-Operation Timeouts** — Documents three-tier precedence chain (per-request opts > operation_timeouts > client.timeout). Includes the exact `%{list: 60_000, search: 45_000}` example from success criteria. Shows full configuration with all 6 operation keys. Recommended values table for heavy workloads.

4. **Connection Warm-Up** — Explains what "warm" means (TLS handshake pre-established, saves ~100–300ms). Documents both `warm_up/1` and `warm_up!/1`. Explains return values and why `GET /v1/` returning 404 is expected and correct.

5. **Benchmarking** — Shows `start_pool_metrics?: true` configuration and `Finch.get_pool_status/2` usage with `Enum.each` to print per-pool utilization. Cross-references Telemetry guide for request-level timing.

6. **Common Pitfalls** — Covers 4 production pitfalls: single-pool bottleneck, not warming up, aggressive timeouts on list/search, ignoring pool saturation.

**mix.exs** — Added `"guides/performance.md"` to the `extras:` list after `"guides/client-configuration.md"`. ExDoc generates `doc/performance.html` successfully.

## Verification Results

- All 6 sections present in guides/performance.md
- `operation_timeouts`, `warm_up`, `size.*count`, `Finch.get_pool_status` all present
- `doc/performance.html` generated successfully by `mix docs`
- `mix test` — 1699 tests, 0 failures (150 excluded)

## Deviations from Plan

### Pre-Existing Issue (Out of Scope)

`mix docs --warnings-as-errors` fails due to a pre-existing CHANGELOG.md reference to `LatticeStripe.ObjectTypes` (line 43), a module that does not exist in the codebase. This warning predates this plan — confirmed by running `mix docs --warnings-as-errors` with the guide reverted, which produced the same failure. The issue is logged here for tracking but is out of scope for this plan.

`mix docs` (without `--warnings-as-errors`) passes and generates `doc/performance.html` correctly.

## Known Stubs

None — the guide is complete prose with no placeholder content.

## Threat Flags

None — documentation-only plan with no new runtime code or network endpoints.

## Self-Check: PASSED

- guides/performance.md exists: FOUND
- d60725b exists: FOUND
- 424c889 exists: FOUND
- doc/performance.html generated: FOUND
- 1699 tests, 0 failures: PASSED
