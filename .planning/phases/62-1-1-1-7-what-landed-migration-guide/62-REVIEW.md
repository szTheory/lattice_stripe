---
phase: 62-1-1-1-7-what-landed-migration-guide
reviewed: 2026-08-24T16:03:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - guides/upgrading-1-1-to-1-7.md
  - test/lattice_stripe/docs_truth_test.exs
findings:
  critical: 1
  warning: 2
  info: 0
  total: 3
status: issues_found
---

# Phase 62: Code Review Report

**Reviewed:** 2026-08-24T16:03:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

The guide's action-first structure and most historical anchors are present, and the focused
DocsTruth suite passes (57 tests). However, the inventory now instructs adopters to create a
public FileLink as part of submitting dispute evidence. That sequence is incorrect and can
expose sensitive evidence. The semantic contract also does not protect this safety boundary or
the required adjacency of the replay-protection warning.

## Critical Issues

### CR-01 (BLOCKER): Dispute-evidence row tells adopters to publish evidence through FileLink

**File:** `guides/upgrading-1-1-to-1-7.md:115`

**Issue:** `FileLink.create/3` creates a publicly accessible URL; it is not the next step for
submitting dispute evidence. The canonical recipe is `File.create/3` with
`purpose: "dispute_evidence"`, then `Dispute.update_evidence/4`, and finally the explicit,
irreversible `Dispute.submit_evidence/3`. The current row both omits the operation that attaches
the uploaded file to the dispute and encourages creating a shareable link for potentially
sensitive evidence. This is an information-disclosure and incorrect-integration risk.

**Fix:** Split the concerns into separate outcome rows. Route “Upload dispute evidence” to
`File.create/3` followed by `Dispute.update_evidence/4` in Recipes; if FileLink must be included
for the phase inventory, give it its actual job, such as “Create an expiring external link to a
Stripe file,” with `FileLink.create/3` as that row's minimum call. Extend the docs-truth test to
assert the evidence row's safe spine and prevent `FileLink.create/3` from being represented as
the evidence-submission step.

## Warnings

### WR-01 (WARNING): The new semantic contract cannot catch the FileLink/evidence regression

**File:** `test/lattice_stripe/docs_truth_test.exs:1187-1214`

**Issue:** The inventory assertions only require independent substrings for `LatticeStripe.File`,
`LatticeStripe.FileLink`, and other surfaces. They all pass when FileLink is attached to the
wrong job and when the required `Dispute.update_evidence/4` attachment step is absent. The green
test result therefore does not prove the safety-critical consumer contract requested by D-09 and
D-13.

**Fix:** Add a narrow, behavior-oriented assertion for the dispute-evidence row or guide section:
it should contain `File.create/3` and `Dispute.update_evidence/4`, and it should not describe
`FileLink.create/3` as the following evidence-submission operation. Keep FileLink coverage in its
own, correctly named job row.

### WR-02 (WARNING): Replay-protection copy is not kept adjacent to the tolerance escape hatch

**File:** `test/lattice_stripe/docs_truth_test.exs:1174-1178`

**Issue:** The phase acceptance criteria require the production replay-protection warning to stay
adjacent to `tolerance: 0`, but the contract only checks that the warning string exists somewhere
in the guide. A future edit can move it into an unrelated section while retaining all three
before/after counts and still pass, making the test-only escape hatch easier to misuse in
production.

**Fix:** Read the tolerance callout/section as a bounded substring (or assert ordering and a
small maximum distance between the tolerance heading and warning) and require both the
test-only wording and replay-protection warning within that scope. This protects the safety
relationship without snapshotting prose.

---

_Reviewed: 2026-08-24T16:03:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
