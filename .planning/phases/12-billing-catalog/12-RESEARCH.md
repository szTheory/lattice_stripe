# Phase 12: Billing Catalog - Research

**Researched:** 2026-04-11
**Domain:** Stripe billing catalog (Products, Prices, Coupons, PromotionCodes, Discount) — Elixir SDK resource modules
**Confidence:** HIGH — every decision derives from verified in-repo patterns and/or CONTEXT.md locks

## Summary

Phase 12 is almost entirely a **copy-adapt-from-template** job. The v1 codebase (Customer, PaymentIntent, Checkout.Session) already establishes the full resource template: `@known_fields` sigil, `defstruct` with `object:` default and `extra: %{}` catch-all, `from_map/1`, CRUD functions that build `%Request{}` then pipe through `Client.request/2 |> Resource.unwrap_singular|unwrap_list`, matching bang variants, `stream!/2` via `List.stream!/2`, optional `search/3` + `search_stream!/3`, and an `Inspect` protocol impl. Phase 12 adds five new resource modules following that template verbatim, four typed nested structs (`Price.Recurring`, `Price.Tier`, `Coupon.AppliesTo`, and standalone `Discount`), one FormEncoder patch (scientific-notation float), and one substantial test battery addition. **Zero runtime deps added**; one test-only dep (`stream_data ~> 1.3`). Zero behaviour changes, zero HTTP/retry/pagination modifications.

The planner's main job is: (a) decide nested-struct file layout (inline vs sibling file), (b) decide whether the search `@doc` eventual-consistency block lives as a module attribute in `LatticeStripe.Resource` or is inlined per-module, (c) structure wave ordering so the FormEncoder fix (D-09f) lands before `Price.update` integration tests can hit the scientific-notation path, and (d) enumerate every Stripe field per resource so the `@known_fields` sigils and `from_map/1` bodies can be written in one pass per resource.

**Primary recommendation:** Order the waves as (1) FormEncoder fix + battery + `stream_data` dep, (2) `Discount` + `Customer.discount` backfill, (3) `Product`, (4) `Price` (+ `Price.Recurring`, `Price.Tier`), (5) `Coupon` (+ `Coupon.AppliesTo`), (6) `PromotionCode`. Steps 3-6 are independent but sequenced for review clarity. Nested structs go **inline in the parent module file** — current v1 convention (Checkout.LineItem in a sibling file) only splits when the nested thing is independently returned by an endpoint; `Price.Recurring` is never a top-level response, so it stays inline. Discount is the exception because it is a nested field on multiple parents (locked by D-08).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01 — Strategic nested struct typing (Tier 2).** Type now: `Price.Recurring`, `Price.Tier`, `Coupon.AppliesTo`, `Discount`. Leave as `map()` with typespec: `Price.transform_quantity`, `Price.custom_unit_amount`, `Price.currency_options` value shape, `Product.package_dimensions`. Milestone rule: a nested object becomes a typed struct iff downstream phases pattern-match on it.

**D-02 — Backfill `Customer.discount` to `%Discount{}`.** `lib/lattice_stripe/customer.ex` line 111 changes from `discount: map() | nil` to `discount: LatticeStripe.Discount.t() | nil`; `from_map/1` must call `Discount.from_map/1` on the `"discount"` key when non-nil.

**D-03 — Whitelist atomization of enum-like fields.** Convert known Stripe enum strings to atoms on ingest; unknown values pass through as raw string. Type becomes `:known | String.t()`. Never `String.to_atom/1`. Phase 12 atomizes: `Price.type`, `Price.billing_scheme`, `Price.tax_behavior`, `Price.Recurring.interval`, `Price.Recurring.usage_type`, `Price.Recurring.aggregate_usage`, `Price.Tier.up_to` (with `:inf` for the literal `"inf"`), `Product.type`, `Coupon.duration`.

**D-04 — Search only on Product and Price.** Verified against Stripe OpenAPI spec: only `charges`, `customers`, `invoices`, `payment_intents`, `prices`, `products`, `subscriptions` have `/search`. `Coupon.search` and `PromotionCode.search` are absent — do not define them.

**D-05 — Forbidden operations omitted, not stubbed.** No `@doc false`, no `raise`, no `{:error, :not_supported}`. Function simply does not exist. Affected: `Price.delete`, `Coupon.update`, `Coupon.search`, `PromotionCode.search`. Each parent `@moduledoc` carries an `## Operations not supported by the Stripe API` section with the documented workaround.

**D-06 — PromotionCode discovery via `list/2`.** `@moduledoc` contains a "Finding promotion codes" section pointing at `list/2` filters: `code`, `coupon`, `customer`, `active`.

**D-07 — Custom IDs via pass-through params, no helpers.** `Coupon.id` and `PromotionCode.code` both flow through the params map as-is. No `create_with_id/3`. No client-side ID validation. `PromotionCode.@moduledoc` explicitly distinguishes the three identifiers (Coupon.id vs PromotionCode.id vs PromotionCode.code).

**D-08 — `Discount` as a standalone module** at `lib/lattice_stripe/discount.ex`. Fields: `id`, `object`, `coupon: Coupon.t() | nil`, `promotion_code: String.t() | nil`, `customer: String.t() | nil`, `subscription: String.t() | nil`, `invoice: String.t() | nil`, `invoice_item: String.t() | nil`, `start: integer() | nil`, `end: integer() | nil`, `checkout_session: String.t() | nil`. Includes `from_map/1`.

**D-09 — FormEncoder battery = exhaustive enumerated + StreamData property tests.** Add `{:stream_data, "~> 1.1", only: :test}` to `mix.exs`. Battery lives in `test/lattice_stripe/form_encoder_test.exs` (extended, not a new file). D-09a enumerated cases cover triple-nested `price_data`, quadruple-nested `transform_quantity`, arrays of scalars, multiple items with mixed shapes, coupon custom id, price tiers (`up_to: "inf"`), coupon `applies_to[products]`, connect account nested booleans, metadata with hyphens/slashes/spaces, empty-string clear-field semantics, atom→string round-trip, int/float/bool coercion, alphabetical sort determinism, nil omission vs empty-string. D-09b StreamData properties assert: nil never emitted, output deterministic, output URL-decodable, no key collisions.

**D-09c — Metadata special-char handling.** Verify hyphens/slashes/spaces in metadata keys URL-encode key segments via `URI.encode_www_form/1`; brackets never double-encoded. Current impl at `form_encoder.ex:99-107` already behaves correctly.

**D-09d — Empty-string clear-field semantics.** `%{"name" => nil}` omits the field; `%{"name" => ""}` emits `name=`. Current impl at `form_encoder.ex:78-81, 91-93`. Battery locks this contract.

**D-09e — Atom value round-trip.** `FormEncoder.encode(%{recurring: %{interval: :month}})` and `FormEncoder.encode(%{recurring: %{interval: "month"}})` must produce identical bytes. Current `to_string/1` coercion at line 91-93 already handles this; battery pins it.

**D-09f — Scientific notation fix.** Replace scalar coercion at `form_encoder.ex:91-93` with a float-aware encoder:
```elixir
defp flatten_value(value, key) when is_float(value) do
  [{key, :erlang.float_to_binary(value, [:compact, {:decimals, 12}])}]
end
defp flatten_value(value, key) do
  [{key, to_string(value)}]
end
```
Test cases: `0.00001`, `1.0e-20`, `12.5`, `0.0`, negative floats.

**D-10 — Shared eventual-consistency `@doc` for search.** Every `search/2` `@doc` in Phase 12 (Product, Price only) carries the same wording block. Options: module attribute `@search_consistency_doc` in `LatticeStripe.Resource`, or inline verbatim per module. Planner picks. Wording fixed in CONTEXT.md.

**D-11 — Battery mixed into existing `form_encoder_test.exs`**, not a new file. `describe/2` blocks organize by shape family.

### Claude's Discretion

- Exact module path for `Discount` (`lib/lattice_stripe/discount.ex` is obvious; planner confirms).
- Whether `Price.Recurring`, `Price.Tier`, `Coupon.AppliesTo` live in separate files (`lib/lattice_stripe/price/recurring.ex`) or inline. **Recommendation below:** inline (see Architecture Patterns).
- Whether the eventual-consistency doc block lives as a module attribute in `LatticeStripe.Resource` or is duplicated verbatim in each resource.
- Exact wording/placement of `## Operations not supported by the Stripe API` sections.
- Name/structure of `atomize_*` helper functions (free functions in each module vs shared `LatticeStripe.Enum` helper). **Recommendation below:** private module functions, not a shared helper (see Architecture Patterns).
- StreamData generator shape — depth/breadth limits based on CI time budget.
- Whether the atom-value round-trip test lives in the FormEncoder battery, in each resource's update-path integration tests, or both.

### Deferred Ideas (OUT OF SCOPE)

