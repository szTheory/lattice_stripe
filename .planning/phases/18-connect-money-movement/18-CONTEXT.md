# Phase 18: Connect Money Movement - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning
**Milestone:** v2.0-connect (second and final phase of Connect track; completes Connect + closes the path to v1.0 via Phase 19 polish)

<domain>
## Phase Boundary

Developers can move money on the Stripe Connect platform end-to-end — attach and manage bank accounts and debit cards on connected accounts via a polymorphic `LatticeStripe.ExternalAccount` surface, transfer funds between the platform and connected accounts via `LatticeStripe.Transfer` + `LatticeStripe.TransferReversal`, trigger and cancel payouts via `LatticeStripe.Payout`, inspect the platform and connected-account balances via `LatticeStripe.Balance`, walk settled fee ledgers via `LatticeStripe.BalanceTransaction`, and integrate destination charges + separate-charge-and-transfer patterns with the existing `LatticeStripe.PaymentIntent` API through guide-only documentation. Phase 18 also ships a minimal `LatticeStripe.Charge` (retrieve-only) to unblock per-payout fee reconciliation.

**Requirements:** **CNCT-02** (Transfers + Payouts), **CNCT-03** (destination charges vs separate charge/transfer patterns), **CNCT-04** (platform fee handling + reconciliation), **CNCT-05** (Balance + BalanceTransactions).

**In scope:**
- `LatticeStripe.BankAccount` — typed resource struct, F-001 `@known_fields` + `:extra`, PII-safe `defimpl Inspect` (scrub `routing_number`, `account_number`, `fingerprint`)
- `LatticeStripe.Card` — typed resource struct, F-001, PII-safe `defimpl Inspect` (scrub `last4`, `fingerprint`, `exp_month`/`exp_year` to prevent correlation)
- `LatticeStripe.ExternalAccount` — dispatcher module owning all external-account CRUD; `cast/1` branches on `"object"` returning `BankAccount.t() | Card.t() | ExternalAccount.Unknown.t()`; `create/3`, `retrieve/3`, `update/4`, `delete/3`, `list/3`, `stream!/3` + bang variants
- `LatticeStripe.ExternalAccount.Unknown` — F-001 forward-compat fallback for future Stripe external-account object types
- `LatticeStripe.Transfer` — full CRUD (`create/3`, `retrieve/3`, `update/4`, `list/3`, `stream!/3`) + bang variants. **No** `reverse` delegator (see D-03).
- `LatticeStripe.TransferReversal` — top-level module with full CRUD (`create/4`, `retrieve/4`, `update/5`, `list/3`, `stream!/3`) + bang variants. Addressed by `(transfer_id, reversal_id)` tuple per Stripe URL `/v1/transfers/:transfer/reversals/:id`. Mirrors `AccountLink`/`LoginLink` standalone pattern.
- `LatticeStripe.Payout` — full CRUD + `cancel/4` + `reverse/4` (both canonical `(client, id, params \\ %{}, opts \\ [])` shape) + bang variants
- `LatticeStripe.Payout.TraceId` — nested typed struct `{status, value}` (1 budget slot)
- `LatticeStripe.Balance` — singleton `retrieve(client, opts \\ [])` + `retrieve!/2`. No id, no list, no create/update/delete.
- `LatticeStripe.Balance.Amount` — nested typed struct reused across 5 parent fields (`available[]`, `pending[]`, `connect_reserved[]`, `instant_available[]`, `issuing.available[]`)
- `LatticeStripe.Balance.SourceTypes` — nested typed struct embedded inside every `Balance.Amount`; `:extra` absorbs future payment-method keys
- `LatticeStripe.BalanceTransaction` — `retrieve/3`, `list/3`, `stream!/3` + bang variants. No create/update/delete (Stripe has no such endpoints).
- `LatticeStripe.BalanceTransaction.FeeDetail` — nested typed struct `{amount, currency, description, type, application}`
- `LatticeStripe.Charge` — **retrieve-only**: `retrieve/3`, `retrieve!/3`, `from_map/1`. `@known_fields` covers Connect-relevant fields listed in D-06. No `create`, `update`, `capture`, `list`, `stream!`, or `search`. Bangs present on the one fallible public fn.
- stripe-mock integration tests covering: ExternalAccount polymorphic CRUD (bank + card + mixed list), Transfer lifecycle, TransferReversal create+list, Payout lifecycle including `cancel` and `reverse`, Balance retrieve (platform + per-connected-account via `stripe_account:` override), BalanceTransaction list filtered by `payout:`, Charge retrieve with `balance_transaction` expansion
- `guides/connect.md` **money-movement section** appended to Phase 17's onboarding half — covers the full outline in D-07
- ExDoc "Connect" module group updated to include all new modules (append to the existing Phase 17 "Connect" group; no new group)
- Webhook-handoff callouts at every money-movement narrative transition (PaymentIntent → charge.succeeded → application_fee.created → payout.paid)

