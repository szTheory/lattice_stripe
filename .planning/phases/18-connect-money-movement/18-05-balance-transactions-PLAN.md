---
phase: 18
plan: 05
type: execute
wave: 3
depends_on: [18-03, 18-04]
files_modified:
  - lib/lattice_stripe/balance.ex
  - lib/lattice_stripe/balance/amount.ex
  - lib/lattice_stripe/balance/source_types.ex
  - lib/lattice_stripe/balance_transaction.ex
  - lib/lattice_stripe/balance_transaction/fee_detail.ex
  - test/lattice_stripe/balance_test.exs
  - test/lattice_stripe/balance/amount_test.exs
  - test/lattice_stripe/balance/source_types_test.exs
  - test/lattice_stripe/balance_transaction_test.exs
  - test/lattice_stripe/balance_transaction/fee_detail_test.exs
  - test/support/fixtures/balance_fixtures.ex
  - test/support/fixtures/balance_transaction_fixtures.ex
  - test/support/fixtures/balance_transaction_fee_detail_fixtures.ex
autonomous: true
requirements: [CNCT-04, CNCT-05]
tags: [connect, balance, balance-transaction, reconciliation, fee-detail, singleton]

must_haves:
  truths:
    - "Developer can call Balance.retrieve(client) to fetch the platform balance"
    - "Developer can call Balance.retrieve(client, stripe_account: \"acct_123\") to fetch a connected account's balance — the per-request stripe_account opt threads through to the Stripe-Account header"
    - "Balance.Amount struct is reused 5x inside %Balance{} (available, pending, connect_reserved, instant_available, issuing.available)"
    - "Balance.SourceTypes is embedded inside every Balance.Amount and uses typed-inner-open-outer (P17 D-02): stable inner {card, bank_account, fpx} + :extra for future payment-method keys"
    - "Developer can list BalanceTransactions filtered by payout, source, type, currency, created"
    - "BalanceTransaction.FeeDetail carries the {amount, currency, description, type, application} shape so reconciliation code can filter `&(&1.type == \"application_fee\")`"
    - "Balance has no id, no list, no create/update/delete (singleton); BalanceTransaction has no create/update/delete (Stripe-managed)"
  artifacts:
    - path: "lib/lattice_stripe/balance.ex"
      provides: "%Balance{} struct + retrieve/2 + retrieve!/2 + from_map/1 (singleton)"
      contains: "defmodule LatticeStripe.Balance"
    - path: "lib/lattice_stripe/balance/amount.ex"
      provides: "%Balance.Amount{amount, currency, source_types} nested typed struct + cast/1"
      contains: "defmodule LatticeStripe.Balance.Amount"
    - path: "lib/lattice_stripe/balance/source_types.ex"
      provides: "%Balance.SourceTypes{card, bank_account, fpx} typed-inner-open-outer + cast/1"
      contains: "defmodule LatticeStripe.Balance.SourceTypes"
    - path: "lib/lattice_stripe/balance_transaction.ex"
      provides: "%BalanceTransaction{} struct + retrieve/3 + list/3 + stream!/3 + bang variants + from_map/1"
      contains: "defmodule LatticeStripe.BalanceTransaction"
    - path: "lib/lattice_stripe/balance_transaction/fee_detail.ex"
      provides: "%BalanceTransaction.FeeDetail{amount, currency, description, type, application} nested typed struct + cast/1"
      contains: "defmodule LatticeStripe.BalanceTransaction.FeeDetail"
  key_links:
    - from: "lib/lattice_stripe/balance.ex"
      to: "/v1/balance"
      via: "Request{method: :get, path: \"/v1/balance\"} piped through Client.request/2"
      pattern: "/v1/balance"
    - from: "lib/lattice_stripe/balance.ex"
      to: "lib/lattice_stripe/client.ex stripe_account opts override"
      via: "opts[:stripe_account] threads through Client.build_headers as Stripe-Account header (already wired)"
      pattern: "stripe_account"
    - from: "lib/lattice_stripe/balance_transaction.ex"
      to: "lib/lattice_stripe/balance_transaction/fee_detail.ex"
      via: "BalanceTransaction.from_map calls Enum.map on fee_details with FeeDetail.cast/1"
      pattern: "FeeDetail.cast"
