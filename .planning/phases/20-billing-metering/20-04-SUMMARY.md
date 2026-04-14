---
phase: 20-billing-metering
plan: "04"
subsystem: billing-metering
tags: [wave-3, meter-event, inspect-masking, tdd, async-ack]
dependency_graph:
  requires:
    - 20-03 (Billing.Meter resource + %Request{} pattern)
  provides:
    - lib/lattice_stripe/billing/meter_event.ex
    - test/lattice_stripe/billing/meter_event_test.exs
  affects:
    - 20-05 (MeterEventAdjustment follows same create-only pattern)
    - 20-06 (metering guide references MeterEvent.create/3 async-ack contract)
tech_stack:
  added: []
  patterns:
    - "Create-only resource: %Request{method: :post} |> then(&Client.request/2) |> Resource.unwrap_singular/2"
    - "defimpl Inspect allowlist pattern (mirrors Customer/Checkout.Session) — :payload excluded"
    - "Minimal struct (no :extra field) per EVENT-05"
    - "Code.fetch_docs/1 assertion to verify @doc content in tests"
    - "Bare %Client{api_key:, finch:} struct in param-validation tests (raises before transport)"
key_files:
  created:
    - lib/lattice_stripe/billing/meter_event.ex
  modified:
    - test/lattice_stripe/billing/meter_event_test.exs
decisions:
  - "Used %Request{} |> then(&Client.request/2) pattern (not Resource.request/6 which doesn't exist) — consistent with Plan 20-03 deviation"
  - "Test param validation with %Client{api_key:, finch:} struct (not Client.new/1 which returns {:error,...} for missing :finch)"
  - "Fixed @doc text: 'accepted for processing' (not 'accepted the event for processing') to satisfy exact substring test"
  - "Fixed fixture alias: LatticeStripe.Test.Fixtures.Metering (not LatticeStripe.Fixtures.Metering as written in plan)"
metrics:
  duration: "~15 minutes"
  completed: "2026-04-14"
  tasks_completed: 1
  files_created: 1
  files_modified: 1
---

# Phase 20 Plan 04: Billing.MeterEvent Resource Summary

Create-only `LatticeStripe.Billing.MeterEvent` resource with `defimpl Inspect` payload masking (T-20-04), async-ack `@doc` explainer (T-20-02), and 9 unit tests covering from_map round-trip, struct shape, param validation, Inspect masking, and Code.fetch_docs @doc assertion.

## What Was Built

### `LatticeStripe.Billing.MeterEvent` module

`lib/lattice_stripe/billing/meter_event.ex` — 118 lines, credo clean:

**Exports:**
- `create/3`, `create!/3` — require_param! for event_name + payload, then POST /v1/billing/meter_events
- `from_map/1` — decodes string-keyed Stripe map into 6-field minimal struct (no `:extra`)

**Struct fields (6, exactly):** `event_name`, `identifier`, `payload`, `timestamp`, `created`, `livemode`

**`defimpl Inspect`** — allowlist renders `#LatticeStripe.Billing.MeterEvent<event_name:, identifier:, timestamp:, created:, livemode:>`, omitting `:payload` entirely (T-20-04 mitigation).

**`@doc create/3`** covers:
- "accepted for processing" async-ack phrase (T-20-02 mitigation)
- `v1.billing.meter.error_report_triggered` webhook reference
- Two-layer idempotency: body `identifier` (24h business dedup) vs `idempotency_key:` opt (HTTP header transport dedup)
- 35-day backdating window + 24-hour dedup window

### Test suite (9 tests)

`test/lattice_stripe/billing/meter_event_test.exs` replaced Wave 0 skeleton:

| describe | Tests | Coverage |
|---------|-------|----------|
| from_map/1 | 2 | round-trip all 6 fields; no :extra field |
| create/3 param validation | 2 | ArgumentError on missing event_name; ArgumentError on missing payload |
| Inspect masking | 4 | prefix format; refute payload values leak; allowlist fields present; escape hatch via struct field access |
| @doc async-ack | 1 | Code.fetch_docs asserts "accepted for processing" + webhook ref + both idempotency keys |

