# Phase 12: Billing Catalog - Context

**Gathered:** 2026-04-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 12 delivers the Stripe **billing catalog** as idiomatic Elixir resources following the v1 template: Products, Prices, Coupons, and PromotionCodes — plus the nested Discount type, plus a regression-proof `FormEncoder` battery for triple-nested (and deeper) inline shapes.

**In scope:**
- `LatticeStripe.Product` — create, retrieve, update, list, stream, search
- `LatticeStripe.Price` — create, retrieve, update, list, stream, search (NO delete — Stripe API constraint)
- `LatticeStripe.Coupon` — create, retrieve, delete, list, stream (NO update, NO search — Stripe API constraints)
- `LatticeStripe.PromotionCode` — create, retrieve, update, list, stream (NO search — verified absent in Stripe OpenAPI spec)
- `LatticeStripe.Discount` — typed struct only (no top-level CRUD; used as nested field on Customer and Subscription)
- Typed nested structs: `Price.Recurring`, `Price.Tier`, `Coupon.AppliesTo`
- `FormEncoder` regression battery covering every known Stripe nested shape through Phase 19, plus StreamData property tests for structural invariants
- Backfill: `LatticeStripe.Customer.discount` retyped from `map()` to `%LatticeStripe.Discount{}`

**Out of scope** (carried forward from PROJECT.md / belongs in later phases):
- `Billing.Meter` / `MeterEvent` / `MeterEventAdjustment` / `MeterEventSummary` (BILL-07, deferred)
- `BillingPortal.Session` / `Configuration` (BILL-05, deferred)
- Subscriptions / SubscriptionItems (Phase 15)
- Invoices / InvoiceItems (Phase 14)
- Billing Test Clocks (Phase 13)
- OpenAPI codegen (ADVN-02, deferred)

</domain>

<decisions>
## Implementation Decisions

### D-01: Strategic nested struct typing (Tier 2)

Type only the nested shapes that downstream phases pattern-match on. Leave rarely-read shapes as `map()` with explicit typespec and `@moduledoc` note.

**Type now (Phase 12):**
- `LatticeStripe.Price.Recurring` — Subscriptions phase depends on it; highest-traffic nested read in any Stripe SDK
- `LatticeStripe.Price.Tier` — consumers iterate tiered-billing prices
- `LatticeStripe.Coupon.AppliesTo` — single field (`products: [String.t()]`), guards discount logic
- `LatticeStripe.Discount` — nested field on Customer and Subscription; needs its own module because it references Coupon

**Leave as `map()` with typespec:**
- `Price.transform_quantity` — one-line shape, rarely read
- `Price.custom_unit_amount` — rarely read
- `Price.currency_options` value shape — low-medium traffic, value type is effectively recursive
- `Product.package_dimensions` — shipping edge case

**Milestone-wide rule (applies to Phases 13-19):**
> A nested object becomes a typed struct if and only if downstream phases pattern-match on it. Otherwise it stays as `map()` with an explicit typespec and a `@moduledoc` note explaining the shape.

### D-02: Backfill `Customer.discount` as typed `%LatticeStripe.Discount{}`

`lib/lattice_stripe/customer.ex` currently declares `discount: map() | nil` (line 111). Phase 12 retypes it to `discount: LatticeStripe.Discount.t() | nil` once the `Discount` module exists. Natural to do in Phase 12 because `Discount` references `Coupon` which is being built in the same phase. ~20 LOC of changes in `customer.ex` + `from_map/1` update.

### D-03: Whitelist atomization of enum-like fields (forward-compatible)

Convert well-known Stripe enum string values to atoms on ingest. Unknown values pass through as the raw string — type becomes `:known_atom | String.t()`.

**Mechanism:**
```elixir
# In Price.Recurring.from_map/1
def atomize_interval("day"), do: :day
def atomize_interval("week"), do: :week
def atomize_interval("month"), do: :month
def atomize_interval("year"), do: :year
def atomize_interval(other) when is_binary(other), do: other  # forward-compat
```

