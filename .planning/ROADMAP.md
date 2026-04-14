# Roadmap: LatticeStripe

## Milestones

- ✅ **v1.0 — Foundation + Billing + Connect + 1.0 Release** — Phases 1-11, 14-19 (shipped 2026-04-13 to Hex.pm) — [archive](milestones/v1.0-ROADMAP.md)
- 🚧 **v1.1 — Accrue unblockers (metering + portal)** — Phases 20-21 (in progress) — [brief](v1.1-accrue-context.md)

## Phases

<details>
<summary>✅ v1.0 — Foundation + Billing + Connect + 1.0 Release (Phases 1-11, 14-19) — SHIPPED 2026-04-13</summary>

- [x] Phase 1: Transport & Client Configuration (5/5 plans)
- [x] Phase 2: Error Handling & Retry (3/3 plans)
- [x] Phase 3: Pagination & Response (3/3 plans) — cursor lists, `stream!/2`, `expand:` (IDs), API version pinning
- [x] Phase 4: Customers & PaymentIntents (2/2 plans) — first resource modules, pattern validated
- [x] Phase 5: SetupIntents & PaymentMethods (2/2 plans)
- [x] Phase 6: Refunds & Checkout (2/2 plans)
- [x] Phase 7: Webhooks (2/2 plans) — HMAC + Event + Plug
- [x] Phase 8: Telemetry & Observability (2/2 plans) — request spans + webhook verify spans
- [x] Phase 9: Testing Infrastructure (3/3 plans) — stripe-mock integration, `LatticeStripe.Testing`
- [x] Phase 10: Documentation & Guides (3/3 plans) — ExDoc, 16 guides, cheatsheet, README quickstart
- [x] Phase 11: CI/CD & Release (3/3 plans) — Release Please, Hex auto-publish, Dependabot
- ~~Phases 12-13: Product/Price/Coupon/TestClock~~ — deleted in commit `39b98c9`, rebuilt in Phase 14
- [x] Phase 14: Invoices & Invoice Line Items (PR #4)
- [x] Phase 15: Subscriptions & Subscription Items (PR #4)
- [x] Phase 16: Subscription Schedules (PR #4)
- [x] Phase 17: Connect Accounts & Account Links (CNCT-01)
- [x] Phase 18: Connect Money Movement (CNCT-02..CNCT-05) — Transfer, Payout, Balance, BalanceTransaction, ExternalAccount, Charge
- [x] Phase 19: Cross-cutting Polish & v1.0 Release — API surface lock, nine-group ExDoc, `api_stability.md`, CHANGELOG Highlights, release-please 1.0.0 cut

See `.planning/milestones/v1.0-ROADMAP.md` for full phase details and decisions.

</details>

### 🚧 v1.1 — Accrue unblockers

> Full brief: `.planning/v1.1-accrue-context.md` — locked decisions D1-D5, Accrue gap list verbatim, phase structure, entry-point runbook.

- [ ] **Phase 20: Billing Metering** — `Billing.Meter` CRUDL + `deactivate/reactivate`, four nested typed structs, `MeterEvent.create/3`, `MeterEventAdjustment.create/3`, integration tests, `guides/metering.md`
- [ ] **Phase 21: Customer Portal** — `BillingPortal.Session.create/3`, `Session.FlowData` nested struct, integration tests, `guides/customer-portal.md`

**No release phase.** v1.1 ships zero-touch when the last `feat:` commit of Phase 21 lands on main — release-please auto-bumps 1.0.0 → 1.1.0, tags, and publishes to Hex. See `v1.1-accrue-context.md` for why (post-1.0 cleanup in PR #8 flipped `bump-minor-pre-major` to `false`).

## Phase Details

### Phase 20: Billing Metering
**Goal**: Elixir developers (and Accrue) can configure usage-based billing meters, report metered usage events with correct idempotency, and make corrections — all with behavior and failure modes clearly documented so the silent-failure modes of Stripe's async metering pipeline cannot silently corrupt billing data.
**Depends on**: Nothing new — all v1.0 infrastructure (Client, Transport, Resource helpers, Telemetry) unchanged.
**Requirements**: METER-01, METER-02, METER-03, METER-04, METER-05, METER-06, METER-07, METER-08, METER-09, EVENT-01, EVENT-02, EVENT-03, EVENT-04, EVENT-05, GUARD-01, GUARD-02, GUARD-03, TEST-01, TEST-03, TEST-05 (metering side), DOCS-01, DOCS-03 (Billing Metering group), DOCS-04
**Success Criteria** (what must be TRUE):
  1. A developer can call `Billing.Meter.create/3` with `formula: "sum"` and `value_settings` present, then report events via `MeterEvent.create/3`, and the phase's test suite passes against stripe-mock — including deactivate, reactivate, list-by-status, and adjust lifecycles.
  2. `Billing.Meter.create/3` raises `ArgumentError` with a clear message when `default_aggregation.formula` is `"sum"` or `"last"` and `value_settings` is absent from params — the silent-zero billing trap is blocked at call time, before any network round-trip.
  3. `MeterEvent.create/3` `@doc` documents both idempotency layers (`identifier` body field and `idempotency_key:` opt) with separate labeled explanations, and explicitly states that `{:ok, %MeterEvent{}}` is an "accepted for processing" acknowledgment — not a billing confirmation — with a pointer to the `v1.billing.meter.error_report_triggered` webhook.
  4. `MeterEventAdjustment.create/3` `@doc` shows the exact `cancel.identifier` nested param shape (not top-level `identifier`, not `id`) and unit tests assert correct `from_map/1` decoding of `cancel.identifier`.
  5. The new `guides/metering.md` contains a Monitoring section covering `v1.billing.meter.error_report_triggered` error codes, a two-layer idempotency example with a stable domain-derived `identifier`, a backdating window warning with exact error codes, and cross-links from `guides/billing.md` (or equivalent) land correctly.
**Plans**: TBD

### Phase 21: Customer Portal
**Goal**: Elixir developers (and Accrue) can create a Stripe customer portal session with a single function call, receiving a short-lived URL they can redirect customers to — with deep-link flow support and early validation that prevents server-side 400s for missing required sub-fields.
**Depends on**: Phase 20 (code-independent; Phase 20 must be planned first per locked D5, but no function in `BillingPortal.Session` calls anything in `Billing.Meter`)
**Requirements**: PORTAL-01, PORTAL-02, PORTAL-03, PORTAL-04, PORTAL-05, PORTAL-06, TEST-02, TEST-04, TEST-05 (portal side), DOCS-02, DOCS-03 (Customer Portal group)
**Success Criteria** (what must be TRUE):
  1. `BillingPortal.Session.create/3` with a valid `customer` ID returns `{:ok, %Session{url: url}}` where `url` is a non-empty string, verified in an integration test against stripe-mock.
  2. `Session.create/3` raises `ArgumentError` before any network call when `customer` is missing, and raises `ArgumentError` with a flow-type-specific message when `flow_data.type` is `"subscription_cancel"`, `"subscription_update"`, or `"subscription_update_confirm"` but the required nested sub-field (`subscription`, `items`) is absent.
  3. `Session.create/3` raises `ArgumentError` with a clear message when an unknown `flow_data.type` string is passed — unknown flow types are caught at the SDK boundary, not silently forwarded to Stripe.
  4. The `BillingPortal.Session` struct's `Inspect` implementation masks the `:url` field (the URL is a single-use auth token and must not appear in logs).
**Plans**: TBD
**UI hint**: no

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-11, 14-19 | v1.0 | All | ✅ Shipped | 2026-04-13 |
| 20. Billing Metering | v1.1 | 0/6 | Not started | — |
| 21. Customer Portal | v1.1 | 0/4 | Not started | — |