## Verification

```
$ mix test test/lattice_stripe/billing/meter_event_test.exs
9 tests, 0 failures

$ mix compile --warnings-as-errors
Generated lattice_stripe app

$ mix credo --strict lib/lattice_stripe/billing/meter_event.ex
5 mods/funs, found no issues.
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `Resource.request/6` does not exist**
- **Found during:** Task 1, GREEN phase
- **Issue:** Plan acceptance criteria sketch used `Resource.request(client, :post, ...)` pattern but this function does not exist (same issue as Plan 20-03). The actual codebase pattern is `%Request{} |> then(&Client.request(client, &1))`
- **Fix:** Used `%Request{method: :post, path: "/v1/billing/meter_events", params: params, opts: opts} |> then(&Client.request(client, &1))`
- **Files modified:** `lib/lattice_stripe/billing/meter_event.ex`
- **Commit:** ed99b36

**2. [Rule 1 - Bug] Wrong fixture module alias in plan test code**
- **Found during:** Task 1, test implementation
- **Issue:** Plan's test snippet used `alias LatticeStripe.Fixtures.Metering` but the actual module is `LatticeStripe.Test.Fixtures.Metering` (as confirmed by `test/lattice_stripe/billing/meter_test.exs`)
- **Fix:** Used correct alias `LatticeStripe.Test.Fixtures.Metering`
- **Files modified:** `test/lattice_stripe/billing/meter_event_test.exs`
- **Commit:** ed99b36

**3. [Rule 1 - Bug] `Client.new/1` returns `{:error, ...}` not `%Client{}`**
- **Found during:** Task 1, test run (RED→GREEN)
- **Issue:** Plan's test code used `LatticeStripe.Client.new(api_key: "sk_test")` for param validation tests, but `Client.new/1` requires `:finch` and returns `{:error, NimbleOptions.ValidationError{}}` when missing — causing `FunctionClauseError` instead of `ArgumentError`
- **Fix:** Used `%LatticeStripe.Client{api_key: "sk_test", finch: :test_finch}` struct directly (satisfies `@enforce_keys`; `require_param!` raises before any transport call)
- **Files modified:** `test/lattice_stripe/billing/meter_event_test.exs`
- **Commit:** ed99b36

**4. [Rule 1 - Bug] @doc text "accepted the event for processing" failed exact substring test**
- **Found during:** Task 1, test run (GREEN phase)
- **Issue:** Initial @doc had "accepted the event for processing" but test asserts `=~ "accepted for processing"` — the substring doesn't match because "the event" intervenes
- **Fix:** Changed to "accepted for processing" (direct phrase, matches test assertion and plan requirement)
- **Files modified:** `lib/lattice_stripe/billing/meter_event.ex`
- **Commit:** ed99b36

## Known Stubs

None. Module is a complete implementation.

## Threat Flags

No new trust boundaries beyond the plan's threat model. All three threats mitigated:

| Threat | Disposition | Evidence |
|--------|-------------|----------|
| T-20-02 async ack | MITIGATED | @doc contains "accepted for processing" + `v1.billing.meter.error_report_triggered`; `Code.fetch_docs` assertion green |
| T-20-04 payload masking | MITIGATED | `defimpl Inspect` excludes `:payload`; `refute r =~ "stripe_customer_id"` + `refute r =~ "cus_test_123"` green |
| T-20-me-01 tampering | MITIGATED | `require_param!` raises `ArgumentError` for missing event_name or payload before network; 2 param validation tests green |

## Self-Check: PASSED

Files created/modified:
- FOUND: lib/lattice_stripe/billing/meter_event.ex
- FOUND: test/lattice_stripe/billing/meter_event_test.exs

Commits:
- FOUND: ed99b36 (feat(20-04): implement Billing.MeterEvent resource with Inspect payload masking)
