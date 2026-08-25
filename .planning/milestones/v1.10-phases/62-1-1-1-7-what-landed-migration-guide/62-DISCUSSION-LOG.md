# Phase 62: "1.1 → 1.7 What Landed" Migration Guide - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-24
**Phase:** 62-"1.1 → 1.7 What Landed" Migration Guide
**Areas discussed:** Historical version boundary, Inventory and examples, Drift protection

---

## Historical Version Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Strict historical guide with thin 2.x handoff | Remove post-1.7 features from the historical leg; keep a generic pointer to the 2.0 migration/current docs. | ✓ |
| Labelled after-1.7 addendum | Keep later features in a clearly separated addendum on the same page. | |
| Rolling 1.1-to-current guide | Replace the fixed historical page with an always-current migration guide. | |

**User's choice:** The user selected all areas for expert analysis and delegated the final recommendation so the result would be coherent and require no further decision-making.

**Notes:** Repository history proves `v1.7.13` still required `:finch`; the default pool arrived in Phase 61 and shipped with 2.0. The strict historical boundary is the only option that satisfies DOC-01 without misleading an adopter using the displayed `~> 1.7` dependency.

---

## Inventory and Examples

| Option | Description | Selected |
|--------|-------------|----------|
| Keep family-first catalogue | Preserve the current organization and make only local corrections. | |
| Action-first checklist plus complete family catalogue | Put required migration actions first, then a JTBD-labelled inventory grouped by familiar ExDoc families, with a version appendix. | ✓ |
| Version-by-version timeline | Make release chronology the primary guide structure. | |

**User's choice:** Delegated to the agent after requesting research across Elixir, Phoenix, Ecto, Stripe SDKs, successful libraries, JTBD, UX, accessibility, and developer-experience lenses.

**Notes:** The selected structure matches the adopter's risk-reduction job and retains the library's existing navigation vocabulary. Completeness includes File/FileLink, Mandate, and SetupAttempt, which shipped in the interval but currently appear only in the appendix.

---

## Drift Protection

| Option | Description | Selected |
|--------|-------------|----------|
| Mix CI and ExDoc warnings only | Rely on current build, link/reference, test, and lint gates. | |
| Narrow semantic docs-truth contract | Add focused structural and semantic assertions in the existing required docs-truth suite. | ✓ |
| Git-tag-derived structural contract | Derive historical availability from tags or a maintained capability manifest in CI. | |
| Rendered snapshots and external-link checks | Snapshot generated docs and/or block on network link validation. | |

**User's choice:** Delegated to the agent as part of the one-shot recommendation.

**Notes:** `mix docs --warnings-as-errors` cannot detect historically false prose; the existing Finch error proves the false-negative. A compact semantic contract fits the repository's testing philosophy without freezing editorial wording or introducing flaky infrastructure.

---

## the agent's Discretion

- Exact heading and microcopy choices within the action-first structure.
- Exact inventory-table phrasing and representative snippets.
- Exact semantic assertion anchors, constrained to named user-harm regressions.

## Deferred Ideas

None. Rolling migration documentation, rendered snapshots, and blocking external-link checks were considered and rejected for this bounded phase.
