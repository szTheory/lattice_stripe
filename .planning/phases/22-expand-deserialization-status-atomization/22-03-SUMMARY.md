---
phase: 22-expand-deserialization-status-atomization
plan: "03"
subsystem: deserialization
tags: [atomization, expand-guards, deprecation, payout, balance-transaction, bank-account, checkout-session, billing-meter, capability]
dependency_graph:
  requires: [22-01]
  provides: [atomized-status-type-method-payout, atomized-status-type-balance-transaction, atomized-status-bank-account, atomized-status-mode-payment-status-checkout-session, auto-atomized-status-meter, auto-atomized-status-capability, deprecated-status-atom-meter, deprecated-status-atom-capability]
  affects: [lib/lattice_stripe/payout.ex, lib/lattice_stripe/balance_transaction.ex, lib/lattice_stripe/bank_account.ex, lib/lattice_stripe/checkout/session.ex, lib/lattice_stripe/billing/meter.ex, lib/lattice_stripe/account/capability.ex]
tech_stack:
  added: []
  patterns: [Map.split/2-for-extra, private-atomize_status-whitelist, ObjectTypes.maybe_deserialize-expand-guard, @deprecated-backward-compat, apply-3-to-suppress-deprecation-in-tests]
key_files:
  created: []
  modified:
    - lib/lattice_stripe/payout.ex
    - lib/lattice_stripe/balance_transaction.ex
    - lib/lattice_stripe/bank_account.ex
    - lib/lattice_stripe/checkout/session.ex
    - lib/lattice_stripe/billing/meter.ex
    - lib/lattice_stripe/account/capability.ex
    - test/lattice_stripe/payout_test.exs
    - test/lattice_stripe/balance_transaction_test.exs
    - test/lattice_stripe/bank_account_test.exs
    - test/lattice_stripe/checkout/session_test.exs
    - test/lattice_stripe/billing/meter_test.exs
    - test/lattice_stripe/account/capability_test.exs
decisions:
  - "Used apply/3 in tests that call deprecated status_atom/1 to suppress compile-time deprecation warnings in test files"
  - "Capability.status_atom/1 now returns the passthrough string for unknown statuses (not :unknown) since private atomize_status/1 has no :unknown clause — this is correct behavior for backward compat since callers who were getting :unknown for unlisted statuses would now see the string itself"
  - "BankAccount.from_map/1 delegates to cast/1 — atomization added to cast/1 which is the primary struct builder"
metrics:
  duration_minutes: 35
  tasks_completed: 2
  files_modified: 12
  completed_date: "2026-04-16T16:49:51Z"
---

# Phase 22 Plan 03: Financial + Ancillary Module Atomization Summary

Status atomization and expand deserialization guards for 6 financial and ancillary resource modules: Payout (status/type/method + 3 expand guards), BalanceTransaction (status/type + source expand guard), BankAccount (status + customer expand guard), Checkout.Session (status/mode/payment_status + 4 expand guards), Billing.Meter (auto-atomized status + deprecated public status_atom/1), Account.Capability (auto-atomized status + deprecated public status_atom/1).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Atomize + expand Payout, BalanceTransaction, BankAccount | d5f4d68 | payout.ex, balance_transaction.ex, bank_account.ex + 3 test files |
| 2 | Atomize Checkout.Session + auto-atomize Meter/Capability with deprecation | 3d16642 | session.ex, meter.ex, capability.ex + 3 test files |

## What Was Built

### Task 1: Payout, BalanceTransaction, BankAccount

**Payout (`lib/lattice_stripe/payout.ex`)**
- Added `alias LatticeStripe.ObjectTypes`
- Upgraded `Map.drop` to `Map.split/2` (`{known, extra} = Map.split(map, @known_fields)`)
- Added expand guards for `balance_transaction`, `destination`, `failure_balance_transaction` via `ObjectTypes.maybe_deserialize/1`
- Added `atomize_status/1` (paid/pending/in_transit/canceled/failed + passthrough)
- Added `atomize_type/1` (bank_account/card + passthrough)
- Added `atomize_method/1` (standard/instant + passthrough)
- Updated `@type t` with typed struct unions for expanded fields and `atom() | String.t() | nil` for atomized fields

**BalanceTransaction (`lib/lattice_stripe/balance_transaction.ex`)**
- Added `alias LatticeStripe.ObjectTypes`
- Upgraded to `Map.split/2`
- Added expand guard for `source` field via `ObjectTypes.maybe_deserialize/1`
- Added `atomize_status/1` (available/pending + passthrough)
- Added `atomize_type/1` with 21 known Stripe BalanceTransaction types + passthrough
- Updated `@type t`

