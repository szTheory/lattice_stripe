# Phase 33: Disputes - Research

**Researched:** 2026-04-17
**Domain:** Stripe Dispute lifecycle — retrieve, list, metadata update, evidence staging, evidence submission, dispute close/accept, typed nested struct deserialization
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Evidence API Split**
- D-01: `update_evidence/4` accepts a flat map of evidence fields — wraps internally into `%{evidence: evidence_map, submit: false}`. Silently strips any stray `submit` key the user passes. The function's contract is safety: impossible to accidentally submit.
- D-02: `update/4` does NOT reject evidence fields — it is the general-purpose method for power users who want raw API access. Accepts anything the Stripe API accepts, including `evidence` + `submit: true` for atomic stage+submit.
- D-03: `submit_evidence/3` takes NO evidence param — signature is `submit_evidence(client, id, opts \\ [])`. Forces the two-step stage-then-submit workflow. Sends `%{submit: true}` to the Stripe endpoint.
- D-04: All three functions (`update/4`, `update_evidence/4`, `submit_evidence/3`) delegate to a shared `defp do_update/4` that calls `POST /v1/disputes/:id`. Single implementation, three semantic entry points.

**Nested Struct Depth**
- D-05: `Dispute.PaymentMethodDetails` gets its own struct with `@known_fields ~w[type card klarna paypal amazon_pay]` + `extra`. Developers branch on `type` to route dispute handling.
- D-06: Card/klarna/paypal/amazon_pay sub-objects inside `PaymentMethodDetails` stay as raw maps. ~4 flat string fields each, no sub-branching needed.
- D-07: `balance_transactions` list deserializes elements using existing `BalanceTransaction.from_map/1` via `Enum.map`. `charge` field uses `ObjectTypes.maybe_deserialize/1` for expand deserialization. Both types already exist.

**Close Verb Semantics**
- D-08: Function name is `Dispute.close/3` (and `close!/3`). Signature: `close(client, id, opts \\ [])` — no params map (Stripe endpoint takes no body parameters).
- D-09: `@doc` includes a dedicated `## Irreversibility` section for `close/3`.
- D-10: No runtime confirmation guards (no `:i_understand` atoms).
- D-11: `submit_evidence/3` gets the same `## Irreversibility` doc pattern with milder wording.

**Status Atomization**
- D-12: Private `defp atomize_status/1` with clauses for all 8 known Stripe dispute status values: `needs_response`, `warning_needs_response`, `under_review`, `warning_under_review`, `warning_closed`, `won`, `lost`, `charge_refunded`. String passthrough catch-all for forward compatibility.
- D-13: Private `defp atomize_reason/1` for ~14 known values: `fraudulent`, `duplicate`, `not_received`, `subscription_canceled`, `product_unacceptable`, `product_not_received`, `unrecognized`, `credit_not_processed`, `general`, `incorrect_account_details`, `insufficient_funds`, `bank_cannot_process`, `debit_not_authorized`, `customer_initiated`. Same passthrough pattern.
- D-14: No public `status_atom/1` or `reason_atom/1` functions — atomization happens at parse time in `from_map/1`.
- D-15: Unknown values pass through as strings via catch-all `defp atomize_status(other), do: other`.

### Claude's Discretion
- Internal `do_update/4` implementation details (header building, URL construction)
- `Dispute.Evidence` and `Dispute.EvidenceDetails` struct field ordering and `from_map/1` implementation
- `PaymentMethodDetails.from_map/1` parsing of polymorphic sub-objects
- Test organization and fixture helper naming within existing test structure
- ExDoc grouping placement for Dispute modules within the nine-group layout
- Custom `Inspect` implementation if any Dispute fields contain sensitive data

### Deferred Ideas (OUT OF SCOPE)
- `Builders.Dispute` changeset-style evidence builder
- `PaymentMethodDetails.Card` typed struct
- Deeper `three_d_secure` typing inside card
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DISP-01 | Developer can retrieve and list disputes with auto-pagination via `stream!/3` | Standard `retrieve/3`, `list/3`, `stream!/3` pattern confirmed; GET /v1/disputes and GET /v1/disputes/:id verified against Stripe API |
| DISP-02 | Developer can update dispute metadata via `Dispute.update/4` | POST /v1/disputes/:id accepts `metadata` key; shared via `do_update/4` private function |
| DISP-03 | Developer can close (accept) a dispute via explicit `Dispute.close/3` verb | POST /v1/disputes/:id/close endpoint verified; takes no body params; returns dispute with status `lost` |
| DISP-04 | Developer can stage evidence without submitting via `Dispute.update_evidence/4` (always `submit: false`) | POST /v1/disputes/:id with `submit: false` verified; wrapper wraps evidence map and forces submit false |
| DISP-05 | Developer can irreversibly submit evidence via `Dispute.submit_evidence/3` with clear warning | POST /v1/disputes/:id with `submit: true` verified; separate function with `## Irreversibility` doc section |
| DISP-06 | Dispute evidence deserializes into typed `Dispute.Evidence` struct with `@known_fields` | 27 evidence fields verified from Stripe API docs; struct pattern matches existing codebase conventions |
| DISP-07 | Dispute evidence details deserializes into typed `Dispute.EvidenceDetails` struct | `due_by`, `has_evidence`, `past_due`, `submission_count`, `enhanced_eligibility` fields verified |
</phase_requirements>

