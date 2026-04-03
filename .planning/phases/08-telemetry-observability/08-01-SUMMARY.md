---
phase: 08-telemetry-observability
plan: "01"
subsystem: telemetry
tags: [telemetry, observability, refactor, elixir]

dependency_graph:
  requires: []
  provides:
    - LatticeStripe.Telemetry module (request_span/4, emit_retry/5, attach_default_logger/1, webhook_verify_span/2)
    - Enriched telemetry metadata (resource, operation, api_version, stripe_account)
    - Full event catalog @moduledoc with Telemetry.Metrics examples
  affects:
    - lib/lattice_stripe/client.ex (calls Telemetry module instead of inline code)

tech_stack:
  added: []
  patterns:
    - Centralized telemetry module pattern (mirrors Finch.Telemetry)
    - :telemetry.span/3 for request and webhook spans
    - URL path parsing for resource/operation derivation

key_files:
  created:
    - lib/lattice_stripe/telemetry.ex
  modified:
    - lib/lattice_stripe/client.ex

decisions:
  - Removed @doc string before @doc false (Elixir treats second @doc as override, causing warnings)
  - parse_resource_and_operation/2 uses helper functions not guard clauses (guards require macros)
  - Unused @webhook_verify_event and @default_logger_id referenced in attach_default_logger/1 stub to avoid warnings
  - id_segment?/1 function checks Stripe object ID prefixes AND long alphanumeric strings for robust ID detection

metrics:
  duration: "4 minutes"
  completed_date: "2026-04-03"
  tasks_completed: 2
  files_modified: 2
---

# Phase 08 Plan 01: Telemetry Module and Client Refactor Summary

Centralized telemetry into `LatticeStripe.Telemetry` and refactored `Client` to delegate all telemetry logic to it — enriching event metadata with resource, operation, api_version, and stripe_account.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create LatticeStripe.Telemetry module | c8e514e | lib/lattice_stripe/telemetry.ex (created) |
| 2 | Refactor Client to delegate telemetry | 5992809 | lib/lattice_stripe/client.ex |

## What Was Built

### Task 1: LatticeStripe.Telemetry Module

Created `lib/lattice_stripe/telemetry.ex` with:

- **`@moduledoc` event catalog** — full documentation for all 7 telemetry events with measurements, metadata fields, types, and copy-paste `Telemetry.Metrics` examples for Prometheus/StatsD integration
- **`request_span/4`** — wraps HTTP requests in `:telemetry.span/3` with enriched start metadata (resource, operation, api_version, stripe_account) and merged stop metadata
- **`emit_retry/5`** — emits `[:lattice_stripe, :request, :retry]` events with attempt count and delay
- **`build_start_metadata/2`** — enriches events with resource/operation parsed from URL path
- **`build_stop_metadata/4`** — three-clause pattern match for ok/connection_error/api_error, merging all start metadata into stop event (prevents stop event from losing context)
- **`parse_resource_and_operation/2`** — parses Stripe API paths to extract resource ("customer", "payment_intent", "checkout.session") and operation ("create", "retrieve", "list", "confirm", etc.)
- **`extract_path/1`** — extracts path component from full URLs
- **Stubs** for `attach_default_logger/1` and `webhook_verify_span/2` (Plan 02 implementation)

### Task 2: Client Refactor

Removed 77 lines of inline telemetry from `lib/lattice_stripe/client.ex`:

- Replaced `if client.telemetry_enabled do :telemetry.span(...)` block with `LatticeStripe.Telemetry.request_span/4`
- Replaced `emit_retry_telemetry/6` call with `LatticeStripe.Telemetry.emit_retry/5`
- Deleted private functions: `emit_retry_telemetry/6`, `extract_path/1`, `telemetry_stop_metadata/3` (all three clauses)

## Verification

- `mix compile --warnings-as-errors` exits 0
- `mix test test/lattice_stripe/client_test.exs` — 58 tests, 0 failures
- `mix test` — 505 tests, 0 failures (full suite, refactor is behavior-preserving)
- `grep -c "telemetry" lib/lattice_stripe/client.ex` — 5 references (down from ~25+)
- All 4 public functions present in Telemetry module: `request_span`, `emit_retry`, `attach_default_logger`, `webhook_verify_span`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed @doc override warning**
- **Found during:** Task 1 compilation
- **Issue:** Setting `@doc """..."""` immediately before `@doc false` causes Elixir to warn "redefining @doc attribute" because the second `@doc` overwrites the first
- **Fix:** Removed the `@doc """..."""` blocks for `request_span/4` and `emit_retry/5`, kept explanatory code comments instead
- **Files modified:** lib/lattice_stripe/telemetry.ex

**2. [Rule 1 - Bug] Fixed is_id/1 guard usage**
- **Found during:** Task 1 compilation
- **Issue:** Plan specified using `is_id/1` in guards, but Elixir guards only support macros — regular functions cannot be used in `when` clauses
- **Fix:** Refactored `parse_resource_and_operation/2` into four helper functions (`parse_segments/3`, `parse_two_segments/3`, `parse_three_segments/4`) using `cond/if` instead of guard clauses; renamed helper to `id_segment?/1`
- **Files modified:** lib/lattice_stripe/telemetry.ex

**3. [Rule 2 - Missing functionality] Referenced stub module attributes**
- **Found during:** Task 1 compilation
- **Issue:** `@webhook_verify_event` and `@default_logger_id` are module attributes needed in Plan 02 but unused in Plan 01 stubs — Elixir warns on unused module attributes with `--warnings-as-errors`
- **Fix:** Added `_ = @default_logger_id` and `_ = @webhook_verify_event` in `attach_default_logger/1` stub with explanatory comment
- **Files modified:** lib/lattice_stripe/telemetry.ex

## Known Stubs

| Stub | File | Reason |
|------|------|--------|
| `attach_default_logger/1` returns `:ok` | lib/lattice_stripe/telemetry.ex:347 | Full implementation (Logger handler attachment) deferred to Plan 02 |
| `webhook_verify_span/2` calls `fun.()` directly | lib/lattice_stripe/telemetry.ex:361 | Webhook telemetry span deferred to Plan 02 |

These stubs do not affect Plan 01's goal (request telemetry centralization). Plan 02 will complete both.

## Self-Check: PASSED

Files exist:
- lib/lattice_stripe/telemetry.ex — FOUND
- lib/lattice_stripe/client.ex — FOUND (modified)

Commits exist:
- c8e514e — FOUND (feat(08-01): create LatticeStripe.Telemetry module)
- 5992809 — FOUND (refactor(08-01): delegate Client telemetry to LatticeStripe.Telemetry module)
