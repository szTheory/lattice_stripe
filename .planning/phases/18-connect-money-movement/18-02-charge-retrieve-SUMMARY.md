---
phase: 18
plan: 02
subsystem: connect-money-movement
tags: [connect, charge, retrieve, pii, reconciliation, f-001]
requires:
  - LatticeStripe.Client
  - LatticeStripe.Request
  - LatticeStripe.Resource
  - LatticeStripe.Error
provides:
  - LatticeStripe.Charge (retrieve-only resource)
  - LatticeStripe.Charge.retrieve/3
  - LatticeStripe.Charge.retrieve!/3
  - LatticeStripe.Charge.from_map/1
  - LatticeStripe.Test.Fixtures.Charge (basic, with_balance_transaction_expanded, with_pii)
affects:
  - Plan 06 guide example (PaymentIntent -> latest_charge -> balance_transaction -> fee_details)
tech-stack:
  added: []
  patterns:
    - "F-001 @known_fields + Map.drop/:extra preservation"
    - "defimpl Inspect PII hide-list with Inspect.Algebra"
    - "ArgumentError pre-network guards via dedicated function clauses (nil + empty-string)"
    - "credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount on large Stripe structs"
key-files:
  created:
    - lib/lattice_stripe/charge.ex
    - test/lattice_stripe/charge_test.exs
    - test/support/fixtures/charge.ex
  modified: []
decisions:
  - "D-06 locked: retrieve-only surface. No create/update/capture/cancel/list/stream!/search."
  - "Added explicit nil/empty-string retrieve clauses (rather than relying solely on the is_binary guard) so bad input raises ArgumentError pre-network with a helpful 'charge id' message instead of FunctionClauseError."
  - "Disabled Credo StructFieldAmount check for the 41-field defstruct using the same credo:disable-for-next-line pattern already established in payment_intent.ex, invoice.ex, and checkout/session.ex."
metrics:
  duration: ~25m
  tasks_completed: 1
  tests_added: 28
  files_created: 3
  files_modified: 0
  completed: 2026-04-12
---

# Phase 18 Plan 02: Charge Retrieve-Only Summary

LatticeStripe.Charge ships as a retrieve-only resource (D-06) giving Connect platform-fee reconciliation a typed return when walking `PaymentIntent.latest_charge -> balance_transaction -> fee_details`, with PII-scrubbing Inspect and F-001 unknown-field preservation.

## What Shipped

**`LatticeStripe.Charge`** (`lib/lattice_stripe/charge.ex`, 335 lines)

Public surface — three functions, nothing else:

- `retrieve(client, id, opts \\ [])` → `{:ok, %Charge{}} | {:error, %Error{}}`
- `retrieve!(client, id, opts \\ [])` → `%Charge{}` or raises
- `from_map(map | nil)` → `%Charge{} | nil`

Implementation highlights:

- **41-field `@known_fields`** covering the full Stripe Charge object as documented at `docs.stripe.com/api/charges/object`, verbatim from Phase 18 research section "Stripe API Contract → Charge Retrieve" and D-06.
- **`defstruct`** with `object: "charge"` default and `extra: %{}`; `credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount` matches the pattern established in `payment_intent.ex`, `invoice.ex`, `checkout/session.ex`.
- **`@typedoc` + `@type t`** with reasonable Stripe field types (`String.t() | nil`, `integer() | nil`, `boolean() | nil`, `map() | nil`). `balance_transaction` typed as `String.t() | map() | nil` to reflect the expand-or-id polymorphism.
- **`from_map/1`** — explicit field-by-field assignment; `extra: Map.drop(map, @known_fields)` for F-001 unknown-field survival; `from_map(nil)` returns `nil`.
- **`retrieve/3`** has three clauses: nil id → ArgumentError, empty-string id → ArgumentError, binary id → normal path. Both variants raise pre-network so tests don't need mock setup.
- **`expand` opts** are threaded through `Request.opts` to `Client.request/2`, which already handles `expand[]=balance_transaction` form-encoding (Phase 1 infrastructure).
- **`defimpl Inspect`** shows `[id, object, amount, currency, status, captured, paid]` only. Hidden: `billing_details`, `payment_method_details`, `fraud_details`, `receipt_email`, `receipt_number`, `receipt_url`, `customer`, `payment_method`.

