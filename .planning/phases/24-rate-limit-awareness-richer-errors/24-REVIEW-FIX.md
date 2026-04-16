---
phase: 24-rate-limit-awareness-richer-errors
fixed_at: 2026-04-16T00:00:00Z
review_path: .planning/phases/24-rate-limit-awareness-richer-errors/24-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 24: Code Review Fix Report

**Fixed at:** 2026-04-16T00:00:00Z
**Source review:** .planning/phases/24-rate-limit-awareness-richer-errors/24-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3
- Fixed: 3
- Skipped: 0

## Fixed Issues

### WR-01: `parse_type/1` called twice on same input in `from_response/3`

**Files modified:** `lib/lattice_stripe/error.ex`
**Commit:** f636a27
**Applied fix:** Bound the result of `parse_type(type_str)` to a local variable `parsed_type` before the struct literal, then used `parsed_type` for both the `type:` field and the `maybe_enrich_message/3` call. This eliminates the duplicate function-head walk and ensures both call sites can never diverge.

---

### WR-02: `acct_` prefix missing from `id_segment?/1` known prefixes

**Files modified:** `lib/lattice_stripe/telemetry.ex`
**Commit:** ea35254
**Applied fix:** Expanded the `known_prefixes` sigil from a single-line list to a multi-line list, adding `acct_` (Connect account IDs), `tr_` (Transfer), `po_` (Payout), `promo_` (PromotionCode), `si_` (SubscriptionItem), and `txn_` (Transaction) alongside the existing prefixes.

---

### WR-03: `build_stop_metadata` for success response includes `rate_limited_reason` unconditionally

**Files modified:** `lib/lattice_stripe/telemetry.ex`
**Commit:** 07153d2
**Applied fix:** Added an inline comment above the `rate_limited_reason:` key in the `{:ok, %Response{}}` clause of `build_stop_metadata/5` explaining that the key is intentionally always present (with `nil` value on non-429 responses) so downstream handlers can use `Map.get/2` without `Map.has_key?/2` guards.

---

_Fixed: 2026-04-16T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
