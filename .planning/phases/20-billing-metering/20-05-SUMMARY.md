---
phase: 20-billing-metering
plan: "05"
subsystem: billing-metering
tags: [wave-4, meter-event-adjustment, cancel-struct, shape-guard, tdd, event-04]
dependency_graph:
  requires:
    - 20-02 (Billing.Guards module pattern)
    - 20-04 (MeterEvent create-only pattern)
  provides:
    - lib/lattice_stripe/billing/meter_event_adjustment.ex
    - lib/lattice_stripe/billing/meter_event_adjustment/cancel.ex
  affects:
    - 20-06 (metering guide references MeterEventAdjustment.create/3 and cancel shape)
tech_stack:
  added: []
  patterns:
    - "Minimal nested struct (no :extra) for single-field Stripe sub-objects"
    - "Pre-flight shape guard pattern: check_adjustment_cancel_shape!/1 with 3 clauses"
    - "Create-only resource: %Request{method: :post} |> then(&Client.request/2) |> Resource.unwrap_singular/2"
    - "~s[] sigil for error message strings with embedded double-quotes (credo compliance)"
key_files:
  created:
    - lib/lattice_stripe/billing/meter_event_adjustment.ex
    - lib/lattice_stripe/billing/meter_event_adjustment/cancel.ex
  modified:
    - lib/lattice_stripe/billing/guards.ex
    - test/lattice_stripe/billing/meter_event_adjustment_test.exs
decisions:
  - "Used %Request{} |> then(&Client.request/2) pattern (Resource.request/6 does not exist — same deviation as 20-03/20-04)"
  - "Used %Client{api_key:, finch:} struct directly in param-validation tests (Client.new/1 requires :finch and returns {:error,...} when missing)"
  - "Used ~s[] sigil for error messages with embedded double-quotes to satisfy credo readability check"
  - "Cancel struct has no :extra field — single-field sub-objects use minimal struct (no unknown-field capture needed)"
  - "Alias order in test file: Guards before MeterEventAdjustment (alphabetical, credo clean)"
metrics:
  duration: "~10 minutes"
  completed: "2026-04-14"
  tasks_completed: 1
  files_created: 2
  files_modified: 2
---

# Phase 20 Plan 05: MeterEventAdjustment with Cancel Struct and Shape Guard Summary

`%MeterEventAdjustment.Cancel{identifier: ...}` typed struct anchors the exact `cancel.identifier` Stripe wire shape (EVENT-04 / T-20-03), with a 3-clause pre-flight guard blocking 4 known wrong shapes before any network call.

## What Was Built

### `LatticeStripe.Billing.MeterEventAdjustment.Cancel`

`lib/lattice_stripe/billing/meter_event_adjustment/cancel.ex` — minimal struct, single field:

- `defstruct [:identifier]` — no `:extra` (minimal per plan spec)
- `from_map/1` — decodes `%{"identifier" => id}` into `%Cancel{identifier: id}`; `from_map(nil)` returns `nil`

### `LatticeStripe.Billing.MeterEventAdjustment`

`lib/lattice_stripe/billing/meter_event_adjustment.ex` — create-only resource:

**Exports:** `create/3`, `create!/3`, `from_map/1`

**Struct fields (7):** `id`, `object`, `event_name`, `status`, `cancel`, `livemode`, `extra`

**`create/3`:**
1. `require_param!` for `event_name`
2. `require_param!` for `cancel`
3. `Guards.check_adjustment_cancel_shape!/1` shape guard
4. `%Request{method: :post, path: "/v1/billing/meter_event_adjustments"}` → `Client.request/2` → `Resource.unwrap_singular/2`

**`from_map/1`:** decodes `cancel` sub-object via `Cancel.from_map(map["cancel"])` — typed struct, never raw map.

### `Billing.Guards.check_adjustment_cancel_shape!/1`

3-clause guard appended to `lib/lattice_stripe/billing/guards.ex`:

| Clause | Pattern | Result |
|--------|---------|--------|
| 1 | `%{"cancel" => %{"identifier" => id}}` where `is_binary(id) and byte_size(id) > 0` | `:ok` |
| 2 | `%{"cancel" => cancel}` (wrong shape) | `ArgumentError` mentioning `identifier` |
| 3 | `params` (missing cancel entirely) | `ArgumentError` mentioning `cancel` |

Prior guards `check_proration_required` and `check_meter_value_settings!` preserved untouched.

### Test suite (10 tests)

`test/lattice_stripe/billing/meter_event_adjustment_test.exs` replaced Wave 0 skeleton:

| describe | Tests | Coverage |
|---------|-------|----------|
| from_map/1 round-trip (EVENT-04 / T-20-03) | 4 | nested Cancel struct; Cancel.from_map round-trip; nil; no :extra |
| create/3 cancel shape guard (GUARD-03) | 4 | missing cancel; top-level identifier (T-20-03 trap); cancel.id; cancel.event_id |
| Guards.check_adjustment_cancel_shape!/1 | 2 | accepts correct shape; rejects empty identifier |

## Verification

```
$ mix test test/lattice_stripe/billing/meter_event_adjustment_test.exs
10 tests, 0 failures

$ mix test test/lattice_stripe/billing/meter_guards_test.exs
8 tests, 0 failures

$ mix compile --warnings-as-errors
Generated lattice_stripe app

$ mix credo --strict lib/lattice_stripe/billing/guards.ex lib/lattice_stripe/billing/meter_event_adjustment.ex lib/lattice_stripe/billing/meter_event_adjustment/cancel.ex
22 mods/funs, found no issues.

$ grep -q "Cancel.from_map" lib/lattice_stripe/billing/meter_event_adjustment.ex
(exits 0)
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `Resource.request/6` does not exist**
- **Found during:** Task 1, implementation
- **Issue:** Plan's action spec uses `Resource.request(client, :post, "/v1/billing/meter_event_adjustments", params, opts, __MODULE__)` but this function does not exist (same as Plans 20-03 and 20-04)
- **Fix:** Used `%Request{method: :post, path: "/v1/billing/meter_event_adjustments", params: params, opts: opts} |> then(&Client.request(client, &1))`
- **Files modified:** `lib/lattice_stripe/billing/meter_event_adjustment.ex`
- **Commit:** d036d37

**2. [Rule 1 - Bug] `Client.new/1` returns `{:error, ...}` not `%Client{}`**
- **Found during:** Task 1, test implementation (known pattern from 20-04)
- **Issue:** Plan test snippet uses `LatticeStripe.Client.new(api_key: "sk_test_xxx")` but `Client.new/1` requires `:finch` and returns `{:error, NimbleOptions.ValidationError{}}` — would cause `FunctionClauseError` instead of `ArgumentError`
- **Fix:** Used `%LatticeStripe.Client{api_key: "sk_test_xxx", finch: :test_finch}` struct directly
- **Files modified:** `test/lattice_stripe/billing/meter_event_adjustment_test.exs`
- **Commit:** d036d37

**3. [Rule 2 - Readability] Credo `~s[]` sigil for error messages**
- **Found during:** Task 1, credo check
- **Issue:** Error message strings in `check_adjustment_cancel_shape!/1` contained more than 3 embedded double-quotes; credo `--strict` flagged both clauses
- **Fix:** Converted affected string literals to `~s[]` sigils; remaining interpolation strings left as normal strings
- **Files modified:** `lib/lattice_stripe/billing/guards.ex`
- **Commit:** d036d37

**4. [Rule 2 - Readability] Credo alias ordering in test file**
- **Found during:** Task 1, credo check
- **Issue:** Plan spec ordered aliases as `MeterEventAdjustment`, `MeterEventAdjustment.Cancel`, `Guards` — but credo requires alphabetical; `Guards` must come before `MeterEventAdjustment`
- **Fix:** Reordered aliases to `Guards`, `MeterEventAdjustment`, `MeterEventAdjustment.Cancel`, `Metering`
- **Files modified:** `test/lattice_stripe/billing/meter_event_adjustment_test.exs`
- **Commit:** d036d37

## Known Stubs

None. Module is a complete implementation.

## Threat Flags

No new trust boundaries beyond the plan's threat model. Both threats mitigated:

| Threat | Disposition | Evidence |
|--------|-------------|----------|
| T-20-03 cancel-shape | MITIGATED | `Guards.check_adjustment_cancel_shape!/1` 3-clause guard; 4 regression tests cover top-level, cancel.id, cancel.event_id, and missing cancel |
| T-20-mea-01 repudiation | MITIGATED | `from_map/1` round-trip test pattern-matches on `%Cancel{identifier: "req_abc"}` — typed struct anchor prevents future flattening refactors |

## Self-Check: PASSED

Files created/modified:
- FOUND: lib/lattice_stripe/billing/meter_event_adjustment.ex
- FOUND: lib/lattice_stripe/billing/meter_event_adjustment/cancel.ex
- FOUND: lib/lattice_stripe/billing/guards.ex (modified)
- FOUND: test/lattice_stripe/billing/meter_event_adjustment_test.exs (modified)

Commits:
- FOUND: d036d37 (feat(20-05): implement MeterEventAdjustment with Cancel nested struct and shape guard)
