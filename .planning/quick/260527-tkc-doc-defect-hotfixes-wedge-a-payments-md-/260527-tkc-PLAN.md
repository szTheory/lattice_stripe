# Quick Task 260527-tkc: Doc defect hotfixes (Wedge A)

**Goal:** Fix three adopter-facing doc defects from milestone assessment without API or Hex changes.

## Tasks

1. **payments.md** — Close Search example fence; move Search API note outside code block.
2. **customer-portal.md** — Align portal configuration copy with shipped `BillingPortal.Configuration` CRUD.
3. **user-flows-and-jtbd.md** — Replace stale "Still missing" inventory; add `recipes.md` to reading order; refresh Short Version.
4. **docs_truth** — Regression locks for fence structure, portal Configuration mention, JTBD recipes routing.

## Verify

- `mix test test/lattice_stripe/docs_truth_test.exs`
