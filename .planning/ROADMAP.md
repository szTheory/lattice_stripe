# Roadmap: LatticeStripe

## Milestones

- ✅ **v1.0 Foundation & Payments** — Phases 1–11 (shipped 2026-04-04 as Hex `lattice_stripe` v0.2.0) — see [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)
- 📋 **v2.0 Billing & Connect** — Phases 12–19 (planned, targets Hex `lattice_stripe` v0.3.0)

## Phases

<details>
<summary>✅ v1.0 Foundation & Payments (Phases 1–11) — SHIPPED 2026-04-04</summary>

- [x] Phase 1: Transport & Client Configuration (5/5 plans) — 2026-04-01
- [x] Phase 2: Error Handling & Retry (3/3 plans) — 2026-04-01
- [x] Phase 3: Pagination & Response (3/3 plans) — 2026-04-02
- [x] Phase 4: Customers & PaymentIntents (2/2 plans) — 2026-04-02
- [x] Phase 5: SetupIntents & PaymentMethods (2/2 plans) — 2026-04-02
- [x] Phase 6: Refunds & Checkout (2/2 plans) — 2026-04-03
- [x] Phase 7: Webhooks (2/2 plans) — 2026-04-03
- [x] Phase 8: Telemetry & Observability (2/2 plans) — 2026-04-03
- [x] Phase 9: Testing Infrastructure (3/3 plans) — 2026-04-03
- [x] Phase 10: Documentation & Guides (4/4 plans) — 2026-04-03
- [x] Phase 11: CI/CD & Release (3/3 plans) — 2026-04-04

Full details: [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)

</details>

### 📋 v2.0 Billing & Connect (Phases 12–19)

v2.0 is a pure resource-surface milestone on top of the v1 foundation — zero new runtime dependencies, zero behaviour additions, zero modifications to HTTP/retry/pagination primitives. Build order is strictly topological: Billing catalog → test clocks (pulled forward) → invoices → subscriptions (with proration discipline) → schedules → Connect accounts → Connect money → cross-cutting polish. Optional v0.3.0-rc1 cut at the Phase 16 boundary; v0.3.0 final after Phase 19.

- [x] **Phase 12: Billing Catalog** — Products, Prices, Coupons, PromotionCodes (+ FormEncoder battery for triple-nested shapes) (completed 2026-04-12)
- [x] **Phase 13: Billing Test Clocks** — TestClock resource, `advance_and_wait/3`, `Testing.TestClock` helper, cleanup Mix task, first `:real_stripe` tier tests (completed 2026-04-12)
- [ ] **Phase 14: Invoices & Invoice Line Items** — Full Invoice CRUD + action verbs (finalize/void/pay/send/mark_uncollectible) + `upcoming/2` preview + auto-advance race mitigation
- [ ] **Phase 15: Subscriptions & Subscription Items** — Full subscription lifecycle + `ProrationBehavior` validator + `require_explicit_proration` client flag + state machine docs
- [ ] **Phase 16: Subscription Schedules** — Schedule CRUD + release vs cancel semantics + schedule-owned subscription warnings + v0.3.0-rc1 cut decision
- [ ] **Phase 17: Connect Accounts & Links** — Account/AccountLink/LoginLink + `Client.with_account/2` + `LatticeStripe.Connect` namespace + Context Matrix
- [ ] **Phase 18: Connect Money Movement** — Transfers (+ reversals), Payouts, Balance singleton, BalanceTransactions
- [ ] **Phase 19: Cross-cutting Polish & v0.3.0 Release** — EventType catalog + OpenAPI drift test, Search facade, Billing/Connect guides, milestone smoke test, Hex v0.3.0 release

## Phase Details

### Phase 12: Billing Catalog
**Goal**: Developers can manage the Stripe billing catalog — Products, Prices, Coupons, and PromotionCodes — as idiomatic Elixir resources
**Depends on**: v1.0 (Phase 11)
**Requirements**: BILL-01, BILL-02, BILL-06, BILL-06b
**Success Criteria** (what must be TRUE):
  1. Developer can create, retrieve, update, list, stream, and search Products and Prices using the same v1 resource template (no `Price.delete/2`, no `Coupon.update/3` — Stripe API constraints are surfaced as missing functions, not runtime errors)
  2. Developer can create, retrieve, delete, list, and stream Coupons, and manage PromotionCodes (including update) — with PromotionCode `search/2` shipped only if verified against the live Stripe API during this phase
  3. Developer can pass triple-nested inline shapes (e.g. `items[0][price_data][recurring][interval]`) through the form encoder and the request round-trips against stripe-mock cleanly — regression-guarded by an explicit `FormEncoder` unit battery
  4. Every `search/2` `@doc` in this phase carries an eventual-consistency callout, matching H3 guidance
**Plans**: 7 plans

