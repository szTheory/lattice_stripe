---
phase: 18-connect-money-movement
fixed_at: 2026-04-12T00:00:00Z
review_path: .planning/phases/18-connect-money-movement/18-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 18: Code Review Fix Report

**Fixed at:** 2026-04-12
**Source review:** .planning/phases/18-connect-money-movement/18-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3 (WR-01, WR-02, WR-03)
- Fixed: 3
- Skipped: 0
- Info findings (IN-01..IN-05): out of scope, not addressed

Verification: `mix compile --warnings-as-errors` clean; `mix test --exclude integration` 1386 tests, 0 failures, 142 excluded.

## Fixed Issues

### WR-01: Transfer / TransferReversal expandable fields missing `map()` in typespec

**Files modified:** `lib/lattice_stripe/transfer.ex`, `lib/lattice_stripe/transfer_reversal.ex`
**Commits:** `772795e` (Transfer), `fe9bbdd` (TransferReversal)
**Applied fix:** Updated `@type t` expandable fields to `String.t() | map() | nil`.
- `Transfer`: `balance_transaction`, `destination`, `destination_payment`, `source_transaction`
- `TransferReversal`: `balance_transaction`, `destination_payment_refund`, `source_refund`, `transfer`

No runtime / struct changes; typespec-only correction to match the `expand: [...]` idiom documented in `guides/connect.md`.

### WR-02: Charge expandable fields `destination` and `source_transfer` missing `map()` in typespec

**Files modified:** `lib/lattice_stripe/charge.ex`
**Commit:** `c26187d`
**Applied fix:** Retyped `destination` and `source_transfer` from `String.t() | nil` to `String.t() | map() | nil`, matching the already-correct `balance_transaction` field on the same struct.

### WR-03: Inconsistent pre-network id validation on `Payout.update` and `BalanceTransaction.retrieve`

**Files modified:** `lib/lattice_stripe/payout.ex`, `lib/lattice_stripe/balance_transaction.ex`
**Commits:** `4614b1c` (Payout), `e60f220` (BalanceTransaction), `10a8827` (BalanceTransaction message alignment)
**Applied fix:**

`Payout.update/4` and `update!/4`:
- Introduced explicit clause heads for `nil` and `""` that raise `ArgumentError` with `"Payout.update/4 requires a non-empty \"payout id\""` (resp. `update!/4`), ahead of the `is_binary(id)` clause. Matches the pattern already used by `Payout.retrieve/3`, `Payout.cancel/4`, and `Payout.reverse/4`.

`BalanceTransaction.retrieve/3` and `retrieve!/3`:
- Replaced the `when is_binary(id)` guard + body-level `if id == ""` with an `id in [nil, ""]` guarded clause that raises `ArgumentError` with `"BalanceTransaction.retrieve/3 requires a non-empty balance_transaction id"` (resp. `retrieve!/3`). Both `nil` and `""` now produce the friendly pre-network error instead of `FunctionClauseError`.
- Preserved the `balance_transaction id` wording (underscore) required by the existing test contract in `test/lattice_stripe/balance_transaction_test.exs:31` — caught on first `mix test --exclude integration` run and corrected in commit `10a8827`.

**Verification note:** WR-03 changes control-flow at function clause heads. Both `mix compile --warnings-as-errors` and the full non-integration suite pass, including the existing `retrieve/3 raises ArgumentError on empty id` pre-network test. No logic-bug flag required — behavior is exercised by tests.

## Skipped Issues

None.

---

_Fixed: 2026-04-12_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
