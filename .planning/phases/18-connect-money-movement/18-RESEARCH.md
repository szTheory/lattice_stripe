# Phase 18: Connect Money Movement — Research

**Researched:** 2026-04-12
**Domain:** Stripe Connect money movement — External Accounts, Transfers, Transfer Reversals, Payouts, Balance, Balance Transactions, Charge (retrieve-only)
**Confidence:** HIGH — CONTEXT.md is extensive and already incorporates four prior research passes (gray areas A/B/C/D); this RESEARCH.md locks the Stripe API contract shapes and codebase patterns plans must replicate verbatim.

## Summary

Phase 18 closes the Connect track by implementing the money-movement half of the platform: attaching `BankAccount` / `Card` to connected accounts through a polymorphic `ExternalAccount` dispatcher, transferring funds via `Transfer` + `TransferReversal`, triggering `Payout` CRUD plus `cancel`/`reverse`, reading platform or per-connected-account `Balance`, listing `BalanceTransaction` for per-payout reconciliation, and shipping a retrieve-only `Charge` so fee reconciliation flows stay strongly typed. There are no changes required to `Client`, `PaymentIntent`, or webhook code — `Stripe-Account` header threading and PaymentIntent destination-charge fields are already wired (verified in scout).

All technical decisions (D-01 .. D-07) are locked in CONTEXT.md. This research pass verifies the Stripe API contract for each endpoint, anchors the code patterns against the existing codebase (`Refund`, `Account`, `Account.Capability`, `AccountLink`, `Customer`), and produces a Validation Architecture section the orchestrator can compile into VALIDATION.md. Confidence is HIGH across the board: every Stripe endpoint URL, required param, and field listed below is cross-cited against `docs.stripe.com/api/*` (locked decisions in CONTEXT.md already cite these URLs) and every code pattern is quoted against an existing LatticeStripe module that plans will copy.

**Primary recommendation:** Execute in the four-wave order suggested by CONTEXT.md (ExternalAccount family + Charge → Transfer + TransferReversal + Payout → Balance + BalanceTransaction → integration tests + guide + ExDoc), copying `Refund`-style CRUDL layout verbatim for every resource module, `Account.Capability`-style nested structs for all four new nested modules, and `AccountLink`-style standalone sub-resource layout for `TransferReversal`. No invention — this is a pattern-match exercise against Phases 14–17.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01 — ExternalAccount polymorphism: two first-class structs + dispatcher.**
- `LatticeStripe.BankAccount` (top-level) — typed struct + F-001 `@known_fields` + `:extra` + `defimpl Inspect` scrubbing `routing_number`, `account_number`, `fingerprint`, `account_holder_name`.
- `LatticeStripe.Card` (top-level) — typed struct + F-001 + `defimpl Inspect` scrubbing `last4`, `fingerprint`, `exp_month`, `exp_year`, `address_line1_check`, `cvc_check`, `address_zip_check`, `name`.
- `LatticeStripe.ExternalAccount` (top-level) — dispatcher owning ALL CRUD (`create/3`, `retrieve/3`, `update/4`, `delete/3`, `list/3`, `stream!/3` + bang variants); `cast/1` pattern-matches on `"object"` and returns `BankAccount.t() | Card.t() | Unknown.t()`.
- `LatticeStripe.ExternalAccount.Unknown` — forward-compat fallback for future Stripe external-account object types; stores full raw payload in `:extra`, never crashes on unknown keys.
- `BankAccount` and `Card` modules stay **data + helpers only** in Phase 18 — no HTTP functions on them. CRUD lives on the dispatcher.
- Return type for ExternalAccount CRUD: `{:ok, BankAccount.t() | Card.t() | Unknown.t()} | {:error, Error.t()}`.

**D-02 — Transfer + TransferReversal: standalone module, no delegator.**
- `LatticeStripe.Transfer` ships full CRUD (`create/3`, `retrieve/3`, `update/4`, `list/3`, `stream!/3`) + bang variants. **NO `reverse/4` delegator on `Transfer`.**
- `LatticeStripe.TransferReversal` is a top-level module with full CRUD addressed by `(transfer_id, reversal_id)` (mirrors `/v1/transfers/:transfer/reversals/:id`). Signatures:
  - `create(client, transfer_id, params, opts \\ [])` + bang
  - `retrieve(client, transfer_id, reversal_id, opts \\ [])` + bang
  - `update(client, transfer_id, reversal_id, params, opts \\ [])` + bang
  - `list(client, transfer_id, params \\ %{}, opts \\ [])` + bang
  - `stream!(client, transfer_id, params \\ %{}, opts \\ [])`
- `require_param!/3` called on both `transfer_id` and `reversal_id` pre-network.
- `Transfer.reversals.data` on a decoded `%Transfer{}` casts to `[%TransferReversal{}]`; the outer paginated sublist wrapper (`has_more`, `url`, `total_count`) lives in `:extra`.

**D-03 — `Payout.cancel` and `Payout.reverse` use canonical shape with default params.**
- `cancel(client, id, params \\ %{}, opts \\ [])` + bang
- `reverse(client, id, params \\ %{}, opts \\ [])` + bang
- `require_param!(id, "payout id")` pre-network on both.
- No atom guards. No positional `method:` argument.

**D-04 — Zero atom-guarded dispatchers in Phase 18.** Every candidate fails the P17 D-04 heuristic. `method`, `source_type`, and similar enums stay inside params maps as plain atoms typed via `@spec` only.

**D-05 — Nested struct budgets and Balance singleton shape.**
- Four new nested modules total across all resources: `Payout.TraceId` (1), `Balance.Amount` (1), `Balance.SourceTypes` (1), `BalanceTransaction.FeeDetail` (1).
- `Balance.Amount` is reused 5× inside `%Balance{}` (`available[]`, `pending[]`, `connect_reserved[]`, `instant_available[]`, `issuing.available[]`). One module, five call-sites.
- `Balance.SourceTypes` follows P17 D-02 typed-inner-open-outer: stable inner `{card, bank_account, fpx}` + `:extra` for future payment-method keys.
- `Balance.retrieve(client, opts \\ [])` is a singleton — no id, no list, no create/update/delete. `retrieve!/2` bang variant.
- `BalanceTransaction.source` stays opaque `binary | map()`; guide documents the "expand then cast via expected resource module" idiom.
- `Payout.destination`, `balance_transaction`, `failure_balance_transaction` stay as expandable references (string OR expanded map) — not promoted.
- All new structs follow F-001 (`@known_fields` + `:extra` + `Map.split/2` in `cast/1`).

**D-06 — Minimal `LatticeStripe.Charge`: retrieve-only.**
- `retrieve/3`, `retrieve!/3`, `from_map/1`. No `create`, `update`, `capture`, `list`, `stream!`, `search`.
- `@known_fields`: `id, object, amount, amount_captured, amount_refunded, application, application_fee, application_fee_amount, balance_transaction, billing_details, captured, created, currency, customer, description, destination, failure_code, failure_message, fraud_details, invoice, livemode, metadata, on_behalf_of, outcome, paid, payment_intent, payment_method, payment_method_details, receipt_email, receipt_number, receipt_url, refunded, refunds, review, source_transfer, statement_descriptor, statement_descriptor_suffix, status, transfer_data, transfer_group`.
- `defimpl Inspect` hides `billing_details`, `payment_method_details`, `fraud_details` (PII-bearing).
- `require_param!(id, "charge id")` pre-network.
- ExDoc group: **Payments** (not Connect). Moduledoc opens with a PaymentIntent-first pointer.

**D-07 — Destination charges + fee reconciliation: guide-only, zero helpers.**
- **No** code changes to `LatticeStripe.PaymentIntent`. Fields already typed.
- No wrapper helpers (`create_destination_charge/4`, `create_with_transfer/5`, `BalanceTransaction.reconcile/3`, `BalanceTransaction.for_payout/2`, `Charge.fees/1`) — rejected as fake ergonomics.
- `guides/connect.md` money-movement section outline fixed at 8 numbered subsections (D-07 body).
- Webhook-handoff callouts at every money-movement narrative transition.

### Claude's Discretion

- Exact field ordering in each new struct (follow Stripe API doc order).
- Exact `@moduledoc` wording and example content (follow Phase 14–17 moduledoc patterns).
- Test fixture shapes for the 11 new fixture modules (follow `test/support/fixtures/` patterns).
- stripe-mock integration test coverage depth (mirror Phase 15/16/17 depth).
- Pre-validation of `Transfer.create` / `Payout.create` fields — **recommend NO** (P15 D5 "let Stripe 400 flow through").
- ExDoc module group wiring — append to existing "Connect" group; `Charge` under "Payments".
- `@typedoc` on every key public struct (yes — Phase 10 D-03).
- Exact `defimpl Inspect` PII hide-lists — audit against stripe-node's published PII field list during execution.
- Wave ordering — suggested Wave 1 (ExternalAccount family + Charge), Wave 2 (Transfer + TransferReversal + Payout), Wave 3 (Balance + BalanceTransaction), Wave 4 (integration + guide + ExDoc).
- `TransferReversal.stream!/3` — yes, consistency.
- `BalanceTransaction.list/3 :type` param staying permissive — yes, no typed union.

