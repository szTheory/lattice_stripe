# Roadmap: LatticeStripe

## Milestones

- ✅ **v1.0 — Foundation + Billing + Connect + 1.0 Release** — Phases 1-11, 14-19 (shipped 2026-04-13 to Hex.pm) — [archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 — Accrue unblockers (metering + portal)** — Phases 20-21 (shipped 2026-04-14) — [brief](v1.1-accrue-context.md)
- ✅ **v1.2 — Production Hardening & DX** — Phases 22-31 (shipped 2026-04-17) — [archive](milestones/v1.2-ROADMAP.md)
- ✅ **v1.3 — Production Coverage & Adoption Polish** — Phases 32-42 plus Phase 41.1 follow-through (shipped 2026-05-25 with accepted external-proof gap) — [archive](milestones/v1.3-ROADMAP.md)
- ✅ **v1.4 — Adoption Closure** — Phases 43-46 (shipped 2026-05-27, Phase 41.1 preserved as `pending-external-verification`) — [archive](milestones/v1.4-ROADMAP.md)
- ✅ **v1.5 — Thin-Event Webhooks** — Phases 47-48 (shipped 2026-05-27) — [archive](milestones/v1.5-ROADMAP.md)
- ✅ **v1.6 — Tax** — Phases 49-51 (shipped 2026-05-27) — [archive](milestones/v1.6-ROADMAP.md)
- 🚧 **v1.7 — Polish & Operator** — Phases 52-55 (in progress; planned v1.x stop signal)

## Phases

<details>
<summary>✅ v1.6 Tax (Phases 49-51) — SHIPPED 2026-05-27</summary>

- [x] Phase 49: Tax Calculation & Transaction Core (3/3 plans) — completed 2026-05-27
- [x] Phase 50: Tax Settings & Registration (2/2 plans) — completed 2026-05-27
- [x] Phase 51: TaxId, Testing & Adoption Surface (4/4 plans) — completed 2026-05-27

</details>

### 🚧 v1.7 Polish & Operator (In Progress)

**Milestone Goal:** Close remaining v1.x scope gaps — expand Charge surface, ship operator guides, reconcile release truth, retire Phase 41.1 — then call the library done for v1.x scope.

- [x] **Phase 52: Charge Surface Expansion** — Expand retrieve-only Charge module to list/search/update/capture parity with sibling resources; integration tests + docs-truth four-surface triangulation. (completed 2026-05-27)
- [x] **Phase 53: Operator Guides** — Ship `guides/production-checklist.md` and `guides/event-debugging.md`; wire into ExDoc Operations & DX and README discovery ladder. (completed 2026-05-27)
- [ ] **Phase 54: Release Truth Capstone** — Bump to 1.7.0, CHANGELOG v1.4–1.7, lockstep `~> 1.7` docs-truth flip, Hex publish.
- [ ] **Phase 55: Milestone Closure & v1.x Stop Signal** — Retire Phase 41.1 as `accepted-external-verification`; publish "done for v1.x scope" in planning and public docs.

## Phase Details

### Phase 52: Charge Surface Expansion

**Goal**: Adopters can list, search, update, and capture charges for support/reconciliation workflows — closing the only mainstream payment resource with multi-endpoint Stripe API but retrieve-only SDK surface.
**Depends on**: Nothing (first v1.7 phase; sits on shipped v1.0–v1.6 foundation)
**Requirements**: CHRG-01, CHRG-02, CHRG-03, CHRG-04, CHRG-05
**Success Criteria** (what must be TRUE):

  1. An adopter can call `Charge.list/3` with filter params and receive `{:ok, %ListResult{data: [%Charge{}]}}` with pagination support via `list!/3` and `stream!/3`.
  2. An adopter can call `Charge.search/3` with a Stripe search query string and receive typed `%Charge{}` results via `search!/3` and `search_stream!/3`.
  3. An adopter can call `Charge.update/4` to modify charge metadata and description, receiving `{:ok, %Charge{}}`.
  4. An adopter can call `Charge.capture/4` to capture an uncaptured charge with optional amount params.
  5. `@moduledoc` updated to reflect expanded surface while preserving PI-first rationale (no `create`/`cancel`).
  6. Integration tests under `test/lattice_stripe/charge/` prove list/search/update/capture via Mox-at-Transport.
  7. Docs-truth grep blocks lock Charge moduledoc examples and surface declarations against drift.

**Plans**: 3 plans (52-01 implementation, 52-02 Mox wire tests + surface contract, 52-03 docs-truth + integration smokes)

### Phase 53: Operator Guides

**Goal**: Adopters have production-ready operator playbooks — a deployment checklist and an event debugging guide — wired into the docs discovery ladder.
**Depends on**: Phase 52 (Charge surface should land before operator guides reference reconciliation workflows)
**Requirements**: OPS-01, OPS-02
**Success Criteria** (what must be TRUE):

  1. `guides/production-checklist.md` exists covering API key hygiene, webhook verification, idempotency, error handling, telemetry, and production Finch configuration.
  2. `guides/event-debugging.md` exists covering snapshot vs thin events, signature verification failures, fetch-after-verify debugging, and common webhook dispatch patterns.
  3. Both guides are wired into ExDoc `Operations & DX` layered grouping.
  4. Both guides appear in the README discovery ladder and JTBD-MAP operator route.
  5. Docs-truth grep blocks lock guide content anchors and ExDoc placement.

**Plans**: TBD

### Phase 54: Release Truth Capstone

**Goal**: Public install truth matches shipped code — version bump, CHANGELOG reconciliation, docs-truth lockstep flip, and Hex publish at 1.7.0.
**Depends on**: Phase 53 (all v1.7 code and docs content must land before release)
**Requirements**: REL-01, REL-02, REL-03, REL-04
**Success Criteria** (what must be TRUE):

  1. `mix.exs` `@version` reads `"1.7.0"`.
  2. CHANGELOG contains v1.4, v1.5, v1.6, and v1.7 sections summarizing shipped milestone work.
  3. README, getting-started, cheatsheet, and guide install anchors all reference `~> 1.7` (docs-truth grep passes).
  4. Package `lattice_stripe` version `1.7.0` is published to Hex.pm.
  5. README HexDocs index reflects v1.4–v1.7 shipped surface (thin events, tax, charge, operator guides).

**Plans**: 4 plans (54-01 version+CHANGELOG, 54-02 lockstep docs+README, 54-03 docs_truth SSOT, 54-04 Hex publish)

### Phase 55: Milestone Closure & v1.x Stop Signal

**Goal**: Close v1.7 honestly — retire Phase 41.1 as accepted external boundary and publish the v1.x stop signal.
**Depends on**: Phase 54 (release must ship before milestone close)
**Requirements**: CLOSE-01, CLOSE-02
**Success Criteria** (what must be TRUE):

  1. Phase `41.1` status updated to `accepted-external-verification` in ROADMAP, STATE, MILESTONES, and Phase 41.1 directory artifacts.
  2. PROJECT.md, README, and MILESTONES.md reflect "done for v1.x scope" posture.
  3. Planning artifacts (PROJECT, ROADMAP, REQUIREMENTS, STATE) are coherent and close-ready.
  4. Deferred specialist Stripe families remain explicitly out of scope with reasoning preserved.
  5. `/gsd-complete-milestone` ready — all 13 v1.7 requirements verified.

**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 52. Charge Surface Expansion | v1.7 | 3/3 | Complete    | 2026-05-27 |
| 53. Operator Guides | v1.7 | 4/4 | Complete    | 2026-05-27 |
| 54. Release Truth Capstone | v1.7 | 3/4 | In Progress|  |
| 55. Milestone Closure & v1.x Stop Signal | v1.7 | 0/TBD | Not started | — |

## Next Step

Run `/gsd-discuss-phase 52` to gather context and negotiate Charge surface scope, then `/gsd-plan-phase 52` to create execution plans.