**Out of scope:**
- `LatticeStripe.Charge.create/update/capture/list/search` — Stripe's modern API is PaymentIntent-first; Charge retrieval is the only Charge verb that earns its keep in Phase 18
- `LatticeStripe.ApplicationFee` and `LatticeStripe.ApplicationFee.Refund` resources — not required by CNCT-02..05 literal text; fee reconciliation reads `BalanceTransaction.fee_details` where `type == "application_fee"` which is the canonical path. Revisit in a later phase if demand surfaces.
- Per-request convenience wrappers: `create_destination_charge/4`, `create_with_transfer/5`, `BalanceTransaction.reconcile/3`, `BalanceTransaction.for_payout/2`, `Charge.fees/1`, `Payout.method_enum/1` — all rejected as fake ergonomics (see D-01, D-04)
- `PaymentIntent.TransferData` typed nested struct — 2-key map, not worth a module slot; `transfer_data` stays as plain map on `%PaymentIntent{}` (already present via `:extra`/`@known_fields`)
- Atom-guarded action verbs anywhere in Phase 18 — the P17 D-04 heuristic correctly refuses to fire (see D-04)
- `Payout.create` `method: :instant | :standard` positional shortcut — multi-field create, keeps `method` inside params map as a plain atom typed via `@spec` (stripity_stripe precedent)
- `BalanceTransaction.source` polymorphic typed union — 16-variant polymorphism, documented opaque `binary | map()` with "expand then manually cast via the expected resource module" idiom in the guide
- Customer-owned external accounts (`/v1/customers/:id/bank_accounts` and `/v1/customers/:id/sources`) — Phase 18 covers connected-account external accounts only; customer-side surfaces compose naturally with `BankAccount`/`Card` modules if a later phase needs them (no refactor required)
- `LatticeStripe.Topup` resource — Connect platform funding of the platform balance; not in CNCT-02..05, defer
- `PaymentIntent` code changes to surface destination-charge fields — fields are **already** typed in `payment_intent.ex:66–77, 139–173` (`application_fee_amount`, `transfer_data`, `on_behalf_of`, `transfer_group`); verified during scout

</domain>

<decisions>
## Implementation Decisions (Locked — D-01..D-07)

### D-01 — ExternalAccount polymorphism: two first-class structs + dispatcher

**Ship Option 2 from gray area A research.** Mirrors 4 of the 5 official Stripe SDKs (stripe-ruby, stripe-python, stripe-node, stripe-java) and every Elixir ecosystem idiom for domain-object sum types.

**Module layout:**

```
lib/lattice_stripe/
  bank_account.ex              # %LatticeStripe.BankAccount{} + F-001 + defimpl Inspect
  card.ex                      # %LatticeStripe.Card{} + F-001 + defimpl Inspect
  external_account.ex          # dispatcher — owns all CRUD + cast/1
  external_account/
    unknown.ex                 # %LatticeStripe.ExternalAccount.Unknown{} forward-compat fallback
```

**Dispatcher `cast/1` (the crux):**

```elixir
def cast(%{"object" => "bank_account"} = raw), do: LatticeStripe.BankAccount.cast(raw)
def cast(%{"object" => "card"}          = raw), do: LatticeStripe.Card.cast(raw)
def cast(%{"object" => other}           = raw), do: LatticeStripe.ExternalAccount.Unknown.cast(raw, other)
```

**Return types:**

```elixir
@spec create(Client.t(), account_id :: String.t(), params :: map(), opts :: keyword()) ::
        {:ok, BankAccount.t() | Card.t() | Unknown.t()} | {:error, Error.t()}
```

Bang variants unwrap the sum identically.

**CRUD functions live on `ExternalAccount`** (the endpoint's URL is `/v1/accounts/:id/external_accounts/:id` — that's the endpoint's identity, not the response's). `BankAccount` and `Card` modules stay as **data + helpers** without their own HTTP functions in Phase 18; customer-side `sources` can later add `BankAccount.retrieve_for_customer/3` etc. without disturbing anything.

**`Unknown` fallback shape** — same F-001 structure as every other resource:

```elixir
defmodule LatticeStripe.ExternalAccount.Unknown do
  @moduledoc """
  Forward-compatibility fallback for `LatticeStripe.ExternalAccount` responses
  whose `object` is neither `"bank_account"` nor `"card"`. Preserves the raw
  payload in `:extra` so user code does not crash on a new Stripe object type.
  Callers should match `%LatticeStripe.BankAccount{}` or `%LatticeStripe.Card{}`
  first and treat `%LatticeStripe.ExternalAccount.Unknown{}` as an escape hatch.
  """
  @known_fields ~w(id object)a
  defstruct @known_fields ++ [extra: %{}]
  @type t :: %__MODULE__{id: String.t() | nil, object: String.t() | nil, extra: map()}
  # cast/2 stores the full raw payload in extra; never crashes on unknown keys
end
```

**PII-safe Inspect:**
- `BankAccount` — hide `routing_number`, `account_number`, `fingerprint`, `account_holder_name`
- `Card` — hide `last4`, `fingerprint`, `exp_month`, `exp_year`, `address_line1_check`, `cvc_check`, `address_zip_check`, `name`

Audit against stripe-node's published PII field list during planning to ensure the hide-list is complete.

**Rejected alternatives (from research):**
- **Option 1 (single flat struct with `object` discriminator)** — mixes bank and card fields on one struct with ~30 nullable fields; `defimpl Inspect` must straddle two PII domains; fights Phoenix-context `case %A{} -> ; %B{} ->` pattern; matches only stripity_stripe v3's degenerate codegen artifact.
- **Option 3 (tagged tuple `{:bank_account, %BankAccount{}}`)** — non-idiomatic for domain objects in Elixir; nests inside `{:ok, ...}` producing `{:ok, {:bank_account, %BankAccount{}}}` which breaks every other LatticeStripe resource's return convention.
- **Option 4 (nested wrapper `%ExternalAccount{type: :bank_account, data: %BankAccount{}}`)** — double indirection (`ea.data.last4`), duplicates `id` across outer and inner, no ecosystem precedent, invents structure Stripe's API doesn't have.

### D-02 — Transfer + TransferReversal: standalone module, no delegator

**Ship `LatticeStripe.TransferReversal` as a top-level module.** `Transfer` does **not** gain a `reverse/4` function. Users reach for `TransferReversal.create/4`.

**Rationale:** Exact parallel to P17 `AccountLink`/`LoginLink` precedent. Stripe's own API reference treats Transfer Reversals as a distinct resource with its own TOC section. Every Elixir ecosystem idiom for sub-resources with independent CRUD puts them in their own module (Ecto.Changeset, Ecto.Multi, Oban.Pro.Workers). stripe-java — the other most-Elixir-adjacent typed SDK — ships `com.stripe.model.TransferReversal` as a top-level class. Adding `Transfer.reverse/4` alone would force either `Transfer.retrieve_reversal/4 + Transfer.update_reversal/5 + Transfer.list_reversals/3` polluting Transfer's surface, or an asymmetric incomplete API where reversals can be created via Transfer but retrieved elsewhere.

