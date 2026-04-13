---
phase: 18
plan: 01
subsystem: connect-money-movement
tags: [connect, external-account, polymorphic, bank-account, card, pii]
requirements: [CNCT-02]
requires:
  - LatticeStripe.Client
  - LatticeStripe.Request
  - LatticeStripe.Response
  - LatticeStripe.List
  - LatticeStripe.Resource (unwrap_singular/2, unwrap_list/2, unwrap_bang!/1)
provides:
  - LatticeStripe.BankAccount (struct, cast/1, from_map/1, Inspect)
  - LatticeStripe.Card (struct, cast/1, from_map/1, Inspect)
  - LatticeStripe.ExternalAccount (polymorphic CRUDL dispatcher)
  - LatticeStripe.ExternalAccount.Unknown (forward-compat fallback)
affects:
  - Downstream plans 18-03/18-04/18-05 can call BankAccount.cast/1 and
    Card.cast/1 to type expanded Payout.destination / BalanceTransaction.source
    fields without circular dependencies.
tech-stack:
  added: []
  patterns:
    - "F-001 extra map on BankAccount, Card, Unknown"
    - "Polymorphic dispatch via pattern-match on string-keyed 'object' discriminator"
    - "PII-safe defimpl Inspect with allow-list of fields"
    - "Pre-network validate_id!/2 ArgumentError guard"
key-files:
  created:
    - lib/lattice_stripe/bank_account.ex
    - lib/lattice_stripe/card.ex
    - lib/lattice_stripe/external_account.ex
    - lib/lattice_stripe/external_account/unknown.ex
    - test/lattice_stripe/bank_account_test.exs
    - test/lattice_stripe/card_test.exs
    - test/lattice_stripe/external_account_test.exs
    - test/support/fixtures/bank_account_fixtures.ex
    - test/support/fixtures/card_fixtures.ex
    - test/support/fixtures/external_account_fixtures.ex
  modified: []
decisions:
  - "D-01 polymorphism shape locked: ExternalAccount.cast/1 pattern-matches on the string-keyed 'object' discriminator and delegates to BankAccount.cast/1 or Card.cast/1; novel types fall through to ExternalAccount.Unknown"
  - "D-04 no atom guards: cast/1 only matches 'bank_account' and 'card' string literals; Unknown branch absorbs any other 'object' value; no String.to_existing_atom at the dispatch layer"
  - "Pre-network validate_id!/2 replaces Resource.require_param! for scalar id arguments — require_param! only checks Map.has_key? and cannot enforce non-empty binary on a positional arg"
  - "cast/1 is wired through BOTH singular unwraps AND list/stream unwraps; each list item runs through the same dispatcher so mixed paginated responses return [%BankAccount{}, %Card{}, %Unknown{}] transparently"
  - "DELETE responses flow 'deleted' => true into the sum-type struct's :extra map (no separate DeletedExternalAccount type); callers detect deletion via pattern match on extra"
metrics:
  duration_minutes: ~15
  tasks_completed: 2
  tests_added: 38
  files_created: 10
  files_modified: 0
completed_at: "2026-04-12"
---

# Phase 18 Plan 01: External Account Summary

Polymorphic Stripe Connect external-account surface — `BankAccount` + `Card` sum type with a forward-compat `Unknown` fallback, a single `ExternalAccount` dispatcher owning all CRUDL under `/v1/accounts/:account/external_accounts`, and PII-safe `Inspect` that never leaks routing/account numbers, fingerprints, `last4`, or card expiry.

## What shipped

### `LatticeStripe.BankAccount`