---

<objective>
Ship the Balance singleton and the BalanceTransaction list/retrieve resource per D-05. Closes CNCT-05 (Balance + BalanceTransactions) and finishes the typed surface for CNCT-04 (platform fee reconciliation via `BalanceTransaction.fee_details`).

D-05 locks 4 nested struct modules in this plan: `Balance.Amount` (reused 5×), `Balance.SourceTypes` (embedded inside every Amount), `BalanceTransaction.FeeDetail`. `Payout.TraceId` was shipped in Plan 18-04.

`Balance.retrieve/2` is a singleton with no id. The per-request `stripe_account:` opt is the ONLY way to retrieve a connected account's balance — guide and moduledoc must show this prominently to mitigate Pitfall 2 (silent wrong-answer bug).

Depends on Plans 18-03 (Transfer) and 18-04 (Payout) for wave-ordering hygiene because Wave 4 integration tests filter `BalanceTransaction.list` by `payout: po.id` and walk reconciliation back to `Charge` (Plan 18-02).

Output: 5 source files, 5 unit test files, 3 fixture modules.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/18-connect-money-movement/18-CONTEXT.md
@.planning/phases/18-connect-money-movement/18-RESEARCH.md
@lib/lattice_stripe/refund.ex
@lib/lattice_stripe/account/capability.ex
@lib/lattice_stripe/customer.ex
@lib/lattice_stripe/resource.ex
@lib/lattice_stripe/list.ex
@lib/lattice_stripe/client.ex

<interfaces>
From lib/lattice_stripe/account/capability.ex (canonical nested struct template — `~w()a` atom sigil):
```elixir
@known_fields ~w(status requested ...)a
defstruct @known_fields ++ [extra: %{}]
def cast(nil), do: nil
def cast(map) when is_map(map) do
  known_string_keys = Enum.map(@known_fields, &Atom.to_string/1)
  {known, extra} = Map.split(map, known_string_keys)
  struct(__MODULE__, status: known["status"], ..., extra: extra)
end
```

From lib/lattice_stripe/client.ex (stripe_account threading — VERIFIED already wired):
```elixir
# opts[:stripe_account] is honored per-request and added as "stripe-account" header
# build_headers/5 + maybe_add_stripe_account/2 (lines 388-427)
# Phase 17 Plan 01 added a regression test for this — Phase 18 makes ZERO Client changes
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Balance singleton + Balance.Amount + Balance.SourceTypes nested structs</name>
  <files>lib/lattice_stripe/balance.ex, lib/lattice_stripe/balance/amount.ex, lib/lattice_stripe/balance/source_types.ex, test/lattice_stripe/balance_test.exs, test/lattice_stripe/balance/amount_test.exs, test/lattice_stripe/balance/source_types_test.exs, test/support/fixtures/balance_fixtures.ex</files>
  <read_first>
    - lib/lattice_stripe/account/capability.ex (full file — nested struct template with `~w()a` atom sigil)
    - lib/lattice_stripe/customer.ex (top-level F-001 + defstruct shape for Balance singleton)
    - lib/lattice_stripe/refund.ex (retrieve/3 shape — Balance.retrieve/2 is similar but takes opts in position 2 instead of id)
    - lib/lattice_stripe/resource.ex (unwrap_singular/2, unwrap_bang!/1)
    - .planning/phases/18-connect-money-movement/18-RESEARCH.md "Stripe API Contract → Balance" section (verbatim @known_fields)
  </read_first>
  <behavior>
    - Balance.retrieve(client) builds GET /v1/balance and returns {:ok, %Balance{}} with platform balance
    - Balance.retrieve(client, stripe_account: "acct_123") threads stripe_account: opts through to the Stripe-Account header — the resulting %Balance{} is the connected account's balance
    - Balance.retrieve!(client) returns bare %Balance{} on success, raises on error
    - Balance has NO id field (singleton)
    - Balance.from_map decodes available, pending, connect_reserved, instant_available into [%Balance.Amount{}] each
    - Balance.from_map decodes issuing.available into [%Balance.Amount{}] (issuing is a map containing available[])
    - Balance.Amount.cast(%{"amount" => 1000, "currency" => "usd", "source_types" => %{...}}) returns %Balance.Amount{amount: 1000, currency: "usd", source_types: %Balance.SourceTypes{...}}
    - Balance.Amount preserves net_available (from instant_available[]) into :extra (per D-05 rule 1)
    - Balance.SourceTypes.cast preserves unknown payment-method keys (e.g., "ach_credit_transfer") into :extra (typed-inner-open-outer P17 D-02)
    - Module surface: NO Balance.list/1, Balance.create/2, Balance.update/3, Balance.delete/2 — only retrieve/2 and retrieve!/2 and from_map/1
  </behavior>
  <action>
**Create `lib/lattice_stripe/balance/source_types.ex`** following the typed-inner-open-outer pattern (P17 D-02), Account.Capability nested struct shape:

```elixir
defmodule LatticeStripe.Balance.SourceTypes do
  @moduledoc """
  Source-type breakdown of a `LatticeStripe.Balance.Amount`.

  Stable inner shape: `card`, `bank_account`, `fpx`. Future Stripe payment-method
  keys land in `:extra` per the typed-inner-open-outer pattern.
  """

  @known_fields ~w(card bank_account fpx)a
  defstruct @known_fields ++ [extra: %{}]

  @typedoc "Source-type breakdown of a Balance.Amount."
  @type t :: %__MODULE__{
          card: integer() | nil,
          bank_account: integer() | nil,
          fpx: integer() | nil,
          extra: map()
        }

  @doc false
  def cast(nil), do: nil
  def cast(map) when is_map(map) do
    known_string_keys = Enum.map(@known_fields, &Atom.to_string/1)
    {known, extra} = Map.split(map, known_string_keys)
    struct(__MODULE__,
      card: known["card"],
      bank_account: known["bank_account"],
      fpx: known["fpx"],
      extra: extra
    )
  end
