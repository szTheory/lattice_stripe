# Project Research Summary

**Project:** LatticeStripe (Elixir Stripe SDK) — v1.1 Accrue Unblockers
**Domain:** Elixir API client library — metering + customer portal extension to shipped v1.0 SDK
**Researched:** 2026-04-13
**Confidence:** HIGH

## Executive Summary

LatticeStripe v1.1 is a targeted minor release that unblocks Accrue Phase 4 by adding three Stripe resource families to the shipped v1.0 SDK: `Billing.Meter` (CRUDL + `deactivate`/`reactivate` lifecycle verbs), `Billing.MeterEvent` + `Billing.MeterEventAdjustment` (fire-and-forget usage reporting and corrections), and `BillingPortal.Session` (create-only portal redirect). No new dependencies are required — the v1.0 stack (Finch, Jason, Telemetry, Plug, NimbleOptions, Mox, stripe-mock) covers all infrastructure needs. All four Stripe endpoint families are confirmed present in the stripe-mock Docker image with no beta or restricted flags, and the pinned API version `2026-03-25.dahlia` is fully compatible with all three resources.

The recommended build order maps directly to the locked decisions from the v1.1 brief: Phase 20 bundles all three metering resources together (they share fixtures, tests, and the `metering.md` guide, and MeterEvent cannot be meaningfully tested without a Meter), then Phase 21 delivers BillingPortal.Session. Both phases follow the six-plan and four-plan wave structures established in Phase 17 (Connect track): fixtures probe first, then nested structs, then resource modules, then integration tests, then guide and ExDoc. Namespacing follows existing v1.0 precedents — `BillingPortal` is a new top-level namespace (mirrors `Checkout`, not nested under `Billing`) and `MeterEventAdjustment` is a sibling of `MeterEvent` (mirrors `TransferReversal`, not nested).

The critical risks are all documentation and behavioral traps, not architectural novelties. The two most dangerous: MeterEvent has two orthogonal idempotency mechanisms (`identifier` body field for domain-level dedup, `idempotency_key:` opt for HTTP-level dedup) that developers will conflate, and several metering failure modes are asynchronous — Stripe returns HTTP 200 but fires a `v1.billing.meter.error_report_triggered` webhook for customer mapping failures, wrong payload keys, and value type errors. Both require clear module documentation and guide-level warnings, not extra implementation code. The `formula: sum` missing `value_settings` pitfall and the FlowData required sub-fields pitfall should be addressed with early-raising guards in `Meter.create/3` and `Session.create/3` respectively, following established v1.0 patterns.

## Key Findings

### Recommended Stack

No dependencies are added in v1.1. The `mix.exs` `deps/0` block is correct as-is. The only `mix.exs` changes in v1.1 are two additive documentation configuration additions: a `"Billing Metering"` group added to `groups_for_modules` in Plan 20-06, and a `"Customer Portal"` group added in Plan 21-04. These mirror the existing nine-group layout and insert new groups after the existing `"Billing"` group (Invoice, Subscription, etc.). Both groups also require corresponding entries in `extras:` for the new guide files.

**Core technologies (unchanged from v1.0):**
- **Finch ~> 0.21**: default HTTP transport — handles all new endpoint calls with zero changes
- **Jason ~> 1.4**: JSON encode/decode — all four new resource families use the same `from_map/1` pattern
- **:telemetry ~> 1.0**: telemetry events emit automatically at the Client layer for all new resources
- **NimbleOptions ~> 1.0**: option validation for `create/3` opts on all new modules
- **Mox ~> 1.2** (test): Transport behaviour mocking — no changes needed, used identically to v1.0
- **stripe-mock** (CI): all four v1.1 endpoint families confirmed present in the Docker image

**Do not add:** StreamData — property testing not warranted for v1.1 (stripe-mock stateless, `identifier` is a passthrough string). Defer to v1.2+ if property tests are added broadly.

### Expected Features

