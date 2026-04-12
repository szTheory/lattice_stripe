---
phase: 12-billing-catalog
plan: 05
subsystem: billing-catalog
tags: [price, recurring, tier, atomization, typed-nesteds, form-encoder]
dependency_graph:
  requires:
    - 12-01 (wave 0 scaffolds + stripe-mock infra)
    - 12-02 (FormEncoder float fix D-09f)
  provides:
    - LatticeStripe.Price
    - LatticeStripe.Price.Recurring
    - LatticeStripe.Price.Tier
  affects:
    - FormEncoder triple-nested regression guard
tech_stack:
  added: []
  patterns:
    - "Inline sibling modules in one file (Price + Price.Recurring + Price.Tier)"
    - "D-03 whitelist atomization (never String.to_atom/1)"
    - "D-05 forbidden-op absence as interface — no delete/delete!"
    - ":inf sentinel for final tier up_to"
    - "D-01 typed nesteds via dedicated from_map decoders"
key_files:
  created:
    - lib/lattice_stripe/price.ex
  modified:
    - test/lattice_stripe/price_test.exs
    - test/integration/price_integration_test.exs
decisions:
  - "Product dep in integration test resolved via Code.ensure_loaded? — graceful fallback to hardcoded product id when parallel Plan 12-04 worktree has not yet merged"
  - "Triple-nested round-trip asserted against FormEncoder output (not live stripe-mock) because /v1/prices is a flat-params endpoint — the inline price_data shape is consumed by /v1/subscriptions (Plan 15) and /v1/checkout/sessions (Plan 06)"
metrics:
  tasks: 2
  completed_date: 2026-04-11
requirements: [BILL-02]
---

# Phase 12 Plan 05: Price + Recurring + Tier Summary

Ships `LatticeStripe.Price` with inline `Price.Recurring` and `Price.Tier` typed nested structs — Phase 12's semantically heaviest resource. All seven atomized enums whitelist-based (type, billing_scheme, tax_behavior on parent; interval, usage_type, aggregate_usage on Recurring), forbidden `delete` op absent by design (D-05), `:inf` sentinel for final tier, and D-10 eventual-consistency callout on `search/3`. BILL-02 complete.

## What Shipped

### `lib/lattice_stripe/price.ex` (single file, three sibling modules)

**`LatticeStripe.Price`** — full v1 resource template minus delete:

- CRUD: `create/2,3`, `retrieve/2,3`, `update/3,4`, `list/1,2,3`
- Search: `search/2,3` + `search_stream!/2,3`
- Pagination: `stream!/1,2,3`
- Bang variants for all of the above
- **No `delete/2,3` and no `delete!/2,3`** (D-05) — Prices are immutable in Stripe; archive via `update(client, id, %{"active" => "false"})`, and the `@moduledoc` documents this in an `## Operations not supported by the Stripe API` section
- `from_map/1` atomizes `type`, `billing_scheme`, `tax_behavior` via whitelist helpers (unknown values pass through as strings for forward compatibility), decodes nested `recurring` via `Price.Recurring.from_map/1`, and decodes each element of `tiers` via `Price.Tier.from_map/1`

**`LatticeStripe.Price.Recurring`** — typed nested (D-01):

- Fields: `aggregate_usage`, `interval`, `interval_count`, `meter`, `trial_period_days`, `usage_type`, `extra`
- `from_map/1` whitelist-atomizes `interval` (`:day`/`:week`/`:month`/`:year`), `usage_type` (`:licensed`/`:metered`), and `aggregate_usage` (`:sum`/`:last_during_period`/`:last_ever`/`:max`)

**`LatticeStripe.Price.Tier`** — typed nested (D-01):

- Fields: `flat_amount`, `flat_amount_decimal`, `unit_amount`, `unit_amount_decimal`, `up_to`, `extra`
- `from_map/1` coerces `up_to: "inf"` → `:inf` (with integer and nil pass-throughs) so consumers can pattern-match the final tier without worrying about the literal string

### `test/lattice_stripe/price_test.exs` — 20 unit tests

- D-03 atomization (type, billing_scheme, tax_behavior) incl. unknown pass-through
- D-01 typed nesteds: `%Price.Recurring{}` decoding, `[%Price.Tier{}]` decoding, nil handling
- `Price.Recurring.from_map/1` full whitelist coverage
- `Price.Tier.from_map/1` `:inf` / integer / nil cases
- D-05 function-surface assertions: CRUD present, `delete`/`delete!` refuted in both /2 and /3 arities
- D-10 doc contracts: `Code.fetch_docs/1` confirms search/3 contains "eventual consistency" and `data-freshness` URL; `@moduledoc` documents forbidden delete with `active` workaround

### `test/integration/price_integration_test.exs` — stripe-mock integration

