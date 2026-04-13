# Phase 18: Connect Money Movement - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in 18-CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 18-connect-money-movement
**Areas discussed:** A (ExternalAccount shape), B (Action verbs & reversals), C (Struct shapes & budgets), D (Destination charges + fees)
**Mode:** Interactive discuss with parallel research (4× gsd-advisor-researcher agents) per user directive "research using subagents, best practices, idiomatic Elixir, pros/cons/tradeoffs, one-shot recommendation"

---

## Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| A: ExternalAccount shape | Polymorphic bank_account/card modeling — single struct with object discriminator, two structs + dispatcher module, or tagged tuple. Drives the whole module's ergonomics. | ✓ |
| B: Action verbs & reversals | TransferReversal as top-level module vs Transfer.reverse/4 action verb. Payout.cancel signature. Atom-guarded method/type enums (instant/standard). | ✓ |
| C: Struct shapes & budgets | Which fields on Transfer/Payout/Balance/BalanceTransaction promote to typed structs vs plain maps (P17 D-01 rule). Balance singleton shape (no id). available[]/pending[] modeling. | ✓ |
| D: Destination charges + fees | Code changes to PaymentIntent (typed application_fee_amount/transfer_data) vs pure guide content. BalanceTransaction.reconcile/3 helper vs raw expand idiom for platform-fee reconciliation. | ✓ |

**User's choice:** All four areas selected for parallel research.
**Notes:** User explicitly directed: "for each of these research using subagents, what is best practices, idiomatic for elixir/plug/ecto/phoenix, great dx, principle of least surprise, great for happy path, error cases and boundary conditions. fits into goals/vision for this lib, lessons learned from other stripe libs... research online gives pros/cons/tradeoffs examples discussed give ur one-shot recommendation."

---

## A: ExternalAccount shape

Four options were researched in depth. Cross-SDK evidence survey covered stripity_stripe, stripe-go, stripe-ruby, stripe-python, stripe-node, stripe-java.

| Option | Description | Selected |
|--------|-------------|----------|
| 1. Single flat `%ExternalAccount{}` with `object` discriminator | One struct, ~30 nullable fields, `:extra` fallback; `defimpl Inspect` straddles two PII domains; matches only stripity_stripe v3 degenerate codegen. | |
| 2. `LatticeStripe.BankAccount` + `LatticeStripe.Card` first-class + `LatticeStripe.ExternalAccount` dispatcher + `ExternalAccount.Unknown` fallback | Two real structs with own `@known_fields`, own `defimpl Inspect`; dispatcher owns CRUD + `cast/1` branching on `"object"`; Phoenix-context `case %A{} -> ; %B{} ->` idiomatic; matches 4/5 official SDKs. | ✓ |
| 3. Tagged tuple `{:bank_account, %BankAccount{}} \| {:card, %Card{}}` | Non-idiomatic for domain objects; breaks `{:ok, struct}` convention producing `{:ok, {:bank_account, %BankAccount{}}}`. | |
| 4. Nested wrapper `%ExternalAccount{type: :bank_account, data: %BankAccount{}}` | Double indirection, duplicates `id`, invents structure Stripe's API doesn't have. | |

**User's choice:** Option 2 (via one-shot recommendation from research; confirmed implicitly through acceptance).
**Notes:** Research agent's one-shot rec was unambiguous. No follow-up discussion needed. Module layout locked in D-01.

---

## B: Action verbs & reversals

Three sub-questions researched together.

### B.1 — TransferReversal placement

| Option | Description | Selected |
|--------|-------------|----------|
| (a) `LatticeStripe.TransferReversal` top-level module only | Matches `AccountLink`/`LoginLink` precedent; Stripe API reference TOC treats reversals as distinct resource; grep-friendly; matches stripity_stripe + stripe-java. | ✓ |
| (b) `LatticeStripe.Transfer.reverse/4` action verb only | Forces `Transfer.retrieve_reversal/4` + `update_reversal/5` + `list_reversals/3` polluting Transfer surface. | |
| (c) Both — module + thin `Transfer.reverse/4` delegator | Two ways to do the same thing; no other LatticeStripe module has such a delegator. | |

