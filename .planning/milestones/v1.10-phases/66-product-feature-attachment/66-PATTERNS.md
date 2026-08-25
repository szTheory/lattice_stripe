# Phase 66: Product ↔ Feature Attachment - Pattern Map

**Mapped:** 2026-08-25  
**Files analyzed:** 12  
**Analogs found:** 12 / 12

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/lattice_stripe/product/feature.ex` | resource/model | request-response, CRUD, streaming, transform | `lib/lattice_stripe/transfer_reversal.ex`; `lib/lattice_stripe/entitlements/feature.ex` | exact composite |
| `lib/lattice_stripe/object_types.ex` | config/dispatcher | transform | `lib/lattice_stripe/object_types.ex` | exact extension |
| `lib/lattice_stripe/product.ex` | model/resource | transform | `lib/lattice_stripe/product.ex` | exact regression-preservation |
| `mix.exs` | config | batch/docs build | `mix.exs` `groups_for_modules` | exact extension |
| `test/lattice_stripe/product/feature_test.exs` | test | request-response, CRUD | `test/lattice_stripe/transfer_reversal_test.exs`; `test/lattice_stripe/entitlements/feature_test.exs` | exact composite |
| `test/lattice_stripe/product/feature_stream_test.exs` | test | streaming | `test/lattice_stripe/entitlements/active_entitlement_stream_test.exs` | exact |
| `test/lattice_stripe/product_test.exs` | test | transform | `test/lattice_stripe/product_test.exs` | exact extension |
| `test/lattice_stripe/object_types_test.exs` | test | transform | `test/lattice_stripe/object_types_test.exs` | exact extension |
| `test/lattice_stripe/docs_truth_test.exs` | test | batch/docs validation | `test/lattice_stripe/docs_truth_test.exs` | exact extension |
| `priv/api/current.txt` | API-surface lock | batch/transform | `test/lattice_stripe/api_surface_lock_test.exs` | exact generated lock |
| `guides/entitlements.md` | documentation | request-response journey | `guides/entitlements.md` | exact replacement |
| `guides/user-flows-and-jtbd.md` | documentation | event-driven routing | `guides/user-flows-and-jtbd.md` | exact extension |

## Pattern Assignments

### `lib/lattice_stripe/product/feature.ex` (resource/model; request-response, CRUD, streaming, transform)

**Primary analog:** `lib/lattice_stripe/transfer_reversal.ex`  
**Decoder/API analogue:** `lib/lattice_stripe/entitlements/feature.ex`

**Imports and canonical scoped path** — `entitlements/feature.ex:79-86`:

```elixir
alias LatticeStripe.{Client, Request, Resource}

@list_path "/v1/entitlements/features"
@known_fields ~w(id object active lookup_key name metadata livemode)
```

Use a private parent-aware `list_path(product_id)` once, and derive the item path from it. Do not duplicate scoped URL literals across verbs. The analogous two-ID requests use the parent as the argument immediately after `client`.

**Parent and child pre-network guards** — `transfer_reversal.ex:123-138`, `155-175`:

```elixir
def create(%Client{}, id, _params, _opts) when id in [nil, ""] do
  raise ArgumentError, ~s|TransferReversal.create/4 requires a non-empty transfer id|
end

def retrieve(%Client{}, _transfer_id, id, _opts) when id in [nil, ""] do
  raise ArgumentError, ~s|TransferReversal.retrieve/4 requires a non-empty reversal id|
end
```

Implement this eager guard shape for `product_id` on all verbs and `product_feature_id` on retrieve/delete. Create must additionally call `Resource.require_param!/3` for the string key `"entitlement_feature"` before constructing its request.

**Required Stripe wire param and response wrapper** — `entitlements/feature.ex:136-158`:

```elixir
Resource.require_param!(params, "lookup_key", "LatticeStripe.Entitlements.Feature.create/3 requires a lookup_key param")

%Request{method: :post, path: @list_path, params: params, opts: opts}
|> then(&Client.request(client, &1))
|> Resource.unwrap_singular(&from_map/1)

def create!(client, params, opts \\ []),
  do: client |> create(params, opts) |> Resource.unwrap_bang!()