end
```

**Create `lib/lattice_stripe/balance/amount.ex`** following the same pattern, embedding SourceTypes:

```elixir
defmodule LatticeStripe.Balance.Amount do
  @moduledoc """
  A single currency-denominated amount in a Stripe Balance.

  This module is REUSED 5× inside `%LatticeStripe.Balance{}` — `available[]`,
  `pending[]`, `connect_reserved[]`, `instant_available[]`, and `issuing.available[]`
  all decode to lists of `%Balance.Amount{}`.

  `net_available` (which only appears under `instant_available[]`) lands in `:extra`
  so this single module covers all five call-sites.
  """

  alias LatticeStripe.Balance.SourceTypes

  @known_fields ~w(amount currency source_types)a
  defstruct @known_fields ++ [extra: %{}]

  @typedoc "A Balance amount in a single currency."
  @type t :: %__MODULE__{
          amount: integer() | nil,
          currency: String.t() | nil,
          source_types: SourceTypes.t() | nil,
          extra: map()
        }

  @doc false
  def cast(nil), do: nil
  def cast(map) when is_map(map) do
    known_string_keys = Enum.map(@known_fields, &Atom.to_string/1)
    {known, extra} = Map.split(map, known_string_keys)
    struct(__MODULE__,
      amount: known["amount"],
      currency: known["currency"],
      source_types: SourceTypes.cast(known["source_types"]),
      extra: extra  # net_available lands here from instant_available[]
    )
  end
