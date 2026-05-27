# Roadmap: LatticeStripe

## Milestones

- ✅ **v1.0 — Foundation + Billing + Connect + 1.0 Release** — Phases 1-11, 14-19 (shipped 2026-04-13 to Hex.pm) — [archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 — Accrue unblockers (metering + portal)** — Phases 20-21 (shipped 2026-04-14) — [brief](v1.1-accrue-context.md)
- ✅ **v1.2 — Production Hardening & DX** — Phases 22-31 (shipped 2026-04-17) — [archive](milestones/v1.2-ROADMAP.md)
- ✅ **v1.3 — Production Coverage & Adoption Polish** — Phases 32-42 plus Phase 41.1 follow-through (shipped 2026-05-25) — [archive](milestones/v1.3-ROADMAP.md)
- ✅ **v1.4 — Adoption Closure** — Phases 43-46 (shipped 2026-05-27) — [archive](milestones/v1.4-ROADMAP.md)
- ✅ **v1.5 — Thin-Event Webhooks** — Phases 47-48 (shipped 2026-05-27) — [archive](milestones/v1.5-ROADMAP.md)
- ✅ **v1.6 — Tax** — Phases 49-51 (shipped 2026-05-27) — [archive](milestones/v1.6-ROADMAP.md)
- ✅ **v1.7 — Polish & Operator** — Phases 52-55 (shipped 2026-05-27, v1.x stop signal) — [archive](milestones/v1.7-ROADMAP.md)
- 🚧 **v1.8 — Adopter Truth & Doc Routing Polish** — Phases 56-58 (in progress)

## Phases

<details>
<summary>✅ v1.7 Polish & Operator (Phases 52-55) — SHIPPED 2026-05-27</summary>

- [x] Phase 52: Charge Surface Expansion (3/3 plans) — completed 2026-05-27
- [x] Phase 53: Operator Guides (4/4 plans) — completed 2026-05-27
- [x] Phase 54: Release Truth Capstone (4/4 plans) — completed 2026-05-27
- [x] Phase 55: Milestone Closure & v1.x Stop Signal (6/6 plans) — completed 2026-05-27

</details>

### 🚧 v1.8 Adopter Truth & Doc Routing Polish (In Progress)

**Milestone Goal:** Close v1.7 audit doc-routing debt — truthful release-status prose, copy-paste-correct payments guide examples, Charge reconciliation discovery, and planning-truth cosmetics — without new API breadth.

- [x] **Phase 56: Release Truth & Getting Started** — Fix getting-started release-status prose; extend docs_truth to lock prose (not just install pin). (TRUTH-01, TRUTH-02) (completed 2026-05-27)
- [x] **Phase 57: Payments Guide & Charge Routing** — Correct payments.md API examples; route Charge list/search/update/capture; extend operator guides; docs_truth canonical guide locks. (GUIDE-01..03, ROUTE-01, ROUTE-02, VERIFY-04) (completed 2026-05-27)
- [ ] **Phase 58: Milestone Closure & Planning Truth** — MILESTONES.md / RETROSPECTIVE cosmetics; JTBD-MAP post-fix refresh; optional tax proof hygiene; milestone close. (PLAN-01, PLAN-02, ROUTE-03, PROOF-01)

## Phase Details

### Phase 56: Release Truth & Getting Started

**Goal:** First-run adopters see truthful release-status prose in getting-started — aligned to Hex 1.7.0 — with docs_truth regression preventing prose drift.
**Depends on:** Nothing (first v1.8 phase)
**Requirements:** TRUTH-01, TRUTH-02
**Success Criteria** (what must be TRUE):

1. `guides/getting-started.md` prose describes 1.7.x (or current Hex) as the published surface; no stale `1.3.x` claim remains.
2. Install snippet remains `~> 1.7` (unchanged unless release policy changes).
3. `docs_truth_test.exs` includes grep blocks that fail if release-status prose regresses to stale version claims.
4. `mix test test/lattice_stripe/docs_truth_test.exs` passes.

**Plans:** 2/2 plans complete

### Phase 57: Payments Guide & Charge Routing

**Goal:** Canonical payments guide examples are copy-paste correct; adopters discover shipped Charge reconciliation workflows from payments and operator guides.
**Depends on:** Phase 56 (release truth baseline before canonical guide edits)
**Requirements:** GUIDE-01, GUIDE-02, GUIDE-03, ROUTE-01, ROUTE-02, VERIFY-04
**Success Criteria** (what must be TRUE):

1. PaymentIntent `confirm/3` status `case` in `guides/payments.md` uses atom statuses matching SDK deserialization.
2. `stream!/2` filter example uses `:succeeded` (not string).
3. `search/3` example uses `search(client, query_string, opts \\ [])` arity and shape.
4. `guides/payments.md` includes a Charge reconciliation section routing to list/search/update/capture (PI-first narrative preserved).
5. `guides/production-checklist.md` and `guides/event-debugging.md` mention Charge update/capture where reconciliation is relevant.
6. `docs_truth_test.exs` grep-regresses payments.md status-atom and search-arity patterns.
7. `mix test test/lattice_stripe/docs_truth_test.exs` passes.

**Plans:** 3/3 plans complete

### Phase 58: Milestone Closure & Planning Truth

**Goal:** Planning artifacts and JTBD map reflect post-v1.8 reality; optional proof-file hygiene resolved; milestone ready to close.
**Depends on:** Phase 57 (all doc fixes landed)
**Requirements:** ROUTE-03, PLAN-01, PLAN-02, PROOF-01
**Success Criteria** (what must be TRUE):

1. `.planning/JTBD-MAP.md` charge-reconciliation row and gaps list reflect closed payments/operator routing (no stale gap claims).
2. `.planning/MILESTONES.md` v1.7 section uses post-publish wording.
3. `.planning/RETROSPECTIVE.md` historical bullets accurate for 1.7.0 Hex publish.
4. Untracked tax proof files are committed or dropped with documented rationale.
5. Milestone audit checklist complete; STATE.md and PROJECT.md updated for close or next maintenance posture.

**Plans:** 4/5 plans complete

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 56. Release Truth & Getting Started | v1.8 | 2/2 | Complete    | 2026-05-27 |
| 57. Payments Guide & Charge Routing | v1.8 | 3/3 | Complete    | 2026-05-27 |
| 58. Milestone Closure & Planning Truth | v1.8 | 4/5 | In Progress | — |

## Next Step

**Phase 58 Plan 05** — `/gsd-complete-milestone v1.8` posture flip.

`/gsd-execute-phase 58` — continue Phase 58 execution
