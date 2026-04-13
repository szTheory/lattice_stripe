---
phase: 18
plan: 06
subsystem: connect-money-movement
tags: [connect, integration, stripe-mock, guide, exdoc, reconciliation]
requires:
  - 18-01-external-account
  - 18-02-charge-retrieve
  - 18-03-transfer-reversal
  - 18-04-payout
  - 18-05-balance-transactions
provides:
  - stripe-mock wire-shape coverage for every Phase 18 resource
  - guides/connect.md money-movement narrative (8 D-07 subsections)
  - ExDoc module grouping for Phase 18 modules (Connect + Charge in Payments)
affects:
  - test/integration
  - guides/connect.md
  - mix.exs
tech-stack:
  added: []
  patterns:
    - "@moduletag :integration + setup_all TCP guard against stripe-mock"
    - "Polymorphic dispatcher assertion via case on BankAccount | Card | Unknown"
    - "stripe_account: per-request opt threading (D-07 Pitfall 2)"
    - "Dual reconciliation idioms documented side-by-side"
key-files:
  created:
    - test/integration/external_account_integration_test.exs
    - test/integration/transfer_integration_test.exs
    - test/integration/transfer_reversal_integration_test.exs
    - test/integration/payout_integration_test.exs
    - test/integration/balance_integration_test.exs
    - test/integration/balance_transaction_integration_test.exs
    - test/integration/charge_integration_test.exs
  modified:
    - guides/connect.md
    - mix.exs
    - test/lattice_stripe/account/business_profile_test.exs
    - test/lattice_stripe/account/capability_test.exs
    - test/lattice_stripe/account/company_test.exs
    - test/lattice_stripe/account/individual_test.exs
    - test/lattice_stripe/account/requirements_test.exs
    - test/lattice_stripe/account/settings_test.exs
    - test/lattice_stripe/account/tos_acceptance_test.exs
    - test/lattice_stripe/account_test.exs
    - test/lattice_stripe/external_account_test.exs
    - test/lattice_stripe/transfer_reversal_test.exs
decisions:
  - "Heredoc strings in external_account_test.exs replaced with ~S sigils (credo strict)"
  - "~S delimiter chosen over ~s{} because Elixir %Struct{} braces collide with ~s{...}"
  - "Per-format auto-fix applied to 10 pre-existing Phase 17/18 test files as Rule 3 blocker (mix ci acceptance gate)"
  - "stripe-mock integration tests assert wire SHAPE not SEMANTICS; state-machine operations (payout cancel/reverse) accept {:ok, _} OR %Error{type: :invalid_request_error}"
metrics:
  tasks_completed: 2
  completed: 2026-04-12
---

# Phase 18 Plan 06: Integration Guide + ExDoc Summary

stripe-mock integration tests for all 7 Phase 18 resource families, a full money-movement narrative appended to `guides/connect.md` covering D-07's 8 subsections with dual reconciliation idioms, and ExDoc module grouping wired through `mix.exs` for all new modules. `mix ci` green end-to-end.

## What shipped

### 7 stripe-mock integration test files (Task 1)

Each file follows the Phase 14/17 template: `use ExUnit.Case, async: false`, `@moduletag :integration`, `setup_all` TCP-probe guard that raises the `docker run` command if stripe-mock is unreachable, `setup` block that yields `test_integration_client()`.

| File | Coverage |
|---|---|
| `external_account_integration_test.exs` | CRUDL + polymorphic dispatcher for bank/card/unknown, mixed list, stream |
| `transfer_integration_test.exs` | Lifecycle + separate-charge-and-transfer params shape (transfer_group + source_transaction) |
| `transfer_reversal_integration_test.exs` | Create/retrieve/list/stream on a live transfer |
| `payout_integration_test.exs` | Full lifecycle + cancel/reverse with `expand: ["balance_transaction"]` (D-03) |
| `balance_integration_test.exs` | Platform + per-connected-account retrieve via `stripe_account:` opt (D-07 Pitfall 2) |
| `balance_transaction_integration_test.exs` | Retrieve, list, payout filter, stream, fee_details filter pattern |
| `charge_integration_test.exs` | Retrieve + expand on balance_transaction + Inspect PII redaction |

