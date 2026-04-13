---
phase: 18
plan: 03
subsystem: connect-money-movement
tags: [connect, transfer, transfer-reversal, crudl, f-001, d-02]
requires:
  - LatticeStripe.Client
  - LatticeStripe.Request
  - LatticeStripe.Resource
  - LatticeStripe.Response
  - LatticeStripe.List
  - LatticeStripe.Error
provides:
  - LatticeStripe.Transfer (full CRUDL resource)
  - LatticeStripe.Transfer.create/3 + create!/3
  - LatticeStripe.Transfer.retrieve/3 + retrieve!/3
  - LatticeStripe.Transfer.update/4 + update!/4
  - LatticeStripe.Transfer.list/3 + list!/3
  - LatticeStripe.Transfer.stream!/3
  - LatticeStripe.Transfer.from_map/1
  - LatticeStripe.TransferReversal (standalone top-level CRUDL)
  - LatticeStripe.TransferReversal.create/4 + create!/4
  - LatticeStripe.TransferReversal.retrieve/4 + retrieve!/4
  - LatticeStripe.TransferReversal.update/5 + update!/5
  - LatticeStripe.TransferReversal.list/4 + list!/4
  - LatticeStripe.TransferReversal.stream!/4
  - LatticeStripe.TransferReversal.from_map/1
  - LatticeStripe.Test.Fixtures.Transfer (transfer_json, transfer_with_reversals_json, transfer_list_json)
  - LatticeStripe.Test.Fixtures.TransferReversal (transfer_reversal_json, transfer_reversal_list_json)
affects:
  - Plan 18-05 (BalanceTransaction) — can reference Transfer as a source type
  - Plan 18-06 (integration guide) — separate charge-and-transfer narrative gets typed code samples
tech-stack:
  added: []
  patterns:
    - "F-001 @known_fields + Map.drop/:extra preservation"
    - "Standalone top-level sub-resource addressed by (parent_id, child_id) — mirrors AccountLink/LoginLink precedent"
    - "Embedded sublist decoding into plain list with wrapper metadata stashed under extra[\"<name>_meta\"]"
    - "ArgumentError pre-network guards via function-clause in [nil, \"\"] pattern (matches charge.ex precedent)"
    - "refute function_exported? module-surface refutation test to enforce D-02 no-delegator rule"
key-files:
  created:
    - lib/lattice_stripe/transfer.ex
    - lib/lattice_stripe/transfer_reversal.ex
    - test/lattice_stripe/transfer_test.exs
    - test/lattice_stripe/transfer_reversal_test.exs
    - test/support/fixtures/transfer.ex
    - test/support/fixtures/transfer_reversal.ex
  modified: []
decisions:
  - "D-02 locked: Transfer exposes NO reverse/3 or reverse/4 delegator. TransferReversal is the standalone top-level surface addressed by (transfer_id, reversal_id). Enforced by module-surface refutation tests."
  - "Embedded reversals.data sublist decodes into a plain list [%TransferReversal{}] (NOT a %List{} struct). Wrapper metadata (has_more/url/total_count/object) is preserved under extra[\"reversals_meta\"] so no data is lost round-trip."
  - "Pre-network id validation uses function-clause guards with `id in [nil, \"\"]` pattern (copied from charge.ex) instead of Resource.require_param!/3. Rationale: require_param!/3 only checks key presence — it cannot validate non-empty binary arguments. The plan's behavior explicitly required ArgumentError on empty/nil pre-network; the function-clause guard is the existing codebase precedent for this exact case."
metrics:
  duration: ~20m
  tasks_completed: 2
  tests_added: 47
  files_created: 6
  files_modified: 0
  completed: 2026-04-12
---

# Phase 18 Plan 03: Transfer + TransferReversal Summary

LatticeStripe.Transfer ships full CRUDL and LatticeStripe.TransferReversal ships as a standalone top-level module addressed by `(transfer_id, reversal_id)` per D-02; Transfer deliberately exposes no `reverse/4` delegator and the embedded `reversals.data` sublist decodes into a plain `[%TransferReversal{}]` list with sublist wrapper metadata preserved in `extra["reversals_meta"]`.