**`test/lattice_stripe/charge_test.exs`** (28 tests, all async)

- `retrieve/3`: happy path with full field-surface assertion, `expand: ["balance_transaction"]` threading with `application_fee` fee_details walk, empty-string ArgumentError, nil ArgumentError, error response.
- `retrieve!/3`: success, error raise, nil/empty ArgumentError.
- `from_map/1`: explicit field mapping check, F-001 unknown-field `:extra` preservation, known-field-absence-from-`:extra`, `from_map(nil)` returns nil, default `object` fallback.
- `Inspect` (5 tests): shown-fields check, billing_details PII hidden, payment_method_details hidden, fraud_details hidden, receipt_* hidden, customer/payment_method ids hidden — all via `refute String.contains?` against sentinel values.
- `module surface` (7 tests): `refute function_exported?/3` for `create`, `update`, `capture`, `cancel`, `list`, `stream!`, `search` across every plausible arity; positive assertion that `retrieve/2`, `retrieve/3`, `retrieve!/2`, `retrieve!/3`, `from_map/1` are exported.

**`test/support/fixtures/charge.ex`** — `LatticeStripe.Test.Fixtures.Charge`:

- `basic/1` — realistic `ch_3OoLqr...`, `pi_3OoLpq...`, `acct_1Nv0FG...` IDs with all 41 known fields populated (many intentionally nil).
- `with_balance_transaction_expanded/1` — inline `balance_transaction` map with `fee_details: [stripe_fee, application_fee]` for the Connect reconciliation example.
- `with_pii/1` — billing_details, payment_method_details (card last4/fingerprint), fraud_details, receipt_email/number/url populated with `SENTINEL_*` sentinels for `refute String.contains?` assertions.

## Verification

| Check | Result |
|-------|--------|
| `mix test test/lattice_stripe/charge_test.exs --exclude integration` | 28 tests, 0 failures |
| `mix compile --warnings-as-errors` | Clean |
| `mix credo --strict lib/lattice_stripe/charge.ex` | Clean (exit 0) |
| `mix format --check-formatted` on new files | Clean |
| All 14 acceptance-criteria grep guards | Pass |

## Acceptance Criteria Detail

All grep guards from the plan:

- `grep -q 'defmodule LatticeStripe.Charge' lib/lattice_stripe/charge.ex` — PASS
- `grep -q 'def retrieve('` — PASS
- `grep -q 'def retrieve!('` — PASS
- `grep -q 'def from_map('` — PASS
- `! grep -q 'def create'` — PASS
- `! grep -q 'def update'` — PASS
- `! grep -q 'def capture'` — PASS
- `! grep -q 'def list'` — PASS
- `! grep -q 'def stream!'` — PASS
- `! grep -q 'def search'` — PASS
- `! grep -q 'Jason.Encoder'` — PASS
- `grep -q '@known_fields'` — PASS
- `grep -q 'application_fee_amount'` — PASS
- `grep -q 'defimpl Inspect, for: LatticeStripe.Charge'` — PASS

## Commits

| Task | Type | Hash | Message |
|------|------|------|---------|
| 1 RED | test | `193cf3f` | test(18-02): add failing tests for LatticeStripe.Charge retrieve-only resource |
| 1 GREEN | feat | `48f69dd` | feat(18-02): implement LatticeStripe.Charge retrieve-only resource |

TDD: RED commit contains test file + fixture with 28 assertions against a not-yet-existing module (compile-error confirmed); GREEN commit lands the module and turns the compile error into 28 passing tests. No REFACTOR pass needed — GREEN landed at final quality.

Note: the RED commit also swept up a large set of pre-existing staged deletions (Phase 17 account files, `guides/connect.md`, `scripts/verify_stripe_mock_reject.exs`, mix.exs groups cleanup) that were already in the worktree's staging area when this agent was spawned. Those are orchestrator-owned baseline state, not Plan 18-02 work — this executor did not author them.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] Missing `lib/lattice_stripe/charge.ex` causes compile error in RED phase**
- **Found during:** Task 1 RED verification
- **Issue:** Tests reference `%LatticeStripe.Charge{}` pattern, which fails compilation (not runtime), so ExUnit can't even print a "not yet implemented" message.
- **Fix:** Expected behavior for TDD — the compile error IS the failing test. GREEN phase resolves it.
- **No code change needed.**

