# Phase 33: Disputes - Pattern Map

**Mapped:** 2026-04-17
**Files analyzed:** 7 new files (5 source, 1 test, 1 fixture)
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/lattice_stripe/dispute.ex` | resource module | request-response + CRUD | `lib/lattice_stripe/refund.ex` | exact |
| `lib/lattice_stripe/dispute/evidence.ex` | nested struct | transform | `lib/lattice_stripe/account/requirements.ex` | exact |
| `lib/lattice_stripe/dispute/evidence_details.ex` | nested struct | transform | `lib/lattice_stripe/account/requirements.ex` | exact |
| `lib/lattice_stripe/dispute/payment_method_details.ex` | nested struct | transform | `lib/lattice_stripe/account/requirements.ex` | role-match |
| `lib/lattice_stripe/object_types.ex` | registry config | — | self (modify existing) | — |
| `test/lattice_stripe/dispute_test.exs` | test | request-response | `test/lattice_stripe/refund_test.exs` | exact |
| `test/support/fixtures/dispute.ex` | test fixture | — | `test/support/fixtures/refund.ex` | exact |

---

## Pattern Assignments

### `lib/lattice_stripe/dispute.ex` (resource module, request-response + CRUD)

**Analog:** `lib/lattice_stripe/refund.ex`

**Imports pattern** (refund.ex lines 63):
```elixir
alias LatticeStripe.{Client, Error, List, ObjectTypes, Request, Resource, Response}
```
Dispute will also alias the three nested sub-modules:
```elixir
alias LatticeStripe.Dispute.{Evidence, EvidenceDetails, PaymentMethodDetails}
alias LatticeStripe.{BalanceTransaction, Client, Error, List, ObjectTypes, Request, Resource, Response}
```

**`@known_fields` and `defstruct` pattern** (refund.ex lines 68-96):
```elixir
@known_fields ~w[
  id object amount balance_transactions charge created currency
  enhanced_eligibility_types evidence evidence_details
  is_charge_refundable livemode metadata payment_intent
  payment_method_details reason status
]

