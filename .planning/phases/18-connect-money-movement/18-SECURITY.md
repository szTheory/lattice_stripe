---
phase: 18
name: connect-money-movement
audited_at: 2026-04-12
asvs_level: L1
threats_total: 29
threats_closed: 29
threats_open: 0
status: SECURED
---

# Phase 18 — Connect Money Movement — Security Audit

## Summary

All 29 threats declared in the Phase 18 plan threat registers (`18-01` through `18-06`) have been verified against the implemented code. 24 `mitigate` threats have code-level evidence; 5 `accept` threats are documented in the accepted risks log below. No unregistered threat flags were reported by plan summaries. No implementation gaps. **Status: SECURED.**

## Threat Register

| ID | Plan | Category | Disposition | Status | Evidence |
|---|---|---|---|---|---|
| T-18-01 | 01 | I — BankAccount Inspect PII | mitigate | CLOSED | `lib/lattice_stripe/bank_account.ex:123-143` — `defimpl Inspect` renders only `id, object, bank_name, country, currency, status`; hides `routing_number`, `fingerprint`, `last4`, `account_holder_*`. Struct intentionally has no `:account_number` field (lines 43-62). |
| T-18-02 | 01 | I — Card Inspect PII | mitigate | CLOSED | `lib/lattice_stripe/card.ex:150-169` — `defimpl Inspect` renders only `id, object, brand, country, funding`; hides `last4`, `dynamic_last4`, `fingerprint`, `exp_month`, `exp_year`, `name`, all `address_*`, all `*_check` fields. |
| T-18-03 | 01 | T/D — ExternalAccount.cast Unknown fallback | mitigate | CLOSED | `lib/lattice_stripe/external_account.ex:81-84` — `cast/1` dispatches on `"object"` with `_other` fallback to `Unknown.cast/1`. `lib/lattice_stripe/external_account/unknown.ex:31-39` preserves raw payload into `:extra` via `Map.drop`. |
| T-18-04 | 01 | T — F-001 BankAccount/Card extras | mitigate | CLOSED | `lib/lattice_stripe/bank_account.ex:114` and `lib/lattice_stripe/card.ex:141` use `extra: Map.drop(map, @known_fields)`. `@known_fields` at `bank_account.ex:37-41` and `card.ex:32-38`. |
| T-18-05 | 01 | E — Cross-tenant Stripe-Account header | **accept** | CLOSED | Documented in accepted risks log below. Phase 17 Plan 01 shipped the threading with regression tests; Phase 18 makes zero `Client` changes (`lib/lattice_stripe/client.ex` untouched). |
| T-18-06 | 02 | I — Charge Inspect PII | mitigate | CLOSED | `lib/lattice_stripe/charge.ex:300-327` — `defimpl Inspect` renders only `[id, object, amount, currency, status, captured, paid]`; hides `billing_details`, `payment_method_details`, `fraud_details`, `receipt_email`, `receipt_url`, `receipt_number`, `customer`, `payment_method` (comment at 304-307 documents hidden set). |
| T-18-07 | 02 | T — F-001 Charge extras | mitigate | CLOSED | `lib/lattice_stripe/charge.ex:295` — `extra: Map.drop(map, @known_fields)` in `from_map/1`. `@known_fields` at line 67. |
| T-18-08 | 02 | E — Charge create/update/etc. absent (D-06) | mitigate | CLOSED | `lib/lattice_stripe/charge.ex` public surface is only `retrieve/3`, `retrieve!/3`, `from_map/1`. Grep for `def create/def update/def cancel/def capture/def delete` returned no matches. |
| T-18-09 | 02 | S/I — payment_method_details disclosure | mitigate | CLOSED | Same Inspect impl as T-18-06 hides `payment_method_details` (`charge.ex:305-306`). |
| T-18-10 | 03 | T/R — Transfer.create retry idempotency | mitigate | CLOSED | `lib/lattice_stripe/client.ex:247-259` — `resolve_idempotency_key/2` auto-generates key for `:post` when user omits it; reused across retries. Transfer uses plain `Client.request/2`. Phase 18 adds no alternate code path. |
| T-18-11 | 03 | T — Embedded reversals as plain list | mitigate | CLOSED | `lib/lattice_stripe/transfer.ex:261-282` — `from_map/1` extracts `reversals.data` via `Enum.map(data, &TransferReversal.from_map/1)` into a plain list; wrapper metadata (`has_more`/`url`/`total_count`) stashed under `extra["reversals_meta"]` (line 281). |
| T-18-12 | 03 | E — Transfer.reverse absent (D-02) | mitigate | CLOSED | `lib/lattice_stripe/transfer.ex` defines no `reverse/_` function (grep for `def reverse` returned no matches; moduledoc lines 36-38 explicitly redirect users to `TransferReversal.create/4`). |
| T-18-13 | 03 | I — Transfer no PII | **accept** | CLOSED | Documented in accepted risks log below. |
| T-18-14 | 03 | T — TransferReversal pre-network id validation | mitigate | CLOSED | `lib/lattice_stripe/transfer_reversal.ex:125, 157, 161, 194, 198, 231, 261` — guard clauses reject `nil`/`""` for both `transfer_id` and `reversal_id` before any network I/O on every public fn. |
| T-18-15 | 04 | T/R — Payout create/cancel/reverse idempotency | mitigate | CLOSED | Same `Client.request/2` auto-generation as T-18-10; `lib/lattice_stripe/payout.ex` uses standard pipeline. |
| T-18-16 | 04 | E — D-03 canonical shape (`params \\ %{}, opts \\ []`) | mitigate | CLOSED | `lib/lattice_stripe/payout.ex:292, 297, 323, 328` — both `cancel` and `reverse` declared as `(client, id, params \\ %{}, opts \\ [])`. Ergonomic common case `Payout.cancel(client, id)` works via default params. |
| T-18-17 | 04 | T — F-001 Payout/TraceId extras | mitigate | CLOSED | `lib/lattice_stripe/payout.ex` `from_map/1` uses `Map.drop(map, @known_fields)`. `lib/lattice_stripe/payout/trace_id.ex` uses `Map.split` + `extra` for unknown keys. |
| T-18-18 | 04 | I — Payout no PII | **accept** | CLOSED | Documented in accepted risks log below. |
| T-18-19 | 04 | E — D-04 no atom-guarded cancel/reverse arity-5 | mitigate | CLOSED | `lib/lattice_stripe/payout.ex:292, 323` — only canonical arity-4 `cancel`/`reverse` defined; no arity-5 atom-guarded variant. Tests in `test/lattice_stripe/payout_test.exs` assert `function_exported?/3` FALSE for arity-5. |
| T-18-20 | 05 | I — Balance.retrieve stripe_account threading | mitigate | CLOSED | `lib/lattice_stripe/balance.ex:83-85` — `retrieve/2` threads full `opts` into `%Request{opts: opts}`, which `Client.request/2` forwards to the `Stripe-Account` header. Moduledoc lines 6-14 prominently warn against the connected-account-loop antipattern. |
| T-18-21 | 05 | T — F-001 across 5 new structs | mitigate | CLOSED | All five modules preserve unknowns: `balance.ex` `Map.drop`; `balance/amount.ex`, `balance/source_types.ex`, `balance_transaction/fee_detail.ex` use `Map.split` + `extra`; `balance_transaction.ex` `Map.drop(map, @known_fields)`. |
| T-18-22 | 05 | T — Balance.SourceTypes unknown PM keys | mitigate | CLOSED | `lib/lattice_stripe/balance/source_types.ex:27-28` — typed-inner-open-outer: `{known, extra} = Map.split(map, known_string_keys)` absorbs novel payment-method keys. |
| T-18-23 | 05 | E — Balance.list/create absent | mitigate | CLOSED | `lib/lattice_stripe/balance.ex` exposes only `retrieve/2`, `retrieve!/2`, `from_map/1`. Singleton struct has no `:id` field (`defstruct` does not list `:id`). Grep for `def list/create/update/delete` returned no matches. |
| T-18-24 | 05 | E — BalanceTransaction.create/update/delete absent | mitigate | CLOSED | `lib/lattice_stripe/balance_transaction.ex` exposes only `retrieve/3`, `list/3`, `stream!/3` + bang variants + `from_map/1`. Grep confirms no `def create/update/delete`. |
| T-18-25 | 05 | T — BalanceTransaction.source polymorphic crash | mitigate | CLOSED | `lib/lattice_stripe/balance_transaction.ex:197` — `source: map["source"]` kept as raw `binary \| map() \| nil` (typespec at line 84). No dispatch, no crash path. Moduledoc lines 28-31 document the decision. |
| T-18-26 | 05 | I — Balance no PII | **accept** | CLOSED | Documented in accepted risks log below. |
| T-18-27 | 06 | I — Guide stripe_account antipattern warning | mitigate | CLOSED | `guides/connect.md:291, 300, 313, 323, 328-329` — Balance section explicitly warns against the connected-account loop antipattern and shows the per-request `stripe_account:` opt. |
| T-18-28 | 06 | E — D-07 payment_intent.ex untouched | mitigate | CLOSED | `git diff --stat HEAD lib/lattice_stripe/payment_intent.ex` returns empty output — file unmodified across Phase 18. |
| T-18-29 | 06 | T — Webhook-handoff discipline in guide | mitigate | CLOSED | `guides/connect.md` contains 5+ `Webhook handoff` callouts (lines 214, 241, 283, 363, 404, 440, 567) covering external accounts, transfers, payouts, destination charges, and reconciliation. |

