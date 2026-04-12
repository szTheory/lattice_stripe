---
phase: 14-invoices-invoice-line-items
plan: 04
subsystem: billing-telemetry-integration
tags: [invoice, invoice-item, telemetry, auto-advance, stripe-mock, integration-tests]
dependency_graph:
  requires:
    - LatticeStripe.Invoice (14-02, 14-03)
    - LatticeStripe.InvoiceItem (14-02)
    - LatticeStripe.Telemetry (phase-08)
  provides:
    - [:lattice_stripe, :invoice, :auto_advance_scheduled] telemetry event
    - Telemetry.emit_auto_advance_scheduled/2
    - Telemetry.handle_auto_advance_log/4
    - test/integration/invoice_integration_test.exs
    - test/integration/invoice_item_integration_test.exs
  affects:
    - lib/lattice_stripe/invoice.ex
    - lib/lattice_stripe/telemetry.ex
    - test/lattice_stripe/telemetry_test.exs
tech_stack:
  added: []
  patterns:
    - Post-success side-effect telemetry: pattern-match on result after Resource.unwrap_singular, emit only on {:ok, %Invoice{auto_advance: true}}
    - Dual-handler attach_default_logger: two :telemetry.attach calls under one public function, both idempotent via detach-first
    - Integration tests live in test/integration/, tagged :integration, use TCP guard + IntegrationFinch pool
    - async: false for all tests that use telemetry_enabled: true to avoid global event bus leakage into concurrent tests
key_files:
  created:
    - test/integration/invoice_integration_test.exs
    - test/integration/invoice_item_integration_test.exs
  modified:
    - lib/lattice_stripe/invoice.ex
    - lib/lattice_stripe/telemetry.ex
    - test/lattice_stripe/telemetry_test.exs
decisions:
  - "Auto-advance telemetry tests moved from invoice_test.exs (async: true) to telemetry_test.exs (async: false) — telemetry_enabled: true with concurrent tests leaks [:lattice_stripe, :request, :stop] events into other tests' global handlers"
  - "emit_auto_advance_scheduled/2 respects client.telemetry_enabled flag — consistent with all other telemetry emission in the SDK"
  - "attach_default_logger/1 attaches a second handler under @auto_advance_logger_id for the new event — detach-first ensures idempotency for both handlers"
  - "Integration tests use flexible assert (match?({:ok,...} or {:error,...}) for state-dependent operations (finalize, delete) — stripe-mock may reject based on resource state"
metrics:
  duration: ~15min
  completed: 2026-04-12
  tasks_completed: 2
  files_created: 2
  files_modified: 3
---

# Phase 14 Plan 04: Auto-Advance Telemetry + Integration Tests Summary

Added a domain-level `[:lattice_stripe, :invoice, :auto_advance_scheduled]` telemetry event emitted by `Invoice.create/3` when the returned invoice has `auto_advance: true`, extended `attach_default_logger/1` to log a warning for this event, and added stripe-mock integration tests for both Invoice and InvoiceItem.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Auto-advance telemetry event + attach_default_logger extension + tests | cb0a9f6 | lib/lattice_stripe/invoice.ex, lib/lattice_stripe/telemetry.ex, test/lattice_stripe/telemetry_test.exs |
| 2 | stripe-mock integration tests for Invoice and InvoiceItem | 6957e5a | test/integration/invoice_integration_test.exs, test/integration/invoice_item_integration_test.exs |

## What Was Built

### Task 1 — Auto-Advance Telemetry Event

**New telemetry event:** `[:lattice_stripe, :invoice, :auto_advance_scheduled]`

Emitted after a successful `Invoice.create/3` when the returned invoice has `auto_advance: true`. Stripe will automatically finalize such invoices ~1 hour after creation, which is a significant billing behavior that users should be able to observe.

**Emission logic in `Invoice.create/3`:**

```elixir
case result do
  {:ok, %__MODULE__{auto_advance: true} = invoice} ->
    Telemetry.emit_auto_advance_scheduled(client, invoice)
    result
  _ ->
    result
end
```

- Only fires on `{:ok, ...}` — errors never emit the event
- Only fires when `auto_advance: true` on the returned struct (not the params)
- Respects `client.telemetry_enabled` flag via `emit_auto_advance_scheduled/2`