defstruct [
  :id,
  :amount,
  :balance_transactions,
  :charge,
  :created,
  :currency,
  :enhanced_eligibility_types,
  :evidence,
  :evidence_details,
  :is_charge_refundable,
  :livemode,
  :metadata,
  :payment_intent,
  :payment_method_details,
  :reason,
  :status,
  object: "dispute",
  extra: %{}
]
```

**Standard retrieve/update/list/stream! pattern** (refund.ex lines 186-302):
```elixir
@spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
  %Request{method: :get, path: "/v1/disputes/#{id}", params: %{}, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end

@spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
  do_update(client, id, params, opts)
end

@spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
def list(%Client{} = client, params \\ %{}, opts \\ []) do
  %Request{method: :get, path: "/v1/disputes", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_list(&from_map/1)
end

@spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
  req = %Request{method: :get, path: "/v1/disputes", params: params, opts: opts}
  List.stream!(client, req) |> Stream.map(&from_map/1)
end
```

**Three-function evidence API via shared private** (CONTEXT.md D-01..D-04):
```elixir
def update_evidence(%Client{} = client, id, evidence, opts \\ []) when is_binary(id) do
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

**Irreversible verb pattern — close/3** (refund.ex lines 240-244, account.ex lines 285-291):
```elixir
# Pattern from Refund.cancel/4 — sub-endpoint with no required body params
# Doc must include ## Irreversibility section per Account.reject/4 precedent

def close(%Client{} = client, id, opts \\ []) when is_binary(id) do
  %Request{method: :post, path: "/v1/disputes/#{id}/close", params: %{}, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

**Bang variants pattern** (refund.ex lines 308-347):
```elixir
@spec retrieve!(Client.t(), String.t(), keyword()) :: t()
def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
  retrieve(client, id, opts) |> Resource.unwrap_bang!()
end

@spec update!(Client.t(), String.t(), map(), keyword()) :: t()
def update!(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
  update(client, id, params, opts) |> Resource.unwrap_bang!()
end

# Same pattern for update_evidence!, submit_evidence!, close!, list!
```

**`from_map/1` with nested delegation and conditional expand** (refund.ex lines 369-400):
```elixir
@spec from_map(map()) :: t()
def from_map(map) when is_map(map) do
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

**`parse_balance_transactions/1` private helper** (invoice.ex lines 1070-1079 adapted — plain array, not List object):
```elixir
# NOTE: dispute.balance_transactions is a plain JSON array [], NOT a Stripe List
# object %{"object" => "list", ...}. Use Enum.map directly — do NOT use the
# parse_lines/1 pattern from Invoice which wraps a %{"object" => "list"} shape.
defp parse_balance_transactions(nil), do: nil
defp parse_balance_transactions(list) when is_list(list) do
  Enum.map(list, &BalanceTransaction.from_map/1)
end
defp parse_balance_transactions(other), do: other
```

**`atomize_status/1` pattern** (subscription.ex lines 527-535, payout.ex lines 441-446):
```elixir
defp atomize_status("needs_response"),         do: :needs_response
defp atomize_status("warning_needs_response"), do: :warning_needs_response
defp atomize_status("under_review"),           do: :under_review
defp atomize_status("warning_under_review"),   do: :warning_under_review
defp atomize_status("warning_closed"),         do: :warning_closed
defp atomize_status("won"),                    do: :won
defp atomize_status("lost"),                   do: :lost
defp atomize_status("charge_refunded"),        do: :charge_refunded
defp atomize_status("prevented"),              do: :prevented
defp atomize_status(other),                    do: other
```

**`atomize_reason/1` pattern** (same convention as atomize_status, see payout.ex):
```elixir
defp atomize_reason("fraudulent"),                do: :fraudulent
defp atomize_reason("duplicate"),                 do: :duplicate
defp atomize_reason("not_received"),              do: :not_received
defp atomize_reason("product_not_received"),      do: :product_not_received
defp atomize_reason("subscription_canceled"),     do: :subscription_canceled
defp atomize_reason("product_unacceptable"),      do: :product_unacceptable
defp atomize_reason("unrecognized"),              do: :unrecognized
defp atomize_reason("credit_not_processed"),      do: :credit_not_processed
defp atomize_reason("general"),                   do: :general
defp atomize_reason("incorrect_account_details"), do: :incorrect_account_details
defp atomize_reason("insufficient_funds"),        do: :insufficient_funds
defp atomize_reason("bank_cannot_process"),       do: :bank_cannot_process
defp atomize_reason("debit_not_authorized"),      do: :debit_not_authorized
defp atomize_reason("customer_initiated"),        do: :customer_initiated
defp atomize_reason("check_returned"),            do: :check_returned
defp atomize_reason("noncompliant"),              do: :noncompliant
defp atomize_reason(other),                       do: other
```

**`Inspect` implementation** (refund.ex lines 414-437):
```elixir
defimpl Inspect, for: LatticeStripe.Dispute do
  import Inspect.Algebra

  def inspect(dispute, opts) do
    fields = [
      id: dispute.id,
      object: dispute.object,
      amount: dispute.amount,
      currency: dispute.currency,
      status: dispute.status,
      reason: dispute.reason
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Dispute<" | pairs] ++ [">"])
  end
end
```

**`## Irreversibility` doc section** (account.ex lines 276-281):
```elixir
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

---

### `lib/lattice_stripe/dispute/evidence.ex` (nested struct, transform)

**Analog:** `lib/lattice_stripe/account/requirements.ex`

**Full module pattern** (requirements.ex lines 1-67):
```elixir
defmodule LatticeStripe.Dispute.Evidence do
  @moduledoc """
  The evidence submitted for a Stripe Dispute.

  Contains up to 27 string fields — file IDs for `*_file` fields,
  plain text for all others. Unknown fields are preserved in `:extra`
  per the F-001 forward-compatibility pattern.

  See [Stripe Dispute Evidence](https://docs.stripe.com/api/disputes/object).
  """

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

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)
    known_atoms = Map.new(known, fn {k, v} -> {String.to_existing_atom(k), v} end)
    struct(__MODULE__, Map.merge(known_atoms, %{extra: extra}))
  end
end
```

---

### `lib/lattice_stripe/dispute/evidence_details.ex` (nested struct, transform)

**Analog:** `lib/lattice_stripe/account/requirements.ex`

**Pattern** (requirements.ex lines 20-66 — same `@known_fields` + `defstruct` + `from_map/1` shape):
```elixir
defmodule LatticeStripe.Dispute.EvidenceDetails do
  @known_fields ~w[due_by has_evidence past_due submission_count enhanced_eligibility]

  defstruct @known_fields ++ [:extra]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)
    known_atoms = Map.new(known, fn {k, v} -> {String.to_existing_atom(k), v} end)
    struct(__MODULE__, Map.merge(known_atoms, %{extra: extra}))
  end
end
```

---

### `lib/lattice_stripe/dispute/payment_method_details.ex` (nested struct, transform)

**Analog:** `lib/lattice_stripe/account/requirements.ex`

**Pattern** — same shape; `card`/`klarna`/`paypal`/`amazon_pay` remain raw maps per D-06:
```elixir
defmodule LatticeStripe.Dispute.PaymentMethodDetails do
  @known_fields ~w[type card klarna paypal amazon_pay]

  defstruct @known_fields ++ [:extra]

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)
    known_atoms = Map.new(known, fn {k, v} -> {String.to_existing_atom(k), v} end)
    struct(__MODULE__, Map.merge(known_atoms, %{extra: extra}))
  end
