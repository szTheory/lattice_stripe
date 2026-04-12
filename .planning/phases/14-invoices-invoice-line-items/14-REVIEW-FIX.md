---
phase: 14-invoices-invoice-line-items
fixed_at: 2026-04-12T00:00:00Z
review_path: .planning/phases/14-invoices-invoice-line-items/14-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 14: Code Review Fix Report

**Fixed at:** 2026-04-12
**Source review:** .planning/phases/14-invoices-invoice-line-items/14-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (WR-01 through WR-04)
- Fixed: 4
- Skipped: 0

## Fixed Issues

### WR-01: Proration guard bypassed when `proration_behavior` is nested in `subscription_details`

**Files modified:** `lib/lattice_stripe/billing/guards.ex`
**Commit:** 0628bbd
**Applied fix:** already_fixed — This fix was applied in a prior commit (0628bbd) during the verification cycle, before this fixer run. The `has_proration_behavior?/1` private function is present in `guards.ex` and correctly checks both the top-level `"proration_behavior"` key and the nested `params["subscription_details"]["proration_behavior"]` path using `get_in`-style access. The `@doc` string was also updated to document both accepted locations.

---

### WR-02: `parse_lines/1` silently drops unexpected map shapes

**Files modified:** `lib/lattice_stripe/invoice.ex`
**Commit:** 97bae75
**Applied fix:** Changed the catch-all `defp parse_lines(_), do: nil` to `defp parse_lines(other), do: other`. This preserves unrecognised map shapes (e.g. an expanded lines object or a future API shape) as raw data rather than silently discarding them. Callers can now distinguish between "field absent" (`nil`) and "field present but unrecognised" (raw map), consistent with the codebase's `extra` map pattern.

---

### WR-03: `id_segment?/1` in telemetry path parser missing `ii_` and `il_` prefixes

**Files modified:** `lib/lattice_stripe/telemetry.ex`
**Commit:** c464feb
**Applied fix:** Added `ii_` (InvoiceItem IDs) and `il_` (Invoice LineItem IDs) to the `known_prefixes` sigil in `id_segment?/1`. Paths like `/v1/invoiceitems/ii_abc123` now hit the fast-path prefix check instead of falling through to the length-based heuristic, preventing misclassification of short IDs.

---

### WR-04: Finch version pinned below CLAUDE.md recommendation

**Files modified:** `mix.exs`
**Commit:** 4a084e7
**Applied fix:** Updated `{:finch, "~> 0.19"}` to `{:finch, "~> 0.21"}` in the deps list, aligning the declared constraint with the `~> 0.21` floor specified in CLAUDE.md. Fresh installs will no longer silently resolve to Finch 0.19.x or 0.20.x.

---

_Fixed: 2026-04-12_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
