# Phase 66: Product ↔ Feature Attachment - Research

**Researched:** 2026-08-25
**Domain:** Stripe Product Feature attachment API in a public Elixir HTTP library
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

The complete D-01–D-28 decision set in `66-CONTEXT.md` is locked. In particular: publish `LatticeStripe.Product.Feature` for the distinct `product_feature` / `prodft_...` attachment; expose only `create/4`, `create!/4`, `retrieve/4`, `retrieve!/4`, `list/4`, `list!/4`, `stream!/4`, `delete/4`, `delete!/4`, and `from_map/1` (with their default-argument arities); use canonical code verbs and attach/remove only in prose; require the string key `"entitlement_feature"`; validate nil/empty parent and attachment IDs before transport; directly decode nested `entitlement_feature` as `LatticeStripe.Entitlements.Feature`; retain unknown fields in `extra`; and register the exact byte key `"product_feature"`.

`Product.features` and `Product.marketing_features` are locked as independent, raw `[map()] | nil` values throughout 1.x. They are legacy/current versions of pricing-table marketing copy, not entitlement attachments. Do not type, copy, normalize, or otherwise reinterpret either field. The authoritative catalog read is `Product.Feature.list/4` or `stream!/4`.

`stream!/4` must delegate all pagination mechanics to `LatticeStripe.List.stream!/2`, preserving product scope, base params, request options, typed values, early termination, and loud later-page failure. Tests must prove all transport paths/methods, decoding, guards, bang twins, identity distinction, multi-page cursor/filter/header behavior, ObjectTypes exact-key dispatch/rejection, Product compatibility, docs semantic anchors, API stability, and the inherited 2,332-test / 38-warning differential gate. Do not add aliases (`attach`, `detach`, `remove`), a delete-by-`feat_...` convenience, reconciliation/authorization policy, a new guide, a flagship recipe, UI, or custom pagination.

### the agent's Discretion

- Exact moduledoc, guide, error-message, and test wording within the decisions above.
- Exact private helper organization for path composition, ID validation, and map decoding.
- Exact plan/wave decomposition and whether the guide/JTBD changes land together or after the verified resource surface.
- No discretion to add public aliases, delete by `feat_...`, type legacy marketing fields as attachments, normalize the ObjectTypes key, or introduce reconciliation/authorization policy.

### Deferred Ideas (OUT OF SCOPE)

- Typed `Product.MarketingFeature` runtime values — consider only in a future major release with an explicit migration path.
- A new Flagship “catalog to access” recipe.
- Application-owned catalog persistence, diffing policy, and authorization UI.
- Global ExDoc-warning cleanup and the two inherited flaky tests.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| PROD-01 | Attach, list, and delete product features through `Product.Feature`. | Parent-scoped resource/API contract, typed decoder, Mox proof, and `List.stream!/2` reuse. |
| PROD-02 | Historical roadmap wording says type `Product.features`. | Corrected by locked context: preserve raw legacy/current marketing maps; fulfill the underlying catalog need with the separate typed attachment endpoint. |
</phase_requirements>

## Summary

