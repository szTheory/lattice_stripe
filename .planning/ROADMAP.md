# Roadmap: LatticeStripe

## Milestones

- ✅ **v1.0 — Foundation + Billing + Connect + 1.0 Release** — Phases 1-11, 14-19 (shipped 2026-04-13 to Hex.pm) — [archive](milestones/v1.0-ROADMAP.md)
- 🚧 **v1.1 — Accrue unblockers (metering + portal)** — Phases 20-21 (planned) — [brief](v1.1-accrue-context.md)

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

### 🚧 v1.1 — Accrue unblockers (Planned)

> Full brief: `.planning/v1.1-accrue-context.md` — locked decisions D1-D5, Accrue gap list verbatim, phase structure, entry-point runbook.

- [ ] Phase 20: Billing metering — `Billing.Meter` CRUDL + `deactivate/reactivate`, `Billing.MeterEvent.create/3`, `Billing.MeterEventAdjustment.create/3` (~6 plans)
- [ ] Phase 21: Customer portal — `BillingPortal.Session.create/3` only (~4 plans)

**No release phase.** v1.1 ships zero-touch when the last `feat:` commit of Phase 21 lands on main — release-please auto-bumps 1.0.0 → 1.1.0, tags, and publishes to Hex. See `v1.1-accrue-context.md` for why (post-1.0 cleanup in PR #8 flipped `bump-minor-pre-major` to `false`).

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-11, 14-19 | v1.0 | All | ✅ Shipped | 2026-04-13 |
| 20 | v1.1 | 0 | 📋 Planned | — |
| 21 | v1.1 | 0 | 📋 Planned | — |