---

## Summary

Phase 33 implements the full Stripe dispute lifecycle as a new `LatticeStripe.Dispute` resource module. The implementation is almost entirely a pattern-application exercise — all core infrastructure (transport, retry, pagination, ObjectTypes dispatch, BalanceTransaction deserialization) already exists. The primary complexity is the three-way evidence API split (`update/4`, `update_evidence/4`, `submit_evidence/3`) that maps to a single shared `do_update/4` private function, and the typed nested struct graph (`Dispute.Evidence`, `Dispute.EvidenceDetails`, `Dispute.PaymentMethodDetails`).

The Stripe dispute API uses a single update endpoint (`POST /v1/disputes/:id`) for metadata changes, evidence staging, and evidence submission — differentiated only by the presence and value of the `submit` parameter. The `close` operation uses a separate endpoint (`POST /v1/disputes/:id/close`) with no body parameters. Both irreversible operations (`close/3` and `submit_evidence/3`) must carry `## Irreversibility` doc sections following the `Account.reject/4` precedent.

One API discrepancy to resolve: the CONTEXT.md D-12 lists `charge_refunded` as a status, and `prevented` was surfaced during research as a newer status. The implementation should include both in `atomize_status/1` with a passthrough catch-all for any future values.

**Primary recommendation:** Follow the `Refund` module as the closest structural analog — it has `cancel/3` as a separate verb, `atomize_status/1`, nested object handling via `ObjectTypes.maybe_deserialize/1`, and a custom `Inspect` implementation.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Dispute retrieve/list | API / Backend (SDK) | — | Pure Stripe API call; no client-side state |
| Evidence staging (`update_evidence/4`) | API / Backend (SDK) | — | Wraps POST /v1/disputes/:id with `submit: false` |
| Evidence submission (`submit_evidence/3`) | API / Backend (SDK) | — | Wraps POST /v1/disputes/:id with `submit: true`; irreversible bank action |
| Dispute close (`close/3`) | API / Backend (SDK) | — | POST /v1/disputes/:id/close; irreversible |
| Typed deserialization | SDK struct layer | — | `from_map/1` in each nested module; no I/O |
| Status/reason atomization | SDK struct layer | — | Private helper at parse time; no network |
| ObjectTypes registration | SDK registry | — | Add `"dispute"` to `object_types.ex` so expanded dispute objects deserialize correctly |

---

## Standard Stack

### Core — No New Dependencies

All dependencies for this phase already exist in the project. This phase uses zero new Hex packages.

| Existing Asset | Version | Role in This Phase |
|---------------|---------|-------------------|
| `Client.request/2` | — | All dispute HTTP calls (standard JSON path, no multipart needed) |
| `Resource.unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1` | — | Response unwrapping for all operations |
| `List.stream!/2` | — | Auto-pagination for `stream!/3` |
| `ObjectTypes.maybe_deserialize/1` | — | `charge` field expand deserialization |
| `BalanceTransaction.from_map/1` | — | `balance_transactions` list element deserialization |
| `Charge.from_map/1` | — | `charge` expand when `object: "charge"` |
| Mox | ~> 1.2 | Unit test transport mocking |
| ExUnit | stdlib | Test framework |

**Version verification:** No new packages — skip npm view step. [VERIFIED: existing project mix.exs]

---

## Architecture Patterns

### System Architecture Diagram

