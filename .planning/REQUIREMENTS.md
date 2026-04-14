# Requirements: LatticeStripe v1.1 — Accrue Unblockers

**Defined:** 2026-04-14
**Milestone:** v1.1 (Accrue unblockers — metering + portal)
**Core Value:** Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.
**Driver:** Accrue Phase 4 (Advanced Billing + Checkout/Portal) is blocked on three Stripe resources LatticeStripe v1.0 does not expose.

> Authoritative brief: `.planning/v1.1-accrue-context.md` — locked decisions D1–D5.
> Research summary: `.planning/research/SUMMARY.md` — no new deps, two phases (~10 plans), no release phase.

## v1.1 Requirements

### Billing Metering — Meter lifecycle

- [ ] **METER-01**: User can create a Meter with `display_name`, `event_name`, `default_aggregation.formula` (`:sum | :count | :last`), `customer_mapping`, `value_settings`, and receive a `%LatticeStripe.Billing.Meter{}` struct
- [ ] **METER-02**: User can retrieve a Meter by ID
- [ ] **METER-03**: User can update a Meter's mutable fields (e.g. `display_name`) via `update/4`
- [ ] **METER-04**: User can list Meters with cursor pagination and lazy `stream/3` following the v1.0 pattern
- [ ] **METER-05**: User can deactivate a Meter via dedicated `deactivate/3` verb (POST `/v1/billing/meters/{id}/deactivate`), NOT via `update/4` with a status param
- [ ] **METER-06**: User can reactivate a Meter via dedicated `reactivate/3` verb (POST `/v1/billing/meters/{id}/reactivate`)
- [ ] **METER-07**: Every Meter function has a bang variant (`create!/3`, `retrieve!/3`, etc.) that returns the struct or raises
- [ ] **METER-08**: Meter nested typed structs exist for `DefaultAggregation`, `CustomerMapping`, `ValueSettings`, `StatusTransitions` — follow the v1.0 `@known_fields + :extra` pattern where Stripe may add fields (CustomerMapping, StatusTransitions); simple value structs (DefaultAggregation, ValueSettings) stay minimal
- [ ] **METER-09**: `Meter.status` is decoded to an atom (`:active` | `:inactive`) with a safe `status_atom/1` helper mirroring `Account.Capability`

### Billing Metering — Event reporting (hot path)

- [ ] **EVENT-01**: User can report a meter event via `LatticeStripe.Billing.MeterEvent.create/3` with `event_name`, `payload`, optional `timestamp`, and optional `identifier` for Stripe-native domain-level dedup
- [ ] **EVENT-02**: `MeterEvent.create/3` honors the standard `idempotency_key:` opt (HTTP header) in addition to the body-level `identifier` field — the two are orthogonal, both documented
- [ ] **EVENT-03**: `MeterEvent.create/3` honors the standard `stripe_account:` opt for Connect (Accrue Phase 5 dependency)
- [ ] **EVENT-04**: User can create a meter event adjustment via `LatticeStripe.Billing.MeterEventAdjustment.create/3` with a `cancel` sub-object containing the exact `cancel.identifier` field (not `id`, not `event_id`) to correct over-reports within Stripe's 24-hour cancellation window
- [ ] **EVENT-05**: `MeterEvent` struct minimally exposes `event_name`, `identifier`, `payload`, `timestamp`, `created`, `livemode` — no back-read operations (no retrieve/list); Accrue only writes events

### Customer Portal — Session creation

- [ ] **PORTAL-01**: User can create a portal session via `LatticeStripe.BillingPortal.Session.create/3` with required `customer`, optional `return_url`, `configuration`, `locale`, `flow_data`, `on_behalf_of`, and receive a `%LatticeStripe.BillingPortal.Session{}` struct with a usable `url`
- [ ] **PORTAL-02**: `Session.create!/3` bang variant exists; no retrieve/list/update/delete functions exist (sessions are create-only per Stripe API)
- [ ] **PORTAL-03**: `flow_data` is accepted as a map and decoded back into a `LatticeStripe.BillingPortal.Session.FlowData` typed struct covering all four flow types (`:subscription_cancel`, `:subscription_update`, `:subscription_update_confirm`, `:payment_method_update`) with `@known_fields + :extra` for forward compatibility
- [ ] **PORTAL-04**: `Session.create/3` validates `flow_data.type` client-side with an atom guard or `Resource.require_param!` — parallel to `Subscription.pause_collection/5` precedent — so invalid flow types raise `ArgumentError` before the network call
- [ ] **PORTAL-05**: Session struct exposes `id`, `object`, `customer`, `url`, `return_url`, `created`, `livemode`, `locale`, `configuration`, `flow` (echoed back)
- [ ] **PORTAL-06**: `Session.create/3` honors the standard `stripe_account:` opt for Connect-hosted portal sessions