Plans:
- [x] 12-01-PLAN.md — Wave 0 test infrastructure (stream_data dep + test stubs for all Phase 12 resources)
- [x] 12-02-PLAN.md — FormEncoder D-09f float fix + D-09a..e regression battery + StreamData property layer
- [x] 12-03-PLAN.md — LatticeStripe.Discount module (D-08) + Customer.discount backfill (D-02)
- [x] 12-04-PLAN.md — LatticeStripe.Product (BILL-01) with D-03 atomization + D-10 search callout
- [x] 12-05-PLAN.md — LatticeStripe.Price + Price.Recurring + Price.Tier typed nesteds (BILL-02) — no delete (D-05)
- [x] 12-06-PLAN.md — LatticeStripe.Coupon + Coupon.AppliesTo (BILL-06) — no update, no search (D-05) + tightened Discount coupon dispatch
- [x] 12-07-PLAN.md — LatticeStripe.PromotionCode (BILL-06b) — no search, no delete; list-filter discovery path (D-06)

### Phase 13: Billing Test Clocks
**Goal**: Developers can deterministically time-travel billing fixtures in tests, unblocking subscription/invoice lifecycle coverage in later phases
**Depends on**: Phase 12
**Requirements**: BILL-08, BILL-08b, BILL-08c, TEST-09, TEST-10
**Success Criteria** (what must be TRUE):
  1. Developer can create, retrieve, list, stream, delete, and advance Billing Test Clocks as a first-class SDK resource
  2. Developer can call `BillingTestClock.advance_and_wait/3` with a configurable timeout and receive either the ready clock or `{:error, :timeout}` — no more silent reads of `status: "advancing"` stale state
  3. Developer can `use LatticeStripe.Testing.TestClock` in their own test suite to coordinate test clock + customer + subscription fixtures with automatic cleanup, and can run `mix lattice_stripe.test_clock.cleanup` (or the equivalent ExUnit helper) to purge tagged clocks and stay under the 100-clock-per-account Stripe limit
  4. The first `@tag :real_stripe` integration test in the repo exercises a clock advancement end-to-end against real Stripe test mode, gated by `STRIPE_TEST_SECRET_KEY`, documenting the two-tier strategy pattern the rest of the milestone will follow
**Plans**: TBD

### Phase 14: Invoices & Invoice Line Items
**Goal**: Developers can manage the full invoice lifecycle — draft creation, line items, action verbs, and proration preview — without tripping Stripe's auto-finalization race
**Depends on**: Phase 13
**Requirements**: BILL-04, BILL-04b, BILL-04c, BILL-10
**Success Criteria** (what must be TRUE):
  1. Developer can create, retrieve, update, list, stream, and search Invoices, and drive the action verbs `finalize/2`, `pay/2+3`, `void/2`, `mark_uncollectible/2`, and `send/2` as first-class functions rather than magic `update` params
  2. Developer can call `Invoice.upcoming/2` and get back a typed Invoice struct with `id: nil`, suitable for previewing proration impact before confirming a subscription change
  3. Developer can list Invoice Line Items for an invoice and also read them off an `Invoice` struct's typed `:lines` field — no raw map access required
  4. When `auto_advance` is omitted on `Invoice.create/2`, a telemetry event fires warning of the ~1h auto-finalization window, and the Invoice guide documents the canonical `create → add_invoice_items → finalize → pay` order (C4 mitigation)
  5. Developer who calls `Invoice.upcoming/2` or any other mutation path while `require_explicit_proration: true` is set gets a typed `{:error, %Error{type: :proration_required}}` instead of Stripe's endpoint-dependent default (C1 mitigation, forward-wired from Phase 15)
**Plans**: TBD

### Phase 15: Subscriptions & Subscription Items
**Goal**: Developers can manage the full subscription lifecycle with proration discipline and a documented state machine — the semantics-heavy center of the milestone
**Depends on**: Phase 14
**Requirements**: BILL-03, BILL-03b, BILL-03c, BILL-03d, BILL-03e, BILL-03f, UTIL-03, UTIL-04
**Success Criteria** (what must be TRUE):
  1. Developer can create, retrieve, update, list, stream, and search Subscriptions, and can cancel in two distinct modes — immediate (`cancel/2`) and scheduled (`cancel/3` with `cancel_at_period_end: true`) — with `Subscription.cancellation_pending?/1` returning `true` for the scheduled-but-still-active case (H1 mitigation)
  2. Developer can pause and resume Subscriptions via dedicated `pause/3` and `resume/3` action verbs mapping to Stripe's dedicated endpoint, with the `@doc` clearly distinguishing these from the `pause_collection` update param
  3. Developer can manage Subscription Items (create/retrieve/update/delete/list) as a nested child resource following the `Checkout.LineItem` precedent
  4. Developer can opt into strict proration mode via `require_explicit_proration: true` on the Client struct and receive a clear `{:error, %Error{type: :proration_required}}` when calling any Subscription/SubscriptionItem/Invoice mutation that omits `proration_behavior`; in the default (off) mode, the param passes through transparently for parity with stripe-ruby/node/python (C1 primary mitigation)
  5. `LatticeStripe.Billing.ProrationBehavior.validate!/1` accepts exactly `"create_prorations"`, `"always_invoice"`, `"none"` as strings and rejects atoms or unknown values with an `ArgumentError` that points at the string form
  6. The `Subscription` `@moduledoc` documents the complete lifecycle state machine — including the `incomplete → incomplete_expired` 23-hour one-way edge, the webhook event sequence, and the fact that the transition fires as `customer.subscription.updated` not `.deleted` — and `Subscription.status_is_terminal?/1` returns `true` for `incomplete_expired`, `canceled`, and `unpaid` (C2 + H1 mitigation)
