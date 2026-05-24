# Phase 34: CreditNote - Pattern Map

**Mapped:** 2026-05-24
**Files analyzed:** 8
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/lattice_stripe/credit_note.ex` | service | request-response | `lib/lattice_stripe/invoice.ex` | exact |
| `lib/lattice_stripe/credit_note/line_item.ex` | model | transform | `lib/lattice_stripe/invoice/line_item.ex` | exact |
| `lib/lattice_stripe/object_types.ex` | config | transform | `lib/lattice_stripe/object_types.ex` | exact |
| `mix.exs` | config | transform | `mix.exs` | exact |
| `test/support/fixtures/credit_note.ex` | test | transform | `test/support/fixtures/dispute.ex` | role-match |
| `test/lattice_stripe/credit_note_test.exs` | test | request-response | `test/lattice_stripe/invoice_test.exs` | exact |
| `test/integration/credit_note_integration_test.exs` | test | request-response | `test/integration/invoice_integration_test.exs` | exact |
| `test/lattice_stripe/object_types_test.exs` | test | transform | `test/lattice_stripe/object_types_test.exs` | exact |

## Pattern Assignments

### `lib/lattice_stripe/credit_note.ex` (service, request-response)

**Primary analog:** `lib/lattice_stripe/invoice.ex`
**Supporting analogs:** `lib/lattice_stripe/dispute.ex`, `lib/lattice_stripe/checkout/session.ex`

**Imports and module shape** (`lib/lattice_stripe/invoice.ex:57-58`)
```elixir
alias LatticeStripe.{Billing, Client, Error, List, ObjectTypes, Request, Resource, Response, Telemetry}
alias LatticeStripe.Invoice.{AutomaticTax, LineItem, StatusTransitions}
```

Copy the alias style: one top-level alias tuple plus one nested alias tuple. For `CreditNote`, replace `Billing/Telemetry/StatusTransitions` with only what the module actually uses; do not introduce local helper modules unless the parser needs them.

**CRUDL request pipeline** (`lib/lattice_stripe/invoice.ex:288-292`, `321-325`, `345-349`, `395-399`, `lib/lattice_stripe/dispute.ex:122-125`)
```elixir
%Request{method: :post, path: "/v1/invoices", params: params, opts: opts}
|> then(&Client.request(client, &1))
|> Resource.unwrap_singular(&from_map/1)

%Request{method: :get, path: "/v1/invoices/#{id}", params: %{}, opts: opts}
|> then(&Client.request(client, &1))
|> Resource.unwrap_singular(&from_map/1)

%Request{method: :get, path: "/v1/invoices", params: params, opts: opts}
|> then(&Client.request(client, &1))
|> Resource.unwrap_list(&from_map/1)

req = %Request{method: :get, path: "/v1/disputes", params: params, opts: opts}
List.stream!(client, req) |> Stream.map(&from_map/1)
```

Use this unchanged pipeline for `create/3`, `retrieve/3`, `update/4`, `list/3`, and `stream!/3`.

**Preview + nested list helper pattern** (`lib/lattice_stripe/invoice.ex:722-786`, `818-860`, `lib/lattice_stripe/checkout/session.ex:477-519`, `569-573`)
```elixir
%Request{method: :post, path: "/v1/invoices/create_preview", params: params, opts: opts}
|> then(&Client.request(client, &1))
|> Resource.unwrap_singular(&from_map/1)

%Request{
  method: :get,
  path: "/v1/invoices/create_preview/lines",
  params: params,
  opts: opts
}
|> then(&Client.request(client, &1))
|> Resource.unwrap_list(&LineItem.from_map/1)

def list_line_items!(%Client{} = client, invoice_id, params \\ %{}, opts \\ [])
    when is_binary(invoice_id),
    do: client |> list_line_items(invoice_id, params, opts) |> Resource.unwrap_bang!()

req = %Request{
  method: :get,
  path: "/v1/checkout/sessions/#{session_id}/line_items",
  params: params,
  opts: opts
}