### Safety guards (pitfall mitigations)

- [ ] **GUARD-01**: `Meter.create/3` raises or warns clearly when `default_aggregation.formula` is `:sum` and `value_settings.event_payload_key` is missing — prevents the silent-zero trap where aggregated usage is always zero because no payload key is designated
- [ ] **GUARD-02**: Inline `@doc` for `MeterEvent.create/3` documents the 35-day backdating window, the 24-hour `identifier` dedup window, and the asynchronous nature of customer-mapping validation (events may be accepted and silently dropped; the only detection mechanism is the `v1.billing.meter.error_report_triggered` webhook)
- [ ] **GUARD-03**: `MeterEvent.create/3` returning `{:ok, %MeterEvent{}}` is documented as "Stripe accepted the event for processing," NOT "the event was recorded against a customer" — guide-level callout, mirrors the Phase 15 webhook-handoff callout precedent

### Testing & integration

- [ ] **TEST-01**: `test/support/fixtures/metering.ex` provides canonical `Meter`, `MeterEvent`, and `MeterEventAdjustment` fixtures reusable across unit and integration tests
- [ ] **TEST-02**: `test/support/fixtures/billing_portal.ex` provides a canonical `Session` fixture including at least one `FlowData` shape per flow type
- [ ] **TEST-03**: Wave 0 `stripe-mock` probe in Phase 20 confirms the three metering endpoints behave as documented, including the exact `cancel` sub-object field shape for MeterEventAdjustment, and records any gaps (stripe-mock is stateless — lifecycle assertions must be shape-only, not state-transition)
- [ ] **TEST-04**: Wave 0 `stripe-mock` probe in Phase 21 confirms `/v1/billing_portal/sessions` and notes whether stripe-mock enforces `flow_data` required sub-fields (informs whether the client-side guard is fully tested via mock or requires unit tests in addition)
- [ ] **TEST-05**: Full integration tests (tagged `:integration`) exercise: seed a meter → report events through it → adjust one → deactivate → list filtered by status → reactivate; and create a portal session for a real test customer and assert the returned `url` shape

### Documentation

- [ ] **DOCS-01**: New `guides/metering.md` covers usage-reporting idiom (how to call `MeterEvent.create/3` from a hot-path worker), idempotency two-layer explainer (`identifier` vs `idempotency_key:`), reconciliation notes (monitor `v1.billing.meter.error_report_triggered` webhook), backdating window, aggregation formula semantics, and webhook handoff pointers
- [ ] **DOCS-02**: `guides/customer-portal.md` is created (or extended if it exists) with an Accrue-style usage example showing create → return URL → redirect, covering all four flow types with required sub-fields
- [ ] **DOCS-03**: `mix.exs` `groups_for_modules` gains a `"Billing Metering"` group (Meter, MeterEvent, MeterEventAdjustment, nested structs) and a `"Customer Portal"` group (Session, FlowData); both guides added to `extras`
- [ ] **DOCS-04**: Cross-links added from existing `guides/billing.md` (or equivalent) to `guides/metering.md`; new metering/portal modules appear in `LatticeStripe` moduledoc resource index

## Future Requirements (v1.2+)

Acknowledged but deferred per locked decisions.

### Metering — advanced

- **METER-FUTURE-01**: `/v2/billing/meter-event-stream` high-throughput streaming variant (D3) — different auth model (15-min session token), different semantics from fire-and-forget `meter_events`
- **METER-FUTURE-02**: Property-based tests for MeterEvent idempotency (StreamData) — deferred alongside broader property test coverage for FormEncoder / pagination cursors

