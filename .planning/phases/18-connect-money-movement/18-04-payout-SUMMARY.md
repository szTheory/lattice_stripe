---
phase: 18-connect-money-movement
plan: 04
subsystem: payments
tags: [stripe, connect, payout, trace-id, cancel, reverse, f-001]

# Dependency graph
requires:
  - phase: 18-connect-money-movement
    provides: Wave 1 ExternalAccount + BankAccount + Card modules (declared wave-ordering dependency only; Plan 04 does not import them)
provides:
  - LatticeStripe.Payout full CRUDL + stream!/3 + bang variants
  - Payout.cancel/4 and Payout.reverse/4 with D-03 canonical (client, id, params \\ %{}, opts \\ []) signature
  - LatticeStripe.Payout.TraceId nested typed struct ({status, value, extra}) with cast/1
  - Payout.from_map/1 decodes trace_id into typed struct; destination/balance_transaction stay as expandable binary|map refs per D-05 rule 7
affects: [18-05-balance-transactions, 18-06-integration-guide-exdoc]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "D-03 canonical (client, id, params \\\\ %{}, opts \\\\ []) shape on action endpoints (cancel/reverse) — params default is mandatory to avoid future breaking change when users need expand:/metadata:"
    - "D-04 zero atom-guarded dispatchers — enum params (method, source_type) stay in params map as plain atoms typed via @spec only"
    - "D-05 nested typed struct budget: Payout.TraceId is 1 of 4 new nested modules in Phase 18"
    - "F-001 round-trip via Map.drop(map, @known_fields) + extra: %{} default"
    - "Pre-network ArgumentError on nil/empty id via multi-clause function dispatch (Charge.retrieve template)"

key-files:
  created:
    - lib/lattice_stripe/payout.ex
    - lib/lattice_stripe/payout/trace_id.ex
    - test/lattice_stripe/payout_test.exs
    - test/lattice_stripe/payout/trace_id_test.exs
    - test/support/fixtures/payout.ex
    - test/support/fixtures/payout_trace_id.ex
  modified: []

key-decisions:
  - "D-03 canonical shape enforced on both cancel/4 and reverse/4 with function_exported? arity-2/arity-4/arity-5 guards in tests"
  - "D-04 no atom-guarded variants — module surface test refutes function_exported?(Payout, :cancel, 5) and same for :reverse"
  - "D-05 Payout.TraceId implemented via atom-sigil @known_fields ~w(status value)a following Account.Capability template (nested structs use atom sigil; top-level Payout uses string sigil to match Jason's string-key output)"
  - "Pre-network id validation uses multi-clause dispatch (retrieve(%Client{}, nil, _opts) | retrieve(%Client{}, \"\", _opts)) rather than Resource.require_param!/3 because require_param!/3 only checks map key presence, not value emptiness — matches the existing Charge.retrieve template"
  - "Expandable references (destination, balance_transaction, failure_balance_transaction) typed as binary() | map() | nil and kept raw per D-05 rule 7; moduledoc documents the 'expand then cast via expected module' idiom"

patterns-established:
  - "Nested typed struct with atom-sigil @known_fields + Enum.map(&Atom.to_string/1) bridge in cast/1 (Account.Capability template, reusable for Balance.Amount / Balance.SourceTypes / BalanceTransaction.FeeDetail in Waves 3)"
  - "D-03 canonical action-verb shape: (client, id, params \\\\ %{}, opts \\\\ []) with multi-clause nil/empty guards + when is_binary(id) clause — direct template for future standalone action verbs (TransferReversal.* etc.)"

requirements-completed: [CNCT-02]

# Metrics
duration: ~20 min
completed: 2026-04-13
---

# Phase 18 Plan 04: Payout CRUDL + Cancel + Reverse Summary

**LatticeStripe.Payout full CRUDL + D-03 canonical cancel/reverse with %Payout.TraceId{} typed nested struct decoded from trace_id field.**

## Performance

- **Duration:** ~20 min (single-session autonomous execution)
- **Completed:** 2026-04-13T01:50:39Z
- **Tasks:** 2 / 2
- **Files created:** 6

## Accomplishments

