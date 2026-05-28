---
status: complete
quick_id: 260527-tm1
date: 2026-05-28
commit: b5a78dc
---

# Quick Task 260527-tm1: Wedge B disputes/files narrative

## Done

- **recipes.md** — Full spine: retrieve → `File.create` (`dispute_evidence`) → `update_evidence` → `submit_evidence`; irreversibility and webhook events; intro routing bullet.
- **user-flows-and-jtbd.md** — Narrative gap line updated (File spine documented).
- **docs_truth** — `describe "guides/recipes.md"` locks dispute/File workflow strings.

## Verification

`mix test test/lattice_stripe/docs_truth_test.exs` — 29 tests, 0 failures.
