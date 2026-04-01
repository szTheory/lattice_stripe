---
phase: 01-transport-client-configuration
plan: 02
subsystem: api
tags: [elixir, jason, json, form-encoding, stripe, uri-encoding]

# Dependency graph
requires:
  - phase: 01-01
    provides: Project scaffold with Mox mock definitions and test infrastructure
provides:
  - LatticeStripe.Json behaviour with encode!/1 and decode!/1 callbacks
  - LatticeStripe.Json.Jason default Jason adapter
  - LatticeStripe.FormEncoder recursive Stripe-compatible form encoder
affects: [01-03, 01-04, 01-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Behaviour + adapter pattern: LatticeStripe.Json defines callbacks, Json.Jason implements them"
    - "Bracket notation form encoding: nested maps become parent[child]=value"
    - "Indexed array encoding: lists become parent[0]=value, parent[N][key]=value for maps"
    - "Literal bracket keys: encode key segments but preserve [ ] characters for Stripe compatibility"

key-files:
  created:
    - lib/lattice_stripe/json.ex
    - lib/lattice_stripe/json/jason.ex
    - lib/lattice_stripe/form_encoder.ex
    - test/lattice_stripe/json_test.exs
    - test/lattice_stripe/form_encoder_test.exs
  modified: []

key-decisions:
  - "Preserve literal brackets in form-encoded keys (not %5B/%5D) for Stripe v1 API compatibility"
  - "Sort encoded pairs alphabetically for deterministic output useful for caching and testing"
  - "Nil values omitted entirely from form encoding (Stripe convention for unset fields)"
  - "Empty string preserved in form encoding (Stripe convention for clearing fields)"

patterns-established:
  - "Pattern: Behaviour + adapter in subdirectory (json.ex + json/jason.ex)"
  - "Pattern: TDD RED/GREEN for pure utility modules"
  - "Pattern: async: true tests for pure functional modules"

requirements-completed: [JSON-01, JSON-02, TRNS-04]

# Metrics
duration: 8min
completed: 2026-04-01
---

# Phase 01 Plan 02: JSON Codec and Form Encoder Summary

**Jason-backed JSON codec behaviour and recursive Stripe bracket-notation form encoder with 23 tests covering all edge cases**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-01T00:45:00Z
- **Completed:** 2026-04-01T00:53:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Expanded `LatticeStripe.Json` behaviour from stub to full implementation with moduledoc and usage example
- Created `LatticeStripe.Json.Jason` default adapter delegating to Jason library
- Created `LatticeStripe.FormEncoder` with recursive bracket-notation encoding compatible with Stripe's v1 API
- 9 JSON tests covering encode/decode, error cases, and Mox-based behaviour swappability
- 14 FormEncoder tests covering flat, nested, arrays, deep nesting, booleans, nil, atoms, special chars

## Task Commits

Each task was committed atomically:

1. **Task 1: JSON codec behaviour and Jason adapter** - `bb63aac` (feat)
2. **Task 2: Recursive Stripe-compatible form encoder** - `2c232e4` (feat)

## Files Created/Modified
- `lib/lattice_stripe/json.ex` - Full JSON codec behaviour with moduledoc and callbacks
- `lib/lattice_stripe/json/jason.ex` - Default Jason adapter implementing the behaviour
- `lib/lattice_stripe/form_encoder.ex` - Recursive encoder: bracket notation, indexed arrays, nil omission
- `test/lattice_stripe/json_test.exs` - 9 tests: encode, decode, error cases, Mox swappability
- `test/lattice_stripe/form_encoder_test.exs` - 14 tests: all edge cases

## Decisions Made

- **Literal brackets in keys:** Stripe's v1 API expects `metadata[key]=value` not `metadata%5Bkey%5D=value`. Only key segments are URL-encoded via `URI.encode_www_form`, brackets are preserved.
- **Alphabetical sort:** Encoded pairs sorted alphabetically for deterministic output. Simplifies test assertions and makes output consistent for caching.
- **Nil omission vs empty string:** Nil values are silently dropped (Stripe convention: omitting a field leaves it unchanged). Empty string is preserved (Stripe convention: `""` clears a field).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed bracket URL-encoding in form-encoded keys**
- **Found during:** Task 2 (FormEncoder implementation), test failure
- **Issue:** `URI.encode_www_form/1` encodes `[` and `]` as `%5B` and `%5D`. Stripe expects literal brackets in key names (e.g., `items[0][price]` not `items%5B0%5D%5Bprice%5D`).
- **Fix:** Added `encode_key/1` private function that splits on brackets, encodes only the non-bracket segments, and rejoins with literal brackets.
- **Files modified:** lib/lattice_stripe/form_encoder.ex
- **Verification:** All 14 form encoder tests pass including array and nested tests
- **Committed in:** 2c232e4 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug)
**Impact on plan:** Fix essential for Stripe API compatibility. No scope creep.

## Issues Encountered
- Dependencies not installed in worktree — ran `mix deps.get` to resolve before tests could compile.

## Known Stubs
None — both modules fully implemented with working code and data flowing to tests.

## Next Phase Readiness
- JSON codec behaviour and Jason adapter ready for use in Client module
- FormEncoder ready for integration into request building pipeline
- No blockers for Plan 03 (Transport behaviour + Finch adapter)

---
*Phase: 01-transport-client-configuration*
*Completed: 2026-04-01*
