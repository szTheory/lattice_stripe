---
phase: 18
plan: 03
type: execute
wave: 2
depends_on: [18-01]
files_modified:
  - lib/lattice_stripe/transfer.ex
  - lib/lattice_stripe/transfer_reversal.ex
  - test/lattice_stripe/transfer_test.exs
  - test/lattice_stripe/transfer_reversal_test.exs
  - test/support/fixtures/transfer_fixtures.ex
  - test/support/fixtures/transfer_reversal_fixtures.ex
autonomous: true
requirements: [CNCT-02, CNCT-03]
tags: [connect, transfer, transfer-reversal, crudl]

must_haves:
  truths:
    - "Developer can create/retrieve/update/list/stream Transfers via LatticeStripe.Transfer with full bang variants"
    - "Developer can create/retrieve/update/list/stream TransferReversals as a top-level standalone module addressed by (transfer_id, reversal_id)"
    - "Transfer does NOT define a reverse/4 delegator (D-02 locked)"
    - "Transfer.from_map/1 decodes the embedded reversals.data sublist into [%TransferReversal{}], stashing has_more/url/total_count into :extra"
    - "TransferReversal calls require_param!/3 on transfer_id (and reversal_id where present) pre-network"
  artifacts:
    - path: "lib/lattice_stripe/transfer.ex"
      provides: "%Transfer{} struct + create/3 + retrieve/3 + update/4 + list/3 + stream!/3 + bang variants + from_map/1"
      contains: "defmodule LatticeStripe.Transfer"
    - path: "lib/lattice_stripe/transfer_reversal.ex"
      provides: "%TransferReversal{} struct + (client, transfer_id, ...) addressed CRUDL + bang variants + from_map/1"
      contains: "defmodule LatticeStripe.TransferReversal"
  key_links:
    - from: "lib/lattice_stripe/transfer.ex"
      to: "lib/lattice_stripe/transfer_reversal.ex"
      via: "Transfer.from_map/1 calls TransferReversal.from_map/1 on each entry of the embedded reversals.data sublist"
      pattern: "TransferReversal.from_map"
    - from: "lib/lattice_stripe/transfer_reversal.ex"
      to: "/v1/transfers/:transfer/reversals/:id"
      via: "Request{path: \"/v1/transfers/#{transfer_id}/reversals/#{reversal_id}\"}"
      pattern: "/v1/transfers/.*reversals"
---

<objective>
Ship `LatticeStripe.Transfer` (full CRUDL) and `LatticeStripe.TransferReversal` (standalone top-level module) per D-02. Closes the Transfer half of CNCT-02 and supports the separate-charge-and-transfer narrative in CNCT-03.

D-02 locks: NO `reverse/4` delegator on `Transfer`. Users reach for `TransferReversal.create/4`. Mirrors P17 `AccountLink`/`LoginLink` precedent and stripe-java's top-level `TransferReversal` class.

Depends on Plan 18-01 only because the Transfer test fixture for `reversals.data` references TransferReversal — but TransferReversal lives in this same plan, so this is technically self-contained. The 18-01 dependency is for `BankAccount.cast/1` which may be needed when expanding `Transfer.destination_payment` references in Wave 4 integration tests; declared explicitly to keep waves clean.

Output: 2 source files, 2 unit test files, 2 fixture modules.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/18-connect-money-movement/18-CONTEXT.md
@.planning/phases/18-connect-money-movement/18-RESEARCH.md
@lib/lattice_stripe/refund.ex
@lib/lattice_stripe/account_link.ex
@lib/lattice_stripe/customer.ex
@lib/lattice_stripe/resource.ex
@lib/lattice_stripe/list.ex

<interfaces>
From lib/lattice_stripe/resource.ex:
```elixir
def unwrap_singular({:ok, %Response{data: data}}, fun)
def unwrap_list({:ok, %Response{data: %List{} = list}} = resp_tuple, fun)
def unwrap_bang!({:ok, value}) | def unwrap_bang!({:error, %Error{} = err})
def require_param!(params, key, message \\ nil)
```