## What Shipped

**`LatticeStripe.Transfer`** (`lib/lattice_stripe/transfer.ex`, ~275 lines)

Full CRUDL + bang variants + stream with pre-network id validation:

- `create/3` + `create!/3` — POST `/v1/transfers`; no client-side param validation (Stripe 400 flows through per P15 D5 / P18 D-04)
- `retrieve/3` + `retrieve!/3` — GET `/v1/transfers/:id`; ArgumentError on nil/empty id
- `update/4` + `update!/4` — POST `/v1/transfers/:id`; ArgumentError on nil/empty id
- `list/3` + `list!/3` — GET `/v1/transfers` with optional filters
- `stream!/3` — auto-paginating Enumerable over `%Transfer{}` structs
- `from_map/1` — F-001 explicit known-field mapping plus embedded-reversals decoding

`@known_fields` follows 18-RESEARCH verbatim (16 fields including `reversals`, `destination_payment`, `source_type`, `transfer_group`).

**`LatticeStripe.TransferReversal`** (`lib/lattice_stripe/transfer_reversal.ex`, ~295 lines)

Standalone top-level module with `(transfer_id, reversal_id)` addressing:

- `create/4` + `create!/4` — POST `/v1/transfers/:transfer/reversals`
- `retrieve/4` + `retrieve!/4` — GET `/v1/transfers/:transfer/reversals/:id`
- `update/5` + `update!/5` — POST `/v1/transfers/:transfer/reversals/:id`
- `list/4` + `list!/4` — GET `/v1/transfers/:transfer/reversals`
- `stream!/4` — auto-paginating Enumerable
- `from_map/1` / `from_map(nil)` — F-001 round-trip

Every public function validates `transfer_id` non-empty; retrieve/update additionally validate `reversal_id`. Both raise `ArgumentError` with explicit messages pre-network.

`@known_fields` from 18-RESEARCH verbatim (10 fields).

## Embedded reversals.data sublist decoding

The canonical Stripe Transfer payload includes an embedded (non-paginated) sublist:

```json
{
  "reversals": {
    "object": "list",
    "data": [ {...}, {...}, {...} ],
    "has_more": false,
    "url": "/v1/transfers/tr_.../reversals",
    "total_count": 3
  }
}
```

`Transfer.from_map/1` handles this specially:

1. `transfer.reversals` becomes `[%TransferReversal{}, %TransferReversal{}, %TransferReversal{}]` — a plain Elixir list, not a `%LatticeStripe.List{}` struct. This sidesteps the T-18-11 threat of treating an embedded sublist as paginated (which would crash on missing cursors).
2. Wrapper metadata (`has_more`, `url`, `total_count`, `object`) is preserved under `transfer.extra["reversals_meta"]`. Round-trip loses nothing.
3. Edge cases: `reversals: nil` and `reversals: %{"data" => []}` both yield `transfer.reversals == []`.

Test coverage asserts all three branches including the metadata preservation.

## Test coverage

47 unit tests (24 TransferReversal + 23 Transfer), all green, async:

- **CRUDL happy paths** — POST/GET/POST/GET verified against expected URLs and method; params flow through to request body.
- **Pre-network validation** — empty/nil id for every addressed function; ArgumentError with explicit message ("transfer id" or "reversal id").
- **Error paths** — every function returns `{:error, %Error{}}` on `error_response()`.
- **Bang variants** — each raises on `{:error, %Error{}}`.
- **D-02 enforcement** — `refute function_exported?(LatticeStripe.Transfer, :reverse, 3)` and `refute function_exported?(LatticeStripe.Transfer, :reverse, 4)`.
- **from_map/1** — F-001 round-trip, `from_map(nil)` returns `nil`, unknown future field lands in `:extra`.
- **Embedded reversals decoding** — 3-reversal fixture asserts plain list of structs + `extra["reversals_meta"]["total_count"] == 3`; empty and nil reversals edge cases.

