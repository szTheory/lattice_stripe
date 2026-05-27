# Phase 57: Payments Guide & Charge Routing - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 57-payments-guide-charge-routing
**Areas discussed:** API example corrections, Charge reconciliation section, Operator guide extensions, docs_truth lock strategy
**Mode:** All areas, research-backed one-shot recommendations (user requested subagent research + coherent package)

---

## API example corrections

| Option | Description | Selected |
|--------|-------------|----------|
| A — Fix 3 blocks only; bullets stay wire strings, no bridge | Smallest diff; latent bullet→case copy-paste trap | |
| B — Atoms in code; wire strings in prose + explicit SDK bridge note | Matches SDK v1.2; two-layer model; Stripe cross-ref friendly | ✓ |
| C — Atoms everywhere including bullet list | Notation purity; fights Stripe docs | |

**User's choice:** Option B (via research synthesis — no manual selection required)
**Notes:** Subagent research compared LatticeStripe atomize_status/1, Stripe official SDKs (wire strings), Elixir OSS patterns, prompts/elixir-opensource-libs-best-practices. Bridge note before L110–116 status machine. Three fixes: confirm case, stream filter, search/3 query string.

---

## Charge reconciliation section

| Option | Description | Selected |
|--------|-------------|----------|
| A — Short routing callout (3–5 bullets + moduledoc link) | Low maintenance; borderline ROUTE-01 | |
| B — Full ## Charge reconciliation (~52–60 lines) after Listing/Searching | Structured routing + one example per verb; closes CHRG-05 | ✓ |
| C — See also bullets only | Fails success criterion #4 | |

**User's choice:** Option B
**Notes:** Placement after PI list/search, before Refunds. PI-first intro + verb table + retrieve/list/search/update/capture examples. Charge.capture labeled legacy; PI.capture cross-linked. Connect depth via link only.

---

## Operator guide extensions

| Option | Description | Selected |
|--------|-------------|----------|
| A — Verb bullets only (update/capture one-liners) | Minimal; stale "no Charge guide" line remains | |
| B — Copy-paste snippets in each operator guide | High discoverability; doc drift + PI-capture footgun risk | |
| C — Cross-link to payments.md#charge-reconciliation + verb bullets | SSOT in payments; Phase 53 spine pattern | ✓ |

**User's choice:** Option C
**Notes:** production-checklist and event-debugging get update/4/capture/4 bullets + anti-patterns; no code fences in operator guides. Replace stale v1.7 routing lines with payments cross-link.

---

## docs_truth lock strategy

| Option | Description | Selected |
|--------|-------------|----------|
| A — Positive-only asserts | Stale+correct can coexist | |
| B — Positive + @stale_payments_api_patterns refute; two tests in describe | Phase 56 template; clear CI signals | ✓ |
| C — Structural regex block parsing | Brittle on editorial refactors | |

**User's choice:** Option B
**Notes:** describe "guides/payments.md" with (1) API correctness test, (2) Charge routing test. Do not lock prose status bullets or webhook event strings. ROUTE-02 operator locks separate when added.

---

## Claude's Discretion

- Exact bridge-note and Charge section editorial polish
- Optional test split if CI triage needs finer signals
- Optional Charge moduledoc pointer to payments guide

## Deferred Ideas

- checkout.md status string bugs
- PaymentIntent.cancel/4 moduledoc cleanup
- JTBD-MAP refresh (Phase 58)
