# Phase 66: Product ↔ Feature Attachment - Context

**Gathered:** 2026-08-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the typed, parent-scoped `LatticeStripe.Product.Feature` resource that lets an
Elixir developer create, retrieve, list, completely enumerate, and delete Stripe
`product_feature` attachments under `/v1/products/:product/features`. The attachment is
the missing catalog link between an `Entitlements.Feature` definition and the Product
whose purchase produces an `ActiveEntitlement`.

This phase also closes the existing Entitlements guide's attachment placeholder, registers
the exact `product_feature` wire object for typed dispatch, and preserves existing Product
retrieve/list behavior.

**Research correction to the roadmap premise:** `Product.features` is not an embedded
entitlement-attachment collection. It is Stripe's pre-2024 name for the pricing-table
`marketing_features` field. Both fields contain display values shaped like `%{"name" =>
...}`, not `product_feature` objects. Stripe renamed `features` to `marketing_features` in
API version 2024-04-10, and current Product schemas expose only `marketing_features`.
Therefore this phase MUST NOT decode either field as `Product.Feature`. The authoritative
entitlement catalog read is `Product.Feature.list/4` or `stream!/4`.

PROD-02 and Roadmap Success Criterion 2 are satisfied only after correcting their semantic
premise: the new typed struct belongs to the dedicated attachment endpoint, not the legacy
Product field. Changing the existing `[map()]` Product fields into structs during the planned
Hex 1.8.0 minor release would break valid string-key access and map pattern matches, contrary
to the project's additive-minor stability contract. Preserve their runtime shape for 1.x.

The SDK remains primitive-first. It does not implement billing policy, customer provisioning,
catalog reconciliation storage, or a request-time network authorization gate.

</domain>

<decisions>
## Implementation Decisions

### Attachment API Contract

- **D-01:** Publish `LatticeStripe.Product.Feature` as the attachment resource (`product_feature`,
  `prodft_...`), distinct from the capability definition `LatticeStripe.Entitlements.Feature`
  (`entitlements.feature`, `feat_...`). — **Reversibility: one-way** — the public module name and
  noun distinction become a published semver contract at the Hex 1.8.0 tag.
- **D-02:** The complete public surface is `create/4`, `create!/4`, `retrieve/4`,
  `retrieve!/4`, `list/4`, `list!/4`, `stream!/4`, `delete/4`, `delete!/4`, and
  `from_map/1`, with default arguments exposing the ordinary lower arities. `stream!` has no
  non-bang twin. `retrieve` is included because the authoritative Stripe OpenAPI for this
  resource exposes `GET /v1/products/:product/features/:id`; forcing a list scan for a known
  `prodft_...` would be surprising and inefficient. — **Reversibility: costly** — removing a
  published verb or arity requires a major release or deprecation cycle.
- **D-03:** Use canonical resource verbs (`create`, `retrieve`, `list`, `delete`) in code.
  Use the domain verbs **attach** and **remove** in prose and examples. Do not publish
  `attach`, `detach`, or `remove` aliases: parallel names split documentation, autocomplete,
  and future maintenance without adding capability.
- **D-04:** `create` takes `(client, product_id, params, opts \\ [])`. `params` is a string-keyed
  Stripe wire map and has no empty-map default. Require the presence of
  `"entitlement_feature"` before any request, using the established directive error-message
  shape. Keep the map rather than replacing it with a positional `feature_id`, so `expand` and
  future additive Stripe parameters continue to pass through naturally.
- **D-05:** Parent and attachment identifiers are explicit: create/list/stream use the
  `prod_...` parent ID; retrieve/delete also require the `prodft_...` attachment ID. Validate
  nil/empty parent and attachment IDs before the network with clear `ArgumentError` messages,
  following the parent-scoped `TransferReversal` precedent.
- **D-06:** Never accept a `feat_...` definition ID as the delete target and never hide a
  list/filter/delete sequence behind a convenience function. Stripe deletes the attachment
  resource, and an invented lookup would add network work, pagination ambiguity, races, and
  unclear zero/multiple-match semantics.

### Typed Object Graph and Compatibility

- **D-07:** `%LatticeStripe.Product.Feature{}` has the live-object fields `id`, `object`,
  `livemode`, and `entitlement_feature`, plus `deleted` for the successful delete response and
  `extra` for forward-compatible unknown fields. `object` defaults to `"product_feature"` and
  `deleted` defaults to `false`.