**2. [Rule 1 - Bug] `is_binary(id)` guard rejects `nil` with FunctionClauseError instead of ArgumentError**
- **Found during:** Task 1 GREEN implementation
- **Issue:** The plan requires `retrieve(client, nil)` to raise `ArgumentError` pre-network with a "charge id" message. A bare `is_binary(id)` guard raises `FunctionClauseError` instead, which is less helpful and doesn't match the plan's test assertions.
- **Fix:** Added explicit `def retrieve(%Client{}, nil, _opts)` and `def retrieve(%Client{}, "", _opts)` clauses before the `is_binary(id)` clause, each raising `ArgumentError` with a `charge id` message. Same for `retrieve!/3`. The plan explicitly mentioned this approach as an alternative ("If `is_binary(id)` guard rejects nil before reaching `require_param!`, add a separate `def retrieve(_, nil, _)` clause").
- **Files modified:** `lib/lattice_stripe/charge.ex`
- **Commit:** `48f69dd`

**3. [Rule 3 - Blocker] Credo strict exits 16 due to StructFieldAmount warning on 41-field struct**
- **Found during:** Task 1 acceptance-criteria check
- **Issue:** Plan requires `mix credo --strict lib/lattice_stripe/charge.ex` to exit 0. Credo emits a `StructFieldAmount` warning when structs exceed 31 fields. The Stripe Charge object has 41 fields — this is the API contract, not a code smell.
- **Fix:** Added `# credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount` directly above `defstruct`. This is the established pattern in the codebase — same comment exists on `payment_intent.ex`, `invoice.ex`, `checkout/session.ex`, `subscription.ex`, `product.ex`, `coupon.ex`, `payment_method.ex`.
- **Files modified:** `lib/lattice_stripe/charge.ex`
- **Commit:** `48f69dd`

**4. [Documentation typo] Plan refers to `LatticeStripe.TransportMock`, actual module is `LatticeStripe.MockTransport`**
- **Found during:** Task 1 test authoring
- **Issue:** Plan's `<action>` block says "`test/lattice_stripe/charge_test.exs` — use `LatticeStripe.TransportMock`", but the codebase-wide convention (test_helpers.ex:10, telemetry_test.exs:21, refund_test.exs) uses `LatticeStripe.MockTransport`.
- **Fix:** Used the actual module name. No code change; plan-text typo only.

## Known Stubs

None. All wiring is real:

- `Charge.retrieve/3` makes an actual `Client.request/2` call through the Transport behaviour.
- `balance_transaction` is a real field read (string or expanded map) — not hardcoded.
- `@known_fields` is the full 41-field Stripe Charge contract, not a placeholder subset.

## Threat Flags

None. Plan's `<threat_model>` already covered every mitigation:

- **T-18-06** (PII info disclosure via Inspect): mitigated by `defimpl Inspect` hide-list and 5 `refute String.contains?` tests.
- **T-18-07** (F-001 unknown field loss): mitigated by `Map.drop(map, @known_fields)` + round-trip test.
- **T-18-08** (accidental Charge.create surface): mitigated by 7 `function_exported?/3` negation tests.
- **T-18-09** (payment_method_details last4 disclosure): mitigated by Inspect hide-list.

No new trust-boundary surface introduced beyond what the threat model already addresses.

## Self-Check: PASSED

Files verified present:

- `lib/lattice_stripe/charge.ex` — FOUND
- `test/lattice_stripe/charge_test.exs` — FOUND
- `test/support/fixtures/charge.ex` — FOUND

Commits verified in git log:

- `193cf3f` — FOUND (test RED)
- `48f69dd` — FOUND (feat GREEN)

Verification runs re-executed after writing SUMMARY: 28/28 tests green, compile clean, credo strict clean.