**Must have (table stakes) — Phase 20:**
- `Billing.Meter.create/3`, `retrieve/3`, `update/4`, `list/3`, `stream!/3` — CRUDL for meter lifecycle
- `Billing.Meter.deactivate/3` + `reactivate/3` — explicit lifecycle verbs (POST to distinct endpoints, not a status mutation)
- `Billing.Meter.DefaultAggregation`, `CustomerMapping`, `ValueSettings`, `StatusTransitions` — four nested typed structs; Accrue reads sub-fields from all four
- `Billing.MeterEvent.create/3` — hot path for usage reporting; `identifier` and `idempotency_key:` both supported independently
- `Billing.MeterEventAdjustment.create/3` — correction flow for over-reported events
- Bang variants (`create!/3`, `deactivate!/3`, etc.) for all above — standard LatticeStripe convention

**Must have (table stakes) — Phase 21:**
- `BillingPortal.Session.create/3` + `create!/3` — create-only (no retrieve/list/update/delete; Stripe API constraint)
- `BillingPortal.Session.FlowData` nested struct — all four flow types with required sub-field validation

**Should have (differentiators):**
- Two-layer idempotency distinction documented clearly in `MeterEvent.create/3` `@doc` — prevents double-billing
- Aggregation formula semantics (`sum`/`count`/`last`) documented in `DefaultAggregation` `@typedoc`
- PII-safe `Inspect` for `MeterEvent` (masks `:payload`) and `BillingPortal.Session` (masks `:url`)
- `v1.billing.meter.error_report_triggered` webhook monitoring section in `guides/metering.md`
- `Resource.require_param!` guard in `Session.create/3` for `"customer"` — fail fast pre-network
- Per-flow-type sub-field validation in `Session.create/3` — fail fast for missing required sub-fields

**Defer to v1.2+:**
- `Billing.MeterEventStream` (D3 locked) — high-throughput streaming; different auth model; Accrue does not need it
- `BillingPortal.Configuration` CRUDL (D4 locked) — full CRUDL with deep UX structs; hosts manage portal config via Stripe Dashboard for v1.1
- `Billing.Meter.EventSummary` — aggregated usage queries per meter; separate API family
- v2 API metering endpoints — requires API version upgrade coordination with Accrue

### Architecture Approach

All three v1.1 resource families slot into the existing v1.0 layered architecture without modifying any foundation layer (Client, Transport, Request, Response, Error, Telemetry, Retry, Webhook). New resource modules occupy the Public API Layer only. Telemetry spans emit automatically at the Client level for all new resources. The `from_map/1` + `@known_fields` + `extra: %{}` tolerance pattern applies to structs that may grow (CustomerMapping, FlowData); simpler structs with fully-known fields use plain `defstruct` without `extra` (DefaultAggregation, ValueSettings, StatusTransitions).

**New components — Phase 20:**
1. `lib/lattice_stripe/billing/meter.ex` — Meter resource module; CRUDL + lifecycle verbs
2. `lib/lattice_stripe/billing/meter/{default_aggregation,customer_mapping,value_settings,status_transitions}.ex` — four nested typed structs
3. `lib/lattice_stripe/billing/meter_event.ex` — MeterEvent resource module; create-only
4. `lib/lattice_stripe/billing/meter_event_adjustment.ex` — MeterEventAdjustment resource module; create-only (sibling, not nested)
5. `test/support/fixtures/metering.ex` — single fixture module for all three metering resources
6. `test/integration/meter_integration_test.exs` — integration tests against stripe-mock
7. `guides/metering.md` — new guide

**New components — Phase 21:**
1. `lib/lattice_stripe/billing_portal/session.ex` — Session resource module; create-only
2. `lib/lattice_stripe/billing_portal/session/flow_data.ex` — FlowData nested struct
3. `test/support/fixtures/billing_portal.ex` — fixture module for portal resources
4. `test/integration/billing_portal_session_integration_test.exs` — integration tests
5. `guides/customer-portal.md` — new guide

**Namespacing decisions (locked):**
- `LatticeStripe.BillingPortal` is a new top-level namespace (not nested under `Billing`). Stripe uses `/v1/billing_portal/` as a distinct prefix; pattern follows `LatticeStripe.Checkout.Session` precedent.
- `LatticeStripe.Billing.MeterEventAdjustment` is a sibling of `MeterEvent` (not nested). Stripe's endpoint is `/v1/billing/meter_event_adjustments` — a top-level resource. Mirrors `LatticeStripe.TransferReversal` precedent.

