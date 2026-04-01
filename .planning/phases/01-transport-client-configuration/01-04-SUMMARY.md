---
phase: 01-transport-client-configuration
plan: "04"
subsystem: config-and-finch-transport
tags: [config, nimble-options, finch, transport, validation]
dependency_graph:
  requires: ["01-02", "01-03"]
  provides: ["config-validation", "finch-transport"]
  affects: ["01-05"]
tech_stack:
  added: []
  patterns: ["NimbleOptions schema validation", "Transport behaviour implementation", "TDD red-green"]
key_files:
  created:
    - lib/lattice_stripe/config.ex
    - lib/lattice_stripe/transport/finch.ex
    - test/lattice_stripe/config_test.exs
    - test/lattice_stripe/transport/finch_test.exs
  modified: []
decisions:
  - "NimbleOptions.new! at module level compiles the schema once at load time for efficient runtime validation"
  - "Finch transport tests avoid starting a real Finch pool — structural and error-path tests only; integration via stripe-mock in Phase 9"
  - "stripe_account uses {:or, [:string, nil]} NimbleOptions type to accept both string and nil values"
metrics:
  duration_seconds: 119
  completed_date: "2026-04-01"
  tasks_completed: 2
  files_created: 4
  files_modified: 0
---

# Phase 01 Plan 04: NimbleOptions Config Validation and Finch Transport Adapter Summary

NimbleOptions-validated client configuration with clear error messages and a Finch adapter that implements the Transport behaviour contract via Finch.build/request calls.

## What Was Built

### Task 1: NimbleOptions Config Schema and Validation

`lib/lattice_stripe/config.ex` provides a NimbleOptions schema compiled at module load time. The schema validates all client configuration at creation time, catching misconfiguration before any HTTP requests are made.

**Schema fields:**
- `api_key` (required, string) — Stripe API key
- `finch` (required, atom) — Finch pool name from the user's supervision tree
- `base_url` (default: `"https://api.stripe.com"`) — override for stripe-mock testing
- `api_version` (default: `"2025-12-18.acacia"`) — pinned Stripe API version
- `transport` (default: `LatticeStripe.Transport.Finch`)
- `json_codec` (default: `LatticeStripe.Json.Jason`)
- `timeout` (default: `30_000`) — milliseconds
- `max_retries` (default: `0`)
- `stripe_account` (default: `nil`) — Connect platform support
- `telemetry_enabled` (default: `true`)

Both `validate/1` (ok/error tuple) and `validate!/1` (raises on failure) are provided. 11 tests cover required field validation, type checking, defaults, and overrides.

### Task 2: Finch Transport Adapter

`lib/lattice_stripe/transport/finch.ex` implements `@behaviour LatticeStripe.Transport` via a single `request/1` callback. The adapter translates the plain map contract into `Finch.build/5` + `Finch.request/3` calls and normalizes the `Finch.Response` struct back into the expected response map format.

Key behaviors:
- `Keyword.fetch!(opts, :finch)` — raises `KeyError` if pool name missing
- `Keyword.get(opts, :timeout, 30_000)` — timeout passed as `receive_timeout`
- Returns `{:ok, %{status, headers, body}}` on success
- Returns `{:error, exception}` on Finch error

3 tests verify behaviour declaration, function export, and the missing `:finch` error path.

## Verification

All verification passes:
- `mix test test/lattice_stripe/config_test.exs test/lattice_stripe/transport/finch_test.exs` — 14 tests, 0 failures
- `mix compile --warnings-as-errors` — exits 0
- `mix format --check-formatted` — exits 0

## Decisions Made

1. **NimbleOptions.new! at module level** — Schema compiled once at load time rather than per-call, following the NimbleOptions idiomatic pattern for efficiency.

2. **Finch tests avoid real pool** — Unit tests verify module structure and error paths only. Full integration testing with a live Finch pool and stripe-mock is deferred to Phase 9. This keeps unit tests fast and dependency-free.

3. **stripe_account type `{:or, [:string, nil]}`** — NimbleOptions union type allows both string values (for Connect platforms) and nil (default, no Connect header).

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None - all fields are functional with real defaults and validation.

## Self-Check

### Files Exist
- lib/lattice_stripe/config.ex: FOUND
- lib/lattice_stripe/transport/finch.ex: FOUND
- test/lattice_stripe/config_test.exs: FOUND
- test/lattice_stripe/transport/finch_test.exs: FOUND

### Commits Exist
- Task 1: 9441d19
- Task 2: b0951e3