- **D-08:** `Product.Feature.from_map/1` is nil-safe and idempotent. It always decodes
  `entitlement_feature` through `LatticeStripe.Entitlements.Feature.from_map/1`; Stripe's schema
  is a direct object reference, never a bare `feat_...` string. Unknown top-level fields remain
  in `extra`. No custom `Inspect` is needed because the object carries no PII.
- **D-09:** Keep `Product.features` and `Product.marketing_features` runtime values as their
  existing raw `[map()] | nil` during 1.x. The former is a legacy API-version compatibility
  field for the latter; neither contains entitlement attachments. Do not add a misleading
  `Product.MarketingFeature` struct merely to make the roadmap's obsolete wording look true.
  — **Reversibility: one-way for 1.x** — changing list elements from string-keyed maps to structs
  can break pattern matching and Access calls in existing consumers; the project promises no
  such silent break in a minor release.
- **D-10:** Do not copy values between the two Product fields. Preserve wire truth independently:
  an older per-request Stripe version may populate `features`, while the pinned/current version
  populates `marketing_features`. Product retrieve/list/stream/search continue to return the
  same Product field shapes they return today.
- **D-11:** Register the exact wire key `"product_feature"` in `ObjectTypes`, mapping to
  `LatticeStripe.Product.Feature`. Earlier Phase 65 prose that says `product.feature` is a typo;
  dot normalization, case folding, or trimming would create a silently dead registry entry.
  Assert the key directly rather than locking the total registry size.

### Enumeration and Removal Ergonomics

- **D-12:** `list/4` returns one `Response` containing a `LatticeStripe.List` of typed
  `%Product.Feature{}` items. It preserves Stripe's order and exposes the normal `limit`,
  `starting_after`, `ending_before`, and `expand` params without sorting, deduplication, or
  reconciliation policy.
- **D-13:** `stream!/4` is the complete-enumeration path. Delegate the cursor state machine to
  `LatticeStripe.List.stream!/2`; preserve the product-scoped path, base params, Connect/request
  options, and response typing on every page. A later-page error raises rather than returning a
  silently partial catalog.
- **D-14:** Create and retrieve return `{:ok, %Product.Feature{}}`; list returns the established
  typed list envelope; delete returns `{:ok, %Product.Feature{deleted: true}}`, not a boolean.
  The deleted struct retains the attachment ID and wire object type while fields absent from the
  deletion response remain nil.
- **D-15:** Document the identity distinction wherever deletion is shown: `feat_...` names the
  reusable feature definition; `prodft_...` names its attachment to one Product. Examples always
  show both `prod_...` and `prodft_...` for retrieve/delete to prevent a global-ID mental model.

### Entitlements Guide Journey and Discoverability

- **D-16:** Expand the existing `guides/entitlements.md`; do not create a new guide or fifth
  Flagship Recipe. Replace all now-stale Phase 65 and Phase 66 placeholders in the same pass so
  the canonical guide never contradicts shipped registry, fixture, or attachment behavior.
- **D-17:** Teach one progressive catalog-to-access journey: scope boundary → mental model →
  define a stable `Entitlements.Feature` → create a `Product.Feature` attachment → inspect the
  complete product attachment catalog → delete an attachment → react to entitlement-summary
  webhooks → full canonical customer reconciliation → local fail-closed authorization.
- **D-18:** Keep inputs and outputs visible in examples: `feat_...` plus `prod_...` produces a
  `prodft_...`; purchasing the Product can produce `ent_...`; an entitlement-summary event
  triggers reconciliation. Never describe attachment creation or Checkout completion as proof
  that the application's local authorization gate has updated.
- **D-19:** Explicitly distinguish `Product.marketing_features` as pricing-table display copy
  from `Product.Feature` as access-bearing catalog configuration. The guide must direct catalog
  readers to `Product.Feature.list/4` or `stream!/4`, never `Product.features`.
- **D-20:** Place `LatticeStripe.Product.Feature` in the existing **Entitlements** ExDoc module
  group beside `LatticeStripe.Entitlements.Feature`, despite its Product namespace. Cross-link
  both moduledocs and the Product moduledoc so HexDocs search and sidebar browsing resolve the
  “two Features” ambiguity immediately.
- **D-21:** Add a concise “Entitlement catalog and access” route to
  `guides/user-flows-and-jtbd.md` that links Entitlements → Subscriptions/Checkout → Webhooks →
  Testing. It is a routing entry, not a duplicate API guide or application workflow framework.