- `LatticeStripe.Payout` ships with full CRUDL (`create/3`, `retrieve/3`, `update/4`, `list/3`, `stream!/3`) + bang variants + `cancel/4` + `reverse/4` + `from_map/1`.
- `cancel/4` and `reverse/4` both implement D-03 canonical `(client, id, params \\ %{}, opts \\ [])` shape. The `params` default means `Payout.cancel(client, "po_x")` is ergonomic today AND dropping `expand:` into the third arg tomorrow is not a breaking change.
- `LatticeStripe.Payout.TraceId` nested typed struct (2 known fields: `status`, `value`, plus `:extra` for F-001) ships per D-05. The `status` field is a clear pattern-match target documented in the moduledoc; a dedicated test asserts the `case payout.trace_id do %TraceId{status: "supported", value: v} -> ...` idiom compiles and runs.
- Zero atom-guarded dispatch variants (D-04) — module surface tests refute `function_exported?(Payout, :cancel, 5)` and same for `:reverse`, guarding against a future contributor slipping in a `method` atom-guarded overload.
- F-001 round-trip verified: unknown future fields from Stripe land in `:extra` on both `%Payout{}` and `%Payout.TraceId{}`.
- Pre-network `ArgumentError` on `nil`/empty id for `retrieve`, `cancel`, and `reverse` via multi-clause function dispatch (matching the existing `Charge.retrieve` template).

## Task Commits

1. **Task 1: Payout.TraceId nested typed struct** — `52f6d11` (feat)
2. **Task 2: Payout CRUDL + cancel + reverse + TraceId integration** — `79605ae` (feat)

_TDD flow: both tasks followed RED → GREEN; no REFACTOR commits needed (generated code was clean on first pass, credo --strict reported 0 issues on both files)._

## Files Created

- `lib/lattice_stripe/payout.ex` — Full Payout resource module (403 lines). CRUDL + cancel + reverse + bang variants + from_map/1 with TraceId decoding.
- `lib/lattice_stripe/payout/trace_id.ex` — Nested typed struct (56 lines). `@known_fields ~w(status value)a` + `:extra` + `cast/1`.
- `test/lattice_stripe/payout_test.exs` — 40 unit tests covering CRUDL, D-03 signature guards, cancel/reverse default params + expand + metadata, trace_id decoding, expandable references, F-001, bang variants, module surface D-04 guards.
- `test/lattice_stripe/payout/trace_id_test.exs` — 8 unit tests covering cast/1 happy paths, nil input, F-001 unknown-key preservation, documented pattern-match idiom.
- `test/support/fixtures/payout.ex` — `LatticeStripe.Test.Fixtures.Payout` with `basic/1`, `with_trace_id/1`, `pending/1`, `cancelled/1`, `reversed/1`, `with_destination_string/1`, `with_destination_expanded/1`, `list_response/1`.
- `test/support/fixtures/payout_trace_id.ex` — `LatticeStripe.Test.Fixtures.PayoutTraceId` with `supported/1`, `pending/1`, `unsupported/1`.

## Decisions Made

All decisions were already locked in CONTEXT.md (D-03, D-04, D-05). One implementation-detail clarification was resolved inline:

- **Pre-network id validation:** `Resource.require_param!/3` only checks `Map.has_key?/2` — it accepts `nil` and `""` values as "present". To enforce non-empty ids, used the existing `Charge.retrieve` multi-clause-dispatch template (`def cancel(%Client{}, nil, _, _)` + `def cancel(%Client{}, "", _, _)` raising `ArgumentError`). This matches the template already in the codebase and avoids adding a new helper.
- **Exception to the plan's acceptance-criterion wording:** The plan's acceptance criterion referenced `Resource.require_param!(%{"id" => id}, "id", ...)` — but wrapping id as a synthetic map still wouldn't catch `%{"id" => ""}`. The multi-clause approach is strictly stronger (validates value, not key presence) and is already the codebase precedent. Tests assert the behaviour (`ArgumentError` on both `nil` and `""`) which is what actually matters.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Strengthened id validation from key-presence to value-emptiness**
- **Found during:** Task 2 implementation (reading `Resource.require_param!/3`)
- **Issue:** The plan specified `Resource.require_param!(%{"id" => id}, "id", ...)` for `cancel/4` and `reverse/4` pre-network validation. But `require_param!/3` only checks `Map.has_key?/2` — it would silently accept `id = ""` (the key is present, the value is empty string). That would push an empty-segment URL like `/v1/payouts//cancel` onto the wire.
- **Fix:** Used the existing `Charge.retrieve` multi-clause-dispatch template — `def cancel(%Client{}, nil, _, _)` and `def cancel(%Client{}, "", _, _)` raise `ArgumentError` before any network call. Same for `reverse/4` and `retrieve/3`. Matches the already-committed codebase pattern in `lib/lattice_stripe/charge.ex:208-222`.
- **Files modified:** lib/lattice_stripe/payout.ex
- **Verification:** Tests `raises ArgumentError on empty id` and `raises ArgumentError on nil id` pass for all three action verbs (retrieve, cancel, reverse).
- **Committed in:** 79605ae (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 2 — missing critical correctness guard)
**Impact on plan:** Strictly stronger than specified. No scope creep. No new helper added.