### Portal — configuration

- **PORTAL-FUTURE-01**: `BillingPortal.Configuration` CRUDL (D4) — full resource with deep UX structs (features, business_profile, login). Hosts manage config via Stripe dashboard for v1.1.

### Carryovers from v1.0 charter

- **EXPD-02**: Expand-deserialization into typed structs — `expand:` currently returns string IDs
- **EXPD-03**: Nested expand dot-paths — `expand: ["data.customer"]` parser support
- **EXPD-05**: Status-field atomization audit — sweep for any remaining string-typed status fields across resources

## Out of Scope

Explicitly excluded for v1.1. Reasons must remain valid before these become actionable.

| Feature | Reason |
|---------|--------|
| `/v2/billing/meter-event-stream` | Different auth + semantics; Accrue doesn't need it for Phase 4 (locked D3) |
| `BillingPortal.Configuration` CRUDL | Triples Phase 21 scope; Accrue manages config via Stripe dashboard (locked D4) |
| `MeterEvent` retrieve / list operations | Stripe API does not expose them; events are write-only for clients |
| `Meter` delete operation | Stripe API does not support deletion; deactivate is the only lifecycle exit |
| `Meter` search operation | Stripe API does not expose meter search |
| Release-cut phase (analogue to Phase 19) | Post-1.0 release-please config (PR #8) makes 1.0→1.1 zero-touch; last `feat:` commit auto-triggers release |
| New hex dependencies | Research confirms zero new runtime or test deps needed |
| Dialyzer / Dialyxir | Permanently excluded per project charter — typespecs are documentation only |
| Higher-level billing abstractions (Cashier/Pay analogue) | That is Accrue — separate repo, separate project, consuming LatticeStripe |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| METER-01 | Phase 20 | Pending |
| METER-02 | Phase 20 | Pending |
| METER-03 | Phase 20 | Pending |
| METER-04 | Phase 20 | Pending |
| METER-05 | Phase 20 | Pending |
| METER-06 | Phase 20 | Pending |
| METER-07 | Phase 20 | Pending |
| METER-08 | Phase 20 | Pending |
| METER-09 | Phase 20 | Pending |
| EVENT-01 | Phase 20 | Pending |
| EVENT-02 | Phase 20 | Pending |
| EVENT-03 | Phase 20 | Pending |
| EVENT-04 | Phase 20 | Pending |
| EVENT-05 | Phase 20 | Pending |
| PORTAL-01 | Phase 21 | Pending |
| PORTAL-02 | Phase 21 | Pending |
| PORTAL-03 | Phase 21 | Pending |
| PORTAL-04 | Phase 21 | Pending |
| PORTAL-05 | Phase 21 | Pending |
| PORTAL-06 | Phase 21 | Pending |
| GUARD-01 | Phase 20 | Pending |
| GUARD-02 | Phase 20 | Pending |
| GUARD-03 | Phase 20 | Pending |
| TEST-01 | Phase 20 | Pending |
| TEST-02 | Phase 21 | Pending |
| TEST-03 | Phase 20 | Pending |
| TEST-04 | Phase 21 | Pending |
| TEST-05 (metering: meter lifecycle + event + adjustment integration tests) | Phase 20 | Pending |
| TEST-05 (portal: session create + url shape integration test) | Phase 21 | Pending |
| DOCS-01 | Phase 20 | Pending |
| DOCS-02 | Phase 21 | Pending |
| DOCS-03 ("Billing Metering" group in groups_for_modules + guides/metering.md in extras) | Phase 20 | Pending |
| DOCS-03 ("Customer Portal" group in groups_for_modules + guides/customer-portal.md in extras) | Phase 21 | Pending |
| DOCS-04 | Phase 20 | Pending |

**Coverage:**
- v1.1 requirements: 32 total (counting TEST-05 and DOCS-03 as 1 requirement each, split across phases in execution)
- Mapped to phases: 32
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-14*
*Traceability finalized: 2026-04-13 (roadmap creation)*
*Driven by: `.planning/v1.1-accrue-context.md` (D1–D5) and `.planning/research/SUMMARY.md`*
