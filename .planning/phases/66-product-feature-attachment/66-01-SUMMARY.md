---
phase: 66-product-feature-attachment
plan: 01
subsystem: api
tags: [elixir, stripe, product-feature, entitlements, mox, typed-resource]

requires:
  - phase: 63-stripe-native-entitlements
    provides: LatticeStripe.Entitlements.Feature nested decoder and canonical resource patterns
provides:
  - "Typed LatticeStripe.Product.Feature attachment resource under /v1/products/:product/features"
  - "Canonical create, retrieve, list, stream!, and delete surface with exact defaulted arities"
  - "Mox coverage for scoped requests, pre-network validation, identity safety, typed decode, and public-surface prohibitions"
affects: [66-02 streaming coverage, 66-03 object-type dispatch, 66-04 docs and API lock]

tech-stack:
  added: []
  patterns:
    - "Parent-scoped resources validate prod_ and prodft_ IDs before transport and construct all item paths from the scoped collection."
    - "Product Feature decoders preserve unknown top-level wire fields in :extra while directly typing entitlement_feature."

key-files:
  created:
    - lib/lattice_stripe/product/feature.ex
    - test/lattice_stripe/product/feature_test.exs
  modified: []

key-decisions:
  - "D-01/D-07: LatticeStripe.Product.Feature models the product_feature/prodft_ attachment, separately from the entitlements.feature/feat_ definition."
  - "D-02/D-03: only canonical CRUD verbs plus stream! are public; aliases and a non-bang stream are structurally forbidden."
  - "D-05/D-06/D-15: deletion addresses a caller-supplied prodft_ attachment directly and rejects feat_ definitions before transport."

requirements-completed: [PROD-01]

coverage:
  - id: D1
    description: "Product Feature attachments can be created with a typed nested entitlement definition through the Product-scoped Stripe collection."
    requirement: PROD-01
    verification:
      - kind: unit
        ref: "test/lattice_stripe/product/feature_test.exs#create/4 posts to the scoped product collection and returns a typed attachment"
        status: pass
      - kind: other
        ref: "mix test test/lattice_stripe/product/feature_test.exs --only tracer && MIX_ENV=prod mix compile"
        status: pass
    human_judgment: false
  - id: D2
    description: "Product Feature attachments expose the canonical typed retrieve/list/stream!/delete surface, preserve explicit prodft_ identity, and reject unsafe or invented alternatives."
    requirement: PROD-01
    verification:
      - kind: unit
        ref: "test/lattice_stripe/product/feature_test.exs#delete addresses one prodft attachment directly and never resolves a feat definition"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/product/feature_test.exs#exports exactly the canonical attachment surface and defaulted arities"
        status: pass
      - kind: other
        ref: "mix test test/lattice_stripe/product/feature_test.exs && mix format --check-formatted && mix compile --warnings-as-errors && mix credo --strict"
        status: pass
    human_judgment: false

duration: 5min
completed: 2026-08-25
status: complete
---

# Phase 66 Plan 01: Product Feature Attachment Summary

**Typed, Product-scoped `product_feature` attachments now support safe creation, direct retrieval and deletion, typed pagination, and lazy enumeration without conflating reusable `feat_` definitions with `prodft_` attachments.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-08-25T14:20:51Z
- **Completed:** 2026-08-25T14:25:00Z
- **Tasks:** 2
- **Files modified:** 2 (2 created)

## Accomplishments

- Added `LatticeStripe.Product.Feature` with a forward-compatible typed decoder: nil-safe, idempotent, direct nested `Entitlements.Feature` decoding, explicit delete state, and preserved unknown wire fields.
- Implemented Product-scoped `create`, `retrieve`, `list`, `stream!`, and `delete` with ordinary bang twins, caller options preserved, and `prod_`/`prodft_` validation before transport.
- Added focused Mox and surface-lock tests for all HTTP paths, empty and ordered list pages, stable idempotency keys, tuple/bang behavior, deletion identity, and prohibited aliases.

## Task Commits

1. **Task 1: End-to-end create one Product Feature attachment** — `3a17fd3` (`feat`)
2. **Task 2: Expand to retrieve, list, delete, bang twins, and exact surface** — `add2b75` (`feat`)

## Files Created/Modified

- `lib/lattice_stripe/product/feature.ex` — typed parent-scoped Product Feature attachment resource and decoder.
- `test/lattice_stripe/product/feature_test.exs` — request, validation, decode, identity, response, idempotency, and public-surface tests.

## Decisions Made

- `Product.Feature` is the explicit attachment resource: a `prodft_` target is always paired with its `prod_` parent, while `feat_` remains the reusable Entitlements Feature definition.
- The resource preserves Stripe's direct endpoints and does not introduce aliases, lookup deletion, sorting, deduplication, or a non-bang stream.
- `entitlement_feature` remains a required string-keyed create parameter so Stripe's extensible wire map passes through unchanged.

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

| Check | Result |
|---|---|
| `mix test test/lattice_stripe/product/feature_test.exs --only tracer && MIX_ENV=prod mix compile` | pass — 1 tracer test, 0 failures; production compile exit 0 |
| `mix test test/lattice_stripe/product/feature_test.exs` | pass — 16 tests, 0 failures |
| `mix format --check-formatted` | pass |
| `mix compile --warnings-as-errors` | pass |
| `mix credo --strict` | pass — no issues |

## Known Stubs

None. The only `nil` match in the focused files is the intentional, tested nil-safe decoder contract.

## Threat Flags

None. The new endpoint is within the plan's declared caller-to-Stripe trust boundary. T-66-03 is mitigated by direct scoped `prodft_` deletion and pre-network guards; T-66-04 is mitigated by `Map.split/2` extra-field preservation.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Plan 66-02 can add multi-page stream behavior against the completed `stream!/4` seam.
- Later Phase 66 plans can register the exact `product_feature` object key and document the shipped surface without changing legacy Product marketing fields.

## Self-Check: PASSED

- `lib/lattice_stripe/product/feature.ex` — exists
- `test/lattice_stripe/product/feature_test.exs` — exists
- Commit `3a17fd3` — present in git log
- Commit `add2b75` — present in git log

---
*Phase: 66-product-feature-attachment*
*Completed: 2026-08-25*
