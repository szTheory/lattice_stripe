# LatticeStripe

## What This Is

A production-grade, idiomatic Elixir SDK for the Stripe API. LatticeStripe is the default Stripe integration for the Elixir ecosystem — reliable enough for production SaaS, ergonomic enough that Elixir developers feel at home immediately. **Shipped v1.7.0 to Hex.pm on 2026-05-27** — feature-complete for intended v1.x scope covering Payments, Billing, Connect, Tax, thin-event webhooks, Charge reconciliation, and operator diagnostics. Hex package: `lattice_stripe`, module prefix: `LatticeStripe`.

## Core Value

Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising. **Still the right priority** — validated by four shipped milestones and a downstream consumer (Accrue) already building on top.

## Current State

**Latest shipped milestone:** v1.7 Polish & Operator (archived 2026-05-27)

**Active milestone:** None — v1.x scope complete; planning next milestone.

**What shipped in v1.7:**

- **Charge surface expansion** — `LatticeStripe.Charge` list/search/update/capture parity with PI-first moduledoc, Mox wire tests, stripe-mock integration smokes, and docs-truth four-surface triangulation (CHRG-01..05).
- **Operator guides** — `guides/production-checklist.md` and `guides/event-debugging.md` wired into ExDoc Operations & DX, README hardening route, and JTBD operator route (OPS-01, OPS-02).
- **Release truth capstone** — `@version` 1.7.0, CHANGELOG v1.4–v1.7, lockstep `~> 1.7` install contract, SSOT docs-truth migration, Hex publish at 1.7.0 (REL-01..04).
- **v1.x stop signal** — Phase `41.1` retired as `accepted-external-verification`; library called "done for v1.x scope" in README, `guides/scope.md`, and planning artifacts (CLOSE-01, CLOSE-02).

**What shipped in v1.6:**

- **Tax Calculation & Transaction core** — `Tax.Calculation` and `Tax.Transaction` with nested structs, explicit verbs (`create_from_calculation/3`, `create_reversal/3`), moduledocs on 90-day expiry and `Invoice.AutomaticTax` boundary, and chained Mox-at-Transport integration spec proving calc→txn→reversal.
- **Tax Settings & Registration** — `Tax.Settings` singleton (`retrieve/2`, `update/3` on `/v1/tax/settings`) and `Tax.Registration` CRUDL with jurisdiction `country_options` and authority disclaimer moduledocs — first singleton resource pattern in the codebase.
- **TaxId dual-path surface** — top-level `LatticeStripe.TaxId` with guard-disambiguated routing for `/v1/tax_ids` and `/v1/customers/:id/tax_ids`, nested `Verification`/`Owner` structs, PII-redacted `Inspect`.
- **Adoption surface** — public `LatticeStripe.Testing` Tax fixtures, expand-through-parent proof for all five Tax object types, canonical `guides/tax.md` (351 lines) in ExDoc Canonical Guides + JTBD ladder, docs-truth grep locks on Tax moduledocs and guide content.

**What shipped in v1.5:**

- Thin-event SDK surface — `Webhook.parse_event_notification/4` (+ bang variant) verifies HMAC signatures and returns typed `EventNotification` structs exposing `id`, `type`, `created`, `context`, and a `related_object` reference, using the same error atoms as `construct_event/3`.
- Typed fetch-after-verify helpers — `Webhook.fetch_event/2,3` (`/v2/core/events/{id}`) and `Webhook.fetch_related_object/2,3` returning typed resources via the existing `ObjectTypes` registry (no new dispatch table), honoring per-request `:client`, `:api_version`, and `:idempotency_key`.
- `Event.t()` extended with a `related_object` field; net-new `EventNotification` + `EventNotification.RelatedObject` modules with custom `Inspect` impls; `ObjectTypes.fetch_module/1` typed-gate accessor.
- `Webhook.check_tolerance/2` `tolerance: 0` semantics reconciled across four surfaces (docstring, code clause, Plug NimbleOptions schema, tests) — `tolerance: 0` now disables the staleness check as the docstring promised, matching every canonical Stripe SDK. CHANGELOG entry + docs-truth grep regression lock the decision.
- Canonical guide `guides/webhooks-thin-events.md` published — Phoenix controller spine, fetch-after-verify, idempotency keyed on `event.id`, rate-limit guidance (<90/s), Connect/context-aware routing, verification-vs-payload-shape failure boundary; wired into ExDoc `Operations & DX` + README hardening-ops route + `guides/webhooks.md` closing section + JTBD Start Here Runtime route + Job 7 Read next.
- `LatticeStripe.Testing` thin-event helpers — `generate_thin_event_payload/3` (signed wire payload + matching `Stripe-Signature` header parseable by `parse_event_notification/4`) and `event_notification/1` (typed builder mirroring `dispute/1`/`customer/1`); snapshot helpers remain backwards-compatible.
- `test/lattice_stripe/webhook/thin_event_test.exs` chained Mox-at-Transport integration suite + five new docs-truth grep blocks (guide content lock, `~> 1.5` install canary, ExDoc placement, cross-link graph, Plug `@moduledoc` `tolerance: 0` testing-only).

