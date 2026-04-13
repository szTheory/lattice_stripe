---
phase: 18
plan: 04
type: execute
wave: 2
depends_on: [18-01]
files_modified:
  - lib/lattice_stripe/payout.ex
  - lib/lattice_stripe/payout/trace_id.ex
  - test/lattice_stripe/payout_test.exs
  - test/lattice_stripe/payout/trace_id_test.exs
  - test/support/fixtures/payout_fixtures.ex
  - test/support/fixtures/payout_trace_id_fixtures.ex
autonomous: true
requirements: [CNCT-02]
tags: [connect, payout, trace-id, cancel, reverse]

must_haves:
  truths:
    - "Developer can create/retrieve/update/list/stream Payouts via LatticeStripe.Payout with full bang variants"
    - "Developer can call Payout.cancel(client, id) AND Payout.cancel(client, id, %{expand: [\"balance_transaction\"]})"
    - "Developer can call Payout.reverse(client, id, %{metadata: %{}, expand: [...]})"
    - "Payout.from_map decodes the trace_id object into a typed %Payout.TraceId{} (status + value pattern-match target)"
    - "Payout.cancel and Payout.reverse use the canonical (client, id, params \\\\ %{}, opts \\\\ []) shape — no breaking change required when expand is needed"
  artifacts:
    - path: "lib/lattice_stripe/payout.ex"
      provides: "%Payout{} struct + create/3 + retrieve/3 + update/4 + list/3 + stream!/3 + cancel/4 + reverse/4 + bang variants + from_map/1"
      contains: "defmodule LatticeStripe.Payout"
    - path: "lib/lattice_stripe/payout/trace_id.ex"
      provides: "%Payout.TraceId{status, value} nested typed struct + cast/1"
      contains: "defmodule LatticeStripe.Payout.TraceId"
  key_links:
    - from: "lib/lattice_stripe/payout.ex"
      to: "lib/lattice_stripe/payout/trace_id.ex"
      via: "Payout.from_map calls Payout.TraceId.cast/1 on the trace_id field"
      pattern: "Payout.TraceId.cast"
    - from: "lib/lattice_stripe/payout.ex"
      to: "/v1/payouts/:id/cancel and /v1/payouts/:id/reverse"
      via: "Request{path: \"/v1/payouts/#{id}/cancel\"} and \"/v1/payouts/#{id}/reverse\""
      pattern: "/v1/payouts/.*(cancel|reverse)"
---

<objective>
Ship `LatticeStripe.Payout` (full CRUDL + cancel + reverse) and `LatticeStripe.Payout.TraceId` (nested typed struct) per D-03 and D-05. Closes the Payout half of CNCT-02.

D-03 locks the canonical `(client, id, params \\ %{}, opts \\ [])` shape on BOTH `cancel` and `reverse` — every Stripe endpoint accepts at least `expand`, and dropping `params` would force a breaking change the first time someone needs `expand: ["balance_transaction"]`.

D-04 locks zero atom guards: `method`, `source_type`, and similar enums stay in the params map as plain atoms typed via `@spec` only.

D-05 promotes `Payout.TraceId` as a 2-field nested typed struct ({status, value}) — `status` is a clear pattern-match target and every typed peer SDK promotes it.

Depends on Plan 18-01 only because Wave 4 integration tests will expand `Payout.destination` and cast via `BankAccount.cast/1` / `Card.cast/1`. Plan 04 itself does not import the BankAccount/Card modules — the dependency is declared for wave-ordering hygiene.

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
@lib/lattice_stripe/account/capability.ex
@lib/lattice_stripe/customer.ex
@lib/lattice_stripe/resource.ex
@lib/lattice_stripe/list.ex