## Issues Encountered

- None. stripe-mock not used (Wave 2 integration tests are scoped to a separate plan, 18-06).

## Threat Model Compliance

All STRIDE entries in the plan's `<threat_model>` are mitigated as specified:

| Threat ID | Disposition | Evidence |
|-----------|-------------|----------|
| T-18-15 (double-execution on retry) | mitigate | `Client.request/2` idempotency infra unchanged; moduledoc Idempotency section documents `idempotency_key:` opt. |
| T-18-16 (dropping `params \\ %{}` from cancel/reverse) | mitigate | D-03 canonical shape tests: `function_exported?(Payout, :cancel, 2)` AND `function_exported?(Payout, :cancel, 4)` both TRUE. Same for `reverse`. |
| T-18-17 (F-001 unknown field loss) | mitigate | Round-trip tests on both `%Payout{}` and `%Payout.TraceId{}` assert synthetic future keys survive in `:extra`. |
| T-18-18 (Payout PII logging) | accept | No PII in Payout object; default Inspect acceptable (no custom defimpl Inspect needed). |
| T-18-19 (atom-guarded overloads slipping in) | mitigate | Module surface test: `refute function_exported?(Payout, :cancel, 5)` AND `refute function_exported?(Payout, :reverse, 5)`. |

No new threat flags introduced. No net-new network endpoints beyond those planned; no new auth paths or file access; no schema changes.

## Known Stubs

None. All fields are either fully typed (`%Payout{}`, `%Payout.TraceId{}`), explicitly documented as expandable polymorphic refs (`destination`, `balance_transaction`, `failure_balance_transaction` — see D-05 rule 7 in 18-CONTEXT.md), or preserved in `:extra` per F-001.

## Next Plan Readiness

- Plan 18-05 (Balance + BalanceTransaction) can proceed — Payout is the upstream for per-payout `BalanceTransaction.list(client, %{payout: po.id})` reconciliation. No code dependency (BalanceTransaction filters by payout id string, not `%Payout{}`), but the example in the moduledoc for 18-05 can reference the Payout module.
- Plan 18-06 (integration tests + guide + ExDoc) has the full `LatticeStripe.Payout` surface to exercise against stripe-mock.

## Self-Check: PASSED

Files exist:
- FOUND: lib/lattice_stripe/payout.ex
- FOUND: lib/lattice_stripe/payout/trace_id.ex
- FOUND: test/lattice_stripe/payout_test.exs
- FOUND: test/lattice_stripe/payout/trace_id_test.exs
- FOUND: test/support/fixtures/payout.ex
- FOUND: test/support/fixtures/payout_trace_id.ex

Commits exist:
- FOUND: 52f6d11 (Task 1: Payout.TraceId)
- FOUND: 79605ae (Task 2: Payout CRUDL + cancel + reverse)

Full test suite: 1287 tests, 0 failures (107 integration tests excluded as expected for Wave 2).
Credo --strict: 0 issues across `lib/lattice_stripe/payout.ex` + `lib/lattice_stripe/payout/trace_id.ex`.
`mix compile --warnings-as-errors`: exits 0.

---
*Phase: 18-connect-money-movement*
*Plan: 04 (Payout)*
*Completed: 2026-04-13*
