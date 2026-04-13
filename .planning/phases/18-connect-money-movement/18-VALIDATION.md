---
phase: 18
slug: connect-money-movement
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-12
---

# Phase 18 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) + Mox 1.2 + stripe-mock (Docker) |
| **Config file** | `test/test_helper.exs`, `test/support/` (inherited from Phases 9/11/17) |
| **Quick run command** | `mix test --exclude integration` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds (unit) / ~45 seconds (full with stripe-mock) |

---

## Sampling Rate

- **After every task commit:** Run `mix test --exclude integration` on the files touched
- **After every plan wave:** Run `mix test` (full suite incl. stripe-mock integration)
- **Before `/gsd-verify-work`:** Full suite green + `mix credo --strict` + `mix docs`
- **Max feedback latency:** 45 seconds

---

## Per-Task Verification Map

> Populated during planning. Every task must map to at least one automated command
> OR declare a Wave 0 dependency. Integration tests via stripe-mock cover CRUDL happy paths;
> Mox unit tests cover request shape + error handling + PII Inspect behavior.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 18-01-01 | 01 | 1 | CNCT-02 | T-18-01 | PII hide-list on BankAccount/Card (Inspect derive) | unit | `mix test test/lattice_stripe/bank_account_test.exs test/lattice_stripe/card_test.exs --exclude integration` | ❌ W0 | ⬜ pending |
| 18-01-02 | 01 | 1 | CNCT-02 | T-18-01 | Polymorphic dispatcher + Unknown fallback | unit | `mix test test/lattice_stripe/external_account_test.exs --exclude integration` | ❌ W0 | ⬜ pending |
| 18-02-01 | 02 | 1 | CNCT-04 | T-18-02 | Charge retrieve-only (no PaymentIntent leakage) | unit | `mix test test/lattice_stripe/charge_test.exs --exclude integration` | ❌ W0 | ⬜ pending |
| 18-03-01 | 03 | 2 | CNCT-02, CNCT-03 | T-18-03 | TransferReversal standalone CRUD + Stripe-Account header | unit | `mix test test/lattice_stripe/transfer_reversal_test.exs --exclude integration` | ❌ W0 | ⬜ pending |
| 18-03-02 | 03 | 2 | CNCT-02, CNCT-03 | T-18-03 | Transfer CRUDL + reversals sublist decoding + idempotency | unit | `mix test test/lattice_stripe/transfer_test.exs --exclude integration` | ❌ W0 | ⬜ pending |
| 18-04-01 | 04 | 2 | CNCT-02 | T-18-04 | Payout.TraceId nested-struct decoding | unit | `mix test test/lattice_stripe/payout/trace_id_test.exs --exclude integration` | ❌ W0 | ⬜ pending |
| 18-04-02 | 04 | 2 | CNCT-02 | T-18-04 | Payout CRUDL + cancel + reverse + idempotency | unit | `mix test test/lattice_stripe/payout_test.exs --exclude integration` | ❌ W0 | ⬜ pending |
| 18-05-01 | 05 | 3 | CNCT-04, CNCT-05 | T-18-05 | Balance singleton + Amount/SourceTypes nested structs | unit | `mix test test/lattice_stripe/balance_test.exs test/lattice_stripe/balance/amount_test.exs test/lattice_stripe/balance/source_types_test.exs --exclude integration` | ❌ W0 | ⬜ pending |
| 18-05-02 | 05 | 3 | CNCT-04, CNCT-05 | T-18-05 | BalanceTransaction list filters + FeeDetail nested struct | unit | `mix test test/lattice_stripe/balance_transaction_test.exs test/lattice_stripe/balance_transaction/fee_detail_test.exs --exclude integration` | ❌ W0 | ⬜ pending |
| 18-06-01 | 06 | 4 | CNCT-02..05 | T-18-06 | Stripe-mock integration coverage for all money-movement resources | integration | `mix test --only integration test/integration/external_account_integration_test.exs test/integration/transfer_integration_test.exs test/integration/transfer_reversal_integration_test.exs test/integration/payout_integration_test.exs test/integration/balance_integration_test.exs test/integration/balance_transaction_integration_test.exs test/integration/charge_integration_test.exs` | ❌ W0 | ⬜ pending |
| 18-06-02 | 06 | 4 | CNCT-02..05 | T-18-06 | Connect guide + ExDoc wiring + `mix ci` gate (no PaymentIntent drift) | integration | `mix ci && mix test --only integration` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Phase 18 inherits Phase 9/11/17 test infrastructure. No new framework install required.*

- [ ] `test/support/stripe_mock_case.ex` — reused from Phase 9 (no changes expected)
- [ ] `test/support/mocks.ex` — reused; verify `LatticeStripe.TransportMock` already defined

*If all reused without modification: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Destination charges + separate charge/transfer runnable examples render correctly in HexDocs | CNCT-02, CNCT-03 | ExDoc visual output | Run `mix docs` and open `doc/index.html`; confirm examples in `LatticeStripe.Transfer` and Connect guide page render with proper syntax highlighting |
| Platform fee reconciliation via BalanceTransaction expansion example runs end-to-end against stripe-mock | CNCT-05 | Doctest + visual confirmation | Run the doctest snippet manually against stripe-mock; confirm `fee_details` field is populated in response |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (none expected for Phase 18 — infrastructure inherited from Phases 9/11/17)
- [x] No watch-mode flags
- [x] Feedback latency < 45s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-04-12
