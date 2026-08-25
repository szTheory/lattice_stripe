---
phase: 66-product-feature-attachment
plan: 03
subsystem: api
tags: [stripe, product-feature, object-types, semver, exunit]
requires:
  - phase: 66-01
    provides: "LatticeStripe.Product.Feature decoder and public attachment resource"
provides:
  - "Semver-safe raw Product marketing-field compatibility regression"
  - "Exact product_feature ObjectTypes dispatch with typed nested entitlement feature"
  - "Byte-exact rejection of the dotted product.feature typo"
affects: [webhook-dispatch, product-decoding, phase-66-validation]
tech-stack:
  added: []
  patterns:
    - "Literal ObjectTypes discriminators are tested for exact acceptance and near-miss rejection."
    - "Legacy and current Product marketing fields remain independent raw maps in 1.x."
key-files:
  created: []
  modified:
    - lib/lattice_stripe/object_types.ex
    - test/lattice_stripe/object_types_test.exs
    - test/lattice_stripe/product_test.exs
key-decisions:
  - "D-09/D-10/D-26: Product.features and Product.marketing_features remain independent raw maps throughout 1.x."
  - "D-11/D-27: register only exact product_feature and reject product.feature without normalization or map-size locks."
patterns-established:
  - "A registry row that affects webhook related-object behavior must be included in explicit retrievability triage."
requirements-completed: [PROD-01, PROD-02]
coverage:
  - id: D1
    description: "Legacy Product.features and current Product.marketing_features preserve raw, independent string-keyed map lists."
    requirement: PROD-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/product_test.exs#legacy and current Product marketing fields remain raw and independent"
        status: pass
      - kind: other
        ref: "git diff --quiet lib/lattice_stripe/product.ex (pass)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Only the exact product_feature discriminator dispatches to a typed Product.Feature with a typed nested entitlement feature and preserved future fields."
    requirement: PROD-01
    verification:
      - kind: unit
        ref: "test/lattice_stripe/object_types_test.exs#product_feature resolves and deserializes exactly"
        status: pass
    human_judgment: false
  - id: D3
    description: "The dotted product.feature typo is rejected and remains a raw map."
    requirement: PROD-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/object_types_test.exs#product.feature is rejected byte-for-byte"
        status: pass
    human_judgment: false
duration: 3min
completed: 2026-08-25
status: complete
---

# Phase 66 Plan 03: Product Dispatch and Compatibility Summary

**Product marketing compatibility remains semver-safe in 1.x, while the exact Stripe `product_feature` object now dispatches to the typed Product.Feature attachment.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-08-25T14:29:09Z
- **Completed:** 2026-08-25T14:32:12Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Locked old-only, current-only, and both-present Product marketing payloads to their independent raw map shapes, including string-key access and absent-sibling behavior.
- Registered exactly `"product_feature"` in `ObjectTypes`; typed dispatch preserves the nested `%Entitlements.Feature{}` and future top-level fields in `extra`.
- Locked the dotted `"product.feature"` spelling to `:error` / raw-map behavior without adding a brittle registry-size assertion.

## Task Commits

1. **Task 1: Lock raw independent Product marketing compatibility** — `732e469` (test), `b7e32bb` (style)
2. **Task 2: Register and prove the exact product_feature discriminator** — `4ee02ed` (test RED), `6822573` (feat GREEN)

## Files Created/Modified

- `lib/lattice_stripe/object_types.ex` — exact `"product_feature"` dispatch entry only.
- `test/lattice_stripe/object_types_test.exs` — exact dispatch, nested decoder/extra, dotted-typo rejection, and webhook-triage coverage.
- `test/lattice_stripe/product_test.exs` — named raw-map compatibility regression for legacy/current Product fields.

## Decisions Made

- PROD-02 follows the accepted D-09/D-10/D-26 interpretation: the dedicated attachment endpoint is typed; Product marketing-copy fields are not.
- The registry accepts only exact wire bytes. No `product.feature` alias, normalization, copying, `Product.MarketingFeature` module, or map-size assertion was added.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Task 1 intentionally characterizes existing Product decoding, so its new regression passed immediately; no Product runtime change was appropriate or made. Task 2's RED test failed before the registry entry was added, then passed after the exact mapping was implemented.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The registry and compatibility locks are ready for Phase 66 documentation/API-surface work. The Product decoder must remain untouched by later attachment changes unless a future major-release migration explicitly changes its published raw-map contract.

## Self-Check: PASSED

- All three modified implementation/test files exist.
- Task commits `732e469`, `4ee02ed`, `6822573`, and `b7e32bb` exist in git history.

---
*Phase: 66-product-feature-attachment*
*Completed: 2026-08-25*