- Typing all remaining nested shapes beyond D-01's strategic set.
- Typed nesteds on existing v1 resources beyond the `Customer.discount` backfill.
- Client-side validation of Stripe ID formats.
- OpenAPI-driven codegen.
- Billing Meters (BILL-07).
- BillingPortal (BILL-05).
- StreamData with reference decoder (round-trip semantics).
- `Coupon.search` / `PromotionCode.search` (verified absent).
- Subscriptions, Invoices, BillingPortal, Meters — deferred to later phases.
- Re-evaluating D-01 through D-11 — locked.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BILL-01 | Developer can manage Products — create, retrieve, update, list, stream, search | v1 Customer template (Customer.ex) is the exact shape to copy. Product has no delete (archive via `update(active: false)`). Product search is confirmed available. |
| BILL-02 | Developer can manage Prices — create, retrieve, update, list, stream, search (no delete — Stripe constraint) | Same template; skip `delete/3`. Includes nested `Price.Recurring`, `Price.Tier` typed structs (D-01). Archive via `update(active: false)` — documented in moduledoc `## Operations not supported by the Stripe API`. |
| BILL-06 | Developer can manage Coupons — create, retrieve, delete, list, stream (no update, no search — Stripe constraints) | Template omits `update/4` and `search/3`. `Coupon.AppliesTo` typed nested. Custom ID via pass-through `"id"` param (D-07). |
| BILL-06b | Developer can manage Promotion Codes — create, retrieve, update, list, stream. Search NOT supported: verified absent in OpenAPI spec. | Full template including `update/4` but NOT `search/3`. Discovery via `list/2` with `code`/`coupon`/`customer`/`active` filters (D-06). Custom code via pass-through `"code"` param (D-07). |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

Extracted actionable directives the planner must honor:

| Constraint | Source | Impact on Phase 12 |
|------------|--------|--------------------|
| Elixir >= 1.15, OTP >= 26 | CLAUDE.md Platform Target | All new code must compile on 1.15; no 1.18+ stdlib `JSON`, no 1.17+ sigil features. CI matrix 1.15/1.17/1.19 × OTP 26/27/28. |
| No Dialyzer | CLAUDE.md Constraints + Key Decisions | Typespecs are documentation only — `:known_atom \| String.t()` unions are valid. Do not add `@spec` discipline gates. |
| Minimal deps | CLAUDE.md Constraints | Phase 12 adds exactly one dep: `{:stream_data, "~> 1.3", only: :test}` (see Standard Stack). No runtime deps added. |
| Jason for JSON | CLAUDE.md | All `from_map/1` consume string-keyed maps from Jason decoding. |
| Finch as default transport | CLAUDE.md | No transport changes in Phase 12; integration tests reuse `LatticeStripe.IntegrationFinch` pool. |
| GSD workflow enforcement | CLAUDE.md | Planner must use `/gsd-plan-phase` and `/gsd-execute-phase`; no direct edits. |
| Forbidden tools | CLAUDE.md "What NOT to Use" | No HTTPoison, Poison, Tesla, Req, ExVCR, Bypass, Ecto, GenServer-for-state, Dialyzer. (None of these are at risk in Phase 12.) |
| Credo `--strict` in CI | `mix.exs` aliases | New resource modules must pass `credo --strict`. Existing `PaymentIntent` uses `credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount` on large structs — Phase 12's Product/Price will likely need the same annotation. |
| `format --check-formatted` in CI | `mix.exs` aliases | All new files must pass `mix format`. |
| `compile --warnings-as-errors` in CI | `mix.exs` aliases | No unused aliases, no undefined helper references. |
| `docs --warnings-as-errors` in CI | `mix.exs` aliases | Every `@doc` must have valid markdown; ExDoc fails on broken refs. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| (none added for runtime) | — | Phase 12 introduces **zero** new runtime deps | PROJECT.md: "Minimal — only what's truly needed". Existing Finch/Jason/Telemetry/Plug stack covers all Phase 12 needs. |

### Supporting (test-only)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `stream_data` | `~> 1.3` (tested on 1.1+) | Property-based testing via `ExUnitProperties` and `StreamData` generators | D-09b FormEncoder property layer. `use ExUnitProperties` in `form_encoder_test.exs`. Import `StreamData` for generators. `[VERIFIED: hex.pm/packages/stream_data — v1.3.0, released 2026-03-09]` |

**Installation** (add to `mix.exs` `deps/0`):
```elixir
{:stream_data, "~> 1.3", only: :test}
```

**Note on version pin:** CONTEXT.md D-09 says `~> 1.1`. That pin is valid (`~> 1.1` allows anything `>= 1.1.0 and < 2.0.0`, which includes 1.3.0). The planner can choose either `~> 1.1` (broader) or `~> 1.3` (current). Recommend `~> 1.1` to match CONTEXT.md verbatim and not drift. `[VERIFIED: hex.pm/packages/stream_data]`

### Version Verification
| Package | Pin | Verified Current | Published |
|---------|-----|------------------|-----------|
| stream_data | `~> 1.1` | 1.3.0 | 2026-03-09 `[VERIFIED: hex.pm]` |
| finch | `~> 0.19` (existing) | 0.21.x | existing pin — not changed |
| jason | `~> 1.4` (existing) | 1.4.4 | existing pin — not changed |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| stream_data | hand-rolled Enumerable generators | ExUnitProperties integration (shrinking on failure, `check all` syntax) is the whole point. Hand-rolling loses failure minimization and clutter-free DX. Use stream_data. |
| stream_data | PropCheck (QuickCheck-style) | PropCheck is Erlang-flavored and has heavier setup. stream_data is Dashbit-maintained, idiomatic Elixir, used by Elixir core for their own property tests. |
| Adding a reference FormEncoder decoder for round-trip | (nothing) | Explicitly deferred per CONTEXT.md D-09b: "structural invariants only — no round-trip". Not worth maintenance cost. |

## Architecture Patterns

### Recommended File Layout
```
lib/lattice_stripe/
├── customer.ex                  # MODIFIED: discount field retype + from_map update (D-02)
├── form_encoder.ex              # MODIFIED: float scalar branch (D-09f)
├── discount.ex                  # NEW: standalone struct module (D-08)
├── product.ex                   # NEW: resource template
├── price.ex                     # NEW: resource template + inline Recurring and Tier
├── coupon.ex                    # NEW: resource template + inline AppliesTo
└── promotion_code.ex            # NEW: resource template (no search)

test/lattice_stripe/
├── form_encoder_test.exs        # EXTENDED: D-09a/b/c/d/e/f battery
├── discount_test.exs            # NEW: from_map only, no CRUD
├── product_test.exs             # NEW: unit tests (Mox-based)
├── price_test.exs               # NEW
├── coupon_test.exs              # NEW
└── promotion_code_test.exs      # NEW

test/integration/
├── product_integration_test.exs           # NEW: stripe-mock
├── price_integration_test.exs             # NEW: stripe-mock
├── coupon_integration_test.exs            # NEW: stripe-mock
└── promotion_code_integration_test.exs    # NEW: stripe-mock
```

### Pattern 1: Resource Module Template (copy from `customer.ex`)

Every Phase 12 resource follows this shape exactly. The only variation across Customer vs PaymentIntent is which CRUD verbs and action verbs exist.

```elixir
defmodule LatticeStripe.Product do
  @moduledoc """
  Operations on Stripe Product objects.

  ...

  ## Operations not supported by the Stripe API

  (include only if applicable — Product has no forbidden ops)

  ## Stripe API Reference

  See the [Stripe Product API](https://docs.stripe.com/api/products) for the full
  object reference and available parameters.
  """

  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  @known_fields ~w[
    id object active attributes caption created default_price deleted
    description features images livemode marketing_features metadata
    name package_dimensions shippable statement_descriptor tax_code
    type unit_label updated url
  ]

  defstruct [
    :id,
    :active,
    # ... every field ...
    object: "product",
    deleted: false,
    extra: %{}
  ]

  @type t :: %__MODULE__{ ... }

  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/products", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  # retrieve/3, update/4, list/3, stream!/3, search/3, search_stream!/3
  # + create!/3 retrieve!/3 update!/4 list!/3 search!/3 bang variants

  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "product",
      # ... verbatim field assignment ...
      extra: Map.drop(map, @known_fields)
    }
  end
end
```

**Key observations from reading `customer.ex` and `payment_intent.ex`:**
- `Resource` is aliased and `unwrap_singular`/`unwrap_list` are always called via the pipe (`|> then(&Client.request(client, &1)) |> Resource.unwrap_singular(&from_map/1)`).
- `extra: Map.drop(map, @known_fields)` is the universal pattern — the `@known_fields ~w[...]` sigil is used verbatim as the argument to `Map.drop`.
- Struct `defstruct` lists every field with a leading `:` except `object:` (which gets a default string) and `extra: %{}` (and any bool like `deleted: false`).
- `@spec` lines are consistent across modules — use `t()`, `Client.t()`, `Error.t()`, `Response.t()`, `Enumerable.t()` in the same pattern.
- Bang variants are trivial one-liners: `def create!(c, p, o), do: create(c, p, o) |> Resource.unwrap_bang!()`.
- Large struct field counts (PaymentIntent has ~40) use `# credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount` above `defstruct` — Product and Price will likely need this.
- `Inspect` protocol impl is at the bottom of each module in a `defimpl Inspect, for: LatticeStripe.X do ... end` block. Customer hides PII; PaymentIntent hides `client_secret`. Phase 12 resources have nothing sensitive enough to require custom Inspect (Product is fully public data, Price is public, Coupon/PromotionCode are marketing codes). **Recommendation: skip custom Inspect for Phase 12 modules** unless the planner identifies a specific field worth hiding. If omitted, the default struct inspect applies — totally fine.