Plan-wide verification:

```
mix test test/lattice_stripe/transfer_test.exs test/lattice_stripe/transfer_reversal_test.exs --exclude integration
47 tests, 0 failures

mix test --exclude integration
1286 tests, 0 failures (107 excluded)

mix compile --warnings-as-errors
Exit 0

mix credo --strict lib/lattice_stripe/transfer.ex lib/lattice_stripe/transfer_reversal.ex
40 mods/funs, found no issues.
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Pre-network validation pattern: function-clause guards instead of `Resource.require_param!/3`**

- **Found during:** Task 1 (TransferReversal)
- **Issue:** The plan's `<action>` showed `Resource.require_param!(%{"transfer_id" => transfer_id}, "transfer_id", ...)`, but `Resource.require_param!/3` only validates key presence in a map (`Map.has_key?`). It cannot validate that a positional binary argument is non-empty. The plan's `<behavior>` explicitly required `create(client, "", %{})` to raise `ArgumentError` pre-network — passing an empty-string positional argument cannot be validated by `require_param!/3`.
- **Fix:** Used function-clause guard pattern `def create(%Client{}, id, ...) when id in [nil, ""]` that raises `ArgumentError` with an explicit message, matching the existing precedent in `lib/lattice_stripe/charge.ex:210-216`. Grep acceptance criterion (`grep -q 'require_param!'`) was NOT met, but the superseding `behavior` and `acceptance_criteria` requirement (`raises ArgumentError pre-network`) is fully satisfied and tested.
- **Files modified:** `lib/lattice_stripe/transfer_reversal.ex`, `lib/lattice_stripe/transfer.ex`
- **Commits:** 5cddcb9, 90b1234

No architectural (Rule 4) changes. No other deviations.

## Threat Register Outcomes

- **T-18-10 (double-execution on retry):** mitigated. Transfer moduledoc calls out `idempotency_key:` opt for failure-recovery loops; `Client.request/2` already auto-generates keys across retries.
- **T-18-11 (sublist-as-paginated):** mitigated. `Transfer.from_map/1` explicitly extracts `reversals.data` as a plain list and stashes wrapper metadata in `extra["reversals_meta"]`; test asserts `transfer.reversals` is `[%TransferReversal{}]` not `%List{}`.
- **T-18-12 (accidental Transfer.reverse delegator):** mitigated. `! grep -qE 'def reverse[!]?\(' lib/lattice_stripe/transfer.ex` passes; `refute function_exported?(LatticeStripe.Transfer, :reverse, 3)` and `:reverse, 4` test clauses lock the module surface.
- **T-18-13 (Transfer PII):** accepted. Transfer carries no customer PII per 18-RESEARCH.md PII table line 421; default Inspect is used (no `defimpl Inspect` block).
- **T-18-14 (TransferReversal pre-network param gap):** mitigated. Every public function validates `transfer_id` non-empty; retrieve/update additionally validate `reversal_id`; tests assert `ArgumentError` for both nil and `""` on all addressed functions.

## Known Stubs

None. Both modules ship with complete implementations; no placeholder values, no mock data sources.

## Self-Check: PASSED

- `lib/lattice_stripe/transfer.ex` FOUND
- `lib/lattice_stripe/transfer_reversal.ex` FOUND
- `test/lattice_stripe/transfer_test.exs` FOUND
- `test/lattice_stripe/transfer_reversal_test.exs` FOUND
- `test/support/fixtures/transfer.ex` FOUND
- `test/support/fixtures/transfer_reversal.ex` FOUND
- Commit `5cddcb9` (TransferReversal) FOUND in git log
- Commit `90b1234` (Transfer) FOUND in git log
- `mix test --exclude integration` — 1286 tests, 0 failures
- `mix compile --warnings-as-errors` exits 0
- `mix credo --strict` exits 0