```

For Phase 66, `params` has no default and the required-message must name `Product.Feature.create/4`; preserve options unchanged. Use `unwrap_singular/2` for create/retrieve/delete, `unwrap_list/2` for list, and `unwrap_bang!/1` for each ordinary bang twin.

**List and stream delegation** — `transfer_reversal.ex:227-274`:

```elixir
%Request{method: :get, path: "/v1/transfers/#{transfer_id}/reversals", params: params, opts: opts}
|> then(&Client.request(client, &1))
|> Resource.unwrap_list(&from_map/1)

req = %Request{method: :get, path: "/v1/transfers/#{transfer_id}/reversals", params: params, opts: opts}
List.stream!(client, req) |> Stream.map(&from_map/1)
```

`stream!/4` must validate before returning a lazy stream and delegate cursor mechanics exactly once to `LatticeStripe.List.stream!/2`; it has no non-bang twin.

**Nested, nil-safe, idempotent decoder** — `entitlements/feature.ex:282-306`:

```elixir
def from_map(nil), do: nil
def from_map(%__MODULE__{} = feature), do: feature

def from_map(map) when is_map(map) do
  {known, extra} = Map.split(map, @known_fields)
  %__MODULE__{id: known["id"], object: known["object"] || "entitlements.feature", extra: extra}
end
```

The struct clause must precede `is_map/1`. For the attachment, map `entitlement_feature:` with `LatticeStripe.Entitlements.Feature.from_map(known["entitlement_feature"])`, set `object: "product_feature"`, `deleted: false`, and preserve all unknown top-level fields in `extra`. Do not use generic `ObjectTypes` for this known nested relationship.

**Typed delete response/default** — `lib/lattice_stripe/tax_id.ex:336-352`:

```elixir
{known, extra} = Map.split(map, @known_fields)
%__MODULE__{
  id: known["id"],
  object: known["object"] || "tax_id",
  deleted: known["deleted"] || false,
  extra: extra
}
```

The deleted endpoint remains a typed attachment response, retaining `id` and `object`; omitted live-object fields stay nil.

---

### `lib/lattice_stripe/object_types.ex` (config/dispatcher; transform)

**Analog:** `lib/lattice_stripe/object_types.ex:4-58, 70-85`

**Exact-byte registry and dispatch**:

```elixir
@object_map %{
  "product" => LatticeStripe.Product,
  "entitlements.active_entitlement" => LatticeStripe.Entitlements.ActiveEntitlement
}

def fetch_module(type) when is_binary(type), do: Map.fetch(@object_map, type)

def maybe_deserialize(%{"object" => object_type} = map) do
  case Map.fetch(@object_map, object_type) do
    {:ok, module} -> module.from_map(map)
    :error -> map
  end
end
```

Add exactly `"product_feature" => LatticeStripe.Product.Feature`. Do not normalize, trim, dot-convert, or add `"product.feature"`; unknown discriminator maps remain raw. The registry affects `Webhook.fetch_related_object/3`, so preserve the existing per-row triage discipline.

---

### `lib/lattice_stripe/product.ex` (model/resource; transform)

**Analog:** `lib/lattice_stripe/product.ex:51-54, 101-104, 399-424`

```elixir
@known_fields ~w[ ... description features images livemode marketing_features metadata ...]

features: map["features"],
marketing_features: map["marketing_features"],
extra: Map.drop(map, @known_fields)
```

Keep both fields independently assigned raw wire values (`[map()] | nil`); do not invoke `Product.Feature.from_map/1`, copy between fields, normalize, or alter the existing retrieve/list/stream/search shapes. Only add the Product moduledoc cross-link/marketing distinction if needed for D-20.

---

### `mix.exs` (config; docs build)

**Analog:** `mix.exs:130-166`

```elixir
Billing: [
  ~r/^LatticeStripe\.(Invoice|...|Product|PromotionCode)($|\.)/
],
Entitlements: [~r/^LatticeStripe\.Entitlements($|\.)/],
```

Because first matching ExDoc group wins, add an exact `LatticeStripe.Product.Feature` entry to **Entitlements before Billing**. Do not broaden the Entitlements regex to `Product.*` or relocate the remaining Product namespace.

---

### `test/lattice_stripe/product/feature_test.exs` (test; request-response, CRUD)

**Analog:** `test/lattice_stripe/transfer_reversal_test.exs:19-105`; `test/lattice_stripe/entitlements/feature_test.exs:319-410`

**Mox request assertion**:

```elixir
expect(LatticeStripe.MockTransport, :request, fn req ->
  assert req.method == :post
  assert String.ends_with?(req.url, "/v1/transfers/#{@transfer_id}/reversals")
  assert req.body =~ "amount=500"
  ok_response(transfer_reversal_json())
end)
```

Use one focused Mox module with `setup :verify_on_exit!`; assert POST collection, GET collection, GET item, DELETE item, URL scopes, encoded `entitlement_feature`, per-request options, tuple error response, bang return/raise, and typed singular/list/deleted results. Guard tests intentionally register **no expectation**, proving validation happens before the transport.

**Decoder and API-prohibition locks** — `entitlements/feature_test.exs:319-347, 355-410`:

```elixir
once = Feature.from_map(Entitlements.feature_json())
assert Feature.from_map(once) == once