<interfaces>
From lib/lattice_stripe/refund.ex (the Refund.cancel pattern that Payout.cancel + Payout.reverse copy):
```elixir
@spec cancel(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def cancel(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
  %Request{method: :post, path: "/v1/refunds/#{id}/cancel", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

From lib/lattice_stripe/account/capability.ex (nested struct ~w()a atom sigil pattern):
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
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Payout.TraceId nested typed struct</name>
  <files>lib/lattice_stripe/payout/trace_id.ex, test/lattice_stripe/payout/trace_id_test.exs, test/support/fixtures/payout_trace_id_fixtures.ex</files>
  <read_first>
    - lib/lattice_stripe/account/capability.ex (full file — canonical nested struct template with `~w()a` atom sigil)
    - .planning/phases/18-connect-money-movement/18-RESEARCH.md "Stripe API Contract → Payouts" section (Payout.TraceId @known_fields)
  </read_first>
  <behavior>
    - Payout.TraceId.cast(%{"status" => "supported", "value" => "FED12345"}) returns %Payout.TraceId{status: "supported", value: "FED12345", extra: %{}}
    - cast/1 on nil returns nil
    - cast/1 with unknown key like %{"status" => "supported", "value" => "x", "future_key" => "y"} preserves "future_key" => "y" in :extra
    - status field is the documented pattern-match target ("supported" | "pending" | "unsupported" | "not_applicable" — Stripe enum)
  </behavior>
  <action>
**Create `lib/lattice_stripe/payout/trace_id.ex`** following `Account.Capability` template (atom sigil for nested structs).

```elixir
defmodule LatticeStripe.Payout.TraceId do
  @moduledoc """
  Trace identifier for a Stripe Payout.

  Surfaces the rail-specific trace ID that lets you reconcile a payout against
  the recipient bank's settlement record. The `status` field is a clear
  pattern-match target — your reconciliation code typically branches on whether
  Stripe has obtained the trace ID yet.

      case payout.trace_id do
        %LatticeStripe.Payout.TraceId{status: "supported", value: trace} -> ...
        %LatticeStripe.Payout.TraceId{status: "pending"} -> ...
        %LatticeStripe.Payout.TraceId{status: status} -> ...
      end
  """

  @known_fields ~w(status value)a

  defstruct @known_fields ++ [extra: %{}]

  @typedoc "A Stripe Payout trace ID."
  @type t :: %__MODULE__{
          status: String.t() | nil,
          value: String.t() | nil,
          extra: map()
        }

  @doc false
  def cast(nil), do: nil

  def cast(map) when is_map(map) do
    known_string_keys = Enum.map(@known_fields, &Atom.to_string/1)
    {known, extra} = Map.split(map, known_string_keys)

    struct(__MODULE__,
      status: known["status"],
      value: known["value"],
      extra: extra
    )
  end