- **D-22:** Preserve the permanent no-`entitled?` fence and its working replacement: reconcile
  in a background/runtime boundary, persist a complete local snapshot, authorize locally, and
  fail closed when state is missing or stale.
- **D-23:** No application UI or bespoke graphic design is warranted. Use semantic headings,
  short runnable Elixir examples, warning callouts, descriptive links, and the existing
  monospace relationship diagram. These satisfy the applicable design pillars: correctness,
  safety, accessibility, discoverability, consistency, performance, maintainability, and
  testability. No project brandbook was found; the established ExDoc/JTBD system is canonical.

### Proof and Regression Boundaries

- **D-24:** Mox-at-Transport tests cover every request method/path, typed decode, required-param
  and ID validation before the network, per-request options, bang twins, deleted-response shape,
  and the `feat_...` versus `prodft_...` identity boundary.
- **D-25:** Prove multi-page `stream!` separately using the established hand-authored pagination
  pattern: page-two cursor equals the last page-one `prodft_...`; product scope and filters remain;
  items preserve order and type; early termination avoids extra requests; request headers carry;
  later-page failure raises.
- **D-26:** Product regression tests prove old/current marketing payloads remain raw and
  independently assigned, while `Product.Feature.from_map/1` proves the separate entitlement
  attachment graph. This is the structural guard against the false roadmap interpretation.
- **D-27:** Add key-level ObjectTypes assertions for `"product_feature"`, including typed
  `maybe_deserialize/1` behavior and exact-byte rejection of `"product.feature"`. Do not add a
  `map_size` assertion.
- **D-28:** Extend docs-truth with semantic anchors rather than exact prose: the Entitlements guide
  names `Product.Feature`, create/retrieve/list/stream/delete, `prodft_...`, the marketing-feature
  distinction, the webhook/reconciliation boundary, and the no-`entitled?` fence. Preserve the
  inherited clean-HEAD gate: at least 2,332 tests, no more than 38 ExDoc warnings, and no new
  warnings naming the Phase 66 modules or guide. Do not use currently-red `mix ci` as the sole
  phase gate.

### the agent's Discretion

- Exact moduledoc, guide, error-message, and test wording within the decisions above.
- Exact private helper organization for path composition, ID validation, and map decoding.
- Exact plan/wave decomposition and whether the guide/JTBD changes land together or after the
  verified resource surface.
- No discretion to add public aliases, delete by `feat_...`, type legacy marketing fields as
  attachments, normalize the ObjectTypes key, or introduce reconciliation/authorization policy.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and adopter pull

- `.planning/ROADMAP.md` § Phase 66 — fixed phase goal, dependencies, success criteria, and
  parent-scoped implementation constraints; read together with the research correction in this
  CONTEXT rather than repeating the obsolete `Product.features` premise.
- `.planning/REQUIREMENTS.md` § Product ↔ Feature — PROD-01/PROD-02 traceability and the narrow
  v1.10 milestone boundary.
- `.planning/PROJECT.md` § Current Milestone: v1.10 Accrue Surface Closure — additive Hex 1.8.0
  posture, project design philosophy, and primitive-first SDK boundary.
- `.planning/seeds/SEED-005-stripe-native-entitlements.md` §1.2 and §6 — adopter need, original
  Product↔Feature ask, and frozen client/request stability contracts.
- `.planning/research/accrue-gap-brief-2026-07-27.txt` §1.2 — Accrue's duplicated-catalog problem
  and the product leverage expected from authoritative attachment reads.

### Prior-phase decisions and readiness

- `.planning/phases/63-stripe-native-entitlements/63-CONTEXT.md` — locked Feature-definition vs
  Product-attachment distinction, direct nested definition decode, ExDoc placement, guide stub,
  local fail-closed gate, and pagination doctrine.
- `.planning/phases/63-stripe-native-entitlements/COVERAGE.md` — explicit Phase 66 ownership of
  the `product_feature` attachment surface.
- `.planning/phases/65-webhook-objecttypes-testing-fixtures/65-04-SUMMARY.md` — registry rules,
  direct-key tests, and intentional avoidance of brittle map-size assertions.
- `.planning/phases/65-webhook-objecttypes-testing-fixtures/65-06-SUMMARY.md` — Phase 66 baseline:
  2,332 tests, 38 ExDoc warnings, registry size 52 before the new exact `product_feature` row.

### Existing source patterns