end
```

**Create `lib/lattice_stripe/balance.ex`** as a singleton resource:

```elixir
defmodule LatticeStripe.Balance do
  @moduledoc """
  Stripe Balance singleton.

  `Balance.retrieve(client)` fetches the **platform** balance.
  `Balance.retrieve(client, stripe_account: "acct_123")` fetches the **connected
  account's** balance via the per-request `Stripe-Account` header — this is the
  ONLY distinction between the two reads.

  Reconciliation code that walks every connected account in a loop MUST pass the
  `stripe_account:` opt on each call; calling `Balance.retrieve(client)` with no
  opts inside such a loop returns the platform balance every time and silently
  produces wrong reconciliation totals.

  ## Examples

      # Platform balance
      {:ok, balance} = LatticeStripe.Balance.retrieve(client)

      # Connected account balance
      {:ok, balance} = LatticeStripe.Balance.retrieve(client, stripe_account: "acct_123")

      # Read available USD balance
      [usd] = Enum.filter(balance.available, &(&1.currency == "usd"))
      IO.puts("Available USD: #{usd.amount}")

      # Read source-type breakdown
      IO.puts("From cards: #{usd.source_types.card}")

  ## Stripe API Reference

  https://docs.stripe.com/api/balance
  """

  alias LatticeStripe.{Client, Error, Request, Resource, Response}
  alias LatticeStripe.Balance.Amount

  @known_fields ~w[
    object available connect_reserved instant_available issuing livemode pending
  ]

  defstruct [
    :available,
    :connect_reserved,
    :instant_available,
    :issuing,
    :livemode,
    :pending,
    object: "balance",
    extra: %{}
  ]

  @typedoc "A Stripe Balance object."
  @type t :: %__MODULE__{
          object: String.t(),
          available: [Amount.t()] | nil,
          pending: [Amount.t()] | nil,
          connect_reserved: [Amount.t()] | nil,
          instant_available: [Amount.t()] | nil,
          issuing: map() | nil,
          livemode: boolean() | nil,
          extra: map()
        }

  @spec retrieve(Client.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, opts \\ []) do
    %Request{method: :get, path: "/v1/balance", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @spec retrieve!(Client.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, opts \\ []) do
    client |> retrieve(opts) |> Resource.unwrap_bang!()
  end

  @doc false
  def from_map(nil), do: nil
  def from_map(map) when is_map(map) do
    cast_amount_list = fn list when is_list(list) -> Enum.map(list, &Amount.cast/1)
                          nil -> nil end
    issuing =
      case map["issuing"] do
        %{"available" => avail} = iss when is_list(avail) ->
          Map.put(iss, "available", Enum.map(avail, &Amount.cast/1))
        other ->
          other
      end

    %__MODULE__{
      object: map["object"] || "balance",
      available: cast_amount_list.(map["available"]),
      pending: cast_amount_list.(map["pending"]),
      connect_reserved: cast_amount_list.(map["connect_reserved"]),
      instant_available: cast_amount_list.(map["instant_available"]),
      issuing: issuing,
      livemode: map["livemode"],
      extra: Map.drop(map, @known_fields)
    }
  end
end
```

**MUST NOT define** `list/1`, `create/2`, `update/3`, `delete/2`. Tests assert these are NOT exported.

**Tests** — three files:

`test/lattice_stripe/balance/source_types_test.exs`:
- describe "cast/1": happy path with all three known fields populated
- describe "cast/1": nil returns nil
- describe "cast/1": unknown payment-method keys (e.g., `"ach_credit_transfer" => 5000`) preserved in :extra (typed-inner-open-outer)
- describe "F-001 round-trip"

`test/lattice_stripe/balance/amount_test.exs`:
- describe "cast/1": happy path with amount, currency, source_types populated; source_types decoded to %SourceTypes{}
- describe "cast/1": nil source_types returns nil source_types
- describe "cast/1": net_available (from instant_available[]) lands in :extra
- describe "cast/1": nil returns nil
- describe "F-001"

`test/lattice_stripe/balance_test.exs` using TransportMock:
- describe "retrieve/2": GET /v1/balance, returns {:ok, %Balance{}}
- describe "retrieve/2 with stripe_account opt": **asserts the captured request opts include `stripe_account: "acct_123"`** so the Client header threading is exercised end-to-end (not just at the Client layer)
- describe "retrieve!/2": bang variant raises on error
- describe "from_map/1": decodes available/pending/connect_reserved/instant_available into [%Balance.Amount{}]
- describe "from_map/1 issuing": `issuing.available` decoded into [%Balance.Amount{}]
- describe "from_map/1 reuse proof": Balance.Amount module is the same struct in all 5 call-sites (assert via `match?(%Balance.Amount{}, hd(balance.available))` etc.)
- describe "module surface": `refute function_exported?(LatticeStripe.Balance, :list, 1)`, same for `:create/2`, `:update/3`, `:delete/2`. Verify NO `id` field exists: `refute Map.has_key?(%LatticeStripe.Balance{}, :id)`
- describe "F-001"

**Fixture** (`test/support/fixtures/balance_fixtures.ex`):
`LatticeStripe.Test.Fixtures.Balance` with `basic/1` (multi-currency, all 4 amount lists populated, issuing.available populated, source_types card/bank_account/fpx with at least one extra key for forward-compat test).
  </action>
  <verify>
    <automated>mix test test/lattice_stripe/balance_test.exs test/lattice_stripe/balance/amount_test.exs test/lattice_stripe/balance/source_types_test.exs --exclude integration</automated>
  </verify>
  <acceptance_criteria>
    - `lib/lattice_stripe/balance.ex` contains `defmodule LatticeStripe.Balance` and `def retrieve(` and `def retrieve!(` and `def from_map(`
    - `! grep -qE 'def (list|create|update|delete)\(' lib/lattice_stripe/balance.ex`
    - `! grep -q ':id' lib/lattice_stripe/balance.ex` (no id field on the singleton struct definition — verify defstruct contents don't include `:id`)
    - `lib/lattice_stripe/balance/amount.ex` contains `defmodule LatticeStripe.Balance.Amount` and `def cast(`
    - `lib/lattice_stripe/balance/source_types.ex` contains `defmodule LatticeStripe.Balance.SourceTypes` and `def cast(`
    - `grep -q '/v1/balance' lib/lattice_stripe/balance.ex` succeeds
    - `grep -q 'Amount.cast' lib/lattice_stripe/balance.ex` succeeds
    - `grep -q 'SourceTypes.cast' lib/lattice_stripe/balance/amount.ex` succeeds
    - `! grep -q 'Jason.Encoder' lib/lattice_stripe/balance.ex`
    - `! grep -q 'Jason.Encoder' lib/lattice_stripe/balance/amount.ex`
    - `! grep -q 'Jason.Encoder' lib/lattice_stripe/balance/source_types.ex`
    - `mix test test/lattice_stripe/balance_test.exs test/lattice_stripe/balance/amount_test.exs test/lattice_stripe/balance/source_types_test.exs` exits 0
    - `mix credo --strict lib/lattice_stripe/balance.ex lib/lattice_stripe/balance/amount.ex lib/lattice_stripe/balance/source_types.ex` exits 0
  </acceptance_criteria>
  <done>Balance singleton ships with no id and no list/create/update/delete; Balance.Amount reused 5x verified by tests; Balance.SourceTypes typed-inner-open-outer pattern verified; stripe_account opt threading exercised end-to-end.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: BalanceTransaction retrieve+list+stream + FeeDetail nested struct</name>
  <files>lib/lattice_stripe/balance_transaction.ex, lib/lattice_stripe/balance_transaction/fee_detail.ex, test/lattice_stripe/balance_transaction_test.exs, test/lattice_stripe/balance_transaction/fee_detail_test.exs, test/support/fixtures/balance_transaction_fixtures.ex, test/support/fixtures/balance_transaction_fee_detail_fixtures.ex</files>
  <read_first>
    - lib/lattice_stripe/balance/amount.ex (just created in Task 1 — same nested struct shape applies to FeeDetail)
    - lib/lattice_stripe/account/capability.ex (canonical nested struct template)
    - lib/lattice_stripe/refund.ex (retrieve/3 + list/3 + stream!/3 — copy verbatim minus create/update/delete)
    - lib/lattice_stripe/customer.ex (F-001 + defstruct)
    - .planning/phases/18-connect-money-movement/18-RESEARCH.md "Stripe API Contract → Balance Transactions" section (verbatim @known_fields + filter list)
  </read_first>
  <behavior>
    - BalanceTransaction.retrieve(client, "txn_123") builds GET /v1/balance_transactions/txn_123
    - BalanceTransaction.retrieve!(client, "txn_123") raises on error
    - BalanceTransaction.retrieve(client, "") raises ArgumentError pre-network
    - BalanceTransaction.list(client, %{payout: "po_123"}) builds GET /v1/balance_transactions with the payout filter
    - BalanceTransaction.list/3 supports filters: payout, source, type, currency, created (no client-side validation — pass-through)
    - BalanceTransaction.stream!(client, %{payout: "po_123"}) yields BalanceTransaction structs lazily
    - BalanceTransaction.from_map decodes fee_details into [%FeeDetail{}] via Enum.map
    - BalanceTransaction.from_map keeps source as raw `binary | map()` (no polymorphic typing per D-05 rule 5)
    - FeeDetail.cast(%{"amount" => 30, "currency" => "usd", "type" => "application_fee", ...}) returns %FeeDetail{...}
    - Reconciliation pattern works: `Enum.filter(bt.fee_details, &(&1.type == "application_fee"))` returns matching FeeDetail structs
    - Module surface: NO BalanceTransaction.create/2, update/3, delete/2 (Stripe-managed, server-side only)
  </behavior>
  <action>
**Create `lib/lattice_stripe/balance_transaction/fee_detail.ex`** following the Account.Capability nested struct template:

```elixir
defmodule LatticeStripe.BalanceTransaction.FeeDetail do
  @moduledoc """
  A single fee line on a Stripe BalanceTransaction.

  Reconciliation code typically filters by `type` to extract platform fees:

      application_fees =
        Enum.filter(bt.fee_details, &(&1.type == "application_fee"))

  Stripe's known `type` enum values: `"application_fee"`, `"stripe_fee"`,
  `"payment_method_passthrough_fee"`, `"tax"`, `"withheld_tax"`. The field is
  typed as `String.t()` to stay forward-compatible with new fee categories.
  """

  @known_fields ~w(amount application currency description type)a
  defstruct @known_fields ++ [extra: %{}]

  @typedoc "A fee line on a Stripe BalanceTransaction."
  @type t :: %__MODULE__{
          amount: integer() | nil,
          application: String.t() | nil,
          currency: String.t() | nil,
          description: String.t() | nil,
          type: String.t() | nil,
          extra: map()
        }

  @doc false
  def cast(nil), do: nil
  def cast(map) when is_map(map) do
    known_string_keys = Enum.map(@known_fields, &Atom.to_string/1)
    {known, extra} = Map.split(map, known_string_keys)
    struct(__MODULE__,
      amount: known["amount"],
      application: known["application"],
      currency: known["currency"],
      description: known["description"],
      type: known["type"],
      extra: extra
    )
  end
end
```

**Create `lib/lattice_stripe/balance_transaction.ex`** following the Refund template MINUS create/update/delete:

`@known_fields` (copy verbatim from RESEARCH.md):
```
~w[
  id object amount available_on created currency description exchange_rate
  fee fee_details net reporting_category source status type
]
```

`defstruct` with `object: "balance_transaction"` default, `extra: %{}`. Add `@typedoc` and `@type t` (note: `fee_details: [FeeDetail.t()] | nil`, `source: String.t() | map() | nil`).

**Public functions** (every with `@spec`):
```elixir
def retrieve(client, id, opts \\ [])  # GET /v1/balance_transactions/:id
def retrieve!(client, id, opts \\ [])
def list(client, params \\ %{}, opts \\ [])  # GET /v1/balance_transactions
def list!(client, params \\ %{}, opts \\ [])
def stream!(client, params \\ %{}, opts \\ [])
```

**MUST NOT define** `create/2`, `update/3`, `delete/2`. Tests assert these are NOT exported.

`from_map/1` — explicit field mapping with one special case for `fee_details`:

```elixir
def from_map(map) when is_map(map) do
  fee_details =
    case map["fee_details"] do
      list when is_list(list) -> Enum.map(list, &LatticeStripe.BalanceTransaction.FeeDetail.cast/1)
      _ -> nil
    end

  %__MODULE__{
    id: map["id"],
    object: map["object"] || "balance_transaction",
    amount: map["amount"],
    available_on: map["available_on"],
    # ... every other known field explicitly
    source: map["source"],  # stays raw binary | map() per D-05 rule 5
    fee_details: fee_details,
    extra: Map.drop(map, @known_fields)
  }
end

def from_map(nil), do: nil
```

`require_param!(id, "balance_transaction id")` pre-network on `retrieve/3`.

**No PII Inspect** — BalanceTransaction carries no PII per RESEARCH.md PII table line 421.

**Tests** — two files:

`test/lattice_stripe/balance_transaction/fee_detail_test.exs`:
- describe "cast/1": happy path with all 5 known fields populated
- describe "cast/1": unknown future field preserved in :extra
- describe "cast/1": nil returns nil
- describe "reconciliation pattern": `Enum.filter([fee1, fee2, fee3], &(&1.type == "application_fee"))` returns only matching entries

`test/lattice_stripe/balance_transaction_test.exs` using TransportMock:
- describe "retrieve/3": GET /v1/balance_transactions/txn_test; ArgumentError on empty id
- describe "retrieve!/3": raises on error
- describe "list/3 with payout filter": GET /v1/balance_transactions, asserts `payout: "po_test"` in request params
- describe "list/3 with multiple filters": payout + source + type + currency + created — all pass-through, no client-side rejection
- describe "list/3": returns wrapped %Response{data: %List{data: [%BalanceTransaction{}, ...]}}
- describe "stream!/3 with payout filter": yields BalanceTransaction structs lazily
- describe "from_map/1 fee_details decoding":
  - Fixture with 3 fee_details entries decodes to `bt.fee_details = [%FeeDetail{}, %FeeDetail{}, %FeeDetail{}]`
  - Reconciliation pattern works end-to-end: `Enum.filter(bt.fee_details, &(&1.type == "application_fee"))` returns at least 1 entry
- describe "from_map/1 source": `bt.source` is a string when not expanded, a map when expanded — both round-trip without crashing (D-05 rule 5)
- describe "module surface": `refute function_exported?(LatticeStripe.BalanceTransaction, :create, 2)`, same for `:update/3`, `:delete/2`
- describe "F-001": unknown future field survives in :extra

**Fixtures**:
- `test/support/fixtures/balance_transaction_fixtures.ex` — `LatticeStripe.Test.Fixtures.BalanceTransaction` with `basic/1`, `with_application_fee/1` (fee_details contains an application_fee entry), `payout_batch/1` (a list response simulating BalanceTransaction.list filtered by payout), `with_source_string/1`, `with_source_expanded/1` (source is an expanded map)
- `test/support/fixtures/balance_transaction_fee_detail_fixtures.ex` — `LatticeStripe.Test.Fixtures.BalanceTransactionFeeDetail` with `application_fee/1`, `stripe_fee/1`, `tax/1`
  </action>
  <verify>
    <automated>mix test test/lattice_stripe/balance_transaction_test.exs test/lattice_stripe/balance_transaction/fee_detail_test.exs --exclude integration</automated>
  </verify>
  <acceptance_criteria>
    - `lib/lattice_stripe/balance_transaction.ex` contains `defmodule LatticeStripe.BalanceTransaction` and `def retrieve(` and `def list(` and `def stream!(` and `def from_map(`
    - `! grep -qE 'def (create|update|delete)\(' lib/lattice_stripe/balance_transaction.ex`
    - `lib/lattice_stripe/balance_transaction/fee_detail.ex` contains `defmodule LatticeStripe.BalanceTransaction.FeeDetail` and `def cast(`
    - `grep -q '/v1/balance_transactions' lib/lattice_stripe/balance_transaction.ex` succeeds
    - `grep -q 'FeeDetail.cast' lib/lattice_stripe/balance_transaction.ex` succeeds
    - `! grep -q 'Jason.Encoder' lib/lattice_stripe/balance_transaction.ex`
    - `! grep -q 'Jason.Encoder' lib/lattice_stripe/balance_transaction/fee_detail.ex`
    - `mix test test/lattice_stripe/balance_transaction_test.exs test/lattice_stripe/balance_transaction/fee_detail_test.exs` exits 0
    - `mix credo --strict lib/lattice_stripe/balance_transaction.ex lib/lattice_stripe/balance_transaction/fee_detail.ex` exits 0
    - `mix compile --warnings-as-errors` exits 0
  </acceptance_criteria>
  <done>BalanceTransaction retrieve+list+stream ships with no create/update/delete (Stripe-managed); FeeDetail nested struct decoded into [%FeeDetail{}]; reconciliation filter pattern verified by test; source remains opaque per D-05 rule 5.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Platform balance ↔ connected-account balance | Same function `Balance.retrieve/2`; the only distinguisher is the per-request `stripe_account:` opt; missing it inside a reconciliation loop produces silent wrong totals |
| BalanceTransaction.source ↔ user code | `source` is polymorphic across 16+ Stripe object types; typing it as a union would cost more than it saves; users compose `Charge.from_map` / `Transfer.from_map` themselves |
| Future Stripe payment-method types ↔ Balance.SourceTypes | Stripe regularly adds new payment methods (`ach_credit_transfer`, `link`, etc.); typed-inner-open-outer prevents struct-shape drift |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-18-20 | I (Information disclosure) / silent wrong-answer | `Balance.retrieve(client)` inside a reconciliation loop returns the platform balance instead of each connected account's balance | mitigate | Moduledoc opens with side-by-side examples (platform vs connected-account) and an explicit warning about the loop antipattern; the connected-account form is shown PROMINENTLY (D-07 guide section 2 also covers this); test asserts `retrieve(client, stripe_account: "acct_123")` threads opts through |
| T-18-21 | T (Tampering) | F-001 unknown field loss in any of the 5 new structs | mitigate | All 5 modules use `Map.split` / `Map.drop` for `:extra`; round-trip tests assert synthetic future fields survive |
| T-18-22 | T (Tampering) | New Stripe payment-method type drops a Balance.SourceTypes value | mitigate | Typed-inner-open-outer pattern absorbs unknown payment-method keys into `:extra`; test asserts `"ach_credit_transfer" => 5000` survives |
| T-18-23 | E (Elevation of privilege) | Accidental Balance.list / Balance.create added later | mitigate | `refute function_exported?` tests for `:list/1`, `:create/2`, `:update/3`, `:delete/2`; grep guard in acceptance criteria; defstruct must NOT include `:id` field |
| T-18-24 | E (Elevation of privilege) | Accidental BalanceTransaction.create / update / delete added later (Stripe manages these server-side; client-side surface would be a footgun) | mitigate | `refute function_exported?` tests + grep guards in acceptance criteria |
| T-18-25 | T (Tampering) | `BalanceTransaction.source` cast forces a polymorphic crash | mitigate | D-05 rule 5: `source` stays as raw `binary | map()`; tests assert both string-source and map-source fixtures round-trip without crashing |
| T-18-26 | I (Information disclosure) | Balance / BalanceTransaction logging | accept | Neither object carries customer PII per RESEARCH.md PII table line 421; default Inspect is acceptable |
</threat_model>

<verification>
- `mix test test/lattice_stripe/balance_test.exs test/lattice_stripe/balance/amount_test.exs test/lattice_stripe/balance/source_types_test.exs test/lattice_stripe/balance_transaction_test.exs test/lattice_stripe/balance_transaction/fee_detail_test.exs --exclude integration` exits 0
- `mix compile --warnings-as-errors` exits 0
- `mix credo --strict` clean for all 5 new files
- Acceptance-criteria grep guards all pass
- Reuse proof test: a single fixture's `available[0]`, `pending[0]`, `connect_reserved[0]`, `instant_available[0]`, and `issuing.available[0]` all match `%LatticeStripe.Balance.Amount{}` (the same module — ZERO duplication)
- Reconciliation pattern test: `Enum.filter(bt.fee_details, &(&1.type == "application_fee"))` returns at least one match against the application-fee fixture
</verification>

<success_criteria>
- `LatticeStripe.Balance` ships as a singleton (no id, no list, no create/update/delete) with `retrieve/2` and `retrieve!/2`
- `LatticeStripe.Balance.Amount` and `LatticeStripe.Balance.SourceTypes` ship as nested typed structs; `Balance.Amount` reused 5× verified
- `LatticeStripe.BalanceTransaction` ships `retrieve/3`, `list/3`, `stream!/3` (no create/update/delete)
- `LatticeStripe.BalanceTransaction.FeeDetail` ships with `{amount, application, currency, description, type}` shape; reconciliation filter pattern verified
- `Balance.retrieve(client, stripe_account: "acct_123")` threading verified end-to-end via TransportMock
- All 5 new modules pass `mix credo --strict` and `mix compile --warnings-as-errors`
- Plan 06 (integration tests + guide) is unblocked
</success_criteria>

<output>
After completion, create `.planning/phases/18-connect-money-movement/18-05-SUMMARY.md`
</output>
