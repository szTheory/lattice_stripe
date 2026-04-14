---
phase: 21-customer-portal
plan: "02"
subsystem: billing_portal
tags: [flow-data, nested-structs, tdd, portal]
dependency_graph:
  requires:
    - 21-01
  provides:
    - lib/lattice_stripe/billing_portal/session/flow_data.ex
    - lib/lattice_stripe/billing_portal/session/flow_data/after_completion.ex
    - lib/lattice_stripe/billing_portal/session/flow_data/subscription_cancel.ex
    - lib/lattice_stripe/billing_portal/session/flow_data/subscription_update.ex
    - lib/lattice_stripe/billing_portal/session/flow_data/subscription_update_confirm.ex
  affects:
    - lib/lattice_stripe/billing_portal/session.ex (plan 21-03 consumer)
tech_stack:
  added: []
  patterns:
    - "@known_fields + Map.drop extra-capture pattern (mirrors Meter.CustomerMapping)"
    - "Nil-safe from_map/1 with is_map guard — two-clause shape"
    - "Polymorphic parent struct with flat branch fields (one per flow type)"
key_files:
  created:
    - lib/lattice_stripe/billing_portal/session/flow_data.ex
    - lib/lattice_stripe/billing_portal/session/flow_data/after_completion.ex
    - lib/lattice_stripe/billing_portal/session/flow_data/subscription_cancel.ex
    - lib/lattice_stripe/billing_portal/session/flow_data/subscription_update.ex
    - lib/lattice_stripe/billing_portal/session/flow_data/subscription_update_confirm.ex
  modified:
    - test/lattice_stripe/billing_portal/session/flow_data_test.exs
decisions:
  - "Sub-structs and parent module committed together in GREEN phase — test file uses struct patterns from both, so splitting commits would leave RED state between Task 1 and Task 2"
  - "Leaf sub-objects (retention, items, discounts, redirect, hosted_confirmation) kept as raw map() per D-02"
  - "No payment_method_update module — zero extra fields, type string alone is sufficient"
metrics:
  duration: ~2 minutes
  completed: 2026-04-14T20:18:33Z
  tasks_completed: 2
  tasks_total: 2
  files_created: 5
  files_modified: 1
---

# Phase 21 Plan 02: FlowData Nested-Struct Tree Summary

**One-liner:** 5-module FlowData nested-struct tree with polymorphic parent, 4 typed branch sub-structs, forward-compat extra capture, and 18 green TDD tests covering all flow types and atom dot-access.

---

## What Was Built

### Task 1 — 4 FlowData sub-struct modules (RED commit `a8b91dc`, GREEN commit `92a0599`)

Four modules following the `Meter.CustomerMapping` `@known_fields + Map.drop` template verbatim:

- `AfterCompletion` — `type/redirect/hosted_confirmation` fields; `redirect` and `hosted_confirmation` stay as raw maps per D-02.
- `SubscriptionCancel` — `subscription/retention` fields; `retention` stays raw map.
- `SubscriptionUpdate` — `subscription` field only.
- `SubscriptionUpdateConfirm` — `subscription/items/discounts`; `items` and `discounts` stay as raw `[map()]` per D-02.

Each module: `@known_fields` list, `defstruct` with `extra: %{}` default, `@spec from_map(map() | nil) :: t() | nil`, two `from_map/1` clauses (`nil` → `nil`, `map` → struct), `Map.drop(map, @known_fields)` for extra capture.

### Task 2 — Parent FlowData module (GREEN commit `92a0599`)

`LatticeStripe.BillingPortal.Session.FlowData` implemented verbatim from CONTEXT.md D-02 interface spec:

- `@known_fields ~w(type after_completion subscription_cancel subscription_update subscription_update_confirm)`
- Delegates to all 4 sub-struct `from_map/1` functions
- `extra: Map.drop(map, @known_fields)` captures unknown flow-type keys (forward compatibility, T-21-03 mitigation)
- Fully typed with `@type t` matching CONTEXT.md spec

18 tests all pass:
- Sub-struct nil → nil
- Sub-struct happy paths with correct field mapping
- Sub-struct extra capture
- Parent nil → nil
- All 4 flow type decode paths
- Forward-compat: `"subscription_pause"` lands in `:extra` without crash
- Atom dot-access: `result.subscription_cancel.subscription == "sub_123"`

---

## TDD Gate Compliance

| Gate | Commit | Status |
|------|--------|--------|
| RED | `a8b91dc` | `test(21-02): add failing tests for FlowData sub-structs and parent module` |
| GREEN | `92a0599` | `feat(21-02): implement FlowData nested-struct tree (PORTAL-03)` |
| REFACTOR | — | No refactor needed; code is minimal and clean |

---

## Deviations from Plan

### Structural Note (Not a Deviation)

The plan separates Task 1 (sub-structs) and Task 2 (parent) into distinct TDD cycles. However, the test file uses struct match patterns from both the sub-struct modules AND the parent `FlowData` module (e.g., `assert %FlowData{subscription_cancel: %SubscriptionCancel{...}} = result`). This means the test file cannot compile with only Task 1 modules present — the parent struct pattern would cause a compile error.

Resolution: Both modules were implemented before the first GREEN test run, then committed together in a single GREEN commit. The RED commit captures the full failing test file. This satisfies TDD intent — RED confirmed (compile error on undefined structs), GREEN confirmed (all 18 tests pass).

---

## Known Stubs

None. All modules fully implemented. Tests are real assertions with no `@tag :skip` remaining in `flow_data_test.exs`.

---

## Threat Flags

None. No new network endpoints, auth paths, or schema changes introduced. Pure data-transformation modules with no I/O.

---

## Self-Check: PASSED

Files verified:
- `lib/lattice_stripe/billing_portal/session/flow_data.ex` — FOUND
- `lib/lattice_stripe/billing_portal/session/flow_data/after_completion.ex` — FOUND
- `lib/lattice_stripe/billing_portal/session/flow_data/subscription_cancel.ex` — FOUND
- `lib/lattice_stripe/billing_portal/session/flow_data/subscription_update.ex` — FOUND
- `lib/lattice_stripe/billing_portal/session/flow_data/subscription_update_confirm.ex` — FOUND
- `test/lattice_stripe/billing_portal/session/flow_data_test.exs` — FOUND (18 tests, 0 failures)

Commits verified:
- `a8b91dc` — RED: failing tests
- `92a0599` — GREEN: 5 FlowData modules
