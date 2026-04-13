---
phase: 18
plan: 02
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/lattice_stripe/charge.ex
  - test/lattice_stripe/charge_test.exs
  - test/support/fixtures/charge_fixtures.ex
autonomous: true
requirements: [CNCT-04]
tags: [connect, charge, retrieve, pii, reconciliation]

must_haves:
  truths:
    - "Developer can retrieve a Stripe Charge by id and receive a typed %LatticeStripe.Charge{} struct with all Connect-relevant fields populated"
    - "Charge.from_map/1 preserves unknown Stripe fields in :extra (F-001) so future Stripe additions never crash"
    - "Charge Inspect output never leaks billing_details, payment_method_details, fraud_details, receipt_email, or receipt_url"
    - "No Charge.create/update/capture/list/search/stream! exists — retrieve-only per D-06"
  artifacts:
    - path: "lib/lattice_stripe/charge.ex"
      provides: "%LatticeStripe.Charge{} struct + retrieve/3 + retrieve!/3 + from_map/1 + PII Inspect"
      contains: "defmodule LatticeStripe.Charge"
    - path: "test/lattice_stripe/charge_test.exs"
      provides: "Unit tests for retrieve, from_map round-trip, PII Inspect, ArgumentError on missing id"
      contains: "describe \"retrieve/3\""
    - path: "test/support/fixtures/charge_fixtures.ex"
      provides: "Charge fixtures including expanded balance_transaction case"
      contains: "defmodule LatticeStripe.Test.Fixtures.Charge"
  key_links:
    - from: "lib/lattice_stripe/charge.ex"
      to: "/v1/charges/:id"
      via: "Request{method: :get, path: \"/v1/charges/#{id}\"} piped through Client.request/2"
      pattern: "/v1/charges/"
---

<objective>
Ship `LatticeStripe.Charge` as a retrieve-only resource per D-06. Charge is added FRESH in Phase 18 — `lib/lattice_stripe/charge.ex` has never existed in git history (verified during research). The module exists to give Connect fee reconciliation a typed return when walking `BalanceTransaction.source` back to a charge id, instead of forcing users to drop into `LatticeStripe.Client.request/2`.

Locks decision D-06: NO `create`, `update`, `capture`, `list`, `stream!`, or `search`. Stripe's modern API is PaymentIntent-first for creation; this module is purely a typed read of already-created charges.

Purpose: closes the per-object reconciliation idiom for CNCT-04 (`PaymentIntent.retrieve(client, "pi_...", expand: ["latest_charge.balance_transaction"])` then walking `fee_details`). Plans 03/05 do not depend on this — it's parallel-safe in Wave 1.

Output: 1 source file, 1 unit test file, 1 fixture module.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/18-connect-money-movement/18-CONTEXT.md
@.planning/phases/18-connect-money-movement/18-RESEARCH.md
@lib/lattice_stripe/refund.ex
@lib/lattice_stripe/customer.ex
@lib/lattice_stripe/resource.ex

