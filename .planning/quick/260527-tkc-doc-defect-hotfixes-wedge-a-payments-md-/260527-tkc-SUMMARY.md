---
status: complete
quick_id: 260527-tkc
date: 2026-05-28
commit: e24e9a3
---

# Quick Task 260527-tkc: Doc defect hotfixes (Wedge A)

## Done

- **payments.md** — Closed Search example fence; note outside code block.
- **customer-portal.md** — Portal configuration copy references `BillingPortal.Configuration` CRUD; removed Dashboard-only claims.
- **user-flows-and-jtbd.md** — Replaced stale gap list; added Recipes to reading order; refreshed Short Version.
- **docs_truth** — Three regression tests (fence, portal Configuration, JTBD recipes routing).

## Verification

`mix test test/lattice_stripe/docs_truth_test.exs` — 28 tests, 0 failures.

## Commit

`e24e9a3` — fix(docs): Wedge A doc defect hotfixes with docs_truth locks
