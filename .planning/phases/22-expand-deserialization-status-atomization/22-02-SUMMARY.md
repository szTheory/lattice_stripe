---
phase: 22-expand-deserialization-status-atomization
plan: "02"
subsystem: resource-deserialization
tags: [atomization, expand, payment-intent, subscription, subscription-schedule, charge, refund, setup-intent]
dependency_graph:
  requires: [22-01]
  provides: [atomized-status-fields, expand-guards-core-resources]
  affects: [payment_intent, subscription, subscription_schedule, charge, refund, setup_intent]
tech_stack:
  added: []
  patterns:
    - Map.split/2 for known/extra field separation
    - Private defp atomize_status/1 whitelist with catch-all passthrough
    - if is_map(field) guard pattern with ObjectTypes.maybe_deserialize/1
key_files:
  created: []
  modified:
    - lib/lattice_stripe/payment_intent.ex
    - lib/lattice_stripe/subscription.ex
    - lib/lattice_stripe/subscription_schedule.ex
    - lib/lattice_stripe/charge.ex
    - lib/lattice_stripe/refund.ex
    - lib/lattice_stripe/setup_intent.ex
    - test/lattice_stripe/payment_intent_test.exs
    - test/lattice_stripe/subscription_test.exs
    - test/lattice_stripe/subscription_schedule_test.exs
    - test/lattice_stripe/charge_test.exs
    - test/lattice_stripe/refund_test.exs
    - test/lattice_stripe/setup_intent_test.exs
decisions:
  - "SetupAttempt module does not exist — SetupIntent.latest_attempt kept as map() | String.t() | nil, no expand guard added"
  - "Charge expand test updated to match %BalanceTransaction{} struct (not raw map) after ObjectTypes dispatch"
  - "Elixir if/do/else keyword syntax requires parentheses inside struct literals to avoid parser ambiguity"
metrics:
  duration_minutes: 30
  completed_date: "2026-04-16"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 12
---

# Phase 22 Plan 02: Atomize + Expand Core Payment Resources Summary

Status atomization and expand deserialization guards applied to all 6 core payment resource modules: PaymentIntent, Subscription, SubscriptionSchedule, Charge, Refund, SetupIntent.

## What Was Built

### Task 1: PaymentIntent, Subscription, SubscriptionSchedule

**PaymentIntent (`lib/lattice_stripe/payment_intent.ex`)**
- Added `alias LatticeStripe.ObjectTypes`
- Upgraded `from_map/1` from `Map.drop` to `Map.split/2` pattern
- Added expand guards for `customer`, `latest_charge`, `payment_method`
- Added `atomize_status/1` for all 7 statuses: `requires_payment_method`, `requires_confirmation`, `requires_action`, `processing`, `requires_capture`, `canceled`, `succeeded`
- Updated `@type t` with union typespecs for expandable fields and `status: atom() | String.t() | nil`

**Subscription (`lib/lattice_stripe/subscription.ex`)**
- Added `alias LatticeStripe.ObjectTypes`
- Added expand guards for `customer`, `default_payment_method`, `latest_invoice`, `pending_setup_intent`, `schedule`
- Added `atomize_status/1` for 8 statuses: `incomplete`, `incomplete_expired`, `trialing`, `active`, `past_due`, `canceled`, `unpaid`, `paused`
- Added `atomize_collection_method/1` for `charge_automatically` and `send_invoice`
- Updated `@type t` for all expandable fields

**SubscriptionSchedule (`lib/lattice_stripe/subscription_schedule.ex`)**
- Added `alias LatticeStripe.ObjectTypes`
- Added expand guards for `customer`, `subscription`
- Added `atomize_status/1` for 5 statuses: `not_started`, `active`, `completed`, `released`, `canceled`
- Added `atomize_end_behavior/1` for `release` and `cancel`
- Updated `@type t` for expandable fields and `end_behavior: atom() | String.t() | nil`

### Task 2: Charge, Refund, SetupIntent