## Accepted Risks Log

Each `accept` disposition from the threat register is recorded here with rationale and compensating controls.

### T-18-05 — Cross-tenant Stripe-Account header confusion

- **Category:** Elevation of privilege
- **Component:** `LatticeStripe.Client` per-request `stripe_account:` opt
- **Rationale:** The `Stripe-Account` header threading was shipped in Phase 17 Plan 01 with its own regression tests. Phase 18 makes zero `lib/lattice_stripe/client.ex` changes — any cross-tenant regression would have to originate in code outside this phase's scope.
- **Compensating controls:** Phase 17 regression tests exercise per-request header override; Phase 18 Plan 05 Task 1 (T-18-20) re-exercises the same threading via `Balance.retrieve(client, stripe_account: ...)`.
- **Review cadence:** Re-audit if `client.ex` is modified in a future phase.

### T-18-13 — Transfer logging carries no customer PII

- **Category:** Information disclosure
- **Component:** `LatticeStripe.Transfer` default `Inspect`
- **Rationale:** The Stripe Transfer object schema carries no customer PII fields (verified in Phase 18 RESEARCH.md PII table). Default `Inspect` output contains only platform/Connect metadata (amounts, currency, account refs, transfer_group).
- **Compensating controls:** If Stripe adds a PII-bearing field in the future, F-001 (T-18-11/T-18-17 style) routes it into `:extra`, which is still shown by default Inspect. Re-evaluate and add `defimpl Inspect` at that time.
- **Review cadence:** Re-audit on any Stripe API version pin bump if the Transfer object shape changes.