**Signatures:**

```elixir
defmodule LatticeStripe.TransferReversal do
  @spec create(Client.t(), transfer_id :: String.t(), params :: map(), opts :: keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def create(client, transfer_id, params, opts \\ [])
  def create!(client, transfer_id, params, opts \\ [])

  @spec retrieve(Client.t(), transfer_id :: String.t(), reversal_id :: String.t(), opts :: keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def retrieve(client, transfer_id, reversal_id, opts \\ [])
  def retrieve!(client, transfer_id, reversal_id, opts \\ [])

  @spec update(Client.t(), transfer_id :: String.t(), reversal_id :: String.t(), params :: map(), opts :: keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def update(client, transfer_id, reversal_id, params, opts \\ [])
  def update!(client, transfer_id, reversal_id, params, opts \\ [])

  @spec list(Client.t(), transfer_id :: String.t(), params :: map(), opts :: keyword()) ::
          {:ok, LatticeStripe.List.t(t())} | {:error, Error.t()}
  def list(client, transfer_id, params \\ %{}, opts \\ [])
  def list!(client, transfer_id, params \\ %{}, opts \\ [])

  def stream!(client, transfer_id, params \\ %{}, opts \\ [])
end
```

**`require_param!/2`** on both `transfer_id` and `reversal_id` where present, pre-network.

**Transfer's `reversals` list field on `%Transfer{}`** — `reversals.data` casts to `[%LatticeStripe.TransferReversal{}]` via the same module above. The outer paginated sublist wrapper (`has_more`, `url`, `total_count`) lands in `:extra`.

### D-03 — Payout.cancel and Payout.reverse: canonical shape with default params

**Both functions take the canonical `(client, id, params \\ %{}, opts \\ [])` shape.** Every surveyed Stripe SDK accepts `expand` on both endpoints, and `reverse` additionally accepts `metadata`. "No body" on Stripe is a myth; dropping `params` forces a breaking change the first time someone needs `expand: ["balance_transaction"]`.

```elixir
@spec cancel(Client.t(), payout_id :: String.t(), params :: map(), opts :: keyword()) ::
        {:ok, t()} | {:error, Error.t()}
def cancel(client, id, params \\ %{}, opts \\ [])
def cancel!(client, id, params \\ %{}, opts \\ [])

@spec reverse(Client.t(), payout_id :: String.t(), params :: map(), opts :: keyword()) ::
        {:ok, t()} | {:error, Error.t()}
def reverse(client, id, params \\ %{}, opts \\ [])
def reverse!(client, id, params \\ %{}, opts \\ [])
```

Both call `require_param!(id, "payout id")` before any HTTP I/O. Common case `LatticeStripe.Payout.cancel(client, "po_123")` stays ergonomic via the `\\ %{}` default. No atom guards.

### D-04 — Zero atom-guarded dispatchers in Phase 18

The P17 D-04 heuristic (atom guard earns its keep when dedicated single-purpose verb + small closed stable enum + compile-time literals) correctly refuses to fire anywhere in Phase 18:

| Candidate | Verdict |
|---|---|
| `Payout.create` with `method: :instant \| :standard` lifted to positional | **Reject** — multi-field create, P15 D5 fake ergonomics on one field of ten |
| `Transfer.create` with `source_type` positional | **Reject** — multi-field create; Stripe adds new rails |
| `Payout.cancel` / `Payout.reverse` / `Transfer.reverse` atom-guarded | **Reject** — no semantic-enum payload to dispatch on |
| `ExternalAccount.create` with `:bank_account \| :card` positional | **Reject** — multi-field create |

**`method`, `source_type`, and similar enums stay inside the params map** as plain atoms typed via `@spec` only (stripity_stripe generated-spec precedent). Users who write `method: :banana` get a Stripe 400 that surfaces as `{:error, %LatticeStripe.Error{}}` — acceptable per "Stripe is the source of truth" principle.

**This is a positive outcome, not a gap.** The heuristic is working correctly: Phase 17 had `Account.reject/4` (entire payload IS the enum); Phase 18 has no such verb. The P15 D5 principle holds.

### D-05 — Nested struct budgets and Balance singleton shape

Per-resource allocation against the P17 D-01 amended budget (5 distinct modules, reuse is free):

| Resource | New modules | Reused (from elsewhere) | Budget used |
|---|---|---|---|
| **Transfer** | (none) | `LatticeStripe.TransferReversal` (from D-02) | **0/5** |
| **Payout** | `LatticeStripe.Payout.TraceId` | — | **1/5** |
| **Balance** | `LatticeStripe.Balance.Amount`, `LatticeStripe.Balance.SourceTypes` | `Balance.Amount` reused 5× across `available`/`pending`/`connect_reserved`/`instant_available`/`issuing.available` | **2/5** |
| **BalanceTransaction** | `LatticeStripe.BalanceTransaction.FeeDetail` | — | **1/5** |
| **ExternalAccount** | (handled in D-01 — `BankAccount` and `Card` are top-level resources, not nested struct slots) | — | **0/5** |

**Total new nested modules in Phase 18: 4.** All resources comfortably under budget.

**Key shape rules applied:**