### Critical Pitfalls

1. **MeterEvent two-layer idempotency trap** (Phase 20, Plans 20-04 + 20-06) — `identifier` in the request body and `idempotency_key:` opt operate at different layers and are not interchangeable. Omitting a stable `identifier` allows double-billing on process-restart retries even when `idempotency_key:` is used. Prevention: document both in `MeterEvent.create/3` `@doc` with separate labels; `guides/metering.md` must show the recommended pattern of passing both with a stable domain-derived identifier.

2. **customer_mapping key silent-drop** (Phase 20, Plans 20-04 + 20-06) — if the MeterEvent payload is missing the customer mapping key, Stripe returns HTTP 200 but fires `v1.billing.meter.error_report_triggered` asynchronously. The event is silently dropped. Prevention: document in `create/3` `@doc` that `{:ok, %MeterEvent{}}` is an "accepted for processing" ack, not a billing confirmation; `guides/metering.md` must include a monitoring section covering `meter_event_no_customer_defined` / `meter_event_customer_not_found`.

3. **formula: sum + missing value_settings silent-zero** (Phase 20, Plans 20-02 + 20-03) — a Meter with `formula: "sum"` but no `value_settings` defaults to key `"value"`. MeterEvents without that key produce async errors and zero usage at billing time. Prevention: add an early-raising guard in `Meter.create/3` when formula is `"sum"` or `"last"` and `value_settings` is absent; document formula semantics in `DefaultAggregation` `@typedoc`.

4. **MeterEventAdjustment cancel.identifier exact field** (Phase 20, Plan 20-04) — the cancel sub-object uses `cancel.identifier` (nested), not `"identifier"` at the top level and not `"id"`. Stripe returns a 400 on mismatch. The 24-hour cancellation window is not enforced by stripe-mock. Prevention: show the exact param map shape in `create/3` `@doc` with a code example; assert correct `from_map/1` decoding in unit tests.

5. **FlowData required sub-field server-side 400** (Phase 21, Plan 21-03) — `subscription_cancel`, `subscription_update`, and `subscription_update_confirm` flow types each require specific sub-fields that Stripe only validates after the round-trip. Prevention: add a per-flow-type validation guard in `Session.create/3` that raises `ArgumentError` before the network call, following the `pause_collection/5` atom guard precedent.

6. **Timestamp backdating window** (Phase 20, Plans 20-04 + 20-06) — MeterEvent `timestamp` must be within the past 35 calendar days and no more than 5 minutes in the future. Batch-flush anti-patterns produce silent 400s. Prevention: document with exact error codes (`timestamp_too_far_in_past`, `timestamp_in_future`) in `create/3` `@doc` and as a guide anti-pattern section.

7. **Events to inactive meter (archived_meter)** (Phase 20, Plans 20-03 + 20-04) — deactivating a meter causes all subsequent MeterEvents with that `event_name` to fail with `archived_meter`. Events submitted during the inactive period are permanently lost. Prevention: document `deactivate/3` behavior; add non-retry guidance to `MeterEvent.create/3` `@doc`.

## Implications for Roadmap

Based on combined research, the two-phase structure is already locked (D1-D5 in `.planning/v1.1-accrue-context.md`). The plan-level structure within each phase follows the Phase 17 wave pattern.

### Phase 20: Billing Metering (Meter + MeterEvent + MeterEventAdjustment)

