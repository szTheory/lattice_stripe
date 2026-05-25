# Phase 41: Quote Lifecycle E2E Verification - Pattern Map

**Mapped:** 2026-05-25
**Files analyzed:** 4
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `test/integration/quote_integration_test.exs` | test | request-response | `test/integration/credit_note_integration_test.exs` + `test/integration/product_integration_test.exs` | exact |
| `test/support/fixtures/quote.ex` | test | transform | `test/support/fixtures/credit_note.ex` | exact |
| `.planning/phases/36-quote/36-VERIFICATION.md` | test | batch | `.planning/phases/35-mandate-setupattempt/35-VERIFICATION.md` | exact |
| `.planning/REQUIREMENTS.md` | config | transform | current `.planning/REQUIREMENTS.md` + `.planning/phases/39-credit-note-verification-closure/39-VERIFICATION.md` | role-match |

## Pattern Assignments

### `test/integration/quote_integration_test.exs` (test, request-response)

**Primary analog:** [test/integration/credit_note_integration_test.exs](/Users/jon/projects/lattice_stripe/test/integration/credit_note_integration_test.exs:1)  
**Supporting analogs:** [test/integration/product_integration_test.exs](/Users/jon/projects/lattice_stripe/test/integration/product_integration_test.exs:29), [test/integration/invoice_integration_test.exs](/Users/jon/projects/lattice_stripe/test/integration/invoice_integration_test.exs:45), [test/lattice_stripe/quote_test.exs](/Users/jon/projects/lattice_stripe/test/lattice_stripe/quote_test.exs:103)

**Imports + setup pattern** (credit note lines 1-25):
```elixir
defmodule LatticeStripe.CreditNoteIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers
  import LatticeStripe.Test.Fixtures.CreditNote

  @moduletag :integration

  alias LatticeStripe.{CreditNote, Error}

  setup_all do
    case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
        :ok

      {:error, _} ->
        raise "stripe-mock not running on localhost:12111 — start with: docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest"
    end
  end

  setup do
    {:ok, client: test_integration_client()}
  end
```

**Create resource via fixture helper, then assert typed shape** (credit note lines 27-46):
```elixir
test "create/3 returns a CreditNote struct from a finalized invoice", %{client: client} do
  invoice =
    create_creditable_invoice!(client, %{"customer_email" => "credit-note-create@example.com"})

  {:ok, credit_note} =
    CreditNote.create(client, %{
      "invoice" => invoice.id,
      "lines" => [
        %{
          "type" => "custom_line_item",
          "description" => "Goodwill credit",
          "quantity" => 1,
          "unit_amount" => 500
        }
      ]
    })

  assert %CreditNote{} = credit_note
  assert is_binary(credit_note.id)
end
```

**One-hop retrieve pattern after create** (invoice lines 45-60):
```elixir
test "retrieve/3 returns invoice by id", %{client: client} do
  {:ok, created} = Invoice.create(client, %{...})

  {:ok, retrieved} = Invoice.retrieve(client, created.id)

  assert %Invoice{} = retrieved
  assert retrieved.id == created.id
end
```

**Dependent-resource create -> retrieve round-trip** (product lines 29-52):
```elixir
describe "Product CRUD round-trip" do
  test "create -> retrieve -> update -> list", %{client: client} do
    {:ok, created} =
      Product.create(client, %{
        "name" => "Integration Test Product",
        "metadata" => %{"test" => "true"}
      })

    assert %Product{} = created
    assert is_binary(created.id)

    {:ok, fetched} = Product.retrieve(client, created.id)
    assert %Product{} = fetched
    assert fetched.id == created.id
  end
end
```

**Lifecycle verb shape assertions to preserve** (quote unit lines 103-148):
```elixir
describe "finalize/4" do
  test "sends POST /v1/quotes/:id/finalize with raw params" do
    ...
    assert {:ok, %Quote{status: :open}} =
             Quote.finalize(client, "qt_test1234567890abc", %{"expires_at" => 1_700_086_400})
  end
end

describe "accept/3" do
  test "sends POST /v1/quotes/:id/accept with empty params" do
    ...
    assert {:ok, %Quote{status: :accepted}} =
             Quote.accept(client, "qt_test1234567890abc")
  end
end

describe "cancel/3" do
  test "sends POST /v1/quotes/:id/cancel with empty params" do
    ...
    assert {:ok, %Quote{status: :canceled}} =
             Quote.cancel(client, "qt_test1234567890abc")
  end
end
```