### Deferred Ideas (OUT OF SCOPE)

- `Charge.create/update/capture/list/search`
- `LatticeStripe.ApplicationFee` and `ApplicationFee.Refund` resources
- `LatticeStripe.Topup`
- Customer-owned external accounts (`/v1/customers/:id/bank_accounts`, `/v1/customers/:id/sources`)
- `PaymentIntent.TransferData` nested typed struct
- `Charge.fees/1` pure accessor
- `BalanceTransaction.for_payout/2` alias
- `BalanceTransaction.source` polymorphic typed union (16 variants)
- Any `create_destination_charge/4` / `create_with_transfer/5` wrappers
- `ExternalAccount.Unknown` generalization to other polymorphic shapes
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CNCT-02 | Transfers and Payouts | Stripe API contract for `/v1/transfers`, `/v1/transfers/:id/reversals`, `/v1/payouts`, `/v1/payouts/:id/cancel`, `/v1/payouts/:id/reverse` documented in "Stripe API Contract" section below. `Refund`-style CRUDL pattern from `lib/lattice_stripe/refund.ex` is the direct template. |
| CNCT-03 | Destination charges vs separate charge/transfer patterns | PaymentIntent destination-charge fields (`application_fee_amount`, `transfer_data`, `on_behalf_of`, `transfer_group`) already typed in `lib/lattice_stripe/payment_intent.ex:66–77, 139–173` (verified in scout). Guide content only — no code changes. Three-step separate-charge-and-transfer flow documented against `docs.stripe.com/connect/separate-charges-and-transfers`. |
| CNCT-04 | Platform fee handling and reconciliation | `BalanceTransaction.FeeDetail` nested struct with `{amount, currency, description, type, application}` shape (typed peer-SDK consensus). Reconciliation idiom: `Enum.filter(bt.fee_details, &(&1.type == "application_fee"))`. Two parallel reconciliation flows documented: per-object `expand: ["latest_charge.balance_transaction"]` and per-payout `BalanceTransaction.list(client, %{payout: po.id})`. |
| CNCT-05 | Balance and Balance Transactions | Singleton `Balance.retrieve(client, opts)` with per-request `stripe_account:` override (already wired `client.ex:178,390-427`). `BalanceTransaction.list/3` with native `payout:`, `source:`, `type:`, `currency:`, `created:` filters (verified against `docs.stripe.com/api/balance_transactions/list`). `stream!/3` for large-payout lazy walk. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

| # | Constraint | How it applies to Phase 18 |
|---|------------|----------------------------|
| C1 | Elixir ≥ 1.15, OTP ≥ 26 | All new modules compile clean on 1.15..1.19 / OTP 26..28. No 1.18-only features (no stdlib `JSON` module). |
| C2 | No Dialyzer — typespecs are documentation | Every public fn gets `@spec`, typespecs are narrative-helpful, not enforced. `@typedoc` on every key public struct. |
| C3 | Finch default transport via `Transport` behaviour | No direct Finch calls from resource modules; always go through `Client.request/2`. |
| C4 | Jason default JSON codec | Never import Jason directly in new code; go through the already-wired codec. `from_map/1` always assumes string keys from Jason. |
| C5 | Plug for webhook endpoint only | Phase 18 touches no webhook code. Mentions webhooks only in narrative (guide callouts). |
| C6 | Minimal dependencies | Phase 18 adds **zero** new Hex dependencies. |
| C7 | Credo strict mode (`mix ci`) | All new modules must pass `mix credo --strict`. Follow `Account` / `Refund` formatting. |
| C8 | Stripe API version pinned, per-request override | Never hardcode a version string inside new resource modules. Use `Client`'s wired version header. |
| C9 | `mix format` clean, `compile --warnings-as-errors` clean | All new files formatted; unused aliases trimmed. Plans must include a final `mix ci` run. |
| C10 | No global module-level configuration, no GenServer state | Every function takes `Client.t()` as first positional argument. No `Application.get_env` reads from new modules. |
| C11 | `Jason.Encoder` NOT derived on resource structs | All 9 new top-level struct modules (`BankAccount`, `Card`, `ExternalAccount.Unknown`, `Transfer`, `TransferReversal`, `Payout`, `Balance`, `BalanceTransaction`, `Charge`) must NOT derive `Jason.Encoder`. Verified pattern in `lib/lattice_stripe/customer.ex`. |
| C12 | GSD workflow enforcement | Every file-edit task in the plan must be reachable through a GSD plan — no freehand repo edits. |

**All C1–C12 [VERIFIED: `/Users/jon/projects/lattice_stripe/CLAUDE.md`] — quoted verbatim from the project instructions in the init context.**

## Standard Stack

**Phase 18 adds zero new dependencies.** All primitives are already present in `mix.exs`.

### Reused in-project primitives (HIGH confidence, verified by reading source)

| Library / Module | Role in Phase 18 | Source file | Why |
|-----------------|------------------|-------------|-----|
| `LatticeStripe.Client` | First-positional arg on every public fn; threads `stripe_account:` header per-request | `lib/lattice_stripe/client.ex` (fields at lines 52–95, override at 176–196, header builder at 388–427) | Already wired end-to-end per scout; **no changes needed** |
| `LatticeStripe.Request` | Every HTTP call builds a `%Request{method, path, params, opts}` struct and pipes into `Client.request/2` | `lib/lattice_stripe/request.ex` | Uniform request shape across all resources |
| `LatticeStripe.Resource` | `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`, `require_param!/3` | `lib/lattice_stripe/resource.ex` (all 148 lines) | Shared helper — never reimplement. Every Phase 18 public fn ends in `Resource.unwrap_singular(&from_map/1)` or `Resource.unwrap_list(&from_map/1)`. |
| `LatticeStripe.Response` | Wraps successful decoded responses; carries `request_id`, HTTP status | `lib/lattice_stripe/response.ex` | Plans never touch this directly — `Resource` helpers unwrap it |
| `LatticeStripe.List` | Paginated list response shape; `stream!/2` for auto-pagination | `lib/lattice_stripe/list.ex` | `stream!/3` on every new list-capable resource uses `List.stream!(client, req) \|> Stream.map(&from_map/1)` |
| `LatticeStripe.Error` | Structured error struct returned on all failures | `lib/lattice_stripe/error.ex` | Never construct; plans pattern-match on `{:error, %Error{}}` |
| `:telemetry` 1.0+ | Auto-wired via `Client.request/2` → `Telemetry.request_span/4` | `lib/lattice_stripe/telemetry.ex` + `parse_resource_and_operation/2` | **Auto-derives resource/operation from URL path** — plans need zero telemetry code, Phase 8 `parse_resource_and_operation/2` picks up `/v1/transfers`, `/v1/payouts`, etc. transparently. [VERIFIED: STATE.md line 112] |

### Dev/test primitives

| Library | Version | Role | Confidence |
|---------|---------|------|-----------|
| `ExUnit` (stdlib) | — | All new unit + integration tests | HIGH |
| `Mox` | `~> 1.2` (already in `mix.exs`) | Transport mock for unit tests of resource modules that need HTTP stubbing; see Phase 4+ resource tests for the exact pattern | HIGH |
| `stripe-mock` (Docker) | `stripe/stripe-mock:latest` | Integration tests for every new resource endpoint; already running in CI per Phase 11 | HIGH |
| `Credo` | `~> 1.7` strict | `mix ci` gate for every new file | HIGH |

**Version verification skipped — no new packages being introduced.** The stack table in CLAUDE.md was confirmed current during Phase 11 CI/release.

## Architecture Patterns

### Recommended project structure (new files only)

```
lib/lattice_stripe/
├── bank_account.ex                        # D-01: top-level typed struct, F-001, PII Inspect
├── card.ex                                # D-01: top-level typed struct, F-001, PII Inspect
├── external_account.ex                    # D-01: dispatcher — cast/1 + all CRUD for external accounts
├── external_account/
│   └── unknown.ex                         # D-01: forward-compat fallback
├── transfer.ex                            # D-02: CRUD + stream!, NO reverse delegator
├── transfer_reversal.ex                   # D-02: standalone, (transfer_id, reversal_id) addressing
├── payout.ex                              # D-03: CRUD + cancel + reverse + stream!
├── payout/
│   └── trace_id.ex                        # D-05: {status, value} nested struct
├── balance.ex                             # D-05: singleton — retrieve/2 only
├── balance/
│   ├── amount.ex                          # D-05: reused 5× inside %Balance{}
│   └── source_types.ex                    # D-05: typed-inner-open-outer embedded in every Amount
├── balance_transaction.ex                 # D-05: retrieve + list + stream!, no CUD
├── balance_transaction/
│   └── fee_detail.ex                      # D-05: {amount, currency, description, type, application}
└── charge.ex                              # D-06: retrieve-only + from_map/1
```

