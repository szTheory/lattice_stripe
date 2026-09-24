---
phase: 75-typed-contract-updates
plan: 02
subsystem: payments
tags: [elixir, stripe, refunds, api-versioning, exunit]
requires:
  - phase: 75-01
    provides: Shared Invoice changelog note and additive API lock baseline
  - phase: 74-versioned-stripe-drift-triage
    provides: Refund field inventory membership and immutable GA schema evidence
provides:
  - Optional typed Refund.customer, customer_account, and payment_method decoding
  - Schema-derived retrieval and expandable-reference regression coverage
  - Refund endpoint version guidance and completed unreleased changelog notes
  - Reviewed additive Refund public API lock entries
affects: [refund-attribution, public-api-compatibility, release-notes]
actuals:
  tokens: 2934
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns:
    - Decode known expandable Refund references through ObjectTypes while retaining unknown response keys in extra
key-files:
  created:
    - .planning/phases/75-typed-contract-updates/75-02-SUMMARY.md
  modified:
    - lib/lattice_stripe/refund.ex
    - test/lattice_stripe/refund_test.exs
    - CHANGELOG.md
    - priv/api/current.txt
key-decisions:
  - "Type customer as Customer.t() | map() | String.t() | nil so deleted_customer remains a raw map under the existing object registry."
  - "Keep the default Stripe API version at 2026-03-25.dahlia and limit new availability claims to Refund API endpoint responses from 2026-07-29.dahlia."
  - "Treat optional Refund struct fields as additive within the current minor line; leave package versioning to Release Please."
patterns-established:
  - "Schema-derived Refund cases name the immutable Stripe OpenAPI GA commit, JSON property paths, and minimum API version."
requirements-completed: [DRIFT-02, DRIFT-03, DRIFT-04]
coverage:
  - id: D1
    description: Refund retrieval and decoding expose customer, customer_account, and payment_method across ID, null, omitted, supported expanded, and deleted_customer forms while preserving extra and existing behavior.
    requirement: DRIFT-02
    verification:
      - kind: unit
        ref: test/lattice_stripe/refund_test.exs#retrieves schema-derived attribution fields at their minimum API version
        status: pass
      - kind: unit
        ref: test/lattice_stripe/refund_test.exs#attribution fields are nil when omitted or explicitly null
        status: pass
      - kind: unit
        ref: test/lattice_stripe/refund_test.exs#customer expands known customers and preserves deleted_customer maps
        status: pass
      - kind: unit
        ref: test/lattice_stripe/refund_test.exs#payment_method expands known objects and accepts an ID
        status: pass
      - kind: unit
        ref: test/lattice_stripe/refund_test.exs#inspect output does NOT contain attribution fields
        status: pass
    human_judgment: false
  - id: D2
    description: The public API lock records only the three additive Refund fields alongside the prior additive Invoice entry.
    requirement: DRIFT-03
    verification:
      - kind: other
        ref: mix lattice_stripe.api_surface --check (3467 entries; pass)
        status: pass
    human_judgment: false
  - id: D3
    description: Refund module docs and changelog state the adopter purpose, 2026-07-29.dahlia minimum, Refund endpoint response scope, unproven event availability, and unchanged 2026-03-25.dahlia package default.
    requirement: DRIFT-04
    verification:
      - kind: other
        ref: mix lattice_stripe.version_prose --check (matches package version 2.2.2)
        status: pass
      - kind: other
        ref: mix docs --warnings-as-errors (completed without warnings)
        status: pass
    human_judgment: true
    rationale: Automated checks validate version prose and successful rendering, but no executable check asserts the endpoint-scope and event-availability wording across both documentation surfaces.
duration: 8min
completed: 2026-09-24
status: complete
plan_head_before: 180ada1619b8d11bb0dbe0af02dbeb23ff687cab
commits: 3
---

# Phase 75 Plan 02: Typed Refund Attribution Summary