**Rationale:** Metering is the higher-priority Accrue unblock (BILL-11 is the hot path for all usage reporting). MeterEvent cannot be meaningfully exercised without a Meter. MeterEventAdjustment adds ~30 lines in the same plan as MeterEvent with tight cohesion. All three share fixtures and a single guide.
**Delivers:** Full `Billing.Meter` CRUDL + lifecycle verbs with four nested structs, `Billing.MeterEvent.create/3`, `Billing.MeterEventAdjustment.create/3`, integration tests, `guides/metering.md`, ExDoc group
**Addresses:** Accrue BILL-11; pitfalls 1-4, 6-7
**Plan structure (6 plans):**
- Plan 20-01: Wave 0 bootstrap — `test/support/fixtures/metering.ex`, stripe-mock endpoint probe
- Plan 20-02: Nested structs — four `Meter.*` sub-modules with `from_map/1` unit tests; formula semantics in `DefaultAggregation` `@typedoc`
- Plan 20-03: `Billing.Meter` resource module — CRUDL + `deactivate`/`reactivate` + bang variants; `formula:sum` guard in `create/3`
- Plan 20-04: `Billing.MeterEvent` + `Billing.MeterEventAdjustment` — create-only for both; idempotency two-layer docs; `cancel.identifier` unit tests; `archived_meter` non-retry guidance
- Plan 20-05: Integration tests — full lifecycle against stripe-mock; stripe-mock limitation comments
- Plan 20-06: Guide + ExDoc — `guides/metering.md`; `"Billing Metering"` group in `groups_for_modules`; `mix.exs extras:` entry

### Phase 21: Customer Portal (BillingPortal.Session)

**Rationale:** Smaller scope (4 plans vs. 6); no code dependency on Phase 20; can begin planning immediately after Phase 20 scope is locked. Unblocks Accrue CHKT-02 (single create call, portal URL redirect).
**Delivers:** `BillingPortal.Session.create/3` + `create!/3`, `Session.FlowData` nested struct with all four flow types and required sub-field validation, integration test, `guides/customer-portal.md`, ExDoc group
**Addresses:** Accrue CHKT-02; pitfall 5
**Plan structure (4 plans):**
- Plan 21-01: Wave 0 bootstrap — `test/support/fixtures/billing_portal.ex`, stripe-mock endpoint probe for `/v1/billing_portal/sessions`
- Plan 21-02: Nested structs — `Session.FlowData` with `@known_fields + extra` pattern; unit tests
- Plan 21-03: `BillingPortal.Session` resource module — `create/3` + `create!/3`; `customer` require guard; per-flow-type sub-field validation; PII-safe `Inspect` for `:url`
- Plan 21-04: Integration test + guide — `guides/customer-portal.md`; `"Customer Portal"` group in `groups_for_modules`; `mix.exs extras:` entry

### Phase Ordering Rationale

- Phase 20 before Phase 21: metering is higher-priority Accrue blocker, larger scope, and must be solid before the milestone ships.
- Phase 21 is independent at the code level: no function in `BillingPortal.Session` calls anything in `Billing.Meter`. Planning for Phase 21 can begin while Phase 20 is executing.
- Within Phase 20: 20-02 must precede 20-03. 20-03 and 20-04 may be parallelized. 20-05 requires both 20-03 and 20-04.
- Within Phase 21: strictly sequential (21-01 → 21-02 → 21-03 → 21-04).
- **No Phase 22 release phase.** Post-1.0 `release-please-config.json` (`bump-minor-pre-major: false`, no `release-as`) makes 1.0→1.1 zero-touch. The last `feat:` commit of Phase 21 auto-triggers release-please. Do not add a release phase by analogy with Phase 19.

### Research Flags

All phases follow well-established v1.0 patterns. No `/gsd-research-phase` runs are needed.

