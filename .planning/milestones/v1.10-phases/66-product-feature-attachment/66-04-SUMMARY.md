---
phase: 66-product-feature-attachment
plan: "04"
subsystem: api
tags: [elixir, exdoc, semver, product-feature, entitlements]
requires:
  - phase: 66-01
    provides: "LatticeStripe.Product.Feature public attachment resource"
  - phase: 66-03
    provides: "Raw Product marketing-field compatibility and exact product_feature dispatch"
provides:
  - "Cross-linked HexDocs that distinguish Product.Feature attachments from entitlement definitions and Product marketing display copy"
  - "Entitlements sidebar placement for the Product.Feature attachment module"
  - "Semver lock entries for the accepted Product.Feature surface"
affects: [hexdocs, api-stability, entitlements, product-catalog]
tech-stack:
  added: []
  patterns:
    - "Use an exact ExDoc module atom before a broad first-match regex for exceptional nested resource placement."
    - "Regenerate the API lock only after reviewing the complete added-symbol diff."
key-files:
  created: []
  modified:
    - lib/lattice_stripe/product/feature.ex
    - lib/lattice_stripe/product.ex
    - mix.exs
    - priv/api/current.txt
key-decisions:
  - "Product.Feature is an Entitlements sidebar member through an exact matcher; Product itself remains in Billing."
  - "Product.features and Product.marketing_features remain raw marketing display maps, while Product.Feature.list/4 and stream!/4 are the authoritative attachment catalog reads."
  - "The API lock accepts only Product.Feature's module, type, six struct fields, canonical resource functions, default arities, and decoder."
coverage:
  - id: D1
    description: "HexDocs distinguish feat_ definitions, prodft_ attachments, and Product marketing copy without changing Product decoding."
    requirement: PROD-02
    verification:
      - kind: command
        ref: "MIX_ENV=prod mix compile && mix docs (pass)"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/docs_truth_test.exs (pass, 76 tests with Product regression)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The public Product.Feature contract is limited to the accepted module, type, fields, canonical verbs, default arities, and decoder."
    requirement: PROD-01
    verification:
      - kind: command
        ref: "mix lattice_stripe.api_surface --check (pass, 3457 entries)"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/api_surface_lock_test.exs (pass)"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/product/feature_test.exs (pass)"
        status: pass
    human_judgment: false
metrics:
  duration: 3min
  completed: 2026-08-25
status: complete
---

# Phase 66 Plan 04: Product Feature Attachment Publication Summary

**Product Feature attachments are now discoverable as Entitlements-facing, cross-linked HexDocs and mechanically locked as the accepted public API.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-08-25T14:32:12Z
- **Completed:** 2026-08-25T14:35:31Z
- **Tasks:** 2/2
- **Files modified:** 4

## Accomplishments

- Documented the `prod_` Product, `feat_` entitlement definition, and `prodft_` attachment relationship, with canonical resource verbs and no parallel aliases.
- Clarified that legacy `features` and current `marketing_features` are raw marketing display copy, while `Product.Feature.list/4` and `stream!/4` enumerate access-bearing attachments.
- Added the exact `LatticeStripe.Product.Feature` ExDoc matcher in Entitlements before Billing's broad Product regex, preserving Product's Billing placement.
- Regenerated and reviewed the API snapshot: exactly 30 Product.Feature additions, with no aliases, non-bang stream, protocol implementation, extra struct field, or Product runtime-surface change.

## Verification

- `MIX_ENV=prod mix compile && mix docs` — pass.
- `mix test test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/product_test.exs` — pass (76 tests).
- `mix lattice_stripe.api_surface` — expected pre-regeneration surface violation showing exactly 30 Product.Feature additions.
- `mix lattice_stripe.api_surface --check` — pass (3457 entries).
- `mix test test/lattice_stripe/api_surface_lock_test.exs test/lattice_stripe/product/feature_test.exs` — pass (22 tests).
- Reviewed `git diff lib/lattice_stripe/product.ex`; it contains documentation-only changes.

## Task Commits

1. **Task 1: Cross-link the two Feature nouns and place the attachment in Entitlements** — `fba4c64` (`docs`)
2. **Task 2: Regenerate and review the public API surface lock** — `2319e9d` (`docs`)

## Files Created/Modified

- `lib/lattice_stripe/product/feature.ex` — public relationship and canonical-verb documentation.
- `lib/lattice_stripe/product.ex` — marketing display-copy versus access-bearing attachment guidance only.
- `mix.exs` — exact Entitlements ExDoc placement before the broad Billing Product matcher.
- `priv/api/current.txt` — 30 reviewed Product.Feature semver lock entries.

## Decisions Made

- The precise nested attachment module belongs under Entitlements, while the parent Product remains under Billing.
- No Product marketing data is retyped or decoded as Product.Feature during 1.x.
- The generated lock is accepted only for the documented Product.Feature surface.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None. This plan adds documentation, sidebar metadata, and a semver snapshot only; it introduces no network, authentication, file-access, or schema boundary.

## User Setup Required

None.

## Next Phase Readiness

Plan 05 can rely on the published distinction and API lock while adding phase-close guide and validation evidence.

## Self-Check: PASSED

- Found all four plan artifact files and this summary on disk.
- Found task commits `fba4c64` and `2319e9d` in repository history.