- 16 known fields matching the Stripe `bank_account` object (id, object, account, account_holder_name, account_holder_type, account_type, available_payout_methods, bank_name, country, currency, customer, default_for_currency, fingerprint, last4, metadata, routing_number, status).
- `cast/1` + `from_map/1` (alias); `cast(nil) -> nil`.
- F-001 forward-compat: unknown keys preserved in `:extra` via `Map.drop/2` against `@known_fields` (string sigil, matches Jason's string keys).
- `defimpl Inspect` shows **only** `id, object, bank_name, country, currency, status`. Tested via `refute` against literal `routing_number`, `account_number`, `fingerprint`, `last4`, and `account_holder_name` values (T-18-01 mitigation).
- Not `Jason.Encoder`-derived.

### `LatticeStripe.Card`

- 27 known fields matching the Stripe `card` object (full `address_*`, `exp_month`, `exp_year`, `cvc_check`, `dynamic_last4`, `tokenization_method`, etc.).
- Same `cast/1` + F-001 pattern.
- `defimpl Inspect` shows **only** `id, object, brand, country, funding`. Tested via `refute` against `last4`, `fingerprint`, `exp_year`, cardholder `name`, and the literal field-name substrings `exp_month`/`exp_year`/`last4`/`fingerprint` (T-18-02 mitigation).
- Not `Jason.Encoder`-derived.

### `LatticeStripe.ExternalAccount.Unknown`

- Nested struct using the `~w(id object)a` atom sigil (Pattern 2 from RESEARCH.md — matches `Account.Capability`).
- `cast/1` preserves `id` and `object` as top-level fields and stuffs everything else into `:extra`.
- Guarantees the polymorphic dispatcher never crashes on novel Stripe object types (T-18-03 mitigation).

### `LatticeStripe.ExternalAccount` dispatcher

- `cast/1` with four clauses: `nil`, `"bank_account"`, `"card"`, and `"object" => _other` → `Unknown`.
- Full CRUDL surface — every function takes `account_id` as the second positional arg:
  - `create/4`, `retrieve/4`, `update/5`, `delete/4`, `list/4`, `stream!/4`
  - Bang variants: `create!/4`, `retrieve!/4`, `update!/5`, `delete!/4`, `list!/4`
- Singular operations unwrap via `Resource.unwrap_singular(&cast/1)`, lists via `Resource.unwrap_list(&cast/1)`, and `stream!/4` pipes `List.stream!/2` through `Stream.map(&cast/1)` so every item in a paginated response is correctly typed.
- `validate_id!/2` pre-network guard raises `ArgumentError` immediately on empty/nil/non-binary `account_id` or `id`, so error-path tests need no mock setup. `Resource.require_param!/3` only checks `Map.has_key?` and cannot enforce non-empty-binary on a positional scalar argument — flagged as an execution-time decision.

### Test coverage (38 tests, 0 failures)

- **BankAccount** (7): cast happy path, nil, F-001 unknown fields, DELETE→:extra round-trip, `from_map` alias, Inspect PII allow-list, Inspect PII refute-list.
- **Card** (7): same structure.
- **ExternalAccount** (24): four `cast/1` branches, every CRUDL verb with URL+method assertions against `LatticeStripe.MockTransport`, mixed-list returning `[%BankAccount{}, %Card{}, %Unknown{}]`, filter params pass-through, `stream!/4` laziness, `ArgumentError` guards on both empty `account_id` and empty `id`, bang-variant success + failure, `Unknown.cast/1` directly.

## Deviations from Plan

### [Rule 3 - Blocker] `Resource.require_param!/3` cannot enforce non-empty binary on positional id arguments

- **Found during:** Task 2 implementation
- **Issue:** Plan says `Resource.require_param!(%{"id" => account_id}, "id", ...)`. Inspecting `lib/lattice_stripe/resource.ex` showed `require_param!/3` only checks `Map.has_key?/2` — it never inspects the value. A map `%{"id" => ""}` would pass the guard, and the plan required "argerror on empty/nil account_id".
- **Fix:** Added a private `validate_id!/2` inside `ExternalAccount` that raises `ArgumentError` on any value that is not a non-empty binary. Applied to both `account_id` and `id` arguments in every verb. Test `raises ArgumentError when account_id is empty` (in `create/4`) and `raises ArgumentError when id is empty` (in `retrieve/4`) cover it.
- **Files modified:** lib/lattice_stripe/external_account.ex
- **Commit:** 91148ac

### [Rule 2 - Critical] Additional `name` substring refute in Card Inspect test

- **Found during:** Task 1 test authoring
- **Issue:** Plan enumerated `last4, dynamic_last4, fingerprint, exp_month, exp_year, address_*_check, cvc_check, name, address_*` as hidden fields, but the "acceptance criteria" test list only asked for `"4242"`, `"fp_abc"`, `"12"`, `"2030"` literal refutes. To actually lock PII, the test asserts the cardholder `name` literal (`"Jane Doe"`) is absent, plus the field-name substrings `exp_month`, `exp_year`, `last4`, `fingerprint` are absent from the rendered output (belt + braces — would fail if someone added them back to the Inspect allow-list).
- **Fix:** Added `refute out =~ "Jane Doe"` and field-name substring refutes to `Card`'s Inspect test.
- **Files modified:** test/lattice_stripe/card_test.exs
- **Commit:** f775aff (Task 1)

### [Rule 3 - Blocker] Worktree baseline mismatch

- **Found during:** Start of plan
- **Issue:** The worktree was created from an older commit (`21e63fe`, the Phase 14-16 billing merge). `git reset --soft $EXPECTED_BASE` moved HEAD to `99b0d66` but left the working tree at `21e63fe`, causing phase-17 files to appear as "D" in `git status` and phase-18 plan files to be missing from disk.
- **Fix:** Ran `git checkout 99b0d66 -- .` to sync the working tree to the declared base, then copied `18-01-external-account-PLAN.md` from the main repo worktree into the branch worktree so the plan file was actually on disk to read.
- **Files modified:** none (infrastructure recovery)
- **Commit:** n/a — not committed, plan file is just a read-only reference

## Threat Surface Scan

All files created in this plan are covered by the plan's `<threat_model>`. No new trust boundaries introduced. No `Threat Flags` section needed.

## Commands run in verification

```
mix test test/lattice_stripe/bank_account_test.exs \
         test/lattice_stripe/card_test.exs \
         test/lattice_stripe/external_account_test.exs --exclude integration
# 38 tests, 0 failures

mix compile --warnings-as-errors
# clean

mix credo --strict lib/lattice_stripe/bank_account.ex \
                   lib/lattice_stripe/card.ex \
                   lib/lattice_stripe/external_account.ex \
                   lib/lattice_stripe/external_account/unknown.ex
# 31 mods/funs, found no issues

grep -q '@known_fields' lib/lattice_stripe/bank_account.ex       # ok
grep -q 'routing_number' lib/lattice_stripe/bank_account.ex      # ok (in @known_fields)
grep -q 'defimpl Inspect, for: LatticeStripe.BankAccount' ...    # ok
grep -q 'defimpl Inspect, for: LatticeStripe.Card' ...           # ok
! grep -q 'Jason.Encoder' lib/lattice_stripe/bank_account.ex     # ok
! grep -q 'Jason.Encoder' lib/lattice_stripe/card.ex             # ok
! grep -q 'Jason.Encoder' lib/lattice_stripe/external_account.ex # ok
grep -q '/v1/accounts/.*external_accounts' lib/.../external_account.ex # ok
grep -q 'def create!' lib/lattice_stripe/external_account.ex     # ok
```

## Known Stubs

None. Every module has real behavior wired and unit-tested against `LatticeStripe.MockTransport`.

## Commits

- `f775aff` feat(18-01): add BankAccount + Card structs with F-001 and PII Inspect
- `91148ac` feat(18-01): add ExternalAccount polymorphic dispatcher + Unknown fallback

## Self-Check: PASSED

- `lib/lattice_stripe/bank_account.ex` — FOUND
- `lib/lattice_stripe/card.ex` — FOUND
- `lib/lattice_stripe/external_account.ex` — FOUND
- `lib/lattice_stripe/external_account/unknown.ex` — FOUND
- `test/lattice_stripe/bank_account_test.exs` — FOUND
- `test/lattice_stripe/card_test.exs` — FOUND
- `test/lattice_stripe/external_account_test.exs` — FOUND
- `test/support/fixtures/bank_account_fixtures.ex` — FOUND
- `test/support/fixtures/card_fixtures.ex` — FOUND
- `test/support/fixtures/external_account_fixtures.ex` — FOUND
- Commit `f775aff` — FOUND
- Commit `91148ac` — FOUND
