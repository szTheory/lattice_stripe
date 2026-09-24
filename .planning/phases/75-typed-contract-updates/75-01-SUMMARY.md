---
phase: 75-typed-contract-updates
plan: 01
subsystem: payments
tags: [elixir, stripe, invoices, api-versioning, exunit]
requires:
  - phase: 74-versioned-stripe-drift-triage
    provides: Exact drift inventory membership and immutable GA schema evidence for Invoice.amount_paid_off_stripe
provides:
  - Optional typed Invoice.amount_paid_off_stripe decoding and retrieval support
  - Schema-derived decoder and API-version retrieval regression coverage
  - Off-Stripe invoice payment reconciliation guidance with version boundaries
  - Reviewed additive Invoice public API lock entry
affects: [75-02-refund-typed-contract-updates, invoice-reconciliation, public-api-compatibility]
actuals:
  tokens: 1979
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns:
    - Add selected response fields through @known_fields, struct, @type t, and from_map/1 while retaining extra
key-files:
  created:
    - .planning/phases/75-typed-contract-updates/75-01-SUMMARY.md
  modified:
    - lib/lattice_stripe/invoice.ex
    - test/lattice_stripe/invoice_test.exs
    - guides/invoices.md
    - CHANGELOG.md
    - priv/api/current.txt
key-decisions:
  - "Expose only the evidence-qualified optional integer field; leave amount_paid and unknown-field behavior unchanged."
  - "Require explicit client opt-in to Stripe API version 2026-05-27.dahlia; keep the package default at 2026-03-25.dahlia."
  - "Document API request response availability only; make no webhook event payload availability claim."
requirements-completed: [DRIFT-02, DRIFT-03, DRIFT-04]
coverage:
  - id: D1
    description: Invoice decoding and retrieval expose amount_paid_off_stripe as an integer while preserving amount_paid and unknown response keys; omission and null decode to nil.
    requirement: DRIFT-02
    verification:
      - kind: unit
        ref: test/lattice_stripe/invoice_test.exs#maps amount_paid_off_stripe while preserving amount_paid and unknown fields
        status: pass
      - kind: unit
        ref: test/lattice_stripe/invoice_test.exs#amount_paid_off_stripe is nil when omitted or explicitly null
        status: pass
      - kind: unit
        ref: test/lattice_stripe/invoice_test.exs#retrieve/3 retrieves off-Stripe payment amount with the explicitly selected API version
        status: pass
    human_judgment: false
  - id: D2
    description: Public Invoice API lock records only the additive amount_paid_off_stripe field.
    requirement: DRIFT-03
    verification:
      - kind: other
        ref: mix lattice_stripe.api_surface --check (3464 entries; passing)
        status: pass
    human_judgment: false
  - id: D3
    description: Invoice module docs, invoices guide, and unreleased changelog explain the smallest-unit amount, API-request-only availability from 2026-05-27.dahlia, and unchanged 2026-03-25.dahlia default.
    requirement: DRIFT-04
    verification:
      - kind: other
        ref: mix lattice_stripe.version_prose --check (matches package version 2.2.2)
        status: pass
      - kind: other
        ref: mix docs --warnings-as-errors (completed without warnings)
        status: pass
    human_judgment: true
    rationale: The checks prove the docs render and version prose matches the package, but no executable check asserts the exact minimum-version and response-scope statements across these three prose surfaces.
duration: 9min
completed: 2026-09-24
status: complete
plan_head_before: ed22a7a0400ec0b0eb1b8de3d8561fbb4604f569
commits: 3
---

# Phase 75 Plan 01: Typed Invoice Off-Stripe Payment Summary

**Invoice retrieval now exposes the schema-qualified off-Stripe amount for explicitly versioned API requests, with nullable decoding, preserved unknown fields, and reconciliation guidance.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-09-24T12:20:13Z
- **Completed:** 2026-09-24T12:29:32Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added optional `Invoice.amount_paid_off_stripe` integer decoding without changing `amount_paid` or `extra` behavior.
- Proved the field through `Invoice.retrieve/3` using a client override of `2026-05-27.dahlia`; the schema-derived test records GA commit `c8faccbde66b784ea916d3c28f5790d7a9c9aee2` and pointer `/components/schemas/invoice/properties/amount_paid_off_stripe`.
- Documented smallest-currency-unit reconciliation use, API-request-only availability, and the unchanged `2026-03-25.dahlia` default.
- Added exactly one public API snapshot entry and confirmed the final lock contains 3464 entries.

## Task Commits

1. **Task 1 RED tests:** `e043868` (`test(75-01): add failing off-Stripe invoice amount tests`)
2. **Task 1 implementation:** `50bcdef` (`feat(75-01): expose off-Stripe invoice payment amount`)
3. **Task 2 API lock:** `534aacc` (`chore(75-01): lock additive invoice field surface`)

The plan metadata commit includes this summary.

## Files Created/Modified

- `lib/lattice_stripe/invoice.ex` — optional field, integer typespec, decoder assignment, and version/scope documentation.
- `test/lattice_stripe/invoice_test.exs` — schema-derived retrieval, version header, omission/null, existing amount, and `extra` assertions.
- `guides/invoices.md` — API-version opt-in and off-Stripe reconciliation example.
- `CHANGELOG.md` — unreleased adopter-facing API contract note.
- `priv/api/current.txt` — one additive Invoice field entry.

## Decisions Made

- Followed the evidence-qualified property at the pinned GA OpenAPI commit and exact JSON Pointer; the fixture is schema-derived, not a live Stripe capture.
- Kept the default API version unchanged and limited the availability claim to API request responses.
- Treated the optional public struct field as an additive surface change, consistent with `guides/api_stability.md`; no release manifest was changed.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The first focused test invocation found dependencies were not fetched. `mix deps.get` initially could not persist the global Hex cache due to filesystem permissions; rerunning with `HEX_HOME=/private/tmp/lattice-stripe-hex` fetched the already-locked dependencies successfully. No dependency declarations or lockfiles changed.
- The first draft of the RED tests failed at compile time because Elixir rejects struct patterns for a not-yet-added field. The assertions were adjusted to use `Map.get/2` for the RED run, then changed to direct field assertions after the decoder implementation; the intentional RED run subsequently failed on the planned amount assertions.

## Verification Results

- `mix test test/lattice_stripe/invoice_test.exs --seed 0` — passed, 76 tests, 0 failures. Re-run after Task 1 commit also passed as the tracer feedback gate.
- `mix lattice_stripe.api_surface --check` — passed, 3464 entries.
- `mix lattice_stripe.version_prose --check` — passed, version prose matches `mix.exs` 2.2.2.
- `mix docs --warnings-as-errors` — passed; documentation generated without warnings.
- Reviewed `priv/api/current.txt` diff — one added `LatticeStripe.Invoice field amount_paid_off_stripe` line, no removals or changed entries.
- Confirmed `lib/lattice_stripe.ex` retains `@stripe_api_version "2026-03-25.dahlia"`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Task 75-01 is complete. Plan 75-02 can add the separately scoped Refund attribution fields and must re-read shared files before editing them.

---
*Phase: 75-typed-contract-updates*
*Completed: 2026-09-24*

## Self-Check: PASSED

- All five implementation output files and this SUMMARY.md exist.
- Task commits `e043868`, `50bcdef`, and `534aacc` exist in the worktree history.
