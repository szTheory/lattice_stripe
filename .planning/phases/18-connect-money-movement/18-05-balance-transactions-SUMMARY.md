---
phase: 18
plan: 05
subsystem: connect-money-movement
tags: [connect, balance, balance-transaction, reconciliation, fee-detail, singleton]
requirements: [CNCT-04, CNCT-05]
dependency_graph:
  requires:
    - 18-03-transfer (wave ordering only — no code coupling)
    - 18-04-payout (wave ordering only — no code coupling)
  provides:
    - LatticeStripe.Balance singleton (retrieve/2, retrieve!/2)
    - LatticeStripe.Balance.Amount nested typed struct (reused 5x)
    - LatticeStripe.Balance.SourceTypes typed-inner-open-outer struct
    - LatticeStripe.BalanceTransaction (retrieve/3, list/3, stream!/3, bang variants)
    - LatticeStripe.BalanceTransaction.FeeDetail nested typed struct
  affects:
    - 18-06 (integration guide + exdoc — now unblocked)
tech_stack:
  added: []
  patterns:
    - Singleton resource (no id, no list/create/update/delete)
    - Typed-inner-open-outer (P17 D-02) for future payment-method keys
    - Polymorphic source kept as raw binary | map() (D-05 rule 5)
key_files:
  created:
    - lib/lattice_stripe/balance.ex
    - lib/lattice_stripe/balance/amount.ex
    - lib/lattice_stripe/balance/source_types.ex
    - lib/lattice_stripe/balance_transaction.ex
    - lib/lattice_stripe/balance_transaction/fee_detail.ex
    - test/lattice_stripe/balance_test.exs
    - test/lattice_stripe/balance/amount_test.exs
    - test/lattice_stripe/balance/source_types_test.exs
    - test/lattice_stripe/balance_transaction_test.exs
    - test/lattice_stripe/balance_transaction/fee_detail_test.exs
    - test/support/fixtures/balance.ex
    - test/support/fixtures/balance_transaction.ex
    - test/support/fixtures/balance_transaction_fee_detail.ex
  modified: []
decisions:
  - "Balance is a singleton: no :id on defstruct, no list/create/update/delete functions; refute function_exported? guards in tests + grep guards in plan acceptance"
  - "Balance.Amount reused 5x across available/pending/connect_reserved/instant_available/issuing.available; proven by match?(%Amount{}, ...) assertions"
  - "net_available (instant_available[]-only) captured into Amount.extra per D-05 rule 1 — single module covers all 5 call-sites without branching"
  - "Balance.SourceTypes uses typed-inner-open-outer: stable {card, bank_account, fpx} inner shape, unknown payment-method keys (ach_credit_transfer, link, ...) flow into :extra"
  - "BalanceTransaction has retrieve/list/stream only — no create/update/delete because Stripe creates these server-side; exposing client-side mutators would be a footgun"
  - "BalanceTransaction.source kept as raw binary | map() per D-05 rule 5 — polymorphic across 16+ Stripe object types; users compose Charge/Transfer/Payout.from_map themselves"
  - "retrieve/3 raises ArgumentError pre-network on empty id (no mock setup needed in tests)"
metrics:
  tasks_completed: 2
  files_created: 13
  files_modified: 0
  tests_added: 52
  duration_minutes: 28
  completed_date: 2026-04-13
---

# Phase 18 Plan 05: Balance + BalanceTransactions Summary

Ships the Stripe Balance singleton and the BalanceTransaction read surface with shared typed nested structs, closing CNCT-05 and finishing the fee-reconciliation typed surface for CNCT-04.

## One-liner

Balance singleton (retrieve-only) and BalanceTransaction (retrieve/list/stream) with reusable Balance.Amount (5x reuse), typed-inner-open-outer Balance.SourceTypes, and FeeDetail nested structs for reconciliation.

## What was built

### Task 1 — Balance singleton (commit `5304b80`)

- `LatticeStripe.Balance` — no `:id`, no `list/create/update/delete`; exposes `retrieve/2` and `retrieve!/2`
- `LatticeStripe.Balance.Amount` — one nested typed struct, reused 5x across `available`, `pending`, `connect_reserved`, `instant_available`, and `issuing.available`
- `LatticeStripe.Balance.SourceTypes` — stable inner shape (`card`, `bank_account`, `fpx`) with `:extra` open outer for forward-compat with new Stripe payment-method keys
- `net_available` (instant_available-only field) lands in `Amount.extra` per D-05 rule 1, so one module covers all five call-sites without branching
- End-to-end `stripe_account:` opt threading verified via MockTransport: the opt reaches the transport layer as a `stripe-account` header
- Reconciliation loop antipattern documented prominently in the moduledoc with a warning callout (T-18-20 mitigation)

Tests: 27 passing across `balance_test.exs`, `balance/amount_test.exs`, `balance/source_types_test.exs`.

