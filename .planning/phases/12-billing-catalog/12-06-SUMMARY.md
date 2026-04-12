---
phase: 12-billing-catalog
plan: 06
subsystem: billing-catalog
tags: [coupon, discount, atomization, typed-nesteds, d-05-absence, custom-id]
dependency_graph:
  requires:
    - 12-01 (wave 0 scaffolds)
    - 12-02 (FormEncoder float fix D-09f)
    - 12-03 (Discount typed struct — target of tightening)
  provides:
    - LatticeStripe.Coupon
    - LatticeStripe.Coupon.AppliesTo
  affects:
    - LatticeStripe.Discount (coupon dispatch tightened from raw map to %Coupon{})
tech_stack:
  added: []
  patterns:
    - "Inline sibling nested module (Coupon + Coupon.AppliesTo) in one file"
    - "D-03 whitelist atomization on duration (never String.to_atom/1)"
    - "D-05 forbidden-op absence as interface — no update, no search"
    - "D-07 custom-ID pass-through via params map (no helper, no validation)"
    - "D-08 cross-module decoder dispatch (Discount.decode_coupon → Coupon.from_map/1)"
key_files:
  created:
    - lib/lattice_stripe/coupon.ex
    - .planning/phases/12-billing-catalog/deferred-items.md
  modified:
    - lib/lattice_stripe/discount.ex
    - test/lattice_stripe/coupon_test.exs
    - test/lattice_stripe/discount_test.exs
    - test/integration/coupon_integration_test.exs
decisions:
  - "D-05 double absence (no update + no search) documented as a named moduledoc section with both operations named explicitly — absence is the interface"
  - "D-07 custom Coupon ID flows through the params map as-is; no helper, no client-side validation — Stripe's server-side parser is the source of truth"
  - "Discount.from_map/1 tightened in one hop: map-shape dispatches to Coupon.from_map/1 while string IDs and nil pass through unchanged"
metrics:
  tasks: 2
  completed_date: 2026-04-12
requirements: [BILL-06]
---

# Phase 12 Plan 06: Coupon + Coupon.AppliesTo + Discount Tightening Summary

Ship `LatticeStripe.Coupon` with the 5-operation surface (create/retrieve/delete/list/stream!) and inline `Coupon.AppliesTo` typed nested; tighten `LatticeStripe.Discount.from_map/1` so expanded coupons decode into typed `%Coupon{}` via `Coupon.from_map/1` instead of raw maps.

## What was built

- **`lib/lattice_stripe/coupon.ex`** (new, ~210 lines):
  - `LatticeStripe.Coupon` struct with 18 fields + `extra: %{}`
  - `create/2,3`, `retrieve/2,3`, `delete/2,3`, `list/1,2,3`, `stream!/1,2,3` and bang variants
  - **NO** `update/3,4`, **NO** `search/2,3` — D-05 forbidden operations
  - `from_map/1` decoder with D-03 atomization on `duration` (`:forever` / `:once` / `:repeating`, raw string catch-all for forward compat)
  - `decode_applies_to/1` dispatch to `Coupon.AppliesTo.from_map/1`
  - `@moduledoc` with **"Operations not supported by the Stripe API"** section naming both `update` and `search`, plus **"Custom IDs"** section with `SUMMER25` example (D-07)

- **`lib/lattice_stripe/coupon.ex` (Coupon.AppliesTo sibling module)**:
  - Typed nested: `%Coupon.AppliesTo{products: [String.t()] | nil, extra: map()}`
  - Minimal — just a `products` list plus `extra` passthrough

- **`lib/lattice_stripe/discount.ex`** (modified):
  - `from_map/1`'s bare `coupon: map["coupon"]` replaced with `coupon: decode_coupon(map["coupon"])`
  - New private `decode_coupon/1` — 3 clauses: `nil → nil`, `binary → binary`, `map → Coupon.from_map(map)`
  - `@type t` field `coupon:` tightened from `term() | nil` to `LatticeStripe.Coupon.t() | String.t() | nil`
  - `@typedoc` cleaned up (removed "until Plan 12-06" comment); `@doc` updated to reference `Coupon.from_map/1`

