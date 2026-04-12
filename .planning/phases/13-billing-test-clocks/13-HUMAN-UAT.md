---
status: partial
phase: 13-billing-test-clocks
source: [13-VERIFICATION.md]
started: 2026-04-11T22:00:00Z
updated: 2026-04-11T22:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Real Stripe round-trip
expected: Run `mix test --include real_stripe` with STRIPE_TEST_SECRET_KEY env set. Create, advance 30 days, poll until ready, delete — passes within 120s.
result: [pending]

### 2. stripe-mock integration
expected: Run `docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest` then `mix test --include integration`. CRUD round-trip passes against stripe-mock.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