### Pattern 2: Resource with Search (copy search region from `payment_intent.ex` lines 482-549)

`Product` and `Price` get the search block from PaymentIntent verbatim, with only the path and module name swapped:

```elixir
@spec search(Client.t(), String.t(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
def search(%Client{} = client, query, opts \\ []) when is_binary(query) do
  %Request{
    method: :get,
    path: "/v1/products/search",
    params: %{"query" => query},
    opts: opts
  }
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_list(&from_map/1)
end

@spec search!(Client.t(), String.t(), keyword()) :: Response.t()
def search!(%Client{} = client, query, opts \\ []) when is_binary(query) do
  search(client, query, opts) |> Resource.unwrap_bang!()
end

@spec search_stream!(Client.t(), String.t(), keyword()) :: Enumerable.t()
def search_stream!(%Client{} = client, query, opts \\ []) when is_binary(query) do
  req = %Request{
    method: :get,
    path: "/v1/products/search",
    params: %{"query" => query},
    opts: opts
  }
  List.stream!(client, req) |> Stream.map(&from_map/1)
end
```

Customer's search `@doc` already has an eventual-consistency sentence (`customer.ex:272-274`) but it's a short inline note, not the full block D-10 prescribes. **Phase 12 upgrades the wording** — the new Phase 12 search blocks carry the long-form D-10 callout, and Phase 19's UTIL-06 can retro-apply the wording to Customer/PaymentIntent/CheckoutSession. That retro-apply is out of scope for Phase 12; only Product and Price get the new wording.

### Pattern 3: Nested Typed Structs — Inline in Parent Module

Reading `lib/lattice_stripe/checkout/line_item.ex` and `lib/lattice_stripe/checkout/session.ex`: the **only** case where v1 splits nested structs into a sibling file is `Checkout.LineItem`, and it's split because line items are returned by a dedicated endpoint (`GET /v1/checkout/sessions/:id/line_items`) — i.e., `LineItem` is a first-class response object with its own `from_map/1` consumed by `Resource.unwrap_list`.

**Phase 12's typed nesteds are not endpoint responses** — they are sub-shapes of their parent's response body. `Price.Recurring` is only ever read via `price.recurring`. `Coupon.AppliesTo` is only ever read via `coupon.applies_to`. They are never separately fetched.

**Recommendation: inline nested structs in the parent module file** as sibling `defmodule LatticeStripe.Price.Recurring do ... end` blocks after the main module. This keeps field inventory locality, keeps git history of "all Price changes" in one file, and avoids the file-per-micro-struct explosion that `stripity_stripe` suffers from.

Exception: `Discount` is locked to its own file per D-08 (shared across multiple parents).

Example inline pattern for `price.ex`:

```elixir
defmodule LatticeStripe.Price do
  @moduledoc "..."
  # ... main module ...
end

defmodule LatticeStripe.Price.Recurring do
  @moduledoc """
  Typed representation of a Price's `recurring` nested object.
  See https://docs.stripe.com/api/prices/object#price_object-recurring.
  """

  @known_fields ~w[aggregate_usage interval interval_count meter trial_period_days usage_type]

  defstruct [:aggregate_usage, :interval, :interval_count, :meter, :trial_period_days, :usage_type, extra: %{}]

  @type t :: %__MODULE__{
          aggregate_usage: :sum | :last_during_period | :last_ever | :max | String.t() | nil,
          interval: :day | :week | :month | :year | String.t() | nil,
          interval_count: integer() | nil,
          meter: String.t() | nil,
          trial_period_days: integer() | nil,
          usage_type: :licensed | :metered | String.t() | nil,
          extra: map()
        }

  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      aggregate_usage: atomize_aggregate_usage(map["aggregate_usage"]),
      interval: atomize_interval(map["interval"]),
      interval_count: map["interval_count"],
      meter: map["meter"],
      trial_period_days: map["trial_period_days"],
      usage_type: atomize_usage_type(map["usage_type"]),
      extra: Map.drop(map, @known_fields)
    }
  end

  # Whitelist-based enum atomization (D-03). Unknown values pass through as strings.
  defp atomize_interval("day"), do: :day
  defp atomize_interval("week"), do: :week
  defp atomize_interval("month"), do: :month
  defp atomize_interval("year"), do: :year
  defp atomize_interval(other), do: other   # nil or forward-compat string

  defp atomize_usage_type("licensed"), do: :licensed
  defp atomize_usage_type("metered"), do: :metered
  defp atomize_usage_type(other), do: other

  defp atomize_aggregate_usage("sum"), do: :sum
  defp atomize_aggregate_usage("last_during_period"), do: :last_during_period
  defp atomize_aggregate_usage("last_ever"), do: :last_ever
  defp atomize_aggregate_usage("max"), do: :max
  defp atomize_aggregate_usage(other), do: other
end
```

Parent `Price.from_map/1` calls `Price.Recurring.from_map/1` when `map["recurring"]` is a map:

```elixir
recurring:
  case map["recurring"] do
    nil -> nil
    r when is_map(r) -> LatticeStripe.Price.Recurring.from_map(r)
  end,
```

Same shape for `tiers: Enum.map(map["tiers"] || [], &LatticeStripe.Price.Tier.from_map/1)`.

### Pattern 4: Whitelist Atomization Helpers — Private Module Functions

**Recommendation:** keep atomize helpers as **private functions in the owning module** (not a shared `LatticeStripe.Enum` helper). Rationale:

- Each enum is owned by exactly one field on one struct. A shared helper would need dispatch on field name, adding indirection for zero reuse.
- Discoverability: a reader looking at `Price.Recurring.t()` sees `atomize_interval/1` in the same file and understands the whitelist immediately.
- Credo won't complain about module size — each helper is three lines.
- The "milestone-wide rule" in D-03 is a **convention** ("every enum gets whitelist atomization"), not an API contract that needs to be shared code.

If pain accumulates in Phases 13-19 with repeated patterns, extract to `LatticeStripe.Enum` in a later cleanup phase. Don't prematurely DRY.

### Pattern 5: FormEncoder Scalar Scaffolding (D-09f fix)

Current `form_encoder.ex:91-94`:

```elixir
defp flatten_value(value, key) do
  # Scalar: boolean, integer, float, atom, binary
  [{key, to_string(value)}]
end
```

Replacement (insert a float-specific clause **above** the generic one):

```elixir
defp flatten_value(value, key) when is_float(value) do
  [{key, :erlang.float_to_binary(value, [:compact, {:decimals, 12}])}]
end

defp flatten_value(value, key) do
  # Scalar: boolean, integer, atom, binary
  [{key, to_string(value)}]
end
```