**Plans**: TBD

### Phase 16: Subscription Schedules
**Goal**: Developers can manage planned upgrade/downgrade trajectories via SubscriptionSchedule, with clear ownership boundaries between schedule and subscription
**Depends on**: Phase 15
**Requirements**: BILL-09, BILL-09b, BILL-09c, REL-03
**Success Criteria** (what must be TRUE):
  1. Developer can create, retrieve, update, cancel, release, list, and stream Subscription Schedules, with `release/2` and `cancel/2` documented as the two distinct escape hatches
  2. Developer can pattern-match `%Subscription{schedule: nil}` vs schedule-owned subscriptions because `:schedule` is surfaced as a typed field on the `Subscription` struct
  3. `Subscription.update/3`'s `@doc` carries a loud warning that mutating a schedule-owned subscription conflicts with phase transitions, and recommends `SubscriptionSchedule.release/2` as the escape hatch (C5 mitigation)
  4. A v0.3.0-rc1 release mechanism is chosen (manual git tag vs Release Please prerelease manifest) and documented in CONTRIBUTING, and either the rc1 tag is cut or a conscious decision is logged to defer to v0.3.0 final (M4 mitigation)
**Plans**: TBD

### Phase 17: Connect Accounts & Links
**Goal**: Developers can onboard and manage Stripe Connect accounts with the platform/connected-account context switch made explicit and greppable
**Depends on**: Phase 16
**Requirements**: CNCT-01, CNCT-01b, CNCT-01c, CNCT-06, CNCT-07
**Success Criteria** (what must be TRUE):
  1. Developer can create, retrieve, update, (where Stripe permits) delete, list, and stream connected Accounts, with `@doc` callouts documenting the Standard/Express/Custom deletion and update constraints (H7 mitigation — Standard live accounts are not deletable; point at oauth deauthorization)
  2. Developer can create AccountLinks for onboarding/update flows and LoginLinks for Express dashboard access — write-only resources with the sensitive `url` field hidden from `Inspect` output
  3. Developer can call `LatticeStripe.Client.with_account(client, "acct_xxx")` to get a new Client struct with the `Stripe-Account` header baked in, making per-tenant code paths explicit and greppable across a codebase (C3 mitigation)
  4. The `LatticeStripe.Connect` namespace module ships with a top-level warning explaining that `stripe_account` is a context switch (platform vs connected account are different data universes), and the Connect guide includes a Context Matrix table documenting which resources must/must-not carry the header
  5. Telemetry metadata on every request span exposes `stripe_account: "acct_xxx" | nil` for log-based cross-tenant auditing
**Plans**: TBD
**UI hint**: yes

### Phase 18: Connect Money Movement
**Goal**: Developers can move money across the Connect graph — Transfers, Payouts, Balance, BalanceTransactions — with the Transfer-vs-Payout distinction made impossible to confuse
**Depends on**: Phase 17
**Requirements**: CNCT-02, CNCT-02b, CNCT-05, CNCT-05b, CNCT-04
**Success Criteria** (what must be TRUE):
  1. Developer can create, retrieve, list, and stream Transfers, and can reverse a Transfer via a dedicated `Transfer.reverse/3` verb mapping to the nested reversal endpoint
  2. Developer can create, retrieve, update, cancel, reverse, list, and stream Payouts, with `@moduledoc` loudly distinguishing Transfer (platform → connected account) from Payout (Stripe → bank)
  3. Developer can retrieve the Balance singleton (`Balance.retrieve/1` — no ID) scoped to any Connect context via the Client's `stripe_account` header, and can retrieve and list/stream BalanceTransactions as a read-only resource
  4. The Connect guide documents both destination-charge (existing v1 `PaymentIntent` with `transfer_data` / `on_behalf_of`) and separate-charge-and-transfer patterns with working code examples using `Client.with_account/2`
**Plans**: TBD