- CRUD round-trip: create → retrieve → update(active:false) → list
- Recurring price decode smoke test
- **D-09 triple-nested regression guard** — asserts FormEncoder produces `items[0][price_data][recurring][interval]=month`, `interval_count=3`, `usage_type=licensed`, plus sibling `tax_behavior=exclusive` and `product_data[name]=T-shirt`
- **D-09f float regression guard** — `percent_off=12.5` round-trips without scientific notation
- `search/3` smoke test (accepts error because stripe-mock's search implementation is limited)

## TDD Flow

| Phase | Commit | Details |
|-------|--------|---------|
| RED | `c347373` | `test(12-05): add failing tests for Price + Recurring + Tier` — compile error on `%Recurring{}` undefined |
| GREEN | `de3495f` | `feat(12-05): implement Price + Price.Recurring + Price.Tier` — 20/20 unit tests pass |
| Integration | `a58d5b3` | `test(12-05): add Price stripe-mock integration with triple-nested round-trip` — unit suite 652/652, integration file compiles clean |

## Verification Results

- `mix compile --warnings-as-errors` — clean (3 modules in one file, no warnings)
- `mix test test/lattice_stripe/price_test.exs` — 20 tests, 0 failures
- `mix test --exclude integration` — 4 properties, 652 tests, 0 failures (46 excluded, +4 from this plan's integration file)
- All 18 grep-based acceptance criteria satisfied (module presence, function presence, forbidden-op absence, doc strings, path strings, integration assertions)

## D-decision Coverage

| Decision | How Satisfied |
|----------|---------------|
| D-01 (typed nesteds) | `Price.Recurring` + `Price.Tier` inline sibling modules with their own `from_map/1` |
| D-03 (atomize enums) | Five whitelist helpers, unknown-value pass-through tested |
| D-05 (Price.delete forbidden) | No `delete`/`delete!` defined; absence asserted via `function_exported?`; `@moduledoc` documents workaround |
| D-09 (triple-nested FormEncoder) | Integration test asserts `items[0][price_data][recurring][interval]=month` etc. |
| D-09f (float fix) | `percent_off=12.5` regression assertion (no `"e"` scientific notation) |
| D-10 (search eventual consistency) | `search/3` `@doc` contains verbatim callout + `data-freshness` URL; Code.fetch_docs assertion |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Product module dependency in integration test**

- **Found during:** Task 2
- **Issue:** Plan's integration test setup calls `LatticeStripe.Product.create/2` to get a real product id, but Product ships in parallel Plan 12-04 which has not been merged to main yet. With `LatticeStripe.Product` undefined, the integration test file would fail to compile as soon as the test suite loads it (ExUnit compiles test files regardless of tag filter).
- **Fix:** Replaced the direct `Product.create` call with a runtime-guarded `Code.ensure_loaded?(LatticeStripe.Product) and function_exported?(LatticeStripe.Product, :create, 2)` check. When Product is available (post Plan 04 merge) the test creates a real Product via `apply/3` (no compile-time module reference); otherwise it falls back to a hardcoded `prod_integration_price_test` id (stripe-mock accepts any string product id and stubs the response).
- **Files modified:** `test/integration/price_integration_test.exs`
- **Commit:** `a58d5b3`
- **Rationale:** Wave-3 parallel worktrees cannot rely on sibling-wave artifacts. The fallback makes this file compile on any branch ordering; once both Plan 04 and Plan 05 land on main, the `Code.ensure_loaded?` branch takes the Product path automatically.

**2. [Rule 2 - Missing test robustness] Unused client warning in encoder-only tests**

- **Found during:** Task 2
- **Issue:** The FormEncoder-only tests (triple-nested, percent_off) don't use `client` but Elixir would warn on unused setup values.
- **Fix:** Pattern-matched `%{client: _client}` in those two tests.
- **Files modified:** `test/integration/price_integration_test.exs`
- **Commit:** `a58d5b3`

## Authentication Gates

None — no auth required.

## Known Stubs

None. `Price` fully wires its typed nesteds and atomization via real `from_map/1` decoders; no placeholder fields flow to callers.

## Self-Check: PASSED

**Created files:**

- FOUND: `lib/lattice_stripe/price.ex`
- FOUND: `.planning/phases/12-billing-catalog/12-05-SUMMARY.md` (this file)

**Modified files:**

- FOUND: `test/lattice_stripe/price_test.exs` (stub replaced with 20 tests)
- FOUND: `test/integration/price_integration_test.exs` (stub replaced with CRUD + D-09 + D-09f)

**Commits:**

- FOUND: `c347373` — RED test
- FOUND: `de3495f` — GREEN implementation
- FOUND: `a58d5b3` — integration test

**Verification:**

- PASSED: `mix compile --warnings-as-errors`
- PASSED: `mix test test/lattice_stripe/price_test.exs` (20/20)
- PASSED: `mix test --exclude integration` (652/652)
- PASSED: 18/18 acceptance grep checks
