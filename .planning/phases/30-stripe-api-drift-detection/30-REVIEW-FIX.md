---
phase: 30-stripe-api-drift-detection
fixed_at: 2026-04-16T00:00:00Z
review_path: .planning/phases/30-stripe-api-drift-detection/30-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 30: Code Review Fix Report

**Fixed at:** 2026-04-16
**Source review:** .planning/phases/30-stripe-api-drift-detection/30-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3 (WR-01, WR-02, WR-03)
- Fixed: 3
- Skipped: 0

## Fixed Issues

### WR-01: `new_resources` list silently prints but exits 0 — CI misses new Stripe resources

**Files modified:** `lib/mix/tasks/lattice_stripe.check_drift.ex`
**Commit:** bfc731e
**Applied fix:** Added `System.halt(1)` after printing the format_report when `new_resources` is non-empty in the `drift_count == 0` branch. New Stripe resources that have no SDK coverage are now treated as drift and trigger the CI issue workflow.

---

### WR-02: `known_fields_for/1` reads source files by compile-time path — silently returns empty set in release/CI builds

**Files modified:** `lib/lattice_stripe/drift.ex`
**Commit:** 34cc82d
**Applied fix:** Extracted a private `resolve_source_path/1` helper. It first checks whether the compile-time absolute path still exists; if not, it derives a fallback path by stripping the leading `/` from the compile-time path and re-joining it under the current project root (via `Mix.Project.build_path/0`). `known_fields_for/1` now delegates path resolution to this helper instead of using the charlist directly.

---

### WR-03: `throw/catch` used for control flow in `fetch_spec/0` — unconventional and potentially masks errors

**Files modified:** `lib/lattice_stripe/drift.ex`
**Commit:** a306d2b
**Applied fix:** Replaced the `throw/catch` escape hatch with idiomatic `with` composition. Extracted `start_finch/1` (returns `:ok` or `{:error, {:finch_start_failed, reason}}`) and `do_request/1` (returns `{:ok, response}` or `{:error, reason}`). `fetch_spec/0` is now a clean `with` chain that propagates `{:error, reason}` tuples normally through the call stack.

---

_Fixed: 2026-04-16_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
