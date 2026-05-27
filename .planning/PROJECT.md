# LatticeStripe

## What This Is

A production-grade, idiomatic Elixir SDK for the Stripe API. LatticeStripe is the default Stripe integration for the Elixir ecosystem — reliable enough for production SaaS, ergonomic enough that Elixir developers feel at home immediately. **Shipped v1.0.0 to Hex.pm on 2026-04-13** with full Payments + Billing + Connect coverage; four milestones later, the shipped 1.3.x surface is broad, documented, and discoverable. Hex package: `lattice_stripe`, module prefix: `LatticeStripe`.

## Core Value

Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising. **Still the right priority** — validated by four shipped milestones and a downstream consumer (Accrue) already building on top.

## Current State

**Latest shipped milestone:** v1.4 Adoption Closure (archived 2026-05-27)

**What shipped in v1.4:**

- Public package/version/install truth aligned across README, CHANGELOG, Getting Started, cheatsheet, mix.exs, and HexDocs extras
- Docs-truth regression coverage extended from README-only to all main onboarding/discovery surfaces (`test/lattice_stripe/docs_truth_test.exs` now 7 tests, 0 failures)
- Discovery ladder (README → JTBD → recipes → canonical guides), layered ExDoc grouping (`Start Here`, `Canonical Guides`, `Operations & DX`, `Flagship Recipes`)
- Four flagship recipe guides published: `checkout-signup-and-portal`, `metering-runtime-and-reconciliation`, `connect-platform-flow`, `quote-to-billing-operator`
- Support-truth follow-through links across nine canonical guides (webhooks/testing/error-handling/subscriptions/portal/metering/connect cluster)
- Planning truth reconciled: PROJECT.md, ROADMAP.md, REQUIREMENTS.md, STATE.md all reflect close-ready posture

**Outstanding follow-through (not milestone-blocking):**

- Phase `41.1` remains `pending-external-verification` for real-sandbox Quote downstream proof — an accepted external-proof boundary carried forward from v1.3, not missing SDK capability.

## Current Milestone: v1.5 Thin-Event Webhooks

**Goal:** Ship first-class thin-event (`/v2/events`) webhook handling — verify, resolve authoritative state, document the fetch-after-verify pattern, and reconcile the `tolerance: 0` webhook bug — so LatticeStripe adopters can consume modern Stripe webhook deliveries idiomatically in Phoenix.

**Target features:**

