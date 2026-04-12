---
phase: 12-billing-catalog
plan: 02
subsystem: api
tags: [elixir, form-encoding, stream-data, stripe, property-testing]

requires:
  - phase: 12-billing-catalog
    provides: stream_data test dep + empty form_encoder_test stub (12-01)
provides:
  - Float-aware FormEncoder scalar encoder (no scientific notation)
  - D-09a enumerated regression battery (triple/quadruple nesting, tiers, applies_to, Connect controller)
  - D-09b StreamData property layer (4 invariants x 200 runs)
  - D-09c metadata special-character handling (hyphen, slash, space, brackets)
  - D-09d empty-string vs nil contract (clear vs omit)
  - D-09e atom/string value parity
affects: [12-03-price, 12-04-coupon, 12-05-promotion-code, 12-06-tax-rate, 12-07-billing-meter, 13-connect]

tech-stack:
  added: []
  patterns:
    - ":erlang.float_to_binary/2 with [:compact, {:decimals, 12}] for Stripe decimal fields"
    - "StreamData tree generator for nested param maps (scalar leaves + map/list branches)"
    - "Property invariants co-located with enumerated examples in single test module"

key-files:
  created: []
  modified:
    - lib/lattice_stripe/form_encoder.ex
    - test/lattice_stripe/form_encoder_test.exs

key-decisions:
  - "D-09f: :erlang.float_to_binary with :compact instead of to_string/1 (float branch added before catch-all in flatten_value/2)"
  - "Single canonical test file: enumerated battery and property layer co-located in form_encoder_test.exs"
  - "StreamData tree generator uses string/integer/boolean scalars only — floats excluded from property inputs to keep shrink deterministic (float branch guarded by enumerated D-09f tests)"

patterns-established:
  - "TDD RED→GREEN→(no refactor needed): commit failing test first, then minimal fix"
  - "Property runs capped at max_runs: 200 per invariant to keep suite under 1s"
  - "URL-decodable invariant via URI.decode_query as cheap wire-format sanity check"

requirements-completed: [BILL-01, BILL-02, BILL-06, BILL-06b]

duration: 8min
completed: 2026-04-12
---

# Phase 12 Plan 02: FormEncoder Float Fix + D-09 Battery Summary

**Float-aware Stripe form encoder using :erlang.float_to_binary with 14 enumerated nested-shape tests and 4 StreamData property invariants (nil omission, determinism, URL-decodability, no key collisions)**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-12T01:44:00Z
- **Completed:** 2026-04-12T01:52:38Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Fixed latent scientific-notation bug in `FormEncoder.flatten_value/2` — small floats like `0.00001` no longer encode as `1.0e-5` (would have been rejected by Stripe's `unit_amount_decimal`/`percent_off` parsers).
- Landed D-09a..e comprehensive regression battery: 14 enumerated nested-shape tests covering `items[0][price_data][recurring][interval]`, `items[0][price_data][transform_quantity][divide_by]`, Price `tiers`, Coupon `applies_to[products]`, Connect `account[controller]` booleans, metadata special characters, atom/string parity, nil/empty-string semantics.
- Landed D-09b StreamData property layer: 4 invariants (no nil emission, determinism, URL-decodability, no duplicate keys) run 200 times each against a tree-generated nested map generator.
- 32 → 55 total tests (4 properties + 51 test cases), suite green in ~100ms.

## Task Commits

Each task committed atomically with TDD discipline:

1. **Task 1 (RED): failing float encoding tests (D-09f)** — `538c98b` (test)
2. **Task 1 (GREEN): float-aware scalar encoder** — `1c80739` (feat)
3. **Task 2: D-09a..e enumerated battery + StreamData property layer** — `845cfdf` (test)

_Task 2 has no REFACTOR commit — existing behavior was already correct for all non-float cases; only new tests were added, no implementation changes._

## Files Created/Modified
- `lib/lattice_stripe/form_encoder.ex` — Added `flatten_value/2` head with `is_float/1` guard using `:erlang.float_to_binary(value, [:compact, {:decimals, 12}])` before the catch-all `to_string/1` branch.
- `test/lattice_stripe/form_encoder_test.exs` — Added `use ExUnitProperties`; appended 12 describe blocks covering float handling, triple/quadruple nesting, tier lists, applies_to, Connect booleans, metadata special chars, empty-string vs nil, atom round-trip, sort determinism, and StreamData property layer.

## Decisions Made
- **Compact decimal form with 12-digit precision**: `[:compact, {:decimals, 12}]` gives exact representation for Stripe's decimal money fields without trailing zeros. 12 decimals covers all realistic unit_amount_decimal / percent_off use cases and is well below double-precision float limits.
- **Property generator excludes floats**: Keeps shrinking deterministic and avoids conflating float-format assertions with structural invariants. Float behavior is locked by the 6 enumerated D-09f tests.
- **URL-decodability via `URI.decode_query`**: Chosen as the property-level wire-format check — it exercises the `&`/`=` split and percent-decode path with a single round-trip, without asserting structural recovery (round-trip recovery is untestable because the encoder flattens nested structure).

## Deviations from Plan

None — plan executed exactly as written. All acceptance criteria met on first compile after GREEN patch.

## Issues Encountered
- Initial `mix test` failed with "stream_data dependency not available" — expected since the worktree had not yet fetched deps. Resolved by running `mix deps.get` (surface-level, not a code issue).

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- **FormEncoder is now the hardened foundation every Phase 12 resource builds on.** Plans 12-03 (Price), 12-04 (Coupon), 12-05 (PromotionCode), 12-06 (TaxRate), 12-07 (BillingMeter) can now pass floats (`unit_amount_decimal`, `percent_off`) and triple-nested inline shapes (`items[0][price_data][recurring]`) without encoder-level regression risk.
- Property invariants stay permanently in the suite — any future FormEncoder change that introduces nil-leaks, key collisions, or non-determinism will be caught by 800 random runs per CI invocation.
- Wave 1 complete; Wave 2 (Price + Coupon resources) unblocked.

## Self-Check: PASSED

- `lib/lattice_stripe/form_encoder.ex` — FOUND (modified)
- `test/lattice_stripe/form_encoder_test.exs` — FOUND (modified)
- Commit `538c98b` (test RED) — FOUND
- Commit `1c80739` (feat GREEN) — FOUND
- Commit `845cfdf` (test battery) — FOUND
- `mix test test/lattice_stripe/form_encoder_test.exs` — PASSED (4 properties, 51 tests, 0 failures)
- `mix compile --warnings-as-errors` — PASSED

---
*Phase: 12-billing-catalog*
*Completed: 2026-04-12*
