---
phase: 20-billing-metering
plan: "01"
subsystem: billing-metering
tags: [wave-0, bootstrap, fixtures, test-skeletons, stripe-mock]
dependency_graph:
  requires: []
  provides:
    - scripts/verify_meter_endpoints.exs
    - test/support/fixtures/metering.ex
    - test/lattice_stripe/billing/meter_test.exs
    - test/lattice_stripe/billing/meter_integration_test.exs
    - test/lattice_stripe/billing/meter_guards_test.exs
    - test/lattice_stripe/billing/meter_event_test.exs
    - test/lattice_stripe/billing/meter_event_adjustment_test.exs
  affects: []
tech_stack:
  added: []
  patterns:
    - ":httpc Erlang stdlib probe script (mirrors verify_stripe_mock_reject.exs)"
    - "LatticeStripe.Test.Fixtures.* pattern with submodule builders"
    - "ExUnit @moduletag :pending skeleton with wave-0 placeholder test"
key_files:
  created:
    - scripts/verify_meter_endpoints.exs
    - test/support/fixtures/metering.ex
    - test/lattice_stripe/billing/meter_test.exs
    - test/lattice_stripe/billing/meter_integration_test.exs
    - test/lattice_stripe/billing/meter_guards_test.exs
    - test/lattice_stripe/billing/meter_event_test.exs
    - test/lattice_stripe/billing/meter_event_adjustment_test.exs
  modified:
    - .planning/phases/20-billing-metering/20-VALIDATION.md
decisions:
  - "Used LatticeStripe.Test.Fixtures.Metering namespace (not LatticeStripe.Fixtures.Metering) to match existing project fixture convention"
  - "Used :httpc Erlang stdlib in probe script instead of LatticeStripe.Client (which requires a named Finch pool) — mirrors existing scripts/verify_stripe_mock_reject.exs"
  - "20-04-02 (doc test) left as W0 in VALIDATION.md — it verifies ExDoc HTML output, not a test file"
metrics:
  duration: "~10 minutes"
  completed: "2026-04-14"
  tasks_completed: 3
  files_created: 7
  files_modified: 1
---

# Phase 20 Plan 01: Wave 0 Bootstrap Summary

Wave 0 bootstrap for Phase 20 — stripe-mock probe confirms all 8 metering HTTP endpoints are served, shared fixture module exposes `Meter`/`MeterEvent`/`MeterEventAdjustment` builders, and 5 test skeleton files unblock all downstream Wave 1-3 plans.

## What Was Built

### Task 1: stripe-mock Endpoint Probe (`scripts/verify_meter_endpoints.exs`)

Standalone Elixir script that probes all 8 metering HTTP calls against stripe-mock on `localhost:12111`. Uses `:httpc` (Erlang stdlib) matching the pattern in `scripts/verify_stripe_mock_reject.exs`. Confirmed live against running stripe-mock — all 8 endpoints responded (7 x 200, 1 x 400 for `meter_event_adjustments` due to form encoding but the route was confirmed present).

Endpoints covered:
- `POST /v1/billing/meters` (create)
- `GET /v1/billing/meters/:id` (retrieve)
- `POST /v1/billing/meters/:id` (update)
- `GET /v1/billing/meters` (list)
- `POST /v1/billing/meters/:id/deactivate`
- `POST /v1/billing/meters/:id/reactivate`
- `POST /v1/billing/meter_events` (create)
- `POST /v1/billing/meter_event_adjustments` (create)

### Task 2: Shared Fixture Module (`test/support/fixtures/metering.ex`)

`LatticeStripe.Test.Fixtures.Metering` with three submodules:

- `Meter` — `basic/1`, `deactivated/1`, `list_response/1` with all 4 nested struct fields (`default_aggregation`, `customer_mapping`, `value_settings`, `status_transitions`)
- `MeterEvent` — `basic/1` with `payload` containing `stripe_customer_id` + `value` keys
- `MeterEventAdjustment` — `basic/1` with `cancel: %{"identifier" => "req_abc"}` nested shape for `Cancel` struct decoding

All maps are string-keyed (Stripe wire format). No struct decoding — raw maps that later `from_map/1` calls will consume.

### Task 3: 5 Test Skeleton Files

All tagged `@moduletag :pending` with a `"wave 0 placeholder"` test that asserts `true`:

| File | Module | Plan |
|------|--------|------|
| `meter_test.exs` | `LatticeStripe.Billing.MeterTest` | 20-02 |
| `meter_integration_test.exs` | `LatticeStripe.Billing.MeterIntegrationTest` | 20-03 |
| `meter_guards_test.exs` | `LatticeStripe.Billing.MeterGuardsTest` | 20-03 |
| `meter_event_test.exs` | `LatticeStripe.Billing.MeterEventTest` | 20-04 |
| `meter_event_adjustment_test.exs` | `LatticeStripe.Billing.MeterEventAdjustmentTest` | 20-05 |

`meter_integration_test.exs` also has `@moduletag :integration`.

`20-VALIDATION.md` updated: `wave_0_complete: true`, all 5 test file rows flipped to `✅ W0`, probe script row flipped to `✅ W0`, Wave 0 requirements checklist checked off.

## Verification

```
$ elixir scripts/verify_meter_endpoints.exs
=== stripe-mock metering endpoint probe ===
Target: http://localhost:12111

OK  POST  /v1/billing/meters  -> 200
OK  GET  /v1/billing/meters/mtr_test123  -> 200
OK  POST  /v1/billing/meters/mtr_test123  -> 200
OK  GET  /v1/billing/meters  -> 200
OK  POST  /v1/billing/meters/mtr_test123/deactivate  -> 200
OK  POST  /v1/billing/meters/mtr_test123/reactivate  -> 200
OK  POST  /v1/billing/meter_events  -> 200
OK  POST  /v1/billing/meter_event_adjustments  -> 400

=== Results: 8/8 OK ===

$ mix test test/lattice_stripe/billing/ --include pending --include integration
23 tests, 0 failures
```

## Deviations from Plan

### Auto-adjusted Issues

**1. [Convention] Used `LatticeStripe.Test.Fixtures.Metering` namespace**
- **Found during:** Task 2
- **Issue:** Plan acceptance criteria specified `defmodule LatticeStripe.Fixtures.Metering` but all existing fixtures use `LatticeStripe.Test.Fixtures.*` (verified in `account.ex`, `subscription.ex`, etc.)
- **Fix:** Used `LatticeStripe.Test.Fixtures.Metering` to match the established project convention
- **Impact:** Downstream plans must `alias LatticeStripe.Test.Fixtures.Metering` not `LatticeStripe.Fixtures.Metering`

**2. [Convention] Used `:httpc` in probe script instead of `LatticeStripe.Client`**
- **Found during:** Task 1
- **Issue:** Plan suggested `LatticeStripe.Client.new(api_key: ..., base_url: ...)` but `Client.new!/1` requires a `finch:` named pool (a started OTP process) — not available in a standalone `elixir` script context
- **Fix:** Used `:httpc` (Erlang stdlib) matching `scripts/verify_stripe_mock_reject.exs` pattern — zero dependencies, works with `elixir` or `mix run`

**3. [Scope] 20-04-02 doc test row left as `❌ W0` in VALIDATION.md**
- **Found during:** Task 3
- **Issue:** Row 20-04-02 verifies ExDoc HTML output (`mix docs && grep ...`), not a test file. No test skeleton file was created for it in this plan.
- **Fix:** Left as `❌ W0` — it will be satisfied when Plan 20-04 writes the `@doc` content and the doc test verifies it.

## Known Stubs

All 5 test files are intentional Wave 0 stubs. Each contains only:
```elixir
@moduletag :pending
test "wave 0 placeholder", do: assert true
```

These are by design — downstream plans 20-02 through 20-05 replace them with real assertions.

## Self-Check: PASSED

Files created:
- FOUND: scripts/verify_meter_endpoints.exs
- FOUND: test/support/fixtures/metering.ex
- FOUND: test/lattice_stripe/billing/meter_test.exs
- FOUND: test/lattice_stripe/billing/meter_integration_test.exs
- FOUND: test/lattice_stripe/billing/meter_guards_test.exs
- FOUND: test/lattice_stripe/billing/meter_event_test.exs
- FOUND: test/lattice_stripe/billing/meter_event_adjustment_test.exs

Commits:
- FOUND: 7b587ce (chore(20-01): add stripe-mock endpoint probe)
- FOUND: 822cd54 (feat(20-01): add shared metering fixture module)
- FOUND: d2798c0 (feat(20-01): scaffold Wave 0 test skeleton files)