```
test/
├── lattice_stripe/
│   ├── bank_account_test.exs
│   ├── card_test.exs
│   ├── external_account_test.exs          # dispatcher cast/1 branch matrix + CRUD via Mox
│   ├── transfer_test.exs
│   ├── transfer_reversal_test.exs
│   ├── payout_test.exs
│   ├── payout/trace_id_test.exs
│   ├── balance_test.exs
│   ├── balance/amount_test.exs
│   ├── balance/source_types_test.exs
│   ├── balance_transaction_test.exs
│   ├── balance_transaction/fee_detail_test.exs
│   └── charge_test.exs
├── integration/
│   ├── external_account_integration_test.exs     # bank + card + mixed list
│   ├── transfer_integration_test.exs
│   ├── transfer_reversal_integration_test.exs
│   ├── payout_integration_test.exs
│   ├── balance_integration_test.exs              # platform + stripe_account: override
│   ├── balance_transaction_integration_test.exs  # filter by payout:
│   └── charge_integration_test.exs               # retrieve with expand
└── support/fixtures/
    ├── bank_account_fixtures.ex
    ├── card_fixtures.ex
    ├── external_account_fixtures.ex
    ├── transfer_fixtures.ex
    ├── transfer_reversal_fixtures.ex
    ├── payout_fixtures.ex
    ├── payout_trace_id_fixtures.ex
    ├── balance_fixtures.ex
    ├── balance_transaction_fixtures.ex
    ├── balance_transaction_fee_detail_fixtures.ex
    └── charge_fixtures.ex
```

### Pattern 1: CRUDL resource module (copy from `Refund`)

**Template:** `lib/lattice_stripe/refund.ex` (verified by read). Every Phase 18 resource except `Balance` (singleton), `ExternalAccount` (dispatcher), `TransferReversal` (sub-resource addressing), and `Charge` (retrieve-only) follows this exact structure.

**Section layout of a resource module:**

1. `@moduledoc` — purpose, usage examples, PII/Inspect note, Stripe API reference link
2. `alias LatticeStripe.{Client, Error, List, Request, Resource, Response}`
3. `@known_fields ~w[...]` (string sigil, no `a`)
4. `defstruct [...]` (atom keys, `object:` default, `extra: %{}`)
5. `@typedoc` + `@type t :: %__MODULE__{...}`
6. `# Public API: CRUD operations` banner comment
7. `create/3`, `retrieve/3`, `update/4`, `cancel/4` (if applicable), `list/3`, `stream!/3`
8. `# Public API: Bang variants` banner comment
9. `create!/3`, `retrieve!/3`, `update!/4`, `cancel!/4`, `list!/3` (note: `stream!` is already bang)
10. `# Public: from_map/1` banner comment
11. `from_map(map)` returning `%__MODULE__{}`
12. Trailing `defimpl Inspect, for: LatticeStripe.<Resource> do ... end` (outside the `defmodule`)

**Quoted from `lib/lattice_stripe/refund.ex:156–172` [VERIFIED: source read]:**

```elixir
@spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def create(%Client{} = client, params \\ %{}, opts \\ []) do
  Resource.require_param!(
    params,
    "payment_intent",
    ~s|Refund.create/3 requires a "payment_intent" key in params. Example: %{"payment_intent" => "pi_..."}|
  )

  %Request{method: :post, path: "/v1/refunds", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

**Quoted from `lib/lattice_stripe/refund.ex:298–302` [VERIFIED]:**

```elixir
@spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
  req = %Request{method: :get, path: "/v1/refunds", params: params, opts: opts}
  List.stream!(client, req) |> Stream.map(&from_map/1)
