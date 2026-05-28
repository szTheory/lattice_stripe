---
status: complete
quick_id: 260527-tp8
date: 2026-05-28
commit: 4c636f4
---

# Quick Task 260527-tp8: Gap 2 narrative polish

## Done

- **subscriptions.md** — `## Product and Price catalog strategy` (setup vs runtime, lookup_key, grandfathering, catalog example).
- **recipes.md** — `## Mandate and SetupAttempt diagnostics` (list attempts, setup_error, Mandate.retrieve).
- **user-flows-and-jtbd.md** — Removed resolved catalog/mandate gap bullets.
- **docs_truth** — Locks for both sections.

## Verification

`mix test test/lattice_stripe/docs_truth_test.exs` — 31 tests, 0 failures.