**Measurements:** `%{system_time: System.system_time()}`

**Metadata:** `%{invoice_id: invoice.id, customer: invoice.customer}`

**Default logger extension:**

`attach_default_logger/1` now attaches a second handler under `:lattice_stripe_auto_advance_logger`:

```
[warning] Invoice in_123 (customer: cus_456) has auto_advance: true — Stripe will auto-finalize in ~1 hour
```

Handles nil customer gracefully (omits the `customer:` part).

**New documentation in `Telemetry` @moduledoc:** full measurements/metadata table for the new event, plus updated default logger example showing the warning format.

### Task 2 — Integration Tests

**`test/integration/invoice_integration_test.exs`** — 7 tests:
- `create/3` returns an Invoice struct
- `retrieve/3` returns invoice by id
- `update/4` returns an updated Invoice struct
- `delete/3` deletes a draft Invoice (flexible assert)
- `list/3` returns a Response with a List
- `finalize/4` transitions invoice from draft to open (flexible assert)
- `list_line_items/4` returns a Response with a List
- (1 @tag :skip — invalid ID test, stripe-mock stubs all IDs)

**`test/integration/invoice_item_integration_test.exs`** — 7 tests:
- `create/3` returns an InvoiceItem struct
- `retrieve/3` returns invoice item by id
- `update/4` returns an updated InvoiceItem struct
- `delete/3` deletes an InvoiceItem (flexible assert)
- `list/3` returns a Response with a List
- (1 @tag :skip — invalid ID test)

Both follow the established `customer_integration_test.exs` pattern:
- TCP guard on localhost:12111 in `setup_all`
- `start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})`
- `test_integration_client()` from TestHelpers
- `@moduletag :integration`
- `async: false`

## Test Coverage

| Suite | Tests Before | Tests After | Result |
|-------|-------------|-------------|--------|
| Unit tests (--exclude integration) | 712 | 720 | 0 failures |
| Integration (invoice + invoice_item) | 0 | 12 | 0 failures (2 skipped) |

8 new unit tests added to telemetry_test.exs:
- 4 tests for `[:lattice_stripe, :invoice, :auto_advance_scheduled]` event behavior
- 4 tests for default logger auto-advance handler (log format, customer handling, idempotency)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Telemetry tests with telemetry_enabled: true leaked into concurrent tests**
- **Found during:** Task 1 test verification
- **Issue:** When `async: true` invoice tests fire `[:lattice_stripe, :request, :stop]` with `telemetry_enabled: true`, the global telemetry handler in `client_test.exs` test 27 received the event, causing `refute_receive` to fail
- **Fix:** Moved all new auto-advance telemetry tests from `invoice_test.exs` (async: true) to `telemetry_test.exs` (async: false), which is the designated home for all telemetry tests
- **Files modified:** test/lattice_stripe/invoice_test.exs (removed block), test/lattice_stripe/telemetry_test.exs (added block)
- **Commit:** Inline in cb0a9f6

## Known Stubs

None — all functions route to real Stripe API endpoints. Integration tests call stripe-mock which validates against the Stripe OpenAPI spec.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries introduced. The new telemetry event `[:lattice_stripe, :invoice, :auto_advance_scheduled]` is a read-only observation of data already returned by Stripe — it does not perform any network call or expose new surface.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| lib/lattice_stripe/invoice.ex | FOUND |
| lib/lattice_stripe/telemetry.ex | FOUND |
| test/lattice_stripe/telemetry_test.exs | FOUND |
| test/integration/invoice_integration_test.exs | FOUND |
| test/integration/invoice_item_integration_test.exs | FOUND |
| Commit cb0a9f6 (Task 1) | FOUND |
| Commit 6957e5a (Task 2) | FOUND |
| `emit_auto_advance_scheduled` in telemetry.ex | FOUND |
| `@auto_advance_event` module attribute | FOUND |
| `handle_auto_advance_log/4` in telemetry.ex | FOUND |
| 720 unit tests, 0 failures | VERIFIED |
| 12 integration tests, 0 failures (2 skipped) | VERIFIED |