end
```

**Quoted from `lib/lattice_stripe/refund.ex:239–244` (action verb with default params — `Payout.cancel` + `Payout.reverse` copy this shape) [VERIFIED]:**

```elixir
@spec cancel(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def cancel(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
  %Request{method: :post, path: "/v1/refunds/#{id}/cancel", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

### Pattern 2: Nested typed struct (copy from `Account.Capability`)

**Template:** `lib/lattice_stripe/account/capability.ex` (verified by read, 70 lines). `Payout.TraceId`, `Balance.Amount`, `Balance.SourceTypes`, `BalanceTransaction.FeeDetail` all copy this exact shape.

**Quoted from `lib/lattice_stripe/account/capability.ex:20–48` [VERIFIED]:**

```elixir
@known_fields ~w(status requested requested_at requirements disabled_reason)a

defstruct @known_fields ++ [extra: %{}]

@type t :: %__MODULE__{
        status: String.t() | nil,
        requested: boolean() | nil,
        requested_at: integer() | nil,
        requirements: map() | nil,
        disabled_reason: String.t() | nil,
        extra: map()
      }

@doc false
def cast(nil), do: nil

def cast(map) when is_map(map) do
  known_string_keys = Enum.map(@known_fields, &Atom.to_string/1)
  {known, extra} = Map.split(map, known_string_keys)

  struct(__MODULE__,
    status: known["status"],
    requested: known["requested"],
    requested_at: known["requested_at"],
    requirements: known["requirements"],
    disabled_reason: known["disabled_reason"],
    extra: extra
  )
end
```

**Key points for every new nested struct:**
- `@known_fields` uses the **atom** sigil `~w(...)a` (different from top-level resource modules which use the **string** sigil).
- `defstruct @known_fields ++ [extra: %{}]` — composition, not repetition.
- `cast/1` head handles `nil`.
- `cast/1` body uses `Map.split/2` on stringified keys — F-001 guarantees zero data loss to `:extra`.
- `@doc false` on `cast/1` — internal API.

### Pattern 3: Standalone sub-resource module (copy from `AccountLink`)

**Template:** `lib/lattice_stripe/account_link.ex` (verified by read, 100 lines). `TransferReversal` copies this layout, adapted to `(transfer_id, reversal_id)` addressing.

**Quoted from `lib/lattice_stripe/account_link.ex:79–90` [VERIFIED]:**

```elixir
@spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def create(%Client{} = client, params, opts \\ []) when is_map(params) do
  %Request{method: :post, path: "/v1/account_links", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end

@doc "Like `create/3` but raises on failure."
@spec create!(Client.t(), map(), keyword()) :: t()
def create!(%Client{} = client, params, opts \\ []) when is_map(params) do
  client |> create(params, opts) |> Resource.unwrap_bang!()
end
```

**`TransferReversal` adaptation:** swap the `path:` string for `"/v1/transfers/#{transfer_id}/reversals"` (create + list) or `"/v1/transfers/#{transfer_id}/reversals/#{reversal_id}"` (retrieve + update); add `when is_binary(transfer_id)` (and `is_binary(reversal_id)` where relevant) to every clause.

### Pattern 4: Polymorphic dispatcher (new in Phase 18, D-01)

**No existing template.** This is the first sum-type dispatcher in LatticeStripe. Pattern locked by D-01:

```elixir
defmodule LatticeStripe.ExternalAccount do
  @moduledoc """..."""
  alias LatticeStripe.{BankAccount, Card, Client, Error, List, Request, Resource, Response}
  alias LatticeStripe.ExternalAccount.Unknown

  # cast/1 dispatches on object discriminator
  def cast(%{"object" => "bank_account"} = raw), do: BankAccount.cast(raw)
  def cast(%{"object" => "card"}          = raw), do: Card.cast(raw)
  def cast(%{"object" => other}           = raw), do: Unknown.cast(raw, other)
  def cast(nil), do: nil

  # CRUD funcs live here, returning sum-type structs
  @type ea :: BankAccount.t() | Card.t() | Unknown.t()

  @spec create(Client.t(), String.t(), map(), keyword()) :: {:ok, ea} | {:error, Error.t()}
  def create(%Client{} = client, account_id, params, opts \\ []) when is_binary(account_id) do
    %Request{
      method: :post,
      path: "/v1/accounts/#{account_id}/external_accounts",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&cast/1)
  end
  # retrieve/3, update/4, delete/3, list/3, stream!/3 follow the same shape
end
```

**Key differences from a normal resource module:**
- Public `cast/1` (not `from_map/1`) — name signals polymorphism.
- `from_map/1` on `BankAccount` and `Card` **also** exist (standard F-001) because nested contexts (e.g., `Payout.destination` expanded) may need to cast a known-type map without going through the dispatcher.
- The dispatcher passes `&cast/1` (not `&from_map/1`) into `Resource.unwrap_singular/2` so the sum-type return works.
- `BankAccount` and `Card` modules have **no** `create`/`retrieve`/`update`/`delete`/`list`/`stream!` functions in Phase 18.

### Pattern 5: PII-safe `defimpl Inspect` (copy from `Customer`)

**Template:** `lib/lattice_stripe/customer.ex:467–489` [VERIFIED]. 16 existing modules already implement this pattern (`grep -c "defimpl Inspect"`).

**Quoted from `lib/lattice_stripe/customer.ex:467–489` [VERIFIED]:**

```elixir
defimpl Inspect, for: LatticeStripe.Customer do
  import Inspect.Algebra

  def inspect(customer, opts) do
    # Show only non-PII structural fields.
    fields = [
      id: customer.id,
      object: customer.object,
      livemode: customer.livemode,
      deleted: customer.deleted
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Customer<" | pairs] ++ [">"])
  end
end
```

**Per-struct hide-list (from D-01, D-06):**

| Struct | Show in Inspect | Hide (PII) |
|--------|-----------------|------------|
| `BankAccount` | `id`, `object`, `bank_name`, `country`, `currency`, `status` | `routing_number`, `account_number`, `fingerprint`, `account_holder_name` |
| `Card` | `id`, `object`, `brand`, `country`, `funding` | `last4`, `fingerprint`, `exp_month`, `exp_year`, `address_line1_check`, `cvc_check`, `address_zip_check`, `name` |
| `Charge` | `id`, `object`, `amount`, `currency`, `status`, `captured`, `paid` | `billing_details`, `payment_method_details`, `fraud_details`, `receipt_email`, `receipt_url` |
| `Transfer`, `TransferReversal`, `Payout`, `Balance`, `BalanceTransaction`, `ExternalAccount.Unknown` | Full struct (no PII) | None — use default `Inspect`, no `defimpl` block |

**Audit requirement:** Cross-check the `BankAccount` and `Card` hide-list against stripe-node's published PII list during execution (D-01 Claude's Discretion). [CITED: https://github.com/stripe/stripe-node]

### Anti-patterns to avoid

- **Hand-rolling `unwrap_singular` / `unwrap_list`** — always use `LatticeStripe.Resource` helpers. Phase 5 D-01 locked this.
- **Adding HTTP functions to `BankAccount` or `Card`** — CRUD lives on the `ExternalAccount` dispatcher, not the data modules. [D-01 locked]
- **Deriving `Jason.Encoder`** on any new resource struct — explicit project rule (C11), verified across all 16 existing resource modules.
- **Client-side param validation beyond `require_param!`** — P15 D5 locked "no fake ergonomics; let Stripe 400 flow through."
- **Atom-guarded dispatchers** — D-04 locked zero for Phase 18.
- **Touching `PaymentIntent` to add helper functions** — D-07 locked "no code changes; guide only."
- **Touching `Client` or `build_headers`** — `stripe_account:` threading is already wired; zero changes to infrastructure in Phase 18. [VERIFIED: client.ex:178,390-427 via CONTEXT.md scout]
- **Calling `String.to_atom/1` on user input anywhere** — always `String.to_existing_atom/1` with pre-declared atom table (see `Account.Capability.status_atom/1` pattern).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Extracting `data` from a singular JSON response | Custom `{:ok, %Response{data: data}}` deconstruction in every resource | `Resource.unwrap_singular(&from_map/1)` | 16 existing modules already use this; breaks cleanly on `{:error, _}` |
| Mapping paginated list items to typed structs | `Enum.map/2` over `list.data` inside each resource | `Resource.unwrap_list(&from_map/1)` | Preserves `%Response{}` wrapper so callers can read `resp.data.has_more`, `resp.data.data` |
| Auto-pagination via cursor loops | Manual `while has_more` loop per resource | `List.stream!(client, req) \|> Stream.map(&from_map/1)` | Lazy, composable with Stream/Enum, already tested |
| Bang-variant unwrapping | Case + raise per fn | `Resource.unwrap_bang!/1` | One place for the raise-or-return convention |
| Required-param validation | Custom `Map.has_key?` check per resource | `Resource.require_param!/3` | Consistent ArgumentError messages, pre-network (no mock setup in tests) |
| Polymorphic object-discriminator cast | Inline `case on object` in every call-site | `ExternalAccount.cast/1` dispatcher | Single source of truth for bank/card/unknown branching; `Unknown` fallback prevents crashes on new Stripe types |
| `Stripe-Account` header injection | New header middleware for Phase 18 | `Client` already threads it per-request (`client.ex:178,390-427`) and per-client (`client.ex:52–95`) | Verified wired — **zero Client changes in Phase 18** |
| Telemetry event emission for new endpoints | Hand-rolled `:telemetry.execute` calls | `Client.request/2` auto-spans via `Telemetry.request_span/4`; `parse_resource_and_operation/2` derives resource name from URL path | Phase 8 D-05 locked this — resource modules stay zero-telemetry |
| JSON form-encoding nested params | Manual URI-encoding per resource | `Client.request/2` uses `LatticeStripe.FormEncoder` (Phase 1) | Already handles `capabilities[card_payments][requested]=true` style |
| Reconciliation helpers (`BalanceTransaction.reconcile/3` etc.) | Convenience wrappers | `BalanceTransaction.list(client, %{payout: po.id})` raw + guide docs | D-07 locked: guide-only, no helpers |
| Destination-charge shortcut (`PaymentIntent.create_destination_charge/4`) | Rearranging existing `create/3` params | `PaymentIntent.create/3` with `application_fee_amount` + `transfer_data` in params | D-07 locked: PaymentIntent fields already typed, no wrapper |

**Key insight:** Phase 18 is almost entirely a pattern-match exercise. Four architectural beats (CRUDL module, nested typed struct, standalone sub-resource, PII `Inspect`) cover all but one new piece of ground, and that one piece (`ExternalAccount` polymorphic dispatcher) is explicitly spelled out in D-01. Plans should cite file-line anchors from this document, not invent new shapes.

## Stripe API Contract (field shapes and endpoints)

All endpoints sourced from `docs.stripe.com` URLs listed in `<canonical_refs>` of CONTEXT.md. Confidence HIGH — Stripe's API reference is the canonical contract.

### External Accounts on a Connected Account

**Endpoints** [CITED: https://docs.stripe.com/api/external_account_bank_accounts, https://docs.stripe.com/api/external_account_cards]:

| Operation | Method | Path |
|-----------|--------|------|
| Create external account | POST | `/v1/accounts/:account/external_accounts` |
| Retrieve | GET | `/v1/accounts/:account/external_accounts/:id` |
| Update | POST | `/v1/accounts/:account/external_accounts/:id` |
| Delete | DELETE | `/v1/accounts/:account/external_accounts/:id` |
| List | GET | `/v1/accounts/:account/external_accounts` (supports `?object=bank_account` / `?object=card` filter) |

**Create params (union across bank_account + card):**
- `external_account` (required) — either a token (`btok_...`, `tok_...`) or a nested hash with `object: "bank_account"` | `"card"` plus type-specific fields
- `default_for_currency` (optional, boolean)
- `metadata` (optional, map)

**`BankAccount` top-level object fields (Phase 18 `@known_fields` recommendation):**

```
id, object, account, account_holder_name, account_holder_type, account_type,
available_payout_methods, bank_name, country, currency, customer,
default_for_currency, fingerprint, last4, metadata, routing_number, status
```

**`Card` top-level object fields:**

```
id, object, account, address_city, address_country, address_line1,
address_line1_check, address_line2, address_state, address_zip,
address_zip_check, available_payout_methods, brand, country, currency,
customer, cvc_check, default_for_currency, dynamic_last4, exp_month,
exp_year, fingerprint, funding, last4, metadata, name, tokenization_method
```

### Transfers

**Endpoints** [CITED: https://docs.stripe.com/api/transfers]:

| Operation | Method | Path |
|-----------|--------|------|
| Create | POST | `/v1/transfers` |
| Retrieve | GET | `/v1/transfers/:id` |
| Update | POST | `/v1/transfers/:id` |
| List | GET | `/v1/transfers` |

**Create params:** `amount` (int), `currency` (str), `destination` (acct id; required), `description`, `metadata`, `source_transaction` (ch_...), `source_type` (`card` | `fpx` | ...), `transfer_group` (str). Multi-field — **no positional `destination`** per D-04.

**List filters:** `created`, `destination`, `ending_before`, `limit`, `starting_after`, `transfer_group`.

**`Transfer` `@known_fields` (Phase 18 recommendation, per `docs.stripe.com/api/transfers/object`):**

```
id, object, amount, amount_reversed, balance_transaction, created, currency,
description, destination, destination_payment, livemode, metadata, reversals,
reversed, source_transaction, source_type, transfer_group
```

- `reversals` decodes to `%Response{data: %List{data: [%TransferReversal{}]}}` ... **no** — it's an embedded sublist (not a paginated fetch), so decode via `reversals[].data |> Enum.map(&TransferReversal.from_map/1)` into a plain list and stash `has_more`/`url`/`total_count` into `:extra` per D-02.

### Transfer Reversals (standalone per D-02)

**Endpoints** [CITED: https://docs.stripe.com/api/transfer_reversals]:

| Operation | Method | Path |
|-----------|--------|------|
| Create | POST | `/v1/transfers/:transfer/reversals` |
| Retrieve | GET | `/v1/transfers/:transfer/reversals/:id` |
| Update | POST | `/v1/transfers/:transfer/reversals/:id` |
| List | GET | `/v1/transfers/:transfer/reversals` |

**Create params:** `amount` (int), `description`, `metadata`, `refund_application_fee` (bool), `expand`.

**`TransferReversal` `@known_fields`:**

```
id, object, amount, balance_transaction, created, currency, destination_payment_refund,
metadata, source_refund, transfer
```

### Payouts

**Endpoints** [CITED: https://docs.stripe.com/api/payouts, https://docs.stripe.com/api/payouts/cancel, https://docs.stripe.com/api/payouts/reverse]:

| Operation | Method | Path |
|-----------|--------|------|
| Create | POST | `/v1/payouts` |
| Retrieve | GET | `/v1/payouts/:id` |
| Update | POST | `/v1/payouts/:id` |
| List | GET | `/v1/payouts` |
| Cancel | POST | `/v1/payouts/:id/cancel` (accepts `expand`) |
| Reverse | POST | `/v1/payouts/:id/reverse` (accepts `expand`, `metadata`) |

**Create params:** `amount` (required int), `currency` (required str), `description`, `destination` (bank acct / card id), `metadata`, `method` (`"standard"` | `"instant"`), `source_type` (`"card"` | `"bank_account"` | `"fpx"`), `statement_descriptor`.

**List filters:** `arrival_date`, `created`, `destination`, `ending_before`, `limit`, `starting_after`, `status`.

**`Payout` `@known_fields`:**

```
id, object, amount, application_fee, application_fee_amount, arrival_date,
automatic, balance_transaction, created, currency, description, destination,
failure_balance_transaction, failure_code, failure_message, livemode, metadata,
method, original_payout, reconciliation_status, reversed_by, source_type,
statement_descriptor, status, trace_id, type
```

**`Payout.TraceId` nested struct** [D-05]: `@known_fields [:status, :value]` — `status` is an enum pattern-match target.

### Balance (singleton)

**Endpoint** [CITED: https://docs.stripe.com/api/balance]: `GET /v1/balance`. No id. No list.

**`Balance.retrieve(client, opts \\ [])` — `stripe_account:` opt flips to connected-account balance.** [VERIFIED: client.ex:178,390-427 per CONTEXT.md]

**`Balance` `@known_fields`:**

```
object, available, connect_reserved, instant_available, issuing, livemode,
pending
```

- `available`, `pending`, `connect_reserved`, `instant_available` are `[%Balance.Amount{}]` — cast via `Enum.map(raw, &Balance.Amount.cast/1)`.
- `issuing` is a map with `available: [%Balance.Amount{}]` — cast via custom branch.

**`Balance.Amount` nested struct** [D-05]: `@known_fields [:amount, :currency, :source_types]`. `net_available` lands in `:extra` per D-05 rule 1.

**`Balance.SourceTypes` nested struct** [D-05, P17 D-02 typed-inner-open-outer]: `@known_fields [:card, :bank_account, :fpx]` + `:extra` for future payment-method keys. Embedded inside every `Balance.Amount`.

### Balance Transactions

**Endpoints** [CITED: https://docs.stripe.com/api/balance_transactions, https://docs.stripe.com/api/balance_transactions/list]:

| Operation | Method | Path |
|-----------|--------|------|
| Retrieve | GET | `/v1/balance_transactions/:id` |
| List | GET | `/v1/balance_transactions` |

**No create/update/delete** — Stripe manages these server-side. `BalanceTransaction` ships `retrieve/3`, `list/3`, `stream!/3` + bang variants only.

**List filters (all native per Stripe):** `created`, `currency`, `ending_before`, `limit`, `payout`, `source`, `starting_after`, `type`.

**`BalanceTransaction` `@known_fields`:**

```
id, object, amount, available_on, created, currency, description, exchange_rate,
fee, fee_details, net, reporting_category, source, status, type
```

- `fee_details` is `[%FeeDetail{}]` — cast each via `FeeDetail.cast/1`.
- `source` stays opaque `binary | map()` per D-05 rule 5.
- `type` stays permissive `String.t() | nil` per Claude's Discretion (no typed union).

**`BalanceTransaction.FeeDetail` nested struct** [D-05]: `@known_fields [:amount, :application, :currency, :description, :type]`. `type` enum values per Stripe [CITED: https://docs.stripe.com/api/balance_transactions/object]: `application_fee`, `stripe_fee`, `payment_method_passthrough_fee`, `tax`, `withheld_tax`. Reconciliation pattern: `Enum.filter(bt.fee_details, &(&1.type == "application_fee"))`.

### Charge (retrieve-only per D-06)

**Endpoint** [CITED: https://docs.stripe.com/api/charges/retrieve]: `GET /v1/charges/:id`.

**`@known_fields`** (already locked in D-06, quoted verbatim):

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

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `BankAccount` and `Card` PII hide-lists match stripe-node's published list | Pattern 5 | Over-hide is harmless; under-hide leaks PII into logs — **execution MUST audit before ship** (D-01 Claude's Discretion) |
| A2 | The exact `@known_fields` list per resource above is complete | Stripe API Contract | Missing a field just dumps it into `:extra` (F-001 guarantees no data loss); promote in a follow-up if users ask to pattern-match it |
| A3 | `Transfer.reversals` embedded sublist field uses the same shape as Stripe's generic sub-list wrapper (`data`, `has_more`, `url`, `total_count`) | Stripe API Contract | Shape verified from API reference docs; D-02 already absorbs the wrapper into `:extra` |
| A4 | stripe-mock returns realistic `fee_details` entries for `application_fee` reconciliation integration tests | Validation Architecture | Falls back to unit-tested fixtures if stripe-mock's payloads are thin |
| A5 | `parse_resource_and_operation/2` from Phase 8 auto-derives resource names for `/v1/transfers/:id/reversals/:rid` correctly (nested URL) | Don't Hand-Roll | If it misbehaves on nested URLs, plan must add a targeted telemetry test; Phase 8 already shipped on `/v1/account_links` so the pattern is covered |

**All five are low-risk** — worst case is a follow-up fix, not a failed ship.

## Common Pitfalls

### Pitfall 1: Dispatcher returning tagged tuples

**What goes wrong:** Writing `cast/1` to return `{:bank_account, %BankAccount{}}` or `{:card, %Card{}}` instead of a bare struct.

**Why it happens:** Erlang/Elixir idiom bias — tagged tuples feel natural for sum types.

**How to avoid:** D-01 explicitly rejects this (Option 3 in the rejected alternatives). The dispatcher returns a bare struct; callers pattern-match on `%BankAccount{}` vs `%Card{}` directly: `case ea do %BankAccount{} -> ...; %Card{} -> ...; %ExternalAccount.Unknown{} -> ... end`.

**Warning sign:** Tests that write `{:ok, {:bank_account, %BankAccount{}}} = ExternalAccount.retrieve(...)` — that's the broken shape.

### Pitfall 2: `Balance.retrieve` forgetting the connected-account path

**What goes wrong:** `Balance.retrieve/2` called without `stripe_account:` opt returns the **platform** balance when the caller wanted the connected account's balance, leading to silent wrong-answer bugs during Connect reconciliation.

**Why it happens:** There is no compile-time distinction between platform vs connected-account retrieval — both use the same function.

**How to avoid:** Guide (D-07 section 2) shows the connected-account form prominently; moduledoc opens with both examples side-by-side. Integration test has explicit cases for both. [CONTEXT.md line 415: "the guide must show this prominently"]

**Warning sign:** Reconciliation code that calls `Balance.retrieve(client)` with no opts inside a loop over connected accounts.

### Pitfall 3: `Payout.cancel` / `Payout.reverse` without `\\ %{}`

**What goes wrong:** Dropping the `params` parameter for "no body" endpoints forces a breaking change the first time a user needs `expand: ["balance_transaction"]`.

**Why it happens:** Perception that cancel/reverse don't accept a body.

**How to avoid:** D-03 locks `(client, id, params \\ %{}, opts \\ [])` on both. Both accept `expand`; `reverse` additionally accepts `metadata`. [CITED: https://docs.stripe.com/api/payouts/cancel, https://docs.stripe.com/api/payouts/reverse]

**Warning sign:** `cancel(%Client{} = client, id, opts \\ [])` — wrong arity.

### Pitfall 4: `from_map/1` on polymorphic nested fields

**What goes wrong:** `Payout.destination` is an **expandable reference** (string OR expanded `%BankAccount{}`/`%Card{}`). Writing `Payout.from_map/1` to force a cast via `BankAccount.cast/1` will crash when `destination` is a bare string.

**Why it happens:** Forgetting that `expand` is opt-in.

**How to avoid:** D-05 rule 7 locks: expandable references stay as raw `binary | map()` on the struct. Users who expand can cast the expanded map via `ExternalAccount.cast/1` themselves in the guide.

**Warning sign:** Crash traces where `Payout.from_map/1` is called on a response where `destination` is a string.

### Pitfall 5: `Transfer.reversals` treated as a paginated list

**What goes wrong:** Writing `Transfer.reversals` as a `%Response{data: %List{}}` value or trying to `List.stream!` it.

**Why it happens:** The embedded sublist wrapper looks superficially like a `List` response.

**How to avoid:** D-02 locks: decode `reversals.data` to a plain `[%TransferReversal{}]` and stash `has_more` / `url` / `total_count` into `:extra`. Users who want full reversal history call `TransferReversal.list(client, transfer_id)` explicitly.

**Warning sign:** Tests that do `transfer.reversals.data` returning a `%List{}` struct.

### Pitfall 6: Touching `PaymentIntent` to add Connect helpers

**What goes wrong:** Adding `PaymentIntent.create_destination_charge/4` or `PaymentIntent.TransferData` nested struct during Phase 18 execution because the guide "reads nicer" with them.

**Why it happens:** Scope creep driven by guide polish.

**How to avoid:** D-07 explicitly rejects all such helpers. PaymentIntent destination-charge fields (`application_fee_amount`, `transfer_data`, `on_behalf_of`, `transfer_group`) are **already** in `@known_fields` per scout [VERIFIED: CONTEXT.md line 340 cites `payment_intent.ex:66–77, 139–173`]. Plans must include an explicit "no PaymentIntent code changes" guard in the execution checklist.

**Warning sign:** Any plan task touching `lib/lattice_stripe/payment_intent.ex`.

## Runtime State Inventory

Not applicable. Phase 18 is pure additive feature work — no rename, refactor, migration, or string replacement. No data stores, no OS registrations, no stored state to update.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | All tests | — | `>= 1.15` (per `mix.exs`) | None — project requirement |
| Erlang/OTP | All tests | — | `>= 26` | None — project requirement |
| `Finch` | `Client.request/2` path for integration tests | Already in `mix.exs` | `~> 0.21` | None — transport default |
| `Jason` | JSON decoding | Already in `mix.exs` | `~> 1.4` | None — codec default |
| `Mox` | Unit test stubs | Already in `mix.exs` | `~> 1.2` | None — standard test mock |
| `Credo` | `mix ci` gate | Already in `mix.exs` | `~> 1.7` | None — CI gate |
| `stripe/stripe-mock` Docker image | Integration tests | Already wired in CI via Phase 11 | `latest` | Skip integration suite, run unit + Mox only |
| `docker` CLI locally | Running `mix test.integration` on a dev box | Assumed — required in Phase 9 for `test_integration_client/0` | N/A | Unit + Mox suite only |

**Missing dependencies with no fallback:** none.

**Missing dependencies with fallback:** none expected.

**Assumption:** The dev box executing Phase 18 plans already runs `docker` for `stripe-mock` because Phase 17 integration tests shipped and ran against the same setup (STATE.md line 31 confirms 18 integration tests passing). If not, the integration-tests plan can skip locally and rely on GitHub Actions CI. [ASSUMED]

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json` — this section is required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) + Mox `~> 1.2` |
| Config file | `.formatter.exs`, `mix.exs` (`test_coverage`, `elixirc_paths(:test)`), `test/test_helper.exs` (integration config via `test_integration_client/0`) |
| Quick run command | `mix test --exclude integration test/lattice_stripe/<resource>_test.exs` |
| Full suite command | `mix ci` (runs format check, compile --warnings-as-errors, credo strict, test, docs build) |
| Integration command | `mix test --only integration` (requires `docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest`) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CNCT-02 | `Transfer.create/3` happy path with params form-encoded | unit (Mox) | `mix test test/lattice_stripe/transfer_test.exs:<line>` | ❌ Wave 1 |
| CNCT-02 | `Transfer.retrieve/3` decodes nested `reversals.data` into `[%TransferReversal{}]`, stashes `has_more`/`url` into `:extra` | unit | `mix test test/lattice_stripe/transfer_test.exs` | ❌ Wave 1 |
| CNCT-02 | `Transfer.list/3` returns `%Response{data: %List{data: [%Transfer{}]}}` | unit | `mix test test/lattice_stripe/transfer_test.exs` | ❌ Wave 1 |
| CNCT-02 | `Transfer.stream!/3` emits `%Transfer{}` structs and auto-paginates | unit | `mix test test/lattice_stripe/transfer_test.exs` | ❌ Wave 1 |
| CNCT-02 | `Transfer.*` full CRUD + stream against stripe-mock | integration | `mix test --only integration test/integration/transfer_integration_test.exs` | ❌ Wave 1 |
| CNCT-02 | `TransferReversal.create/4` requires both `transfer_id` and `reversal_id` via `require_param!` pre-network | unit | `mix test test/lattice_stripe/transfer_reversal_test.exs` | ❌ Wave 1 |
| CNCT-02 | `TransferReversal.retrieve/4` and `update/5` use `/v1/transfers/:t/reversals/:r` URL shape | unit (Mox asserts exact path) | `mix test test/lattice_stripe/transfer_reversal_test.exs` | ❌ Wave 1 |
| CNCT-02 | `TransferReversal` CRUD via stripe-mock | integration | `mix test --only integration test/integration/transfer_reversal_integration_test.exs` | ❌ Wave 1 |
| CNCT-02 | `Payout.create/3` happy path | unit | `mix test test/lattice_stripe/payout_test.exs` | ❌ Wave 2 |
| CNCT-02 | `Payout.cancel/4` signature `(client, id, params \\ %{}, opts \\ [])` — covers no-params and `expand: [...]` cases | unit | `mix test test/lattice_stripe/payout_test.exs` | ❌ Wave 2 |
| CNCT-02 | `Payout.reverse/4` signature matches D-03, accepts `metadata` + `expand` | unit | `mix test test/lattice_stripe/payout_test.exs` | ❌ Wave 2 |
| CNCT-02 | `Payout.TraceId.cast/1` splits `{status, value}` into struct, dumps unknown keys to `:extra` | unit | `mix test test/lattice_stripe/payout/trace_id_test.exs` | ❌ Wave 2 |
| CNCT-02 | `Payout` full lifecycle (create → cancel → reverse) against stripe-mock | integration | `mix test --only integration test/integration/payout_integration_test.exs` | ❌ Wave 2 |
| CNCT-03 | Destination charge via `PaymentIntent.create` with `application_fee_amount` + `transfer_data` — **doctest** inside `guides/connect.md` code block | doctest / manual (readable code block) | `mix docs` parses the guide fence | ❌ Wave 4 |
| CNCT-03 | Separate charge/transfer three-step flow: `PaymentIntent.create` → confirm → `Transfer.create` with `source_transaction: ch_...` | integration (or guide smoke) | `mix test --only integration test/integration/transfer_integration_test.exs` (scenario test) | ❌ Wave 1/4 |
| CNCT-04 | `BalanceTransaction.FeeDetail.cast/1` decodes `{amount, currency, description, type, application}` | unit | `mix test test/lattice_stripe/balance_transaction/fee_detail_test.exs` | ❌ Wave 3 |
| CNCT-04 | Reconciliation filter: `Enum.filter(bt.fee_details, &(&1.type == "application_fee"))` | unit (via fixture) | `mix test test/lattice_stripe/balance_transaction_test.exs` | ❌ Wave 3 |
| CNCT-04 | `Charge.retrieve/3` returns typed `%Charge{}` with `balance_transaction` as either string or expandable map | unit | `mix test test/lattice_stripe/charge_test.exs` | ❌ Wave 1 |
| CNCT-04 | `Charge` retrieve with `expand: ["balance_transaction"]` against stripe-mock | integration | `mix test --only integration test/integration/charge_integration_test.exs` | ❌ Wave 1 |
| CNCT-04 | `Charge` PII `Inspect` hides `billing_details`, `payment_method_details`, `fraud_details` | unit | `mix test test/lattice_stripe/charge_test.exs` | ❌ Wave 1 |
| CNCT-05 | `Balance.retrieve/2` singleton — no id, `retrieve!/2` bang variant | unit | `mix test test/lattice_stripe/balance_test.exs` | ❌ Wave 3 |
| CNCT-05 | `Balance.retrieve(client, stripe_account: "acct_...")` threads `Stripe-Account` header | unit (Mox asserts header presence) | `mix test test/lattice_stripe/balance_test.exs` | ❌ Wave 3 |
| CNCT-05 | `Balance.Amount.cast/1` + 5× reuse inside `%Balance{}` | unit | `mix test test/lattice_stripe/balance/amount_test.exs` | ❌ Wave 3 |
| CNCT-05 | `Balance.SourceTypes.cast/1` typed-inner-open-outer — unknown payment methods land in `:extra` | unit | `mix test test/lattice_stripe/balance/source_types_test.exs` | ❌ Wave 3 |
| CNCT-05 | `Balance` retrieve platform + connected-account via stripe-mock | integration | `mix test --only integration test/integration/balance_integration_test.exs` | ❌ Wave 3 |
| CNCT-05 | `BalanceTransaction.list/3` with `%{payout: "po_..."}` filter | unit | `mix test test/lattice_stripe/balance_transaction_test.exs` | ❌ Wave 3 |
| CNCT-05 | `BalanceTransaction.stream!/3` lazy auto-pagination | unit | `mix test test/lattice_stripe/balance_transaction_test.exs` | ❌ Wave 3 |
| CNCT-05 | `BalanceTransaction` list by payout + retrieve against stripe-mock | integration | `mix test --only integration test/integration/balance_transaction_integration_test.exs` | ❌ Wave 3 |
| (ExternalAccount core) | `ExternalAccount.cast/1` dispatches on `object` — bank_account, card, unknown fallback | unit | `mix test test/lattice_stripe/external_account_test.exs` | ❌ Wave 1 |
| (ExternalAccount core) | `ExternalAccount.create/4` returns `BankAccount.t() \| Card.t() \| Unknown.t()` sum type | unit | `mix test test/lattice_stripe/external_account_test.exs` | ❌ Wave 1 |
| (ExternalAccount core) | `ExternalAccount` polymorphic CRUD + mixed list against stripe-mock | integration | `mix test --only integration test/integration/external_account_integration_test.exs` | ❌ Wave 1 |
| (ExternalAccount core) | `BankAccount.cast/1` + F-001 unknown-field preservation | unit | `mix test test/lattice_stripe/bank_account_test.exs` | ❌ Wave 1 |
| (ExternalAccount core) | `BankAccount` PII `Inspect` hides `routing_number`, `account_number`, `fingerprint`, `account_holder_name` | unit | `mix test test/lattice_stripe/bank_account_test.exs` | ❌ Wave 1 |
| (ExternalAccount core) | `Card.cast/1` + F-001 | unit | `mix test test/lattice_stripe/card_test.exs` | ❌ Wave 1 |
| (ExternalAccount core) | `Card` PII `Inspect` hides `last4`, `fingerprint`, `exp_month`, `exp_year`, `address_line1_check`, `cvc_check`, `address_zip_check`, `name` | unit | `mix test test/lattice_stripe/card_test.exs` | ❌ Wave 1 |
| (guide) | `guides/connect.md` money-movement section compiles in `mix docs --warnings-as-errors` | doc build | `mix docs` | ❌ Wave 4 |
| (exdoc) | New modules appear in ExDoc "Connect" group (except `Charge` → "Payments") | doc build | `mix docs` + manual verification | ❌ Wave 4 |

### Sampling Rate

- **Per task commit:** `mix test --exclude integration test/lattice_stripe/<resource>_test.exs` (quick — single file, ~1s). Task turning a single resource module green should rerun its own file.
- **Per wave merge:** `mix test --exclude integration` (full unit suite, ~3–5s per STATE.md velocity table).
- **Wave 4 + phase gate:** `mix ci` — runs format, compile --warnings-as-errors, credo strict, full test suite, docs build. Integration suite runs via `mix test --only integration` after `stripe-mock` is started.
- **Before `/gsd-verify-work`:** full `mix ci` green AND `mix test --only integration` green.

### Wave 0 Gaps

Phase 18 has **no Wave 0** in the narrow sense because test infrastructure is fully established (Phases 9, 11, 17 all passed green). Plans should still confirm the following exists as a Wave-1 prerequisite check (take < 30 seconds):

- [ ] `mix test --exclude integration` runs clean on the current `main` (baseline)
- [ ] `mix test --only integration` runs clean against `stripe-mock` on the dev box
- [ ] `mix ci` runs clean on current `main`

No framework install, no config file creation, no shared-fixture bootstrapping beyond adding new fixture modules under the existing `test/support/fixtures/` directory (which Phase 6 established).

## Code Examples

Canonical patterns verified against the existing codebase. Plans should reference these file-line anchors directly.

### Example 1: F-001 `@known_fields` + `:extra` + `Map.split` (top-level resource)

```elixir
# Source: lib/lattice_stripe/customer.ex:50-91, 436-463 [VERIFIED]

# 1. Known fields as string sigil
@known_fields ~w[id object amount currency status ...]

# 2. Explicit defstruct with atom keys + object default + extra
defstruct [
  :id,
  :amount,
  # ... every known field as a keyword-list entry
  object: "customer",
  extra: %{}
]

# 3. from_map/1 maps each known field explicitly then Map.drop/2 for extra
def from_map(map) when is_map(map) do
  %__MODULE__{
    id: map["id"],
    amount: map["amount"],
    # ... every field spelled out
    extra: Map.drop(map, @known_fields)
  }
end
```

### Example 2: F-001 nested struct (`~w()a` atom sigil)

```elixir
# Source: lib/lattice_stripe/account/capability.ex:20-48 [VERIFIED]

@known_fields ~w(status requested requested_at requirements disabled_reason)a

defstruct @known_fields ++ [extra: %{}]

@type t :: %__MODULE__{
        status: String.t() | nil,
        requested: boolean() | nil,
        requested_at: integer() | nil,
        requirements: map() | nil,
        disabled_reason: String.t() | nil,
        extra: map()
      }

def cast(nil), do: nil

def cast(map) when is_map(map) do
  known_string_keys = Enum.map(@known_fields, &Atom.to_string/1)
  {known, extra} = Map.split(map, known_string_keys)

  struct(__MODULE__,
    status: known["status"],
    requested: known["requested"],
    requested_at: known["requested_at"],
    requirements: known["requirements"],
    disabled_reason: known["disabled_reason"],
    extra: extra
  )
end
```

### Example 3: Action verb with default params (template for `Payout.cancel` + `Payout.reverse`)

```elixir
# Source: lib/lattice_stripe/refund.ex:239-244 [VERIFIED]

@spec cancel(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def cancel(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
  %Request{method: :post, path: "/v1/refunds/#{id}/cancel", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

### Example 4: `stream!/3` auto-pagination

```elixir
# Source: lib/lattice_stripe/refund.ex:298-302 [VERIFIED]

@spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
  req = %Request{method: :get, path: "/v1/refunds", params: params, opts: opts}
  List.stream!(client, req) |> Stream.map(&from_map/1)
end
```

### Example 5: PII-safe `Inspect` impl

```elixir
# Source: lib/lattice_stripe/customer.ex:467-489 [VERIFIED]
# Template for BankAccount, Card, Charge

defimpl Inspect, for: LatticeStripe.BankAccount do
  import Inspect.Algebra

  def inspect(ba, opts) do
    fields = [
      id: ba.id,
      object: ba.object,
      bank_name: ba.bank_name,
      country: ba.country,
      currency: ba.currency,
      status: ba.status
      # Hidden: routing_number, account_number, fingerprint, account_holder_name
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.BankAccount<" | pairs] ++ [">"])
  end
end
```

### Example 6: Two-arg `(transfer_id, reversal_id)` addressing (template for `TransferReversal.retrieve`)

```elixir
# New pattern for Phase 18, extending AccountLink-style standalone module

@spec retrieve(Client.t(), String.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def retrieve(%Client{} = client, transfer_id, reversal_id, opts \\ [])
    when is_binary(transfer_id) and is_binary(reversal_id) do
  %Request{
    method: :get,
    path: "/v1/transfers/#{transfer_id}/reversals/#{reversal_id}",
    params: %{},
    opts: opts
  }
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

## Security Domain

`security_enforcement` config key absent → treat as enabled.

### Applicable ASVS categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | **yes** — all requests send `Authorization: Bearer <api_key>` | Already wired via `Client.build_headers/5` (Phase 1); Phase 18 inherits zero-config |
| V3 Session Management | no — stateless HTTP SDK, no sessions | — |
| V4 Access Control | **yes** — `Stripe-Account` header scopes ops to connected account | Already wired per-client + per-request (`client.ex:178,390-427`); Phase 18 relies on it |
| V5 Input Validation | **yes** — all user-supplied params passed to Stripe API | `require_param!/3` for endpoint-required params; otherwise P15 D5 "let Stripe 400 flow through" |
| V6 Cryptography | no — TLS handled by Finch; no signing in Phase 18 (webhooks are Phase 7) | — |
| V7 Error Handling | **yes** — errors must not leak secrets | `Error` struct already scrubs `Authorization` header (Phase 2); new resources inherit |
| V8 Data Protection | **yes** — PII in bank account / card / charge responses | PII-safe `defimpl Inspect` on `BankAccount`, `Card`, `Charge` (Pattern 5 + D-01 + D-06) |
| V11 Business Logic | **yes** — money movement is high-stakes | Webhook-handoff callouts in guide (D-07) to prevent UI-from-SDK-response anti-pattern |
| V14 Configuration | **yes** — API keys and connected-account IDs are sensitive config | No global config; `Client.t()` struct passed explicitly (C10) |

### Known threat patterns for Elixir Stripe SDK

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| API key leaked in logs via `Kernel.inspect/1` on `%Client{}` | Information Disclosure | Existing `Client` `defimpl Inspect` already scrubs `api_key` (Phase 1); Phase 18 inherits |
| Bank account number / card last4 leaked via `inspect/1` in crash reports | Information Disclosure | PII-safe `defimpl Inspect` on `BankAccount`, `Card`, `Charge` — mandatory per D-01, D-06 |
| Wrong connected account balance returned due to missing `stripe_account:` opt | Tampering / Business Logic | Guide prominently shows both platform and connected-account retrieval forms (D-07 section 2); integration tests cover both explicit paths |
| Idempotency conflict on retried `Transfer.create` | Business Logic / Tampering | `Client` auto-generates idempotency keys and reuses on retry (Phase 2 RTRY-03); 409 surfaces as `:idempotency_error` per ERRR-04 |
| Timing-attack on `fingerprint` comparison | Information Disclosure | Not applicable — no signature verification in Phase 18. PII just hidden from `Inspect`; users comparing fingerprints should already use `Plug.Crypto.secure_compare/2` (out of SDK scope) |
| Stripe-Account header spoofing by logging PII | Information Disclosure | Connected-account IDs are not secret but Phase 18 guide warns against logging `%BankAccount{}` / `%Card{}` structs raw |
| Mass-assignment via unchecked params map | Tampering | Stripe server-side validation is authoritative; SDK `require_param!` only for endpoint-required params (P15 D5) |
| User-supplied atom → atom table exhaustion | DoS | Never call `String.to_atom/1` on user input; follow `Account.Capability.status_atom/1` pattern with pre-declared atom table (C10 + existing `lib/lattice_stripe/account/capability.ex:50-58`) |

## State of the Art

| Old approach | Current approach | When changed | Impact for Phase 18 |
|--------------|------------------|--------------|---------------------|
| Charge-based payments as primary flow | PaymentIntent-first | Stripe API 2019+ | `Charge` ships retrieve-only (D-06); moduledoc opens with PaymentIntent pointer |
| Legacy `/v1/customers/:id/sources` for card storage | PaymentMethod + SetupIntent | Stripe API 2019+ | Phase 18 covers connected-account external accounts only; customer sources deferred |
| Hand-rolled polling for payout status | Webhooks (`payout.paid`, `payout.failed`) | Stripe platform event-driven architecture | Guide callout on every money-movement transition (D-07) |
| Polling balance for reconciliation | `BalanceTransaction.list` with `payout:` filter triggered by `payout.paid` webhook | Stripe platform standard | D-07 section 7 shows the idiom; `BalanceTransaction.stream!/3` available for large payouts |
| Single `ExternalAccount` class mixing bank + card (stripe-go) | First-class `BankAccount` + `Card` types (stripe-ruby, python, node, java) | Typed-SDK ecosystem consensus | D-01 follows 4-of-5 SDK consensus; Go outlier explicitly rejected |

**Deprecated / outdated:**
- `Charge.create` — PaymentIntent replaces it. Not shipped in Phase 18.
- `Transfer.reversal_id` singular field — Stripe now always returns a `reversals` sublist even for single reversals; D-02 handles both shapes via `[%TransferReversal{}]`.

## Open Questions (RESOLVED)

1. **Does stripe-mock return non-trivial `fee_details` entries for BalanceTransaction list calls?**
   - What we know: stripe-mock returns OpenAPI-spec-generated sample payloads; the spec defines `fee_details` shape.
   - What's unclear: whether the generated samples include a realistic `type == "application_fee"` entry by default, or return an empty list.
   - **RESOLVED:** Integration tests assert the **shape** of `fee_details` only (list of `%FeeDetail{}` or empty). Unit tests via Mox fixtures cover the `application_fee` filter logic end-to-end with synthetic payloads. No blocker for planning.

2. **Does the Phase 8 telemetry path parser handle nested URLs (`/v1/transfers/:id/reversals/:rid`) cleanly?**
   - What we know: `parse_resource_and_operation/2` derives resource from URL path (STATE.md line 112); Phase 17 shipped `/v1/account_links` which is flat.
   - What's unclear: whether the parser emits a sensible `resource: "transfer_reversal"` or something like `"transfers/:id/reversals"` for the nested path.
   - **RESOLVED:** Plan 03 adds one targeted telemetry unit test asserting the derived resource name for a `/v1/transfers/:id/reversals` request. If the parser emits a malformed name, Plan 03 fixes `parse_resource_and_operation/2` as an in-phase micro-change (Phase 8 code, but low-risk and scope-adjacent to Phase 18 needs).

3. **Does `BankAccount.account_holder_name` actually appear in recent Stripe API responses, or is it deprecated in favor of `account_holder_type`?**
   - What we know: stripe-ruby and stripe-node still document `account_holder_name`.
   - What's unclear: whether Stripe's current API version (pinned in `Client`) still returns it.
   - **RESOLVED:** Include `account_holder_name` in `@known_fields` and add to the PII Inspect hide-list preemptively. F-001 (nested-struct open-outer policy) guarantees that if Stripe drops the field, it simply decodes as `nil` — no breakage. No blocker for planning.

## Sources

### Primary (HIGH confidence — official Stripe docs or verified codebase)

- [VERIFIED] `/Users/jon/projects/lattice_stripe/CLAUDE.md` — project constraints C1–C12
- [VERIFIED] `/Users/jon/projects/lattice_stripe/.planning/phases/18-connect-money-movement/18-CONTEXT.md` — locked decisions D-01..D-07, canonical refs, deferred ideas
- [VERIFIED] `/Users/jon/projects/lattice_stripe/.planning/REQUIREMENTS.md` — CNCT-02..CNCT-05 definitions (lines 184–187)
- [VERIFIED] `/Users/jon/projects/lattice_stripe/.planning/STATE.md` — project decisions log, Phase 17 completion
- [VERIFIED] `/Users/jon/projects/lattice_stripe/.planning/ROADMAP.md` Phase 18 (lines 224–236)
- [VERIFIED] `lib/lattice_stripe/refund.ex` — CRUDL template, `cancel/4` action-verb shape
- [VERIFIED] `lib/lattice_stripe/account/capability.ex` — F-001 nested struct template
- [VERIFIED] `lib/lattice_stripe/account_link.ex` — standalone sub-resource template
- [VERIFIED] `lib/lattice_stripe/customer.ex` — top-level F-001 + PII Inspect template
- [VERIFIED] `lib/lattice_stripe/resource.ex` — shared unwrap + require_param helpers
- [VERIFIED] Directory listing of `lib/lattice_stripe/` — confirms existing modules and informs new-file placement
- [CITED] https://docs.stripe.com/api/external_account_bank_accounts — BankAccount CRUD endpoint contract
- [CITED] https://docs.stripe.com/api/external_account_cards — Card CRUD endpoint contract
- [CITED] https://docs.stripe.com/api/transfers — Transfer endpoint contract
- [CITED] https://docs.stripe.com/api/transfer_reversals — TransferReversal standalone-resource confirmation
- [CITED] https://docs.stripe.com/api/payouts — Payout endpoint contract
- [CITED] https://docs.stripe.com/api/payouts/cancel — confirms `expand` param
- [CITED] https://docs.stripe.com/api/payouts/reverse — confirms `expand` + `metadata` params
- [CITED] https://docs.stripe.com/api/balance — Balance singleton shape
- [CITED] https://docs.stripe.com/api/balance_transactions — BalanceTransaction endpoint contract
- [CITED] https://docs.stripe.com/api/balance_transactions/list — native filters (`payout`, `source`, `type`, `currency`, `created`)
- [CITED] https://docs.stripe.com/api/balance_transactions/object — `fee_details` schema + `type` enum values
- [CITED] https://docs.stripe.com/api/charges/retrieve — Charge retrieve endpoint
- [CITED] https://docs.stripe.com/connect/destination-charges — destination-charge pattern
- [CITED] https://docs.stripe.com/connect/separate-charges-and-transfers — three-step separate flow
- [CITED] https://docs.stripe.com/connect/platform-fees — platform fee reconciliation flows

### Secondary (MEDIUM confidence — cross-SDK verification, one removed from official)

- [CITED] https://github.com/stripe/stripe-java — `TransferReversal` as top-level class; `BankAccount` + `Card` as separate types confirms D-01/D-02
- [CITED] https://github.com/stripe/stripe-node — TS union `ExternalAccount = BankAccount | Card` confirms D-01
- [CITED] https://github.com/stripe/stripe-ruby — `BalanceTransaction.FeeDetail` promotion confirms D-05
- [CITED] https://github.com/stripe/stripe-go — `Payout.TraceId` struct promotion confirms D-05
- [CITED] https://github.com/beam-community/stripity-stripe — closest Elixir precedent for CRUD shapes

### Tertiary (LOW confidence — flagged in Assumptions Log)

- [ASSUMED] stripe-node PII hide-list is authoritative — must audit during execution (A1, D-01 Claude's Discretion)
- [ASSUMED] stripe-mock returns usable `fee_details` data (A4, Open Question 1)

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — all primitives already in `mix.exs` and verified by reading existing modules
- Architecture patterns: **HIGH** — all five patterns quoted verbatim from existing codebase files
- Stripe API contract: **HIGH** — every endpoint cites an official `docs.stripe.com` URL; CONTEXT.md already walked these with 4 parallel research agents
- Validation architecture: **HIGH** — Phase 18 inherits the full Phase 9/11/17 test infrastructure with zero bootstrap gaps
- Security: **HIGH** — ASVS mapping straightforward; threat model inherited from Phases 1/2/7; PII hide-lists locked in D-01/D-06
- Pitfalls: **HIGH** — every pitfall is a locked decision from CONTEXT.md (D-01..D-07) or a verified scout finding

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (30 days — Stripe API is stable, pinned API version in `Client`, no dependency churn expected)