Result: **35 new integration tests, 0 failures**. Full integration suite: **142 tests, 0 failures, 11 skipped**.

### guides/connect.md money-movement section (Task 2)

Replaced the "What's next" stub with a full money-movement section matching the D-07 8-subsection outline verbatim:

1. **External accounts** — polymorphic create + pattern-match idiom + list/stream
2. **Balance** — platform vs connected account side-by-side + the "reconciliation loop antipattern" warning quoted verbatim
3. **Transfers** — create with `transfer_group`, reversal flow
4. **Payouts** — lifecycle + `Payout.TraceId` read + cancel with expand (D-03) + reverse
5. **Destination charges** — raw `PaymentIntent.create` with `application_fee_amount`/`transfer_data`/`on_behalf_of`, with explicit note that LatticeStripe ships NO wrapper
6. **Separate charges and transfers** — three-step flow with multi-destination fan-out and a "source_transaction is load-bearing" callout
7. **Reconciling platform fees** — BOTH idioms documented side-by-side: per-object `Charge.retrieve(..., expand: ["balance_transaction"])` AND per-payout `BalanceTransaction.list(client, %{payout: po.id})` + stream variant + manual cast via `Charge.from_map/1` per D-05
8. **What's next** — pointer to ExDoc Connect group

Webhook-handoff callouts: **7 total** (`>` blockquote format) on external accounts, transfers, payouts, destination charges, reconciliation, plus the top-level intro + inline Balance antipattern warning. Acceptance required 4+.

### mix.exs ExDoc groups

Added to the existing **Connect** group (13 new modules):

```
LatticeStripe.BankAccount, LatticeStripe.Card, LatticeStripe.ExternalAccount,
LatticeStripe.ExternalAccount.Unknown, LatticeStripe.Transfer,
LatticeStripe.TransferReversal, LatticeStripe.Payout, LatticeStripe.Payout.TraceId,
LatticeStripe.Balance, LatticeStripe.Balance.Amount, LatticeStripe.Balance.SourceTypes,
LatticeStripe.BalanceTransaction, LatticeStripe.BalanceTransaction.FeeDetail
```

Added to the existing **Payments** group (D-06 — Charge is a shared primary resource, NOT a Connect-only concept):

```
LatticeStripe.Charge
```

## Verification

| Gate | Result |
|---|---|
| `mix format --check-formatted` | PASS |
| `mix compile --warnings-as-errors` | PASS |
| `mix credo --strict` | PASS |
| `mix test` | 1386 tests, 0 failures (142 excluded) |
| `mix docs --warnings-as-errors` | PASS |
| `mix test --only integration` | 142 tests, 0 failures, 11 skipped |
| `git diff --stat lib/lattice_stripe/payment_intent.ex` | empty (D-07 enforced) |

All acceptance grep guards pass:

- `grep -c 'Webhook handoff' guides/connect.md` → **7** (≥4 required)
- `grep -q 'stripe_account:' guides/connect.md` → PASS
- `grep -q 'application_fee_amount' guides/connect.md` → PASS
- `grep -q 'source_transaction' guides/connect.md` → PASS
- `grep -q 'BalanceTransaction.list' guides/connect.md` → PASS
- `grep -q 'expand:.*balance_transaction' guides/connect.md` → PASS
- `grep -q 'LatticeStripe.BankAccount' mix.exs` → PASS
- `grep -q 'LatticeStripe.Charge' mix.exs` → PASS
- `grep -q 'stripe_account' test/integration/balance_integration_test.exs` → PASS
- `grep -q 'expand' test/integration/payout_integration_test.exs` → PASS

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Pre-existing `mix format` failures in 10 Phase 17/18 test files**

