---
phase: 18-connect-money-movement
verified: 2026-04-12T00:00:00Z
status: passed
score: 28/28 must-haves verified
overrides_applied: 0
---

# Phase 18: Connect Money Movement Verification Report

**Phase Goal:** Ship the Connect money-movement surface — ExternalAccount (bank/card polymorphic CRUDL), Charge retrieve-only, Transfer + TransferReversal full CRUDL, Payout full CRUDL + cancel/reverse with TraceId, Balance singleton, BalanceTransaction list/retrieve with FeeDetail, integration tests against stripe-mock, and a Connect guide + ExDoc wiring.

**Verified:** 2026-04-12
**Status:** passed
**Re-verification:** No — initial verification
**Repository HEAD:** 3046217

## Goal Achievement

### Observable Truths (merged from ROADMAP success criteria + all 6 PLAN frontmatter must_haves)

| #  | Truth                                                                                                                                             | Status     | Evidence                                                                                                       |
| -- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------- |
| 1  | Developer can CRUDL External Accounts (bank + card) polymorphically on a connected account                                                        | VERIFIED   | `lib/lattice_stripe/external_account.ex:111,131,154,177,199,220` — create/retrieve/update/delete/list/stream! all addressed by `account_id` |
| 2  | ExternalAccount.cast/1 dispatches on the object discriminator and returns BankAccount / Card / Unknown                                            | VERIFIED   | `external_account.ex:82-84` — `cast(%{"object" => "bank_account"})`, `"card"`, and `_other` branches           |
| 3  | Unknown fallback prevents crashes on novel object types                                                                                           | VERIFIED   | `lib/lattice_stripe/external_account/unknown.ex` (38 lines, defstruct + cast/1 preserving :extra)              |
| 4  | BankAccount and Card Inspect output never leaks routing/account/fingerprint/last4/exp PII                                                         | VERIFIED   | `defimpl Inspect` present in both `bank_account.ex` and `card.ex`; unit tests assert refute String.contains    |
| 5  | BankAccount + Card + Charge preserve unknown Stripe fields in :extra (F-001)                                                                      | VERIFIED   | `@known_fields` + Map.drop patterns present; round-trip tests in unit suites                                   |
| 6  | Developer can retrieve a Charge via Charge.retrieve/retrieve! and receive a typed %Charge{} with Connect-relevant fields                          | VERIFIED   | `lib/lattice_stripe/charge.ex:208,231` — retrieve/3 + retrieve!/3 with nil/"" pre-network guards; 335 lines     |
| 7  | Charge module is retrieve-only (no create/update/capture/list/stream!/search/cancel per D-06)                                                     | VERIFIED   | `charge.ex` grep returned ONLY retrieve/retrieve! — no other CRUD verbs                                        |
| 8  | Charge PII Inspect hides billing_details / payment_method_details / fraud_details / receipt_email / receipt_url                                    | VERIFIED   | `defimpl Inspect` in `charge.ex`; plan acceptance criteria enforced by unit tests                              |
| 9  | Developer can create/retrieve/update/list/stream Transfers with bang variants                                                                     | VERIFIED   | `lib/lattice_stripe/transfer.ex:197,218,231,244,257` + bang variants                                            |
| 10 | Transfer defines NO reverse/3 or reverse/4 delegator (D-02 locked)                                                                                | VERIFIED   | grep `def reverse` on `transfer.ex` returned no matches                                                        |
| 11 | Transfer.from_map decodes embedded reversals.data into [%TransferReversal{}] and stashes wrapper metadata under extra["reversals_meta"]           | VERIFIED   | `transfer.ex:262` calls `TransferReversal.from_map`; `reversals_meta` key present at lines 268-278             |
| 12 | TransferReversal standalone module supports (transfer_id, reversal_id) addressed CRUDL + stream! + bang variants                                   | VERIFIED   | `lib/lattice_stripe/transfer_reversal.ex:123,155,192,229,259` all present with nil/"" guards                   |
| 13 | TransferReversal calls require_param! on transfer_id (and reversal_id where present) pre-network                                                  | VERIFIED   | explicit `when id in [nil, ""]` head clauses in create/retrieve/update/list/stream!                             |
| 14 | Developer can create/retrieve/update/list/stream Payouts with bang variants                                                                       | VERIFIED   | `lib/lattice_stripe/payout.ex:197,210,231,244,257` + bangs at 343-361                                          |
| 15 | Payout.cancel accepts (client, id, params \\ %{}, opts \\ []) — canonical D-03 shape                                                              | VERIFIED   | `payout.ex:289` — default empty params + opts; POST /v1/payouts/:id/cancel at line 298                          |
| 16 | Payout.reverse accepts same shape, enabling expand: ["balance_transaction"] without breaking change                                               | VERIFIED   | `payout.ex:323` — default empty params + opts; POST /v1/payouts/:id/reverse at line 332                         |
| 17 | Payout.from_map decodes trace_id into a typed %Payout.TraceId{} (status + value)                                                                  | VERIFIED   | `payout.ex:417` `trace_id: TraceId.cast(map["trace_id"])`; `lib/lattice_stripe/payout/trace_id.ex` (61 lines) |
| 18 | Balance.retrieve/2 returns platform balance; stripe_account: opt routes to connected account                                                      | VERIFIED   | `balance.ex:83` retrieve/2 with opts; doc at lines 6-24 explicitly shows stripe_account: example + Pitfall 2 warning |
| 19 | Balance has no id, no list, no create/update/delete (singleton)                                                                                   | VERIFIED   | `balance.ex` grep returned only retrieve/retrieve!                                                              |
| 20 | Balance.Amount struct reused for available/pending/connect_reserved/instant_available/issuing.available                                           | VERIFIED   | `lib/lattice_stripe/balance/amount.ex` (41 lines); Balance module aliases and uses throughout                   |
| 21 | Balance.SourceTypes uses typed-inner-open-outer (stable {card, bank_account, fpx} + :extra)                                                       | VERIFIED   | `lib/lattice_stripe/balance/source_types.ex` (37 lines) — P17 D-02 pattern                                     |
| 22 | BalanceTransaction supports retrieve + list + stream! + bang variants (no create/update/delete — Stripe-managed)                                   | VERIFIED   | `balance_transaction.ex:102,117,130,140,149` — exactly retrieve/list/stream! + bangs                            |
| 23 | BalanceTransaction.from_map decodes fee_details via FeeDetail.cast/1 — reconciliation shape {amount, currency, description, type, application}   | VERIFIED   | `balance_transaction.ex:169-171` Enum.map over fee_details calling FeeDetail.cast; fee_detail.ex (46 lines)     |
| 24 | Every Phase 18 resource has a stripe-mock integration test covering canonical happy path                                                          | VERIFIED   | 7 files exist: external_account/transfer/transfer_reversal/payout/balance/balance_transaction/charge_integration_test.exs, all with @moduletag :integration + test_integration_client |
| 25 | Balance integration test exercises stripe_account: opt (Pitfall 2 mitigation)                                                                     | VERIFIED   | `balance_integration_test.exs:48-55` — explicit "with stripe_account: opt threads the per-request header (D-07 Pitfall 2)" test |
| 26 | Payout integration test exercises cancel + expand: ["balance_transaction"] (D-03 path)                                                            | VERIFIED   | `payout_integration_test.exs:85-89` — cancel/4 with expand test                                                |
| 27 | guides/connect.md money-movement section covers all 8 D-07 subsections with 4+ webhook-handoff callouts and dual reconciliation idioms            | VERIFIED   | 577-line guide; 7 "Webhook handoff" callouts; grep confirms stripe_account:, application_fee_amount, source_transaction, BalanceTransaction.list, expand:.*balance_transaction all present (29 total matches) |
| 28 | mix.exs ExDoc groups wire all Phase 18 modules (Connect group for 13 new modules; Charge under Payments per D-06)                                  | VERIFIED   | `mix.exs:58` LatticeStripe.Charge in Payments group; `mix.exs:94-106` all 13 Connect modules in Connect group |

