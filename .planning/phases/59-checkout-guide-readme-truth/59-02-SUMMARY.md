---
phase: 59-checkout-guide-readme-truth
plan: "02"
subsystem: docs-truth
tags: [readme, docs-truth, error-taxonomy, CHECKOUT-03, README-01, README-02, VERIFY-05]
dependency_graph:
  requires:
    - phase: 59-01
      provides: atom-correct checkout.md content to lock
  provides: [readme-error-taxonomy-fix, checkout-docs-truth-locks, readme-docs-truth-locks]
  affects: [README.md, test/lattice_stripe/docs_truth_test.exs]
tech_stack:
  added: []
  patterns: [stale-pattern-refute-loops, per-surface-describe-blocks]
key_files:
  created: []
  modified:
    - README.md
    - test/lattice_stripe/docs_truth_test.exs
decisions:
  - "README keeps teaser shape with 4 example atoms plus link to error-handling guide per D-09–D-11"
  - "Separate describe blocks for checkout.md and README.md per D-12 pattern from Phase 57"
metrics:
  duration: "~5 minutes"
  completed: "2026-05-27"
  tasks_completed: 3
  files_modified: 2
requirements-completed: [README-01, README-02, CHECKOUT-03, VERIFY-05]
---

# Phase 59 Plan 02: README Error Taxonomy & docs_truth Locks Summary

**One-liner:** README error teaser now matches `LatticeStripe.Error` canonical atoms with CI grep locks for checkout guide and README taxonomy drift.

## Task Commits

| Task | Name | Commit |
|------|------|--------|
| 1 | Fix README error taxonomy bullet | 8712ead |
| 2–3 | Add docs_truth locks for checkout.md and README.md | eb87abb |

## Accomplishments

- Replaced stale `:auth_error`/`:server_error` with `:authentication_error`/`:api_error` in README Features §Payments.
- Added inline link to `guides/error-handling.md` for full error type table.
- Added `@stale_checkout_api_patterns` and `describe "guides/checkout.md"` with positive asserts and stale refute loop.
- Added `@stale_readme_error_atoms` and `describe "README.md"` with canonical atom asserts and stale refute loop.
- Full docs_truth suite passes (26 tests, 0 failures).

## Files Modified

- `README.md` — canonical error atom teaser with guide link
- `test/lattice_stripe/docs_truth_test.exs` — checkout and README describe blocks

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `mix test test/lattice_stripe/docs_truth_test.exs` — 26 tests, 0 failures
- `rg -n 'describe "guides/checkout.md"|describe "README.md"' test/lattice_stripe/docs_truth_test.exs` — found

---
*Phase: 59-checkout-guide-readme-truth*
*Completed: 2026-05-27*
