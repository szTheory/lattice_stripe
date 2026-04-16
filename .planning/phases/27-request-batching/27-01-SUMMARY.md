---
phase: 27-request-batching
plan: "01"
subsystem: batch
tags: [batch, concurrency, task-async-stream, tdd, fan-out]
dependency_graph:
  requires: [lib/lattice_stripe/client.ex, lib/lattice_stripe/error.ex]
  provides: [lib/lattice_stripe/batch.ex]
  affects: [mix.exs]
tech_stack:
  added: []
  patterns: [Task.async_stream with on_timeout: :kill_task, try/rescue per task body, MFA tuple dispatch, stream result normalization]
key_files:
  created:
    - lib/lattice_stripe/batch.ex
    - test/lattice_stripe/batch_test.exs
  modified:
    - mix.exs
decisions:
  - "Use stub/3 (not expect/3) in batch tests because N concurrent tasks each call MockTransport — prevents Mox 'unexpected call' errors"
  - "Counter-based slot routing in error isolation test (not URL-based) to cleanly produce one success + one failure across two identical Customer.retrieve calls"
metrics:
  duration_seconds: 100
  completed_date: "2026-04-16"
  tasks_completed: 3
  files_changed: 3
---

# Phase 27 Plan 01: Request Batching — Batch Module Summary

**One-liner:** `LatticeStripe.Batch.run/3` with `Task.async_stream` fan-out, `on_timeout: :kill_task` crash isolation, and `try/rescue` per-task exception wrapping.

## What Was Built

`LatticeStripe.Batch` is a new single-function module that enables developers to execute multiple independent Stripe API calls concurrently. It accepts a list of MFA tuples (`{module, :function, args}`) and dispatches each via `apply(mod, fun, [client | args])`, automatically prepending the client. Results are returned in order with one `{:ok, result} | {:error, %Error{}}` per input.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Write failing test suite for Batch.run/3 | f484707 | test/lattice_stripe/batch_test.exs |
| 2 | Implement Batch.run/3 to pass all tests | 55eb2db | lib/lattice_stripe/batch.ex |
| 3 | Add Batch to ExDoc grouping and run full suite | deb7441 | mix.exs |

## TDD Gate Compliance

- RED gate: `f484707` — `test(27-01): add failing test suite for Batch.run/3` (7 tests, all failing with UndefinedFunctionError)
- GREEN gate: `55eb2db` — `feat(27-01): implement Batch.run/3 with Task.async_stream fan-out` (7 tests, all passing)
- REFACTOR gate: Not needed — credo clean after GREEN

## Key Design Decisions

1. **`on_timeout: :kill_task` is mandatory** — The default `on_timeout: :exit` would kill the calling process on any task timeout. Using `:kill_task` isolates timeouts to individual slots, emitting `{:exit, :timeout}` in the stream.

2. **`timeout: :infinity` on async_stream** — The Client's three-tier timeout cascade (per-request > `operation_timeouts` > `client.timeout`) is the authoritative deadline per D-03. Setting `:infinity` avoids double-timeout conflicts.

3. **`stub/3` over `expect/3` in tests** — `Task.async_stream` spawns N concurrent processes each calling `MockTransport.request/1`. `expect` with exact call counts would require N expects and is fragile under concurrent execution order. `stub` handles unlimited concurrent calls safely.

4. **`:counters` for slot routing in error isolation test** — Two calls to `Customer.retrieve` with different expected outcomes needed a reliable ordering mechanism. An atomic counter (`:counters.new/2`, `:counters.add/4`) ensures the first call returns success and the second returns an error without relying on URL patterns.

## Acceptance Criteria Verification

- `lib/lattice_stripe/batch.ex` contains `defmodule LatticeStripe.Batch` — PASS
- `alias LatticeStripe.{Client, Error}` — PASS
- `@type task :: {module(), atom(), [term()]}` — PASS
- `@type result :: {:ok, term()} | {:error, Error.t()}` — PASS
- `@spec run(Client.t(), [task()], keyword())` — PASS
- `def run(%Client{} = client, tasks, opts \\ []) when is_list(tasks)` — PASS
- `on_timeout: :kill_task` — PASS
- `timeout: :infinity` — PASS
- `ordered: true` — PASS
- `System.schedulers_online()` — PASS
- `apply(mod, fun, [client | args])` — PASS
- `try do` and `rescue` — PASS
- `"Task timed out"` in map_stream_result — PASS
- `"Task exited:"` in map_stream_result — PASS
- `"tasks list cannot be empty"` — PASS
- `"invalid task:"` — PASS
- `@moduledoc` contains `## When to use` — PASS
- `@moduledoc` contains `## What it is NOT` — PASS
- `@moduledoc` contains `## Error isolation` — PASS
- "not a substitute for Stripe" in @moduledoc — PASS
- `mix test test/lattice_stripe/batch_test.exs` — 7 tests, 0 failures — PASS
- `mix credo lib/lattice_stripe/batch.ex --strict` — no issues — PASS
- `LatticeStripe.Batch` in ExDoc `"Client & Configuration"` after `Client`, before `Config` — PASS
- `mix test` full suite — 1706 tests, 0 failures — PASS

## Deviations from Plan

None — plan executed exactly as written. The counter-based slot routing in the error isolation test is an implementation detail within the test's discretionary scope (test organization is listed as "Claude's Discretion" in CONTEXT.md).

## Known Stubs

None — all tests exercise real module logic with MockTransport.

## Threat Surface Scan

`lib/lattice_stripe/batch.ex` introduces `apply(mod, fun, [client | args])` dynamic dispatch. This is within the plan's `<threat_model>` — T-27-01 disposition is `accept` with `valid_mfa?/1` structural guards as the mitigation. No new trust boundary surfaces beyond what the threat model documents.

## Self-Check: PASSED

Files created/exist:
- lib/lattice_stripe/batch.ex — FOUND
- test/lattice_stripe/batch_test.exs — FOUND

Commits exist:
- f484707 — FOUND (test RED)
- 55eb2db — FOUND (feat GREEN)
- deb7441 — FOUND (docs ExDoc)