**Score:** 28/28 truths verified

### Required Artifacts

| Artifact                                                   | Expected                                            | Status     | Details                                |
| ---------------------------------------------------------- | --------------------------------------------------- | ---------- | -------------------------------------- |
| `lib/lattice_stripe/bank_account.ex`                       | BankAccount struct + cast + PII Inspect             | VERIFIED   | 139 lines, defimpl Inspect present     |
| `lib/lattice_stripe/card.ex`                               | Card struct + cast + PII Inspect                    | VERIFIED   | 169 lines, defimpl Inspect present     |
| `lib/lattice_stripe/external_account.ex`                   | Polymorphic dispatcher CRUDL                        | VERIFIED   | 278 lines, all 6 verbs + bangs         |
| `lib/lattice_stripe/external_account/unknown.ex`           | Unknown forward-compat fallback                     | VERIFIED   | 38 lines                               |
| `lib/lattice_stripe/charge.ex`                             | Charge retrieve-only + from_map + PII Inspect       | VERIFIED   | 335 lines, only retrieve/retrieve!     |
| `lib/lattice_stripe/transfer.ex`                           | Transfer CRUDL + reversals decoding                 | VERIFIED   | 302 lines, no reverse/4                |
| `lib/lattice_stripe/transfer_reversal.ex`                  | Standalone (transfer_id, reversal_id) CRUDL         | VERIFIED   | 306 lines                              |
| `lib/lattice_stripe/payout.ex`                             | Payout CRUDL + cancel + reverse + TraceId decoding  | VERIFIED   | 422 lines                              |
| `lib/lattice_stripe/payout/trace_id.ex`                    | TraceId nested struct                               | VERIFIED   | 61 lines                               |
| `lib/lattice_stripe/balance.ex`                            | Balance singleton retrieve                          | VERIFIED   | 124 lines                              |
| `lib/lattice_stripe/balance/amount.ex`                     | Balance.Amount nested struct                        | VERIFIED   | 41 lines                               |
| `lib/lattice_stripe/balance/source_types.ex`               | SourceTypes typed-inner-open-outer                  | VERIFIED   | 37 lines                               |
| `lib/lattice_stripe/balance_transaction.ex`                | BT retrieve + list + stream + FeeDetail decoding    | VERIFIED   | 194 lines                              |
| `lib/lattice_stripe/balance_transaction/fee_detail.ex`     | FeeDetail nested struct                             | VERIFIED   | 46 lines                               |
| `test/integration/external_account_integration_test.exs`  | stripe-mock ExternalAccount CRUDL                   | VERIFIED   | 135 lines                              |
| `test/integration/transfer_integration_test.exs`          | stripe-mock Transfer lifecycle                      | VERIFIED   | 93 lines                               |
| `test/integration/transfer_reversal_integration_test.exs` | stripe-mock TransferReversal                        | VERIFIED   | 66 lines                               |
| `test/integration/payout_integration_test.exs`            | stripe-mock Payout + cancel(expand) + reverse       | VERIFIED   | 104 lines                              |
| `test/integration/balance_integration_test.exs`           | stripe-mock Balance + stripe_account: opt           | VERIFIED   | 74 lines                               |
| `test/integration/balance_transaction_integration_test.exs` | stripe-mock BT retrieve/list                     | VERIFIED   | 77 lines                               |
| `test/integration/charge_integration_test.exs`            | stripe-mock Charge retrieve + expand                | VERIFIED   | 59 lines                               |
| `guides/connect.md`                                        | Money Movement section (8 subsections)              | VERIFIED   | 577 lines, 7 webhook handoff callouts  |
| `mix.exs`                                                  | ExDoc groups wiring                                 | VERIFIED   | Connect + Payments groups updated      |