refute function_exported?(Feature, :stream, 1)
refute function_exported?(Feature, :stream, 2)
refute function_exported?(Feature, :stream, 3)
```

Lock every required/defaulted exported arity for the new surface, then refute all arities of `stream`, `attach`, `detach`, `remove`, and any delete-by-feature/lookup convenience. Assert nested `entitlement_feature` is `%LatticeStripe.Entitlements.Feature{}` and identity examples keep `feat_...` distinct from `prodft_...`.

---

### `test/lattice_stripe/product/feature_stream_test.exs` (test; streaming)

**Analog:** `test/lattice_stripe/entitlements/active_entitlement_stream_test.exs:27-52, 60-107, 130-166, 206-266`

**Hand-authored multi-page seam**:

```elixir
LatticeStripe.MockTransport
|> expect(:request, fn req ->
  assert req.url =~ "customer=cus_123"
  list_response([entitlement("ent_a"), entitlement("ent_b")], true)
end)
|> expect(:request, fn req ->
  assert req.url =~ "customer=cus_123"
  assert req.url =~ "starting_after=ent_b"
  list_response([entitlement("ent_c")], false)
end)
```

Use raw JSON list pages so `List.from_json/3` captures the last raw `prodft_...` id before the resource maps to structs. Prove page 2 retains product path, limit/filter/expand params and Connect header; results remain typed/in order; `Stream.take(1)` makes one request; an idempotency key is absent on page 2; and page-two 500 raises `LatticeStripe.Error` rather than yielding a partial catalog.

---

### `test/lattice_stripe/product_test.exs` (test; transform)

**Analog:** `test/lattice_stripe/product_test.exs:6-48` plus `lib/lattice_stripe/product.ex:399-424`

```elixir
p = Product.from_map(%{"id" => "prod_1", "object" => "product", "name" => "T"})
assert p.id == "prod_1"
```

Extend `from_map/1` tests with separate legacy `features` and current `marketing_features` payload maps. Assert the original raw string-key maps survive independently (no copying, no `%Product.Feature{}` conversion), and separately test the new attachment decoder graph in its focused test file.

---

### `test/lattice_stripe/object_types_test.exs` (test; transform)

**Analog:** `test/lattice_stripe/object_types_test.exs:307-332`

```elixir
assert ObjectTypes.fetch_module("entitlements.active_entitlement") ==
         {:ok, LatticeStripe.Entitlements.ActiveEntitlement}

assert ObjectTypes.fetch_module("Billing.meter_event") == :error
```

Add direct key-level assertions for `"product_feature"`, `maybe_deserialize/1` returning `%Product.Feature{}`, and `"product.feature"` rejected by `fetch_module/1`/left raw. Do not assert total `object_map` size.

---

### `test/lattice_stripe/docs_truth_test.exs` (test; batch/docs validation)

**Analog:** `test/lattice_stripe/docs_truth_test.exs:611-668`

```elixir
assert docs_group_of(LatticeStripe.Entitlements.Feature) == :Entitlements
assert guide =~ "Scope boundary"
assert guide =~ "entitled?"
assert guide =~ "fail closed"
```

Extend this single semantic lock: require `Product.Feature` to group under Entitlements; load its source alongside the other entitlement modules for guide cross-link checks; lock durable anchors rather than paragraphs — all five verbs, `prodft_`, marketing-feature distinction, webhook/reconcile boundary, and the no-`entitled?`/fail-closed fence.

---

### `priv/api/current.txt` (API-surface lock; batch/transform)

**Analog:** `test/lattice_stripe/api_surface_lock_test.exs:20-32`; existing `priv/api/current.txt:1265-1296`

```elixir
expected = ApiSurface.lock_path() |> File.read!() |> ApiSurface.parse()
actual = ApiSurface.lines()