1. **`Balance.Amount` reuse (P17 D-01)** — one hand-written module pays for five call-sites. `instant_available[].net_available` is absorbed via `:extra` per P17 D-02 typed-inner-open-outer, avoiding a 4th Balance module.
2. **`Balance.SourceTypes` (P17 D-02 precedent)** — stable inner shape `{card, bank_account, fpx}` with `:extra` catching future payment-method keys; embedded inside every `Balance.Amount`.
3. **`BalanceTransaction.FeeDetail`** — every typed peer SDK (go, ruby, java) promotes this; canonical Connect reconciliation idiom is `Enum.filter(bt.fee_details, &(&1.type == "application_fee"))`. Textbook P14 D-06 pattern-match target and the core Phase 18 success criterion #6 use case.
4. **`Payout.TraceId`** — 2-field `{status, value}` promoted despite thin shape; `status` enum is a clear pattern-match target and every typed peer SDK (go, ruby, java) promotes it. User confirmed the promotion during discussion.
5. **`BalanceTransaction.source` stays opaque `binary | map()`** — 16-variant polymorphism isn't worth modeling. Document the "expand then manually cast via the expected resource module" idiom in the guide.
6. **Transfer's `reversals.data` field** casts to `[%TransferReversal{}]` via the module from D-02; the paginated sublist wrapper (`has_more`, `url`, `total_count`) lives in `:extra`.
7. **Payout's `destination`, `balance_transaction`, `failure_balance_transaction`** — stay as expandable references (string or expanded object), not promoted. Generic expand logic handles them, not nested structs. stripe-go's `PayoutDestination` polymorphic wrapper is overkill; if a user expands `destination`, they can cast it via `ExternalAccount.cast/1` directly.

**`Balance.retrieve/2` signature (singleton):**

```elixir
@spec retrieve(Client.t(), opts :: keyword()) :: {:ok, t()} | {:error, Error.t()}
def retrieve(client, opts \\ [])
def retrieve!(client, opts \\ [])
```

**Client-first, opts in position 2** — consistency with the rest of the SDK, and `opts` is **critical** for Connect platforms retrieving a connected account's balance via the per-request `stripe_account:` override (already wired at `client.ex:178,390-427`). No id arg; no `list/2`; no `create/2`. Name is `retrieve` (not `get` or `fetch`) to match the SDK-wide verb convention.

**`@known_fields` per new struct:**

- `Payout.TraceId` — `[:status, :value]`
- `Balance.Amount` — `[:amount, :currency, :source_types]` (+ `net_available` lands in `:extra`)
- `Balance.SourceTypes` — `[:card, :bank_account, :fpx]` (+ `:extra` for future payment methods)
- `BalanceTransaction.FeeDetail` — `[:amount, :currency, :description, :type, :application]`

All four follow F-001 (`@known_fields` + `:extra` + `Map.split/2` in `cast/1`).

### D-06 — Minimal LatticeStripe.Charge: retrieve-only

**Ship `LatticeStripe.Charge` with `retrieve/3`, `retrieve!/3`, and `from_map/1` only.** No `create`, `update`, `capture`, `list`, `stream!`, or `search`.

**Rationale (per user selection in discussion):** The per-payout reconciliation flow walks `BalanceTransaction.source` back to a Charge id; letting users type that result via `LatticeStripe.Charge.retrieve/3` instead of dropping to `LatticeStripe.Client.request/2` makes the Connect guide read cleanly and gives `@spec` typing on the return. This is **not** fake ergonomics — `Charge.retrieve/3` is a direct HTTP endpoint binding, not a wrapper. Stripe's modern API is PaymentIntent-first for *creation*, but *retrieval* of already-created charges is the canonical way to read settled fee details.

**Research correction:** the memory note claiming "Charge was deleted in commit 39b98c9" is inaccurate — `lib/lattice_stripe/charge.ex` has never existed in git history. Commit 39b98c9 deletes `Price`/`Product`/`Coupon`/`TestClock` scaffolding; `Charge` is being added fresh in Phase 18, not revived. See `project_phase12_13_deletion.md` memory for follow-up correction.

**`@known_fields` — Connect-relevant surface only:**

```
id, object, amount, amount_captured, amount_refunded, application,
application_fee, application_fee_amount, balance_transaction, billing_details,
captured, created, currency, customer, description, destination, failure_code,
failure_message, fraud_details, invoice, livemode, metadata, on_behalf_of,
outcome, paid, payment_intent, payment_method, payment_method_details,
receipt_email, receipt_number, receipt_url, refunded, refunds, review,
source_transfer, statement_descriptor, statement_descriptor_suffix, status,
transfer_data, transfer_group
```

All other fields land in `:extra`. No `defimpl Inspect` PII hiding needed — `billing_details`, `payment_method_details`, and `fraud_details` may contain PII, so they get a basic hide pass via `defimpl Inspect` following the `Customer` pattern from `lib/lattice_stripe/customer.ex:462-467`.

**Signatures:**

```elixir
@spec retrieve(Client.t(), charge_id :: String.t(), opts :: keyword()) ::
        {:ok, t()} | {:error, Error.t()}
def retrieve(client, id, opts \\ [])
def retrieve!(client, id, opts \\ [])
```

**`require_param!(id, "charge id")`** pre-network.

**ExDoc group:** place `LatticeStripe.Charge` in the existing "Payments" group (not "Connect") — Charge is a core payments primitive that Connect reconciliation happens to lean on. Moduledoc must open with a pointer: "Stripe's modern API is PaymentIntent-first; use `LatticeStripe.PaymentIntent.create/3` to accept payments. This module exposes retrieve-only for reading settled fee details during reconciliation."

### D-07 — Destination charges + fee reconciliation: guide-only, zero helpers

**No code changes to `LatticeStripe.PaymentIntent`.** Fields `application_fee_amount`, `transfer_data`, `on_behalf_of`, `transfer_group` are **already** in `@known_fields` per scout (verified at `lib/lattice_stripe/payment_intent.ex:66–77, 139–173, 580–614`). No retroactive audit needed.