**PDF binary assertion pattern** (quote unit lines 230-247):
```elixir
describe "pdf/3" do
  test "returns raw binary from Client.download/3" do
    ...
    assert {:ok, "pdf-binary-data"} = Quote.pdf(client, "qt_test1234567890abc")
  end
end
```

**What to copy for Phase 41**
- Keep the existing module shell in [test/integration/quote_integration_test.exs](/Users/jon/projects/lattice_stripe/test/integration/quote_integration_test.exs:1); extend it rather than creating a new integration module.
- Add an audit-facing moduledoc like [test/integration/mandate_integration_test.exs](/Users/jon/projects/lattice_stripe/test/integration/mandate_integration_test.exs:2) so the suite explicitly says `stripe-mock` proves routing, binary transport, and typed decode sanity, not lifecycle semantics.
- Follow the credit-note style of building prerequisite resources through fixture helpers, then asserting `%Quote{}` and `is_binary(id)`.
- For the downstream follow-through hop, copy the create/retrieve structure from product or invoice tests: inspect `accepted.invoice` first, otherwise `subscription`, otherwise `subscription_schedule`, retrieve exactly one linked resource, and stop.
- Keep semantic status assertions in unit tests only. In integration, do not require `:open`, `:accepted`, or `:canceled` if `stripe-mock` keeps returning `:draft`.

---

### `test/support/fixtures/quote.ex` (test, transform)

**Primary analog:** [test/support/fixtures/credit_note.ex](/Users/jon/projects/lattice_stripe/test/support/fixtures/credit_note.ex:83)  
**Supporting analog:** current [test/support/fixtures/quote.ex](/Users/jon/projects/lattice_stripe/test/support/fixtures/quote.ex:178)

**Fixture helper that creates prerequisite Stripe resources first** (credit note lines 83-113):
```elixir
def create_creditable_invoice!(client, attrs \\ %{}) do
  {:ok, customer} =
    Customer.create(client, %{
      "email" => Map.get(attrs, "customer_email", "credit-note-test@example.com")
    })

  invoice_params =
    %{
      "customer" => customer.id,
      "auto_advance" => false,
      "collection_method" => "send_invoice",
      "days_until_due" => 30
    }
    |> Map.merge(Map.drop(attrs, ["customer_email", "invoice_item"]))

  {:ok, invoice} = Invoice.create(client, invoice_params)
  ...
  {:ok, finalized_invoice} = Invoice.finalize(client, invoice.id)
  finalized_invoice
end
```

**Secondary helper that wraps the main resource create call** (credit note lines 115-134):
```elixir
def create_open_invoice_credit_note!(client, attrs \\ %{}) do
  invoice = create_creditable_invoice!(client, attrs)

  params =
    %{
      "invoice" => invoice.id,
      "lines" => [
        %{
          "type" => "custom_line_item",
          "description" => "Open invoice credit",
          "quantity" => 1,
          "unit_amount" => 500
        }
      ]
    }
    |> Map.merge(Map.get(attrs, "credit_note", %{}))

  {:ok, credit_note} = CreditNote.create(client, params)
  credit_note
end
```

**Current quote helper that needs the same prerequisite-resource discipline** (quote lines 187-209):
```elixir
def create_quote!(client, attrs \\ %{}) do
  customer = create_quote_customer!(client, attrs)

  params =
    %{
      "customer" => customer.id,
      "line_items" => [
        %{
          "price_data" => %{
            "currency" => "usd",
            "product_data" => %{"name" => "Quote fixture product"},
            "unit_amount" => 2_000,
            "recurring" => %{"interval" => "month"}
          },
          "quantity" => 1
        }
      ]
    }
    |> Map.merge(Map.get(attrs, "quote", %{}))

  {:ok, quote} = Quote.create(client, params)
  quote
end
```

**What to copy for Phase 41**
- Preserve the existing `create_quote_customer!/2` -> `create_quote!/2` helper layering.
- Replace inline `price_data.product_data` integration payloads with the credit-note pattern of creating prerequisite resources first, then threading the created ID into the final create call.
- Keep `attrs` merging shallow and explicit: `Map.get(attrs, "quote", %{})` is already the right override seam.
- Limit fixture changes to evidence-enabling setup for current `stripe-mock` validation rules.

---

### `.planning/phases/36-quote/36-VERIFICATION.md` (test, batch)