**Outstanding follow-through (not milestone-blocking):**

- None — Phase `41.1` retired as `accepted-external-verification` in v1.7 (Phase 55).

## v1.x Status (post–1.7.0)

The library is **done for v1.x scope** — intended mainstream SaaS Stripe coverage is shipped and documented. Identity, Treasury, Issuing, Terminal, Financial Connections, Climate, Sigma, and Reporting remain deferred unless adopter pull justifies a future milestone.

**Forward posture:** Maintenance mode — bugfixes, Stripe API drift, adopter-driven narrow additions. No planned new resource-family breadth in v1.x absent fresh adopter pull.

## Next Milestone Goals

No active milestone defined. Run `/gsd-new-milestone` to assess whether v2.0, specialist Stripe families (Identity, Treasury, Issuing, Terminal), or maintenance-only posture is the right next step.

Candidate directions (not committed):
- Specialist Stripe families if adopter pull materializes (SPEC-01, SPEC-02)
- Tax extensions (TAX-01 Tax Code lookup, TAX-02 Transaction list if Stripe adds it)
- Post-close doc-routing polish from v1.7 audit tech debt

## Context

**Ecosystem gap:** At project start, the Elixir ecosystem lacked a modern, maintained Stripe SDK. `stripity_stripe` was outdated, with known issues around nested encoding and stale API coverage. LatticeStripe fills that gap with a production-minded Elixir-first surface.

**Target users:** Elixir developers building SaaS products who need Stripe integrations that are correct, documented, and unsurprising. Early adopter signal remains strong: Accrue already consumes LatticeStripe as a downstream billing layer.

**Codebase scale (post-v1.7):** v1.7 added ~7,527 lines across 138 files in a single-day milestone (2026-05-27) on top of seven prior milestones. Charge reconciliation, operator guides, and release truth are now first-class surfaces with docs-truth regression locks. The library is publicly declared done for v1.x scope at Hex 1.7.0.

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

- ✓ Tax Settings & Registration (CONF-01..04) — Phase 50, v1.6
- ✓ Tax Calculation & Transaction core (CALC-01..03, TXN-01..04, DX-03) — Phase 49, v1.6
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
- ✓ Thin-event SDK surface: `Webhook.parse_event_notification/4`, typed `EventNotification`/`RelatedObject` structs, `Event.related_object` extension (THIN-01..04) — v1.5
- ✓ Webhook bug reconciliation: `Webhook.check_tolerance/2` `tolerance: 0` semantics aligned across docstring, code clause, Plug schema, and tests (WEBFIX-01) — v1.5
- ✓ `LatticeStripe.Testing` thin-event payload + notification helpers, snapshot helpers backwards-compatible (TESTING-01) — v1.5
- ✓ Canonical Phoenix thin-event guide wired into ExDoc + discovery ladder (GUIDE-03) — v1.5
- ✓ Integration coverage for thin-event happy-path, fetch-after-verify, malformed-payload, and `tolerance: 0` boundaries + docs-truth regression extension (VERIFY-03) — v1.5
- ✓ Tax Calculation & Transaction core (CALC-01..03, TXN-01..04, DX-03) — Phase 49, v1.6
- ✓ Tax Settings & Registration (CONF-01..04) — Phase 50, v1.6
- ✓ TaxId dual-path CRUDL (TAXID-01..04) — Phase 51, v1.6
- ✓ Tax ObjectTypes, Testing fixtures, canonical guide, docs-truth (DX-01, DX-02, DX-04, DX-05) — Phase 51, v1.6
- ✓ Charge list/search/update/capture surface (CHRG-01..05) — Phase 52, v1.7
- ✓ Operator guides: production checklist + event debugging (OPS-01, OPS-02) — Phase 53, v1.7
- ✓ Release truth: 1.7.0 version, CHANGELOG v1.4–v1.7, lockstep `~> 1.7` install contract, Hex publish (REL-01..04) — Phase 54, v1.7
- ✓ Phase 41.1 retired + v1.x stop signal (CLOSE-01, CLOSE-02) — Phase 55, v1.7