**Rejected helpers (all violate P15 D5 "no fake ergonomics"):**
- `PaymentIntent.create_destination_charge/4` — thin wrapper around existing create with the same params rearranged
- `PaymentIntent.create_with_transfer/5` — same problem
- `BalanceTransaction.reconcile/3` — hides one param (`expand: ["balance_transaction"]`) behind an ambiguous name ("reconcile" means different things for charge vs payout vs transfer contexts)
- `BalanceTransaction.for_payout/2` alias — just `BalanceTransaction.list(client, %{payout: po.id})` with less flexibility
- `Charge.fees/1` accessor and `LatticeStripe.PaymentIntent.TransferData` nested struct — out of scope for Phase 18; revisit only if the guide reads awkwardly during execution (it won't)

**`guides/connect.md` money-movement section outline** (appended to Phase 17's onboarding half):

1. **External accounts** — attaching bank accounts and debit cards to a connected account; using the dispatcher with `case %BankAccount{} -> ; %Card{} ->` pattern; Unknown fallback note; default_for_currency semantics
2. **Balance** — inspecting the platform balance and per-connected-account balance via `stripe_account:` opts override; interpreting `available`/`pending`/`connect_reserved`/`instant_available`; reading `source_types` breakdown
3. **Transfers** — moving funds from platform to connected account; `source_transaction` + `transfer_group` patterns; creating a `TransferReversal` and retrieving reversal history
4. **Payouts** — triggering payouts to external accounts; `method: :instant | :standard`; `cancel` and `reverse` with `expand: ["balance_transaction"]`; reading `trace_id.status` for settlement tracking
5. **Destination charges** — raw PaymentIntent params pattern (`application_fee_amount` + `transfer_data`); webhook-handoff callout on `charge.succeeded` + `application_fee.created` + `payout.paid`
6. **Separate charges and transfers** — three-step flow with `transfer_group` + `source_transaction`; explicit note that `source_transaction` prevents transfers running ahead of settled funds; multi-destination fan-out example
7. **Reconciling platform fees** — two parallel idioms, both documented:
   - **Per-object:** `PaymentIntent.retrieve` with `expand: ["latest_charge.balance_transaction"]`, walk `fee_details` filtering `type == "application_fee"`
   - **Per-payout batch:** `BalanceTransaction.list(client, %{payout: po.id})` + `stream!/3` lazy variant; walk each BT's `fee_details`; expand `source` and cast to `Charge` / `Refund` / `Transfer` via the expected resource module
   - Webhook-handoff callout on `payout.paid` ("trigger reconciliation on `payout.paid`, do not poll")
8. **Closing callout** — forward pointer to Phase 19 polish (not a phase boundary doc, just a "the Connect surface is now complete" note)

**Guide philosophy:** every code block is copy-pasteable against stripe-mock or a real test-mode Stripe key. Every narrative transition ends with a webhook callout. Guide is reviewed end-to-end by the plan executor before Phase 18 ships.

### Claude's Discretion

The following fall under Claude's judgment during planning and execution — no need to re-ask:

- Exact field order in each nested struct (follow Stripe API doc order unless Stripe's own docs are wrong)
- Exact `@moduledoc` wording, examples, and heading structure (follow Phase 14/15/16/17 moduledoc patterns)
- Test fixture shapes for `BankAccountFixtures`, `CardFixtures`, `TransferFixtures`, `TransferReversalFixtures`, `PayoutFixtures`, `BalanceFixtures`, `BalanceTransactionFixtures`, `ChargeFixtures`, `ExternalAccountFixtures` (follow `test/support/fixtures/` patterns from Phase 06)
- stripe-mock integration test coverage depth (mirror Phase 15/16/17 depth)
- Whether `Transfer.create/3` / `Payout.create/3` pre-validate any fields (recommend NO per P15 D5; let Stripe 400 flow through)
- ExDoc module group wiring details — add new modules to the existing "Connect" group from Phase 17; place `Charge` under the existing "Payments" group
- Whether `@typedoc` is added to every new struct (yes — follow Phase 10 D-03 "all key public structs get @typedoc")
- Exact `defimpl Inspect` PII hide-lists for `BankAccount` and `Card` — audit against stripe-node's published PII field list during execution
- `Client` header threading — already wired (confirmed during scout, `client.ex:178,390-427`). **No changes needed.**
- Whether to ship `@typedoc "A Stripe Connect Money Movement resource."` uniformity notes vs resource-specific typedocs — resource-specific wins per Phase 10 D-03
- Guide headline/TOC wording — plan executor writes, doc reviewer polishes
- Whether `BalanceTransaction.list/3` surfaces a `:type` param typed as a specific union (`"charge" | "payout" | ...`) — no, stay permissive; Stripe extends the list
- Order of waves within the phase plan (executor decides; suggested: Wave 1 = BankAccount + Card + ExternalAccount + Charge; Wave 2 = Transfer + TransferReversal + Payout + Payout.TraceId; Wave 3 = Balance (+ Amount + SourceTypes) + BalanceTransaction (+ FeeDetail); Wave 4 = integration tests + guide + ExDoc wiring)
- Whether to add a `stream!/3` on `TransferReversal.list` — yes, consistency with the rest of the SDK

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or implementing.**

### Project-level decisions and state
- `.planning/PROJECT.md` — vision, principles, non-negotiables, technology stack
- `.planning/REQUIREMENTS.md` §"Connect" — CNCT-02 through CNCT-05 requirement definitions
- `.planning/STATE.md` — current milestone position, accumulated decisions log
- `.planning/ROADMAP.md` Phase 18 entry (lines 224–236) — goal, depends-on, success criteria
- `.planning/phases/17-connect-accounts-links/17-CONTEXT.md` — **Phase 17 is Phase 18's direct predecessor; D-03 scope boundary and D-04 atom-guard heuristic carry forward verbatim**

### Prior phase contexts that establish patterns Phase 18 must follow
- `.planning/phases/14-invoices-invoice-line-items/14-CONTEXT.md` — D-06 nested struct cutoff heuristic ("promote fields users pattern-match on; leave simple K-V as plain maps")
- `.planning/phases/15-subscriptions-subscription-items/15-CONTEXT.md` — D4 flat namespace for top-level resources, D5 "no fake ergonomics" principle, webhook-handoff callout requirement
- `.planning/phases/15-subscriptions-subscription-items/15-REVIEW-FIX.md` — F-001 `@known_fields` + `:extra` split pattern (mandatory for every new struct in Phase 18)
- `.planning/phases/16-subscription-schedules/16-CONTEXT.md` — D1 5-field budget (amended in Phase 17 D-01 to count distinct modules, reuse free); Phase ↔ default_settings reuse precedent
- `.planning/phases/17-connect-accounts-links/17-CONTEXT.md` — D-01 amended budget rule, D-02 typed-inner-open-outer pattern for `Account.Capability`, D-03 scope split with Phase 18, D-04 atom-guard heuristic

### Codebase files Phase 18 code must be coherent with
- `lib/lattice_stripe/client.ex:52-95` — Client struct definition, `stripe_account` field already present
- `lib/lattice_stripe/client.ex:176-196` — per-request `stripe_account` opts override (already wired; **zero Client changes in Phase 18**)
- `lib/lattice_stripe/client.ex:388-427` — `build_headers/5` and `maybe_add_stripe_account/2` (already wired)
- `lib/lattice_stripe/resource.ex` — shared `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`, `require_param!/2` — use these everywhere, do not reimplement
- `lib/lattice_stripe/customer.ex:36-55,462-467` — canonical F-001 `@known_fields` + `:extra` + `defimpl Inspect` PII example; copy the pattern exactly
- `lib/lattice_stripe/account.ex` + `lib/lattice_stripe/account/` — most recent precedent for a resource with many nested structs (Phase 17 shipped this)
- `lib/lattice_stripe/account/capability.ex` — P17 D-02 typed-inner-open-outer template applicable to `Balance.SourceTypes`
- `lib/lattice_stripe/account_link.ex` — standalone sub-resource module precedent for `TransferReversal`
- `lib/lattice_stripe/payment_intent.ex:66-77,105-121,139-173,580-614` — **already** types `application_fee_amount`, `transfer_data`, `on_behalf_of`, `transfer_group`; **no changes needed** (verified during scout)
- `lib/lattice_stripe/refund.ex` — already has `balance_transaction` and `failure_balance_transaction` as typed fields; precedent for how Phase 18 resources should surface their balance_transaction references
- `lib/lattice_stripe/subscription_schedule.ex` + `lib/lattice_stripe/subscription_schedule/` — recent precedent for a resource with shared nested struct reuse (Phase 16)
- `lib/lattice_stripe/list.ex` — shared list response struct; `Transfer.list/3`, `Payout.list/3`, `BalanceTransaction.list/3` all return this via `Resource.unwrap_list/2`
- `test/support/fixtures/` — reusable fixture modules (Phase 06 established); add `BankAccountFixtures`, `CardFixtures`, `ExternalAccountFixtures`, `TransferFixtures`, `TransferReversalFixtures`, `PayoutFixtures`, `PayoutTraceIdFixtures`, `BalanceFixtures`, `BalanceTransactionFixtures`, `BalanceTransactionFeeDetailFixtures`, `ChargeFixtures`
- `test/integration/` — stripe-mock integration test setup; `test_integration_client/0` helper; follow Phase 15/16/17 structure
- `mix.exs` (docs config) — ExDoc `groups_for_modules:` "Connect" group exists from Phase 17; append new modules. "Payments" group gets `LatticeStripe.Charge`.
- `guides/connect.md` — Phase 17 onboarding half exists; append money-movement section per D-07 outline
- `.planning/phases/17-connect-accounts-links/17-VERIFICATION.md` — Phase 17 verification notes (reference for depth/style)

### Stripe API references (web)
- https://docs.stripe.com/api/external_account_bank_accounts — BankAccount CRUD on connected accounts
- https://docs.stripe.com/api/external_account_cards — Card CRUD on connected accounts
- https://docs.stripe.com/api/transfers — Transfer resource, all CRUD
- https://docs.stripe.com/api/transfer_reversals — TransferReversal resource, treated as distinct TOC section
- https://docs.stripe.com/api/payouts — Payout resource
- https://docs.stripe.com/api/payouts/cancel — confirms `expand` param accepted
- https://docs.stripe.com/api/payouts/reverse — confirms `expand` + `metadata` params accepted
- https://docs.stripe.com/api/balance — Balance singleton shape
- https://docs.stripe.com/api/balance_transactions — BalanceTransaction list + retrieve
- https://docs.stripe.com/api/balance_transactions/list — confirms native `payout:`, `source:`, `type:`, `currency:`, `created:` filters
- https://docs.stripe.com/api/balance_transactions/object — `fee_details` schema: `{amount, application, currency, description, type}`; `type` enum includes `application_fee`, `stripe_fee`, `payment_method_passthrough_fee`, `tax`, `withheld_tax`
- https://docs.stripe.com/api/charges/retrieve — Charge retrieve endpoint
- https://docs.stripe.com/connect/destination-charges — canonical destination-charge pattern using PaymentIntent params
- https://docs.stripe.com/connect/separate-charges-and-transfers — three-step flow with `transfer_group` + `source_transaction`
- https://docs.stripe.com/connect/balance-transactions — Connect-specific balance transaction semantics
- https://docs.stripe.com/connect/platform-fees — platform fee reconciliation flows
- https://docs.stripe.com/reports/reporting-categories — `reporting_category` enum values
- https://docs.stripe.com/payouts/reconciliation — per-payout reconciliation canonical walkthrough

### Cross-SDK comparison references used during research
- https://github.com/beam-community/stripity-stripe — closest Elixir precedent (codegen; flat shapes); Balance, BalanceTransaction, Transfer, TransferReversal, Payout source files
- https://github.com/stripe/stripe-go — deep typed tree; balance.go, balancetransaction.go, payout.go, transfer.go, bankaccount.go
- https://github.com/stripe/stripe-ruby — hand-maintained typed (closest peer); Balance, BalanceTransaction, Payout, BankAccount (note: no `ExternalAccount` class)
- https://github.com/stripe/stripe-java — top-level `TransferReversal` class confirming standalone-module precedent; `BankAccount` and `Card` implement marker interface `ExternalAccount`
- https://github.com/stripe/stripe-node — TS union type `ExternalAccount = BankAccount | Card`; `transfers.createReversal` method API; `payouts.cancel`/`reverse` accept params
- https://github.com/stripe/stripe-python — `@nested_resource_class_methods("reversal")` decorator on Transfer (no natural Elixir analogue)
- https://joshthompson.co.uk/automations/extract-stripe-fees-per-transaction-api/ — real-world fee reconciliation idiom (common case reads `.fee` directly)

</canonical_refs>

<code_context>
## Existing Code Insights (from scout)

### Reusable Assets (use, don't duplicate)
- **`LatticeStripe.Resource`** (`lib/lattice_stripe/resource.ex`) — shared `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`, `require_param!/2`. Every Phase 18 resource must use these helpers, not reimplement.
- **Client `stripe_account` header threading** (`client.ex:178,390-427`) — per-client AND per-request opts override already wired end-to-end. **Phase 18 requires zero changes to `Client` or `build_headers`.** Confirmed during scout.
- **`@known_fields` + `:extra` pattern (F-001)** — canonical example in `customer.ex:36-55,462-467`. Copy into every new struct in Phase 18.
- **`defimpl Inspect` PII-hiding pattern** — canonical examples in `customer.ex:467+` and `checkout/session.ex`. Use for `BankAccount`, `Card`, `Charge`.
- **Fixtures** — `test/support/fixtures/` has Customer/PI/SI/PM/Refund/Checkout.Session/Account/AccountLink/LoginLink fixtures. Add the 11 new fixture modules listed in D-06 Claude's Discretion.
- **`LatticeStripe.List`** — shared list response struct; `list/3` and `stream!/3` pattern used throughout; `Balance` does NOT return this (singleton).
- **`LatticeStripe.PaymentIntent` already types destination-charge fields** — `application_fee_amount`, `transfer_data`, `on_behalf_of`, `transfer_group` at `payment_intent.ex:66-77, 139-173`. **No code changes needed.** D-07 relies on this.
- **`LatticeStripe.Refund` already has `balance_transaction` + `failure_balance_transaction`** — shape precedent for how Phase 18 `Transfer`/`Payout`/`Charge` surface their balance_transaction references.
- **`LatticeStripe.Account.Capability`** (`lib/lattice_stripe/account/capability.ex`) — P17 D-02 typed-inner-open-outer template. Applies to `Balance.SourceTypes` in Phase 18.

### Established Patterns
- **Flat namespace** for top-level resources (P15 D4) — `LatticeStripe.BankAccount`, `LatticeStripe.Card`, `LatticeStripe.Transfer`, `LatticeStripe.TransferReversal`, `LatticeStripe.Payout`, `LatticeStripe.Balance`, `LatticeStripe.BalanceTransaction`, `LatticeStripe.Charge`, `LatticeStripe.ExternalAccount` all sit at the top level. Nested typed structs live under their resource directory (`lib/lattice_stripe/balance/amount.ex`, etc.).
- **Bang variants** for every public fallible function (Phase 4+).
- **`Jason.Encoder` NOT derived** on any resource struct.
- **Pre-network `require_param!`** for endpoint-required params.
- **Webhook-handoff callout** in every resource guide.
- **No mass `@typedoc` boilerplate** — typedoc on key public struct types only, per Phase 10 D-03.
- **P17 D-01 amended budget** — 5 distinct nested struct modules per resource, reuse is free. Phase 18 ships 4 total new nested modules + 1 reused.
- **P17 D-02 typed-inner-open-outer** — stable inner shape as struct, open outer map as plain map with `:extra`. Applied to `Balance.SourceTypes`.
- **P17 D-04 atom-guard heuristic** — atom guards earn their place only on dedicated single-purpose verbs with closed stable enums. Phase 18 ships zero.

### Integration Points
- `mix.exs` — ExDoc `groups_for_modules:` "Connect" group already exists (Phase 17); append Phase 18 modules. "Payments" group gets `LatticeStripe.Charge`.
- `mix.exs` — ExDoc `extras:` `guides/connect.md` already in the extras list; Phase 18 appends a section to the same file.
- `test/test_helper.exs` — integration test runner already configured for stripe-mock; no changes.
- `lib/lattice_stripe/telemetry.ex` — no changes needed; Phase 18 resource paths will be auto-derived by `parse_resource_and_operation/2` from URL paths.
- No changes needed to any existing Phase 1–17 resource.

### Creative Options Enabled
- The already-wired per-request `stripe_account:` override means `Balance.retrieve(client, stripe_account: "acct_123")` pulls the *connected account's* balance, not the platform's — exactly the Connect reconciliation pattern. The guide must show this prominently.
- `Payout.reverse/4` composes naturally with `expand: ["balance_transaction"]` to let users reconcile a reversed payout in a single round trip.
- `BalanceTransaction.stream!/3` with `%{payout: "po_123"}` filter streams every line item of a payout lazily — avoids pagination boilerplate for large payouts. Guide should show this alongside the paginated `list/3` variant.

</code_context>

<specifics>
## Specific Ideas from Discussion

- **Research-verified cross-SDK consensus for ExternalAccount** — 4 of 5 official SDKs (stripe-ruby, stripe-python, stripe-node, stripe-java) expose `BankAccount` and `Card` as first-class types; only stripe-go collapses them (and only because Go lacks sum types). LatticeStripe follows the 4-of-5 consensus, not the Go outlier.
- **TransferReversal is treated as a distinct resource in Stripe's own API reference** — its own TOC section. LatticeStripe ships it as a standalone module to match.
- **"No body" endpoints are a myth** — every Stripe endpoint accepts at least `expand`. `Payout.cancel/4` and `Payout.reverse/4` ship with the canonical `(client, id, params \\ %{}, opts \\ [])` shape even though the common case passes no params, because defaulting to `params \\ %{}` costs zero ergonomics and forestalls a breaking change.
- **`Balance.Amount` reuse is the strongest case yet for the P17 D-01 amended budget rule** — one hand-written module pays for 5 call-sites (`available`, `pending`, `connect_reserved`, `instant_available`, `issuing.available`). If the old Phase 16 rule (count parent fields) were still in force, this would consume 5 budget slots for one logical shape.
- **`Balance.SourceTypes` is the second in-production application of P17 D-02's typed-inner-open-outer pattern** — stable `{card, bank_account, fpx}` inner shape, open outer map via `:extra` for forward-compat. The pattern is proving itself as a template.
- **`Payout.TraceId` promotion was a close call** that the user explicitly confirmed during discussion — 2-field shape with clear pattern-match target on `status` enum, promoted despite thin shape because every typed peer SDK promotes it.
- **User explicitly chose to ship `Charge.retrieve` in Phase 18** — rather than defer to planning; reduces risk that guide execution blocks on a missing module.
- **Research flagged a memory correction** — the `project_phase12_13_deletion.md` memory claims "Charge was deleted in commit 39b98c9" but `lib/lattice_stripe/charge.ex` has never existed in git history. Commit 39b98c9 deletes `Price`/`Product`/`Coupon`/`TestClock` scaffolding. The memory should be updated to remove the Charge claim. (Not a blocker for Phase 18; logged here for memory-hygiene follow-up.)
- **Unknown dispatcher fallback** — `ExternalAccount.Unknown` is the first use of a "fallback object type" in LatticeStripe; the pattern may be useful elsewhere if Stripe's polymorphic response shapes grow (e.g., `payment_method_details` sub-types). Not generalized in Phase 18, but noted for future phases.
- **The reconciliation guide section must include both idioms side-by-side** — per-object `expand: ["balance_transaction"]` AND per-payout `BalanceTransaction.list(client, %{payout: po.id})`. They serve different use cases (one payment vs entire payout ledger) and users need to know when to reach for which.
- **Webhook-handoff callouts are mandatory at every money-movement narrative transition** — `charge.succeeded`, `application_fee.created`, `payout.paid`, `transfer.reversed`. Phase 15 D5 precedent applies: LatticeStripe tells users "drive application state from webhook events, not SDK responses," and Connect money movement is the most critical place to repeat that.
- **`BalanceTransaction.source` stays opaque on purpose** — 16-variant polymorphism is too expensive to model; the guide documents the "expand then manually cast via the expected resource module" idiom, and users compose `BankAccount.cast/1`, `Card.cast/1`, `Charge.from_map/1` etc. themselves.

</specifics>

<deferred>
## Deferred Ideas

- **`LatticeStripe.Charge.create` / `update` / `capture` / `list` / `search`** — rejected in Phase 18 per the PaymentIntent-first philosophy. `Charge.retrieve` ships because fee reconciliation requires it. If user demand for direct charge creation surfaces (unlikely given PaymentIntent covers it), revisit as a later phase addition.
- **`LatticeStripe.ApplicationFee` + `LatticeStripe.ApplicationFee.Refund` resources** — Stripe exposes `/v1/application_fees` separately from `BalanceTransaction`; LatticeStripe leans on `BalanceTransaction.fee_details[type == "application_fee"]` for reconciliation. If direct application fee listing/refunding surfaces as a real need, add as a late-v1 or early-v1.1 phase.
- **`LatticeStripe.Topup`** — Connect platforms funding their own balance. Not in CNCT-02..05 literal text. Defer until demand surfaces.
- **Customer-owned external accounts** (`/v1/customers/:id/bank_accounts` and `/v1/customers/:id/sources`) — Phase 18 covers connected-account external accounts only. If customer-side surfaces are needed, add `BankAccount.retrieve_for_customer/3` etc. without refactoring the `ExternalAccount` dispatcher (the `BankAccount` and `Card` modules are reusable as-is).
- **`PaymentIntent.TransferData` nested typed struct** — 2-key map (`destination`, `amount`); not worth a module slot. Revisit only if users start pattern-matching on `transfer_data` frequently enough to justify the budget cost.
- **`Charge.fees/1` pure accessor** (returns `[FeeDetail.t()]` from an already-expanded balance_transaction) — considered in D-07; defer. If the Connect guide examples read awkwardly without it during Phase 18 execution, add as a tiny late-wave addition.
- **`BalanceTransaction.for_payout/2` alias** — just `list/3` with a filter. Document the filter idiom in the guide; do not add an alias.
- **`BalanceTransaction.source` polymorphic typed union** — 16-variant sum type. Cost/benefit doesn't pencil out for a hand-maintained SDK. Document the expand-and-cast idiom; revisit if users demand the union.
- **`Payout.create_destination_charge/4` and separate-charge-and-transfer wrappers** — rejected as fake ergonomics. Guide content only.
- **`stream!/3` on `TransferReversal.list`** — ship in Phase 18 (listed above); this is NOT deferred, noting here only because it's the one `stream!` that could have been trimmed and wasn't.
- **`ExternalAccount.Unknown` generalization to other polymorphic response shapes** — pattern may apply to `payment_method_details` sub-types, `charge.source` variants, etc. Not generalized in Phase 18. If a third use-case appears, consider promoting to a shared helper.
- **Memory hygiene follow-up** — update `project_phase12_13_deletion.md` memory to remove the inaccurate "Charge was deleted" claim. Not a Phase 18 code deliverable; handle in a separate `/gsd-note` or memory-edit task.

### Reviewed Todos (not folded)

No todos cross-referenced for Phase 18 — `todo match-phase 18` returned zero matches.

</deferred>

---

*Phase: 18-connect-money-movement*
*Context gathered: 2026-04-12*
*Research: 4 parallel gsd-advisor-researcher agents covered gray areas A (ExternalAccount shape) / B (action verbs + reversals) / C (struct shapes + budgets) / D (destination charges + reconciliation)*
