---
status: complete
phase: 77-adopter-edge-profiles-and-ci
source: 77-01-SUMMARY.md, 77-02-SUMMARY.md, 77-03-SUMMARY.md
started: 2026-09-25T01:14:10Z
updated: 2026-09-25T01:14:10Z
---

## Current Test

[testing complete]

## Tests

### 1. Versioned typed Invoice retrieval
expected: Versioned Invoice retrieval exposes amount_paid_off_stripe through the adopter transport.
result: pass
source: automated
coverage_id: D1

### 2. Structured Invoice error
expected: A synthetic invalid Invoice response returns the stable structured SDK error.
result: pass
source: automated
coverage_id: D2

### 3. Required Phoenix adopter CI lane
expected: The adopter CI job resolves the nested lockfile, runs the full suite on Elixir 1.19 / OTP 28, and is required by ci-gate.
result: pass
source: automated
coverage_id: D3

### 4. Adopter README profile guidance
expected: README names all three profile selectors, the full suite command, and the synthetic evidence boundary.
result: pass
source: automated
coverage_id: D4

### 5. Bounded usage-summary stream
expected: The usage summary stream follows exactly two pages, preserves customer and UTC-day filters, and yields three typed summaries in order.
result: pass
source: automated
coverage_id: D1

### 6. Meter-event idempotency contract
expected: Meter event creation sends a stable body identifier separately from the HTTP idempotency key and decodes a typed response.
result: pass
source: automated
coverage_id: D2

### 7. Complete nested adopter suite
expected: The complete nested Phoenix adopter suite, including prior B2B and core cases, passes without live Stripe.
result: pass
source: automated
coverage_id: D3

### 8. Per-request Connect account routing
expected: Two connected-account Balance reads on one Client use only the account selected for each request and decode to typed Balance values.
result: pass
source: automated
coverage_id: D1

### 9. Explicit nil account suppression
expected: Explicit per-request nil omits the client account header, and a following request on the same Client uses only its selected account.
result: pass
source: automated
coverage_id: D2

### 10. Complete synthetic adopter CI command
expected: The complete synthetic adopter suite, including core/webhook, B2B, usage, and Connect tests, passes under the CI warnings-as-errors command.
result: pass
source: automated
coverage_id: D3

## Summary

total: 10
passed: 10
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

None.