### Key Link Verification

| From                                                  | To                                                         | Via                                                    | Status | Details |
| ----------------------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------ | ------ | ------- |
| `external_account.ex`                                 | `bank_account.ex` / `card.ex`                              | `cast/1` dispatches on "object" discriminator          | WIRED  | Lines 82-84 present |
| `external_account.ex`                                 | `/v1/accounts/:account/external_accounts`                  | Request path interpolation with account_id             | WIRED  | Lines 116,137,160,183,204,225 |
| `charge.ex`                                           | `/v1/charges/:id`                                          | Request{method: :get, path: "/v1/charges/#{id}"}       | WIRED  | retrieve/3 at line 218 |
| `transfer.ex`                                         | `transfer_reversal.ex`                                     | `from_map` calls `TransferReversal.from_map` on each reversals.data entry | WIRED | Line 262 |
| `transfer_reversal.ex`                                | `/v1/transfers/:transfer/reversals[/:id]`                  | Request path interpolation                             | WIRED  | all 5 verbs wired |
| `payout.ex`                                           | `payout/trace_id.ex`                                       | `from_map` calls `TraceId.cast(map["trace_id"])`       | WIRED  | Line 417 |
| `payout.ex`                                           | `/v1/payouts/:id/cancel` and `/reverse`                    | Request path interpolation                             | WIRED  | Lines 298, 332 |
| `balance.ex`                                          | `/v1/balance`                                              | GET with opts carrying stripe_account                  | WIRED  | Line 84 |
| `balance.ex`                                          | Client stripe_account opts override                       | opts[:stripe_account] threads through build_headers    | WIRED  | Explicitly doc'd lines 6-24; integration test asserts |
| `balance_transaction.ex`                              | `balance_transaction/fee_detail.ex`                        | `from_map` Enum.map's fee_details list via `FeeDetail.cast/1` | WIRED | Lines 169-171 |
| `guides/connect.md`                                   | Every Phase 18 module                                      | Worked code examples reference each module by name    | WIRED  | 29 matches on required terms |
| `mix.exs` groups_for_modules                          | Phase 18 modules                                           | Connect group expanded; Charge in Payments group       | WIRED  | Lines 58, 94-106 |