- Thin-event helpers — `Webhook.parse_event_notification/3`, `Webhook.fetch_event/2`, `Webhook.fetch_related_object/2` (reuses existing `ObjectTypes` dispatch).
- `Event` struct extension to surface `context` and `related_object` for the thin-event payload shape.
- Testing module thin-event payload helpers, signature-compatible with snapshot helpers.
- Canonical Phoenix guide `guides/webhooks-thin-events.md` covering fetch-after-verify idempotency, rate-limit guidance (<90/s under Stripe's 100 req/s ceiling), Connect/context-aware routing, and the verification-vs-payload-shape failure boundary.
- `Webhook.check_tolerance/2` `tolerance: 0` reconciliation — docstring (`lib/lattice_stripe/webhook.ex:84`) and code path (`lib/lattice_stripe/webhook.ex:268-273`) must agree.
- Integration test coverage for thin-event signature, fetch-after-verify happy path, and malformed-payload failure boundary.

**Key context:**

- Phase numbering continues from Phase 46 — v1.5 phases start at Phase 47.
- Pure SDK scope; no Accrue scope overlap (Tax filing/dunning/entitlement stay downstream).
- Reference shape: stripe-node v49+ `parseEventNotification` returning `Stripe.V2.EventNotification` with `fetchRelatedObject()` / `fetchEvent()` methods.
- First new Hex code release since `1.3.0` (April) — `mix.exs` currently pinned at `@version "1.3.0"`.
- See `.planning/threads/v1-5-next-milestone-assessment.md` (full dossier) and `.planning/threads/thin-event-webhook-evaluation.md` (locked-in shape).

## Subsequent Milestones

1. **v1.6 — Tax** (large, 2-3 phases) — broadest remaining mainstream family. `Tax.Calculation`, `Tax.Transaction`, `Tax.Settings`, `Tax.Registration`, `TaxId` nested under `Customer`. Negotiate scope in discuss-phase to keep filing orchestration in Accrue.
2. **v1.7 — Polish & Operator** (small, ~1 phase) — fill the unusually thin `Charge` surface (`list/3`, `search/3`, `capture/4`, `update/4`), close Phase `41.1` honestly, ship a production-checklist guide and event-debugging guide. Planned stop signal for v1.x scope.

After v1.7, expect to publicly call the library "done for v1.x scope" absent fresh adopter pull. Identity / Treasury / Issuing / Terminal / Financial Connections / Climate / Sigma / Reporting stay deferred per JTBD doctrine.

## Context

**Ecosystem gap:** At project start, the Elixir ecosystem lacked a modern, maintained Stripe SDK. `stripity_stripe` was outdated, with known issues around nested encoding and stale API coverage. LatticeStripe fills that gap with a production-minded Elixir-first surface.

**Target users:** Elixir developers building SaaS products who need Stripe integrations that are correct, documented, and unsurprising. Early adopter signal remains strong: Accrue already consumes LatticeStripe as a downstream billing layer.

**Codebase scale (post-v1.4):** ~5 v1.4 commits over 2 days, layered over 4 prior milestones. Documentation, regression contract, and discovery surfaces are now first-class artifacts alongside SDK code.

**Design philosophy:**

- Pure-functional core; processes only where the runtime boundary needs them
- Behaviours for extensibility (`Transport`, `RetryStrategy`, `Json`)
- `{:ok, result} | {:error, reason}` everywhere, with bang variants layered on top
- Pattern-matchable returns and explicit verbs for destructive or irreversible operations
- Principle of least surprise for Elixir developers

**Testing philosophy:**

- Integration specs first, with real request-pipeline proof where feasible
- Shift-left verification by default when a flow can be executed truthfully in CI
- Unit tests for pure logic and Mox for behaviour contracts
- Docs-truth assertions are first-class regression coverage, not editorial cleanup

## Constraints

- **Language**: Elixir 1.15+, OTP 26+
- **License**: MIT
- **No Dialyzer**: Typespecs remain documentation-first
- **HTTP**: Finch default transport behind a behaviour boundary
- **JSON**: Jason

## Requirements

### Validated

- ✓ Production-grade transport, retry, pagination, telemetry foundation — v1.0
- ✓ Payments, Checkout, SetupIntents, Refunds, webhooks — v1.0
- ✓ Billing core (Invoice, Subscription, SubscriptionSchedule, SubscriptionItem) — v1.0
- ✓ Connect core (Accounts, AccountLinks, money movement) — v1.0
- ✓ Accrue unblockers (Meter, MeterEvent, BillingPortal.Session) — v1.1
- ✓ Production hardening (Configuration CRUDL, per-op timeouts, warm-up, circuit breaker, OpenTelemetry guides, batching, drift detection, LiveBook) — v1.2
- ✓ Production coverage (File/FileLink, Disputes, CreditNote, Mandate, SetupAttempt, Quote) — v1.3
- ✓ Public truth aligned across README, CHANGELOG, Getting Started, cheatsheet, mix.exs, HexDocs (TRUTH-01, TRUTH-02) — v1.4
- ✓ Docs-truth regression coverage extended beyond README (VERIFY-01, VERIFY-02) — v1.4
- ✓ Guide discovery ladder and layered ExDoc grouping (GUIDE-01, GUIDE-02) — v1.4
- ✓ Flagship recipes: Checkout+Portal, Metering runtime, Connect platform, Quote-to-billing (RECIPE-01..04) — v1.4
- ✓ Planning truth reflects close-ready posture while preserving Phase 41.1 external-proof boundary (PLAN-01) — v1.4

### Active

(v1.5 Thin-Event Webhooks requirements — to be defined in REQUIREMENTS.md by this milestone's roadmapper run.)

### Out of Scope

- Billing-engine abstractions, entitlement logic, dunning workflows — belong downstream in Accrue or application code
- Resolving Phase 41.1 as a milestone-blocking requirement — real-sandbox proof remains valuable as carried follow-through, not as a release gate

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Handwritten v1 surface | Polish and Elixir ergonomics mattered more than breadth-first codegen | ✓ Good |
| Integration-first proof posture | Real boundaries catch drift earlier than mock-only tests | ✓ Good |
| Explicit verbs over magical updates | Clearer SDK semantics for irreversible actions | ✓ Good |
| Shift-left verification default | Docs/example flows should become executable proof where feasible | ✓ Good |
| Keep LatticeStripe lower-level than Accrue | Billing-engine abstractions belong downstream, not in the SDK | ✓ Good |
| Prioritize adoption closure before new breadth | Public truth and guide clarity unlock more value than another narrow Stripe family | ✓ Good (v1.4 confirmed) |
| Treat public docs/support truth as milestone-grade | First-run trust and flagship guidance change adoption more than another small API family | ✓ Good (v1.4 confirmed) |
| Keep recipe/operator guidance primitive-first | Recipes should stitch shipped primitives together without becoming an app workflow product | ✓ Good (v1.4 confirmed) |
| Treat the library as near-done for scope | Remaining leverage is adopter truth + selected wedges, not missing foundation | ✓ Good |
| Docs-truth as verifier-worthy regression surface | A green narrow docs test can still hide adopter-facing drift; v1.4 found `~> 1.2` drift while older assertions stayed green | ✓ Good (validated by Phase 43 find) |
| Preserve Phase 41.1 as `pending-external-verification` boundary | Real-sandbox proof is valuable but should not flatten into a false close; honesty over headline | ✓ Good (carried through v1.4) |
| Layered ExDoc grouping (Start Here / Canonical / Operations / Flagship) | Flat extras list buried high-leverage guides; role-based grouping surfaces the right surface for the right reader | ✓ Good (v1.4) |
| Webhook-confirmed truth posture in flagship guides | Accepted-now-vs-confirmed-by-webhook framing avoids overclaiming synchronous authority for async billing flows | ✓ Good (v1.4) |
| Lead post-adoption with thin-event webhooks, then Tax, then polish-and-stop | Thin events are mainstream Stripe direction; webhook foundation is already strong so the wedge is additive; Tax is the broadest remaining mainstream family but bigger; v1.7 polish gives the project an honest stop point at "done for v1.x scope" | ✓ Selected for v1.5 (assessment 2026-05-27) |
| Verify shipped surface against `lib/` source before every new milestone | Planning artifacts can be coherent and still miss real code-truth gaps (v1.5 assessment found `Charge` is unusually thin and the `tolerance: 0` webhook bug stayed open through v1.4 — neither captured in planning docs alone) | ✓ New rule (2026-05-27) |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check -> still the right priority?
3. Audit Out of Scope -> reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-27 — v1.5 Thin-Event Webhooks milestone kicked off via /gsd:new-milestone*
