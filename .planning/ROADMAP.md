# Roadmap: LatticeStripe

## Milestones

- ✅ **v1.0 — Foundation + Billing + Connect + 1.0 Release** — Phases 1-11, 14-19 (shipped 2026-04-13 to Hex.pm) — [archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 — Accrue unblockers (metering + portal)** — Phases 20-21 (shipped 2026-04-14) — [brief](v1.1-accrue-context.md)
- ✅ **v1.2 — Production Hardening & DX** — Phases 22-31 (shipped 2026-04-17) — [archive](milestones/v1.2-ROADMAP.md)
- ✅ **v1.3 — Production Coverage & Adoption Polish** — Phases 32-42 plus Phase 41.1 follow-through (shipped 2026-05-25 with accepted external-proof gap) — [archive](milestones/v1.3-ROADMAP.md)
- ✅ **v1.4 — Adoption Closure** — Phases 43-46 (shipped 2026-05-27, Phase 41.1 preserved as `pending-external-verification`) — [archive](milestones/v1.4-ROADMAP.md)
- 🚧 **v1.5 — Thin-Event Webhooks** — Phases 47-48 (in progress, kicked off 2026-05-27)

## Phases

- [x] **Phase 47: Thin-Event SDK Surface & Webhook Reconciliation** — Net-new thin-event helpers, `Event` struct extension, signed-payload testing helpers, and `tolerance: 0` bug reconciliation. (completed 2026-05-27)
- [ ] **Phase 48: Thin-Event Adoption Surface — Guide & Integration Verification** — Canonical Phoenix thin-event guide plus integration coverage and docs-truth regression for the new helpers.

## Phase Details

### Phase 47: Thin-Event SDK Surface & Webhook Reconciliation

**Goal**: Adopters can verify a thin-event payload, pattern-match its typed notification struct, fetch the authoritative Event and related resource, and generate signed test payloads — on a webhook module whose `tolerance: 0` semantics agree between docstring and code.
**Depends on**: Nothing (first v1.5 phase; sits on top of shipped v1.0-v1.4 webhook foundation)
**Requirements**: WEBFIX-01, THIN-04, THIN-01, THIN-02, THIN-03, TESTING-01
**Success Criteria** (what must be TRUE):

  1. An adopter can call `Webhook.parse_event_notification/3` with a raw thin-event payload + `Stripe-Signature` header + secret and get back `{:ok, notification}` exposing `id`, `type`, `created`, `context`, and a `related_object` reference — or a typed `{:error, reason}` using the same reason atoms as `construct_event/3`.
  2. An adopter can pattern-match `notification.related_object` (a `%{id: ..., type: ...}` map, may be `nil` for snapshot events) and `notification.context` directly on the returned struct, without re-parsing the wire payload, and the same `context` + `related_object` fields are surfaced on `Event.t()` for the snapshot/legacy event path.
  3. An adopter can call `Webhook.fetch_event/2` with a notification (or its `id`) and receive `{:ok, %Event{}}` typed via the existing `Event` from-map machinery, honoring `:client`, `:api_version`, and `:idempotency_key` per-request opts.
  4. An adopter can call `Webhook.fetch_related_object/2` and receive `{:ok, resource}` where `resource` is the typed underlying object (e.g. `%Customer{}`, `%Invoice{}`) dispatched through the existing `ObjectTypes` registry — no new dispatch table introduced — with expand semantics from v1.2 reused.
  5. `Webhook.check_tolerance/2` `tolerance: 0` behavior agrees between `lib/lattice_stripe/webhook.ex:84` (docstring) and the code path at `:268-273`, the chosen semantics are documented inline in the source, and a CHANGELOG entry records the reconciliation.
  6. `LatticeStripe.Testing` exposes thin-event payload builders that produce wire-format payloads + matching `Stripe-Signature` headers parseable by `Webhook.parse_event_notification/3`, while existing snapshot helpers continue to work unchanged.

**Plans**: 5 plans
Plans:
**Wave 1**

- [x] 47-01-PLAN.md — Types: `EventNotification` + `RelatedObject` modules, `Event.related_object` extension, `ObjectTypes.fetch_module/1`, canonical fixture (THIN-04)
- [x] 47-03-PLAN.md — WEBFIX-01 four-surface reconciliation: code clause + Plug schema + test rewrite + CHANGELOG + docs-truth regression (WEBFIX-01)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 47-02-PLAN.md — Parse: `Webhook.parse_event_notification/4` + bang variant + 4-atom verify error set (THIN-01)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 47-04-PLAN.md — Fetchers: `Webhook.fetch_event/3` (v2 path `/v2/core/events/{id}`) + `Webhook.fetch_related_object/3` (D-05 typed-error gate) + Mox tests (THIN-02, THIN-03)
- [x] 47-05-PLAN.md — Testing helpers: `Testing.generate_thin_event_payload/3` + `Testing.event_notification/1` + roundtrip proof (TESTING-01)

### Phase 48: Thin-Event Adoption Surface — Guide & Integration Verification

**Goal**: Adopters can follow one canonical Phoenix guide from receiving a thin-event delivery through verified, fetch-after-verify, idempotent handling — backed by integration coverage that proves the helpers behave under happy-path, malformed-payload, and `tolerance: 0` boundary conditions and a docs-truth regression suite that keeps the guide honest.
**Depends on**: Phase 47 (all helper / struct / testing / bugfix surface must land first)
**Requirements**: GUIDE-03, VERIFY-03
**Success Criteria** (what must be TRUE):

  1. `guides/webhooks-thin-events.md` is published and discoverable — a reader can follow it from a Phoenix endpoint receiving `/v2/events` deliveries through `Webhook.parse_event_notification/3`, fetch-after-verify via `Webhook.fetch_event/2` or `Webhook.fetch_related_object/2`, and idempotent handler dispatch keyed on `event.id` (not on fetched resource state).
  2. The guide explicitly teaches the verification-vs-payload-shape failure boundary (which errors are signature/tolerance failures vs JSON/shape failures), rate-limit guidance (<90/s under Stripe's 100 req/s ceiling) acknowledging fetch-after-verify doubles call rate, and Connect/context-aware routing via `event.context`.
  3. The guide is wired into the ExDoc layered grouping (Canonical Guides) and the JTBD discovery ladder so evaluators land on it from README → JTBD → canonical guide path the same way the v1.4 flagship recipes are surfaced.
  4. Integration tests under `test/lattice_stripe/webhook*` cover thin-event verification happy path, fetch-after-verify roundtrip (returning typed resources via `ObjectTypes` dispatch), malformed-payload rejection, and `tolerance: 0` reconciled semantics — all green in CI.
  5. The docs-truth regression suite is extended so `webhooks-thin-events.md` install + handler snippets stay enforceable (drift in code samples must fail CI), matching the v1.4 docs-truth contract pattern.

**Plans**: TBD

## Outstanding Follow-Through

- **Phase 41.1** — `pending-external-verification` for real-sandbox Quote downstream follow-through proof. Accepted external-proof boundary, carried forward from v1.3 archive. Not a milestone-blocking gap; decide whether to re-run with valid sandbox credentials or retire as accepted external-only follow-through. (Planned to ride along with v1.7 polish milestone.)

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 47. Thin-Event SDK Surface & Webhook Reconciliation | 5/5 | Complete   | 2026-05-27 |
| 48. Thin-Event Adoption Surface — Guide & Integration Verification | 0/? | Not started | - |

## Next Step

Run `/gsd:execute-phase 47` to begin executing Phase 47 (5 plans across 3 waves).