end
```

---

### `lib/lattice_stripe/object_types.ex` (registry config — modify existing)

**Analog:** self

**Modification:** Add one entry to `@object_map` after `"file_link"` (lines 16-17):
```elixir
# Current (object_types.ex lines 4-39):
@object_map %{
  ...
  "file"                     => LatticeStripe.File,
  "file_link"                => LatticeStripe.FileLink,
  # ADD THIS LINE:
  "dispute"                  => LatticeStripe.Dispute,
  ...
}
```
Exact placement: alphabetically after `"customer"` or grouped with payment-related types near `"charge"`. Convention in the file is not strictly alphabetical — insert after `"file_link"` to keep the block visually intact, or after `"charge"` to group by payment semantics. Either is acceptable.

---

### `test/lattice_stripe/dispute_test.exs` (test, request-response)

**Analog:** `test/lattice_stripe/refund_test.exs`

**Module header pattern** (refund_test.exs lines 1-11):
```elixir
defmodule LatticeStripe.DisputeTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.Dispute

  alias LatticeStripe.{Dispute, Error, List, Response}

  setup :verify_on_exit!
```

**Standard test block pattern for retrieve** (refund_test.exs lines 79-95):
```elixir
describe "retrieve/3" do
  test "sends GET /v1/disputes/:id and returns {:ok, %Dispute{}}" do
    client = test_client()

    expect(LatticeStripe.MockTransport, :request, fn req ->
      assert req.method == :get
      assert String.ends_with?(req.url, "/v1/disputes/dp_test1234567890abc")
      ok_response(dispute_json())
    end)

    assert {:ok, %Dispute{id: "dp_test1234567890abc"}} =
             Dispute.retrieve(client, "dp_test1234567890abc")
  end
end
```

**Test for update_evidence/4 submit-key stripping** (new — no direct analog, but follows Mox pattern):
```elixir
describe "update_evidence/4" do
  test "strips stray submit key and sends submit: false" do
    client = test_client()

    expect(LatticeStripe.MockTransport, :request, fn req ->
      assert req.method == :post
      assert String.ends_with?(req.url, "/v1/disputes/dp_test1234567890abc")
      # submit must be false regardless of what caller passed
      assert req.body =~ "submit=false"
      refute req.body =~ "submit=true"
      ok_response(dispute_json())
    end)

    assert {:ok, %Dispute{}} =
             Dispute.update_evidence(client, "dp_test1234567890abc",
               %{"product_description" => "Widget", "submit" => true})
  end
end
```

**Test for close/3 empty body** (follows refund cancel pattern):
```elixir
describe "close/3" do
  test "sends POST /v1/disputes/:id/close with empty body" do
    client = test_client()

    expect(LatticeStripe.MockTransport, :request, fn req ->
      assert req.method == :post
      assert String.ends_with?(req.url, "/v1/disputes/dp_test1234567890abc/close")
      ok_response(dispute_json(%{"status" => "lost"}))
    end)

    assert {:ok, %Dispute{status: :lost}} =
             Dispute.close(client, "dp_test1234567890abc")
  end
end
```

---

### `test/support/fixtures/dispute.ex` (test fixture)

**Analog:** `test/support/fixtures/refund.ex`

**Full module pattern** (refund.ex lines 1-36):
```elixir
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
        "access_activity_log" => nil,
        "billing_address" => nil,
        "cancellation_policy" => nil,
        "cancellation_policy_disclosure" => nil,
        "cancellation_rebuttal" => nil,
        "customer_communication" => nil,
        "customer_email_address" => nil,
        "customer_name" => nil,
        "customer_purchase_ip" => nil,
        "customer_signature" => nil,
        "duplicate_charge_documentation" => nil,
        "duplicate_charge_explanation" => nil,
        "duplicate_charge_id" => nil,
        "enhanced_evidence" => nil,
        "product_description" => nil,
        "receipt" => nil,
        "refund_policy" => nil,
        "refund_policy_disclosure" => nil,
        "refund_refusal_explanation" => nil,
        "service_date" => nil,
        "service_documentation" => nil,
        "shipping_address" => nil,
        "shipping_carrier" => nil,
        "shipping_date" => nil,
        "shipping_documentation" => nil,
        "shipping_tracking_number" => nil,
        "uncategorized_file" => nil,
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