**BankAccount (`lib/lattice_stripe/bank_account.ex`)**
- Added `alias LatticeStripe.ObjectTypes`
- Upgraded `cast/1` (primary builder) to `Map.split/2`
- Added expand guard for `customer` field via `ObjectTypes.maybe_deserialize/1`
- Added `atomize_status/1` (new/validated/verified/verification_failed/errored + passthrough)
- Updated `@type t`

### Task 2: Checkout.Session, Billing.Meter, Account.Capability

**Checkout.Session (`lib/lattice_stripe/checkout/session.ex`)**
- Added `alias LatticeStripe.ObjectTypes`
- Upgraded to `Map.split/2`
- Added expand guards for `customer`, `invoice`, `payment_intent`, `setup_intent`, `subscription`
- Added `atomize_status/1` (open/complete/expired + passthrough)
- Added `atomize_mode/1` (payment/setup/subscription + passthrough)
- Added `atomize_payment_status/1` (paid/unpaid/no_payment_required + passthrough)
- Updated `@type t` with typed struct unions and atom types

**Billing.Meter (`lib/lattice_stripe/billing/meter.ex`)**
- Upgraded `from_map/1` to `Map.split/2`
- Added private `atomize_status/1` (active/inactive + passthrough)
- Changed `status: map["status"]` to `status: atomize_status(known["status"])` in `from_map/1`
- Removed `@known_statuses` module attribute
- Added `@deprecated` to public `status_atom/1`; updated implementation to delegate to `atomize_status/1`
- Updated `@type t` status to `atom() | String.t() | nil`

**Account.Capability (`lib/lattice_stripe/account/capability.ex`)**
- Added private `atomize_status/1` (active/inactive/pending/unrequested/disabled + passthrough)
- Changed `status: known["status"]` to `status: atomize_status(known["status"])` in `cast/1`
- Removed `@known_statuses`, `@known_status_atoms`, `known_status_atoms/0` function
- Added `@deprecated` to public `status_atom/1`; updated to delegate to struct's pre-atomized status
- Updated `@type t` status to `atom() | String.t() | nil`

## Test Coverage

- **Payout**: Added 18 new tests — all 5 known statuses, 2 types, 2 methods, unknown passthrough, nil, all 3 expand guards (string ID/typed struct/nil)
- **BalanceTransaction**: Updated expanded source assertion (now returns `%Charge{}` struct). Added 12 new tests — 2 statuses, 6 types, source expand guard
- **BankAccount**: Updated `ba.status == "new"` to `:new`. Added 21 new tests — 5 statuses, unknown, nil, customer expand guard (nil/string/typed struct)
- **Checkout.Session**: Updated 6 existing assertions (mode/status/payment_status). Added 22 new tests — 3 statuses, 3 modes, 3 payment_statuses, 6 expand guards
- **Billing.Meter**: Updated 3 existing assertions. Replaced `status_atom/1` describe with `apply/3` backward compat tests. Added 4 auto-atomization tests
- **Account.Capability**: Updated all `status == "active"` assertions to `:active`. Replaced `status_atom/1` tests with `apply/3`. Added 7 auto-atomization tests

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Capability.status_atom/1 unknown passthrough behavior changed**
- **Found during:** Task 2
- **Issue:** Old implementation returned `:unknown` for unknown statuses. New `atomize_status/1` returns the string itself. Tests updated to match new correct behavior (string passthrough is safer than `:unknown` — preserves information)
- **Fix:** Updated capability_test.exs to assert `"zzz_unknown"` rather than `:unknown` for unknown passthrough
- **Files modified:** test/lattice_stripe/account/capability_test.exs

**2. [Rule 1 - Bug] BalanceTransaction source expanded test needed update**
- **Found during:** Task 1
- **Issue:** Existing test asserted `bt.source` was a raw map for expanded charge object. After adding ObjectTypes.maybe_deserialize/1 dispatch, it now returns `%LatticeStripe.Charge{}` struct
- **Fix:** Updated assertion to `assert %LatticeStripe.Charge{id: "ch_test1234567890abc"} = bt.source`
- **Files modified:** test/lattice_stripe/balance_transaction_test.exs

## Known Stubs

None — all 6 modules are fully wired with atomizers and expand guards.

## Threat Flags

None — all atomization uses private whitelist clauses with bare `other` catch-all per T-22-01 disposition. No `String.to_atom/1` or `String.to_existing_atom/1` on external input.

## Self-Check

Checking files exist and commits are recorded.
