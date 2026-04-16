---
phase: 22-expand-deserialization-status-atomization
fixed_at: 2026-04-16T12:15:00Z
review_path: .planning/phases/22-expand-deserialization-status-atomization/22-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 2
skipped: 2
status: partial
---

# Phase 22: Code Review Fix Report

**Fixed at:** 2026-04-16T12:15:00Z
**Source review:** .planning/phases/22-expand-deserialization-status-atomization/22-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (1 Critical, 3 Warning)
- Fixed: 2
- Skipped: 2

## Fixed Issues

### WR-01: PaymentMethod.stream!/3 error message references wrong function name

**Files modified:** `lib/lattice_stripe/payment_method.ex`
**Commit:** 9bc4e74
**Applied fix:** Changed error message in `stream!/3` from referencing `PaymentMethod.list/3` to `PaymentMethod.stream!/3`, including both the function name and the example call.

### WR-03: Billing.Meter does not set default object value in from_map/1

**Files modified:** `lib/lattice_stripe/billing/meter.ex`
**Commit:** 0384c4e
**Applied fix:** Changed `defstruct` from `:object` (nil default) to `object: "billing.meter"`, and added `|| "billing.meter"` fallback in `from_map/1`. Now consistent with all other resource modules.

## Skipped Issues

### CR-01: CHANGELOG [Unreleased] describes unimplemented features

**File:** `CHANGELOG.md:9-38`
**Reason:** False positive. The reviewer ran before Wave 2 code was merged. All resource modules now have expand guards and status atomizers implemented. The CHANGELOG correctly reflects the shipped code.
**Original issue:** CHANGELOG [Unreleased] section documents expand deserialization and status atomization as completed, but reviewer believed source code had not yet implemented these changes.

### WR-02: Inconsistent nil handling between Capability.status_atom/1 and Meter.status_atom/1

**File:** `lib/lattice_stripe/billing/meter.ex:285` and `lib/lattice_stripe/account/capability.ex:64`
**Reason:** Already resolved in current code. Both `Capability.status_atom(nil)` and `Meter.status_atom(nil)` now return `nil`. The reviewer's observation was based on an earlier code state.
**Original issue:** Reviewer reported `Meter.status_atom(nil)` returned `:unknown` while `Capability.status_atom(nil)` returned `nil`, but current code shows both return `nil`.

---

_Fixed: 2026-04-16T12:15:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
