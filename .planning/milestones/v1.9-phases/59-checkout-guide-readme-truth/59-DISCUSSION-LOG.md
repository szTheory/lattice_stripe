# Phase 59: Checkout Guide & README Truth - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 59-Checkout Guide & README Truth
**Areas discussed:** Status callout scope, Callout placement, README error taxonomy, docs_truth lock structure

---

## Status callout scope

| Option | Description | Selected |
|--------|-------------|----------|
| payment_status only | Callout documents `:paid`, `:unpaid`, `:no_payment_required` only | |
| Both fields, one callout | Single callout covers `payment_status` and `status` atoms + wire-string note | ✓ |
| Full dual callout + mapping tables | Separate callouts with wire→atom mapping tables | |

**User's choice:** Both fields, one callout (research-backed recommendation; user delegated via "discuss all" + "create context")
**Notes:** Mirrors Stripe's separate lifecycle vs payment-outcome concepts while preserving Phase 57 single-callout shape. No mapping tables — six trivial 1:1 wire→atom pairs add noise.

---

## Callout placement

| Option | Description | Selected |
|--------|-------------|----------|
| Near retrieve (L164–172) | Teach when fields first appear | |
| Before stream filter (L199–208) | Teach at first status comparison / copy-paste bug site | ✓ |
| Both locations | Full callout at retrieve + stream | |

**User's choice:** Before stream filter under `### Auto-Pagination with Streams`
**Notes:** payments.md precedent places callout at first comparison, not first field print. Skimmers jumping to reconciliation miss retrieve-only callouts. Optional one-line cross-link at retrieve.

---

## README error taxonomy breadth

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal fix | Swap stale atoms; keep "and more" | |
| Full canonical list | All 7 types from error.ex | |
| Minimal fix + link | Fix atoms + pointer to error-handling.md | ✓ |

**User's choice:** Minimal fix + link to `guides/error-handling.md`
**Notes:** README is marketing/discovery, not reference. Full enumeration brittle and duplicates error-handling.md. Exact line specified in CONTEXT.md D-11.

---

## docs_truth lock structure

| Option | Description | Selected |
|--------|-------------|----------|
| Mirror payments.md | Dedicated `describe "guides/checkout.md"` + `describe "README.md"` | ✓ |
| Extend existing describes | Add to cross-link / install tests | |
| Consolidated describe | Single "canonical guide + README truth" block | |

**User's choice:** Mirror payments.md (Phase 57 VERIFY-04 precedent)
**Notes:** Per-surface failure signals; cross-link test stays routing-only. Scales cleanly when Phase 60 CI-01 enables docs_truth on guide-only PRs.

---

## Claude's Discretion

- Exact callout prose and wire-string bullet formatting
- Whether retrieve-section cross-link ships
- Optional stale-pattern expansion beyond `"paid"`

## Deferred Ideas

- Output-comment wire-string polish in guides
- JTBD-MAP upgrade (Phase 60)
- CI paths-ignore fix (Phase 60)
