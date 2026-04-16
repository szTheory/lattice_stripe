---
phase: 29-changeset-style-param-builders
plan: "02"
subsystem: builders
tags: [billing-portal, flow-data, param-builders, tdd, exdoc]
dependency_graph:
  requires:
    - lib/lattice_stripe/billing_portal/guards.ex
    - lib/lattice_stripe/billing_portal/session.ex
    - lib/lattice_stripe/billing_portal/session/flow_data.ex
  provides:
    - LatticeStripe.Builders.BillingPortal
  affects:
    - mix.exs (ExDoc groups_for_modules)
tech_stack:
  added: []
  patterns:
    - Named constructor functions returning plain string-keyed maps (no accumulator struct)
    - Private helper (maybe_after_completion/2) for DRY opt handling across all constructors
    - TDD RED/GREEN cycle with Guard integration tests
key_files:
  created:
    - lib/lattice_stripe/builders/billing_portal.ex
    - test/lattice_stripe/builders/billing_portal_test.exs
  modified:
    - mix.exs
decisions:
  - "Named constructors with no accumulator struct (FlowData is single-call, not compositional)"
  - "Private maybe_after_completion/2 helper DRYs after_completion opt across all four constructors"
  - "when items != [] guard on subscription_update_confirm/3 causes FunctionClauseError on empty items (fail-fast before Guards.check_flow_data!/1)"
  - "String keys throughout builder output to match Guards.check_flow_data!/1 wire format expectations (D-06)"
metrics:
  duration: "~6 minutes"
  completed_date: "2026-04-16"
  tasks_completed: 3
  files_created: 2
  files_modified: 1
requirements:
  - DX-03
---

# Phase 29 Plan 02: BillingPortal FlowData Builder Summary

BillingPortal FlowData builder with four named constructors (subscription_cancel/2, subscription_update/2, subscription_update_confirm/3, payment_method_update/1) that produce Guards-validated string-keyed maps.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | RED -- Write failing tests for BillingPortal builder | 0cf27ac | test/lattice_stripe/builders/billing_portal_test.exs, lib/lattice_stripe/builders/billing_portal.ex (stub) |
| 2 | GREEN + REFACTOR -- Implement BillingPortal builder | 5ecc6c9 | lib/lattice_stripe/builders/billing_portal.ex |
| 3 | Wire ExDoc Param Builders group in mix.exs | 2af5c44 | mix.exs |

## What Was Built

`LatticeStripe.Builders.BillingPortal` provides optional named constructor functions for the four Stripe portal flow types. Each constructor returns a plain string-keyed map that passes `Guards.check_flow_data!/1` validation and can be placed directly into `params["flow_data"]` for `BillingPortal.Session.create/3`.

### Constructor functions

- `subscription_cancel/2` — requires `subscription_id`, optional `:retention` and `:after_completion` keyword args
- `subscription_update/2` — requires `subscription_id`, optional `:after_completion`
- `subscription_update_confirm/3` — requires `subscription_id` + non-empty `items` list, optional `:discounts` and `:after_completion`; raises `FunctionClauseError` on empty items via `when items != []` guard
- `payment_method_update/1` — no required args, optional `:after_completion`

A private `maybe_after_completion/2` helper DRYs the optional `after_completion` key injection across all four constructors.

### ExDoc

Both `LatticeStripe.Builders.SubscriptionSchedule` and `LatticeStripe.Builders.BillingPortal` are registered in the `"Param Builders"` ExDoc group in `mix.exs`, after the `Internals` group.

## TDD Gate Compliance

- RED gate: commit `0cf27ac` — `test(29-02): add failing tests for BillingPortal builder` (15 tests, 15 failures confirmed)
- GREEN gate: commit `5ecc6c9` — `feat(29-02): implement BillingPortal FlowData builder` (15 tests, 0 failures confirmed)
- REFACTOR gate: not needed — implementation was clean on first pass

## Verification

- `mix test test/lattice_stripe/builders/billing_portal_test.exs` — 15 tests, 0 failures
- `mix compile --warnings-as-errors` — no warnings
- All four flow type outputs pass `Guards.check_flow_data!/1` (tested via guard integration tests)
- `subscription_update_confirm/3` raises `FunctionClauseError` on empty items (tested)
- `after_completion` opt works on all four constructors (tested)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all four constructors produce complete, validated output. No placeholder data.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. Builder module is pure data transformation with no external calls.

## Self-Check: PASSED

All created files exist. All task commits exist. 15 tests pass. No compile warnings.
