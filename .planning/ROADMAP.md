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
- ✅ **v1.8 — Adopter Truth & Doc Routing Polish** — Phases 56-58 (shipped 2026-05-27) — [archive](milestones/v1.8-ROADMAP.md)
- 🚧 **v1.9 — CI & Doc Honesty** — Phases 59-60 (in progress)

## Current Status

**Active milestone:** v1.9 CI & Doc Honesty — doc-only; no Hex bump; closes checkout/README truth gaps and CI-01.

## Phases

### v1.9 CI & Doc Honesty

**Milestone Goal:** Close remaining adopter-truth gaps in checkout/README docs and make CI actually enforce docs_truth on guide-only changes — without new API breadth or Hex bump.

- [x] **Phase 59: Checkout Guide & README Truth** — Fix checkout.md atom status bug + callout; fix README error taxonomy; extend docs_truth locks. (CHECKOUT-01..03, README-01..02, VERIFY-05) (completed 2026-05-27)
- [ ] **Phase 60: CI Gate & Milestone Close** — Narrow CI paths-ignore so docs_truth runs on guide/md PRs; JTBD-MAP upgrade; optional 54-VERIFICATION backfill; milestone audit. (CI-01, JTBD-01, PLAN-01)

## Phase Details

### Phase 59: Checkout Guide & README Truth

**Goal:** Canonical checkout guide and README high-visibility claims are copy-paste correct with docs_truth regression locks.
**Depends on:** Nothing (first v1.9 phase)
**Requirements:** CHECKOUT-01, CHECKOUT-02, CHECKOUT-03, README-01, README-02, VERIFY-05
**Success Criteria** (what must be TRUE):

1. `guides/checkout.md` `Stream.filter` example uses `s.payment_status == :paid` (not `"paid"`).
2. `guides/checkout.md` includes status-values callout for atomized `payment_status` on `%Session{}`.
3. `README.md` error list uses `:authentication_error` and `:api_error` (matches `lib/lattice_stripe/error.ex`).
4. `docs_truth_test.exs` includes describe/grep blocks for checkout.md atom patterns and README error taxonomy.
5. Stale patterns (`"paid"` filter, `:auth_error`, `:server_error`) fail docs_truth if reintroduced.
6. `mix test test/lattice_stripe/docs_truth_test.exs` passes.

**Plans:** 2/2 plans complete

### Phase 60: CI Gate & Milestone Close

**Goal:** CI no longer bypasses docs_truth on guide-only PRs; planning artifacts reflect post-v1.9 reality; milestone ready to close.
**Depends on:** Phase 59 (doc fixes and docs_truth locks landed first)
**Requirements:** CI-01, JTBD-01, PLAN-01 (optional)
**Success Criteria** (what must be TRUE):

1. `.github/workflows/ci.yml` `paths-ignore` narrowed so changes under `guides/**` or root `*.md` still trigger docs_truth (or full test suite).
2. Guide-only PR workflow change documented in commit message; explicit approval gate satisfied before merge.
3. `.planning/JTBD-MAP.md` hosted checkout narrative coverage upgraded to Strong (checkout examples locked).
4. Optional: `.planning/phases/54-release-truth-capstone/54-VERIFICATION.md` backfilled from Phase 54 close evidence.
5. Milestone audit checklist complete; STATE.md and PROJECT.md updated for close or maintenance posture.
6. No Hex version bump (doc-only milestone).

**Plans:** 0 plans

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 59. Checkout Guide & README Truth | v1.9 | 2/2 | Complete    | 2026-05-27 |
| 60. CI Gate & Milestone Close | v1.9 | 0/? | Pending | — |

## Next Step

**Phase 59: Checkout Guide & README Truth** — Fix checkout.md atom status bug + callout; fix README error taxonomy; extend docs_truth locks.

`/gsd-discuss-phase 59` — gather context and clarify approach

Also: `/gsd-plan-phase 59` — skip discussion, plan directly