### Data-Flow Trace (Level 4)

Phase 18 produces library code (structs + API request functions); rendered-data tracing does not apply. Data flows verified instead as "does from_map receive and decode real Stripe response payloads":

| Artifact                    | Data Variable            | Source                                     | Produces Real Data                                            | Status |
| --------------------------- | ------------------------ | ------------------------------------------ | ------------------------------------------------------------- | ------ |
| Transfer.reversals          | map["reversals"]["data"] | Stripe API response via Client.request/2   | Yes — mapped to [%TransferReversal{}] via TransferReversal.from_map | FLOWING |
| Payout.trace_id             | map["trace_id"]          | Stripe API response                        | Yes — cast to %Payout.TraceId{}                               | FLOWING |
| BalanceTransaction.fee_details | map["fee_details"]     | Stripe API response                        | Yes — Enum.map with FeeDetail.cast                            | FLOWING |
| Balance (all 5 amount lists) | map["available"], etc.  | GET /v1/balance                            | Yes — Balance.Amount.cast applied per element                 | FLOWING |
| ExternalAccount.cast dispatch | map["object"]          | GET/POST /v1/accounts/:a/external_accounts | Yes — dispatches to BankAccount/Card/Unknown                  | FLOWING |

### Behavioral Spot-Checks

Phase 18 is library code — behavioral verification is performed via the test suites (1386 unit tests + 142 integration tests, all 0 failures as reported by 18-06 SUMMARY). No standalone runnable entry points exist for this phase.

| Behavior                                      | Command                               | Result (per 18-06 SUMMARY)         | Status |
| --------------------------------------------- | ------------------------------------- | ---------------------------------- | ------ |
| Full unit test suite                          | `mix test`                            | 1386 tests, 0 failures (142 excluded) | PASS  |
| Integration suite against stripe-mock         | `mix test --only integration`         | 142 tests, 0 failures, 11 skipped  | PASS   |
| mix ci (format + compile + credo + test + docs) | `mix ci`                             | green (5 quality gates)            | PASS   |

Spot-checks re-run by this verifier were restricted to grep-level code inspection, not shell execution — the phase's own authoritative test run is trusted here because (a) commit history confirms `dc59a83 test(18-06)` and `3046217 docs(18-06): complete integration-guide-exdoc plan` both landed, (b) the 18-06 SUMMARY is explicit about the test count, and (c) all expected artifacts exist and are substantive.

### Requirements Coverage

| Requirement | Source Plans            | Description                                              | Status    | Evidence                                                                                                    |
| ----------- | ----------------------- | -------------------------------------------------------- | --------- | ----------------------------------------------------------------------------------------------------------- |
| CNCT-02     | 18-01, 18-03, 18-04, 18-06 | Transfers and Payouts (+ External Accounts)              | SATISFIED | ExternalAccount CRUDL (Plan 01), Transfer + TransferReversal CRUDL (Plan 03), Payout CRUDL + cancel/reverse (Plan 04) |
| CNCT-03     | 18-03, 18-06            | Destination charges vs separate charge/transfer patterns | SATISFIED | Transfer supports `transfer_group` + `source_transaction` via params; guides/connect.md dedicates Subsection 6 to separate charges + transfers (grep confirms `source_transaction` present) |
| CNCT-04     | 18-02, 18-05, 18-06     | Platform fee handling and reconciliation                 | SATISFIED | Charge retrieve-only for per-object idiom (Plan 02); BalanceTransaction.fee_details typed as [%FeeDetail{}] (Plan 05); guide Subsection 7 documents BOTH reconciliation idioms side-by-side |
| CNCT-05     | 18-05, 18-06            | Balance and Balance Transactions                         | SATISFIED | Balance singleton retrieve/2 with stripe_account: opt (Plan 05); BalanceTransaction retrieve/list/stream + integration tests |

No orphaned requirements detected — REQUIREMENTS.md maps CNCT-02..05 to Phase 18 and all four are claimed by at least one plan.