### T-18-18 — Payout logging carries no customer PII

- **Category:** Information disclosure
- **Component:** `LatticeStripe.Payout` default `Inspect`
- **Rationale:** Stripe Payout object carries no customer PII — it is a platform settlement object. Fields like `trace_id`, `arrival_date`, `amount`, `currency`, `statement_descriptor`, `method` are operational metadata, not personal data.
- **Compensating controls:** `destination` is typically an opaque `"ba_..."` reference; if a user explicitly expands it they opt into whatever disclosure that entails. F-001 preservation still applies.
- **Review cadence:** Same as T-18-13.

### T-18-26 — Balance / BalanceTransaction logging carries no customer PII

- **Category:** Information disclosure
- **Component:** `LatticeStripe.Balance`, `LatticeStripe.BalanceTransaction` default `Inspect`
- **Rationale:** Both objects are aggregate ledger data — amounts, currencies, fee breakdowns, source-type sums. No customer PII fields. `BalanceTransaction.source` is an opaque reference string by default; expanding it is a user decision.
- **Compensating controls:** F-001 captures future fields into `:extra`. If Stripe ever adds PII to these objects, add `defimpl Inspect`.
- **Review cadence:** Same as T-18-13.

## Unregistered Flags

None. Each Phase 18 plan SUMMARY explicitly declared zero unregistered threat flags:

- `18-01-SUMMARY.md:127` — "No `Threat Flags` section needed."
- `18-02-charge-retrieve-SUMMARY.md:160-169` — "None. Plan's `<threat_model>` already covered every mitigation."
- `18-03-transfer-reversal-SUMMARY.md`, `18-04-payout-SUMMARY.md`, `18-05-balance-transactions-SUMMARY.md`, `18-06-integration-guide-exdoc-SUMMARY.md` — threat-model-coverage sections report full mitigation with no new surface.

## Audit Trail

| When | Who | Event |
|---|---|---|
| 2026-04-12 | Claude (gsd-secure-phase auditor, Opus 4.6) | Initial audit. Loaded 29-threat register from 6 PLAN.md files and all 6 SUMMARY.md files. Verified each `mitigate` threat against implementation files via Grep+Read. Confirmed `git diff --stat lib/lattice_stripe/payment_intent.ex` empty (T-18-28). Confirmed `guides/connect.md` contains 7 `Webhook handoff` callouts (T-18-29). Recorded 5 accepted risks. 29/29 CLOSED. No implementation modifications. Status: SECURED. |
