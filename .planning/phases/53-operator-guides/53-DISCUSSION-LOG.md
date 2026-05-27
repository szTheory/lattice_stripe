# Phase 53: Operator Guides - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 53-operator-guides
**Areas discussed:** All 5 gray areas (user requested full research-backed auto-resolution)

---

## Guide shape & depth

| Option | Description | Selected |
|--------|-------------|----------|
| A — Short trust-rail (~150–220 each) | Phase 48 sibling pattern; low duplication | Partial |
| B — Medium playbook (~250–350 each) | Substance for evaluators; room for LatticeStripe-specific anchors | ✓ (with A discipline) |
| C — Comprehensive runbook (~450+ each) | One-stop ops bible | |
| D — Checklist index only (~80–120) | Pure cross-links | |

**User's choice:** Auto-resolved after subagent research — **asymmetric trust-rail pair**: checklist ~180–220 lines, event-debugging ~220–280 lines (~400–500 total, not per guide).
**Notes:** Rejects Option C (violates Phase 48 guide-family; creates second source of truth) and Option D (fails JTBD Gap 2 evaluator bar). North star: `webhooks-thin-events.md`.

---

## Production checklist composition

| Option | Description | Selected |
|--------|-------------|----------|
| A — Curated checklist + cross-links only | Zero duplication; risks link farm | |
| B — Consolidated standalone | Self-contained; high drift risk vs 9 existing guides | |
| C — Hybrid spine + inline essentials + deep links | Checklist composes; canonical guides own depth | ✓ |

**User's choice:** Hybrid (C) — inline essentials only for silent launch failures (Client.new!, Finch supervision, Plug order, D-14 rule, request_id, idempotency); 12–16 item quick checklist; 9 phased sections with deep links.
**Notes:** Oban `Ready for Production` and Stripe go-live checklist cited as calibration. AWS Well-Architected "questions + linked depth" pattern.

---

## Event debugging vs existing webhook guides

| Option | Description | Selected |
|--------|-------------|----------|
| A — Troubleshooting index | Link farm to siblings | |
| B — Net-new debugging workflows | Full decision trees inline; duplicates Phase 48 | |
| C — Hybrid symptom spine | Symptom → diagnosis → link to canonical section | ✓ |

**User's choice:** Hybrid symptom spine (~220–280 lines). Build content stays in webhooks.md / webhooks-thin-events.md; diagnose content in event-debugging.md.
**Notes:** Must-add: request_id on fetch failures, replay/CLI footguns, wrong-entry-point, fetch races, telemetry wiring. Must-not-duplicate: thin controller, Ecto idempotency sketch, rate-limit tables.

---

## Discovery wiring & docs-truth contract

| Option | Description | Selected |
|--------|-------------|----------|
| ExDoc top (operator-first) | Both guides before client-configuration | |
| ExDoc webhooks cluster only | Both after webhooks-thin-events | |
| ExDoc hybrid | Checklist after client-configuration; debugging in webhooks cluster | ✓ |
| Docs-truth grep only | Phase 48 pattern | ✓ |
| adoption_contract_test.exs | Phase 51 Tax pattern | |

**User's choice:** Hybrid ExDoc placement; Phase 48 docs-truth pattern (4 new tests + 1 extend); augment README/JTBD (not replace); `~> 1.7` install canary on both new guides only.
**Notes:** No adoption contract — prose guides without new wire-path surface. Phase 54 consumes canaries for lockstep flip.

---

## Charge reconciliation references

| Option | Description | Selected |
|--------|-------------|----------|
| A — No Charge mentions | Zero scope creep | |
| B — Brief production-checklist callout | Support/audit subsection ~8–12 lines | ✓ |
| C — Event-debugging only | charge.* paragraph only | ✓ (partial) |
| D — Both guides teach list/search fully | Maximum discoverability; de facto Charge guide | |

**User's choice:** B + narrow C — ~20 lines total across both guides. Shared PI-first guardrail verbatim. Checklist: support subsection with list/search + eventual-consistency caveat. Event-debugging: charge.* paragraph with retrieve anti-pattern for search on fresh payments.
**Notes:** stripe-node/stripe-ruby pattern: list/search in API ref only; ops docs route, don't teach. Link connect-money-movement for fee reconciliation; don't duplicate.

---

## Claude's Discretion

- Exact docs-truth anchor strings
- ExDoc ordering regression assert (optional)
- webhooks-thin-events forward link to event-debugging (optional)

## Deferred Ideas

- guides/charges.md — future adoption phase if evaluator pull
- Global ~> 1.7 flip — Phase 54
- LiveBook event inspector — polish candidate
- DLQ/worker replay recipes — Accrue territory