**Primary analog:** [.planning/phases/35-mandate-setupattempt/35-VERIFICATION.md](/Users/jon/projects/lattice_stripe/.planning/phases/35-mandate-setupattempt/35-VERIFICATION.md:1)  
**Supporting analog:** [.planning/phases/39-credit-note-verification-closure/39-VERIFICATION.md](/Users/jon/projects/lattice_stripe/.planning/phases/39-credit-note-verification-closure/39-VERIFICATION.md:1)

**Closed verifier frontmatter** (phase 35 lines 1-8):
```yaml
---
phase: 35-mandate-setupattempt
verified: 2026-05-25T12:58:00Z
status: closed
score: 5/5
overrides_applied: 0
re_verification: false
---
```

**Goal Achievement / Observable Truths structure** (phase 35 lines 17-29):
```markdown
## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `35-VERIFICATION.md` now exists in a closed verifier state backed by fresh AUTH-scoped commands | VERIFIED | ... |
```

**Artifact Verification section** (phase 35 lines 31-40):
```markdown
### Artifact Verification

| Artifact | Status | Evidence |
|----------|--------|----------|
| `test/integration/mandate_integration_test.exs` | VERIFIED | Fresh Mandate retrieve route-sanity and typed `%LatticeStripe.Mandate{}` decode proof |
```

**Behavioral Spot-Checks + command/result table** (phase 35 lines 42-60):
```markdown
### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Mandate integration proof closes the missing audit gap | `mix test test/integration/mandate_integration_test.exs --include integration` | 1 test, 0 failures | PASS |

### Verification Evidence

| Command | Observed Result |
|---------|-----------------|
| `mix test test/integration/mandate_integration_test.exs --include integration` | Passed — `1 test, 0 failures` |
```

**Bounded stripe-mock wording** (phase 35 lines 62-69, phase 39 lines 47-54):
```markdown
`stripe-mock` evidence is intentionally bounded: these integration suites prove request routing, endpoint shape, and typed decode sanity against Stripe-shaped responses. They do not prove full persisted Stripe lifecycle semantics for Mandates or SetupAttempts.
```

```markdown
| CRDN-04 | List and stream issued line items | SATISFIED | `34-VERIFICATION.md`; parser plus unit coverage |
| CRDN-05 | List preview line items | SATISFIED | `34-VERIFICATION.md`; unit/integration coverage |
| CRDN-06 | Typed `CreditNote.LineItem` decoding | SATISFIED | `34-VERIFICATION.md`; Phase 34 parser summary and current unit assertions |
```

**What to copy for Phase 41**
- Use `status: closed`, not `passed`, because the phase is closing a prior feature phase.
- Keep the verifier QUOT-only. It should cover `QUOT-01` through `QUOT-05` and avoid DX, AUTH, or roadmap reconciliation.
- Include fresh Quote-scoped commands for both unit and integration proof, with the integration run explicitly citing `test/integration/quote_integration_test.exs --include integration`.
- Add an explicit scope note that `Quote.pdf/3` proof covers binary transport only and that `accept/3` follow-through proves one typed downstream retrieve at most.
- If `stripe-mock` still omits downstream references or realistic status transitions, document the reproduced limitation in the verifier instead of over-asserting semantics.

---

### `.planning/REQUIREMENTS.md` (config, transform)

**Primary analog:** current [.planning/REQUIREMENTS.md](/Users/jon/projects/lattice_stripe/.planning/REQUIREMENTS.md:42)  
**Supporting analog:** [.planning/phases/39-credit-note-verification-closure/39-VERIFICATION.md](/Users/jon/projects/lattice_stripe/.planning/phases/39-credit-note-verification-closure/39-VERIFICATION.md:45)

**Checkbox rows to flip only for Quote scope** (requirements lines 42-48):
```markdown
### Quotes & Proposals

- [ ] **QUOT-01**: Developer can create, retrieve, update, list quotes with auto-pagination via `stream!/3`
- [ ] **QUOT-02**: Developer can finalize, accept, and cancel quotes via explicit verbs
- [ ] **QUOT-03**: Developer can list and stream quote line items via `Quote.list_line_items/4` and `stream_line_items!/4`
- [ ] **QUOT-04**: Developer can download quote PDF as raw binary via `Quote.pdf/3`
- [ ] **QUOT-05**: Quote line items deserialize into typed `Quote.LineItem` struct
```