```
Developer call
     |
     v
Dispute.update/4  Dispute.update_evidence/4  Dispute.submit_evidence/3
     |                    |                          |
     |        (wraps: %{evidence: map,    (wraps: %{submit: true})
     |                  submit: false})              |
     +--------------------+--------------------------+
                          |
                          v
                   defp do_update(client, id, params, opts)
                          |
                          v
              POST /v1/disputes/:id
              (Client.request/2 -> Transport -> Finch -> Stripe)
                          |
                          v
              Resource.unwrap_singular(&Dispute.from_map/1)
                          |
                          v
                    %Dispute{
                      evidence: %Dispute.Evidence{},
                      evidence_details: %Dispute.EvidenceDetails{},
                      payment_method_details: %Dispute.PaymentMethodDetails{},
                      balance_transactions: [%BalanceTransaction{}, ...],
                      charge: %Charge{} | String.t(),
                      status: :needs_response | atom(),
                      reason: :fraudulent | atom()
                    }

Dispute.close/3
     |
     v
POST /v1/disputes/:id/close  (no body params)
     |
     v
Resource.unwrap_singular(&Dispute.from_map/1)
```

### Recommended Project Structure

```
lib/lattice_stripe/
├── dispute.ex                    # Main resource module (CRUD + verbs)
└── dispute/
    ├── evidence.ex               # %Dispute.Evidence{} — 27 fields
    ├── evidence_details.ex       # %Dispute.EvidenceDetails{} — 5 fields
    └── payment_method_details.ex # %Dispute.PaymentMethodDetails{} — type + 4 sub-maps

test/lattice_stripe/
└── dispute_test.exs              # All unit tests (Mox-based)

test/support/fixtures/
└── dispute.ex                    # dispute_json/1, dispute_evidence_json/1,
                                  # dispute_evidence_details_json/1
```

### Pattern 1: Three-Function Evidence API via Shared Private

**What:** Three public functions with distinct semantics share one private HTTP call.

**When to use:** When the same endpoint supports multiple behavioral modes that should be exposed as separate named functions to prevent misuse.

```elixir
# Source: CONTEXT.md D-01..D-04 (locked decisions)

def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
  do_update(client, id, params, opts)
end

def update_evidence(%Client{} = client, id, evidence, opts \\ []) when is_binary(id) do
  # Strip any stray :submit or "submit" key the caller may have included
  clean = Map.drop(evidence, ["submit", :submit])
  do_update(client, id, %{evidence: clean, submit: false}, opts)
end

def submit_evidence(%Client{} = client, id, opts \\ []) when is_binary(id) do
  do_update(client, id, %{submit: true}, opts)
end

defp do_update(%Client{} = client, id, params, opts) do
  %Request{method: :post, path: "/v1/disputes/#{id}", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

### Pattern 2: Separate-Endpoint Verb (close/3)

**What:** Irreversible action on a `/action` sub-endpoint with no body params.

**When to use:** When Stripe uses a separate URL path for a semantic action.

```elixir
# Source: CONTEXT.md D-08; pattern from Refund.cancel/4, Account.reject/4