**Refund responses now decode customer, customer-account, and payment-method attribution with schema-qualified nullable and expandable shapes, version guidance, and additive API-lock coverage.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-09-24T12:33:11Z
- **Completed:** 2026-09-24T12:40:52Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added optional `Refund.customer`, `Refund.customer_account`, and `Refund.payment_method` fields to `@known_fields`, the public struct and typespec, and `from_map/1`. Customer and payment method use the existing `ObjectTypes.maybe_deserialize/1`; deleted customers remain raw maps and unrelated keys remain in `extra`.
- Added schema-derived retrieval and decoder coverage. The examples identify Stripe OpenAPI GA commit `c8faccbde66b784ea916d3c28f5790d7a9c9aee2`, property pointers `/components/schemas/refund/properties/customer`, `/customer_account`, and `/payment_method`, and minimum API version `2026-07-29.dahlia`. These fixtures are not live Stripe captures and make no live-payload or event-availability claim.
- Documented refund customer/account and payment-method attribution, the Refund API endpoint response scope, the minimum API version, and the unchanged `2026-03-25.dahlia` package default. The unreleased changelog now covers all four Phase 75 fields and their adopter jobs.
- Reviewed the API lock diff: three Refund field additions in this plan; four additive fields across Phase 75 including the Invoice field from 75-01. No existing entry changed or was removed.

## Task Commits

1. **Task 1 RED tests:** `c310c60` (`test(75-02): add failing refund attribution tests`)
2. **Task 1 implementation:** `b7c173d` (`feat(75-02): expose Refund attribution fields`)
3. **Task 2 release notes and API lock:** `3cb08e2` (`chore(75-02): lock Refund API and release notes`)

The plan metadata commit includes this summary.

## Files Created/Modified

- `lib/lattice_stripe/refund.ex` — optional attribution fields, accurate expandable unions, decoder assignments, and API-version/scope documentation.
- `test/lattice_stripe/refund_test.exs` — schema-derived retrieval, ID/null/omission/expanded forms, deleted-customer raw-map behavior, existing behavior, and Inspect redaction assertions.
- `CHANGELOG.md` — unreleased notes for the Invoice and Refund additions, their adopter uses, and unchanged default API version.
- `priv/api/current.txt` — three additive Refund struct fields; final lock contains 3,467 entries.

## Decisions Made

- Used the schema-qualified types: customer accepts a Customer struct, raw map, ID string, or `nil`; customer_account accepts an ID string or `nil`; payment_method accepts a PaymentMethod struct, ID string, or `nil`.
- Kept object registry and webhook fetching behavior unchanged. In particular, `deleted_customer` stays a map because it is not in the existing decoder registry.
- Kept API version behavior opt-in and made no event-payload availability claim. The public struct additions are minor-line additions under `guides/api_stability.md`; package versioning remains with Release Please.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

- The worktree initially lacked fetched Mix dependencies. `HEX_HOME=/private/tmp/lattice-stripe-hex mix deps.get` fetched the existing locked dependencies without modifying dependency declarations or lockfiles.
- The RED evidence checker consumes TAP output while this project uses ExUnit. A temporary Node TAP wrapper ran the focused ExUnit suite and preserved its intentional target-test assertion failure; `gsd_run check tdd-red-evidence` returned `RED_EVIDENCE_OK` before implementation.

## Verification Results

- `mix test test/lattice_stripe/refund_test.exs` — passed, 44 tests, 0 failures.
- `mix lattice_stripe.api_surface --check` — passed, 3,467 entries. Diff review against the pre-Phase 75 baseline found only the prior Invoice field and three Refund field additions.
- `mix lattice_stripe.version_prose --check` — passed, version prose matches package version 2.2.2.
- `mix docs --warnings-as-errors` — passed, generated without warnings.
- `mix ci` — passed: Credo reported no issues; 2,461 tests, 0 failures, 1 skipped; public API lock, version prose, and docs checks passed. The compiler emitted existing deprecation warnings in Billing Meter and Account Capability tests.
- `LatticeStripe.api_version/0` remains `2026-03-25.dahlia`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 75 plans 01 and 02 are complete. The selected Invoice and Refund fields are typed and covered; the separate lower-priority InvoiceItem field remains outside this reconciliation slice.

---
*Phase: 75-typed-contract-updates*
*Completed: 2026-09-24*

## Self-Check: PASSED

- Summary file exists at the expected phase path.
- Task commits `c310c60`, `b7c173d`, and `3cb08e2` exist in worktree history.