- **`test/lattice_stripe/coupon_test.exs`** (replaced wave 0 stub, 11 tests):
  - D-03 atomization battery (forever/once/repeating/unknown/nil)
  - D-01 typed `applies_to` decoding
  - `percent_off` float + `amount_off` integer preservation
  - D-05 forbidden-op absence assertions (`refute function_exported?` for update and search at every arity)
  - Moduledoc contract tests via `Code.fetch_docs/1` — asserts the "Operations not supported" section, both op names, "immutable", "/v1/coupons/search", and the "Custom IDs" / "SUMMER25" markers

- **`test/lattice_stripe/discount_test.exs`** (extended):
  - Updated existing "coupon expanded (map)" test — now asserts `%Coupon{id: "cpn_abc", percent_off: 25}` instead of raw map equality
  - New describe block "from_map/1 — D-08 coupon dispatch (tightened in Plan 06)" — 3 tests covering map → Coupon, binary → binary, nil → nil

- **`test/integration/coupon_integration_test.exs`** (replaced wave 0 stub):
  - Full CRUD round-trip against stripe-mock
  - D-07 custom-ID pass-through test (tolerant of stripe-mock not honoring custom IDs)
  - D-09f `percent_off` fractional float (12.5) round-trip with explicit anti-scientific-notation refutation

## Verification

- `mix test test/lattice_stripe/coupon_test.exs` → 11 tests, 0 failures
- `mix test test/lattice_stripe/discount_test.exs` → 18 tests, 0 failures (including the tightened coupon dispatch assertions)
- `mix compile --warnings-as-errors` → clean
- `mix test --exclude integration` → 686 tests, 2 pre-existing unrelated failures in `LatticeStripe.ProductTest` (see Deferred Issues)

## Commits

| Task | Hash    | Message |
|------|---------|---------|
| 1-RED   | `56cdaa4` | test(12-06): add failing tests for Coupon + Discount tightening |
| 1-GREEN | `63f5bbd` | feat(12-06): implement LatticeStripe.Coupon + Coupon.AppliesTo, tighten Discount coupon dispatch |
| 2       | `5033552` | test(12-06): Coupon stripe-mock integration with D-07 custom-ID + D-09f float paths |

## Deviations from Plan

None — plan executed exactly as written. D-01/D-03/D-05/D-07/D-08/D-09f all verified at the specified call sites.

## Deferred Issues

Pre-existing failures in `LatticeStripe.ProductTest` (unrelated to Plan 12-06 — present on main prior to this plan):

- `test/lattice_stripe/product_test.exs:57` — `function_exported?(Product, :retrieve, 2)` returns false
- `test/lattice_stripe/product_test.exs:80` — `function_exported?(Product, :search_stream!, 2)` returns false

Both failures logged to `.planning/phases/12-billing-catalog/deferred-items.md`. Out of scope for BILL-06 — belongs to Plan 12-04 / Plan 12-07.

## Known Stubs

None.

## Key Decisions Revisited

- **D-05 (double absence)**: `Coupon.update` is forbidden because Coupons are immutable by Stripe's design; `Coupon.search` is forbidden because the `/v1/coupons/search` endpoint does not exist in Stripe's API. Both absences are documented in the moduledoc's "Operations not supported by the Stripe API" section so `mix docs` renders the contract visibly. Attempting `Coupon.update(...)` is a **compile-time UndefinedFunctionError**, not a runtime error.

- **D-07 (custom ID pass-through)**: The SDK exposes no `create_with_id/3` helper and performs zero validation on the `"id"` key. This is a deliberate contract — duplicating Stripe's server-side ID parser creates maintenance burden and gives users false confidence. Invalid IDs surface as `%LatticeStripe.Error{type: :invalid_request_error}`.

- **D-08 (Discount → Coupon dispatch)**: The tightening lives in `Discount.decode_coupon/1`, not inside `Coupon.from_map/1`. This keeps each decoder responsible for its own input validation and makes the dispatch point greppable.

## Self-Check: PASSED

- `lib/lattice_stripe/coupon.ex` exists
- `lib/lattice_stripe/discount.ex` modified (decode_coupon + LatticeStripe.Coupon.t() typespec present)
- `test/lattice_stripe/coupon_test.exs` replaced (29 assertions across 11 tests)
- `test/lattice_stripe/discount_test.exs` extended
- `test/integration/coupon_integration_test.exs` replaced
- Commits `56cdaa4`, `63f5bbd`, `5033552` present in `git log`
- `mix compile --warnings-as-errors` clean
- All Plan 12-06-owned tests pass
