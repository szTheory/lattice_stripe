---
phase: 12-billing-catalog
plan: 03
subsystem: billing-catalog
tags: [discount, customer, typed-struct, backfill]
requires:
  - 12-01  # Wave 0 test infrastructure (discount_test.exs stub)
provides:
  - LatticeStripe.Discount typed struct + from_map/1
  - Customer.discount backfilled from map() to Discount.t()
affects:
  - lib/lattice_stripe/customer.ex (typespec + decoder)
tech-stack:
  added: []
  patterns:
    - "Nested read-only typed struct (defstruct + @known_fields + from_map/1 + extra catch-all)"
    - "Reserved-keyword atom struct field (:end) accessed via Map.get dot-sugar"
    - "Lazy embedded-object dispatch via private decode_* helpers"
key-files:
  created:
    - lib/lattice_stripe/discount.ex
  modified:
    - test/lattice_stripe/discount_test.exs
    - lib/lattice_stripe/customer.ex
    - test/lattice_stripe/customer_test.exs
decisions:
  - "Kept coupon field as term() in typespec until Plan 12-06 lands the Coupon module"
  - "decode_discount/1 private helper in Customer rather than pattern-match clause on from_map/1 — keeps from_map body uniform"
metrics:
  duration_seconds: 142
  completed: 2026-04-12
  tasks_completed: 2
  tests_added: 14
  files_created: 1
  files_modified: 3
requirements: [BILL-06]
---

# Phase 12 Plan 03: Discount Module + Customer.discount Backfill Summary

**One-liner:** Created `LatticeStripe.Discount` typed struct with `from_map/1` (handling the `:end` reserved-keyword field) and backfilled `Customer.discount` from `map()` to `Discount.t() | nil` via a private `decode_discount/1` helper.

## Tasks Completed

| Task | Name                                                    | Commit(s)            | Result |
| ---- | ------------------------------------------------------- | -------------------- | ------ |
| 1    | Create LatticeStripe.Discount module + tests (D-08)     | 2e53263, 2fc3d92     | GREEN  |
| 2    | Backfill Customer.discount as typed Discount.t() (D-02) | 5df292c, 10deb86     | GREEN  |

Each task used TDD: RED commit (failing tests) followed by GREEN commit (implementation).

## Implementation Details

### Task 1 — `LatticeStripe.Discount`

New module at `lib/lattice_stripe/discount.ex`:

- `defstruct` with 11 explicit fields plus `object: "discount"` default and `extra: %{}` catch-all
- `:end` atom field works fine as a struct key — Elixir only forbids the bareword `end`, not the atom `:end`. Dot access (`discount.end`) compiles to `Map.get(discount, :end)` which is legal syntax; the test suite locks this behavior explicitly.
- `@known_fields` sigil list drives both the struct shape and `Map.drop/2` for the `extra` catch-all
- `from_map/1` accepts any map and returns a struct with nil defaults for missing fields
- `coupon` field is `term()` in the typespec and kept as whatever shape Stripe returns (nil, string ID, or map). Plan 12-06 will replace this with a `decode_coupon/1` helper that calls `LatticeStripe.Coupon.from_map/1`.

Tests (11 total) cover:

- Minimal map decoding
- Both `start` and `end` Unix timestamps
- Explicit `:end` runtime access path (reserved-keyword safety check)
- All six parent-ID fields (customer, subscription, invoice, invoice_item, checkout_session, promotion_code)
- Three `coupon` shapes: string, expanded map, nil
- Empty map → struct with all-nil fields and empty `extra`
- Unknown field → lands in `extra`
- `defstruct` defaults (`object: "discount"`, `extra: %{}`)

### Task 2 — `Customer.discount` Backfill

Three edits to `lib/lattice_stripe/customer.ex`:

1. Alias updated: `alias LatticeStripe.{Client, Discount, Error, List, Request, Resource, Response}`
2. Typespec: `discount: map() | nil` → `discount: Discount.t() | nil`
3. `from_map/1` body: `discount: map["discount"]` → `discount: decode_discount(map["discount"])`
4. Added private helper at module bottom:
   ```elixir
   defp decode_discount(nil), do: nil
   defp decode_discount(%{} = discount_map), do: Discount.from_map(discount_map)
   ```

Three regression tests appended to `test/lattice_stripe/customer_test.exs` under a new `describe "from_map/1 — D-02 discount backfill"` block:

- Embedded discount map decodes to `%Discount{}`, not raw map
- Explicit `nil` stays `nil`
- Missing key produces `nil`

## Verification Results

- `mix compile --warnings-as-errors` — clean
- `mix test test/lattice_stripe/discount_test.exs` — 11/11 passing
- `mix test test/lattice_stripe/customer_test.exs` — 24/24 passing (21 existing + 3 new)
- `mix test` full suite — **633 tests, 4 properties, 0 failures** (42 integration excluded)

Grep-based acceptance criteria from the plan:

| Check                                                                | Result |
| -------------------------------------------------------------------- | ------ |
| `grep -q "defmodule LatticeStripe.Discount"`                         | OK     |
| `grep -q ":end," lib/lattice_stripe/discount.ex`                     | OK     |
| `grep -q "Map.drop(map, @known_fields)"`                             | OK     |
| `grep -q "alias LatticeStripe.{Client, Discount"`                    | OK     |
| `grep -q "Discount.t() \| nil" lib/lattice_stripe/customer.ex`       | OK     |
| `grep -q "decode_discount" lib/lattice_stripe/customer.ex` (3 refs)  | OK     |
| `grep -q "discount: map() \| nil" lib/lattice_stripe/customer.ex`    | OK (absent) |
| `grep -q "D-02 discount backfill" test/lattice_stripe/customer_test.exs` | OK |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. The `coupon` field holding a raw map when Stripe returns an expanded Coupon is not a stub — it is a documented intentional design, explicitly called out in the Discount `@typedoc` and slated for tightening in Plan 12-06. Plan 12-03's success criteria deliberately accept this state.

## Success Criteria Status

- [x] `LatticeStripe.Discount` module exists with typed struct + `from_map/1`
- [x] `Discount` struct includes `:end` field (reserved-keyword safe, runtime-verified)
- [x] `from_map/1` decodes with nil Coupon, string Coupon, and map Coupon shapes
- [x] `Customer.discount` typespec is `Discount.t() | nil`
- [x] `Customer.from_map/1` decodes `map["discount"]` through `Discount.from_map/1`
- [x] All existing Customer tests pass
- [x] `mix compile --warnings-as-errors` clean

## Requirements Completed

- BILL-06 (Discount typed struct — the Discount portion of the billing catalog requirement)

Note: BILL-06 also covers the Coupon module, which lands in Plan 12-06. The requirement can't be marked fully complete until Plan 12-06 lands; Plan 12-03 covers the Discount half.

## Self-Check: PASSED

- lib/lattice_stripe/discount.ex — FOUND
- test/lattice_stripe/discount_test.exs — FOUND (replaced stub)
- Commit 2e53263 — FOUND
- Commit 2fc3d92 — FOUND
- Commit 5df292c — FOUND
- Commit 10deb86 — FOUND
