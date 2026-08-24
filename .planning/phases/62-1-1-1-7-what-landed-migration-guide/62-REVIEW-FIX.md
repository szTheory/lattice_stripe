---
phase: 62-1-1-1-7-what-landed-migration-guide
fixed_at: 2026-08-24T20:13:19Z
review_path: .planning/phases/62-1-1-1-7-what-landed-migration-guide/62-REVIEW.md
iteration: 3
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 62: Code Review Fix Report

**Fixed at:** 2026-08-24T20:13:19Z  
**Source review:** `.planning/phases/62-1-1-1-7-what-landed-migration-guide/62-REVIEW.md`  
**Iterations:** 1–3

**Summary:**

- Findings resolved across all review iterations: 5
- Fixed: 5
- Skipped: 0

## Fixed Issues

### CR-01: Dispute-evidence row told adopters to publish evidence through FileLink

**Files modified:** `guides/upgrading-1-1-to-1-7.md`, `test/lattice_stripe/docs_truth_test.exs`  
**Commit:** `5e1c4f8`  
**Applied fix:** Replaced the unsafe FileLink step with the evidence spine: `File.create/3` using `purpose: "dispute_evidence"`, `Dispute.update_evidence/4`, then explicit `Dispute.submit_evidence/3`. Added a separate FileLink row for intentionally public, expiring file links.

### WR-01 (iteration 1): The semantic contract could not catch the FileLink/evidence regression

**Files modified:** `test/lattice_stripe/docs_truth_test.exs`  
**Commit:** `5e1c4f8`  
**Applied fix:** Added narrow row-level assertions for the evidence workflow and the separate FileLink job, including a negative assertion that FileLink is not an evidence-submission operation.

### WR-02 (iteration 1): Replay-protection copy was not kept adjacent to the tolerance escape hatch

**Files modified:** `test/lattice_stripe/docs_truth_test.exs`  
**Commit:** `5e1c4f8`  
**Applied fix:** Added behavior-, test-scope-, and production-safety assertions for the tolerance callout without snapshotting prose.

### WR-01 (iteration 2): The tolerance safety contract did not enforce adjacency

**Files modified:** `test/lattice_stripe/docs_truth_test.exs`  
**Commit:** `c1e1409`  
**Applied fix:** Bounded the tolerance contract from its exact breaking-change heading to `### If none apply`, so the observed behavior, test-only scope, and replay-protection warning must remain together in the same local callout while its prose remains flexible.

### WR-01 (iteration 3): Finite-status migration inventory omitted shipped 1.7 resources

**Files modified:** `guides/upgrading-1-1-to-1-7.md`, `test/lattice_stripe/docs_truth_test.exs`  
**Commit:** `6745e38`  
**Applied fix:** Added SubscriptionSchedule, BankAccount, Billing.Meter, and Account.Capability to the finite-status atomization resource list and the existing guide-inventory anchor lock.

## Verification

- `mix format test/lattice_stripe/docs_truth_test.exs` — passed
- `mix test test/lattice_stripe/docs_truth_test.exs` — passed (57 tests, 0 failures)

---

_Fixed: 2026-08-24T20:13:19Z_  
_Fixer: the agent (gsd-code-fixer)_  
_Iterations: 1–3_