- **Found during:** Task 2 `mix ci` gate
- **Issue:** 10 test files under `test/lattice_stripe/account/*`, `test/lattice_stripe/account_test.exs`, `test/lattice_stripe/external_account_test.exs`, and `test/lattice_stripe/transfer_reversal_test.exs` had format drift inherited from earlier phases (pre-existing before Phase 18 Plan 06 started). `mix ci` is a hard acceptance criterion; without fixing these, Task 2 cannot complete.
- **Fix:** `mix format` auto-applied to the whole project. Changes are purely whitespace and delimiter wrapping — no semantic edits.
- **Files modified:** 10 files listed in key-files.modified.
- **Commit:** `e082ed7`

**2. [Rule 3 - Blocking] Pre-existing credo "More than 3 quotes in string literal" in external_account_test.exs**

- **Found during:** Task 2 `mix credo --strict` gate
- **Issue:** Two test names used `\"` escape sequences (`"dispatches %{\"object\" => \"bank_account\"} -> %BankAccount{}"`), triggering credo's readability rule "use a sigil instead". Pre-existing.
- **Fix:** Rewrote the two test names using `~S[...]` sigils. `~S` chosen over `~s{...}` because `%BankAccount{}` braces collide with `~s{...}` delimiters (parser error).
- **Files modified:** `test/lattice_stripe/external_account_test.exs` (2 test-name lines)
- **Commit:** `e082ed7`

### Architectural decisions made during execution

**Payout cancel/reverse assertions accept both success and :invalid_request_error.**
stripe-mock enforces the payout state machine loosely — a just-created canned payout may or may not be cancelable. Rather than hard-coding one branch, each cancel/reverse test uses a `case` that accepts `{:ok, %Payout{}}` OR `{:error, %LatticeStripe.Error{type: :invalid_request_error}}`. This matches the plan's guidance ("wrap in try/rescue or assert against the specific shape") and preserves wire-shape coverage.

**Balance integration test does NOT sniff the `Stripe-Account` header directly.**
The Finch transport ships the header per D-07, but there is no current test hook to introspect outgoing headers without plumbing a Mox-style spy through the integration client. Instead the test calls `Balance.retrieve(client, stripe_account: account_id)` with a freshly created `acct_...` id and asserts the wire shape — stripe-mock accepts the header and returns a valid balance. The unit test in `test/lattice_stripe/balance_test.exs` (Phase 18-05) already covers the header-threading assertion via Mox. The grep guard `grep -q 'stripe_account' test/integration/balance_integration_test.exs` is the D-07 Pitfall 2 acceptance hook and passes.

## D-07 Enforcement Result

`git diff --stat lib/lattice_stripe/payment_intent.ex` produced NO output at every commit in this plan. PaymentIntent module remains untouched for Phase 18, matching D-07's explicit lock.

## Commits

| Hash | Message |
|---|---|
| `dc59a83` | test(18-06): stripe-mock integration tests for Phase 18 resources |
| `e082ed7` | docs(18-06): connect guide money-movement section + ExDoc wiring |

## Self-Check: PASSED

- FOUND: test/integration/external_account_integration_test.exs
- FOUND: test/integration/transfer_integration_test.exs
- FOUND: test/integration/transfer_reversal_integration_test.exs
- FOUND: test/integration/payout_integration_test.exs
- FOUND: test/integration/balance_integration_test.exs
- FOUND: test/integration/balance_transaction_integration_test.exs
- FOUND: test/integration/charge_integration_test.exs
- FOUND: guides/connect.md (modified, money-movement section present)
- FOUND: mix.exs (modified, ExDoc groups updated)
- FOUND: commit dc59a83
- FOUND: commit e082ed7
- VERIFIED: lib/lattice_stripe/payment_intent.ex untouched (D-07)
- VERIFIED: mix ci exit 0
- VERIFIED: mix test --only integration exit 0