### B.2 — Payout.cancel and Payout.reverse signatures

| Option | Description | Selected |
|--------|-------------|----------|
| (i) `cancel(client, id, opts)` — no params map | Factually wrong; Stripe accepts `expand` on cancel/reverse; forces later breaking change. | |
| (ii) `cancel(client, id, params \\ %{}, opts \\ [])` — canonical shape | Consistent with `create`/`update`; accepts `expand` and future server-side additions; default arg keeps common case ergonomic. | ✓ |

### B.3 — Atom-guarded enums in Phase 18

| Option | Description | Selected |
|--------|-------------|----------|
| No atom-guarded dispatchers in Phase 18 | Coheres with P15 D5 / P17 D-04; every Phase 18 candidate fails the heuristic. | ✓ |
| Lift `Payout.create` `method: :instant \| :standard` to positional shortcut | Violates P15 D5; inconsistent with multi-field-create precedent. | |

**User's choice:** Option (a) + (ii) + "no atom guards" — full one-shot recommendation from research accepted.
**Notes:** Research agent confirmed the P17 D-04 heuristic is correctly exclusionary for Phase 18; this is a feature, not a gap. Locked in D-02, D-03, D-04.

---

## C: Struct shapes & budgets

Per-resource analysis against the P17 D-01 amended budget (5 distinct modules per resource, reuse is free).

| Resource | Candidate field | Promote? | Shared? | Selected |
|---|---|---|---|---|
| Transfer | `reversals.data[]` | YES — reuse `TransferReversal` from gray area B | Shared (free) | ✓ |
| Transfer | `source_transaction`/`destination_payment`/`balance_transaction` | No — expandable refs | — | ✓ (stay as ref) |
| Payout | `trace_id` `{status, value}` | YES — `Payout.TraceId` | No | ✓ (1 slot) |
| Payout | `failure_balance_transaction`/`balance_transaction` | No — expandable refs | — | ✓ (stay as ref) |
| Payout | `destination` | No — keep as string id | — | ✓ |
| Balance | `available[]` + `pending[]` + `connect_reserved[]` + `instant_available[]` + `issuing.available[]` | YES — one `Balance.Amount` reused 5× | Shared | ✓ |
| Balance | `source_types` `{card, bank_account, fpx}` | YES — `Balance.SourceTypes` embedded in every `Balance.Amount` | Embedded, reused | ✓ |
| Balance | `instant_available[].net_available` | No — absorbed via `:extra` per P17 D-02 | — | ✓ (save budget slot) |
| BalanceTransaction | `fee_details[]` | YES — `BalanceTransaction.FeeDetail` | No | ✓ (1 slot) |
| BalanceTransaction | `source` polymorphic | No — stay opaque `binary \| map()` | — | ✓ (16-variant too expensive) |

**Balance singleton retrieve signature:**

| Option | Description | Selected |
|--------|-------------|----------|
| `retrieve(client, opts \\ [])` | Client-first consistency; opts slot 2 carries `stripe_account:` override (critical for Connect balance per connected account). | ✓ |
| `retrieve(client)` no opts | Blocks `stripe_account:` override — the #1 Connect use case. | |
| `get/1`, `fetch/1` naming | Breaks SDK-wide `retrieve` verb convention. | |

**User's choice:** Full one-shot recommendation accepted; `Payout.TraceId` confirmed via explicit follow-up question (see below).

**Follow-up question asked:** "Payout.TraceId — promote the 2-field `{status, value}` shape to a typed struct?"

| Option | Description | Selected |
|--------|-------------|----------|
| Promote (1 budget slot) | Ship `Payout.TraceId` struct. Rationale: stable 2-field shape, `status` is pattern-match target, every typed peer SDK (go/ruby/java) promotes it. | ✓ |
| Leave as plain map | Save the budget slot; users access via `payout.trace_id["status"]`. | |

**User's choice:** Promote.
**Notes:** 4 total new nested modules (Payout.TraceId, Balance.Amount, Balance.SourceTypes, BalanceTransaction.FeeDetail) + 1 reused (TransferReversal). All four resources comfortably inside budget. Locked in D-05.

---

## D: Destination charges + fees

### D.1 — Destination charges: code or docs?