**Traceability rows to flip from `Pending` to `Verified`** (requirements lines 90-116):
```markdown
| QUOT-01 | Phase 41 | Pending |
| QUOT-02 | Phase 41 | Pending |
| QUOT-03 | Phase 41 | Pending |
| QUOT-04 | Phase 41 | Pending |
| QUOT-05 | Phase 41 | Pending |
```

**Requirement-coverage table style to mirror in the verifier** (phase 39 lines 45-54):
```markdown
### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| CRDN-01 | Create/retrieve/update/list/stream CreditNotes | SATISFIED | ... |
```

**What to copy for Phase 41**
- Check only `QUOT-01` through `QUOT-05` in the top requirements checklist.
- Flip only the five Quote traceability rows to `Verified`.
- Keep AUTH already closed and DX still pending.
- Use the same evidence language as the new `36-VERIFICATION.md` so the checkbox and traceability updates remain auditable.

## Shared Patterns

### stripe-mock Guard
**Source:** [test/integration/quote_integration_test.exs](/Users/jon/projects/lattice_stripe/test/integration/quote_integration_test.exs:11)  
**Apply to:** Quote integration module edits
```elixir
setup_all do
  case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
    {:ok, socket} ->
      :gen_tcp.close(socket)
      start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
      :ok

    {:error, _} ->
      raise "stripe-mock not running on localhost:12111 — start with: docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest"
  end
end
```

### Quote Lifecycle Surface
**Source:** [lib/lattice_stripe/quote.ex](/Users/jon/projects/lattice_stripe/lib/lattice_stripe/quote.ex:211)  
**Apply to:** integration assertions and verifier wording
```elixir
def finalize(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
  %Request{method: :post, path: "/v1/quotes/#{id}/finalize", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end

def accept(%Client{} = client, id, opts \\ []) when is_binary(id) do
  %Request{method: :post, path: "/v1/quotes/#{id}/accept", params: %{}, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end

def cancel(%Client{} = client, id, opts \\ []) when is_binary(id) do
  %Request{method: :post, path: "/v1/quotes/#{id}/cancel", params: %{}, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

### Binary PDF Proof
**Source:** [lib/lattice_stripe/quote.ex](/Users/jon/projects/lattice_stripe/lib/lattice_stripe/quote.ex:314)  
**Apply to:** `Quote.pdf/3` integration assertion and verifier scope note
```elixir
@doc """
Downloads a Quote PDF as raw binary.

This calls Stripe's binary PDF endpoint and unwraps the transport `%Response{}`
into `{:ok, binary}` at the resource layer.
"""
def pdf(%Client{} = client, id, opts \\ []) when is_binary(id) do
  case Client.download(client, "/v1/quotes/#{id}/pdf", opts) do
    {:ok, %Response{data: data}} when is_binary(data) -> {:ok, data}
    {:error, %Error{} = error} -> {:error, error}
  end
end
```

### Semantic Truth Stays in Unit Tests
**Source:** [test/lattice_stripe/quote_test.exs](/Users/jon/projects/lattice_stripe/test/lattice_stripe/quote_test.exs:263)  
**Apply to:** verifier caveats and integration-assertion boundaries
```elixir
assert Quote.from_map(quote_json(%{"status" => "draft"})).status == :draft
assert Quote.from_map(open_quote_json()).status == :open
assert Quote.from_map(accepted_quote_json()).status == :accepted
assert Quote.from_map(canceled_quote_json()).status == :canceled

quote = Quote.from_map(expanded_quote_json())
assert %Invoice{} = quote.invoice
assert %Subscription{} = quote.subscription
assert %SubscriptionSchedule{} = quote.subscription_schedule
```

### Scoped Closure-Phase Wording
**Source:** [.planning/phases/35-mandate-setupattempt/35-VERIFICATION.md](/Users/jon/projects/lattice_stripe/.planning/phases/35-mandate-setupattempt/35-VERIFICATION.md:71)  
**Apply to:** `36-VERIFICATION.md`
```markdown
### Gaps Summary

Phase 40 closes the exact prior audit gaps for the AUTH family:

- Missing `35-VERIFICATION.md`
- Missing Mandate integration coverage
- Stale/current AUTH evidence closure for milestone acceptance
```

## No Analog Found

None.

## Metadata

**Analog search scope:** `test/integration/`, `test/support/fixtures/`, `test/lattice_stripe/`, `lib/lattice_stripe/`, `.planning/phases/`, `.planning/REQUIREMENTS.md`  
**Files scanned:** 12  
**Pattern extraction date:** 2026-05-25