<interfaces>
From lib/lattice_stripe/resource.ex:
```elixir
def unwrap_singular({:ok, %Response{data: data}}, fun)
def unwrap_bang!({:ok, value}) | def unwrap_bang!({:error, %Error{} = err})
def require_param!(params, key, message \\ nil)  # raises ArgumentError
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Charge struct + retrieve/3 + retrieve!/3 + from_map/1 + PII Inspect</name>
  <files>lib/lattice_stripe/charge.ex, test/lattice_stripe/charge_test.exs, test/support/fixtures/charge_fixtures.ex</files>
  <read_first>
    - lib/lattice_stripe/refund.ex (canonical CRUDL template — copy retrieve/3 shape verbatim)
    - lib/lattice_stripe/customer.ex (lines 36-91 for F-001 defstruct shape; lines 462-489 for defimpl Inspect Inspect.Algebra pattern)
    - lib/lattice_stripe/resource.ex (require_param!/3, unwrap_singular/2, unwrap_bang!/1)
    - .planning/phases/18-connect-money-movement/18-RESEARCH.md "Stripe API Contract → Charge" section (verbatim @known_fields list)
  </read_first>
  <behavior>
    - Charge.retrieve(client, "ch_123") builds GET /v1/charges/ch_123 and returns {:ok, %Charge{id: "ch_123", ...}}
    - Charge.retrieve!(client, "ch_123") returns the bare %Charge{} on success and raises on {:error, %Error{}}
    - Charge.retrieve(client, "") raises ArgumentError pre-network ("charge id" message)
    - Charge.retrieve(client, nil) raises ArgumentError pre-network
    - Charge.from_map/1 maps every known field explicitly; unknown fields land in :extra
    - inspect(%Charge{billing_details: %{"email" => "secret@example.com"}, receipt_email: "rcpt@x.com"}) does NOT contain "secret@example.com" or "rcpt@x.com"
    - inspect/1 SHOWS id, object, amount, currency, status, captured, paid
    - Charge.retrieve accepts opts including expand: ["balance_transaction"]
    - Module does NOT define create/2, update/3, capture/3, cancel/3, list/2, stream!/2, search/2
  </behavior>
  <action>
**Create `lib/lattice_stripe/charge.ex`** following the Refund template structure but with ONLY `retrieve/3`, `retrieve!/3`, and `from_map/1` as public functions.

**`@moduledoc`** opens with the PaymentIntent-first pointer (D-06):
```
Stripe's modern API is PaymentIntent-first; use `LatticeStripe.PaymentIntent.create/3`
to accept payments. This module exposes retrieve-only access for reading settled
fee details during Connect platform fee reconciliation.
```
Include a worked example showing `Charge.retrieve(client, "ch_123", expand: ["balance_transaction"])` and walking `bt.fee_details |> Enum.filter(&(&1.type == "application_fee"))`.

**`@known_fields`** — copy verbatim from D-06 (string sigil, no `a`):
```
~w[
  id object amount amount_captured amount_refunded application
  application_fee application_fee_amount balance_transaction billing_details
  captured created currency customer description destination failure_code
  failure_message fraud_details invoice livemode metadata on_behalf_of
  outcome paid payment_intent payment_method payment_method_details
  receipt_email receipt_number receipt_url refunded refunds review
  source_transfer statement_descriptor statement_descriptor_suffix status
  transfer_data transfer_group
]
```

**`defstruct`** lists every field as `:field` with `object: "charge"` default and `extra: %{}`. Add `@typedoc "A Stripe Charge object."` and `@type t :: %__MODULE__{...}` with reasonable Stripe types (`String.t() | nil`, `integer() | nil`, `boolean() | nil`, `map() | nil`).

**`from_map/1`** — explicit field-by-field assignment, `extra: Map.drop(map, @known_fields)`. Match Customer/Refund body structure exactly. Add `from_map(nil) -> nil`.

**`retrieve/3`** — copy from `Refund.retrieve/3`:
```elixir
@spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
  Resource.require_param!(%{"id" => id}, "id", ~s|Charge.retrieve/3 requires a non-empty "id"|)
  %Request{method: :get, path: "/v1/charges/#{id}", params: %{}, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end

@spec retrieve!(Client.t(), String.t(), keyword()) :: t()
def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
  client |> retrieve(id, opts) |> Resource.unwrap_bang!()
end
```

`require_param!` must accept nil-safe input — wrap as `Resource.require_param!(%{"id" => id}, "id", ...)` so a nil id is rejected. If `is_binary(id)` guard rejects nil before reaching `require_param!`, add a separate `def retrieve(_, nil, _)` clause that raises ArgumentError with the same message — verify against Customer/Refund precedent for the exact pattern.

**`defimpl Inspect, for: LatticeStripe.Charge`** — show only:
```
[id, object, amount, currency, status, captured, paid]
```
HIDE: `billing_details`, `payment_method_details`, `fraud_details`, `receipt_email`, `receipt_url`, `receipt_number`, `customer`, `payment_method`. Use the same `Inspect.Algebra concat/to_doc` pattern as `customer.ex:467+`.

**MUST NOT define:** `create/2`, `update/3`, `capture/3`, `cancel/3`, `list/2`, `stream!/2`, `search/2`. Tests assert these arities are NOT exported via `function_exported?/3`.

**`test/lattice_stripe/charge_test.exs`** — use `LatticeStripe.TransportMock`:
- describe "retrieve/3": happy path stubs a Charge fixture, asserts request shape (GET /v1/charges/ch_*), asserts return is `{:ok, %Charge{}}` with all fields populated
- describe "retrieve/3": with `expand: ["balance_transaction"]` opts — assert opts threaded
- describe "retrieve/3": empty/nil id raises ArgumentError pre-network
- describe "retrieve!/3": bang variant raises on `{:error, %Error{}}`
- describe "from_map/1": unknown future field `"extra_thing" => "x"` survives in :extra (F-001 round-trip)
- describe "from_map/1": nil returns nil
- describe "Inspect": `inspect(charge)` does NOT contain literal PII strings (`refute String.contains?`)
- describe "module surface": `refute function_exported?(LatticeStripe.Charge, :create, 2)`, same for `:update/3`, `:capture/3`, `:cancel/3`, `:list/2`, `:stream!/2`, `:search/2`
- describe "no Jason.Encoder": (compile-time check via test that can call `Code.fetch_docs(LatticeStripe.Charge)` and inspect `@derive` — or simpler: grep is enforced via acceptance criteria below)

**`test/support/fixtures/charge_fixtures.ex`** — `LatticeStripe.Test.Fixtures.Charge`:
- `basic/1` returns a string-keyed map matching `/v1/charges/ch_*` response with all known fields populated, realistic IDs (`"ch_3OoLqrJ2eZvKYlo20wxYzAbC"`, `"pi_3OoLpqJ2eZvKYlo21fGhIjKl"`, `"acct_1Nv0FGQ9RKHgCVdK"`)
- `with_balance_transaction_expanded/1` — same but `balance_transaction` is an expanded map (not a string), with realistic `fee_details` containing one `application_fee` entry
- `with_pii/1` — populates `billing_details`, `payment_method_details`, `fraud_details`, `receipt_email`, `receipt_url` with sentinel values for Inspect tests
  </action>
  <verify>
    <automated>mix test test/lattice_stripe/charge_test.exs --exclude integration</automated>
  </verify>
  <acceptance_criteria>
    - `lib/lattice_stripe/charge.ex` exists and contains `defmodule LatticeStripe.Charge` and `def retrieve(` and `def retrieve!(` and `def from_map(`
    - `! grep -q 'def create' lib/lattice_stripe/charge.ex`
    - `! grep -q 'def update' lib/lattice_stripe/charge.ex`
    - `! grep -q 'def capture' lib/lattice_stripe/charge.ex`
    - `! grep -q 'def list' lib/lattice_stripe/charge.ex`
    - `! grep -q 'def stream!' lib/lattice_stripe/charge.ex`
    - `! grep -q 'def search' lib/lattice_stripe/charge.ex`
    - `! grep -q 'Jason.Encoder' lib/lattice_stripe/charge.ex`
    - `grep -q '@known_fields' lib/lattice_stripe/charge.ex` succeeds
    - `grep -q 'application_fee_amount' lib/lattice_stripe/charge.ex` succeeds
    - `grep -q 'defimpl Inspect, for: LatticeStripe.Charge' lib/lattice_stripe/charge.ex` succeeds
    - `mix test test/lattice_stripe/charge_test.exs` exits 0
    - `mix compile --warnings-as-errors` exits 0
    - `mix credo --strict lib/lattice_stripe/charge.ex` exits 0
  </acceptance_criteria>
  <done>Charge retrieve-only resource ships, all 41 known fields decoded into typed struct, F-001 unknown-field preservation tested, PII Inspect verified, surface restriction verified by test, no other CRUD verbs introduced.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| developer logs ↔ Charge struct | `billing_details`, `payment_method_details`, `fraud_details`, `receipt_email`, `receipt_url` may contain customer PII; Inspect must hide them |
| LatticeStripe ↔ Stripe API | `Charge.retrieve` carries the platform secret key; per-request `stripe_account:` opt is honored by Client (already wired) |
| Public API surface ↔ user code | Adding `Charge.create` later would conflict with the PaymentIntent-first philosophy and force a documentation rewrite |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-18-06 | I (Information disclosure) | `LatticeStripe.Charge` Inspect | mitigate | `defimpl Inspect` shows only `[id, object, amount, currency, status, captured, paid]`; hides `billing_details`, `payment_method_details`, `fraud_details`, `receipt_email`, `receipt_url`, `receipt_number`, `customer`, `payment_method`; tested via `refute String.contains?` against literal sentinel values |
| T-18-07 | T (Tampering) | F-001 unknown field loss | mitigate | `from_map/1` uses `Map.drop(map, @known_fields)` for `:extra`; round-trip test asserts a synthetic future field survives |
| T-18-08 | E (Elevation of privilege) | Accidental Charge.create surface | mitigate | Tests assert `function_exported?/3` is FALSE for `:create`, `:update`, `:capture`, `:cancel`, `:list`, `:stream!`, `:search`; grep guard in acceptance criteria; D-06 locked rationale documented in moduledoc |
| T-18-09 | S (Spoofing) / I (Information disclosure) | Logging a Charge with `payment_method_details` containing card last4 | mitigate | Hidden by Inspect; if user explicitly accesses `charge.payment_method_details` they own the disclosure decision |
</threat_model>

<verification>
- `mix test test/lattice_stripe/charge_test.exs --exclude integration` exits 0
- `mix compile --warnings-as-errors` exits 0
- `mix credo --strict lib/lattice_stripe/charge.ex` exits 0
- Acceptance-criteria grep guards all pass
- Charge appears under the existing "Payments" ExDoc group (wiring comes in Plan 06)
</verification>

<success_criteria>
- `LatticeStripe.Charge.retrieve/3` ships, returns typed `%Charge{}` with full Connect-relevant field surface
- `from_map/1` round-trips unknown Stripe fields into `:extra`
- PII Inspect hide-list passes `refute String.contains?` tests for every hidden field
- Module surface is restricted: only `retrieve/3`, `retrieve!/3`, `from_map/1` are public
- Plan 06's per-object reconciliation guide example can call `Charge.retrieve(client, "ch_...", expand: ["balance_transaction"])` and walk `fee_details`
</success_criteria>

<output>
After completion, create `.planning/phases/18-connect-money-movement/18-02-SUMMARY.md`
</output>