| Option | Description | Selected |
|--------|-------------|----------|
| 1. Pure guide, no code changes | `PaymentIntent` already types `application_fee_amount`, `transfer_data`, `on_behalf_of`, `transfer_group` (verified `payment_intent.ex:66–77, 139–173`); zero maintenance; matches every surveyed SDK. | ✓ |
| 2. Typed `PaymentIntent.TransferData` nested struct | 2-key map not worth a module; response/param asymmetry already exists elsewhere via `:extra`. | |
| 3. `create_destination_charge/4` convenience wrapper | Textbook fake ergonomics; thin wrapper around existing create with same params rearranged. | |
| 4. Retroactive `@known_fields` audit of PaymentIntent | Already done — fields present per scout. | |

### D.2 — Platform fee reconciliation: expand idiom or helper?

| Option | Description | Selected |
|--------|-------------|----------|
| 1. Raw `expand: ["balance_transaction"]` idiom, documented in guide | Matches Stripe docs 1:1; works for per-charge and per-payout reconciliation; zero maintenance. | ✓ |
| 2. `BalanceTransaction.reconcile/3` convenience | Fake ergonomics — hides one param behind ambiguous "reconcile" naming. | |
| 3. `Charge.fees/1` pure accessor returning `[FeeDetail.t()]` | Considered; deferred to planning if guide reads awkwardly. | |
| 4. `BalanceTransaction.list(payout: id)` batch idiom | Already supported natively by Stripe; document as guide example alongside option 1. | ✓ (as guide example) |

**Follow-up question asked:** "Minimal LatticeStripe.Charge module — ship in Phase 18 or defer?"

| Option | Description | Selected |
|--------|-------------|----------|
| Ship Charge.retrieve only | Add `LatticeStripe.Charge` with `retrieve/3` + `retrieve!/3` + `from_map/1` only. Unblocks per-payout reconciliation guide walking `BalanceTransaction.source` → Charge. | ✓ |
| Write guide first, decide in planning | Defer decision to plan execution. | |
| Defer Charge entirely | Phase 18 ships zero Charge surface. | |

**User's choice:** Ship Charge.retrieve only — reduces risk that guide execution blocks on missing module.
**Notes:** Research agent flagged the memory claim "Charge was deleted in 39b98c9" as inaccurate; `lib/lattice_stripe/charge.ex` has never existed in git history. Memory-hygiene follow-up logged in 18-CONTEXT.md specifics section. Locked in D-06, D-07.

---

## Claude's Discretion

Areas where Claude has flexibility during planning/execution:
- Exact field order in each nested struct (follow Stripe API doc order)
- Exact moduledoc wording, examples, and heading structure (follow Phase 14/15/16/17 patterns)
- Test fixture shapes for the 11 new fixture modules
- stripe-mock integration test coverage depth
- ExDoc module group wiring details (Connect group from Phase 17 + Payments group for Charge)
- `@typedoc` uniformity vs resource-specific wording (resource-specific wins per P10 D-03)
- Exact `defimpl Inspect` PII hide-lists (audit against stripe-node's published list)
- Wave ordering within the phase plan (executor decides; suggested 4-wave split in D-06)

---

## Deferred Ideas

Ideas raised during discussion that belong in other phases or later iterations:
- `LatticeStripe.Charge.create`/`update`/`capture`/`list`/`search` — PaymentIntent-first philosophy
- `LatticeStripe.ApplicationFee` + `LatticeStripe.ApplicationFee.Refund` resources
- `LatticeStripe.Topup` (Connect platform balance funding)
- Customer-owned external accounts (`/v1/customers/:id/bank_accounts` and `/v1/customers/:id/sources`)
- `PaymentIntent.TransferData` nested typed struct
- `Charge.fees/1` pure accessor
- `BalanceTransaction.for_payout/2` alias
- `BalanceTransaction.source` polymorphic typed union
- `Payout.create_destination_charge/4` and separate-charge-and-transfer wrappers
- `ExternalAccount.Unknown` generalization to other polymorphic response shapes
- Memory hygiene follow-up: update `project_phase12_13_deletion.md` to remove inaccurate Charge-deletion claim
