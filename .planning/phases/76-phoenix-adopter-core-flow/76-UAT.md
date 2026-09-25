---
status: complete
phase: 76-phoenix-adopter-core-flow
source: [76-01-SUMMARY.md]
started: 2026-09-24T20:05:00Z
updated: 2026-09-25T01:06:49.569Z
---

## Current Test

[testing complete]

## Tests

### 1. A Phoenix adopter uses the checked-out SDK through a separate path dependency and starts its Endpoint with the SDK's single Finch pool.
expected: A Phoenix host boots from its separate path dependency and the SDK starts exactly one Finch pool.
result: pass
source: automated
coverage_id: ADOPT-01
verification: `cd test_apps/phoenix_adopter && HEX_HOME=/tmp/lattice_stripe_phase76_hex mix test` — 9 tests, 0 failures (rerun 2026-09-25 during this verification)

### 2. A synthetic subscription Checkout returns a typed Session and the Phoenix webhook Plug dispatches a valid signed Event while rejecting a modified body.
expected: The host flow returns a typed Checkout Session, dispatches a valid signed Event, and rejects a tampered webhook body before handler dispatch.
result: pass
source: automated
coverage_id: ADOPT-02
verification: `cd test_apps/phoenix_adopter && HEX_HOME=/tmp/lattice_stripe_phase76_hex mix test` — 9 tests, 0 failures (rerun 2026-09-25 during this verification)

## Summary

total: 2
passed: 2
issues: 0
pending: 0
skipped: 0

## Gaps

[none]
