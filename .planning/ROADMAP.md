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

LatticeStripe is near-done for its intended mainstream Stripe SDK scope. v1.12 delivered the
previously selected API freshness and Phoenix adopter-proof wedge. Keep the project in
reactive maintenance; these horizons preserve direction without creating scheduled work.
Re-rank them at each milestone close or when new evidence arrives.

### Near term — reactive maintenance

- Fix confirmed defects and security issues; follow stable Stripe API changes that affect
  already-supported, high-value resources.
- Keep package, docs, and release truth aligned; keep `main` CI green and repository state
  tidy after any scoped release.
- Do not start a feature milestone from raw drift counts, coverage goals, or the existence of
  acknowledged v1.12 edge-case debt alone.

### Mid term — targeted confidence or adopter gaps (triggered only by evidence)

- Promote only a demonstrated adopter-blocking contract, material reliability/privacy risk,
  or recurring CI cost into a bounded milestone.
- Consider selective property-based tests when a named pure invariant has meaningful cases
  that examples do not cover; extend the shared Phoenix adopter only for a distinct reusable
  SDK contract or recurring failure mode.
- Reassess minimum-version compatibility, dependency/security automation, retry/error
  semantics, and observability when evidence points to a concrete gap.

### Long term — specialist Stripe coverage (pull-driven)

- Consider specialist resource families only for a named adopter job, stable Stripe contract,
  clear SDK/application boundary, and maintainable proof path.
- Keep healthcare, gaming, commerce, marketplace, and other industry policy in adopter
  applications; expose reusable Stripe-shaped primitives where justified.
- Admin/operator product UI is outside this headless SDK and belongs in an adopting product
  (such as Accrue), not on this roadmap.

### Roadmap refresh and done-enough rule

At each milestone close, refresh these horizons and `.planning/JTBD-MAP.md` against shipped
behavior, current Stripe changelog and versioned schema evidence, adopter feedback,
CI/security/runtime signals, and the maintenance cost of proposed proof. Promote a candidate
to an active milestone only when its user outcome, scope, acceptance evidence, and
compatibility/release implications are clear. Treat the SDK as done enough while common
adopter jobs remain covered and no evidence-backed gap justifies its ongoing maintenance cost;
resume feature work only when a concrete trigger fires.