List.stream!(client, req) |> Stream.map(&LineItem.from_map/1)
```

For `CreditNote`, rename the preview surface per decisions:
- `preview/3` follows the `create_preview/3` body shape, but hits `/v1/credit_notes/preview`
- `list_preview_line_items/3`, `list_preview_line_items!/3`, `stream_preview_line_items!/3` follow the `create_preview_lines/3` and `Checkout.Session` nested stream pattern
- `list_line_items/4`, `list_line_items!/4`, `stream_line_items!/4` copy the issued-line-items pattern directly

**Irreversible action verb** (`lib/lattice_stripe/dispute.ex:184-205`)
```elixir
@doc """
Closes a Dispute by accepting the loss.

Sends `POST /v1/disputes/:id/close` with an empty body.

## Irreversibility
...
"""
def close(%Client{} = client, id, opts \\ []) when is_binary(id) do
  %Request{method: :post, path: "/v1/disputes/#{id}/close", params: %{}, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

Copy this doc structure for `CreditNote.void/3`: dedicated verb, empty `%{}` params, dedicated `## Irreversibility` section, and explicit invoice-state warning in the docs.

**Top-level parser and embedded line list** (`lib/lattice_stripe/invoice.ex:927-1028`)
```elixir
{known, extra} = Map.split(map, @known_fields)

%__MODULE__{
  id: known["id"],
  object: known["object"] || "invoice",
  customer:
    (if is_map(known["customer"]),
       do: ObjectTypes.maybe_deserialize(known["customer"]),
       else: known["customer"]),
  lines: parse_lines(known["lines"]),
  status: atomize_status(known["status"]),
  extra: extra
}
```

This is the direct parser model for `CreditNote.from_map/1`: `Map.split/2`, explicit field assignment, `ObjectTypes.maybe_deserialize/1` for expandables, `parse_lines/1` for embedded list data, atomization helpers with string pass-through, and `extra` for forward compatibility.

### `lib/lattice_stripe/credit_note/line_item.ex` (model, transform)

**Analog:** `lib/lattice_stripe/invoice/line_item.ex`

**Known fields + struct shape** (`lib/lattice_stripe/invoice/line_item.ex:52-87`)
```elixir
@known_fields ~w[
  id object amount amount_excluding_tax currency description
  discount_amounts discountable discounts invoice invoice_item
  livemode metadata period plan price proration proration_details
  quantity subscription subscription_item tax_amounts tax_rates
  type unit_amount_excluding_tax
]

defstruct [
  :id,
  :amount,
  ...
  :type,
  object: "line_item",
  extra: %{}
]
```

Use this exact module layout: `@known_fields`, `defstruct`, `@type`, `from_map/1`, then `Inspect`. Replace the invoice-specific fields with Stripe credit-note line-item fields, but keep `type` as a string and preserve `extra`.

**Parser pattern** (`lib/lattice_stripe/invoice/line_item.ex:145-179`)
```elixir
def from_map(nil), do: nil

def from_map(map) when is_map(map) do
  {known, extra} = Map.split(map, @known_fields)

  %__MODULE__{
    id: known["id"],
    object: known["object"] || "line_item",
    amount: known["amount"],
    ...
    type: known["type"],
    extra: extra
  }
end
```

Copy this directly for `CreditNote.LineItem.from_map/1`. Do not atomize `type`.

**Inspect pattern** (`lib/lattice_stripe/invoice/line_item.ex:182-212`)
```elixir
base_fields = [
  id: item.id,
  object: item.object,
  amount: item.amount,
  currency: item.currency,
  description: item.description,
  type: item.type
]
```

Use the same compact inspect strategy if a custom inspect is kept.

### `lib/lattice_stripe/object_types.ex` (config, transform)

**Analog:** `lib/lattice_stripe/object_types.ex`

**Registry insertion pattern** (`lib/lattice_stripe/object_types.ex:4-39`)
```elixir
@object_map %{
  "dispute" => LatticeStripe.Dispute,
  "file" => LatticeStripe.File,
  "file_link" => LatticeStripe.FileLink,
  "invoice" => LatticeStripe.Invoice,
  ...
  "checkout.session" => LatticeStripe.Checkout.Session,
  "line_item" => LatticeStripe.Invoice.LineItem
}
```

Add:
- `"credit_note" => LatticeStripe.CreditNote`
- `"credit_note_line_item" => LatticeStripe.CreditNote.LineItem`

Keep the map sorted in the existing style; append the test-clock and line-item style consistently rather than creating a second registry.

**Dispatch behavior** (`lib/lattice_stripe/object_types.ex:45-56`)
```elixir
def maybe_deserialize(nil), do: nil
def maybe_deserialize(val) when is_binary(val), do: val

def maybe_deserialize(%{"object" => object_type} = map) do
  case Map.fetch(@object_map, object_type) do
    {:ok, module} -> module.from_map(map)
    :error -> map
  end
end
```

No behavior change is needed; only registry entries plus tests.

### `mix.exs` (config, transform)

**Analog:** `mix.exs`

**Billing ExDoc group placement** (`mix.exs:52-95`)
```elixir
groups_for_modules: [
  ...
  Billing: [
    LatticeStripe.Invoice,
    LatticeStripe.Invoice.LineItem,
    LatticeStripe.Invoice.StatusTransitions,
    LatticeStripe.Invoice.AutomaticTax,
    LatticeStripe.InvoiceItem,
    LatticeStripe.InvoiceItem.Period,
    LatticeStripe.Subscription,
    ...
  ],
  ...
]
```

Place `LatticeStripe.CreditNote` and `LatticeStripe.CreditNote.LineItem` in the existing `Billing` group next to `Invoice` and `Invoice.LineItem`. Do not create a new ExDoc group for CreditNote.

### `test/support/fixtures/credit_note.ex` (test, transform)

**Primary analog:** `test/support/fixtures/dispute.ex`
**Supporting analogs:** `test/support/fixtures/file.ex`, `test/support/fixtures/file_link.ex`, `test/integration/invoice_integration_test.exs`

**Static fixture module shape** (`test/support/fixtures/dispute.ex:1-30`)
```elixir
defmodule LatticeStripe.Test.Fixtures.Dispute do
  @moduledoc false

  def dispute_json(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "dp_test1234567890abc",
        "object" => "dispute",
        ...
      },
      overrides
    )
  end
end
```

Credit-note fixtures should follow this module pattern: one top-level JSON builder plus focused helpers for nested objects.

**Variant helper pattern** (`test/support/fixtures/file.ex:24-45`, `test/support/fixtures/file_link.ex:22-33`)
```elixir
def with_links(overrides \\ %{}) do
  links = %{"object" => "list", "data" => [...], "has_more" => false, "url" => "..."}
  basic(Map.merge(%{"links" => links}, overrides))
end

def with_expanded_file(overrides \\ %{}) do
  expanded = %{"id" => "file_test123", "object" => "file", ...}
  basic(Map.merge(%{"file" => expanded}, overrides))
end
```

Use this pattern for:
- issued credit-note fixture
- embedded `lines` fixture
- `"invoice_line_item"` variant
- `"custom_line_item"` variant
- expanded `invoice` / `customer` variants as needed

**Operational helper seed** (`test/integration/invoice_integration_test.exs:103-117`)
```elixir
{:ok, draft} =
  Invoice.create(client, %{
    "customer" => customer.id,
    "auto_advance" => false,
    "collection_method" => "send_invoice",
    "days_until_due" => 30
  })

result = Invoice.finalize(client, draft.id)
```

There is no exact fixture analog for “creditable invoice” setup. Planner should combine the static fixture-module pattern above with a live helper that creates an invoice and finalizes it before credit-note calls.

### `test/lattice_stripe/credit_note_test.exs` (test, request-response)

**Primary analog:** `test/lattice_stripe/invoice_test.exs`
**Supporting analogs:** `test/lattice_stripe/dispute_test.exs`, `test/lattice_stripe/checkout/session_test.exs`

**Parser coverage pattern** (`test/lattice_stripe/invoice_test.exs:67-304`, `test/lattice_stripe/dispute_test.exs:153-242`)
```elixir
describe "from_map/1" do
  test "returns nil when given nil" do
    assert Invoice.from_map(nil) == nil
  end

  test "passes through unknown status as string" do
    invoice = Invoice.from_map(invoice_json(%{"status" => "future_status"}))
    assert invoice.status == "future_status"
  end

  test "parses lines as List struct when present" do
    ...
    assert %List{data: [%LineItem{id: "il_test123"}]} = invoice.lines
  end
end
```

Copy this organization for `CreditNote.from_map/1` coverage:
- nil handling
- known enum atomization and unknown string pass-through
- embedded `lines` parsing into `%List{}`
- expandable `customer`, `invoice`, `customer_balance_transaction`
- `extra` preservation
- both line-item subtypes via fixture helpers

**Preview and preview-line request assertions** (`test/lattice_stripe/invoice_test.exs:744-829`)
```elixir
describe "create_preview/3" do
  test "sends POST /v1/invoices/create_preview ..." do
    expect(LatticeStripe.MockTransport, :request, fn req ->
      assert req.method == :post
      assert String.ends_with?(req.url, "/v1/invoices/create_preview")
      ...
    end)
  end
end

describe "create_preview_lines/3" do
  test "sends GET /v1/invoices/create_preview/lines ..." do
    ...
  end
end
```

Translate this to:
- `preview/3` hitting `GET /v1/credit_notes/preview`
- `list_preview_line_items/3` hitting `GET /v1/credit_notes/preview/lines`
- bang variants returning `%CreditNote{}` / `%Response{}`

**Nested line-item list and stream tests** (`test/lattice_stripe/checkout/session_test.exs:311-359`, `461-472`, `test/lattice_stripe/invoice_test.exs:836-870`)
```elixir
assert String.ends_with?(req.url, "/v1/checkout/sessions/.../line_items")
assert {:ok, %Response{data: %List{data: [%LineItem{}]}}} = ...

results = Session.stream_line_items!(client, "cs_test1234567890abc") |> Enum.to_list()
assert [%LineItem{...}] = results
```

Use this structure for:
- `list_line_items/4`
- `list_line_items!/4`
- `stream_line_items!/4`
- `list_preview_line_items!/3`
- `stream_preview_line_items!/3`

**Void action assertion** (`test/lattice_stripe/dispute_test.exs:138-150`)
```elixir
expect(LatticeStripe.MockTransport, :request, fn req ->
  assert req.method == :post
  assert String.ends_with?(req.url, "/v1/disputes/dp_test1234567890abc/close")
  assert req.body in [nil, ""]
  ...
end)
```

Copy this exactly for `CreditNote.void/3`, changing the path to `/v1/credit_notes/:id/void`.

### `test/integration/credit_note_integration_test.exs` (test, request-response)

**Analog:** `test/integration/invoice_integration_test.exs`

**Integration module structure** (`test/integration/invoice_integration_test.exs:1-27`)
```elixir
defmodule LatticeStripe.InvoiceIntegrationTest do
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  setup_all do
    case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
        :ok
      {:error, _} ->
        raise "stripe-mock not running ..."
    end
  end

  setup do
    {:ok, client: test_integration_client()}
  end
end
```

Reuse this shell exactly.

**Lifecycle-style tests** (`test/integration/invoice_integration_test.exs:29-135`)
```elixir
test "create/3 returns an Invoice struct", %{client: client} do
  {:ok, customer} = Customer.create(client, %{"email" => "invoice-test@example.com"})
  {:ok, invoice} = Invoice.create(client, %{...})
  assert %Invoice{} = invoice
end

test "list_line_items/4 returns a Response with a List", %{client: client} do
  ...
  {:ok, resp} = Invoice.list_line_items(client, invoice.id)
  assert %LatticeStripe.Response{} = resp
  assert %LatticeStripe.List{} = resp.data
end
```

Credit-note integration tests should follow the same direct “real route, assert struct/response shell” style. Add a dedicated helper for finalized invoices before `create/3` and a separate open-invoice setup for `void/3`.

### `test/lattice_stripe/object_types_test.exs` (test, transform)

**Analog:** `test/lattice_stripe/object_types_test.exs`

**Dispatch test pattern** (`test/lattice_stripe/object_types_test.exs:16-49`)
```elixir
test "dispatches invoice map to Invoice.from_map/1" do
  map = %{"object" => "invoice", "id" => "in_123", "status" => "open"}
  result = ObjectTypes.maybe_deserialize(map)
  assert %LatticeStripe.Invoice{id: "in_123"} = result
end

test "returns unknown object types as raw map" do
  map = %{"object" => "unknown_future_type", "id" => "foo_123"}
  assert ObjectTypes.maybe_deserialize(map) == map
end
```

Add one test for `"credit_note"` and one for `"credit_note_line_item"`. Keep the unknown-object raw-map test unchanged.

## Shared Patterns

### Request/unwrap pipeline
**Sources:** `lib/lattice_stripe/invoice.ex:288-292`, `321-325`, `395-399`; `lib/lattice_stripe/dispute.ex:122-125`

All public resource functions should build `%Request{}` structs, call `Client.request/2`, then unwrap with either `Resource.unwrap_singular/1` or `Resource.unwrap_list/1`. Streams should build `req` once and pipe through `List.stream!/2`.

### Nested paginated sub-resources
**Sources:** `lib/lattice_stripe/invoice.ex:816-860`; `lib/lattice_stripe/checkout/session.ex:477-519`, `569-573`

Nested collections use:
- `list_*` returning `{:ok, %Response{data: %List{data: [%TypedStruct{}]}}}`
- `list_*!` wrapping `Resource.unwrap_bang!/1`
- `stream_*` creating a `req` and mapping `List.stream!/2` over the typed parser

### Irreversible action docs
**Source:** `lib/lattice_stripe/dispute.ex:184-205`

Explicit destructive verbs get:
- a dedicated function name
- empty POST params
- a `## Irreversibility` doc section
- a bang variant with no extra logic

### Expandable deserialization
**Sources:** `lib/lattice_stripe/invoice.ex:947-957`, `990-1012`; `lib/lattice_stripe/object_types.ex:45-56`

Expanded related objects should pass through `ObjectTypes.maybe_deserialize/1`; string IDs and nil stay unchanged.

### Forward-compatible enum handling
**Sources:** `lib/lattice_stripe/invoice.ex:1007`, `1035-1045`; `lib/lattice_stripe/dispute.ex:230-231`, `253-280`; `test/lattice_stripe/invoice_test.exs:82-169`

Atomize only the known top-level enums. Unknown values remain strings. Mirror that test pattern for every atomized `CreditNote` field.

### Test organization
**Sources:** `test/lattice_stripe/invoice_test.exs:67-304`, `744-870`; `test/lattice_stripe/dispute_test.exs:138-242`; `test/integration/invoice_integration_test.exs:1-144`

Unit tests stay in `test/lattice_stripe/*_test.exs` with `describe` blocks per function family. Integration tests stay in `test/integration/*_integration_test.exs`, are `async: false`, boot Finch in `setup_all`, and assert only route/shape behavior that stripe-mock can reliably enforce.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `test/support/fixtures/credit_note.ex` helper for “creditable invoice” setup | test | request-response | No existing fixture module performs live invoice finalization/open-invoice preparation; combine static fixture modules with the setup steps in `test/integration/invoice_integration_test.exs:103-117` |

## Metadata

**Analog search scope:** `lib/lattice_stripe`, `test/lattice_stripe`, `test/integration`, `test/support/fixtures`, `mix.exs`
**Files scanned:** 14
**Pattern extraction date:** 2026-05-24