Verification: `iex> :erlang.float_to_binary(0.00001, [:compact, {:decimals, 12}])` returns `"0.00001"` (confirmed behavior of Erlang's `float_to_binary/2` with `:compact` option — standard Erlang stdlib). `[CITED: https://www.erlang.org/doc/man/erlang.html#float_to_binary-2]`

Edge cases the battery must cover:
- `0.00001` → `"0.00001"` (not `"1.0e-5"`)
- `1.0e-20` → `"0.00000000000000000001"` — wait, this is the trap. With `{:decimals, 12}`, `1.0e-20` would round to `"0.000000000000"` which is lossy. The planner should **verify in iex** during Wave 0 what `:erlang.float_to_binary(1.0e-20, [:compact, {:decimals, 12}])` actually produces and possibly widen `:decimals` to 20 or switch to `:scientific` for extreme magnitudes. Stripe's `unit_amount_decimal` supports up to 12 decimal places per Stripe docs, so `{:decimals, 12}` is likely right for the domain. `[ASSUMED — A1]`
- `12.5` → `"12.5"` (baseline)
- `0.0` → `"0.0"` (must not drop trailing zero; must not become `"0"`)
- `-1.5` → `"-1.5"`

**Alternative:** use `Float.to_string/1` (which in Elixir 1.15+ uses shortest-roundtrip format by default). The planner should compare `Float.to_string(0.00001)` vs `:erlang.float_to_binary(0.00001, [:compact, {:decimals, 12}])` in iex during Wave 0 and pick whichever produces cleaner Stripe-compatible output across the whole test set. Elixir's `Float.to_string/1` calls into `:io_lib_format` internals and **may itself emit scientific notation for very small magnitudes** — `[ASSUMED — A2]` — so `:erlang.float_to_binary/2` with explicit options is the more predictable choice.

### Pattern 6: StreamData Integration (D-09b property tests)

```elixir
defmodule LatticeStripe.FormEncoderTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias LatticeStripe.FormEncoder

  describe "encode/1 — properties" do
    property "nil values are never emitted as bare key=" do
      check all map <- nested_param_map_gen(), max_runs: 500 do
        encoded = FormEncoder.encode(map)
        refute encoded =~ ~r/\bnil\b/
      end
    end

    property "output is deterministic" do
      check all map <- nested_param_map_gen() do
        assert FormEncoder.encode(map) == FormEncoder.encode(map)
      end
    end

    property "output is URL-decodable" do
      check all map <- nested_param_map_gen() do
        _ = URI.decode_query(FormEncoder.encode(map))
      end
    end
  end

  # Generator helpers
  defp scalar_gen do
    one_of([
      StreamData.string(:ascii, max_length: 20),
      StreamData.integer(),
      StreamData.boolean(),
      StreamData.constant(nil)
    ])
  end

  defp nested_param_map_gen do
    tree(scalar_gen(), fn child ->
      one_of([
        StreamData.map_of(StreamData.string(:alphanumeric, min_length: 1, max_length: 10), child, max_length: 5),
        StreamData.list_of(child, max_length: 5)
      ])
    end)
  end
end
```

`[CITED: https://hexdocs.pm/stream_data/ExUnitProperties.html]` — `use ExUnitProperties` brings `check all` and `property/2` macros; `StreamData.tree/2` is the canonical recursive generator combinator.

### Anti-Patterns to Avoid

- **Do NOT use `String.to_existing_atom/1` for enum atomization.** Stripe can add enum values in API versions without warning; crashing the SDK on new values is the opposite of "principle of least surprise". Use the whitelist-with-fallback pattern from D-03.
- **Do NOT define `Coupon.update/3` or `Price.delete/2` or `Coupon.search/2` or `PromotionCode.search/2`.** Per D-05, these functions must not exist. No `@doc false` stub. No `raise`. No tuple return. The absence IS the interface.
- **Do NOT hand-decode `recurring` as a map in Price.from_map/1 and then pattern-match on it elsewhere.** Once typed, always typed. The whole point of D-01 is that downstream `Subscription` module can write `%Price{recurring: %Price.Recurring{interval: :month}}`.
- **Do NOT add a runtime dep for StreamData.** It is `only: :test`. Production users do not need it on their BEAM.
- **Do NOT introduce a new `LatticeStripe.Enum` shared helper module in Phase 12.** Wait for real duplication pressure in Phases 13-19.
- **Do NOT forget the `extra: Map.drop(map, @known_fields)` line** — it's the escape hatch for new Stripe fields and every v1 resource has it.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Property-based test generators | Custom Enumerable-based random map builder | `stream_data` (`StreamData.tree/2`, `StreamData.map_of/3`) | Failure shrinking is non-trivial to implement. stream_data minimizes counterexamples automatically on failure. |
| Float-to-decimal-string conversion | Hand-rolled IEEE 754 formatting | `:erlang.float_to_binary/2` with `[:compact, {:decimals, N}]` | Erlang stdlib handles all edge cases (subnormals, infinity, NaN behavior is predictable). |
| URL-encoding of form values | Custom percent-encoder | `URI.encode_www_form/1` (already used by `form_encoder.ex`) | UTF-8, multibyte, special-char edge cases are in stdlib. |
| List-of-pair sorting for deterministic output | `:lists.sort/2` with custom comparator | `Enum.sort_by/2` (already used at `form_encoder.ex:44`) | Same asymptotics; idiomatic Elixir. |
| HTTP retry / pagination / idempotency / form encoding | Any new primitives | **Nothing — v1 has them all.** `Client.request/2`, `List.stream!/2`, `Resource.unwrap_*`, `Request`, `Response`, `Error` are all reused unchanged. | CONTEXT.md + ROADMAP guarantee "zero behaviour additions" for the entire v2.0 milestone. |
| Response decoding to typed structs | New resource unwrapping logic | `Resource.unwrap_singular/2` and `Resource.unwrap_list/2` | Copy the `|> then(&Client.request(client, &1)) |> Resource.unwrap_singular(&from_map/1)` pipeline verbatim. |

**Key insight:** Phase 12 is a **pure resource-surface phase**. Everything except the FormEncoder float fix is new files (5 resource modules + 1 standalone Discount + test files). There is no architecture work. The risk is getting the Stripe field inventory wrong per resource — not the Elixir structure.

## Stripe Field Inventory

Complete `@known_fields` lists per resource. Fields marked `*` are typed-nested per D-01 (everything else stays `map() | nil` or scalar per context). Cross-referenced against stripe-ruby and stripe-node as of Stripe API version `2026-03-25.dahlia`. `[CITED: https://docs.stripe.com/api/products/object, prices/object, coupons/object, promotion_codes/object, discounts]`

### LatticeStripe.Product

Endpoint base: `/v1/products`. Supports: create, retrieve, update, list, stream, search. No delete via API (archive via `update(active: false)`).

`@known_fields`:
```
id object active attributes caption created default_price deleted
description features images livemode marketing_features metadata
name package_dimensions shippable statement_descriptor tax_code
type unit_label updated url
```

Key field types:
- `id: String.t() | nil`
- `active: boolean() | nil`
- `attributes: [String.t()] | nil` — deprecated but still in API
- `caption: String.t() | nil`
- `created: integer() | nil` (unix timestamp)
- `default_price: String.t() | nil` (price ID; can be expanded)
- `description: String.t() | nil`
- `features: [map()] | nil` — list of `%{"name" => ...}` maps
- `images: [String.t()] | nil` — URLs
- `livemode: boolean() | nil`
- `marketing_features: [map()] | nil`
- `metadata: map() | nil`
- `name: String.t() | nil`
- `package_dimensions: map() | nil` — `{height, length, weight, width}` — **stays `map()`** per D-01
- `shippable: boolean() | nil`
- `statement_descriptor: String.t() | nil`
- `tax_code: String.t() | nil`
- `type: :good | :service | String.t() | nil` — atomized per D-03
- `unit_label: String.t() | nil`
- `updated: integer() | nil`
- `url: String.t() | nil`
- `deleted: boolean()` (default `false`)
- `extra: map()`

### LatticeStripe.Price

Endpoint base: `/v1/prices`. Supports: create, retrieve, update, list, stream, search. **No delete** (D-05 — `## Operations not supported by the Stripe API` section required in moduledoc).

`@known_fields`:
```
id object active billing_scheme created currency currency_options
custom_unit_amount deleted livemode lookup_key metadata nickname
product recurring tax_behavior tiers tiers_mode transform_quantity
type unit_amount unit_amount_decimal
```

Key field types:
- `id: String.t() | nil`
- `active: boolean() | nil`
- `billing_scheme: :per_unit | :tiered | String.t() | nil` — atomized
- `created: integer() | nil`
- `currency: String.t() | nil`
- `currency_options: map() | nil` — stays `map()` per D-01 (recursive value shape)
- `custom_unit_amount: map() | nil` — stays `map()` per D-01
- `livemode: boolean() | nil`
- `lookup_key: String.t() | nil`
- `metadata: map() | nil`
- `nickname: String.t() | nil`
- `product: String.t() | nil` (product ID; can be expanded)
- `recurring: LatticeStripe.Price.Recurring.t() | nil` — **TYPED nested struct** (D-01)
- `tax_behavior: :inclusive | :exclusive | :unspecified | String.t() | nil` — atomized
- `tiers: [LatticeStripe.Price.Tier.t()] | nil` — **TYPED nested struct list** (D-01)
- `tiers_mode: String.t() | nil` — `"graduated"` or `"volume"`; **not atomized** (not in D-03 list)
- `transform_quantity: map() | nil` — stays `map()` per D-01
- `type: :one_time | :recurring | String.t() | nil` — atomized
- `unit_amount: integer() | nil`
- `unit_amount_decimal: String.t() | nil` — **Stripe returns this as a string** (e.g., `"12.5"`); decimal precision matters, which is why D-09f float fix exists for the encode path
- `deleted: boolean()` (default `false`)
- `extra: map()`

### LatticeStripe.Price.Recurring (typed nested)

`@known_fields`: `aggregate_usage interval interval_count meter trial_period_days usage_type`

- `aggregate_usage: :sum | :last_during_period | :last_ever | :max | String.t() | nil`
- `interval: :day | :week | :month | :year | String.t() | nil`
- `interval_count: integer() | nil`
- `meter: String.t() | nil` (meter ID for metered billing; optional)
- `trial_period_days: integer() | nil`
- `usage_type: :licensed | :metered | String.t() | nil`

### LatticeStripe.Price.Tier (typed nested)

`@known_fields`: `flat_amount flat_amount_decimal unit_amount unit_amount_decimal up_to`

- `flat_amount: integer() | nil`
- `flat_amount_decimal: String.t() | nil`
- `unit_amount: integer() | nil`
- `unit_amount_decimal: String.t() | nil`
- `up_to: integer() | :inf | nil` — **special case per D-03**: Stripe returns the literal string `"inf"` for the final tier; `from_map/1` converts to `:inf`. Integer values pass through.

`from_map/1` body:
```elixir
def from_map(map) when is_map(map) do
  %__MODULE__{
    flat_amount: map["flat_amount"],
    flat_amount_decimal: map["flat_amount_decimal"],
    unit_amount: map["unit_amount"],
    unit_amount_decimal: map["unit_amount_decimal"],
    up_to: coerce_up_to(map["up_to"]),
    extra: Map.drop(map, @known_fields)
  }
end

defp coerce_up_to("inf"), do: :inf
defp coerce_up_to(n) when is_integer(n), do: n
defp coerce_up_to(nil), do: nil
defp coerce_up_to(other), do: other
```

### LatticeStripe.Coupon

Endpoint base: `/v1/coupons`. Supports: create, retrieve, **delete**, list, stream. **No update** (D-05). **No search** (D-05, verified absent).

`@known_fields`:
```
id object amount_off applies_to created currency currency_options deleted
duration duration_in_months livemode max_redemptions metadata name
percent_off redeem_by times_redeemed valid
```

Key field types:
- `id: String.t() | nil` (can be user-supplied on create per D-07)
- `amount_off: integer() | nil` — cents
- `applies_to: LatticeStripe.Coupon.AppliesTo.t() | nil` — **TYPED nested struct** (D-01)
- `created: integer() | nil`
- `currency: String.t() | nil`
- `currency_options: map() | nil` — stays `map()` per D-01
- `duration: :forever | :once | :repeating | String.t() | nil` — atomized
- `duration_in_months: integer() | nil` — required when `duration == :repeating`
- `livemode: boolean() | nil`
- `max_redemptions: integer() | nil`
- `metadata: map() | nil`
- `name: String.t() | nil`
- `percent_off: float() | nil` — **this is where the float encoder fix matters**: partial percents like `12.5`
- `redeem_by: integer() | nil` — unix timestamp
- `times_redeemed: integer() | nil`
- `valid: boolean() | nil`
- `deleted: boolean()` (default `false`)
- `extra: map()`

### LatticeStripe.Coupon.AppliesTo (typed nested)

`@known_fields`: `products`

- `products: [String.t()] | nil` — list of product IDs this coupon restricts to

Minimal `from_map/1`:
```elixir
def from_map(map) when is_map(map) do
  %__MODULE__{products: map["products"], extra: Map.drop(map, @known_fields)}
end
```

### LatticeStripe.PromotionCode

Endpoint base: `/v1/promotion_codes`. Supports: create, retrieve, update, list, stream. **No search** (D-05, verified absent — discovery via `list/2` per D-06). **No delete** (PromotionCodes are immutable once created; can be deactivated with `update(active: false)`).

`@known_fields`:
```
id object active code coupon created customer expires_at livemode
max_redemptions metadata restrictions times_redeemed
```

Key field types:
- `id: String.t() | nil` — always Stripe-generated (`promo_...`)
- `active: boolean() | nil`
- `code: String.t() | nil` — the customer-facing code (e.g., `"SUMMER25USER"`); separately assignable on create per D-07
- `coupon: LatticeStripe.Coupon.t() | nil` — Stripe expands the coupon by default; **if expanded**, this is a full Coupon object and `from_map/1` should call `Coupon.from_map/1`; **if unexpanded**, it's a string ID. The planner needs to handle both cases:
  ```elixir
  coupon: case map["coupon"] do
    nil -> nil
    s when is_binary(s) -> s   # unexpanded string ID — stays as String.t()
    m when is_map(m) -> LatticeStripe.Coupon.from_map(m)
  end,
  ```
  Typespec becomes `coupon: LatticeStripe.Coupon.t() | String.t() | nil`.
- `created: integer() | nil`
- `customer: String.t() | nil` — customer ID this code is restricted to (nil = anyone)
- `expires_at: integer() | nil`
- `livemode: boolean() | nil`
- `max_redemptions: integer() | nil`
- `metadata: map() | nil`
- `restrictions: map() | nil` — `%{first_time_transaction, minimum_amount, minimum_amount_currency, currency_options}` — stays `map()` (not in D-01)
- `times_redeemed: integer() | nil`
- `extra: map()`

### LatticeStripe.Discount (D-08)

Standalone module at `lib/lattice_stripe/discount.ex`. No CRUD. Only `from_map/1`. Field list from D-08 verbatim:

`@known_fields`: `id object checkout_session coupon customer end invoice invoice_item promotion_code start subscription`

Key field types:
- `id: String.t() | nil` — note: Stripe discount IDs look like `"di_..."`; can be `nil` on freshly-created discounts applied via coupon
- `object: String.t()` — default `"discount"`
- `checkout_session: String.t() | nil`
- `coupon: LatticeStripe.Coupon.t() | nil` — **typed** (Discount always embeds the full Coupon object per Stripe API, not just an ID)
- `customer: String.t() | nil`
- `end: integer() | nil` — **note: `end` is a reserved keyword in Elixir**. Use `end:` in `defstruct` (fine as atom), but accessing `discount.end` works because Elixir accepts it in struct-field position. Verify during Wave 0 that `defstruct [..., :end, ...]` compiles cleanly on Elixir 1.15+. `[ASSUMED — A3]` — very likely fine, Elixir allows `:end` as an atom, and struct field accessors route through `Map.get/2` at runtime. `Kernel.SpecialForms` documents that `foo.end` is shorthand for `Map.get(foo, :end)` which works.
- `invoice: String.t() | nil`
- `invoice_item: String.t() | nil`
- `promotion_code: String.t() | nil`
- `start: integer() | nil`
- `subscription: String.t() | nil`
- `extra: map()`

**`Customer.discount` backfill (D-02):**

In `lib/lattice_stripe/customer.ex`:

1. Line 111 typespec: change `discount: map() | nil` → `discount: LatticeStripe.Discount.t() | nil`.
2. Add `alias LatticeStripe.Discount` (or reference fully-qualified).
3. In `from_map/1` line 446, change:
   ```elixir
   discount: map["discount"],
   ```
   to:
   ```elixir
   discount: case map["discount"] do
     nil -> nil
     m when is_map(m) -> LatticeStripe.Discount.from_map(m)
   end,
   ```
4. Update existing customer tests that assert on `discount: ...` to expect a `%Discount{}` struct instead of a raw map. Grep for `customer.discount` in `test/` — likely 0 or 1 hit.

## Runtime State Inventory

Not applicable — Phase 12 is pure code addition, no renames, refactors, or migrations. No stored data changes, no live service config, no OS-registered state, no secrets. All new files.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — verified by scope (new modules only) | — |
| Live service config | None — stripe-mock has no persistent state | — |
| OS-registered state | None | — |
| Secrets/env vars | None — reuses existing `STRIPE_TEST_SECRET_KEY` pattern for future `:real_stripe` tests (none yet in Phase 12) | — |
| Build artifacts | None — adding files, not renaming packages | — |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | Compilation | Assumed ✓ (project already builds) | `~> 1.15` | — |
| Docker / stripe-mock | Integration tests | Assumed ✓ (existing integration test guard pattern) | `stripe/stripe-mock:latest` | Tests raise with clear error if not running — pattern at `test/integration/customer_integration_test.exs:14-22` |
| Hex (for `stream_data`) | `mix deps.get` in Wave 0 | Assumed ✓ | — | — |

No blocking dependencies. Phase 12 can execute entirely offline after `mix deps.get` fetches stream_data.

## Common Pitfalls

### Pitfall 1: `end` as a Discount struct field

**What goes wrong:** Elixir's `end` keyword terminates blocks. If the planner writes `defstruct [..., end: nil, ...]`, the parser should accept it (because `end:` is unambiguously an atom key), but syntax-highlighting tools and some formatters trip on it.

**Prevention:** Use `:end` quoted atom form in the defstruct list if formatter complains: `defstruct [:id, :coupon, :"end", :start]`. In typespec, use `"end": integer() | nil` (string form). Test during Wave 0. `[ASSUMED — A4]` — most likely `:end` works unquoted but worth a 60-second experiment in iex.

### Pitfall 2: Scientific-notation float bug — the actual trigger

**What goes wrong:** The D-09f bug only bites **outbound** (request encoding), not inbound. Prices have `percent_off` (Coupon) and `unit_amount_decimal` (string from Stripe, but developers may pass a float). If a user calls `Coupon.create(client, %{"percent_off" => 0.00001})`, the current encoder emits `percent_off=1.0e-5` which Stripe's parser rejects with a 400.

**Why it happens:** `to_string(0.00001)` in Elixir delegates to `:io_lib.format/2` with default specifiers that choose scientific notation for magnitudes below `1e-4` or above `1e15`.

**Prevention:** D-09f patch; battery asserts exact wire format for the 5 edge cases.

**Warning signs:** Any 400 response from Stripe mentioning `invalid_number` or `must be a number` after a Phase 12-era release.

### Pitfall 3: Expanded vs unexpanded coupon on PromotionCode

**What goes wrong:** `PromotionCode.from_map/1` must handle `map["coupon"]` being either a string ID (unexpanded) or a full Coupon object (expanded, which is Stripe's default for this field). If the planner writes `coupon: map["coupon"]` without dispatch, the struct type drifts — sometimes it's `%Coupon{}`, sometimes it's `String.t()`.

**Prevention:** Dispatch in `from_map/1` as shown in Stripe Field Inventory above. Typespec union: `Coupon.t() | String.t() | nil`. Test both cases in unit tests.

### Pitfall 4: `Coupon.applies_to` is never omitted — it's always `nil` or a map

**What goes wrong:** Some Stripe fields are "present-but-null". The `applies_to` field on Coupon is always present in the response — either `null` or `{"products": [...]}`. `from_map/1` must handle `nil`:

```elixir
applies_to: case map["applies_to"] do
  nil -> nil
  m when is_map(m) -> LatticeStripe.Coupon.AppliesTo.from_map(m)
end,
```

**Prevention:** Always `case` on map fields that get typed-nested decoding. Never assume non-nil.

### Pitfall 5: `tiers_mode` not atomized but `billing_scheme` is

**What goes wrong:** D-03 lists `billing_scheme` for atomization but **not** `tiers_mode`. Both are enum-like (`"graduated" | "volume"` vs `"per_unit" | "tiered"`). The planner might over-apply atomization.

**Prevention:** Follow D-03 list **exactly**. Do not add fields to the atomization set during planning — that's a scope decision, not an implementation one. If extra atomization is valuable, flag it as a future improvement, don't silently expand scope.

### Pitfall 6: Price deletion — users will try `Price.delete/2` and get a `function not available` compile error

**What goes wrong:** Developers migrating from stripity_stripe or stripe-ruby expect `Price.delete/2` to exist. With D-05, the function doesn't exist — calling it is a compile error (`function Price.delete/2 is undefined or private`).

**Prevention:** The `## Operations not supported by the Stripe API` block in `Price.@moduledoc` is the **only** signpost. Make it prominent. Consider a `@deprecated` trick? No — `@deprecated` requires the function to exist. The moduledoc section is the right place. Also: ExDoc will render the section under the module header, so `mix docs` output includes it.

### Pitfall 7: `@known_fields` drift from `defstruct`

**What goes wrong:** If the `@known_fields ~w[...]` sigil lists a field that's not in `defstruct`, `Map.drop` works but the field is never assigned in `from_map/1` and stays at its default — data loss. If `defstruct` has a field not in `@known_fields`, it ends up in `extra` AND in its own field key — duplication.

**Prevention:** Keep the two lists in strict lockstep. Visual inspection during code review catches most drift. A future test could compare lengths: `assert length(@known_fields) == length(struct(__MODULE__) |> Map.keys() |> Enum.reject(&(&1 in [:__struct__, :extra])))`. Not required for Phase 12 but worth mentioning.

### Pitfall 8: stripe-mock does not enforce all field-level validation

**What goes wrong:** stripe-mock validates request shapes against the OpenAPI spec but is more lenient than real Stripe on cross-field constraints (e.g., "if duration is 'repeating' then duration_in_months is required"). Integration tests can pass on stripe-mock and fail in real Stripe.

**Prevention:** Integration tests cover the happy-path request/response shape. The milestone smoke test in Phase 19 (REL-02) against stripe-mock is acceptable for Phase 12 purposes. Real-Stripe testing is deferred to the `:real_stripe` tier in Phase 13+.

## Code Examples

### Example 1: Product.create/3 (copy template from Customer.create/3)

```elixir
# Source: adapted from lib/lattice_stripe/customer.ex:165-169
@spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def create(%Client{} = client, params \\ %{}, opts \\ []) do
  %Request{method: :post, path: "/v1/products", params: params, opts: opts}
  |> then(&Client.request(client, &1))
  |> Resource.unwrap_singular(&from_map/1)
end
```

### Example 2: Price.from_map/1 with typed recurring

```elixir
# Source: pattern from lib/lattice_stripe/customer.ex:432-464
@spec from_map(map()) :: t()
def from_map(map) when is_map(map) do
  %__MODULE__{
    id: map["id"],
    object: map["object"] || "price",
    active: map["active"],
    billing_scheme: atomize_billing_scheme(map["billing_scheme"]),
    created: map["created"],
    currency: map["currency"],
    currency_options: map["currency_options"],
    custom_unit_amount: map["custom_unit_amount"],
    livemode: map["livemode"],
    lookup_key: map["lookup_key"],
    metadata: map["metadata"],
    nickname: map["nickname"],
    product: map["product"],
    recurring: decode_recurring(map["recurring"]),
    tax_behavior: atomize_tax_behavior(map["tax_behavior"]),
    tiers: decode_tiers(map["tiers"]),
    tiers_mode: map["tiers_mode"],
    transform_quantity: map["transform_quantity"],
    type: atomize_type(map["type"]),
    unit_amount: map["unit_amount"],
    unit_amount_decimal: map["unit_amount_decimal"],
    deleted: map["deleted"] || false,
    extra: Map.drop(map, @known_fields)
  }
end

defp decode_recurring(nil), do: nil
defp decode_recurring(m) when is_map(m), do: LatticeStripe.Price.Recurring.from_map(m)

defp decode_tiers(nil), do: nil
defp decode_tiers(list) when is_list(list), do: Enum.map(list, &LatticeStripe.Price.Tier.from_map/1)

defp atomize_billing_scheme("per_unit"), do: :per_unit
defp atomize_billing_scheme("tiered"), do: :tiered
defp atomize_billing_scheme(other), do: other

defp atomize_tax_behavior("inclusive"), do: :inclusive
defp atomize_tax_behavior("exclusive"), do: :exclusive
defp atomize_tax_behavior("unspecified"), do: :unspecified
defp atomize_tax_behavior(other), do: other

defp atomize_type("one_time"), do: :one_time
defp atomize_type("recurring"), do: :recurring
defp atomize_type(other), do: other
```

### Example 3: FormEncoder float fix + battery cases

```elixir
# Source: new clause for lib/lattice_stripe/form_encoder.ex:91
defp flatten_value(value, key) when is_float(value) do
  [{key, :erlang.float_to_binary(value, [:compact, {:decimals, 12}])}]
end

defp flatten_value(value, key) do
  # Scalar: boolean, integer, atom, binary
  [{key, to_string(value)}]
end
```

Battery cases in `test/lattice_stripe/form_encoder_test.exs`:

```elixir
describe "encode/1 — float coercion (D-09f)" do
  test "small float does not use scientific notation" do
    assert FormEncoder.encode(%{"rate" => 0.00001}) == "rate=0.00001"
  end

  test "standard decimal encodes cleanly" do
    assert FormEncoder.encode(%{"pct" => 12.5}) == "pct=12.5"
  end

  test "zero float encodes as 0.0" do
    assert FormEncoder.encode(%{"x" => 0.0}) == "x=0.0"
  end

  test "negative float" do
    assert FormEncoder.encode(%{"x" => -1.5}) == "x=-1.5"
  end

  test "extreme small float — document actual behavior" do
    # Lock the contract; if :erlang.float_to_binary changes, we catch it
    encoded = FormEncoder.encode(%{"x" => 1.0e-20})
    # This documents what the fix actually produces; battery value TBD after Wave 0 verification
    refute encoded =~ "e-"
  end
end
```

### Example 4: Triple-nested price_data golden

```elixir
describe "encode/1 — triple-nested inline price_data (D-09a case 1)" do
  test "items[0][price_data][recurring][interval] is correctly bracketed" do
    params = %{
      "items" => [
        %{
          "price_data" => %{
            "currency" => "usd",
            "unit_amount" => 2000,
            "product_data" => %{"name" => "T-shirt"},
            "recurring" => %{"interval" => "month", "interval_count" => 3, "usage_type" => "licensed"},
            "tax_behavior" => "exclusive"
          }
        }
      ]
    }

    encoded = FormEncoder.encode(params)

    assert encoded =~ "items[0][price_data][currency]=usd"
    assert encoded =~ "items[0][price_data][unit_amount]=2000"
    assert encoded =~ "items[0][price_data][product_data][name]=T-shirt"
    assert encoded =~ "items[0][price_data][recurring][interval]=month"
    assert encoded =~ "items[0][price_data][recurring][interval_count]=3"
    assert encoded =~ "items[0][price_data][recurring][usage_type]=licensed"
    assert encoded =~ "items[0][price_data][tax_behavior]=exclusive"
  end
end
```

### Example 5: Inspecting current `form_encoder_test.exs` for overlap

Current tests at `test/lattice_stripe/form_encoder_test.exs` already cover: flat map, nested map, 3+ level deep, boolean, nil omission, empty map, integer, atom keys, alphabetical sort, special-char URL-encode, empty-string preservation, array-of-scalars, array-of-maps, 4+ level deep, unicode (accented + CJK), equals/ampersand escaping, nil-in-array skipping, zero/negative integers.

**Coverage gaps the battery must add:**
- Triple-nested `price_data` shape specifically (has related `a[b][c][d]=deep` test but not the canonical Stripe shape)
- Quadruple-nested `transform_quantity` under `price_data` under `items[]`
- Mixed `items[0][price]` + `items[1][price_data]...` shape
- Coupon custom `id` at top level (trivial but locks the pattern)
- Price tier lists with `up_to: "inf"` literal
- Coupon `applies_to[products][0]` array inside nested map
- Connect account nested booleans (forward-compat for Phase 17)
- Metadata with hyphens / slashes / spaces (D-09c) — space test exists but hyphen/slash don't
- Float coercion (D-09f, all 5 cases)
- Atom-value round-trip for enum (e.g., `:month == "month"`) (D-09e)
- StreamData properties (D-09b)

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib) + Mox (~> 1.2) + stream_data (~> 1.1, new) |
| Config file | `test/test_helper.exs` (existing, no changes for stream_data — `use ExUnitProperties` is per-test-module) |
| Quick run command | `mix test --exclude integration` |
| Full suite command | `mix test` (includes integration if stripe-mock running) |
| Integration tag | `@moduletag :integration` — pattern from `test/integration/customer_integration_test.exs:6` |
| CI full gate | `mix ci` alias: `format --check-formatted`, `compile --warnings-as-errors`, `credo --strict`, `test`, `docs --warnings-as-errors` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| BILL-01 | Product CRUD shape + from_map decoding | unit | `mix test test/lattice_stripe/product_test.exs` | Wave 0 — create `test/lattice_stripe/product_test.exs` |
| BILL-01 | Product create/retrieve/update/list/search round-trip against stripe-mock | integration | `mix test test/integration/product_integration_test.exs` | Wave 0 — create |
| BILL-02 | Price CRUD shape + typed Recurring/Tier decoding | unit | `mix test test/lattice_stripe/price_test.exs` | Wave 0 — create |
| BILL-02 | Price has NO delete/2 exported | unit (compile-time + introspection) | `mix test test/lattice_stripe/price_test.exs` (assert `function_exported?(Price, :delete, 2) == false`) | Wave 0 — create |
| BILL-02 | Price create/retrieve/update/list/search round-trip with `recurring`, `tiers` against stripe-mock | integration | `mix test test/integration/price_integration_test.exs` | Wave 0 — create |
| BILL-06 | Coupon CRUD shape, typed AppliesTo, custom id pass-through | unit | `mix test test/lattice_stripe/coupon_test.exs` | Wave 0 — create |
| BILL-06 | Coupon has NO update/3, NO search/2 exported | unit | `mix test test/lattice_stripe/coupon_test.exs` | Wave 0 — create |
| BILL-06 | Coupon create/retrieve/delete/list against stripe-mock (no update test possible) | integration | `mix test test/integration/coupon_integration_test.exs` | Wave 0 — create |
| BILL-06b | PromotionCode CRUD shape, custom code pass-through, expanded-vs-unexpanded coupon field | unit | `mix test test/lattice_stripe/promotion_code_test.exs` | Wave 0 — create |
| BILL-06b | PromotionCode has NO search/2 exported | unit | `mix test test/lattice_stripe/promotion_code_test.exs` | Wave 0 — create |
| BILL-06b | PromotionCode create/retrieve/update/list against stripe-mock | integration | `mix test test/integration/promotion_code_integration_test.exs` | Wave 0 — create |
| (D-01) | Price.Recurring / Price.Tier / Coupon.AppliesTo / Discount from_map unit tests including atomization | unit | `mix test test/lattice_stripe/price_test.exs test/lattice_stripe/coupon_test.exs test/lattice_stripe/discount_test.exs` | Wave 0 — create |
| (D-02) | Customer.discount field retype — from_map decodes to `%Discount{}` | unit (regression) | `mix test test/lattice_stripe/customer_test.exs` | Exists — extend |
| (D-03) | Whitelist atomization: known strings → atoms, unknown → pass through, nil → nil | unit | `mix test test/lattice_stripe/price_test.exs` etc. | Wave 0 — create |
| (D-04) | Product.search, Price.search available; Coupon/PromotionCode.search unavailable | unit (introspection) | `mix test` (grouped) | Wave 0 — create |
| (D-05) | Missing-function contract: calling absent functions is a compile error | doc + explicit test via `function_exported?/3` | `mix test` | Wave 0 — create |
| (D-09a) | Enumerated FormEncoder cases (14 shape families) | unit | `mix test test/lattice_stripe/form_encoder_test.exs` | Exists — extend |
| (D-09b) | StreamData properties (nil never emitted, deterministic, URL-decodable, no key collisions) | property | `mix test test/lattice_stripe/form_encoder_test.exs` | Exists — extend (add `use ExUnitProperties`) |
| (D-09c) | Metadata special-char handling (hyphen, slash, space) | unit | `mix test test/lattice_stripe/form_encoder_test.exs` | Exists — extend |
| (D-09d) | Empty-string clear-field vs nil omission | unit (regression) | `mix test test/lattice_stripe/form_encoder_test.exs` | Exists — extend with new explicit contract-locking test |
| (D-09e) | Atom value round-trip (`:month` == `"month"`) | unit | `mix test test/lattice_stripe/form_encoder_test.exs` | Exists — extend |
| (D-09f) | Float scalar fix: `0.00001`, `1.0e-20`, `12.5`, `0.0`, negative | unit | `mix test test/lattice_stripe/form_encoder_test.exs` | Exists — extend |
| (D-10) | Eventual-consistency callout present in Product.search and Price.search `@doc` | doc | `mix docs --warnings-as-errors` + grep assertion in unit test | Wave 0 — create |
| (D-11) | Battery organized with describe blocks by shape family | n/a — structural | `mix test` | Exists — extend |

### Sampling Rate

- **Per task commit:** `mix test --exclude integration` (unit + property tests, ~5s)
- **Per wave merge:** `mix test` (adds integration tier if stripe-mock up) + `mix credo --strict` + `mix format --check-formatted`
- **Phase gate:** `mix ci` (the existing full alias) — all tests green, all warnings clean, docs build clean

### Wave 0 Gaps

Files to create before implementation waves:

- [ ] `test/lattice_stripe/product_test.exs` — covers BILL-01 unit
- [ ] `test/lattice_stripe/price_test.exs` — covers BILL-02 unit, D-01 Recurring/Tier decoding, D-03 atomization
- [ ] `test/lattice_stripe/coupon_test.exs` — covers BILL-06 unit, D-01 AppliesTo
- [ ] `test/lattice_stripe/promotion_code_test.exs` — covers BILL-06b unit, D-07 code vs id distinction
- [ ] `test/lattice_stripe/discount_test.exs` — covers D-08 from_map
- [ ] `test/integration/product_integration_test.exs` — stripe-mock
- [ ] `test/integration/price_integration_test.exs` — stripe-mock, exercises `recurring` and `tiers`
- [ ] `test/integration/coupon_integration_test.exs` — stripe-mock (no update case — validate absence, not behavior)
- [ ] `test/integration/promotion_code_integration_test.exs` — stripe-mock
- [ ] Dependency install: `mix deps.get` after adding `{:stream_data, "~> 1.1", only: :test}` to `mix.exs`

**Existing files extended:**
- `test/lattice_stripe/form_encoder_test.exs` — add `use ExUnitProperties`, D-09a/b/c/d/e/f describe blocks
- `test/lattice_stripe/customer_test.exs` — assert `%Discount{}` type on decoded `discount` field (D-02 regression guard)

No new framework install needed — ExUnit and Mox are already in the project.

## Security Domain

Not a user-facing security-critical phase. All inputs come from application code (developer-supplied), not network input. Stripe signature verification, PII handling, and sensitive-field hiding already exist in v1 and are **not modified** in Phase 12.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes (indirect) | Reuses v1 `Client.api_key` — no changes |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes (modest) | Input is Elixir maps from application code, not untrusted network. `Resource.require_param!/3` exists for guarded params but Phase 12 resources don't need new guards (all params are optional per Stripe). Atom-whitelist-with-fallback (D-03) is the input-validation pattern. **Never `String.to_atom/1`** — prevents atom-table exhaustion DoS on unknown Stripe enum values. |
| V6 Cryptography | no | — |

### Known Threat Patterns for Phase 12

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Atom-table exhaustion via untrusted Stripe enum string | Denial of Service | Whitelist atomization (D-03) — `String.to_atom/1` forbidden, `String.to_existing_atom/1` forbidden (crashes on forward-compat); only pattern-match literal whitelist in private function. |
| Secrets leaking through struct `Inspect` | Information Disclosure | None of Phase 12's structs hold secrets. Coupon/PromotionCode IDs are marketing codes (non-sensitive). No custom `Inspect` needed. If the planner disagrees, add a `defimpl Inspect` block following the `customer.ex:467-489` pattern. |
| Unsanitized metadata keys causing HTTP smuggling | Tampering | `FormEncoder.encode_key/1` URL-encodes key segments via `URI.encode_www_form/1` (`form_encoder.ex:99-107`). Brackets are preserved, everything else is percent-encoded. D-09c battery locks this contract. |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| stripity_stripe: all nesteds as `term()` | LatticeStripe: strategic typed nesteds per D-01 | Phase 12 (2026-04) | Downstream code can pattern-match `%Price{recurring: %Recurring{interval: :month}}` |
| stripity_stripe: `Price.delete/2` stubbed with error tuple | LatticeStripe: function absent entirely | Phase 12 (2026-04, D-05) | Elixir developers get compile-time errors instead of runtime tuples for forbidden operations — "missing functions, not runtime errors" (ROADMAP #1) |
| stripe-ruby: `Coupon.update` exists and returns an API error | LatticeStripe: `Coupon.update` does not exist | Phase 12 (2026-04) | Catches the mistake at compile time instead of deploy time |
| Generic `to_string/1` for floats in form encoding | `:erlang.float_to_binary/2` with `[:compact, {:decimals, 12}]` | Phase 12 (D-09f) | Fixes latent bug where `0.00001` emitted as `1.0e-5`, rejected by Stripe parser. First bites when `unit_amount_decimal` ships in Prices. |

**Deprecated/outdated:**
- `stripity_stripe` in general — unmaintained, `term()`-typed nesteds, no strategic decisions. Explicitly cited in PROJECT.md as what LatticeStripe replaces.

## Assumptions Log

Claims in this research that were not independently verified in-session and may need user/Wave-0 confirmation:

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `:erlang.float_to_binary(1.0e-20, [:compact, {:decimals, 12}])` produces a usable decimal form for Stripe | Architecture Pattern 5, Pitfall 2, Example 3 | Extreme-small-float edge case in D-09f battery may need `{:decimals, 20}` or a different approach. **Low actual risk** — Stripe's documented max precision for decimal amounts is 12 places. Verify in iex during Wave 0. |
| A2 | Elixir's `Float.to_string/1` may emit scientific notation for small magnitudes | Architecture Pattern 5 | Influences choice between `Float.to_string/1` and `:erlang.float_to_binary/2`. Verify in iex — 60-second check. |
| A3 | `defstruct [..., :end, ...]` compiles and `discount.end` access works on Elixir 1.15+ | Pitfall 1, Discount field inventory | If `end:` as struct field breaks, quote it as `:"end"` or rename to `ends_at` (the latter breaks Stripe fidelity). **Very low risk** — Elixir allows reserved words as atom keys in struct defs. Verify in iex during Wave 0 with `defmodule T do defstruct [:end] end`. |
| A4 | Same as A3, pertaining to formatter/syntax-highlighter behavior | Pitfall 1 | Cosmetic — at worst, Credo warns. |
| A5 | Stripe returns `PromotionCode.coupon` as an **expanded** object by default (full Coupon, not just ID) | Stripe Field Inventory > PromotionCode | If unexpanded by default, the `case` dispatch in `from_map/1` still works (covers both branches) — **no risk**, the code handles both paths. |
| A6 | Stripe-mock supports all Phase 12 endpoints and enforces OpenAPI-level shape validation | Validation Architecture | Integration tests might succeed despite wrong request shapes. Mitigated by unit tests asserting exact `%Request{}` contents via Mox. **Low risk** — stripe-mock is Stripe's official mock and is spec-driven. |
| A7 | `stream_data` ~> 1.1 pin permits the current 1.3.0 version and `ExUnitProperties` imports work unchanged | Standard Stack | `~> 1.1` semantically allows `>= 1.1.0 and < 2.0.0`, so 1.3.0 is included. `[VERIFIED: semver.org]` — actually **not an assumption**, promoting to verified. Leaving here for traceability. |

**Planner action:** Assumptions A1, A2, and A3 should be resolved in Wave 0 by a 2-minute iex session. A5-A7 are reference-only and don't block the plan.

## Open Questions

1. **Exact wording of `## Operations not supported by the Stripe API` section** — CONTEXT.md D-05 provides exemplars for `Price.@moduledoc` and `Coupon.@moduledoc`. `PromotionCode.@moduledoc` needs the same pattern applied (no search). `Product.@moduledoc` does NOT need the section — Product supports all operations.
   - Recommendation: planner writes the section for Price, Coupon, PromotionCode during each resource's implementation task. Use the exact text blocks from CONTEXT.md D-05 for Price and Coupon; derive PromotionCode's block from D-06 (discovery via `list/2`).

2. **Should `Product.search` carry the D-10 eventual-consistency callout as a shared attribute or inlined text?**
   - Recommendation: **inline text per module in Phase 12** (only 2 sites — Product, Price). Revisit as a shared `LatticeStripe.Resource` attribute in Phase 19 (UTIL-06), which will also retro-apply to v1's Customer/PaymentIntent/CheckoutSession search docs. Don't prematurely abstract.

3. **Does `Customer.discount` in existing tests need mock-data updates?**
   - What we know: `customer.ex:446` currently does `discount: map["discount"]`. Existing tests either don't set a discount or set it as a raw map.
   - What's unclear: Whether any test asserts on the shape of `customer.discount` beyond "is a map".
   - Recommendation: Wave 0 grep `test/` for `discount` string matches. Update any test that asserts on the raw map shape to expect `%Discount{}`. Likely 0-2 files affected.

4. **`Price.tiers` when `null` vs `[]`** — Stripe omits the field for non-tiered prices. `from_map/1` handles `nil` via `decode_tiers(nil) -> nil`. Should the typespec be `tiers: [Tier.t()] | nil` or `tiers: [Tier.t()]` (always list)?
   - Recommendation: `[Tier.t()] | nil` — matches Stripe's actual wire format and aligns with the `map()` fallback pattern used for other optional nested fields.

## Sources

### Primary (HIGH confidence — verified in-session)

- `lib/lattice_stripe/customer.ex` — canonical v1 resource template (struct, `@known_fields`, `from_map/1`, CRUD, Inspect) — **read in full**
- `lib/lattice_stripe/payment_intent.ex` — reference for resource-with-search template — **read in full**
- `lib/lattice_stripe/form_encoder.ex` — current encoder (114 LOC) — **read in full**, line numbers verified: nil omission lines 78-81, scalar coercion lines 91-94 (D-09f target), encode_key lines 99-107 (D-09c)
- `lib/lattice_stripe/resource.ex` — `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`, `require_param!/3` — **read in full**
- `lib/lattice_stripe/checkout/line_item.ex` — evidence for nested-struct file split pattern — **read in full**
- `lib/lattice_stripe/checkout/session.ex` — lines 1-80 verified for moduledoc patterns
- `lib/lattice_stripe/request.ex` — `%Request{}` struct fields — **read in full**
- `lib/lattice_stripe/list.ex` — lines 1-80, `stream!/2` pattern confirmed
- `test/lattice_stripe/form_encoder_test.exs` — **read in full**, current coverage cataloged
- `test/integration/customer_integration_test.exs` — lines 1-60 for integration-test scaffolding pattern
- `mix.exs` — full deps/0 verified, no `stream_data` present, aliases confirmed
- `.planning/phases/12-billing-catalog/12-CONTEXT.md` — the locked decision doc
- `.planning/REQUIREMENTS.md` — BILL-01, BILL-02, BILL-06, BILL-06b verified
- `.planning/ROADMAP.md` — Phase 12 goal, depends, success criteria lines 44-53
- `.planning/PROJECT.md` — constraints, design philosophy
- `CLAUDE.md` — tech stack, versions, what-not-to-use list
- https://docs.stripe.com/search — `[VERIFIED]` — confirms 7 searchable resources (charges, customers, invoices, payment_intents, prices, products, subscriptions) match D-04
- https://hex.pm/packages/stream_data — `[VERIFIED]` — stream_data 1.3.0 released 2026-03-09

### Secondary (MEDIUM confidence — cited)

- https://docs.stripe.com/api/products/object — Product field list `[CITED]`
- https://docs.stripe.com/api/prices/object — Price field list, recurring, tiers structure `[CITED]`
- https://docs.stripe.com/api/coupons/object — Coupon field list, applies_to shape `[CITED]`
- https://docs.stripe.com/api/promotion_codes/object — PromotionCode field list `[CITED]`
- https://docs.stripe.com/api/promotion_codes/list — list filter params (code, coupon, customer, active) `[CITED]`
- https://www.erlang.org/doc/man/erlang.html#float_to_binary-2 — `:erlang.float_to_binary/2` options `[CITED]`
- https://hexdocs.pm/stream_data/ExUnitProperties.html — `use ExUnitProperties`, `check all`, `property` macros `[CITED]`

### Tertiary (LOW confidence / unverified)

None — every factual claim is either grounded in files read this session or marked `[ASSUMED]` in the Assumptions Log.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — single test-only dep, version verified against hex.pm
- Architecture: HIGH — templates read in full, inline patterns grounded in existing v1 code
- Pitfalls: HIGH for 1-4, 6-8; MEDIUM for Pitfall 5 (`tiers_mode` omission is a CONTEXT.md reading, not a code fact)
- Stripe field inventory: MEDIUM-HIGH — cross-referenced against Stripe API docs but not against the live OpenAPI spec file this session. Wave 0 spike should diff `@known_fields` against `spec3.sdk.json` for each resource before final sign-off.
- Validation architecture: HIGH — patterns taken directly from existing integration and unit test files
- Assumptions log: all assumptions are low-cost to verify and have clear fallback paths

**Research date:** 2026-04-11
**Valid until:** 2026-05-11 (30 days — Elixir / Stripe API / stream_data all stable series, low churn)