### Task 2 — BalanceTransaction + FeeDetail (commit `6873c5f`)

- `LatticeStripe.BalanceTransaction` — `retrieve/3`, `list/3`, `stream!/3` + bang variants; NO `create`, `update`, `delete` (Stripe-managed)
- `LatticeStripe.BalanceTransaction.FeeDetail` — `{amount, application, currency, description, type}` nested typed struct with `:extra` for new fee categories
- Reconciliation pattern verified end-to-end: `Enum.filter(bt.fee_details, &(&1.type == "application_fee"))`
- `source` stays as raw `binary | map()` per D-05 rule 5 — both string and expanded-map round-trip without crashing
- `retrieve/3` raises `ArgumentError` pre-network on empty id (no mock setup needed)
- `list/3` pass-through filters: `payout`, `source`, `type`, `currency`, `created` (no client-side rejection)

Tests: 25 passing across `balance_transaction_test.exs` and `balance_transaction/fee_detail_test.exs`.

## Verification

- `mix test test/lattice_stripe/balance_test.exs test/lattice_stripe/balance/amount_test.exs test/lattice_stripe/balance/source_types_test.exs test/lattice_stripe/balance_transaction_test.exs test/lattice_stripe/balance_transaction/fee_detail_test.exs --exclude integration` — 52 tests, 0 failures
- Full suite: `mix test --exclude integration` — 1386 tests, 0 failures (no regressions)
- `mix compile --warnings-as-errors` — clean
- `mix credo --strict` on all 5 new source files — 0 issues
- All plan acceptance grep guards pass (no `def create|update|delete`, no `:id`, no `Jason.Encoder`, path + helper references present)
- Reuse proof test: a single fixture's `available[0]`, `pending[0]`, `connect_reserved[0]`, `instant_available[0]`, `issuing.available[0]` all match `%LatticeStripe.Balance.Amount{}` (zero duplication)
- Reconciliation pattern test: `Enum.filter(bt.fee_details, &(&1.type == "application_fee"))` returns exactly one match against `with_application_fee` fixture

## Threat model coverage

| Threat | Mitigation |
|--------|------------|
| T-18-20 (silent wrong-answer in reconciliation loop) | Moduledoc warning callout + test asserts stripe_account opt reaches transport as `stripe-account` header |
| T-18-21 (F-001 unknown field loss) | All 5 modules use `Map.split`/`Map.drop` for `:extra`; round-trip tests assert synthetic future fields survive |
| T-18-22 (new payment-method type drops SourceTypes value) | Typed-inner-open-outer pattern; test asserts `"ach_credit_transfer" => 5000` survives in `:extra` |
| T-18-23 (accidental Balance.list/create) | `refute function_exported?` tests + grep guards + `:id` absence check |
| T-18-24 (accidental BalanceTransaction.create/update/delete) | `refute function_exported?` tests + grep guards |
| T-18-25 (polymorphic source forced into struct crash) | `source` kept as raw `binary | map()`; tests assert both string and expanded-map fixtures round-trip |
| T-18-26 (PII logging) | Accepted — neither object carries PII per RESEARCH.md PII table |

## Deviations from Plan

**None** — plan executed exactly as written. No Rule 1-3 auto-fixes required. The only micro-adjustment was dropping the plan's example `Resource.require_param!(id, ...)` call (wrong arity — it validates map keys, not scalar ids) in favor of a direct `raise ArgumentError` on empty id, which matches the documented behavior and tests.

## Known Stubs

None.

## Commits

- `5304b80` feat(18-05): add Balance singleton with Amount and SourceTypes nested structs
- `6873c5f` feat(18-05): add BalanceTransaction retrieve/list/stream + FeeDetail struct

## Self-Check: PASSED

- [x] `lib/lattice_stripe/balance.ex` FOUND
- [x] `lib/lattice_stripe/balance/amount.ex` FOUND
- [x] `lib/lattice_stripe/balance/source_types.ex` FOUND
- [x] `lib/lattice_stripe/balance_transaction.ex` FOUND
- [x] `lib/lattice_stripe/balance_transaction/fee_detail.ex` FOUND
- [x] `test/lattice_stripe/balance_test.exs` FOUND
- [x] `test/lattice_stripe/balance/amount_test.exs` FOUND
- [x] `test/lattice_stripe/balance/source_types_test.exs` FOUND
- [x] `test/lattice_stripe/balance_transaction_test.exs` FOUND
- [x] `test/lattice_stripe/balance_transaction/fee_detail_test.exs` FOUND
- [x] `test/support/fixtures/balance.ex` FOUND
- [x] `test/support/fixtures/balance_transaction.ex` FOUND
- [x] `test/support/fixtures/balance_transaction_fee_detail.ex` FOUND
- [x] Commit `5304b80` FOUND in git log
- [x] Commit `6873c5f` FOUND in git log