### Phase 19: Cross-cutting Polish & v0.3.0 Release
**Goal**: The milestone ships as Hex `lattice_stripe` v0.3.0 — exhaustive EventType catalog, Search facade, Billing + Connect guides, end-to-end smoke test, and release automation discipline
**Depends on**: Phase 18
**Requirements**: UTIL-01, UTIL-01b, UTIL-01c, UTIL-02, UTIL-05, UTIL-06, TEST-07, TEST-08, DOCS-05, DOCS-06, DOCS-07, DOCS-08, DOCS-09, DOCS-10, DOCS-11, REL-01, REL-02, REL-04
**Success Criteria** (what must be TRUE):
  1. Developer can reference every Stripe webhook event type for API version `2026-03-25.dahlia` via `LatticeStripe.EventType` — each event as both a `@attribute` and a `foo/0` function, grouped by `billing_events/0`, `payment_events/0`, `connect_events/0`, `subscription_events/0`, `invoice_events/0`, and `all/0`, with string values matching wire format (M1 mitigation)
  2. A weekly GitHub Actions workflow runs `mix lattice_stripe.gen.event_types` against the vendored `test/fixtures/stripe_openapi_events.json`, and an ExUnit test tagged `:openapi_sync` fails CI and opens an issue when the Stripe OpenAPI spec drifts from `LatticeStripe.EventType.all/0`
  3. Developer can read `LatticeStripe.Search` module docs explaining the search pagination shape (`page`/`next_page` vs list's `starting_after`/`ending_before`) and every searchable resource's `search/2` `@doc` links to it and carries an eventual-consistency callout (H3 + UTIL-02 + UTIL-06 mitigation — `LatticeStripe.Search` is a thin facade, not a new engine module)
  4. Developer can call `LatticeStripe.Event.created_at/1` to get a `DateTime` from an event's unix `created` timestamp, and the Webhooks guide "Handling out-of-order events" section uses it in an idempotent-upsert example (H2 mitigation)
  5. Developer can follow the Billing guide from install to first Subscription (with explicit `proration_behavior`) and the Connect guide from install to first destination charge, with every new v2 resource covered by a worked example; Subscription and Invoice lifecycle reference pages document state machines and auto-advance races respectively
  6. The testing guide documents the two-tier `@tag :real_stripe` integration strategy, a milestone smoke test exercises end-to-end `Product → Price → Customer → Subscription → Invoice → pay` against stripe-mock, and CONTRIBUTING documents Conventional Commit scopes (`feat(billing):`, `feat(connect):`, `feat(sdk):`) for Release Please v4
  7. `lattice_stripe` v0.3.0 is published to Hex via Release Please after this phase merges to `main`, with README version badge and Billing/Connect sections updated
**Plans**: TBD

## Progress

| Phase                                     | Milestone | Plans Complete | Status      | Completed  |
|-------------------------------------------|-----------|----------------|-------------|------------|
| 1. Transport & Client Config              | v1.0      | 5/5            | Complete    | 2026-04-01 |
| 2. Error Handling & Retry                 | v1.0      | 3/3            | Complete    | 2026-04-01 |
| 3. Pagination & Response                  | v1.0      | 3/3            | Complete    | 2026-04-02 |
| 4. Customers & PaymentIntents             | v1.0      | 2/2            | Complete    | 2026-04-02 |
| 5. SetupIntents & PaymentMethods          | v1.0      | 2/2            | Complete    | 2026-04-02 |
| 6. Refunds & Checkout                     | v1.0      | 2/2            | Complete    | 2026-04-03 |
| 7. Webhooks                               | v1.0      | 2/2            | Complete    | 2026-04-03 |
| 8. Telemetry & Observability              | v1.0      | 2/2            | Complete    | 2026-04-03 |
| 9. Testing Infrastructure                 | v1.0      | 3/3            | Complete    | 2026-04-03 |
| 10. Documentation & Guides                | v1.0      | 4/4            | Complete    | 2026-04-03 |
| 11. CI/CD & Release                       | v1.0      | 3/3            | Complete    | 2026-04-04 |
| 12. Billing Catalog                       | v2.0      | 7/7 | Complete   | 2026-04-12 |
| 13. Billing Test Clocks                   | v2.0      | 8/7 | Complete   | 2026-04-12 |
| 14. Invoices & Invoice Line Items         | v2.0      | 0/0            | Not started | -          |
| 15. Subscriptions & Subscription Items    | v2.0      | 0/0            | Not started | -          |
| 16. Subscription Schedules                | v2.0      | 0/0            | Not started | -          |
| 17. Connect Accounts & Links              | v2.0      | 0/0            | Not started | -          |
| 18. Connect Money Movement                | v2.0      | 0/0            | Not started | -          |
| 19. Cross-cutting Polish & v0.3.0 Release | v2.0      | 0/0            | Not started | -          |