- `lib/lattice_stripe/product.ex` — existing public Product struct, legacy/current raw marketing
  fields, all Product read paths, and forward-compatible `extra` behavior that must not regress.
- `lib/lattice_stripe/entitlements/feature.ex` — direct nested decoder, required-param guard
  message style, definition-vs-attachment moduledoc, bang twins, and list/stream conventions.
- `lib/lattice_stripe/transfer_reversal.ex` — closest parent-scoped create/retrieve/list/delete,
  explicit two-ID surface, pre-network ID validation, and stream pattern.
- `lib/lattice_stripe/tax_id.ex` — additional parent-scoped arity/path precedent and typed delete
  response handling.
- `lib/lattice_stripe/list.ex` — the only cursor/stream state machine; Phase 66 must reuse it.
- `lib/lattice_stripe/resource.ex` — response unwrap and required-param helpers.
- `lib/lattice_stripe/object_types.ex` — exact-byte typed dispatch table and the new
  `"product_feature"` integration point.
- `test/lattice_stripe/product_test.exs` — existing Product runtime and public-surface regression
  suite to extend without rewriting unrelated Product contracts.
- `test/lattice_stripe/entitlements/feature_test.exs` — closest sibling proof style for required
  params, typed pages, pagination, bang twins, absent verbs, and domain warnings.

### Documentation and compatibility contracts

- `guides/entitlements.md` — canonical guide whose Phase 65/66 placeholders this phase completes.
- `guides/user-flows-and-jtbd.md` — job-oriented discovery layer for the concise catalog route.
- `guides/api_stability.md` — strict post-1.0 additive-minor contract; the reason legacy Product
  map values cannot silently become structs in Hex 1.8.0.
- `test/lattice_stripe/docs_truth_test.exs` — semantic documentation regression patterns.
- `mix.exs` `docs/0` — ExDoc extras and module grouping; `Product.Feature` belongs in
  Entitlements, not the broad Billing group.
- `.github/workflows/ci.yml` — required test/docs lanes and the inherited differential docs gate.

### Project-local commissioned research

- `prompts/elixir-best-practices-deep-research.md` — tuple/bang API pairs, boundary validation,
  public specs, documentation, and test conventions.
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — consumer-first OSS library
  API design, HexDocs layers, explicit behavior, and anti-patterns.
- `prompts/stripe-explanation-domain-language-deep-research.md` — Stripe nouns and the difference
  between create/attach/remove as wire operations versus teaching language.
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — premium pagination/response-shaping
  DX, reconciliation, and job-oriented docs.
- `prompts/stripe-sdk-api-surface-area-deep-research.md` — cursor auto-pagination, expandable
  fields, typed response surfaces, and SDK completeness lessons.
- `prompts/payments_domain_field_guide.md` — lifecycle, catalog, pagination, idempotency, and
  concurrency footguns.

### Authoritative external API truth verified during discussion

- `https://docs.stripe.com/api/product-feature` — Product Feature domain definition and endpoint
  family.
- `https://docs.stripe.com/api/product-feature/attach` — required `entitlement_feature` request
  param and live attachment response.
- `https://docs.stripe.com/api/product-feature/list` — parent-scoped list envelope and cursor
  params, including default limit 10.
- `https://docs.stripe.com/api/product-feature/remove` — `prodft_...` delete target and deleted
  response shape.
- `https://docs.stripe.com/changelog/2024-04-10/renames-features-attribute-product-object` —
  authoritative proof that Product `features` was renamed to `marketing_features` and is not the
  entitlement attachment collection.
- `https://docs.stripe.com/api/products/object` — current Product schema: `marketing_features`
  are pricing-table display objects; no embedded entitlement-attachment field.
- `https://github.com/stripe/openapi/blob/af5309cae53e5f666f9686dfed306d6d3b5fdc67/openapi/spec3.sdk.json`
  — authoritative `product_feature` object and create/retrieve/list/delete operation schema.
- `https://raw.githubusercontent.com/stripe/stripe-node/master/src/resources/Products.ts` —
  successful official SDK precedent for create/retrieve/list/delete feature methods and typed
  `MarketingFeature` values.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `LatticeStripe.Resource`: reuse `require_param!/3`, `unwrap_singular/2`, `unwrap_list/2`, and
  `unwrap_bang!/1`; no new response abstraction is needed.
- `LatticeStripe.List.stream!/2`: reuse the complete cursor mechanism; Phase 66 supplies only the
  parent-scoped request and typed mapper.