## Shared Patterns

### Request-Response Pipeline
**Source:** `lib/lattice_stripe/refund.ex` lines 164-166
**Apply to:** All HTTP operations in `dispute.ex`
```elixir
%Request{method: :post, path: "/v1/disputes/#{id}", params: params, opts: opts}
|> then(&Client.request(client, &1))
|> Resource.unwrap_singular(&from_map/1)
```

### Bang Variant via `unwrap_bang!/1`
**Source:** `lib/lattice_stripe/refund.ex` lines 313-315
**Apply to:** Every public function gets a `!` variant
```elixir
def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
  retrieve(client, id, opts) |> Resource.unwrap_bang!()
end
```

### `@known_fields` + `defstruct` + `from_map/1` + `extra: %{}`
**Source:** `lib/lattice_stripe/refund.ex` lines 68-96, `lib/lattice_stripe/account/requirements.ex` lines 20-66
**Apply to:** All new struct modules (`dispute.ex`, `evidence.ex`, `evidence_details.ex`, `payment_method_details.ex`)

### Private Atomization at Parse Time (post-Phase 22 standard)
**Source:** `lib/lattice_stripe/subscription.ex` lines 527-535, `lib/lattice_stripe/payout.ex` lines 441-446
**Apply to:** `dispute.ex` `from_map/1` for `status` and `reason` fields
- NO public `atomize_status/1` — keep private
- Catch-all `defp atomize_status(other), do: other` required (no `String.to_atom/1`)

### `ObjectTypes.maybe_deserialize/1` for Expanded Fields
**Source:** `lib/lattice_stripe/refund.ex` lines 378-383
**Apply to:** `dispute.ex` `from_map/1` for `charge` and `payment_intent` fields
```elixir
charge:
  (if is_map(known["charge"]),
    do: ObjectTypes.maybe_deserialize(known["charge"]),
    else: known["charge"]),
```

### `Inspect` Protocol Implementation
**Source:** `lib/lattice_stripe/refund.ex` lines 414-437
**Apply to:** `dispute.ex` (outside the module, after the closing `end`)
- Show only: `id`, `object`, `amount`, `currency`, `status`, `reason`
- Hide: `charge`, `payment_intent`, `metadata`, `evidence` (may contain PII/sensitive data)

### ExDoc Payments Group
**Source:** `mix.exs` lines 62-68
**Apply to:** `mix.exs` `groups_for_modules`
Add to the `Payments:` list after `LatticeStripe.Refund`:
```elixir
LatticeStripe.Dispute,
LatticeStripe.Dispute.Evidence,
LatticeStripe.Dispute.EvidenceDetails,
LatticeStripe.Dispute.PaymentMethodDetails,
```

---

## No Analog Found

All files have close analogs. No new patterns need to be invented.

---

## Critical Anti-Patterns (copy these guards verbatim)

| Anti-Pattern | Guard | Source |
|---|---|---|
| `submit: true` leaking through `update_evidence/4` | `clean = Map.drop(evidence, ["submit", :submit])` | CONTEXT.md D-01 |
| Body params in `close/3` | `params: %{}` hardcoded, no `params` argument | CONTEXT.md D-08 |
| `balance_transactions` as List object | `is_list(list)` guard, not `%{"object" => "list"}` | RESEARCH.md Pitfall 2 |
| Public `atomize_status/1` | Keep `defp` — no public export | CONTEXT.md D-14 |
| `String.to_atom/1` in catch-all | `defp atomize_status(other), do: other` passthrough | CONTEXT.md D-15 |
| Missing `object_types.ex` registration | Add `"dispute" => LatticeStripe.Dispute` | RESEARCH.md Pitfall 1 |

---

## Metadata

**Analog search scope:** `lib/lattice_stripe/`, `test/lattice_stripe/`, `test/support/fixtures/`
**Files scanned:** 12 source files, 4 fixture files, 1 test file
**Pattern extraction date:** 2026-04-17