def close(%Client{} = client, id, opts \\ []) when is_binary(id) do
  %Request{method: :post, path: "/v1/disputes/#{id}/close", params: %{}, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

### Pattern 3: Nested List Deserialization (balance_transactions)

**What:** Parse a list-object field into typed structs using `Enum.map`.

**When to use:** When a resource field is a list of typed objects (not a paginated `List` object).

```elixir
# Source: Invoice.parse_lines/1 at invoice.ex:1070-1079

defp parse_balance_transactions(nil), do: nil
defp parse_balance_transactions(list) when is_list(list) do
  Enum.map(list, &BalanceTransaction.from_map/1)
end
defp parse_balance_transactions(other), do: other
```

Note: `balance_transactions` on a dispute is returned as a plain JSON array (not wrapped in a Stripe `list` object), so `Enum.map` directly is correct — not the `parse_lines` pattern which handles the `%{"object" => "list"}` wrapper. [VERIFIED: Stripe API docs — dispute.balance_transactions is an array]

### Pattern 4: Status + Reason Atomization at Parse Time

**What:** Private clauses convert known string values to atoms in `from_map/1`.

**When to use:** Post-Phase 22 standard for all status/reason fields.

```elixir
# Source: Payout.atomize_status/1, Subscription.atomize_status/1

defp atomize_status("needs_response"),          do: :needs_response
defp atomize_status("warning_needs_response"),  do: :warning_needs_response
defp atomize_status("under_review"),            do: :under_review
defp atomize_status("warning_under_review"),    do: :warning_under_review
defp atomize_status("warning_closed"),          do: :warning_closed
defp atomize_status("won"),                     do: :won
defp atomize_status("lost"),                    do: :lost
defp atomize_status("charge_refunded"),         do: :charge_refunded
defp atomize_status("prevented"),               do: :prevented
defp atomize_status(other),                     do: other

defp atomize_reason("fraudulent"),              do: :fraudulent
defp atomize_reason("duplicate"),               do: :duplicate
defp atomize_reason("not_received"),            do: :not_received
defp atomize_reason("subscription_canceled"),   do: :subscription_canceled
defp atomize_reason("product_unacceptable"),    do: :product_unacceptable
defp atomize_reason("product_not_received"),    do: :product_not_received
defp atomize_reason("unrecognized"),            do: :unrecognized
defp atomize_reason("credit_not_processed"),    do: :credit_not_processed
defp atomize_reason("general"),                 do: :general
defp atomize_reason("incorrect_account_details"), do: :incorrect_account_details
defp atomize_reason("insufficient_funds"),      do: :insufficient_funds
defp atomize_reason("bank_cannot_process"),     do: :bank_cannot_process
defp atomize_reason("debit_not_authorized"),    do: :debit_not_authorized
defp atomize_reason("customer_initiated"),      do: :customer_initiated
defp atomize_reason("check_returned"),          do: :check_returned
defp atomize_reason("noncompliant"),            do: :noncompliant
defp atomize_reason(other),                     do: other
```

### Pattern 5: Irreversibility Doc Section

**What:** `## Irreversibility` callout in `@doc` for destructive operations.

**When to use:** Required for `close/3` and `submit_evidence/3` per CONTEXT.md D-09/D-11.

```elixir
# Source: Account.reject/4 @doc — established pattern

@doc """
Closes (accepts) a dispute, conceding it to the cardholder.

Sends `POST /v1/disputes/:id/close`.

## Irreversibility

Closing is irreversible. The dispute status changes to `lost` and the
disputed amount plus any dispute fees are permanently deducted from
your Stripe balance. This cannot be undone via the API or Stripe
Dashboard.
"""
```

### Anti-Patterns to Avoid

- **`submit: true` in `update_evidence/4`:** The entire point of `update_evidence/4` is safety. Must strip any `submit` key the caller passes before delegating to `do_update/4`. [VERIFIED: CONTEXT.md D-01]
- **Making `balance_transactions` a `%List{}`:** Stripe returns this as a plain JSON array on the dispute object, not a paginated list. Wrap with `parse_balance_transactions/1` + `Enum.map`, not `Resource.unwrap_list/2`. [VERIFIED: Stripe API docs]
- **Public `atomize_status/1`:** Post-Phase 22 policy prohibits public atomizer functions. Keep private, call at parse time only. [VERIFIED: CONTEXT.md D-14]
- **Body params in `close/3`:** The `POST /v1/disputes/:id/close` endpoint accepts no body parameters. Pass `params: %{}`. [VERIFIED: Stripe API docs]
- **Forgetting `object_types.ex` registration:** Without adding `"dispute"` to the `@object_map`, expanded dispute objects inside other resources will fall through to raw maps. This is an easy-to-miss task.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP retries | Custom retry loop | `Client.request/2` (uses `RetryStrategy.Default`) | Already handles `Stripe-Should-Retry` header, exponential backoff, idempotency |
| Auto-pagination | Manual cursor loop | `List.stream!/2 \|> Stream.map(&from_map/1)` | Already implemented; all resource modules use it |
| Expand deserialization | Custom type dispatch | `ObjectTypes.maybe_deserialize/1` | Registry-based; handles `charge`, `payment_intent`, etc. |
| Balance transaction parsing | Custom struct | `BalanceTransaction.from_map/1` | Already typed; reuse directly |
| Status string-to-atom | Runtime `String.to_atom/1` | `defp atomize_status/1` clauses | Avoid atom table exhaustion with unknown strings |

**Key insight:** Disputes are architecturally identical to Payouts and Refunds in terms of SDK implementation. The only novelty is the three-way evidence function split and the two irreversible-action doc patterns.

---

## Stripe API Reference — Verified Field Lists

### Dispute Object Top-Level Fields [VERIFIED: docs.stripe.com/api/disputes/object]

```
id, object, amount, balance_transactions, charge, created, currency,
enhanced_eligibility_types, evidence, evidence_details,
is_charge_refundable, livemode, metadata, payment_intent,
payment_method_details, reason, status
```

`@known_fields` for `Dispute`:
```elixir
@known_fields ~w[
  id object amount balance_transactions charge created currency
  enhanced_eligibility_types evidence evidence_details
  is_charge_refundable livemode metadata payment_intent
  payment_method_details reason status
]
```

### Dispute.Evidence Fields (27) [VERIFIED: docs.stripe.com/api/disputes/object]

All string values (file IDs for `*_file` fields, plain text for the rest):

```
access_activity_log
billing_address
cancellation_policy
cancellation_policy_disclosure
cancellation_rebuttal
customer_communication
customer_email_address
customer_name
customer_purchase_ip
customer_signature
duplicate_charge_documentation
duplicate_charge_explanation
duplicate_charge_id
enhanced_evidence
product_description
receipt
refund_policy
refund_policy_disclosure
refund_refusal_explanation
service_date
service_documentation
shipping_address
shipping_carrier
shipping_date
shipping_documentation
shipping_tracking_number
uncategorized_file
uncategorized_text
```

Note: `enhanced_evidence` is a nested object (Visa Compelling Evidence 3.0). Per D-06 spirit (sub-objects stay as raw maps for low-value sub-branching), this should remain a raw map unless user feedback demands promotion.

### Dispute.EvidenceDetails Fields [VERIFIED: docs.stripe.com/api/disputes/object]

```
due_by
has_evidence
past_due
submission_count
enhanced_eligibility  (nested object — raw map, same rationale as D-06)
```

`@known_fields` for `Dispute.EvidenceDetails`:
```elixir
@known_fields ~w[due_by has_evidence past_due submission_count enhanced_eligibility]
```

### Dispute.PaymentMethodDetails Fields [VERIFIED: docs.stripe.com/api/disputes/object]

```
type          (string: "card", "klarna", "paypal", "amazon_pay")
card          (nested object — raw map per D-06)
klarna        (nested object — raw map per D-06)
paypal        (nested object — raw map per D-06)
amazon_pay    (nested object — raw map per D-06)
```

`@known_fields` for `Dispute.PaymentMethodDetails`:
```elixir
@known_fields ~w[type card klarna paypal amazon_pay]
```

### Dispute Status Values [VERIFIED: dj-stripe/djstripe, Stripe docs search 2025]

`needs_response`, `warning_needs_response`, `under_review`, `warning_under_review`,
`warning_closed`, `won`, `lost`, `charge_refunded`, `prevented`

CONTEXT.md D-12 lists 8 values; research found a 9th (`prevented`) not in the CONTEXT. Both should be in `atomize_status/1`. [VERIFIED: multiple Stripe documentation sources]

### Dispute Reason Values [VERIFIED: docs.stripe.com/api/disputes/object]

`fraudulent`, `duplicate`, `product_not_received`, `product_unacceptable`,
`unrecognized`, `credit_not_processed`, `general`, `incorrect_account_details`,
`insufficient_funds`, `bank_cannot_process`, `debit_not_authorized`,
`customer_initiated`, `subscription_canceled`, `check_returned`, `noncompliant`

Note: CONTEXT.md D-13 lists `not_received` — the actual Stripe API uses `product_not_received`. The value `not_received` does not appear in the Stripe API reference. The reason atomizer should use `product_not_received` (matching D-13's intent) and add `check_returned` and `noncompliant` as they appear in current Stripe docs. [VERIFIED: docs.stripe.com/api/disputes/object first fetch]

---

## Common Pitfalls

### Pitfall 1: Missing `object_types.ex` Registration

**What goes wrong:** If `"dispute"` is not added to `ObjectTypes.@object_map`, any expanded dispute object nested inside another resource (e.g., a charge expanded with a dispute) will deserialize to a raw map instead of `%Dispute{}`. Tests for the dispute module itself pass, but cross-resource expand tests fail silently.

**Why it happens:** `object_types.ex` is a manual registry — it doesn't auto-discover new modules.

**How to avoid:** Add `"dispute" => LatticeStripe.Dispute` as a dedicated implementation task (not bundled into the main module task).

**Warning signs:** `ObjectTypes.maybe_deserialize/1` returning a raw map where a `%Dispute{}` is expected.

### Pitfall 2: `balance_transactions` is an Array, Not a List Object

**What goes wrong:** Using the `parse_lines/1` pattern from `Invoice` (which handles `%{"object" => "list", "data" => [...]}`) for the dispute's `balance_transactions` field, which is a plain JSON array `[...]`.

**Why it happens:** The Invoice `lines` field is a Stripe List object with pagination metadata. The dispute `balance_transactions` is a plain array with no pagination wrapper.

**How to avoid:** Use `defp parse_balance_transactions(list) when is_list(list), do: Enum.map(list, &BalanceTransaction.from_map/1)` — match on `is_list`, not on `%{"object" => "list"}`.

**Warning signs:** `Enum.map` failing with `%{"object" => "list", "data" => [...]}` as the input.

### Pitfall 3: `submit` Key Leakage in `update_evidence/4`

**What goes wrong:** If the developer passes `%{"submit" => true}` inside their evidence map, an unguarded `update_evidence/4` would forward it to `do_update/4`, making the call submit evidence when it should only stage.

**Why it happens:** The evidence parameter is a flat map — nothing prevents a caller from including `submit` inside it.

**How to avoid:** Explicitly strip both `"submit"` and `:submit` keys before wrapping: `clean = Map.drop(evidence, ["submit", :submit])`.

**Warning signs:** `update_evidence/4` submitting evidence to the bank in integration tests.

### Pitfall 4: Status `prevented` Not in Atomizer

**What goes wrong:** Stripe recently added a `prevented` dispute status (for disputes stopped by Radar/dispute prevention). If only the 8 statuses from D-12 are in `atomize_status/1`, `prevented` falls through to the catch-all as a string — inconsistent with the atom-based API.

**Why it happens:** CONTEXT.md D-12 was written before research confirmed `prevented` in current Stripe docs.

**How to avoid:** Add `defp atomize_status("prevented"), do: :prevented` alongside the D-12 list.

**Warning signs:** `dispute.status == "prevented"` (string) instead of `:prevented` (atom).

### Pitfall 5: `close/3` Sending a Non-Empty Body

**What goes wrong:** Following the `update/4` pattern and sending `params: params`, the `close` endpoint receives a body that Stripe may reject or silently ignore — either way it's incorrect behavior.

**Why it happens:** Mechanical copy-paste from other verb functions without checking endpoint docs.

**How to avoid:** Hard-code `params: %{}` in the `close/3` request. No params map parameter in the function signature.

---

## Code Examples

### Verified Pattern: `from_map/1` with Nested Struct Delegation

```elixir
# Source: Account.from_map/1 pattern (lib/lattice_stripe/account.ex:340-360)

def from_map(%{} = map) do
  {known, extra} = Map.split(map, @known_fields)

  %__MODULE__{
    id: known["id"],
    object: known["object"] || "dispute",
    amount: known["amount"],
    balance_transactions: parse_balance_transactions(known["balance_transactions"]),
    charge:
      (if is_map(known["charge"]),
        do: ObjectTypes.maybe_deserialize(known["charge"]),
        else: known["charge"]),
    created: known["created"],
    currency: known["currency"],
    enhanced_eligibility_types: known["enhanced_eligibility_types"],
    evidence: Evidence.from_map(known["evidence"]),
    evidence_details: EvidenceDetails.from_map(known["evidence_details"]),
    is_charge_refundable: known["is_charge_refundable"],
    livemode: known["livemode"],
    metadata: known["metadata"],
    payment_intent:
      (if is_map(known["payment_intent"]),
        do: ObjectTypes.maybe_deserialize(known["payment_intent"]),
        else: known["payment_intent"]),
    payment_method_details: PaymentMethodDetails.from_map(known["payment_method_details"]),
    reason: atomize_reason(known["reason"]),
    status: atomize_status(known["status"]),
    extra: extra
  }
end
```

### Verified Pattern: Nested Struct `from_map/1` (Evidence)

```elixir
# Source: Pattern from Account.Requirements.from_map/1 (lib/lattice_stripe/account/requirements.ex)

defmodule LatticeStripe.Dispute.Evidence do
  @known_fields ~w[
    access_activity_log billing_address cancellation_policy
    cancellation_policy_disclosure cancellation_rebuttal
    customer_communication customer_email_address customer_name
    customer_purchase_ip customer_signature duplicate_charge_documentation
    duplicate_charge_explanation duplicate_charge_id enhanced_evidence
    product_description receipt refund_policy refund_policy_disclosure
    refund_refusal_explanation service_date service_documentation
    shipping_address shipping_carrier shipping_date shipping_documentation
    shipping_tracking_number uncategorized_file uncategorized_text
  ]

  defstruct @known_fields ++ [:extra]

  def from_map(nil), do: nil
  def from_map(%{} = map) do
    {known, extra} = Map.split(map, @known_fields)
    struct(__MODULE__, Map.new(known, fn {k, v} -> {String.to_existing_atom(k), v} end)
      |> Map.put(:extra, extra))
  end
end
```

### Verified Pattern: Test Fixture Structure

```elixir
# Source: test/support/fixtures/refund.ex pattern

defmodule LatticeStripe.Test.Fixtures.Dispute do
  @moduledoc false

  def dispute_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "dp_test1234567890abc",
        "object" => "dispute",
        "amount" => 1000,
        "balance_transactions" => [],
        "charge" => "ch_test1234567890abc",
        "created" => 1_700_000_000,
        "currency" => "usd",
        "enhanced_eligibility_types" => [],
        "evidence" => dispute_evidence_json(),
        "evidence_details" => dispute_evidence_details_json(),
        "is_charge_refundable" => true,
        "livemode" => false,
        "metadata" => %{},
        "payment_intent" => "pi_test1234567890abc",
        "payment_method_details" => %{
          "type" => "card",
          "card" => %{"brand" => "visa", "network_reason_code" => "4853"}
        },
        "reason" => "fraudulent",
        "status" => "needs_response"
      },
      overrides
    )
  end

  def dispute_evidence_json(overrides \\ %{}) do
    Map.merge(
      %{
        "product_description" => nil,
        "customer_email_address" => nil,
        # ... all 27 fields nil by default
        "uncategorized_text" => nil
      },
      overrides
    )
  end

  def dispute_evidence_details_json(overrides \\ %{}) do
    Map.merge(
      %{
        "due_by" => 1_700_000_000,
        "has_evidence" => false,
        "past_due" => false,
        "submission_count" => 0,
        "enhanced_eligibility" => nil
      },
      overrides
    )
  end
end
```

---

## ExDoc Group Placement

The `Dispute` family of modules should be added to the `Payments` group in `mix.exs`, alongside `Refund` (disputes are the chargeback counterpart to refunds). [ASSUMED — the CONTEXT.md mentions "Payments group (disputes are payment-related)" but Claude's Discretion covers the exact placement]

Modules to add:
- `LatticeStripe.Dispute`
- `LatticeStripe.Dispute.Evidence`
- `LatticeStripe.Dispute.EvidenceDetails`
- `LatticeStripe.Dispute.PaymentMethodDetails`

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Public `status_atom/1` function | Private `atomize_status/1` at parse time | Phase 22 audit | Simpler API surface, atoms resolved at deserialization |
| Single `update/4` for evidence staging | Three-function split (`update/4`, `update_evidence/4`, `submit_evidence/3`) | Phase 33 design | Eliminates accidental evidence submission |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `prevented` is a current valid Stripe dispute status that should be in `atomize_status/1` | Code Examples, Pitfalls | Low — catch-all handles it as string; just less ergonomic |
| A2 | ExDoc group for Dispute modules is `Payments` | ExDoc Group Placement | Low — planner can verify against mix.exs and place correctly |
| A3 | `balance_transactions` on Dispute is a plain JSON array (not a Stripe List object) | Architecture Patterns | Medium — if wrong, `parse_balance_transactions/1` would need the `parse_lines` pattern instead |
| A4 | `enhanced_evidence` inside `Dispute.Evidence` and `enhanced_eligibility` inside `Dispute.EvidenceDetails` remain as raw maps | Architecture Patterns | Low — deferred; catch-all `extra` will still capture fields |

**Verified claims:** All Stripe API field names, endpoint URLs, and status/reason enums verified against official Stripe documentation during this research session.

---

## Open Questions

1. **`prevented` status in D-12**
   - What we know: D-12 lists 8 statuses; research found `prevented` in current Stripe docs/SDK enums
   - What's unclear: Whether D-12 was written before `prevented` was added to Stripe, or whether it was intentionally excluded
   - Recommendation: Add `prevented` to `atomize_status/1` alongside the D-12 list; the catch-all makes this safe either way

2. **`not_received` vs `product_not_received` in D-13**
   - What we know: D-13 lists `not_received` as a reason; Stripe API docs list `product_not_received`
   - What's unclear: Whether `not_received` was a historical Stripe value that still appears in some accounts
   - Recommendation: Include both `atomize_reason("not_received")` and `atomize_reason("product_not_received")` for maximum compatibility; the string catch-all handles any others

---

## Environment Availability

Step 2.6: SKIPPED — Phase 33 is a pure SDK resource module implementation with no external dependencies beyond the existing Stripe API (already integrated) and stripe-mock (already in CI infrastructure).

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/dispute_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DISP-01 | `retrieve/3` returns `{:ok, %Dispute{}}` | unit | `mix test test/lattice_stripe/dispute_test.exs` | ❌ Wave 0 |
| DISP-01 | `list/3` returns `{:ok, %Response{data: %List{}}}` | unit | `mix test test/lattice_stripe/dispute_test.exs` | ❌ Wave 0 |
| DISP-01 | `stream!/3` emits `%Dispute{}` structs | unit | `mix test test/lattice_stripe/dispute_test.exs` | ❌ Wave 0 |
| DISP-02 | `update/4` sends POST with metadata params | unit | `mix test test/lattice_stripe/dispute_test.exs` | ❌ Wave 0 |
| DISP-03 | `close/3` sends POST to `/close` with empty body | unit | `mix test test/lattice_stripe/dispute_test.exs` | ❌ Wave 0 |
| DISP-04 | `update_evidence/4` sends `submit: false`; strips any stray `submit` key | unit | `mix test test/lattice_stripe/dispute_test.exs` | ❌ Wave 0 |
| DISP-05 | `submit_evidence/3` sends `submit: true` with no evidence body | unit | `mix test test/lattice_stripe/dispute_test.exs` | ❌ Wave 0 |
| DISP-06 | `from_map/1` deserializes `evidence` into `%Dispute.Evidence{}` | unit | `mix test test/lattice_stripe/dispute_test.exs` | ❌ Wave 0 |
| DISP-07 | `from_map/1` deserializes `evidence_details` into `%Dispute.EvidenceDetails{}` | unit | `mix test test/lattice_stripe/dispute_test.exs` | ❌ Wave 0 |
| DISP-06/07 | status and reason atomized at parse time | unit | `mix test test/lattice_stripe/dispute_test.exs` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test test/lattice_stripe/dispute_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/lattice_stripe/dispute_test.exs` — all DISP-01..DISP-07 coverage
- [ ] `test/support/fixtures/dispute.ex` — `dispute_json/1`, `dispute_evidence_json/1`, `dispute_evidence_details_json/1`

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | API key handled by `Client` — no new auth surface |
| V3 Session Management | no | Stateless HTTP SDK |
| V4 Access Control | no | Stripe API key scopes enforce access server-side |
| V5 Input Validation | yes | Evidence map is user-supplied; `Map.drop` strips dangerous keys (`submit`) |
| V6 Cryptography | no | No new crypto; webhook HMAC already in `Webhook.Plug` |

### Known Threat Patterns for Dispute Operations

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Accidental evidence submission via `update_evidence/4` | Tampering | `Map.drop(evidence, ["submit", :submit])` in wrapper |
| Atom table exhaustion from unknown status strings | Denial of Service | `defp atomize_status(other), do: other` catch-all (no `String.to_atom/1`) |
| Irreversible close without intent | Tampering | Separate `close/3` function + `## Irreversibility` doc warning |

---

## Sources

### Primary (HIGH confidence)
- [Stripe Dispute Object](https://docs.stripe.com/api/disputes/object) — all top-level fields, Evidence fields (27), EvidenceDetails fields, PaymentMethodDetails structure, status and reason enum values
- [Stripe Update Dispute](https://docs.stripe.com/api/disputes/update) — `submit` parameter behavior, `evidence` sub-object, `metadata` parameter
- [Stripe Close Dispute](https://docs.stripe.com/api/disputes/close) — endpoint URL, no body params, returns dispute with `lost` status
- [Stripe List Disputes](https://docs.stripe.com/api/disputes/list) — filter parameters confirmed
- `lib/lattice_stripe/refund.ex` — canonical pattern for verb + atomize_status [VERIFIED: codebase read]
- `lib/lattice_stripe/account.ex` — `## Irreversibility` doc pattern, `reject/4` [VERIFIED: codebase read]
- `lib/lattice_stripe/object_types.ex` — current registry, `"dispute"` not yet present [VERIFIED: codebase read]
- `lib/lattice_stripe/invoice.ex` — `parse_lines/1` nested list pattern [VERIFIED: codebase read]
- `mix.exs` — ExDoc group structure, nine-group layout [VERIFIED: codebase read]

### Secondary (MEDIUM confidence)
- [dj-stripe enums.py](https://github.com/dj-stripe/dj-stripe/blob/master/djstripe/enums.py) — confirms `charge_refunded` as valid dispute status; confirms `prevented` as valid status
- [Stripe How Disputes Work](https://docs.stripe.com/disputes/how-disputes-work) — `late_win` mentioned as rare additional status

### Tertiary (LOW confidence)
- Web search results for `prevented` status — multiple sources agree it is current

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; all reuse existing infrastructure
- Architecture: HIGH — verified against Stripe API docs and existing codebase patterns
- Dispute API fields: HIGH — verified directly from docs.stripe.com/api/disputes/object
- Pitfalls: HIGH — derived from code reading of existing modules and API docs
- Status enum completeness: MEDIUM — `prevented` confirmed via secondary sources; `charge_refunded` confirmed via dj-stripe

**Research date:** 2026-04-17
**Valid until:** 2026-05-17 (Stripe API is stable; dispute object fields rarely change)