From lib/lattice_stripe/list.ex:
```elixir
def stream!(%Client{} = client, %Request{} = req)  # returns Enumerable
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: TransferReversal standalone module</name>
  <files>lib/lattice_stripe/transfer_reversal.ex, test/lattice_stripe/transfer_reversal_test.exs, test/support/fixtures/transfer_reversal_fixtures.ex</files>
  <read_first>
    - lib/lattice_stripe/account_link.ex (standalone sub-resource template; copy structure)
    - lib/lattice_stripe/refund.ex (CRUDL shape, especially update/4 with id)
    - lib/lattice_stripe/customer.ex (F-001 + defstruct shape)
    - lib/lattice_stripe/resource.ex (require_param!/3, unwrap_singular/2)
    - .planning/phases/18-connect-money-movement/18-RESEARCH.md "Stripe API Contract → Transfer Reversals" section
  </read_first>
  <behavior>
    - TransferReversal.create(client, "tr_123", %{amount: 500}) builds POST /v1/transfers/tr_123/reversals and returns {:ok, %TransferReversal{}}
    - TransferReversal.create(client, "", %{}) raises ArgumentError pre-network (transfer_id required)
    - TransferReversal.retrieve(client, "tr_123", "trr_456") builds GET /v1/transfers/tr_123/reversals/trr_456
    - TransferReversal.retrieve(client, "tr_123", "") raises ArgumentError pre-network (reversal_id required)
    - TransferReversal.update(client, "tr_123", "trr_456", %{metadata: %{"k" => "v"}}) builds POST /v1/transfers/tr_123/reversals/trr_456
    - TransferReversal.list(client, "tr_123") builds GET /v1/transfers/tr_123/reversals and returns %Response{data: %List{data: [%TransferReversal{}, ...]}}
    - TransferReversal.stream!(client, "tr_123") yields %TransferReversal{} structs lazily
    - All bang variants raise on {:error, %Error{}}
    - from_map/1 decodes all known fields, unknown into :extra
    - from_map(nil) returns nil
  </behavior>
  <action>
**Create `lib/lattice_stripe/transfer_reversal.ex`** as a standalone top-level module per D-02.

`@known_fields` (copy verbatim from RESEARCH.md):
```
~w[
  id object amount balance_transaction created currency
  destination_payment_refund metadata source_refund transfer
]
```

`defstruct` lists every field with `object: "transfer_reversal"` default and `extra: %{}`. Add `@typedoc` and `@type t :: %__MODULE__{...}`.

**Required signatures (every one with `@spec`):**

```elixir
@spec create(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def create(%Client{} = client, transfer_id, params, opts \\ []) when is_binary(transfer_id) do
  Resource.require_param!(%{"transfer_id" => transfer_id}, "transfer_id",
    ~s|TransferReversal.create/4 requires a non-empty transfer id|)
  %Request{method: :post, path: "/v1/transfers/#{transfer_id}/reversals", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end

def create!(client, transfer_id, params, opts \\ [])

@spec retrieve(Client.t(), String.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def retrieve(client, transfer_id, reversal_id, opts \\ [])
def retrieve!(client, transfer_id, reversal_id, opts \\ [])

@spec update(Client.t(), String.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def update(client, transfer_id, reversal_id, params, opts \\ [])
def update!(client, transfer_id, reversal_id, params, opts \\ [])

@spec list(Client.t(), String.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
def list(client, transfer_id, params \\ %{}, opts \\ [])
def list!(client, transfer_id, params \\ %{}, opts \\ [])

@spec stream!(Client.t(), String.t(), map(), keyword()) :: Enumerable.t()
def stream!(%Client{} = client, transfer_id, params \\ %{}, opts \\ []) when is_binary(transfer_id) do
  req = %Request{method: :get, path: "/v1/transfers/#{transfer_id}/reversals", params: params, opts: opts}
  List.stream!(client, req) |> Stream.map(&from_map/1)
end
```

**`require_param!/3` calls:**
- `create/4`: validate `transfer_id` non-empty
- `retrieve/4`: validate both `transfer_id` and `reversal_id`
- `update/5`: validate both
- `list/4` + `stream!/4`: validate `transfer_id`

`from_map/1` follows F-001 — explicit field mapping, `Map.drop(map, @known_fields)` for `:extra`, `from_map(nil) -> nil`.

**No `defimpl Inspect`** — TransferReversal carries no PII (per RESEARCH.md PII table line 421).

**Tests** (`test/lattice_stripe/transfer_reversal_test.exs`) using `TransportMock`:
- describe "create/4": happy path asserts POST path `/v1/transfers/tr_test/reversals`; empty/nil transfer_id raises ArgumentError pre-network
- describe "retrieve/4": asserts GET path `/v1/transfers/tr_test/reversals/trr_test`; missing reversal_id raises ArgumentError
- describe "update/5": asserts POST path with both ids; metadata in params
- describe "list/4": returns wrapped `%Response{data: %List{data: [%TransferReversal{}]}}`
- describe "stream!/4": yields TransferReversal structs lazily
- describe "from_map/1": F-001 round-trip with synthetic future field
- describe "bang variants": each raises on `{:error, %Error{}}`

**Fixture** (`test/support/fixtures/transfer_reversal_fixtures.ex`):
`LatticeStripe.Test.Fixtures.TransferReversal` with `basic/1`, `list_response/1`. Realistic IDs (`"trr_1OoMpqJ2eZvKYlo20wxYzAbC"`, `"tr_1OoMnpJ2eZvKYlo21fGhIjKl"`).
  </action>
  <verify>
    <automated>mix test test/lattice_stripe/transfer_reversal_test.exs --exclude integration</automated>
  </verify>
  <acceptance_criteria>
    - `lib/lattice_stripe/transfer_reversal.ex` contains `defmodule LatticeStripe.TransferReversal` and `def create(` and `def retrieve(` and `def update(` and `def list(` and `def stream!(` and `def from_map(`
    - `grep -q '/v1/transfers/.*reversals' lib/lattice_stripe/transfer_reversal.ex` succeeds
    - `grep -q 'require_param!' lib/lattice_stripe/transfer_reversal.ex` succeeds (must validate transfer_id and reversal_id)
    - `! grep -q 'Jason.Encoder' lib/lattice_stripe/transfer_reversal.ex`
    - `mix test test/lattice_stripe/transfer_reversal_test.exs` exits 0
    - `mix credo --strict lib/lattice_stripe/transfer_reversal.ex` exits 0
  </acceptance_criteria>
  <done>TransferReversal standalone module ships with full CRUDL + bang variants + stream! + (transfer_id, reversal_id) addressing + pre-network param validation; tests cover all six public functions plus error paths.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Transfer CRUDL with embedded reversals.data sublist decoding</name>
  <files>lib/lattice_stripe/transfer.ex, test/lattice_stripe/transfer_test.exs, test/support/fixtures/transfer_fixtures.ex</files>
  <read_first>
    - lib/lattice_stripe/transfer_reversal.ex (just created in Task 1 — Transfer.from_map calls TransferReversal.from_map for nested reversals.data)
    - lib/lattice_stripe/refund.ex (canonical CRUDL template)
    - lib/lattice_stripe/customer.ex (F-001 + defstruct)
    - .planning/phases/18-connect-money-movement/18-RESEARCH.md "Stripe API Contract → Transfers" section (verbatim @known_fields list)
  </read_first>
  <behavior>
    - Transfer.create(client, %{amount: 1000, currency: "usd", destination: "acct_123"}) builds POST /v1/transfers
    - Transfer.retrieve(client, "tr_123") builds GET /v1/transfers/tr_123 returns {:ok, %Transfer{}}
    - Transfer.update(client, "tr_123", %{metadata: %{}}) builds POST /v1/transfers/tr_123
    - Transfer.list(client, %{destination: "acct_123"}) returns wrapped %Response{data: %List{data: [%Transfer{}, ...]}}
    - Transfer.stream!(client) yields %Transfer{} structs lazily
    - Transfer.from_map decodes the embedded reversals sublist: reversals.data → [%TransferReversal{}], with reversals.has_more/reversals.url/reversals.total_count stashed under :extra (NOT lost)
    - Transfer module does NOT define reverse/3 or reverse/4 (D-02 prohibition)
    - Bang variants raise on errors
    - require_param! is called on id where present
  </behavior>
  <action>
**Create `lib/lattice_stripe/transfer.ex`** following the `Refund` template.

`@known_fields` (copy verbatim from RESEARCH.md Stripe API Contract → Transfers):
```
~w[
  id object amount amount_reversed balance_transaction created currency
  description destination destination_payment livemode metadata reversals
  reversed source_transaction source_type transfer_group
]
```

`defstruct` with `object: "transfer"` default, `extra: %{}`. Add `@typedoc` and `@type t`.

**Public functions** (every one with `@spec`):
```elixir
def create(client, params, opts \\ [])    # POST /v1/transfers
def create!(client, params, opts \\ [])
def retrieve(client, id, opts \\ [])      # GET /v1/transfers/:id
def retrieve!(client, id, opts \\ [])
def update(client, id, params, opts \\ []) # POST /v1/transfers/:id
def update!(client, id, params, opts \\ [])
def list(client, params \\ %{}, opts \\ []) # GET /v1/transfers
def list!(client, params \\ %{}, opts \\ [])
def stream!(client, params \\ %{}, opts \\ [])
```

**MUST NOT define** `reverse/3` or `reverse/4`. Test asserts `refute function_exported?(LatticeStripe.Transfer, :reverse, 3)` and `refute function_exported?(LatticeStripe.Transfer, :reverse, 4)`. Moduledoc explicitly points users to `LatticeStripe.TransferReversal.create/4` for reversals.

**Per D-04 / P15 D5: NO client-side validation of `Transfer.create` params beyond what the standard CRUDL does.** Stripe's 400 flows through as `{:error, %Error{}}`. Do NOT pre-validate `amount`/`currency`/`destination`.

**`from_map/1`** — explicit known-field mapping, BUT with one special case for `reversals` (per D-02):

```elixir
def from_map(map) when is_map(map) do
  raw_reversals = map["reversals"] || %{}
  reversal_structs =
    case raw_reversals do
      %{"data" => data} when is_list(data) ->
        Enum.map(data, &LatticeStripe.TransferReversal.from_map/1)
      _ ->
        []
    end

  # The sublist wrapper (has_more, url, total_count) goes into :extra under a namespaced key
  reversals_meta = Map.drop(raw_reversals, ["data"])

  base_extra = Map.drop(map, @known_fields)
  extra = if map_size(reversals_meta) > 0,
    do: Map.put(base_extra, "reversals_meta", reversals_meta),
    else: base_extra

  %__MODULE__{
    id: map["id"],
    object: map["object"] || "transfer",
    amount: map["amount"],
    # ... every other known field explicitly
    reversals: reversal_structs,
    extra: extra
  }
end

def from_map(nil), do: nil
```

The `reversals` field on `%Transfer{}` is therefore typed as `[TransferReversal.t()]` (not a `%List{}` struct). Document this in `@typedoc` and moduledoc.

**No PII Inspect** — Transfer carries no PII per RESEARCH.md PII table line 421 (uses default Inspect).

**Tests** (`test/lattice_stripe/transfer_test.exs`) using `TransportMock`:
- describe "create/3": POST /v1/transfers; multi-field params (amount/currency/destination); no client-side validation (bare %{} doesn't raise — Stripe 400 surfaces as {:error, %Error{}})
- describe "retrieve/3": GET /v1/transfers/tr_test
- describe "update/4": POST /v1/transfers/tr_test
- describe "list/3": with destination filter; returns wrapped Response{data: List{data: [Transfer]}}
- describe "stream!/3": yields Transfer structs lazily
- describe "from_map/1 reversals decoding":
  - Fixture with reversals: %{data: [...3 reversals...], has_more: false, url: "...", total_count: 3}
  - Assert `transfer.reversals` is `[%TransferReversal{}, %TransferReversal{}, %TransferReversal{}]` (a plain list)
  - Assert `transfer.extra["reversals_meta"]` contains `"has_more"`, `"url"`, `"total_count"`
  - Assert NO data loss: round-trip preserves all sublist metadata
- describe "from_map/1 with empty reversals": `reversals: nil` or `reversals: %{"data" => []}` returns `[]`
- describe "module surface": `refute function_exported?(LatticeStripe.Transfer, :reverse, 3)`, same for arity 4
- describe "F-001": unknown future field survives in :extra

**Fixture** (`test/support/fixtures/transfer_fixtures.ex`):
`LatticeStripe.Test.Fixtures.Transfer` with `basic/1`, `with_reversals/1` (3 embedded reversals + sublist wrapper), `list_response/1`. IDs like `"tr_1OoMnpJ2eZvKYlo21fGhIjKl"`, `"acct_1Nv0FGQ9RKHgCVdK"`.
  </action>
  <verify>
    <automated>mix test test/lattice_stripe/transfer_test.exs --exclude integration</automated>
  </verify>
  <acceptance_criteria>
    - `lib/lattice_stripe/transfer.ex` contains `defmodule LatticeStripe.Transfer` and `def create(` and `def retrieve(` and `def update(` and `def list(` and `def stream!(` and `def from_map(`
    - `! grep -qE 'def reverse[!]?\(' lib/lattice_stripe/transfer.ex` (D-02 enforcement)
    - `grep -q 'TransferReversal.from_map' lib/lattice_stripe/transfer.ex` succeeds (embedded sublist decoding)
    - `grep -q 'reversals_meta' lib/lattice_stripe/transfer.ex` succeeds (sublist wrapper preservation)
    - `! grep -q 'Jason.Encoder' lib/lattice_stripe/transfer.ex`
    - `mix test test/lattice_stripe/transfer_test.exs` exits 0
    - `mix credo --strict lib/lattice_stripe/transfer.ex` exits 0
    - `mix compile --warnings-as-errors` exits 0
  </acceptance_criteria>
  <done>Transfer CRUDL ships, embedded reversals sublist correctly decoded into [%TransferReversal{}] with metadata preserved, no reverse/4 delegator (D-02 enforced by test), F-001 round-trip verified.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| LatticeStripe ↔ Stripe API | `Transfer.create` is a money-moving operation; idempotency keys (auto-generated by Client) must reuse the same key on retry to prevent double transfers |
| Plan boundary ↔ Transfer.reverse expectations | If a delegator slips in, it would fork the API surface and confuse users |
| Embedded sublist ↔ paginated list | `Transfer.reversals.data` looks like a `%List{}` but is NOT — treating it as paginated would crash on missing cursors |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-18-10 | T (Tampering) / R (Repudiation) | `Transfer.create` double-execution on retry | mitigate | `Client.request/2` already auto-generates idempotency keys for mutating requests and reuses them across retries (Phase 2 RTRY-03 shipped); Transfer plan adds NO new code path that could break this. Documented in moduledoc with explicit "use idempotency_key opt for at-least-once safety in failure recovery" example |
| T-18-11 | T (Tampering) | Embedded reversals sublist decoded as paginated List | mitigate | `Transfer.from_map/1` explicitly extracts `reversals.data` as a plain list and stashes wrapper metadata in `:extra["reversals_meta"]`; tests assert `transfer.reversals` is `[%TransferReversal{}]` not `%List{}` |
| T-18-12 | E (Elevation of privilege) | Accidental Transfer.reverse delegator added later | mitigate | D-02 prohibition enforced by `refute function_exported?(LatticeStripe.Transfer, :reverse, _)` test + `! grep -qE 'def reverse[!]?\(' lib/lattice_stripe/transfer.ex` acceptance criterion |
| T-18-13 | I (Information disclosure) | Transfer logging (no PII) | accept | Transfer object carries no customer PII per RESEARCH.md PII table line 421; default Inspect is acceptable |
| T-18-14 | T (Tampering) | TransferReversal pre-network param validation gap | mitigate | `require_param!/3` called on `transfer_id` in every public fn and on `reversal_id` in `retrieve`/`update`; tests assert `ArgumentError` on empty/nil ids before any HTTP I/O |
</threat_model>

<verification>
- `mix test test/lattice_stripe/transfer_test.exs test/lattice_stripe/transfer_reversal_test.exs --exclude integration` exits 0
- `mix compile --warnings-as-errors` exits 0
- `mix credo --strict lib/lattice_stripe/transfer.ex lib/lattice_stripe/transfer_reversal.ex` exits 0
- Acceptance-criteria grep guards all pass
- Pattern test: a hand-crafted Transfer fixture with 3 embedded reversals decodes to `transfer.reversals = [%TransferReversal{}, %TransferReversal{}, %TransferReversal{}]` AND `transfer.extra["reversals_meta"]["total_count"] == 3`
</verification>

<success_criteria>
- `LatticeStripe.Transfer` ships full CRUDL + stream + bang variants
- `LatticeStripe.TransferReversal` ships as standalone top-level module with `(transfer_id, reversal_id)` addressing
- Transfer carries NO `reverse/4` delegator (D-02 enforced by test)
- Embedded `reversals.data` sublist decoded into `[%TransferReversal{}]` with wrapper metadata preserved
- Both modules pass `mix credo --strict` and `mix compile --warnings-as-errors`
- Plan 04 (Payout) and Plan 05 (Balance) are unblocked because they live in independent paths
</success_criteria>

<output>
After completion, create `.planning/phases/18-connect-money-movement/18-03-SUMMARY.md`
</output>
