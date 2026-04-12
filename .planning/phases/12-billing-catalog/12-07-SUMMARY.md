---
phase: 12-billing-catalog
plan: 07
subsystem: billing-catalog
tags: [promotion-code, coupon-dispatch, d-04-absence, d-05-absence, d-06-discovery, d-07-identifiers]
dependency_graph:
  requires:
    - 12-01 (wave 0 scaffolds)
    - 12-02 (FormEncoder + shared Resource helpers)
    - 12-03 (Discount typed struct)
    - 12-06 (LatticeStripe.Coupon — expanded-coupon decode target)
  provides:
    - LatticeStripe.PromotionCode
  affects: []
tech_stack:
  added: []
  patterns:
    - "D-04/D-05 double absence (no search + no delete) documented as named moduledoc section — absence is the interface"
    - "D-06 discovery via list/2 filters (code, coupon, customer, active) — substitute for the non-existent search endpoint"
    - "D-07 three-identifier distinction (Coupon.id vs PromotionCode.id vs PromotionCode.code) locked into moduledoc and verified via Code.fetch_docs"
    - "D-07 custom customer-facing code flows through params map via the 'code' key — no helper, no validation"
    - "Three-clause coupon dispatch in from_map/1: nil / string / map → %Coupon{} (expanded by default on PromotionCode responses per Stripe docs)"
key_files:
  created:
    - lib/lattice_stripe/promotion_code.ex
  modified:
    - test/lattice_stripe/promotion_code_test.exs
    - test/integration/promotion_code_integration_test.exs
decisions:
  - "D-04/D-05 double absence (no search + no delete) named explicitly in a single moduledoc section with the update(active:false) deactivation workaround"
  - "D-06 discovery path: list/2 filter keys enumerated in moduledoc (code, coupon, customer, active) and exercised in integration test"
  - "D-07 three-identifier table locked into moduledoc and verified by doc contract tests reading Code.fetch_docs"
  - "from_map/1 coupon dispatch is three-clause (nil / is_binary / map) — pattern-match failure on any fourth shape is the desired loud signal for Stripe API format changes"
metrics:
  tasks: 2
  completed_date: 2026-04-11
requirements: [BILL-06b]
---

# Phase 12 Plan 07: LatticeStripe.PromotionCode Summary

Ships `LatticeStripe.PromotionCode` with the 5-operation surface (create/retrieve/update/list/stream!), three-way coupon dispatch in `from_map/1`, and moduledoc-enforced documentation of the three distinct identifiers and the list-filter discovery path — closing BILL-06b and completing Wave 5 of Phase 12.

## What was built

- **`lib/lattice_stripe/promotion_code.ex`** (new, ~190 lines):
  - `LatticeStripe.PromotionCode` struct with 13 fields + `extra: %{}` catch-all
  - 5-op surface: `create/2,3`, `retrieve/2,3`, `update/3,4`, `list/1,2,3`, `stream!/1,2,3` (plus bang variants for non-list ops)
  - **NO `search/2,3`** — D-04/D-05 verified absent from Stripe's OpenAPI spec
  - **NO `delete/2,3`** — PromotionCodes cannot be deleted; deactivate via `update(active: false)`
  - `from_map/1` with three-clause `decode_coupon/1` private helper: `nil` / binary ID / map → `Coupon.from_map/1`
  - `@moduledoc` carries four named sections:
    - `## Identifiers` — table distinguishing `Coupon.id` / `PromotionCode.id` / `PromotionCode.code` with examples
    - `## Usage` — create-with-custom-code and update-to-deactivate snippets
    - `## Finding promotion codes` — D-06 discovery path with all four filter keys named
    - `## Operations not supported by the Stripe API` — D-04/D-05 absences with workarounds
- **`test/lattice_stripe/promotion_code_test.exs`** (replaced wave-0 stub, 11 tests):
  - `from_map/1` decoding: minimal, nil coupon, string coupon, expanded coupon → `%Coupon{}`, unknown fields → `extra`
  - Function surface presence: `create/2`, `retrieve/2`, `update/3`, `list/1`, `stream!/1`
  - Function surface absence (D-04/D-05): `search/2`, `search/3`, `search!/2`, `delete/2`, `delete/3`
  - Doc contracts via `Code.fetch_docs/1`: Identifiers section, three-identifier distinction, `SUMMER25USER`, `promo_` prefix, `Finding promotion codes` heading, four filter keys, `Operations not supported` heading, `/v1/promotion_codes/search` callout
- **`test/integration/promotion_code_integration_test.exs`** (replaced wave-0 stub, 3 tests):
  - CRUD round-trip: create with custom `code` → retrieve → update (`active: false`) → list
  - D-06 discovery exercise: `list/2` with each of `coupon` / `active` / `code` / `customer` filters accepted by stripe-mock
  - D-07 coupon dispatch tolerance: accepts expanded `%Coupon{}`, unexpanded string ID, or nil from stripe-mock response (mock may choose any shape)

## Verification

- `mix compile --warnings-as-errors` — clean
- `mix test test/lattice_stripe/promotion_code_test.exs` — 11 tests, 0 failures
- `mix test --exclude integration` — 696 tests / 4 properties, 0 failures
- Integration file compiles; execution requires stripe-mock running at `localhost:12111` (run in CI via Docker image)

## Deviations from Plan

None — plan executed exactly as written. The worktree branched from an older main commit, so a pre-execution `git merge main` was required to bring in the Phase 12 context files, prior-wave summaries, and Plan 06 artifacts (`Coupon`, `Discount` tightening, `FormEncoder` battery). No code deviation from the plan itself.

## Threat Flags

None. The three-clause `decode_coupon/1` dispatch (T-12-19) is implemented exactly as mitigated: pattern-match failure on any fourth shape is the intended loud signal. Custom `code` string pass-through (T-12-20) and customer-facing code string exposure (T-12-21) are accepted per plan.

## Self-Check: PASSED

- `lib/lattice_stripe/promotion_code.ex` — FOUND
- `test/lattice_stripe/promotion_code_test.exs` — FOUND (11 tests)
- `test/integration/promotion_code_integration_test.exs` — FOUND (3 tests)
- Commits:
  - `c4f959c` — RED (failing tests)
  - `dc9d2bf` — GREEN (PromotionCode module)
  - `944f418` — integration test