Implement one additive nested resource at `lib/lattice_stripe/product/feature.ex`; do not alter `Product.from_map/1` except potentially explanatory documentation. Stripe’s current API defines a `product_feature` attachment between a Product and an Entitlements Feature. It creates and lists at `/v1/products/:product/features`, removes at `/v1/products/:product/features/:product_feature`, and returns an attachment with a nested `entitlement_feature`. [CITED: https://docs.stripe.com/api/product-feature] [CITED: https://docs.stripe.com/api/product-feature/attach] [CITED: https://docs.stripe.com/api/product-feature/remove]

The roadmap/requirements’ older `Product.features` premise is false and must not drive implementation. Stripe renamed `Product.features` to `marketing_features` in API version 2024-04-10; current docs describe `marketing_features` as pricing-table display objects. Existing consumers can validly use string-keyed map access on either field, making a silent struct conversion breaking in this library’s additive-minor contract. [CITED: https://docs.stripe.com/changelog/2024-04-10/renames-features-attribute-product-object] [CITED: https://docs.stripe.com/api/products/object] [VERIFIED: codebase grep]

**Primary recommendation:** Plan a resource-and-proof slice first, then ObjectTypes/API/docs/JTBD compatibility locks; keep the shared pagination state machine untouched and test its Product-specific guarantees at the Transport boundary.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Create/retrieve/list/delete attachment | API / Backend | Stripe API | The Elixir client composes and validates HTTP requests; Stripe owns persistence. |
| Typed attachment decoding | API / Backend | — | `from_map/1` maps Stripe JSON to public structs and preserves unknown fields. |
| Complete attachment enumeration | API / Backend | Stripe API | `List.stream!/2` owns cursor state; the resource supplies scoped request and mapper. |
| Webhook/embedded object dispatch | API / Backend | — | `ObjectTypes` maps the exact wire discriminator to the decoder. |
| Catalog/access guidance | Library documentation | Host application | The SDK exposes primitives; the host persists/reconciles/gates locally. |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---|---|---|---|
| Elixir / Mix | installed locally | Resource implementation, ExUnit tests, ExDoc docs. | Existing project stack; no dependency change. [VERIFIED: codebase grep] |
| Mox | existing test dependency | Assert outbound `LatticeStripe.Transport` requests and scripted page responses. | Project-wide unit boundary. [VERIFIED: codebase grep] |
| `LatticeStripe.List` | local module | Lazy cursor enumeration and next-page request reconstruction. | The only approved pagination state machine. [VERIFIED: `lib/lattice_stripe/list.ex`] |

### Supporting

| Library | Version | Purpose | When to Use |
|---|---|---|---|
| `LatticeStripe.Resource` | local module | Required-param guard and singular/list/bang response unwrapping. | Every public Product.Feature verb. [VERIFIED: `lib/lattice_stripe/resource.ex`] |
| `LatticeStripe.Entitlements.Feature` | local module | Nested `entitlement_feature` decoder. | Every `Product.Feature.from_map/1` call. [VERIFIED: `lib/lattice_stripe/entitlements/feature.ex`] |
| `stripe-mock` | CI integration lane | Official OpenAPI wire integration. | Optional integration confirmation; Mox remains pagination proof because stripe-mock ignores cursors. [VERIFIED: `66-CONTEXT.md`] |

**Installation:** none. This phase adds no external package.

## Architecture Patterns

### System Architecture Diagram

```text
Product.Feature.create/list/retrieve/delete/stream!
        |
        | pre-network ID + required-key guards
        v
%LatticeStripe.Request{method, scoped path, params, opts}
        |
        v
LatticeStripe.Client.request/2 --> Transport behaviour --> Stripe Product Feature API
        |                                           |
        | singular/list response                   | product_feature JSON
        v                                           v
Resource.unwrap_* + Product.Feature.from_map/1 <-- nested Entitlements.Feature.from_map/1
        |
        +--> list: typed %LatticeStripe.List{}
        +--> stream!: List.stream!/2 --cursor--> next scoped request / typed item
        +--> ObjectTypes.maybe_deserialize: exact "product_feature" dispatch
```

### Recommended Project Structure

```text
lib/lattice_stripe/product/feature.ex          # new public attachment resource
lib/lattice_stripe/object_types.ex             # one exact object-map row
test/lattice_stripe/product/feature_test.exs   # verb/decode/guard/surface tests
test/lattice_stripe/product/feature_stream_test.exs # multi-page/laziness/failure proof
test/lattice_stripe/product_test.exs           # legacy/current marketing-map regression
test/lattice_stripe/object_types_test.exs      # exact-key typed dispatch / typo rejection
guides/entitlements.md                         # canonical catalog-to-access journey
guides/user-flows-and-jtbd.md                  # concise routing entry
```

### Pattern 1: Parent-scoped canonical resource

**What:** Follow `TransferReversal`’s explicit parent and child IDs, but use `Product.Feature`’s nested namespace. Compose one private list path such as `"/v1/products/#{product_id}/features"`; item paths append `"/#{product_feature_id}"`. [VERIFIED: `lib/lattice_stripe/transfer_reversal.ex`]

**When to use:** All Product Feature verbs. `create/list/stream` require product only; `retrieve/delete` require product and attachment IDs. The official Product Feature landing page lists create/list/delete and the locked context confirms retrieve from Stripe’s OpenAPI. [CITED: https://docs.stripe.com/api/product-feature] [VERIFIED: `66-CONTEXT.md`]

```elixir
def create(%Client{} = client, product_id, params, opts \\ []) do
  validate_product_id!(product_id)
  Resource.require_param!(params, "entitlement_feature",
    "LatticeStripe.Product.Feature.create/4 requires an entitlement_feature param")

  %Request{method: :post, path: list_path(product_id), params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

### Pattern 2: Direct nested decoder, idempotent outer decoder

**What:** Implement `from_map(nil)`, struct idempotence before `is_map/1`, then `Map.split/2`; decode `entitlement_feature` through `Entitlements.Feature.from_map/1`. This exact nesting style is the active Entitlements precedent. [VERIFIED: `lib/lattice_stripe/entitlements/feature.ex`]

**When to use:** Singular, list, stream, delete, and ObjectTypes paths. The create/list response examples show an object (not a string) in `entitlement_feature`. [CITED: https://docs.stripe.com/api/product-feature/attach] [CITED: https://docs.stripe.com/api/product-feature/list]

### Pattern 3: Shared lazy pagination, resource-local typing

**What:** `stream!/4` builds the first scoped GET request and calls `List.stream!/2 |> Stream.map(&from_map/1)`; it never copies cursor code. `List` preserves base params/opts, uses the last raw-map id as `starting_after`, and raises page errors. [VERIFIED: `lib/lattice_stripe/list.ex`]

**When to use:** Complete catalog reads only. One `list/4` page is not a reconciliation result; Stripe’s list default is 10 and maximum is 100. [CITED: https://docs.stripe.com/api/product-feature/list]

### Anti-Patterns to Avoid

- **Typing `Product.features` or `marketing_features`:** semantically wrong and a breaking runtime-shape change; test they remain separately raw. [CITED: https://docs.stripe.com/changelog/2024-04-10/renames-features-attribute-product-object] [VERIFIED: `lib/lattice_stripe/product.ex`]
- **Custom pagination:** risks dropping the scoped product path, filters, Connect header, or later-page failure. Use `List.stream!/2`. [VERIFIED: `lib/lattice_stripe/list.ex`]
- **Delete by `feat_...`:** Stripe removes an attachment `prodft_...`, not the reusable definition; hidden lookup/delete creates race and pagination semantics. [CITED: https://docs.stripe.com/api/product-feature/remove]
- **Normalize `product.feature`:** the exact wire type is `product_feature`; normalization would create a dead dispatch row. [CITED: https://docs.stripe.com/api/product-feature/attach] [VERIFIED: `lib/lattice_stripe/object_types.ex`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Cursor pagination | Per-resource `Stream.resource` / cursor logic | `LatticeStripe.List.stream!/2` | It already carries filters/options, removes GET idempotency keys, supports reverse/search modes, and raises failures. [VERIFIED: `lib/lattice_stripe/list.ex`] |
| Response conversion | New response wrapper | `Resource.unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1` | Keeps established return tuples and list envelope. [VERIFIED: `lib/lattice_stripe/resource.ex`] |
| Nested feature decode | ad hoc map-to-struct duplication | `Entitlements.Feature.from_map/1` | One canonical decoder preserves idempotence and unknown fields. [VERIFIED: `lib/lattice_stripe/entitlements/feature.ex`] |
| Wire dispatch | heuristic object-name conversion | exact `ObjectTypes` map row | Unknown object types intentionally stay raw/fail fast downstream. [VERIFIED: `lib/lattice_stripe/object_types.ex`] |

## Common Pitfalls

### Product marketing-field confusion
**What goes wrong:** A contributor changes Product marketing lists into attachment structs.
**How to avoid:** Add regression maps for an old `features` payload and a current `marketing_features` payload; assert each is raw and independently assigned, while a `product_feature` map decodes only through the new module. [CITED: https://docs.stripe.com/changelog/2024-04-10/renames-features-attribute-product-object] [VERIFIED: `test/lattice_stripe/product_test.exs`]

### Cursor calculated after typing
**What goes wrong:** Page-two cursor becomes unavailable because `List.from_json/3` derives `_last_id` from raw string-key maps.
**How to avoid:** Let `List.stream!/2` fetch raw pages first, then map items in the resource stream. [VERIFIED: `lib/lattice_stripe/list.ex`]

### Passing page one as a complete catalog
**What goes wrong:** Defaults return 10 attachments and a catalog silently truncates.
**How to avoid:** Document `stream!/4` as the complete path and prove a page-two failure raises. [CITED: https://docs.stripe.com/api/product-feature/list] [VERIFIED: `test/lattice_stripe/entitlements/active_entitlement_stream_test.exs`]

### Lazy guard placed inside stream
**What goes wrong:** Invalid parent IDs raise only on first enumeration rather than at the caller.
**How to avoid:** Validate before constructing the request/stream, following parent-scoped precedents. [VERIFIED: `lib/lattice_stripe/transfer_reversal.ex`]

### Public-surface accidental expansion
**What goes wrong:** aliases or a non-bang `stream` become semver API.
**How to avoid:** structural exported-arity tests plus the API-surface lock; refute all alias/default arities. [VERIFIED: `test/lattice_stripe/entitlements/feature_test.exs`] [VERIFIED: `test/lattice_stripe/api_surface_lock_test.exs`]

## Code Examples

### Decoder shape

```elixir
@known_fields ~w[id object livemode entitlement_feature deleted]

def from_map(nil), do: nil
def from_map(%__MODULE__{} = attachment), do: attachment
def from_map(map) when is_map(map) do
  {known, extra} = Map.split(map, @known_fields)
  %__MODULE__{id: known["id"], object: known["object"] || "product_feature",
    livemode: known["livemode"], deleted: known["deleted"] || false,
    entitlement_feature: Entitlements.Feature.from_map(known["entitlement_feature"]), extra: extra}
end
```

Source pattern: [VERIFIED: `lib/lattice_stripe/entitlements/feature.ex`]; wire shape: [CITED: https://docs.stripe.com/api/product-feature/attach].

### Multi-page transport proof

```elixir
MockTransport
|> expect(:request, fn req ->
  assert req.url =~ "/v1/products/prod_123/features"
  assert {"stripe-account", "acct_connected"} in req.headers
  list_response([attachment("prodft_a"), attachment("prodft_b")], true)
end)
|> expect(:request, fn req ->
  assert req.url =~ "starting_after=prodft_b"
  assert req.url =~ "limit=2"
  assert {"stripe-account", "acct_connected"} in req.headers
  list_response([attachment("prodft_c")], false)
end)
```

Source pattern: [VERIFIED: `test/lattice_stripe/entitlements/active_entitlement_stream_test.exs`].

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Product `features` marketing-copy field | Product `marketing_features` marketing-copy field | Stripe API version 2024-04-10 | Preserve both raw compatibility shapes; use Product Feature endpoint for entitlement links. [CITED: https://docs.stripe.com/changelog/2024-04-10/renames-features-attribute-product-object] |
| Manual one-page catalog read | `stream!/4` full lazy enumeration | Existing library pattern | Avoid silent default-limit truncation and preserve failure semantics. [VERIFIED: `lib/lattice_stripe/list.ex`] |

## Recommended Plan Decomposition

1. **Resource + narrow unit surface:** add `Product.Feature`, exact fields/defaults/decoder/guards/verbs/bang twins and focused Mox path-method-body-option/error/identity tests. Lock no aliases/non-bang stream and no convenience delete.
2. **Pagination + compatibility/dispatch:** add a dedicated multi-page stream test file with cursor, product scope, filter/limit, order/type, early `Stream.take/2`, Connect header, idempotency behavior, and page-two error. Extend Product raw-marketing regressions and ObjectTypes direct-key/typo tests.
3. **Published truth:** add the exact module to Entitlements ExDoc group, repair guide placeholders, add compact JTBD route, semantic docs-truth assertions, and API-surface snapshot update. Run targeted tests, complete suite, docs differential gate, and production compile.

## Open Questions

None that block planning. The official Product Feature landing page shown by Stripe lists create/list/delete, while the locked context records the retrieve operation from Stripe’s authoritative OpenAPI; plan `retrieve/4` as locked and prove its exact scoped GET path with Mox. [CITED: https://docs.stripe.com/api/product-feature] [VERIFIED: `66-CONTEXT.md`]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Elixir/Mix | implementation and ExUnit | ✓ | OTP 28 observed | — |
| Docker | optional stripe-mock integration lane | ✓ | Docker 29.5.2 | Mox proves all unit/pagination behavior |
| stripe-mock CLI | optional local integration execution | ✗ on PATH | — | CI integration lane / Mox unit suite |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** local `stripe-mock`; do not silently skip CI integration if its lane invokes it. [VERIFIED: environment probe]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit + Mox Transport mock [VERIFIED: `test/lattice_stripe/entitlements/feature_test.exs`] |
| Config file | `test/test_helper.exs` [VERIFIED: codebase grep] |
| Quick run command | `mix test test/lattice_stripe/product/feature_test.exs test/lattice_stripe/product/feature_stream_test.exs test/lattice_stripe/product_test.exs test/lattice_stripe/object_types_test.exs test/lattice_stripe/docs_truth_test.exs` |
| Full suite command | `mix test` (inherited clean gate: at least 2,332 tests) [VERIFIED: `65-06-SUMMARY.md`] |
| Docs gate | `mix docs` and compare against max 38 warnings; no Phase-66-name warnings. Do not use red-at-clean-HEAD `mix ci` as sole gate. [VERIFIED: `STATE.md`] |
| Release-surface gate | `mix test test/lattice_stripe/api_surface_lock_test.exs` and update `priv/api/current.txt` intentionally. [VERIFIED: `lattice-verification-policy`] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| PROD-01 | `create/retrieve/list/delete` send exact parent-scoped methods/paths and decode typed attachment. | unit/Mox | `mix test test/lattice_stripe/product/feature_test.exs` | ❌ Wave 0 |
| PROD-01 | `stream!/4` pages with last `prodft_` cursor, preserves scope/options/order/type, avoids page 2 when stopped, and raises on page-2 failure. | unit/Mox | `mix test test/lattice_stripe/product/feature_stream_test.exs` | ❌ Wave 0 |
| PROD-01 | Exact `product_feature` dispatch returns `Product.Feature`; `product.feature` stays raw / `fetch_module` errors. | unit | `mix test test/lattice_stripe/object_types_test.exs` | ✅ extend |
| PROD-02 | Old `features` and current `marketing_features` remain raw, independent maps; attachment decoder is separate. | unit | `mix test test/lattice_stripe/product_test.exs` | ✅ extend |
| PROD-01/02 | New public surface is visible and docs state the semantically correct journey/boundaries. | API/docs regression | `mix test test/lattice_stripe/api_surface_lock_test.exs test/lattice_stripe/docs_truth_test.exs` | ✅ extend |

### Required Behavioral Test Inventory

- Every method/path: POST/GET collection, GET item, DELETE item; assert request body includes `entitlement_feature`, per-request headers/options, typed singular/list/deleted response, and bang success/error behavior.
- No-expectation guard tests: missing required key; nil/empty product for all verbs; nil/empty attachment for retrieve/delete. Mox verification proves transport was not reached.
- Decoder: nil, typed idempotence, nested `%Entitlements.Feature{}`, defaults, unknown `extra`, and delete’s nil absent fields with `deleted: true`.
- Module shape: exact required/defaulted arities; refute `stream`, `attach`, `detach`, `remove`, lookup/delete-by-feature conveniences at every exported arity.
- Stream proof: page-two `starting_after=prodft_last`; `limit`/any caller filters and product URL retained; `stripe-account` retained; types/order; `Stream.take(1)` only one expectation; page-two 500 raises.
- Product regression: a `features` payload and a `marketing_features` payload do not get copied or typed into attachment structs.
- Dispatch: one direct map-row test, `maybe_deserialize/1` typed test, and explicit typo rejection; do not count `@object_map` rows.

### Sampling Rate

- **Per task commit:** targeted resource/stream/object/docs/API-lock tests plus `MIX_ENV=prod mix compile`.
- **Per wave merge:** `mix test` and `mix docs`; capture count/warning differential.
- **Phase gate:** full suite green, docs warning count ≤38 with no Phase 66 warnings, API lock review, and stripe-mock lane where available.

### Wave 0 Gaps

- [ ] `test/lattice_stripe/product/feature_test.exs` — PROD-01 resource and structural surface.
- [ ] `test/lattice_stripe/product/feature_stream_test.exs` — PROD-01 multi-page proof.
- [ ] Extend `product_test.exs`, `object_types_test.exs`, `docs_truth_test.exs`, and API snapshot — compatibility/dispatch/docs locks.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | yes | Existing Client API-key and per-request transport boundary; assert options/headers propagate. [VERIFIED: codebase tests] |
| V3 Session Management | no | Headless HTTP library has no user session. [VERIFIED: `lattice-verification-policy`] |
| V4 Access Control | yes | SDK must not add request-time `entitled?`; docs retain host-local fail-closed gate. [VERIFIED: `66-CONTEXT.md`] |
| V5 Input Validation | yes | Pre-network non-empty ID guards and required string-key param guard. [VERIFIED: `lib/lattice_stripe/resource.ex`] |
| V6 Cryptography | no | This feature introduces no cryptographic operation. [VERIFIED: scope] |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Cross-product/tenant read on page two | Information disclosure | Mox assertion that scoped Product path and caller filters/Connect header persist across pages. |
| Partial catalog treated as authorization truth | Elevation of privilege | `stream!/4` only for complete enumerations; later-page errors raise; guide preserves local fail-closed ownership. |
| Wrong identifier deletes wrong concept | Tampering | Explicit parent + `prodft_...` target; no `feat_...` convenience; path and guard tests. |
| Unknown future wire fields dropped | Tampering | `extra` preserves unknown top-level values. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | None. | — | All implementation-relevant claims are locked context, verified codebase behavior, or official Stripe documentation. |

## Sources

### Primary (HIGH confidence)

- [Stripe Product Feature API](https://docs.stripe.com/api/product-feature) — endpoint family and attachment purpose.
- [Attach Product Feature](https://docs.stripe.com/api/product-feature/attach) — required key and object/decode shape.
- [List Product Features](https://docs.stripe.com/api/product-feature/list) — list envelope/cursor/default limit.
- [Remove Product Feature](https://docs.stripe.com/api/product-feature/remove) — attachment target and deleted response.
- [Stripe Product field rename](https://docs.stripe.com/changelog/2024-04-10/renames-features-attribute-product-object) and [current Product object](https://docs.stripe.com/api/products/object) — marketing-field correction.
- Local analogs: `product.ex`, `entitlements/feature.ex`, `transfer_reversal.ex`, `list.ex`, `resource.ex`, `object_types.ex`, and their focused tests. [VERIFIED: codebase grep]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; direct local patterns.
- Architecture: HIGH — exact local parent-scoped and pagination precedents.
- Pitfalls: HIGH — locked correction plus existing Mox proof patterns.

**Research date:** 2026-08-25
**Valid until:** 2026-09-01 (Stripe API surface is externally versioned; recheck before implementation if delayed).