### Active

(None — run `/gsd-new-milestone` to define next milestone requirements.)

### Out of Scope

- Billing-engine abstractions, entitlement logic, dunning workflows — belong downstream in Accrue or application code
- Resolving Phase 41.1 as a milestone-blocking requirement — retired as `accepted-external-verification` in v1.7
- New Stripe resource families in v1.x — v1.7 is the planned stop signal; Identity, Treasury, Issuing, Terminal, Financial Connections, Climate, Sigma, and Reporting deferred unless adopter pull justifies a future milestone

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
| Lead post-adoption with thin-event webhooks, then Tax, then polish-and-stop | Thin events are mainstream Stripe direction; webhook foundation is already strong so the wedge is additive; Tax is the broadest remaining mainstream family but bigger; v1.7 polish gives the project an honest stop point at "done for v1.x scope" | ✓ Confirmed by v1.5 (shipped 2026-05-27 in ~6 hours single-day; surface landed clean with 21 tests added) |
| Verify shipped surface against `lib/` source before every new milestone | Planning artifacts can be coherent and still miss real code-truth gaps (v1.5 assessment found `Charge` is unusually thin and the `tolerance: 0` webhook bug stayed open through v1.4 — neither captured in planning docs alone) | ✓ Validated by v1.5 (`tolerance: 0` bug discovered by source verification, not planning review) |
| Reuse existing dispatch tables for new resource families instead of growing new ones | `Webhook.fetch_related_object/2,3` typed-dispatches via the existing `ObjectTypes` registry. Resisting "new dispatch table" temptation kept v1.5 narrow and made the surface immediately benefit from `ObjectTypes` typed deserialization | ✓ Good (v1.5) |
| Treat docstring/code drift as bug, not as docstring-fix opportunity | WEBFIX-01 chose to fix the code clause to match the docstring (matching every canonical Stripe SDK and the more useful semantics) instead of the easier path of changing the docstring. CHANGELOG + docs-truth grep regression locks the decision against future "fix it to be stricter" drift | ✓ Good (v1.5 WEBFIX-01) |
| Four-surface triangulation for security-adjacent bug fixes | WEBFIX-01 reconciled `tolerance: 0` across (1) source docstring, (2) source code clause, (3) `Webhook.Plug` NimbleOptions schema, (4) tests + CHANGELOG + docs-truth grep — the four surfaces an adopter touches to reach the behavior. Single-surface fixes leave drift seams | ✓ Good (v1.5 pattern, reusable for Charge surface work in v1.7) |
| Top-level `TaxId` with arity-based dual-path routing | Single module covers `/v1/tax_ids` and `/v1/customers/:id/tax_ids` via guard-disambiguated arity — avoids duplicating Customer-scoped vs top-level modules | ✓ Good (v1.6) |
| Singleton resource pattern for `Tax.Settings` | First singleton in codebase (`GET/POST /v1/tax/settings`, no resource ID) — establishes pattern for future Stripe singletons | ✓ Good (v1.6) |
| SDK primitives only for Tax; Accrue owns filing | Phase 51 guide fences filing orchestration to Accrue once; prevents scope bleed into multi-jurisdiction filing automation | ✓ Good (v1.6) |
| Hex publish is stop-milestone capstone, not out-of-band | Out-of-band publish creates adopter truth lag (install `~> 1.3` while code ships v1.5/v1.6); fold release prep into v1.7 | ✓ Good (v1.7 REL-04) |
| v1.7 as planned v1.x stop signal | Polish + operator guides + release truth close remaining scope gaps honestly before declaring maintenance mode | ✓ Good (v1.7) |
| Retire Phase 41.1 as accepted external boundary | Real-sandbox proof valuable but should not block honest close; append-only retirement preserves audit trail | ✓ Good (v1.7 CLOSE-01) |

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
*Last updated: 2026-05-27 after v1.7 milestone*
