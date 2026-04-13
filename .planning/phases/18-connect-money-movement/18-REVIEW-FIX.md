---
phase: 18-connect-money-movement
fixed_at: 2026-04-12T00:00:00Z
review_path: .planning/phases/18-connect-money-movement/18-REVIEW.md
iteration: 2
findings_in_scope: 5
fixed: 8
skipped: 0
status: all_fixed
---

# Phase 18: Code Review Fix Report

**Source review:** .planning/phases/18-connect-money-movement/18-REVIEW.md
**Iterations:** 2

**Summary across both iterations:**
- Total findings in REVIEW.md: 8 (0 critical, 3 warning, 5 info)
- Fixed: 8
- Skipped: 0
- Iteration 1 scope (critical+warning): 3 findings — all fixed
- Iteration 2 scope (info only): 5 findings — all fixed

Final verification after iteration 2:
- `mix compile --warnings-as-errors` — clean
- `mix test --exclude integration` — 1386 tests, 0 failures, 142 excluded
- `mix credo --strict` — 1138 mods/funs, 0 issues across 204 files

## Fixed Issues

### WR-01: Transfer / TransferReversal expandable fields missing `map()` in typespec

**Iteration:** 1
**Files modified:** `lib/lattice_stripe/transfer.ex`, `lib/lattice_stripe/transfer_reversal.ex`
**Commits:** `772795e` (Transfer), `fe9bbdd` (TransferReversal)
**Applied fix:** Updated `@type t` expandable fields to `String.t() | map() | nil`.
- `Transfer`: `balance_transaction`, `destination`, `destination_payment`, `source_transaction`
- `TransferReversal`: `balance_transaction`, `destination_payment_refund`, `source_refund`, `transfer`

Typespec-only correction to match the `expand: [...]` idiom documented in `guides/connect.md`.

### WR-02: Charge expandable fields `destination` and `source_transfer` missing `map()` in typespec

**Iteration:** 1
**Files modified:** `lib/lattice_stripe/charge.ex`
**Commit:** `c26187d`
**Applied fix:** Retyped `destination` and `source_transfer` from `String.t() | nil` to `String.t() | map() | nil`, matching the already-correct `balance_transaction` field on the same struct.

### WR-03: Inconsistent pre-network id validation on `Payout.update` and `BalanceTransaction.retrieve`

**Iteration:** 1
**Files modified:** `lib/lattice_stripe/payout.ex`, `lib/lattice_stripe/balance_transaction.ex`
**Commits:** `4614b1c` (Payout), `e60f220` (BalanceTransaction), `10a8827` (BalanceTransaction message alignment)
**Applied fix:**

`Payout.update/4` and `update!/4`:
- Added explicit `nil`/`""` clauses raising `ArgumentError` before the `is_binary(id)` clause.

`BalanceTransaction.retrieve/3` and `retrieve!/3`:
- Replaced `when is_binary(id)` + body-level `if id == ""` with `id in [nil, ""]` clause guards. Preserved the `balance_transaction id` wording required by `test/lattice_stripe/balance_transaction_test.exs:31`.

### IN-01: `BankAccount` moduledoc mentions `account_number` but struct has no such field

**Iteration:** 2
**Files modified:** `lib/lattice_stripe/bank_account.ex`
**Commit:** `b720afa`
**Applied fix:** Removed `account_number` from the hide-list (nothing to hide when the struct has no such field) and added a dedicated paragraph explaining the defensive-by-omission design: no `:account_number` field is defined, and any future Stripe payload containing one would land in `:extra` and never in `Inspect` output. The paragraph explicitly instructs future maintainers never to add `:account_number` to `defstruct`.

### IN-02: Inconsistent `nil`/`""` guard style across Phase 18

**Iteration:** 2
**Files modified:** `lib/lattice_stripe/charge.ex`, `lib/lattice_stripe/payout.ex`
**Commit:** `542fc1b`
**Applied fix:** Picked `when id in [nil, ""]` as the canonical idiom (concise, already used by `Transfer`, `TransferReversal`, and `BalanceTransaction` — the phase majority). Collapsed the separate `nil` / `""` clauses in `Charge.retrieve/3`, `Charge.retrieve!/3`, `Payout.retrieve/3`, `Payout.update/4`, `Payout.update!/4`, `Payout.cancel/4`, and `Payout.reverse/4` into single `id in [nil, ""]` clause heads. Error messages were preserved verbatim so the existing `~r/charge id/` and `~r/payout id/` test regexes continue to match.

**Judgment call — ExternalAccount left untouched:** `ExternalAccount` uses a private `validate_id!/2` helper rather than clause guards. This is kept deliberately: every id-taking function on `ExternalAccount` validates **two** ids (`account_id` *and* `id`), which cannot be expressed cleanly with a single clause guard like `when id in [nil, ""]` without introducing four separate clause heads per function. The helper is the right tool for that two-id shape. Post-fix the codebase has exactly two idioms: `when id in [nil, ""]` clause guards for single-id functions (canonical) and `validate_id!/2` for multi-id functions on `ExternalAccount`. The three-idiom drift called out in the review is gone.

### IN-03: `ExternalAccount.Unknown.cast/1` hardcodes string keys instead of deriving from `@known_fields`

**Iteration:** 2
**Files modified:** `lib/lattice_stripe/external_account/unknown.ex`
**Commit:** `00d618e`
**Applied fix:** `cast/1` now derives the drop list from `@known_fields` via `Enum.map(@known_fields, &Atom.to_string/1)` before calling `Map.drop/2`. If a future change adds an atom to `@known_fields`, the `:extra` split stays consistent automatically, matching the pattern already used by `balance/amount.ex`, `balance/source_types.ex`, `balance_transaction/fee_detail.ex`, and `payout/trace_id.ex`.

### IN-04: `Payout.update/4` and `update!/4` `when is_binary(id)` guard hides params misuse

**Iteration:** 2
**Files modified:** `lib/lattice_stripe/payout.ex`
**Commit:** `bdc4ab8`
**Applied fix:** Added `and is_map(params)` to the `is_binary(id)` guard on both `Payout.update/4` and `Payout.update!/4`, matching the guard style already used by `Transfer.update/4`. A keyword list or other non-map `params` now fails at the API boundary (`FunctionClauseError` from the head) rather than crashing deeper in `Client.request`. Note: the public contract is unchanged for well-behaved callers (a `%{}` params still matches).

### IN-05: `Transfer.from_map/1` falls through silently if `reversals` is a non-map non-`nil` value

**Iteration:** 2
**Files modified:** `lib/lattice_stripe/transfer.ex`
**Commit:** `ae1c85e`
**Applied fix:** Rewrote the `reversals` decode block into a single `case` that returns a `{reversal_structs, reversals_meta, reversals_raw}` tuple. The new `other ->` clause preserves any unexpected non-map non-nil value (e.g. `false`, a bare string) in `extra["reversals_raw"]` instead of silently dropping it, satisfying F-001 ("no data is silently lost") for this edge case. The normal Stripe wire format (map with `"data"` list) is untouched — it still flows through the first clause and produces the same `reversal_structs` + `reversals_meta` shape as before. Verified with `mix test --exclude integration test/lattice_stripe/transfer_test.exs` (23 tests, 0 failures).

## Skipped Issues

None.

---

_Fixed: 2026-04-12_
_Fixer: Claude (gsd-code-fixer)_
_Iterations: 1 and 2_