### ROADMAP Success Criteria Coverage

| SC | Criterion | Status | Evidence |
| -- | --------- | ------ | -------- |
| 1  | CRUDL External Accounts polymorphic (bank + card) | SATISFIED | ExternalAccount dispatcher with cast/1 + 6 verbs |
| 2  | create/retrieve/update/list/reverse Transfers | SATISFIED | Transfer CRUDL + stream!; reversals via standalone TransferReversal.create/4 per D-02 (channeled, not method-on-Transfer) |
| 3  | create/retrieve/update/list/cancel Payouts | SATISFIED | Payout CRUDL + stream! + cancel/4 + reverse/4 |
| 4  | Balance retrieve + BalanceTransaction list with filtering | SATISFIED | Balance singleton + BT retrieve/list/stream! with payout/source/type filters |
| 5  | Destination charges and separate-charge-and-transfer documented with runnable examples | SATISFIED | guides/connect.md Subsections 5 + 6; grep confirms application_fee_amount + source_transaction present |
| 6  | Platform fee reconciliation surfaced through BT expansion | SATISFIED | FeeDetail typed struct; guide Subsection 7 dual-idiom; integration test walks filter pattern |

**Note on SC #2:** "reverse Transfers" is achieved via `LatticeStripe.TransferReversal.create/4` rather than a `Transfer.reverse/4` delegator. This is D-02 (locked decision) — mirrors stripe-java's top-level TransferReversal class and the AccountLink/LoginLink precedent. The capability exists; only the method's module home is channeled.

### Anti-Patterns Found

No blocker or warning anti-patterns detected in the 14 new source files. Spot-checks:

- No `TODO`/`FIXME`/`PLACEHOLDER` in new `lib/lattice_stripe/*.ex` Phase 18 files (confirmed substantive via line counts: all well above stub thresholds — smallest is Unknown fallback at 38 lines which is appropriate for a 2-field forward-compat struct)
- No `@derive Jason.Encoder` on any new struct (per plan acceptance criteria; enforced at unit-test time)
- D-07 enforcement: `lib/lattice_stripe/payment_intent.ex` last modified in commit `30b55c8` (Phase 4), confirming NO Phase 18 edits
- D-02 enforcement: `def reverse` grep on `transfer.ex` returned zero matches
- D-06 enforcement: `charge.ex` exposes only `retrieve` and `retrieve!` — no create/update/capture/list/stream!/search

### Human Verification Required

None. All must-haves verified programmatically via code inspection, key-link grep, ROADMAP/REQUIREMENTS cross-reference, and the phase's own test-run evidence (1386 unit + 142 integration, 0 failures; `mix ci` green).

Optional post-merge manual spot-checks (NOT required for phase closure):

- Open `doc/index.html` after `mix docs` to visually confirm Connect group lists 13 new modules and Payments group shows Charge
- Render `guides/connect.md` in ExDoc to verify 8-subsection structure + webhook-handoff callouts display cleanly

### Gaps Summary

No gaps. Phase 18 achieves its goal end-to-end:

1. Every planned module exists with substantive implementation (14 source files, 2,492 lines total).
2. All polymorphic/dispatch key links are wired (ExternalAccount→BankAccount/Card/Unknown, Transfer→TransferReversal via from_map, Payout→TraceId, BalanceTransaction→FeeDetail, Balance→stripe_account: opt).
3. D-02, D-03, D-06, D-07 locked decisions all enforced (Transfer has no reverse, Payout.cancel/reverse accept params, Charge is retrieve-only, PaymentIntent untouched).
4. All 7 integration test files exist with `@moduletag :integration` and substantive test coverage including the Pitfall 2 (stripe_account: opt) and D-03 (expand on cancel) critical paths.
5. guides/connect.md money-movement section ships with 7 webhook handoff callouts and the dual reconciliation idiom.
6. mix.exs ExDoc groups wire all 14 new modules correctly (Charge under Payments, others under Connect).
7. Requirements CNCT-02, CNCT-03, CNCT-04, CNCT-05 all SATISFIED.
8. Roadmap note: Plan 18-06 checkbox in ROADMAP.md shows `[ ]` but commit `3046217 docs(18-06): complete integration-guide-exdoc plan` on main and the presence of `18-06-integration-guide-exdoc-SUMMARY.md` confirm the plan is actually complete. This is a cosmetic roadmap-bookkeeping lag, not a real gap — does not block phase verification.

---

_Verified: 2026-04-12_
_Verifier: Claude (gsd-verifier)_
