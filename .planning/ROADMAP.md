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

## Active Milestone

v1.12 API Contract Freshness and Adopter Proof is active. This bounded milestone resumes
evidence-led maintenance for an already-supported API surface and a test-only host app, then
closes with a published release, green `main` CI, triaged pull requests, and clean worktrees.

Open a bounded milestone only for a confirmed defect, Stripe API drift, security need, or demonstrated adopter pull. The canonical Stripe drift radar is issue #13; deferred ideas remain evidence-gated rather than an implied roadmap.

## v1.12 API Contract Freshness and Adopter Proof

**Goal:** Improve typed support for high-value changes in already-supported Stripe resources
and prove the package from one test-only Phoenix application consuming it as a dependency.

**Starting phase:** 74 (continues after v1.11 Phase 73).

### Phases

- [x] **Phase 74: Versioned Stripe Drift Triage** — classify drift against stable, versioned Stripe sources and select fields or behaviors by adopter value. (completed 2026-09-23)
- [x] **Phase 75: Typed Contract Updates** — implement and document selected typed fields with compatibility and decoding proof. (completed 2026-09-24)
- [x] **Phase 76: Phoenix Adopter Core Flow** — validate dependency setup and a common Checkout/subscription/webhook flow.
- [ ] **Phase 77: Adopter Edge Profiles and CI** — prove selected B2B, usage, and Connect contracts and run the complete adopter suite deterministically.
- [ ] **Phase 78: Release and Repository Closeout** — publish and verify the package release, green `main` CI, triaged pull requests, and clean Git worktrees.

### Phase Details

#### Phase 74: Versioned Stripe Drift Triage

**Goal:** Maintainers can distinguish applicable stable Stripe contract changes from preview changes and OpenAPI noise, then select a bounded set using common adopter jobs and operational value.
**Depends on:** Nothing (first phase of v1.12).
**Requirements:** DRIFT-01
**Success Criteria** (what must be TRUE):

1. Candidate changes in already-supported resources link to stable, versioned Stripe sources and are classified by API-version applicability.
2. Selected and deferred candidates include an adopter job, semantic rationale, and type/decode implications.
3. The default API-version decision is recorded against explicit compatibility evidence; the pin stays unchanged if a move is not justified.

**Plans:** 1/1 plans complete

Plans:

- [x] 74-01-PLAN.md — evidence-first Stripe drift candidate triage and pin decision

#### Phase 75: Typed Contract Updates

**Goal:** Adopters can use the selected high-value fields as typed data without losing unknown-field access or changing existing public behavior.
**Depends on:** Phase 74
**Requirements:** DRIFT-02, DRIFT-03, DRIFT-04
**Success Criteria** (what must be TRUE):

1. Selected fields decode from stable-version fixtures into documented typed values.
2. Regression coverage proves unknown response fields remain available through `extra`.
3. Compatibility checks show existing public behavior is preserved and intended additions are reviewed against package SemVer policy.
4. Adopter documentation identifies the relevant Stripe API-version contract and selected fields.

**Plans:** 2/2 plans complete

Plans:
**Wave 1**

- [x] 75-01-PLAN.md — typed Invoice off-Stripe amount through retrieval, decoder proof, and version guidance

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 75-02-PLAN.md — typed Refund attribution fields, compatibility lock, and complete gate

#### Phase 76: Phoenix Adopter Core Flow

**Goal:** Maintainers can verify that a host Phoenix application configures and uses LatticeStripe as a dependency across a common SaaS flow.
**Depends on:** Phase 75
**Requirements:** ADOPT-01, ADOPT-02
**Success Criteria** (what must be TRUE):

1. A test-only Phoenix app imports the checked-out LatticeStripe package as a path dependency and starts with its documented host configuration and supervision.
2. A synthetic Checkout or subscription flow exercises typed Stripe responses and webhook handling from the host app boundary.
3. The core adopter flow runs without live Stripe credentials or production data.

**Plans:** 1/1 plans complete

#### Phase 77: Adopter Edge Profiles and CI

**Goal:** One adopter app proves a small set of distinct Stripe contracts and provides a repeatable CI gate for the full host-app integration.
**Depends on:** Phase 76
**Requirements:** ADOPT-03, ADOPT-04, ADOPT-05
**Success Criteria** (what must be TRUE):

1. Opt-in B2B invoicing, usage reconciliation, and Connect tenant-context profiles each assert the distinct SDK contract they exercise.
2. Adopter tests cover relevant error, pagination or streaming, idempotency, and webhook-verification boundaries with deterministic synthetic inputs.
3. CI runs the complete adopter suite deterministically without live credentials or adopter data.
4. The app remains a contract test harness; business policy, compliance, and durable billing orchestration stay out of scope.

**Plans:** 3 plans

Plans:

- [ ] 77-01-PLAN.md — versioned B2B Invoice profile and required adopter CI tracer
- [ ] 77-02-PLAN.md — usage summary stream and meter-event idempotency profile
- [ ] 77-03-PLAN.md — request-scoped Connect Balance profile and complete suite gate

#### Phase 78: Release and Repository Closeout

**Goal:** Adopters can install a verified milestone release, and maintainers can close the milestone with healthy `main` CI, triaged pull requests, and a clean repository workspace.
**Depends on:** Phase 77
**Requirements:** REL-01, REL-02, CLOSE-01, CLOSE-02, CLOSE-03
**Success Criteria** (what must be TRUE):

1. A new package version consistent with the delivered public API changes is published and verified on Hex, with matching GitHub release and HexDocs content.
2. All required CI checks are green for the release commit on `main`.
3. Every open pull request has a recorded triage disposition and any accepted changes have passed their required checks.
4. The primary checkout and all linked Git worktrees have no uncommitted changes at milestone close.

**Plans:** TBD

### Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 74. Versioned Stripe Drift Triage | 1/1 | Complete    | 2026-09-23 |
| 75. Typed Contract Updates | 2/2 | Complete    | 2026-09-24 |
| 76. Phoenix Adopter Core Flow | 1/1 | Complete    | 2026-09-24 |
| 77. Adopter Edge Profiles and CI | 0/TBD | Not started | - |
| 78. Release and Repository Closeout | 0/TBD | Not started | - |

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