**Charge (`lib/lattice_stripe/charge.ex`)**
- Added `alias LatticeStripe.ObjectTypes`
- Upgraded `from_map/1` from `Map.drop` to `Map.split/2`
- Added expand guards for `customer`, `invoice`, `payment_intent`, `payment_method`, `balance_transaction`, `destination`, `source_transfer`
- Added `atomize_status/1` for `succeeded`, `pending`, `failed`
- Updated `@type t` with proper struct union types for all expandable fields

**Refund (`lib/lattice_stripe/refund.ex`)**
- Added `alias LatticeStripe.ObjectTypes`
- Upgraded `from_map/1` from `Map.drop` to `Map.split/2`
- Added expand guards for `charge`, `payment_intent`
- Added `atomize_status/1` for `pending`, `requires_action`, `succeeded`, `failed`, `canceled`
- Updated `@type t` union typespecs

**SetupIntent (`lib/lattice_stripe/setup_intent.ex`)**
- Added `alias LatticeStripe.ObjectTypes`
- Upgraded `from_map/1` from `Map.drop` to `Map.split/2`
- Added expand guards for `customer`, `payment_method` (skipped `latest_attempt` — `SetupAttempt` module does not exist in codebase)
- Added `atomize_status/1` for 6 statuses: `requires_payment_method`, `requires_confirmation`, `requires_action`, `processing`, `canceled`, `succeeded`
- Added `atomize_usage/1` for `off_session`, `on_session`
- Updated `@type t` union typespecs

## Security

Per T-22-01: All atomizers use private `defp` whitelists with a bare `other` catch-all. `String.to_atom/1` is never called on external input. Unknown status values pass through as raw strings for forward-compatibility.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `if` keyword syntax requires parentheses inside struct literals**
- **Found during:** Task 1 implementation
- **Issue:** Elixir parser raises `SyntaxError: unexpected comma` when bare `if ... do: ..., else: ...` keyword syntax appears inside `%Struct{}` literal — the parser cannot distinguish the comma as a struct field separator vs keyword argument separator
- **Fix:** Wrapped all `if` expand guard expressions with parentheses: `(if is_map(field), do: ..., else: ...)`
- **Files modified:** payment_intent.ex, subscription.ex, subscription_schedule.ex, charge.ex, refund.ex, setup_intent.ex
- **Commit:** 346dd55

**2. [Rule 1 - Bug] Charge expand test: `balance_transaction` deserialized to struct, not raw map**
- **Found during:** Task 2 test run
- **Issue:** Existing test `assert {:ok, %Charge{balance_transaction: %{"fee_details" => fee_details}}}` and `fd["type"]` accessor failed because `ObjectTypes.maybe_deserialize/1` now converts the expanded `balance_transaction` map (with `"object" => "balance_transaction"`) to a `%BalanceTransaction{}` struct, and `fee_details` elements become `%BalanceTransaction.FeeDetail{}` structs
- **Fix:** Updated test to match `%BalanceTransaction{fee_details: fee_details}` and access `fd.type` instead of `fd["type"]`
- **Files modified:** test/lattice_stripe/charge_test.exs
- **Commit:** f203eae

### Intentional Deviation

**SetupAttempt expand guard skipped:** `SetupIntent.latest_attempt` was specified to expand to `LatticeStripe.SetupAttempt.t()` but `LatticeStripe.SetupAttempt` does not exist in the codebase. Per plan instruction: "If it does NOT exist, use `map() | String.t() | nil` for the typespec and skip the expand guard for this field." Typespec is `map() | String.t() | nil` and `latest_attempt` is passed through as-is.

## Known Stubs

None. All 6 modules produce fully wired atom statuses and struct-typed expand results.

## Threat Flags

None. All changes are within the documented trust boundary: Stripe API response -> from_map/1. Atomization uses private whitelist (T-22-01 mitigated). No new network endpoints or auth paths introduced.

## Self-Check

### Created files exist
- SUMMARY.md: this file

### Commits exist

- Task 1: `346dd55` feat(22-02): atomize + expand PaymentIntent, Subscription, SubscriptionSchedule — FOUND
- Task 2: `f203eae` feat(22-02): atomize + expand Charge, Refund, SetupIntent — FOUND

## Self-Check: PASSED