**Why:** Pattern matching on atoms is idiomatic Elixir. `String.to_atom/1` is a DoS risk (atoms are not GC'd). `String.to_existing_atom/1` crashes on unknown values — if Stripe silently adds an enum value in a new API version, the SDK must not crash. Whitelist-based conversion is forward-compatible by construction.

**Fields atomized in Phase 12:**
- `Price.type` — `:one_time | :recurring | String.t()`
- `Price.billing_scheme` — `:per_unit | :tiered | String.t()`
- `Price.tax_behavior` — `:inclusive | :exclusive | :unspecified | String.t()`
- `Price.Recurring.interval` — `:day | :week | :month | :year | String.t()`
- `Price.Recurring.usage_type` — `:licensed | :metered | String.t()`
- `Price.Recurring.aggregate_usage` — `:sum | :last_during_period | :last_ever | :max | String.t() | nil`
- `Price.Tier.up_to` — `integer() | :inf` (Stripe returns the literal string `"inf"` for the final tier; we convert to `:inf`)
- `Product.type` — `:good | :service | String.t()`
- `Coupon.duration` — `:forever | :once | :repeating | String.t()`

**Milestone-wide rule:**
> Every documented Stripe enum field on a typed struct gets whitelist-atomized with a `String.t()` catch-all for forward compatibility. Never `String.to_atom/1`. Never crash on unknown values.

**FormEncoder round-trip guarantee:** `:month` and `"month"` must encode identically. This is tested explicitly in the FormEncoder battery (D-09b).

### D-04: Search endpoints — ship Product and Price only

**Verified absent in Stripe OpenAPI spec** (`spec3.sdk.json`): Only 7 resources have `/search` endpoints: `charges`, `customers`, `invoices`, `payment_intents`, `prices`, `products`, `subscriptions`. **Coupon and PromotionCode do NOT have search endpoints.**

**Result:**
- `LatticeStripe.Product.search/2,3` — ship ✓
- `LatticeStripe.Price.search/2,3` — ship ✓
- `LatticeStripe.Coupon.search/2,3` — do NOT define
- `LatticeStripe.PromotionCode.search/2,3` — do NOT define

**Search query fields** (documented in `@doc`):
- Product: `active`, `description`, `metadata`, `name`, `shippable`, `url`
- Price: `active`, `currency`, `lookup_key`, `metadata`, `product`, `type`

**Eventual consistency callout** (required by roadmap success criterion #4): every `search/2` `@doc` carries the same callout block — "Search results have eventual consistency (~1 minute under normal ops, longer during outages per https://docs.stripe.com/search#data-freshness). Do not use `search/2` in read-after-write flows." The exact wording is a shared helper string referenced from each resource's `@doc`.

**REQUIREMENTS.md updated:** BILL-06b now reflects that PromotionCode search is verified-absent, not "conditional on verification".

### D-05: Forbidden operations — omit + `@moduledoc` callout

For any operation forbidden by the Stripe API, the SDK does **NOT** define the function. No `@doc false` stub. No `raise ArgumentError`. No `{:error, :not_supported}` tuple. The function simply does not exist.

**Affected in Phase 12:**
- `LatticeStripe.Price` has no `delete/2,3` (Prices are immutable; archive with `update(active: false)`)
- `LatticeStripe.Coupon` has no `update/3,4` (Coupons are immutable; create a new Coupon to change terms)
- `LatticeStripe.Coupon` has no `search/2,3` (endpoint does not exist; see D-04)
- `LatticeStripe.PromotionCode` has no `search/2,3` (endpoint does not exist; see D-04)

**Discoverability:** Every module with forbidden operations carries an `## Operations not supported by the Stripe API` section in `@moduledoc` listing each absent operation with its workaround. Example for `Price.@moduledoc`:

```markdown
## Operations not supported by the Stripe API

- **delete** — Prices are immutable once created. To stop a Price from being used,
  archive it with `update/3`: `Price.update(client, price_id, %{"active" => "false"})`.
```

Example for `Coupon.@moduledoc`:

```markdown
## Operations not supported by the Stripe API

- **update** — Coupons are immutable by design. To change coupon terms, create a
  new Coupon with the new parameters.
- **search** — The `/v1/coupons/search` endpoint does not exist. Use `list/2` with
  filters for discovery.
```

**Milestone-wide rule (applies to Phases 14-19):**
> Any operation forbidden by Stripe's API is absent from the module AND named in an `## Operations not supported by the Stripe API` section of the `@moduledoc` with the documented workaround. Phase 14 (Invoice finalization constraints) and Phase 15 (Subscription terminal-state constraints) apply this template.

### D-06: PromotionCode discovery via `list/2`

Because PromotionCode has no `search`, consumers discover codes via `LatticeStripe.PromotionCode.list/2` with filters: `code`, `coupon`, `customer`, `active`. The `@moduledoc` contains an explicit "Finding promotion codes" section pointing to `list/2` with filter examples (per https://docs.stripe.com/api/promotion_codes/list).

### D-07: Custom IDs — pass-through + explicit `@doc` distinction

**Stripe data model:**
- `Coupon.id` is optional on create — consumers can supply a specific ID (e.g. `"SUMMER25"`) or let Stripe generate one (e.g. `"8sXjvpGx"`).
- `PromotionCode.id` is always Stripe-generated (`promo_...`). The customer-facing identifier is the separate `code` param (e.g. `"SUMMER25USER"`).

**SDK handling:** Pure pass-through via the params map. No helper functions. No dedicated `create_with_id/3`. Consumers pass `"id"` (Coupon) or `"code"` (PromotionCode) in the params map exactly as Stripe's API documents.

**Documentation contract:** `PromotionCode.@moduledoc` explicitly distinguishes the three identifiers (Coupon.id vs PromotionCode.id vs PromotionCode.code) with examples. This is the SDK's leverage point because the distinction is the #1 common confusion.

**No client-side ID validation.** Stripe's charset/length constraints on custom IDs are the server's contract; client-side validation creates maintenance burden and duplicates server logic. Invalid IDs flow through the existing `%Error{type: :invalid_request_error}` path.

### D-08: `Discount` as a standalone module

`LatticeStripe.Discount` gets its own module (`lib/lattice_stripe/discount.ex`) — not an inner struct of Coupon — because it's a nested field on **multiple** parents (Customer.discount, Subscription.discount, Invoice.discount). Struct fields: `id`, `object`, `coupon: Coupon.t() | nil`, `promotion_code: String.t() | nil`, `customer: String.t() | nil`, `subscription: String.t() | nil`, `invoice: String.t() | nil`, `invoice_item: String.t() | nil`, `start: integer() | nil`, `end: integer() | nil`, `checkout_session: String.t() | nil`. Includes `from_map/1`.

### D-09: FormEncoder battery — hybrid (exhaustive enumerated + StreamData property tests)

Ship both layers. Add `stream_data ~> 1.1` as a `:test`-only dep in `mix.exs`.

#### D-09a: Exhaustive enumerated catalog

A `test/lattice_stripe/form_encoder_test.exs` (or dedicated `form_encoder_battery_test.exs`) file covering every known Stripe nested shape that will be exercised through Phase 19:

1. **Triple-nested `price_data` inline creation** (the roadmap motivating case):
   ```
   items[0][price_data][currency]=usd
   items[0][price_data][unit_amount]=2000
   items[0][price_data][product_data][name]=T-shirt
   items[0][price_data][recurring][interval]=month
   items[0][price_data][recurring][interval_count]=3
   items[0][price_data][recurring][usage_type]=licensed
   items[0][price_data][tax_behavior]=exclusive
   ```

2. **Quadruple-nested** (`transform_quantity` under `price_data` under `items[]`):
   ```
   items[0][price_data][transform_quantity][divide_by]=10
   items[0][price_data][transform_quantity][round]=up
   ```

3. **Arrays of scalars inside maps inside arrays** (`tax_rates`, `expand`):
   ```
   items[0][tax_rates][0]=txr_123
   items[0][tax_rates][1]=txr_456
   expand[0]=data.customer
   expand[1]=data.default_payment_method
   ```

4. **Multiple items with mixed shapes:**
   ```
   items[0][price]=price_existing
   items[1][price_data][currency]=usd
   items[1][price_data][recurring][interval]=year
   ```

5. **Coupon custom ID at top level:**
   ```
   id=SUMMER25
   percent_off=25
   duration=once
   ```

6. **Price Tier lists (flat_amount + up_to):**
   ```
   tiers[0][up_to]=100
   tiers[0][flat_amount]=1000
   tiers[1][up_to]=inf
   tiers[1][unit_amount]=500
   ```

7. **Coupon applies_to products array:**
   ```
   applies_to[products][0]=prod_abc
   applies_to[products][1]=prod_def
   ```

8. **Connect account nested booleans** (forward compat for Phase 17):
   ```
   account[controller][application][loss_liable]=true
   account[controller][stripe_dashboard][type]=express
   ```

9. **Metadata with hyphens, slashes, spaces:** (see D-09c)

10. **Empty-string clear-field semantics:** (see D-09d)

11. **Atom → string coercion round-trip:** (see D-09e)

12. **Integer, float, boolean coercion:**
    ```
    active=true   unit_amount=2000   unit_amount_decimal=12.5
    ```

13. **Alphabetical sort determinism:** same input produces identical output bytes regardless of map iteration order (guarantees deterministic idempotency keys and HTTP request signatures).

14. **Nil omission vs empty-string preservation:** `%{name: nil}` → no output; `%{name: ""}` → `name=`.

Each shape has at least one test with the expected wire-format string as a golden value.

#### D-09b: StreamData property layer

Add property-based tests for structural invariants (no reference decoder needed):

```elixir
use ExUnitProperties

property "nil values are never emitted in encoded output" do
  check all map <- nested_param_map_gen(), max_runs: 500 do
    refute FormEncoder.encode(map) =~ "=nil"
    # And no bare "key=" for a nil field
  end
end

property "output is deterministic (sort stable)" do
  check all map <- nested_param_map_gen() do
    assert FormEncoder.encode(map) == FormEncoder.encode(map)
  end
end

property "all values are URL-decodable" do
  check all map <- nested_param_map_gen() do
    encoded = FormEncoder.encode(map)
    URI.decode_query(encoded)  # must not raise
  end
end

property "no key collisions in output" do
  check all map <- nested_param_map_gen() do
    encoded = FormEncoder.encode(map)
    keys = encoded |> String.split("&") |> Enum.map(&(String.split(&1, "=") |> hd()))
    assert length(keys) == length(Enum.uniq(keys))
  end
end
```

`nested_param_map_gen/0` generates random maps with scalar + map + list children up to depth 4. No round-trip via reference decoder — structural properties only.

#### D-09c: Metadata special-char handling

Phase 12 tests (and fixes if broken) metadata keys containing hyphens, slashes, and spaces:
```
metadata[user-id]=usr_abc       # hyphen
metadata[tenant/plan]=gold      # slash
metadata[hello world]=value     # space → URL-encoded as hello%20world
```
Current `form_encoder.ex:99-107` URL-encodes key segments via `URI.encode_www_form/1`. Battery verifies this holds for all three special chars and that brackets are NOT double-encoded.

#### D-09d: Empty-string clear-field semantics

Phase 12 locks the contract in a test: `%{"name" => nil}` omits the field entirely; `%{"name" => ""}` emits `name=`. Current encoder (`form_encoder.ex:78-81, 91-93`) already behaves this way — battery prevents regression. This matches Stripe's documented convention (empty string = clear field, omit = don't touch).

#### D-09e: Atom value round-trip

Because D-03 atomizes enum fields on ingest, consumers may pass atoms back on update:
```elixir
Price.update(client, price_id, %{"recurring" => %{"interval" => :month}})
```
Battery asserts `FormEncoder.encode(%{recurring: %{interval: :month}})` emits the same bytes as `FormEncoder.encode(%{recurring: %{interval: "month"}})`. Current encoder's `to_string/1` coercion already handles this but it's never been explicitly tested.

#### D-09f: Scientific notation fix (latent bug)

**Latent bug:** Elixir's `to_string/1` on small floats produces scientific notation:
```elixir
iex> to_string(0.00001)
"1.0e-5"
```
Stripe's `unit_amount_decimal` parser rejects this. Phase 12 **fixes** this in `form_encoder.ex` — replace the generic `to_string/1` scalar coercion (line 92-94) with a float-aware encoder:
```elixir
defp encode_scalar(f) when is_float(f) do
  :erlang.float_to_binary(f, [:compact, {:decimals, 12}])
end
defp encode_scalar(v), do: to_string(v)
```
Battery includes test cases for `0.00001`, `1.0e-20`, `12.5`, `0.0`, and negative floats.

### D-10: Search `@doc` eventual-consistency callout (shared wording)

Every `search/2,3` `@doc` in Phase 12 (Product and Price only — see D-04) carries the same shared eventual-consistency block. Implementation: define a module attribute `@search_consistency_doc` in a shared module (or inline the exact same string block in each module) so the wording cannot drift:

```elixir
## Eventual consistency

Search results have eventual consistency. Under normal operating conditions, newly
created or updated objects appear in search results within ~1 minute. During Stripe
outages, propagation may be slower. Do not use `search/2` in read-after-write flows
where strict consistency is necessary. See https://docs.stripe.com/search#data-freshness.
```

Phase 14 (Invoice) and Phase 15 (Subscription) inherit this callout pattern for their search functions.

### D-11: FormEncoder unit battery mixed in with existing form_encoder_test

The battery lives in `test/lattice_stripe/form_encoder_test.exs` alongside any existing simpler tests — not a new file — to keep one canonical form-encoding test suite. Section headers with `describe/2` blocks organize by shape family (triple-nested, quadruple-nested, arrays, coercion, determinism, properties).

### Claude's Discretion

- Exact module path for `Discount` (`lib/lattice_stripe/discount.ex` is the obvious choice; planner confirms)
- Whether `Price.Recurring`, `Price.Tier`, `Coupon.AppliesTo` live in separate files (`lib/lattice_stripe/price/recurring.ex`) or inline in their parent module file — planner picks based on file-size conventions in the v1 codebase
- Whether the eventual-consistency doc block lives as a `@search_consistency_doc` module attribute in `LatticeStripe.Resource` or is duplicated verbatim in each resource (DRY vs explicit)
- Exact wording and placement of `## Operations not supported by the Stripe API` sections
- Name and structure of the `atomize_*` helper functions (e.g. free functions in each module vs a shared `LatticeStripe.Enum` helper)
- StreamData generator shape — planner chooses depth/breadth limits based on CI time budget
- Whether the atom-value round-trip test lives in the FormEncoder battery or in each resource's update-path integration tests (or both)

### Folded Todos

None — `gsd-tools todo match-phase 12` returned zero matches.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-level
- `.planning/PROJECT.md` — design philosophy, v2.0 milestone goals, key decisions, out-of-scope
- `.planning/REQUIREMENTS.md` — BILL-01, BILL-02, BILL-06, BILL-06b (BILL-06b was updated during this discussion to reflect verified-absent search)
- `.planning/ROADMAP.md` — Phase 12 goal, dependencies, success criteria (lines 44-53)
- `CLAUDE.md` — tech stack, conventions, constraints, GSD workflow enforcement

### v1 resource template (match this pattern)
- `lib/lattice_stripe/customer.ex` — canonical v1 resource template (struct, `@known_fields`, `from_map/1`, `Resource.unwrap_singular/unwrap_list`, CRUD signatures)
- `lib/lattice_stripe/resource.ex` — `unwrap_singular/2`, `unwrap_list/2` shared helpers
- `lib/lattice_stripe/form_encoder.ex` — current form encoder (114 LOC) — target of D-09 battery and D-09f fix
- `lib/lattice_stripe/request.ex` — `%Request{}` struct used by all resource CRUD
- `lib/lattice_stripe/client.ex` — `Client.request/2` entry point
- `lib/lattice_stripe/error.ex` — `%Error{}` struct (for `:invalid_request_error` type referenced in D-07)
- `lib/lattice_stripe/list.ex` — list response wrapper used by `list/2` and `stream!/2`
- `lib/lattice_stripe/payment_intent.ex` — reference for a resource with search (compare `search/3` signature)
- `lib/lattice_stripe/checkout/session.ex` (or wherever Checkout lives) — reference for nested line items (closest existing example of `items[0][price_data]` shapes)

### Stripe API references (external)
- https://docs.stripe.com/api/products — Product object, fields, endpoints
- https://docs.stripe.com/api/prices — Price object, `recurring`, `tiers`, `transform_quantity`, `custom_unit_amount`
- https://docs.stripe.com/api/coupons — Coupon object, `applies_to`, `duration`, immutability
- https://docs.stripe.com/api/promotion_codes — PromotionCode object, `code` vs `id` distinction, list filters
- https://docs.stripe.com/api/promotion_codes/list — discovery path (D-06)
- https://docs.stripe.com/search — search-enabled resources list, query language, eventual consistency
- https://docs.stripe.com/search#data-freshness — exact eventual-consistency wording reference for D-10
- https://github.com/stripe/openapi/blob/master/openapi/spec3.sdk.json — authoritative source for D-04 (`/search` endpoint enumeration)

### SDK comparison (for planner's reference, not to be copied from)
- https://github.com/stripe/stripe-ruby/blob/master/lib/stripe/resources/price.rb — reference for typed nested pattern
- https://github.com/stripe/stripe-ruby/blob/master/lib/stripe/resources/coupon.rb — `APIOperations::Save` + `APIOperations::Delete`, no update, no search
- https://github.com/stripe/stripe-ruby/blob/master/lib/stripe/resources/promotion_code.rb — no search operation
- https://github.com/stripe/stripe-node/blob/master/types/PromotionCodesResource.d.ts — TypeScript confirmation that search is absent
- https://github.com/beam-community/stripity_stripe/blob/main/lib/generated/price.ex — cautionary counterexample (all nesteds as `term`)

### Internal research (if needed)
- `prompts/` directory — PROJECT.md references "extensive deep research documents" covering Stripe API surface, Elixir patterns, SDK comparisons. Planner should skim for any Phase 12-relevant notes.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`LatticeStripe.Resource.unwrap_singular/2` and `unwrap_list/2`** (`lib/lattice_stripe/resource.ex`) — Phase 12 CRUD all routes through these exactly like Customer/PaymentIntent; no new unwrapping code
- **`LatticeStripe.FormEncoder.encode/1`** — handles 95% of Phase 12's needs out of the box; only the scientific-notation float fix (D-09f) requires a code change. All other decisions are test additions.
- **`LatticeStripe.Request` / `Client.request/2`** — unchanged; Phase 12 resources build `%Request{}` structs exactly as v1 does
- **`LatticeStripe.Error`** — reused for PromotionCode custom-ID validation errors (D-07) flowing as `:invalid_request_error`
- **`LatticeStripe.List`** — `list/2` result type, unchanged
- **`LatticeStripe.Customer.from_map/1`** — copy-adapt pattern for each new resource's `from_map/1`. Copy struct definition, `@known_fields`, `from_map/1` body, and tweak per-resource.

### Established Patterns
- **String-keyed params throughout** — v1 resources all accept `%{"field" => "value"}`. Phase 12 matches. FormEncoder `to_string/1`-coerces atoms, so atom-keyed maps work, but docs/examples use strings.
- **`{:ok, t()} | {:error, Error.t()}` everywhere** — no bang variants on CRUD. `stream!/2` is the only bang.
- **`extra: %{}` catch-all map** on every resource struct — any field Stripe adds that we haven't declared lands there. D-02 `Discount` module follows the same pattern.
- **Search functions take a second positional query arg** (`search(client, query, opts \\ [])`) — copy Customer.search/3 shape
- **`@known_fields ~w[...]` sigil** defines the string-keyed field allowlist in each module (see `customer.ex:53-59`)
- **`@doc` blocks carry `## Parameters` + `## Returns` + `## Example`** — Phase 12 resources follow this structure

### Integration Points
- **`mix.exs` deps list** — add `{:stream_data, "~> 1.1", only: :test}` for D-09b property tests. No runtime deps added.
- **`test/test_helper.exs`** — no changes expected; StreamData integrates via `use ExUnitProperties` in individual test modules
- **`lib/lattice_stripe/customer.ex` line 111** — backfill target for D-02 (`discount: map()` → `discount: LatticeStripe.Discount.t() | nil`)
- **`lib/lattice_stripe/customer.ex` `from_map/1`** — must call `LatticeStripe.Discount.from_map/1` when building the struct (D-02)
- **`lib/lattice_stripe/form_encoder.ex` line 92-94** — scalar coercion site; float branch added for D-09f
- **New files expected:**
  - `lib/lattice_stripe/product.ex` + `test/lattice_stripe/product_test.exs`
  - `lib/lattice_stripe/price.ex` (+ `price/recurring.ex`, `price/tier.ex` if planner splits) + test
  - `lib/lattice_stripe/coupon.ex` (+ `coupon/applies_to.ex` if split) + test
  - `lib/lattice_stripe/promotion_code.ex` + test
  - `lib/lattice_stripe/discount.ex` + test
  - `test/lattice_stripe/form_encoder_test.exs` — expanded with battery (D-09a/b/c/d/e/f)
- **stripe-mock integration tests** — each new resource gets an integration test file (pattern established in v1 phases 4-6)

</code_context>

<specifics>
## Specific Ideas

- **"Principle of least surprise" (PROJECT.md)** drove the atom-whitelist decision (D-03) — forward-compatible by construction, never crashes on new Stripe enum values.
- **"Pattern-matchable returns — domain-rich types, not boolean soup" (PROJECT.md)** drove the strategic-typing tier (D-01) — `Price.Recurring` is the textbook case for domain-rich typing.
- **"Missing functions, not runtime errors" (ROADMAP Phase 12 success criterion #1)** drove D-05 — omit, don't stub.
- **stripe-ruby / stripe-node / stripe-go behavior** is the reference point for D-01, D-05, D-07. When in doubt, match what 4-of-5 official SDKs do. The outlier (stripity_stripe) is unmaintained and explicitly cited as the thing LatticeStripe is replacing.
- **stripe-mock acceptance is NOT proof an endpoint exists** (D-04 research note) — the OpenAPI spec is authoritative. stripe-mock is generated from the spec but may be lenient.
- **Scientific notation on floats (D-09f)** is a latent bug in v1's FormEncoder that happens to not bite Payments because `unit_amount` is always an integer. Phase 12 is the first phase where a decimal unit amount ships (`unit_amount_decimal` on Prices), so it becomes the first phase where this can bite.

</specifics>

<deferred>
## Deferred Ideas

- **Typing all remaining nested shapes** (`Price.TransformQuantity`, `Price.CustomUnitAmount`, `Product.PackageDimensions`, `Price.CurrencyOptions` value shape) — deferred per D-01's "strategic typing" rule. Revisit in future milestones if downstream phases start pattern-matching on them.
- **Typed nesteds on existing v1 resources** (beyond the `Customer.discount` backfill in D-02) — `Customer.address`, `Customer.shipping`, `Customer.cash_balance`, `Customer.invoice_settings`, and all nesteds on `PaymentIntent`/`SetupIntent`/`PaymentMethod`/`Refund`/`Checkout.Session` remain as `map()`. Backfill is out of Phase 12 scope. Consider a dedicated "v1 nested typing polish" phase if pain accumulates.
- **Client-side validation of Stripe ID formats** (D-07 rejection) — ruled out explicitly. Revisit if users complain about cryptic 400 errors on malformed custom IDs, but probably never.
- **OpenAPI-driven codegen** — PROJECT.md ADVN-02, deferred beyond v2. All Phase 12 resources are hand-written following the v1 template.
- **Billing Meters** (BILL-07) — `Billing.Meter`, `MeterEvent`, `MeterEventAdjustment`, `MeterEventSummary` are explicitly out-of-scope for v2, deferred to a future milestone.
- **BillingPortal** (BILL-05) — `BillingPortal.Session`, `BillingPortal.Configuration` deferred beyond v2.
- **StreamData with reference decoder** — D-09b uses structural invariants only (no round-trip). A future enhancement could build a reference decoder for full semantic round-trip testing, but it's not worth the maintenance cost right now.
- **Coupon.search / PromotionCode.search** — the Stripe endpoints do not exist. If Stripe ever adds them, a future phase revisits D-04.

### Reviewed Todos (not folded)

None — no todos matched Phase 12 via `gsd-tools todo match-phase 12`.

</deferred>

---

*Phase: 12-billing-catalog*
*Context gathered: 2026-04-11*