case ApiSurface.diff(expected, actual) do
  {[], []} -> :ok
  {removed, added} -> flunk(ApiSurface.format_diff(removed, added))
end
```

Generate/update this lock only through the project API-surface command after the public module exists. Review that the entries represent only the locked struct fields, `t/0`, `from_map/1`, required canonical verbs and their default-argument arities; no alias or non-bang stream may enter.

---

### `guides/entitlements.md` (documentation; request-response journey)

**Analog:** `guides/entitlements.md:13-76, 181-248`

```markdown
1. **Reconcile** when the `entitlements.active_entitlement_summary.updated`
   webhook fires ... enumerate it fully.
2. **Persist** ... alongside a `reconciled_at` timestamp.
3. **Gate locally** on every request. Authorization reads your store, never the network.
4. **Fail closed on staleness.**
```

Replace, rather than append to, both stale attachment placeholders. Preserve the relationship diagram and progressive sequence: definition `feat_...` + Product `prod_...` → attachment `prodft_...` → purchase-derived `ent_...` → webhook-driven reconciliation/local fail-closed gate. Teach `Product.Feature.list/4`/`stream!/4` as authoritative catalog reads and explicitly distinguish raw pricing-table `Product.marketing_features` / legacy `Product.features`; do not imply an attachment or Checkout return synchronously updates local authorization.

---

### `guides/user-flows-and-jtbd.md` (documentation; event-driven routing)

**Analog:** `guides/user-flows-and-jtbd.md:78-96`

```markdown
- **Usage-based billing and reconciliation**:
  [Metering Runtime and Reconciliation](metering-runtime-and-reconciliation.md),
  [Metering](metering.md), [Webhooks](webhooks.md), [Testing](testing.md)
```

Add one concise catalog/access route using the same link-list form: Entitlements → Subscriptions/Checkout → Webhooks → Testing. It is discovery only, not a duplicated guide or app workflow.

## Shared Patterns

### Parent-scoped validation and request composition

**Sources:** `lib/lattice_stripe/transfer_reversal.ex:123-175, 227-274`  
**Apply to:** `Product.Feature` and focused Mox tests.

Validate non-empty parent and child IDs before requests; compose only the parent-scoped collection path plus child suffix. Every verb retains caller `opts`.

### Cursor pagination preserves raw IDs, scope, and options

**Source:** `lib/lattice_stripe/list.ex:123-140, 224-284`  
**Apply to:** `Product.Feature.stream!/4`, stream test.

```elixir
_last_id: last_item_id(items)
base_params = Map.drop(list._params, ["starting_after", "ending_before", "page"])
opts = Keyword.delete(list._opts, :idempotency_key)
%Request{method: :get, path: list.url, params: Map.merge(base_params, pagination_params), opts: opts}
```

Pass raw pages into `List.stream!/2` and type only downstream. This preserves the `prodft_...` cursor, parent URL, filters and Connect request options, while deliberately stripping idempotency on follow-up GETs.

### Exact object dispatch

**Source:** `lib/lattice_stripe/object_types.ex:70-85`  
**Apply to:** registry implementation and ObjectTypes test.

Dispatch uses `Map.fetch/2` on literal wire bytes. Tests must protect both exact acceptance and typo rejection; adding a registry key changes webhook related-object behavior, so it needs direct coverage.

### Docs and API locks are executable evidence

**Sources:** `test/lattice_stripe/docs_truth_test.exs:114-174, 611-668`; `test/lattice_stripe/api_surface_lock_test.exs:20-32`; `.agents/skills/lattice-verification-policy/SKILL.md`.

Use named assertions/commands as verification, not a human-only claim: focused Mox tests prove HTTP and error paths; docs-truth proves ExDoc placement and semantic anchors; `api_surface_lock_test.exs` plus `priv/api/current.txt` proves published module/function/arity/struct/type changes. The only potential human decision is accepting the one-way new public API name/shape, already locked by D-01/D-02; all other runtime and prose requirements must be executable checks.

## No Analog Found

None. This phase is entirely an extension of existing resource, pagination, decoder, registry, compatibility, and documentation-lock patterns.

## Metadata

**Analog search scope:** `lib/lattice_stripe`, `test/lattice_stripe`, `guides`, `mix.exs`, `priv/api`  
**Files scanned:** 335 tracked source/test/doc/API files (plus phase context/research)  
**Pattern extraction date:** 2026-08-25