**Standard patterns (no additional research):**
- **Phase 20 (Plans 20-01 to 20-03):** Meter CRUDL + lifecycle verb pattern is identical to existing resources (`Payout.cancel/4`, `Account.reject/4`). Nested struct pattern is identical to `Invoice.StatusTransitions` and `Subscription.CancellationDetails`.
- **Phase 20 (Plan 20-04):** MeterEvent and MeterEventAdjustment are both create-only with minimal structs. Two-layer idempotency documentation is fully specified in FEATURES.md and PITFALLS.md.
- **Phase 20 (Plan 20-05):** Integration test structure is identical to `test/integration/account_integration_test.exs`. stripe-mock limitations for dedup windows are known and must be commented.
- **Phase 20 (Plan 20-06):** ExDoc group extension pattern is established. Guide content is fully specified in FEATURES.md and PITFALLS.md.
- **Phase 21 (all plans):** `BillingPortal.Session` mirrors `Checkout.Session` (create-only, short-lived URL, required param guard). FlowData pattern mirrors `Subscription.CancellationDetails`. Per-flow-type validation guard mirrors `pause_collection/5`.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All endpoints confirmed in Stripe OpenAPI spec3.json; all confirmed present in stripe-mock Docker image; no beta/restricted flags; zero new deps required |
| Features | HIGH | Stripe API docs verified for all four resources; Accrue minimum API surfaces enumerated in v1.1-accrue-context.md; anti-features locked in decisions D1-D5 |
| Architecture | HIGH | All namespacing and struct decisions grounded in existing v1.0 precedents (Checkout.Session, TransferReversal, Invoice.StatusTransitions, Subscription.CancellationDetails) |
| Pitfalls | HIGH | All 7 pitfalls sourced from Stripe API docs with exact error codes; stripe-mock statelessness limitations confirmed; v1.0 precedent patterns identified for each guard/doc requirement |

**Overall confidence:** HIGH

### Gaps to Address

- **stripe-mock metering endpoint availability**: Plan 20-01 must probe all three metering endpoints against the local stripe-mock Docker image. Endpoints are confirmed in the OpenAPI spec, but the wave-0 plan documents a fallback to fixture-only unit tests if any endpoint is absent. Low-probability risk; the probe is the safety net.
- **stripe-mock FlowData sub-field enforcement**: stripe-mock may or may not enforce required sub-fields for portal flow types. The Plan 21-03 validation guard handles this at the SDK boundary regardless; the integration test should document which validations are SDK-side vs. server-side.
- **formula: sum guard as warning vs. blocking error**: research recommends raising `ArgumentError` when `formula` is `"sum"` or `"last"` and `value_settings` is absent — but Stripe itself allows omitting `value_settings`. Plan 20-03 must make a final call. Either is acceptable as long as the guide documents the implicit contract.

## Sources

### Primary (HIGH confidence)
- [Stripe OpenAPI spec3.json](https://github.com/stripe/openapi) — all four v1.1 endpoint families confirmed present, no beta/restricted flags (parsed directly, 2026-04-13)
- [Stripe Billing Meter API Reference](https://docs.stripe.com/api/billing/meter) — object fields, status values, formula enum
- [Stripe MeterEvent Create](https://docs.stripe.com/api/billing/meter-event/create) — `identifier` field, 24-hour dedup window, 100-char max
- [Stripe Recording Usage API Guide](https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api) — timestamp 35-day window, async validation, error codes
- [Stripe MeterEventAdjustment Object](https://docs.stripe.com/api/billing/meter-event-adjustment/object) — `cancel.identifier` field, 24-hour cancellation window
- [Stripe BillingPortal Session Create](https://docs.stripe.com/api/customer_portal/sessions/create) — `flow_data` parameter structure, `on_behalf_of` semantics
- [Stripe Portal Deep Links Guide](https://docs.stripe.com/customer-management/portal-deep-links) — all four flow types, required sub-fields per type
- [stripe-mock on GitHub](https://github.com/stripe/stripe-mock) — Docker image; confirmed stateless; dedup/time windows not simulated
- [Stripe Changelog: deprecate legacy usage-based billing](https://docs.stripe.com/changelog/basil/2025-03-31/deprecate-legacy-usage-based-billing) — meters canonical post-2025-03-31.basil

### Secondary (project-internal)
- `.planning/v1.1-accrue-context.md` — authoritative v1.1 brief; locked decisions D1-D5; Accrue minimum API surfaces
- `.planning/research/STACK.md` — v1.1 addendum confirming zero new deps; mix.exs docs-config changes
- `.planning/research/FEATURES.md` — full feature categorization for all three resource families
- `.planning/research/ARCHITECTURE.md` — namespacing decisions, nested struct patterns, build order, file manifest
- `.planning/research/PITFALLS.md` — all 7 critical pitfalls with phase assignments and code-level prevention

---
*Research completed: 2026-04-13*
*Ready for roadmap: yes*
