# Roadmap: LatticeStripe

## Milestones

- ✅ **v1.0 — Foundation + Billing + Connect + 1.0 Release** — Phases 1-11, 14-19 (shipped 2026-04-13 to Hex.pm) — [archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 — Accrue unblockers (metering + portal)** — Phases 20-21 (shipped 2026-04-14) — [brief](v1.1-accrue-context.md)
- ✅ **v1.2 — Production Hardening & DX** — Phases 22-31 (shipped 2026-04-17) — [archive](milestones/v1.2-ROADMAP.md)

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

<details>
<summary>✅ v1.1 — Accrue unblockers (Phases 20-21) — SHIPPED 2026-04-14</summary>

- [x] **Phase 20: Billing Metering** — `Billing.Meter` CRUDL + `deactivate/reactivate`, four nested typed structs, `MeterEvent.create/3`, `MeterEventAdjustment.create/3`, integration tests, `guides/metering.md` (completed 2026-04-14)
- [x] **Phase 21: Customer Portal** — `BillingPortal.Session.create/3`, `Session.FlowData` nested struct, integration tests, `guides/customer-portal.md` (completed 2026-04-14)

</details>

<details>
<summary>✅ v1.2 — Production Hardening & DX (Phases 22-31) — SHIPPED 2026-04-17</summary>

- [x] **Phase 22: Expand Deserialization & Status Atomization** — typed struct dispatch for `expand:`, dot-path support, status field atomization sweep across 84+ modules (completed 2026-04-16)
- [x] **Phase 23: BillingPortal.Configuration CRUDL** — portal branding/features customization resource, Level 1+2 typed structs (completed 2026-04-16)
- [x] **Phase 24: Rate-Limit Awareness & Richer Errors** — `RateLimit-*` header capture via telemetry, fuzzy param name suggestions (completed 2026-04-16)
- [x] **Phase 25: Performance Guide, Per-Op Timeouts & Connection Warm-Up** — `guides/performance.md`, opt-in `Client` timeout field, Finch warm-up helper (completed 2026-04-16)
- [x] **Phase 26: Circuit Breaker & OpenTelemetry Guides** — `:fuse` RetryStrategy guide, OTel guide with Honeycomb/Datadog (completed 2026-04-16)
- [x] **Phase 27: Request Batching** — `LatticeStripe.Batch` with `Task.async_stream`, crash isolation (completed 2026-04-16)
- [x] **Phase 28: meter_event_stream v2** — `Billing.MeterEventStream` session-token API (completed 2026-04-16)
- [x] **Phase 29: Changeset-Style Param Builders** — fluent builders for SubscriptionSchedule + BillingPortal (completed 2026-04-16)
- [x] **Phase 30: Stripe API Drift Detection** — Mix task + GitHub Actions weekly cron (completed 2026-04-16)
- [x] **Phase 31: LiveBook Notebook** — `notebooks/stripe_explorer.livemd` interactive SDK exploration (completed 2026-04-17)

See `.planning/milestones/v1.2-ROADMAP.md` for full phase details and decisions.

</details>

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-11, 14-19 | v1.0 | All | ✅ Shipped | 2026-04-13 |
| 20-21 | v1.1 | 11/11 | ✅ Shipped | 2026-04-14 |
| 22-31 | v1.2 | 24/24 | ✅ Shipped | 2026-04-17 |
