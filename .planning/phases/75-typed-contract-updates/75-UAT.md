---
status: complete
phase: 75-typed-contract-updates
source: [75-01-SUMMARY.md, 75-02-SUMMARY.md]
started: 2026-09-24T17:44:48Z
updated: 2026-09-24T19:18:26Z
---

## Current Test

[testing complete]

## Tests

<!-- Summary-level confirmation omitted: all scoped deliverables have passing automated evidence below. -->

### 1. Invoice typed field decoding and retrieval
expected: Invoice amount_paid_off_stripe is optional and nullable, retrieval honors the explicitly selected API version, and existing amount_paid and unknown response keys remain available.
result: pass
source: automated

### 2. Invoice additive API lock
expected: Public API lock records the additive amount_paid_off_stripe field.
result: pass
source: automated

### 3. Invoice version and response-scope documentation
expected: Invoice docs, guide, and changelog state smallest-unit semantics, API-request-only availability from 2026-05-27.dahlia, and unchanged 2026-03-25.dahlia default.
result: pass
source: automated

### 4. Refund typed field decoding and retrieval
expected: Refund customer, customer_account, and payment_method support the documented ID, null, omitted, expanded, and deleted_customer shapes while retaining unknown fields and existing behavior.
result: pass
source: automated

### 5. Refund additive API lock
expected: Public API lock records only the three additive Refund fields alongside the Invoice addition.
result: pass
source: automated

### 6. Refund version and response-scope documentation
expected: Refund docs and changelog state adopter purpose, 2026-07-29.dahlia minimum, Refund endpoint response scope, event-availability caveat, and unchanged 2026-03-25.dahlia package default.
result: pass
source: automated

## Summary

total: 6
passed: 6
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

None.
