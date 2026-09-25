# Roadmap: LatticeStripe

## Milestones

- ✅ **v1.0 — Foundation + Billing + Connect + 1.0 Release** — shipped 2026-04-13 — [archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 — Accrue unblockers** — shipped 2026-04-14
- ✅ **v1.2 — Production Hardening & DX** — shipped 2026-04-17 — [archive](milestones/v1.2-ROADMAP.md)
- ✅ **v1.3 — Production Coverage & Adoption Polish** — shipped 2026-05-25 — [archive](milestones/v1.3-ROADMAP.md)
- ✅ **v1.4 — Adoption Closure** — shipped 2026-05-27 — [archive](milestones/v1.4-ROADMAP.md)
- ✅ **v1.5 — Thin-Event Webhooks** — shipped 2026-05-27 — [archive](milestones/v1.5-ROADMAP.md)
- ✅ **v1.6 — Tax** — shipped 2026-05-27 — [archive](milestones/v1.6-ROADMAP.md)
- ✅ **v1.7 — Polish & Operator** — shipped 2026-05-27 — [archive](milestones/v1.7-ROADMAP.md)
- ✅ **v1.8 — Adopter Truth & Doc Routing Polish** — shipped 2026-05-27 — [archive](milestones/v1.8-ROADMAP.md)
- ✅ **v1.9 — CI & Doc Honesty** — shipped 2026-05-27 — [archive](milestones/v1.9-ROADMAP.md)
- ✅ **v1.10 — Accrue Surface Closure** — shipped 2026-08-25 — [archive](milestones/v1.10-ROADMAP.md)
- ✅ **v1.11 — Reader-First Quality Closure** — shipped 2026-08-25; final package 2.2.2 — [archive](milestones/v1.11-ROADMAP.md)
- ✅ **v1.12 — API Contract Freshness and Adopter Proof** — shipped 2026-09-25 — [archive](milestones/v1.12-ROADMAP.md)

## Phases

<details>
<summary>✅ v1.12 API Contract Freshness and Adopter Proof (Phases 74–78) — SHIPPED 2026-09-25</summary>

- [x] Phase 74: Versioned Stripe Drift Triage (1/1 plans) — completed 2026-09-23
- [x] Phase 75: Typed Contract Updates (2/2 plans) — completed 2026-09-24
- [x] Phase 76: Phoenix Adopter Core Flow (1/1 plan) — completed 2026-09-24
- [x] Phase 77: Adopter Edge Profiles and CI (3/3 plans) — completed 2026-09-24
- [x] Phase 78: Release and Repository Closeout (6/6 plans) — completed 2026-09-25

Audit: 14/14 requirements satisfied. Bounded technical debt accepted; see
[milestone audit](milestones/v1.12-MILESTONE-AUDIT.md).

</details>

## Planning Horizons (living, not active commitments)

The horizons preserve direction without turning speculative ideas into backlog. Re-rank them
at every milestone close using current Stripe API evidence, adopter feedback, quality signals,
and the cost of maintaining the proposed proof.

### Near term — confidence gaps after v1.12

Add generated/property-based checks only for important pure invariants that the current
example-based suite does not already prove. Extend the adopter profiles only where a distinct
integration contract or operator failure mode appears in evidence. Reassess CI duration,
dependency and security automation, minimum-version support, error/retry semantics, data
handling, and observability alongside the code changes.

### Long term — evidence-gated Stripe breadth

Consider specialist Stripe families and industry-specific integration needs only when a
named adopter job, stable Stripe contract, and testable support path justify their ongoing
cost. Keep healthcare, gaming, commerce, marketplace, and other industry policy in adopter
applications; add SDK coverage only for reusable Stripe-shaped contracts.

### Roadmap refresh rule

At each milestone close, refresh these horizons and the audience/JTBD map against shipped
behavior, current Stripe changelog and OpenAPI drift, production feedback, and CI/security
evidence. Promote a candidate to an active milestone only after its user outcome, scope,
acceptance proof, and compatibility/release implications are clear.
