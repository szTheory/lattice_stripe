# Phase 52: Charge Surface Expansion - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 52-charge-surface-expansion
**Areas discussed:** PI-first moduledoc rewrite, canonical sibling template, D-06 test contract evolution, Testing helper & integration depth
**Mode:** All areas auto-researched via subagents + prompts/ research synthesis; user requested decisive recommendations without further Q&A

---

## PI-first moduledoc rewrite

| Option | Description | Selected |
|--------|-------------|----------|
| Keep "retrieve-only" headline | Preserve Phase 18 wording literally | |
| Generic sibling doc only | "Operations on Stripe Charge objects" like Customer/Refund | |
| **PI-first result-record module** | Object-first, PI-first, ops-second; D-06 as omitted initiation | ✓ |
| Negative inventory lead | Lead with "no create, no cancel, no …" | |
| Full stripity_stripe parity doc | Document create even though absent | |

**User's choice:** PI-first result-record module (D-01) — research-backed default; user asked for all areas researched and decided coherently.

**Notes:** Reframe D-06 from "retrieve-only module" to "no payment initiation surface." Remove stale "Only three public functions" inventory. Keep Connect reconciliation section unchanged.

---

## Canonical sibling template

| Option | Description | Selected |
|--------|-------------|----------|
| **PaymentIntent mechanical template** | Full verb overlap: list/search/stream/capture/update | ✓ |
| Dispute template | Support workflow tone but no search | partial (tone only) |
| Refund template | Metadata constraint docs only | partial (update docs only) |
| Hybrid PI + Refund + existing Charge | Mechanical PI + update constraints + retrieve guards | ✓ (synthesis) |

**User's choice:** PaymentIntent mechanical template with Refund-style update constraint docs and existing Charge retrieve guards (D-02).

**Notes:** Dispute rejected as primary template (no search). Do not add nested refund helpers or third pagination API.

---

## D-06 test contract evolution

| Option | Description | Selected |
|--------|-------------|----------|
| In-place flip | Change refute→assert in existing D-06 describe | |
| **TaxId dual-path surface guard** | Positive expanded exports + negative create/cancel only | ✓ |
| PaymentIntent-style Mox only | Delete module surface block entirely | |
| Negative-only retention | Keep refutes on new functions | |
| Full Tax adoption contract file | Separate adoption_contract_test.exs like Phase 51 | |

**User's choice:** TaxId-style surface guard in charge_test.exs + Mox wire tests under test/lattice_stripe/charge/ + docs-truth grep; no separate adoption contract file (D-03).

**Notes:** Delete entire "D-06 retrieve-only" describe (8 tests). CHRG-05 four-surface = moduledoc + code + tests + docs-truth, not Tax trilogy.

---

## Testing helper & integration depth

| Option | Description | Selected |
|--------|-------------|----------|
| Add Testing.charge/1 now | Symmetric with Testing.dispute/1 | |
| **Defer Testing.charge/1** | Internal fixtures suffice; no testing.md workflow | ✓ |
| Mox-at-Transport primary | test/lattice_stripe/charge/ wire tests | ✓ |
| Extend stripe-mock integration | Shape-first smokes for new endpoints | ✓ (recommended polish) |
| Full Tax adoption trilogy | adoption contract + guide + discovery ladder | |

**User's choice:** Mox primary + optional stripe-mock smokes; defer Testing.charge/1 (D-04).

**Notes:** Aligns with Dispute wire-test model, not Tax family closure. Avoid public API creep.

---

## Claude's Discretion

- Mox test file layout under test/lattice_stripe/charge/
- Exact docs-truth grep anchor strings
- Search eventual-consistency / India availability moduledoc wording

## Deferred Ideas

- Testing.charge/1 until guides/testing.md documents Charge workflows
- guides/charges.md canonical guide
- Tax-style adoption_contract_test.exs without a canonical guide