end
```

**Tests** (`test/lattice_stripe/payout/trace_id_test.exs`):
- describe "cast/1": happy path with status + value populates struct
- describe "cast/1": nil returns nil
- describe "cast/1": unknown future key preserved in :extra (F-001 round-trip)
- describe "cast/1": pattern-match works — `%TraceId{status: "supported", value: trace} = ...`
- describe "no Jason.Encoder": grep guard

**Fixture** (`test/support/fixtures/payout_trace_id_fixtures.ex`):
`LatticeStripe.Test.Fixtures.PayoutTraceId` with `supported/1`, `pending/1`, `unsupported/1` returning string-keyed maps.
  </action>
  <verify>
    <automated>mix test test/lattice_stripe/payout/trace_id_test.exs --exclude integration</automated>
  </verify>
  <acceptance_criteria>
    - `lib/lattice_stripe/payout/trace_id.ex` contains `defmodule LatticeStripe.Payout.TraceId` and `def cast(`
    - `grep -q '@known_fields ~w(status value)a' lib/lattice_stripe/payout/trace_id.ex` succeeds
    - `! grep -q 'Jason.Encoder' lib/lattice_stripe/payout/trace_id.ex`
    - `mix test test/lattice_stripe/payout/trace_id_test.exs` exits 0
    - `mix credo --strict lib/lattice_stripe/payout/trace_id.ex` exits 0
  </acceptance_criteria>
  <done>Payout.TraceId nested struct ships with F-001 + atom sigil pattern; pattern-match on status verified by test.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Payout CRUDL + cancel + reverse + TraceId integration</name>
  <files>lib/lattice_stripe/payout.ex, test/lattice_stripe/payout_test.exs, test/support/fixtures/payout_fixtures.ex</files>
  <read_first>
    - lib/lattice_stripe/payout/trace_id.ex (just created)
    - lib/lattice_stripe/refund.ex (cancel/4 with default params is the canonical template for Payout.cancel + Payout.reverse)
    - lib/lattice_stripe/customer.ex (F-001 + defstruct shape)
    - .planning/phases/18-connect-money-movement/18-RESEARCH.md "Stripe API Contract → Payouts" section (verbatim @known_fields)
  </read_first>
  <behavior>
    - Payout.create(client, %{amount: 1000, currency: "usd"}) builds POST /v1/payouts
    - Payout.retrieve(client, "po_123") builds GET /v1/payouts/po_123
    - Payout.update(client, "po_123", %{metadata: %{}}) builds POST /v1/payouts/po_123
    - Payout.list(client, %{status: "paid"}) returns wrapped %Response{data: %List{data: [%Payout{}, ...]}}
    - Payout.stream!(client) yields %Payout{} structs lazily
    - Payout.cancel(client, "po_123") works without explicit params (default %{}) — common case stays ergonomic
    - Payout.cancel(client, "po_123", %{expand: ["balance_transaction"]}) threads expand into params
    - Payout.reverse(client, "po_123", %{metadata: %{"k" => "v"}, expand: ["balance_transaction"]}) builds POST /v1/payouts/po_123/reverse
    - Payout.from_map decodes trace_id field into a %Payout.TraceId{} struct (or nil if absent)
    - Payout module signature for cancel and reverse is exactly `(client, id, params \\ %{}, opts \\ [])` — verified by `function_exported?` arity-2 and arity-4 checks
    - All bang variants raise on errors
    - require_param! validates id pre-network on retrieve/update/cancel/reverse
  </behavior>
  <action>
**Create `lib/lattice_stripe/payout.ex`** following the `Refund` template.

`@known_fields` (copy verbatim from RESEARCH.md Stripe API Contract → Payouts):
```
~w[
  id object amount application_fee application_fee_amount arrival_date
  automatic balance_transaction created currency description destination
  failure_balance_transaction failure_code failure_message livemode metadata
  method original_payout reconciliation_status reversed_by source_type
  statement_descriptor status trace_id type
]
```

`defstruct` with `object: "payout"` default, `extra: %{}`. Add `@typedoc` and `@type t` (note: `trace_id: LatticeStripe.Payout.TraceId.t() | nil`).

**Public functions** (every with `@spec`):
```elixir
def create(client, params, opts \\ [])     # POST /v1/payouts
def create!(client, params, opts \\ [])
def retrieve(client, id, opts \\ [])       # GET /v1/payouts/:id
def retrieve!(client, id, opts \\ [])
def update(client, id, params, opts \\ []) # POST /v1/payouts/:id
def update!(client, id, params, opts \\ [])
def list(client, params \\ %{}, opts \\ [])
def list!(client, params \\ %{}, opts \\ [])
def stream!(client, params \\ %{}, opts \\ [])

# D-03 canonical shape — params \\ %{} is mandatory:
@spec cancel(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def cancel(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
  Resource.require_param!(%{"id" => id}, "id", ~s|Payout.cancel/4 requires a non-empty payout id|)
  %Request{method: :post, path: "/v1/payouts/#{id}/cancel", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
def cancel!(client, id, params \\ %{}, opts \\ [])

@spec reverse(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def reverse(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
  Resource.require_param!(%{"id" => id}, "id", ~s|Payout.reverse/4 requires a non-empty payout id|)
  %Request{method: :post, path: "/v1/payouts/#{id}/reverse", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
def reverse!(client, id, params \\ %{}, opts \\ [])
```

**Per D-04 / P15 D5:** NO atom-guard variants of `Payout.create`, `Payout.cancel`, or `Payout.reverse`. NO positional `method:` argument. Because of default params on `cancel/4` and `reverse/4`, both arity-2 and arity-4 ARE exported and both must work. Tests assert `function_exported?(LatticeStripe.Payout, :cancel, 4)` is TRUE, `function_exported?(LatticeStripe.Payout, :cancel, 2)` is TRUE, and `function_exported?(LatticeStripe.Payout, :cancel, 5)` is FALSE (same for `reverse`).

**`from_map/1`** — explicit field mapping with one special case for `trace_id`:

```elixir
def from_map(map) when is_map(map) do
  %__MODULE__{
    id: map["id"],
    object: map["object"] || "payout",
    amount: map["amount"],
    # ... every other known field explicitly
    trace_id: LatticeStripe.Payout.TraceId.cast(map["trace_id"]),
    extra: Map.drop(map, @known_fields)
  }
end

def from_map(nil), do: nil
```

`destination`, `balance_transaction`, `failure_balance_transaction` stay as raw `binary | map()` per D-05 rule 7 (expandable references — not promoted). Document in moduledoc that users who pass `expand: ["destination"]` can cast the result via `LatticeStripe.ExternalAccount.cast/1` themselves.

**No PII Inspect** — Payout carries no customer PII per RESEARCH.md PII table line 421.

**Tests** (`test/lattice_stripe/payout_test.exs`) using `TransportMock`:
- describe "create/3": POST /v1/payouts; multi-field params; no client-side validation
- describe "retrieve/3": GET /v1/payouts/po_test; ArgumentError on empty id
- describe "update/4": POST /v1/payouts/po_test
- describe "list/3": with status filter
- describe "stream!/3": yields Payout structs lazily
- describe "cancel/4 default params": `Payout.cancel(client, "po_test")` works without explicit params (no breaking-change-on-add risk); asserts POST /v1/payouts/po_test/cancel with empty params body
- describe "cancel/4 with expand": `Payout.cancel(client, "po_test", %{expand: ["balance_transaction"]})` threads expand
- describe "cancel/4": empty/nil id raises ArgumentError pre-network
- describe "reverse/4 default params": same patterns as cancel
- describe "reverse/4 with metadata + expand": `Payout.reverse(client, "po_test", %{metadata: %{"k" => "v"}, expand: ["balance_transaction"]})`
- describe "from_map/1 trace_id decoding":
  - Fixture with `trace_id: %{status: "supported", value: "FED12345"}` decodes to `payout.trace_id == %Payout.TraceId{status: "supported", value: "FED12345"}`
  - Fixture with `trace_id: nil` decodes to `payout.trace_id == nil`
  - Pattern match on `%Payout{trace_id: %Payout.TraceId{status: "supported"}}` works
- describe "from_map/1 expandable references": `payout.destination` is a string when not expanded, a map when expanded — both round-trip
- describe "F-001": unknown future field survives in :extra
- describe "module surface — no atom-guard variants": `refute function_exported?(LatticeStripe.Payout, :cancel, 5)` (no arity-5 variant)
- describe "bang variants": each raises on `{:error, %Error{}}`

**Fixture** (`test/support/fixtures/payout_fixtures.ex`):
`LatticeStripe.Test.Fixtures.Payout` with `basic/1`, `with_trace_id/1` (status: "supported"), `pending/1` (status: "pending"), `cancelled/1`, `reversed/1`, `with_destination_string/1`, `with_destination_expanded/1` (destination is a bank_account map), `list_response/1`. IDs like `"po_1OoMpqJ2eZvKYlo20wxYzAbC"`.
  </action>
  <verify>
    <automated>mix test test/lattice_stripe/payout_test.exs --exclude integration</automated>
  </verify>
  <acceptance_criteria>
    - `lib/lattice_stripe/payout.ex` contains `defmodule LatticeStripe.Payout` and `def create(` and `def retrieve(` and `def update(` and `def list(` and `def stream!(` and `def cancel(` and `def reverse(`
    - `grep -qE 'def cancel\(' lib/lattice_stripe/payout.ex` succeeds AND test assertion `function_exported?(LatticeStripe.Payout, :cancel, 4)` AND `function_exported?(LatticeStripe.Payout, :cancel, 2)` both TRUE AND `function_exported?(LatticeStripe.Payout, :cancel, 5)` FALSE (D-03 canonical shape — robust to multi-line signature formatting)
    - `grep -qE 'def reverse\(' lib/lattice_stripe/payout.ex` succeeds AND test assertion `function_exported?(LatticeStripe.Payout, :reverse, 4)` AND `function_exported?(LatticeStripe.Payout, :reverse, 2)` both TRUE AND `function_exported?(LatticeStripe.Payout, :reverse, 5)` FALSE (D-03 canonical shape)
    - `grep -q '/v1/payouts/.*cancel' lib/lattice_stripe/payout.ex` succeeds
    - `grep -q '/v1/payouts/.*reverse' lib/lattice_stripe/payout.ex` succeeds
    - `grep -q 'Payout.TraceId.cast' lib/lattice_stripe/payout.ex` succeeds
    - `! grep -q 'Jason.Encoder' lib/lattice_stripe/payout.ex`
    - `mix test test/lattice_stripe/payout_test.exs` exits 0
    - `mix credo --strict lib/lattice_stripe/payout.ex` exits 0
    - `mix compile --warnings-as-errors` exits 0
  </acceptance_criteria>
  <done>Payout CRUDL + cancel + reverse ships with D-03 canonical signature, TraceId nested struct decoded into typed field, no atom-guarded variants, common-case `cancel(client, id)` ergonomic via default params, F-001 round-trip verified.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| LatticeStripe ↔ Stripe API | `Payout.create`, `Payout.cancel`, `Payout.reverse` are money-moving operations; idempotency keys (auto-generated by Client) must reuse the same key on retry |
| API surface stability ↔ user code | Dropping `params \\ %{}` from `cancel`/`reverse` would force a breaking change the first time someone needs `expand` |
| `trace_id` enum drift ↔ user pattern matching | Stripe could add new `status` enum values (`"voided"`, etc.); typing it as `String.t()` keeps users forward-compatible |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-18-15 | T (Tampering) / R (Repudiation) | `Payout.create` / `cancel` / `reverse` double-execution on retry | mitigate | `Client.request/2` already auto-generates idempotency keys for mutating requests and reuses them across retries (Phase 2 RTRY-03 shipped); Plan 04 adds NO new code path that could break this. Moduledoc includes idempotency_key opt example |
| T-18-16 | E (Elevation of privilege) / API breakage | Dropping `params \\ %{}` from cancel/reverse | mitigate | D-03 canonical shape locked; acceptance criterion grep guards `def cancel(.*params \\\\ %{}, opts \\\\ \[\])` and same for reverse; tests cover BOTH `cancel(client, id)` and `cancel(client, id, %{expand: [...]})` cases |
| T-18-17 | T (Tampering) | F-001 unknown field loss in `Payout` or `Payout.TraceId` | mitigate | Both modules use `Map.drop` / `Map.split` for `:extra`; round-trip tests assert synthetic future fields survive |
| T-18-18 | I (Information disclosure) | Payout logging | accept | Payout object carries no customer PII per RESEARCH.md PII table line 421; default Inspect is acceptable |
| T-18-19 | E (Elevation of privilege) | Atom-guarded `Payout.cancel` / `Payout.reverse` slipping in later | mitigate | D-04 prohibition; tests assert `refute function_exported?(LatticeStripe.Payout, :cancel, 5)` (no atom-guarded arity-5 variant) and grep guards in acceptance criteria |
</threat_model>

<verification>
- `mix test test/lattice_stripe/payout_test.exs test/lattice_stripe/payout/trace_id_test.exs --exclude integration` exits 0
- `mix compile --warnings-as-errors` exits 0
- `mix credo --strict lib/lattice_stripe/payout.ex lib/lattice_stripe/payout/trace_id.ex` exits 0
- Acceptance-criteria grep guards all pass
- D-03 signature regression test: `cancel(client, "po_x")` and `cancel(client, "po_x", %{expand: ["balance_transaction"]})` BOTH succeed against stubbed transport
</verification>

<success_criteria>
- `LatticeStripe.Payout` ships full CRUDL + cancel + reverse with D-03 canonical `(client, id, params \\ %{}, opts \\ [])` shape on both action verbs
- `LatticeStripe.Payout.TraceId` nested typed struct decoded as the `trace_id` field, status pattern-match verified
- No atom-guarded variants of `Payout.create`, `cancel`, or `reverse` (D-04 enforced)
- F-001 round-trip preserves unknown future fields
- Plan 05 (Balance + BalanceTransaction) is unblocked
</success_criteria>

<output>
After completion, create `.planning/phases/18-connect-money-movement/18-04-SUMMARY.md`
</output>