- `LatticeStripe.Entitlements.Feature.from_map/1`: the exact nested decoder for every
  `product_feature.entitlement_feature` object.
- `ObjectTypes.object_map/0`: one exact `"product_feature"` row enables existing typed dispatch;
  no new registry or normalization layer is needed.
- The existing `guides/entitlements.md` mental model and reserved attachment section provide the
  documentation skeleton; extend rather than duplicate it.

### Established Patterns

- Public network APIs return `{:ok, value} | {:error, %LatticeStripe.Error{}}`; ordinary bang
  twins call `Resource.unwrap_bang!/1`.
- Parent-scoped resources take the parent ID immediately after `client` and compose item paths
  from parent plus resource ID.
- List-bearing modules expose one-page `list` plus lazy complete `stream!`; pagination is never
  reimplemented per resource.
- Unknown response fields remain in `extra`; custom `Inspect` exists only for PII-bearing objects.
- Explicit code verbs mirror Stripe resource operations, while domain prose can say attach/remove.
- Docs-truth locks semantic harm boundaries rather than exact paragraphs.

### Integration Points

- Add `lib/lattice_stripe/product/feature.ex` and its focused unit/wire/pagination tests.
- Extend `lib/lattice_stripe/object_types.ex` and key-level tests with exact
  `"product_feature"` dispatch.
- Keep `lib/lattice_stripe/product.ex` runtime field decoding stable; update documentation only to
  clarify legacy marketing `features` versus entitlement attachments.
- Append `LatticeStripe.Product.Feature` to the Entitlements ExDoc grouping without pulling the
  entire Product namespace out of Billing.
- Replace Phase 65/66 placeholders in `guides/entitlements.md`; add the concise JTBD discovery
  route and semantic docs-truth locks.

### Creative Options Rejected

- `attach/detach` aliases: attractive prose, but duplicate a permanent public surface.
- Delete by `feat_...`: hides list/filter/network semantics and confuses definition with
  attachment identity.
- Decode legacy Product `features` as Product.Feature: semantically false and silently corrupting.
- New flagship guide or UI: duplicates the canonical Entitlements guide and expands scope into
  application-owned workflows.

</code_context>

<specifics>
## Specific Ideas

- The happy-path teaching sequence should remain visually compact:

  ```elixir
  alias LatticeStripe.Entitlements.Feature, as: EntitlementFeature
  alias LatticeStripe.Product.Feature, as: ProductFeature

  {:ok, feature} =
    EntitlementFeature.create(client, %{
      "lookup_key" => "advanced_analytics",
      "name" => "Advanced analytics"
    })

  {:ok, attachment} =
    ProductFeature.create(client, "prod_pro", %{
      "entitlement_feature" => feature.id
    })

  lookup_keys =
    client
    |> ProductFeature.stream!("prod_pro")
    |> Enum.map(& &1.entitlement_feature.lookup_key)
  ```

- The guide should immediately follow that catalog example with the existing runtime boundary:
  an attachment configures future purchase-derived access; it is not a synchronous customer gate.
- Recommended validation microcopy follows the established fully-qualified format, for example:
  `LatticeStripe.Product.Feature.create/4 requires an entitlement_feature param` and
  `LatticeStripe.Product.Feature.delete/4 requires a non-empty product feature id`.
- The human mental model is deliberately three IDs, not one overloaded “feature” ID:
  `feat_...` definition → `prodft_...` attachment under `prod_...` → `ent_...` customer result.

</specifics>

<deferred>
## Deferred Ideas

- **Typed `Product.MarketingFeature` runtime values** — consider only in a future major release
  with an explicit migration path. The current 1.x return shape is raw maps, and the type has no
  bearing on entitlement catalog derivation.
- **A new Flagship “catalog to access” recipe** — keep deferred unless adopter pull demonstrates
  the canonical Entitlements guide is insufficient. A new recipe would otherwise duplicate
  Product, Checkout, Webhooks, and reconciliation truth.
- **Application-owned catalog persistence, diffing policy, and authorization UI** — belong in
  Accrue or the host application, not this SDK phase.
- **Global ExDoc-warning cleanup and the two inherited flaky tests** — remain routed to their
  existing Phase 67/deferred-items owners; Phase 66 holds the differential baseline rather than
  absorbing unrelated cleanup.

</deferred>

---

*Phase: 66-product-feature-attachment*
*Context gathered: 2026-08-25*
