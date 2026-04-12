---
phase: 12-billing-catalog
plan: 04
subsystem: billing-catalog
tags: [product, bill-01, d-03, d-05, d-10, v1-template]
requires: [12-01, 12-02]
provides:
  - LatticeStripe.Product resource (CRUD + list + stream + search + search_stream)
  - D-03 whitelist atomization pattern for enum-like fields
  - D-05 forbidden-operation moduledoc block pattern (archive via update)
  - D-10 eventual-consistency @doc callout template for search/3 + search_stream!/3
affects:
  - Price (12-05), Coupon (12-06), PromotionCode (12-07) — template to copy from
tech-stack:
  added: []
  patterns:
    - Whitelist atom mapping with raw-string fallthrough for forward compat
    - Full top-level field inventory + `extra: %{}` catch-all for unknown fields
key-files:
  created:
    - lib/lattice_stripe/product.ex
  modified:
    - test/lattice_stripe/product_test.exs
    - test/integration/product_integration_test.exs
decisions:
  - "D-03 atomize_type/1 whitelists good/service; unknown strings pass through unchanged"
  - "D-05 no delete/3 — Stripe API has no endpoint; moduledoc documents archive-via-update(active: false)"
  - "D-10 eventual-consistency block duplicated verbatim on both search/3 and search_stream!/3 @doc"
  - "No custom Inspect impl — Product is a public catalog object with no PII (T-12-10 accept)"
  - "Added `deleted` to @known_fields and a dedicated test to ensure deleted=true never leaks into extra"
metrics:
  duration: ~25min
  completed: 2026-04-11
  commits: 3
  tests_added: 18
  files_touched: 3
requirements_completed: [BILL-01]
---

# Phase 12 Plan 04: LatticeStripe.Product Summary

**One-liner:** Ship the first full v1-template Stripe resource — `LatticeStripe.Product` — with CRUD + search + streaming, D-03 atomized `type`, D-05 documented delete-absence, and D-10 eventual-consistency callout on search.

## What shipped

`LatticeStripe.Product` is now the canonical v1 template for remaining Phase 12 resources (Price, Coupon, PromotionCode). Developers can call every documented Stripe Product operation through the SDK with typed structs, automatic pagination, and search — and the module's `@moduledoc` makes the missing `delete` operation discoverable so callers aren't surprised.

### Public surface

| Function | Arity | Purpose |
|---|---|---|
| `create/2,3` | Post to `/v1/products` |
| `retrieve/2,3` | Get `/v1/products/:id` |
| `update/3,4` | Post to `/v1/products/:id` (archive via `%{"active" => "false"}`) |
| `list/1,2,3` | Paginated `/v1/products` |
| `stream!/1,2,3` | Lazy auto-paginated stream |
| `search/2,3` | `/v1/products/search` with D-10 eventual-consistency @doc |
| `search_stream!/2,3` | Streaming search (D-10 @doc) |
| `create!/2,3`, `retrieve!/2,3`, `update!/3,4`, `list!/1,2,3`, `search!/2,3` | Bang variants |
| `from_map/1` | Decoder with D-03 atomization |

`delete/3` is intentionally absent — Product has no Stripe API delete endpoint.

### D-03 atomization (Product.type)

```elixir
defp atomize_type("good"),    do: :good
defp atomize_type("service"), do: :service
defp atomize_type(nil),       do: nil
defp atomize_type(other) when is_binary(other), do: other
```

Whitelist-only — no `String.to_atom/1`, so atom table cannot grow from Stripe responses (T-12-08 mitigate). Future Stripe enum values flow through as raw strings so old SDK builds don't crash.

### D-05 forbidden operation

`@moduledoc` ends with an "Operations not supported by the Stripe API" block that names `delete` and shows the archive-via-update workaround. The integration test exercises that workaround directly (`archive-via-update (D-05 delete workaround)`). `function_exported?(Product, :delete, ...)` returns `false` in all test cases.

### D-10 eventual-consistency callout

Both `search/3` and `search_stream!/3` @doc end with:

> Search results have eventual consistency. Under normal operating conditions, newly created or updated objects appear in search results within ~1 minute. During Stripe outages, propagation may be slower. Do not use `search/3` in read-after-write flows where strict consistency is necessary. See https://docs.stripe.com/search#data-freshness.

A documentation-contract test fetches `Code.fetch_docs(Product)` and asserts the string is present and references the Stripe data-freshness URL — so the callout can't be silently refactored away.

## Tests

- **Unit (`test/lattice_stripe/product_test.exs`):** 18 tests across three describe blocks
  - `from_map/1` — 8 tests (minimal decode, D-03 good/service/unknown/nil, extra-field capture, deleted default + non-leak)
  - `function surface (D-05 absence)` — 8 tests (each CRUD function exported + delete absence)
  - `documentation contracts` — 2 tests (D-10 callout, D-05 moduledoc)
- **Integration (`test/integration/product_integration_test.exs`):** 3 stripe-mock tests, tagged `:integration`, excluded from default suite
  - Full CRUD round-trip (create/retrieve/update/list)
  - Archive-via-update (D-05 workaround)
  - `search/3` returns typed list (tolerates stripe-mock search stub)

`mix test --exclude integration` → **650 tests, 0 failures**. `mix compile --warnings-as-errors` → clean.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Added `deleted` to @known_fields and a regression test**

- **Found during:** Task 1 code review
- **Issue:** Plan's `@known_fields` sigil omitted `deleted`, but `from_map/1` reads `map["deleted"]` and `extra: Map.drop(map, @known_fields)`. Without `deleted` in the sigil, a response with `"deleted" => true` would have set `struct.deleted = true` *and* leaked `%{"deleted" => true}` into `extra` — duplicating data and breaking the `extra = unknown-fields-only` invariant.
- **Fix:** Added `deleted` to the `@known_fields` list (matching Customer's pattern), plus a new unit test `"deleted=true is captured and does not leak to extra"` to lock the invariant in.
- **Files modified:** `lib/lattice_stripe/product.ex`, `test/lattice_stripe/product_test.exs`
- **Commit:** included in `15548ad` (RED) + `ff1e2a0` (GREEN)

No other deviations. Plan was otherwise executed verbatim.

## Threat-model coverage

| Threat ID | Mitigation verified |
|---|---|
| T-12-08 (DoS via atomize_type) | Whitelist-only clauses, no `String.to_atom`. Test `"unknown type passes through as raw string (forward compat)"` asserts the safe branch. |
| T-12-09 (query pass-through) | `search/3` builds `%{"query" => query}` verbatim; no interpolation. |
| T-12-10 (no PII) | No custom Inspect impl — plan step 10 explicitly drops Customer's PII-hiding Inspect block. |

## Commits

| Hash | Message |
|---|---|
| `15548ad` | test(12-04): add failing Product test suite (RED) |
| `ff1e2a0` | feat(12-04): implement LatticeStripe.Product resource (GREEN) |
| `3e3cd78` | test(12-04): Product stripe-mock integration test |

## Follow-on template notes (for 12-05/06/07)

- Copy `product.ex` verbatim, adapt paths and field list
- Price and Coupon need their own atomization whitelists (Price.type, Coupon.duration) — reuse the `atomize_*/1` pattern
- Price has `delete` in Stripe API → keep the delete function and drop the forbidden-operation moduledoc block
- Coupon and PromotionCode both expose `delete` too — only Product has the D-05 absence
- The D-10 eventual-consistency block is the same verbatim string; factor it out if a fourth resource needs it

## Self-Check: PASSED

All 4 artifact files exist on disk; all 3 commit hashes resolvable in `git log --all`.
