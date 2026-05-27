---
phase: 48-thin-event-adoption-surface-guide-integration-verification
plan: "04"
subsystem: docs-truth
tags: [docs-truth, testing, webhooks, thin-events, regression]
dependency_graph:
  requires: ["48-01", "48-02", "48-03"]
  provides: ["GUIDE-03 verification", "VERIFY-03 contract", "D-03 3A/3B/3C/3D locks"]
  affects: ["test/lattice_stripe/docs_truth_test.exs"]
tech_stack:
  added: []
  patterns: ["grep-locked docs regression", "ExUnit async File.read! substring assertions"]
key_files:
  created: []
  modified:
    - test/lattice_stripe/docs_truth_test.exs
decisions:
  - "3A test block: 16 substring assertions locking guide content — function names, error atoms, rate-limit phrasing, idempotency/Connect/truth/surface anchors, verification-vs-payload-shape phrasing"
  - "3B install-line canary: single assertion on {:lattice_stripe, \"~> 1.5\"} — only 1.5-only doc until release-prep lockstep flip (B2 canary architecture)"
  - "3C in-place extension: 2 assertions appended inside existing ExDoc placement test (not a new block)"
  - "3D cross-link graph: 8 assertions across 4 files (forward + reverse links from/to guide)"
  - "New blocks inserted BEFORE Plan 01 3E block to keep D-03 sub-decisions adjacent for readability"
metrics:
  duration: "~5 minutes"
  completed: "2026-05-27"
  tasks_completed: 2
  files_modified: 1
---

# Phase 48 Plan 04: Docs-Truth Regression Net for webhooks-thin-events.md Summary

Locked the `guides/webhooks-thin-events.md` guide content, install-line canary, ExDoc placement, and cross-link graph via four docs-truth grep tests (3A, 3B, 3C, 3D) in `test/lattice_stripe/docs_truth_test.exs`.

## What Was Built

Extended `test/lattice_stripe/docs_truth_test.exs` with the D-03 sub-decisions 3A, 3B, 3C, and 3D regression net:

- **3C (in-place, Task 1):** Added 2 assertions to the existing `"exdoc keeps the primary public truth surfaces published"` test, immediately after the `assert "guides/webhooks.md" in groups["Operations & DX"]` line. Locks that `guides/webhooks-thin-events.md` is present in both `extras` and `groups["Operations & DX"]`.

- **3A (new block, Task 2):** `test "webhooks-thin-events guide locks the thin-event adopter contract"` at lines 190-224. Contains 16 `assert guide =~ "..."` assertions: 3 function names (`parse_event_notification`, `fetch_event`, `fetch_related_object`), 4 error atoms (`:no_matching_signature`, `:timestamp_expired`, `:no_related_object`, `:unknown_object_type`), 2 rate-limit substrings (`100 req/s`, `90/s`), 4 anchor substrings (`event.id`, `event.context`, `Webhooks confirm`, `/v2/events`), 2 verification-vs-payload-shape substrings.

- **3B (new block, Task 2):** `test "webhooks-thin-events guide is the v1.5 install-line canary"` at lines 226-235. 1 assertion: `guide =~ "{:lattice_stripe, \"~> 1.5\"}"`. The existing tests at lines 54, 61, 165 still assert `~> 1.3` for README/getting-started/cheatsheet — when v1.5 release prep flips those, the old tests fail first, enforcing lockstep without coupling Phase 48 to release prep.

- **3D (new block, Task 2):** `test "webhooks-thin-events guide is cross-linked from README/JTBD/webhooks.md"` at lines 237-264. Reads 4 distinct files: `guides/webhooks-thin-events.md` (3 forward links: `webhooks.md`, `testing.md`, `error-handling.md`), `guides/webhooks.md` (2 assertions: `webhooks-thin-events.md` + `thin event`), `README.md` (1 assertion: `webhooks-thin-events.md`), `guides/user-flows-and-jtbd.md` (1 assertion: `webhooks-thin-events.md`). Total: 8 substring assertions.

## Test File Line Ranges

| Block | Lines | Type | Assertions |
|-------|-------|------|-----------|
| 3C in-place edit | lines 39-41 (inside existing test at 8-43) | in-place extension | 2 assertions in existing ExDoc placement test |
| 3A new block | lines 190-224 | new test | 16 assertions (guide content lock) |
| 3B new block | lines 226-235 | new test | 1 assertion (install-line canary) |
| 3D new block | lines 237-264 | new test | 8 assertions across 4 files (cross-link graph) |
| 3E (Plan 01) | lines 266-277 | existing (Plan 01) | 1 assertion (Plug @moduledoc tolerance: 0) |

## Final Test Count

`grep -c '^  test "' test/lattice_stripe/docs_truth_test.exs` = **12**

- 8 existing tests (unchanged beyond 3C in-place extension)
- 1 from Plan 01 (3E: `Webhook.Plug @moduledoc documents tolerance: 0 testing-only semantics`)
- 3 new from this plan (3A, 3B, 3D)

## Verification Results

- `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors`: **12 tests, 0 failures**
- Full suite: **2004 tests, 0 failures** (pre-existing warnings in unrelated test files cause `--warnings-as-errors` abort on the full suite; docs_truth_test.exs itself is clean)
- `guides/webhooks-thin-events.md` contains all 16 locked substrings for 3A
- `guides/webhooks.md` contains both `webhooks-thin-events.md` and `thin event`
- `README.md` contains `webhooks-thin-events.md`
- `guides/user-flows-and-jtbd.md` contains `webhooks-thin-events.md` (at 3 locations)

## Cross-Link Graph Verification

All 4 files read by the 3D test contain the expected `webhooks-thin-events.md` references:
- `guides/webhooks-thin-events.md`: contains forward links to `webhooks.md`, `testing.md`, `error-handling.md` in the "See also" section
- `guides/webhooks.md`: contains `webhooks-thin-events.md` reference and `thin event` in the closing "Thin events (`/v2/events`)" section
- `README.md`: contains `webhooks-thin-events.md` in the hardening-ops discovery route
- `guides/user-flows-and-jtbd.md`: contains `webhooks-thin-events.md` at 3 locations (Start Here route, runtime route, Job 7 Read next)

## Commits

- `5f6c390`: `test(48-04): extend ExDoc placement test with 3C thin-events assertions (in-place)` — Task 1
- `0654e27`: `test(48-04): append 3A + 3B + 3D docs-truth regression tests for webhooks-thin-events guide` — Task 2

## Requirements Satisfied

- **GUIDE-03**: "Drift in code samples must fail CI" — satisfied via 3A (16 content locks) + 3B (install-line canary) + 3C (ExDoc placement) + 3D (cross-link graph)
- **VERIFY-03**: "Docs-truth regression suite extended so webhooks-thin-events.md install/handler snippets stay enforceable" — satisfied

## Deviations from Plan

None — plan executed exactly as written.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. This plan adds only test assertions that read existing files via `File.read!`. No new threat surface.

## Self-Check: PASSED

- [x] `test/lattice_stripe/docs_truth_test.exs` modified with 3 new test blocks + 1 in-place extension
- [x] Commits 5f6c390 and 0654e27 exist
- [x] 12 tests pass in docs_truth_test.exs
- [x] No existing test blocks modified beyond 3C in-place extension
