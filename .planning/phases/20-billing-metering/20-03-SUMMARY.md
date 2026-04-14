---
phase: 20-billing-metering
plan: "03"
subsystem: billing-metering
tags: [wave-2, meter-resource, guard, tdd, integration]
dependency_graph:
  requires:
    - 20-02 (4 nested Meter.* structs)
  provides:
    - lib/lattice_stripe/billing/meter.ex
    - lib/lattice_stripe/billing/guards.ex (check_meter_value_settings! appended)
    - test/lattice_stripe/billing/meter_guards_test.exs
    - test/lattice_stripe/billing/meter_integration_test.exs
  affects:
    - 20-04 (MeterEvent.create/3 follows same resource pattern)
tech_stack:
  added: []
  patterns:
    - "Resource module: %Request{} |> then(&Client.request/2) |> Resource.unwrap_singular/2"
    - "Lifecycle verb POSTs sub-path: /v1/billing/meters/:id/deactivate (mirrors Payout.cancel)"
    - "status_atom/1 with @known_statuses ~w(...) (mirrors Account.Capability pattern)"
    - "Pre-flight guard: :ok = Billing.Guards.check_meter_value_settings!(params) after require_param!"
    - "TDD: RED (failing tests) → GREEN (implementation) → commit per task"
key_files:
  created:
    - lib/lattice_stripe/billing/meter.ex
  modified:
    - lib/lattice_stripe/billing/guards.ex
    - test/lattice_stripe/billing/meter_test.exs
    - test/lattice_stripe/billing/meter_guards_test.exs
    - test/lattice_stripe/billing/meter_integration_test.exs
decisions:
  - "Used %Request{} |> then(&Client.request/2) pattern (not Resource.request/6 which doesn't exist)"
  - "Alias ordering fixed to satisfy mix credo --strict alphabetical requirement"
  - "Integration test uses setup_all :gen_tcp probe matching CustomerIntegrationTest pattern"
  - "list/3 response accessed via resp.data.data (Response wraps List wraps items)"
metrics:
  duration: "~20 minutes"
  completed: "2026-04-14"
  tasks_completed: 3
  files_created: 1
  files_modified: 4
---

# Phase 20 Plan 03: Billing.Meter Resource + Guards Summary

Full `LatticeStripe.Billing.Meter` resource module (CRUDL + `deactivate`/`reactivate` lifecycle verbs + bang variants), `Billing.Guards.check_meter_value_settings!/1` guard with 8-case matrix blocking T-20-01 silent-zero trap, and stripe-mock integration lifecycle test covering all 6 verbs.

## What Was Built

### Task 1: `Billing.Guards.check_meter_value_settings!/1` (GUARD-01)

Extended `lib/lattice_stripe/billing/guards.ex` (preserving `check_proration_required/2`) with:

- Hard `ArgumentError` when `default_aggregation.formula` is `"sum"` or `"last"` AND `value_settings` is present-but-malformed (`event_payload_key` missing, nil, or empty string). Blocks T-20-01 silent-zero trap — Stripe would accept this shape and silently drop every event's value contribution.
- `Logger.warning/1` when `formula == "count"` and `value_settings` is passed — Stripe silently ignores value_settings for count meters.
- Silent pass when `value_settings` omitted entirely — Stripe defaults `event_payload_key` to `"value"` (legal shape).
- String-keys-only: atom-keyed params bypass the guard (D-01 decision).

8-case test matrix in `test/lattice_stripe/billing/meter_guards_test.exs`:

| Case | Input | Result |
|------|-------|--------|
| 1 | sum + no value_settings | :ok |
| 2 | sum + valid value_settings | :ok |
| 3 | sum + empty map value_settings | ArgumentError |
| 4 | sum + empty string event_payload_key | ArgumentError |
| 5 | last + nil event_payload_key | ArgumentError |
| 6 | count + value_settings | Logger.warning + :ok |
| 7 | count + no value_settings | :ok silent |
| 8 | atom-keyed params | :ok silent (bypass) |

### Task 2: `LatticeStripe.Billing.Meter` Resource Module

`lib/lattice_stripe/billing/meter.ex` — 259 lines, credo clean:

**Exports:**
- `create/3`, `create!/3` — require_param! for display_name/event_name/default_aggregation, then guard, then POST /v1/billing/meters
- `retrieve/3`, `retrieve!/3` — GET /v1/billing/meters/:id
- `update/4`, `update!/4` — POST /v1/billing/meters/:id
- `list/3`, `list!/3` — GET /v1/billing/meters (paginated)
- `stream!/3` — lazy auto-paginating Stream via List.stream!/2
- `deactivate/3`, `deactivate!/3` — POST /v1/billing/meters/:id/deactivate
- `reactivate/3`, `reactivate!/3` — POST /v1/billing/meters/:id/reactivate
- `from_map/1` — decodes string-keyed Stripe map with all 4 nested structs + :extra
- `status_atom/1` — :active | :inactive | :unknown (mirrors Capability pattern)

