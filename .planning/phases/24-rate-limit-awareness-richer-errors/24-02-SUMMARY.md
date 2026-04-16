---
phase: 24-rate-limit-awareness-richer-errors
plan: "02"
subsystem: error
tags: [dx, error-handling, fuzzy-matching]
dependency_graph:
  requires: []
  provides: [fuzzy-param-suggestion]
  affects: [lib/lattice_stripe/error.ex, test/lattice_stripe/error_test.exs]
tech_stack:
  added: []
  patterns: [compile-time struct key aggregation, String.jaro_distance fuzzy matching]
key_files:
  created: []
  modified:
    - lib/lattice_stripe/error.ex
    - test/lattice_stripe/error_test.exs
decisions:
  - "Use struct keys (not @known_fields) as compile-time candidate pool — struct keys are accessible cross-module at runtime; @known_fields is compile-time only within its defining module"
  - "0.8 Jaro distance threshold + 4-char minimum length — avoids noisy short-name matches while catching real typos like payment_method_type -> payment_method_types (0.983 distance)"
  - "Suggestion appended with '; did you mean :field_name?' format — semicolon separator preserves original Stripe message intact for existing pattern matches"
metrics:
  duration_minutes: 12
  completed_date: "2026-04-16"
  tasks_completed: 2
  files_changed: 2
---

# Phase 24 Plan 02: Fuzzy Param Suggestion for invalid_request_error Summary

**One-liner:** Client-side fuzzy param name suggestions appended to `invalid_request_error` messages using `String.jaro_distance/2` against a compile-time aggregate of all resource module struct keys.

## What Was Built

`Error.from_response/3` now enriches `:invalid_request_error` messages with a "did you mean" suggestion when the `param` field is a near-miss of a known Stripe field name.

Example: A developer who passes `payment_method_type` instead of `payment_method_types` receives:
```
"No such parameter: payment_method_type; did you mean :payment_method_types?"
```

### Implementation Details

**`maybe_enrich_message/3`** — guarded private function that only fires for `:invalid_request_error` with a non-nil binary param. Falls through silently for all other error types.

**`suggest_param/1`** — calls `extract_leaf_param/1` to strip bracket notation, then filters out response-only fields, and uses `Enum.max_by/3` with `String.jaro_distance/2` to find the best candidate. Returns `nil` if the best candidate is below 0.8 or the leaf is under 4 characters.

**`extract_leaf_param/1`** — extracts the leaf key from bracket notation params (`card[nubmer]` → `nubmer`).

**`@all_resource_modules`** — compile-time list of 34 resource modules. References all modules in ObjectTypes plus extras (AccountLink, Invoice.LineItem, LoginLink, Billing.MeterEvent, Billing.MeterEventAdjustment).

**`@all_resource_known_fields`** — computed at compile time from struct keys of all resource modules. Struct keys mirror `@known_fields` in each module. `Enum.uniq/1` applied to deduplicate shared field names (e.g., `id`, `metadata`).

**`@response_only_fields`** — guards against suggesting `id`, `object`, `created`, `livemode`, `url`, `deleted`, `has_more`, `total_count`, `next_page`, `previous_page`, `data` — fields Stripe returns but callers never send.

## Files Modified

- `lib/lattice_stripe/error.ex` — Added `maybe_enrich_message/3`, `suggest_param/1`, `extract_leaf_param/1`, `all_known_fields/0`, `@all_resource_modules`, `@all_resource_known_fields`, `@response_only_fields`. Modified `from_response/3` message field. No struct changes.
- `test/lattice_stripe/error_test.exs` — Added `describe "fuzzy param suggestions"` block with 8 new tests.

## Test Results

45 tests, 0 failures (37 existing + 8 new).

Tests cover: near-miss match, wrong error type (card_error, rate_limit_error), nil param, unrelated param, short param < 4 chars, bracket notation, and field preservation.

## Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add fuzzy param suggestion to Error.from_response/3 | 3e5b693 | lib/lattice_stripe/error.ex |
| 2 | Add error_test.exs tests for fuzzy param suggestion | 9dcc09a | test/lattice_stripe/error_test.exs |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None. The fuzzy matching uses a closed candidate set (struct keys from known resource modules). No external input is used as dictionary keys. The only external input (`param`) flows through `String.jaro_distance/2` which is O(n*m) and bounded by the short length of Stripe param strings.

## Self-Check: PASSED

- `lib/lattice_stripe/error.ex` — exists with all required functions
- `test/lattice_stripe/error_test.exs` — exists with 8 new test cases
- Commit 3e5b693 — verified in git log
- Commit 9dcc09a — verified in git log
- `mix test test/lattice_stripe/error_test.exs` — 45 tests, 0 failures
