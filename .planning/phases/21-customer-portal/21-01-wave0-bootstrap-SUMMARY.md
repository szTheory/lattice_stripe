---
phase: 21-customer-portal
plan: "01"
subsystem: billing_portal
tags: [bootstrap, fixtures, test-skeletons, stripe-mock-probe]
dependency_graph:
  requires: []
  provides:
    - scripts/verify_portal_endpoint.exs
    - test/support/fixtures/billing_portal.ex
    - test/lattice_stripe/billing_portal/session_test.exs
    - test/lattice_stripe/billing_portal/guards_test.exs
    - test/lattice_stripe/billing_portal/session/flow_data_test.exs
    - test/integration/billing_portal_session_integration_test.exs
  affects:
    - .planning/phases/21-customer-portal/21-VALIDATION.md
tech_stack:
  added: []
  patterns:
    - stripe-mock probe script with :httpc (no Jason — plain elixir script context)
    - LatticeStripe.Test.Fixtures.* nested submodule convention (mirrors metering.ex)
    - @tag :skip skeleton tests for Wave 0 bootstrap
key_files:
  created:
    - scripts/verify_portal_endpoint.exs
    - test/support/fixtures/billing_portal.ex
    - test/lattice_stripe/billing_portal/session_test.exs
    - test/lattice_stripe/billing_portal/guards_test.exs
    - test/lattice_stripe/billing_portal/session/flow_data_test.exs
    - test/integration/billing_portal_session_integration_test.exs
  modified:
    - .planning/phases/21-customer-portal/21-VALIDATION.md
decisions:
  - "stripe-mock returns HTTP 400 (not 422) for validation errors; probe updated to accept 400 or 422"
  - "RESEARCH Finding 1 confirmed: stripe-mock does NOT enforce flow_data sub-field validation"
  - "Unused alias warnings in skeleton test files are test-compile-time only; mix compile --warnings-as-errors clean"
metrics:
  duration: ~15 minutes
  completed: 2026-04-14T19:54:25Z
  tasks_completed: 3
  tasks_total: 3
  files_created: 6
  files_modified: 1
---

# Phase 21 Plan 01: Wave 0 Bootstrap Summary

**One-liner:** Wave 0 bootstrap — stripe-mock probe confirming 400/sub-field-gap behavior, BillingPortal fixture module with 5 Session builders, and 4 skeleton test files (29 skipped tests) unblocking plans 21-02 through 21-04.

---

## What Was Built

### Task 1 — stripe-mock probe (commit `9eedac0`)

`scripts/verify_portal_endpoint.exs` probes 4 cases against `POST /v1/billing_portal/sessions`:

1. Happy path (`customer=cus_test123`) — HTTP 200 with `url` field present
2. Missing customer — HTTP 400 rejected
3. Unknown `flow_data.type` — HTTP 400 "value is not in enumeration"
4. Sub-field gap (`subscription_cancel` without `.subscription`) — HTTP 200 (RESEARCH Finding 1 confirmed)

All 4 cases pass (exit 0). Script mirrors `verify_meter_endpoints.exs` idiom with `:httpc` only (no Jason — unavailable in plain `elixir` script context).

### Task 2 — BillingPortal fixture module (commit `1c10619`)

`LatticeStripe.Test.Fixtures.BillingPortal.Session` with 5 builder functions:

- `basic/1` — 11 wire-format fields, `flow: nil`
- `with_payment_method_update_flow/1` — zero required sub-fields
- `with_subscription_cancel_flow/1` — `subscription_cancel.subscription` sub-field
- `with_subscription_update_flow/1` — `subscription_update.subscription` sub-field
- `with_subscription_update_confirm_flow/1` — `subscription_update_confirm.subscription` + non-empty `items` list

Covers all 4 flow types for TEST-02. Follows `metering.ex` namespace convention exactly.

### Task 3 — Test skeletons + 21-VALIDATION.md (commit `e736ab3`)

Four test files scaffolded with `@tag :skip` stubs (29 tests, 0 failures):

- `session_test.exs` — PORTAL-01/02/05/06 + D-03 Inspect masking (3 describe blocks)
- `guards_test.exs` — D-01 10-case guard matrix (PORTAL-04)
- `session/flow_data_test.exs` — PORTAL-03 FlowData decode cases for all 4 flow types + extra capture
- `billing_portal_session_integration_test.exs` — TEST-05 portal stub with `setup_all` stripe-mock probe

`21-VALIDATION.md` updated: `wave_0_complete: true`, all Wave 0 checkboxes ticked, per-task map rows for plans 21-01..21-04 populated with real task IDs and ✅ status for Wave 0 tasks.

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] stripe-mock returns HTTP 400 not 422 for validation errors**
- **Found during:** Task 1 (first probe run)
- **Issue:** RESEARCH.md documented expected 422 for missing customer and unknown flow_data.type; stripe-mock actually returns 400 for OpenAPI validation failures
- **Fix:** Probe cases 2 and 3 updated to accept `status in [400, 422]`; header comment updated to document this finding; the semantic outcome (request rejected with `invalid_request_error`) is identical
- **Files modified:** `scripts/verify_portal_endpoint.exs`
- **Commit:** `9eedac0`

---

## Known Stubs

All stubs are intentional Wave 0 skeletons. The test bodies reference modules (`LatticeStripe.BillingPortal.Session`, `LatticeStripe.BillingPortal.Guards`, `LatticeStripe.BillingPortal.Session.FlowData`) that do not exist yet — they will be created in plans 21-02 and 21-03. The stubs use `@tag :skip` to prevent compilation failures.

| Stub | File | Reason |
|------|------|--------|
| All `describe "create/3"` tests | `session_test.exs` | Module created in plan 21-03 |
| All `describe "from_map/1"` tests | `session_test.exs` | Module created in plan 21-03 |
| All `describe "Inspect impl"` tests | `session_test.exs` | Module created in plan 21-03 |
| All `describe "check_flow_data!/1"` tests | `guards_test.exs` | Module created in plan 21-03 |
| All `describe "from_map/1"` tests | `session/flow_data_test.exs` | Modules created in plan 21-02 |
| Integration test | `billing_portal_session_integration_test.exs` | Module created in plan 21-03; full test in plan 21-04 |

---

## Threat Flags

None. Probe script targets localhost only. Fixture URLs are fake placeholders (`https://billing.stripe.com/session/test_token`), not real bearer credentials.

---

## Self-Check: PASSED

Files verified:
- `scripts/verify_portal_endpoint.exs` — FOUND
- `test/support/fixtures/billing_portal.ex` — FOUND
- `test/lattice_stripe/billing_portal/session_test.exs` — FOUND
- `test/lattice_stripe/billing_portal/guards_test.exs` — FOUND
- `test/lattice_stripe/billing_portal/session/flow_data_test.exs` — FOUND
- `test/integration/billing_portal_session_integration_test.exs` — FOUND
- `.planning/phases/21-customer-portal/21-VALIDATION.md` — FOUND (wave_0_complete: true)

Commits verified:
- `9eedac0` — probe script
- `1c10619` — fixture module
- `e736ab3` — test skeletons + validation map