**Unit tests added to `meter_test.exs`** (23 new tests, total 36 with nested struct tests):
- `describe "Meter.from_map/1"` — full round-trip from fixture, extra capture
- `describe "Meter.status_atom/1"` — all 5 cases (active/inactive/nil/empty/unknown)
- `describe "Meter.create/3 require_param!"` — 3 ArgumentError cases
- `describe "Meter.create/3 guard integration"` — guard fires before network
- `describe "Meter.create/3"` — happy path via MockTransport
- `describe "Meter.retrieve/3"` — GET path assertion
- `describe "Meter.deactivate/3"` — sub-path POST assertion
- `describe "Meter.reactivate/3"` — sub-path POST assertion

### Task 3: Integration Lifecycle Test (TEST-05)

`test/lattice_stripe/billing/meter_integration_test.exs` replaced Wave 0 skeleton:

- `@moduletag :integration`
- `setup_all` uses `:gen_tcp` probe for stripe-mock connectivity (matching `CustomerIntegrationTest` pattern)
- Single lifecycle test: create → retrieve → update → list → deactivate → reactivate
- All 6 verbs called exactly once; list accessed via `resp.data.data`
- No state transition assertions (stripe-mock is stateless — documented in test)

## Verification

```
$ mix compile --warnings-as-errors
Generated lattice_stripe app

$ mix test test/lattice_stripe/billing/meter_guards_test.exs
8 tests, 0 failures

$ mix test test/lattice_stripe/billing/meter_test.exs
36 tests, 0 failures (includes 13 nested struct tests from Plan 20-02)

$ mix test test/lattice_stripe/billing/meter_integration_test.exs --include integration
1 test, 0 failures

$ mix credo --strict lib/lattice_stripe/billing/meter.ex
18 mods/funs, found no issues.
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `Resource.request/6` does not exist**
- **Found during:** Task 2, GREEN phase
- **Issue:** Plan acceptance criteria referenced `Resource.request(client, method, path, body, opts, __MODULE__)` but this function does not exist in `LatticeStripe.Resource`. The actual codebase pattern (Payout, Account, Customer) uses `%Request{} |> then(&Client.request(client, &1))`
- **Fix:** Rewrote all 6 HTTP calls to use `%Request{method: ..., path: ..., params: ..., opts: ...} |> then(&Client.request(client, &1))`
- **Files modified:** `lib/lattice_stripe/billing/meter.ex`
- **Commit:** 6f50685

**2. [Rule 1 - Bug] Credo alias ordering violation**
- **Found during:** Task 2, credo verification
- **Issue:** `alias LatticeStripe.{Client, Resource}` before `alias LatticeStripe.Billing` violated alphabetical ordering rule; `DefaultAggregation` was not first in its group
- **Fix:** Reordered to `alias LatticeStripe.Billing`, then `alias LatticeStripe.Billing.Meter.{CustomerMapping, DefaultAggregation, StatusTransitions, ValueSettings}`, then `alias LatticeStripe.{Client, Request, Resource}`
- **Files modified:** `lib/lattice_stripe/billing/meter.ex`
- **Commit:** 6f50685

## Known Stubs

None. All modules are complete implementations.

## Threat Flags

No new trust boundaries introduced beyond what is in the plan's threat model:

| T-20-01 silent-zero | MITIGATED | `check_meter_value_settings!/1` raises `ArgumentError` with "value_settings.event_payload_key" substring; 8-case matrix confirms all paths blocked |
| T-20-meter-01 | ACCEPTED | `%Meter{}` Inspect not masked — meter config (formulas, payload keys) is non-sensitive per D-02/D-03 |
| T-20-meter-02 | ACCEPTED | `stream!/3` unbounded by design; caller controls iteration per Customer.stream! precedent |

## Self-Check: PASSED

Files created/modified:
- FOUND: lib/lattice_stripe/billing/meter.ex
- FOUND: lib/lattice_stripe/billing/guards.ex
- FOUND: test/lattice_stripe/billing/meter_guards_test.exs
- FOUND: test/lattice_stripe/billing/meter_integration_test.exs
- FOUND: .planning/phases/20-billing-metering/20-03-SUMMARY.md

Commits:
- FOUND: 3652fa7 (feat(20-03): add check_meter_value_settings!/1 guard + 8-case test matrix)
- FOUND: 6f50685 (feat(20-03): implement Billing.Meter resource module with CRUDL + lifecycle verbs)
- FOUND: 2412cea (test(20-03): add Meter lifecycle integration test against stripe-mock)
