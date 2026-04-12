# Feature Landscape — LatticeStripe v2.0 Billing & Connect

**Domain:** Stripe Billing tier + Stripe Connect platform support for an Elixir SDK
**Researched:** 2026-04-11
**API version in scope:** `2026-03-25.dahlia` (pinned by lattice_stripe v0.2.0; unchanged for v2.0)
**Overall confidence:** HIGH — Stripe Billing semantics are exhaustively documented and well-known; gap document (`~/Downloads/lattice_stripe_billing_gap.txt`) is authoritative on scope.

## Scope Framing

v2.0 adds **resource coverage** on top of a v1 foundation that already owns HTTP, retries, idempotency, pagination, webhooks, error types, and the Payments tier. No new behaviours, no architectural shifts — every feature below lands as a new resource module using the existing `LatticeStripe.Resource` helper plus cross-cutting helpers (`EventType`, `Search.stream!`, `ProrationBehavior` validator).

Existing v1 resources that the v2 features depend on:
- `Customer` (subscription owner, invoice recipient, balance transactions scope)
- `PaymentMethod` (default_payment_method on Subscription, Invoice)
- `PaymentIntent` (Invoice.payment_intent, Subscription.latest_invoice.payment_intent)
- `SetupIntent` (pending_setup_intent on Subscription during SCA/3DS flows)
- `Checkout.Session` (subscription mode — already shipped, reused by v2 examples)
- `Webhook.Event` (consumes the new `EventType` catalog)

---

## Table Stakes

Features users expect to exist in a "complete" Elixir Stripe SDK. Missing any of these and the library feels incomplete for SaaS/subscription work.

### Billing — Catalog

| Feature | Why Expected | Complexity | Depends On | Notes |
|---------|--------------|------------|------------|-------|
| **Product** CRUD + list + search + stream! | Every subscription SKU starts here. Canonical "thing being sold". | Low | v1 Resource helper | Plain CRUD; no lifecycle. Search-capable (Stripe's search endpoint supports Products). |
| **Price** CRUD (no delete) + list + search + stream! | Replaces legacy Plan; required to attach anything to a Subscription. | Low-Medium | Product | **Footgun:** No `delete/2` — Stripe API forbids it. Use `update/3` with `active: false` to archive. Expose `deactivate/2` alias? (optional ergonomics). Search-capable. Recurring vs one_time vs usage-based (`recurring.usage_type`) all land via the same `create/2`. |
| **Coupon** create/retrieve/delete/list/stream! | Discounts — ubiquitous in SaaS. | Low | — | **Footgun:** No `update/3`. Stripe's Coupon is immutable after creation (except metadata in some versions). Document this loudly; don't expose an `update` that silently only updates metadata. Not search-capable. |
| **PromotionCode** CRUD + list + stream! (search?) | User-facing wrapper around a Coupon (the `PROMO50` string). | Low | Coupon | Updatable (unlike Coupon). Gap doc lists it as searchable, but Stripe's published search-capable list does NOT include PromotionCode. **VERIFY in Phase 12** — do not ship `PromotionCode.search/2` until confirmed against live API / openapi spec. |

### Billing — Lifecycle Resources

| Feature | Why Expected | Complexity | Depends On | Notes |
|---------|--------------|------------|------------|-------|
| **Subscription** CRUD + cancel + pause + resume + list + search + stream! | The whole point of the Billing tier. | **HIGH** | Customer, Price, Invoice, PaymentIntent | See "Subscription Lifecycle Traps" below. Search-capable. |
| **Invoice** CRUD + finalize + pay + void + mark_uncollectible + send + **upcoming** + list + search + stream! | Every subscription produces invoices; proration preview UX requires `upcoming/2`. | **HIGH** | Customer, Subscription, Price | See "Invoice Lifecycle Traps" below. Search-capable. `upcoming/2` is a **separate endpoint** (`GET /v1/invoices/upcoming`) — it does NOT take an invoice ID; it takes a customer_id and optional subscription params and *synthesizes* what the next invoice would look like. Must not be confused with `retrieve/2`. |
| **InvoiceLineItem** list (read-only, invoice-scoped) | Itemized billing display. | Low | Invoice | Surface as `Invoice.lines` typed field *and* a standalone `InvoiceLineItem.list/3` scoped by invoice_id. No create/update — line items are derived from subscription items and one-off invoice items. |
| **SubscriptionSchedule** create/retrieve/update/cancel/release/list/stream! | Planned upgrades/downgrades, phased intro pricing, future start dates. Without it, "upgrade next month" must be hacked with cron. | Medium-High | Subscription, Price | **Key concept:** a Schedule is a *plan* for how a Subscription should change over time via ordered `phases`. `release/2` detaches the schedule but leaves the subscription alive in its current phase; `cancel/2` kills both. Not search-capable. See "SubscriptionSchedule Scenarios" below. |

### Billing — Test Infrastructure

| Feature | Why Expected | Complexity | Depends On | Notes |
|---------|--------------|------------|------------|-------|
| **Billing.TestClock** create/retrieve/advance/delete/list/stream! | Without it, integration tests of subscription lifecycle are impossible — you can't wait 30 days for a renewal in CI. | Medium | — | Pulled to Phase 13 (before Invoices/Subscriptions/Schedules) precisely so later phases can use time-travel for integration tests. A TestClock is *attached to a Customer at creation time* (`test_clock` param on `Customer.create`); the customer + all descendant subscriptions/invoices live on that clock's timeline. `advance/3` moves the clock forward (must be future, within clock's `frozen_time` + limit). `delete/2` also deletes every customer attached. |

### Connect — Account Plane

| Feature | Why Expected | Complexity | Depends On | Notes |
|---------|--------------|------------|------------|-------|
| **Account** create/retrieve/update/delete/list/stream! | Foundation of any marketplace/platform. | Medium | — | **Three account types** the SDK doesn't branch on but must document: **Standard** (full Stripe dashboard, fully owned by connected user — minimal platform responsibility), **Express** (Stripe-hosted dashboard, platform manages flow), **Custom** (platform owns *everything* including onboarding UX and dispute handling). From the SDK's POV these differ only in the `type` param on create and which operations are allowed afterward — the HTTP shape is uniform. Not search-capable. |
| **AccountLink** create (only) | Onboarding / update URLs for Standard + Express accounts. Short-lived URLs (minutes). | Low | Account | Write-only resource — no retrieve, no list. Returns a URL the platform redirects the connected user to. Used for KYC flows. |
| **LoginLink** create (only) | Express dashboard magic link. | Low | Account (Express only) | Same shape as AccountLink — write-only, returns a URL. Only valid for `type: "express"` accounts; will error on Standard/Custom — document the constraint. |

### Connect — Money Movement

| Feature | Why Expected | Complexity | Depends On | Notes |
|---------|--------------|------------|------------|-------|
| **Transfer** create/retrieve/update/list/stream! + **reversals** | Separate charges + transfers flow. | Medium | Account, Charge (via v1 PaymentIntent) | Two money-flow models the SDK must support both of: (1) **Destination charges** — platform charges customer, funds go to connected account, handled via `transfer_data.destination` on PaymentIntent (v1 already supports the raw param pass-through); (2) **Separate charges + transfers** — platform charges to its own balance then calls `Transfer.create` to push funds. **Transfer reversals** (`POST /v1/transfers/{id}/reversals`) are how you claw funds back — nested sub-resource; consider surfacing as `Transfer.reverse/3` for ergonomics. |
| **Payout** create/retrieve/update/cancel/reverse/list/stream! | Move money from Stripe balance to bank account. | Medium | — | **Critical distinction vs Transfer:** a `Transfer` moves funds between Stripe balances (platform → connected account); a `Payout` moves funds from a Stripe balance to an *external bank account*. Confusing these two is the #1 Connect footgun. `reverse/2` exists for payouts in some contexts but is only allowed on specific payout states — document the constraint. Not search-capable. |
| **Balance** retrieve/1 (no id) | Query current platform or connected account balance. | Low | — | **Odd shape:** singleton resource — `GET /v1/balance`. No id param. To query a connected account's balance, pass `stripe_account` header (already supported in v1). The `retrieve/1` signature takes only a client, not an id. |
| **BalanceTransaction** retrieve/list/stream! | Audit trail for every credit/debit. | Low-Medium | — | Read-only. Every money movement (charge, refund, payout, transfer, adjustment, dispute) produces a BalanceTransaction entry. Essential for reconciliation. Not search-capable. |

### Cross-cutting Developer Ergonomics

| Feature | Why Expected | Complexity | Depends On | Notes |
|---------|--------------|------------|------------|-------|
| **`LatticeStripe.EventType` catalog** | Stringly-typed webhook dispatch is the ecosystem pain point; a canonical catalog is table stakes for an SDK that wants to win mindshare. | Low-Medium | — | Module with `@constant` + accessor per event name, plus grouping functions: `billing_events/0`, `payment_events/0`, `connect_events/0`, `all/0`. Strings stay strings at runtime (Stripe sends strings) — this is a **naming/catalog** concern, not a deserialization concern. **Auto-verify** the catalog against Stripe's OpenAPI spec in Phase 19 so it can't silently drift. |
| **`LatticeStripe.Search.stream!/3`** | v1 shipped `List.stream!` which assumes cursor pagination (`starting_after`/`ending_before`). Stripe's search endpoints use `page`/`next_page` — a *different* pagination shape. Mixing them silently is a bug. | Low | v1 pagination | Separate helper, explicit naming, clear docs on which to pick. |
| **`LatticeStripe.Billing.ProrationBehavior` validator** | Stripe's `proration_behavior` default varies across endpoints/API versions — "create_prorations" for Subscription.update, "none" for some Schedule paths, etc. Silent inheritance of the wrong default is the #1 Billing footgun. | Low | — | Validator module that accepts `:create_prorations`, `:always_invoice`, `:none` as atoms; raises/returns `{:error, :invalid_proration_behavior}` on anything else. Plus an **optional client config flag** `require_explicit_proration: true` that makes proration a required opt on Subscription.update and SubscriptionSchedule.update (off by default for SDK parity with Stripe's own libs, on for strict callers like Accrue). This is exactly the "SDK parity + opinionated strictness available" pattern already decided in PROJECT.md Key Decisions. |
| **Billing guide + Connect guide** | v1 shipped 5 guides; 0 for the v2 surface would be a visible regression. | Low-Medium | All v2 resources | One guide for subscription lifecycle (create → trial → active → cancel_at_period_end → canceled), one for Connect onboarding (Standard vs Express, AccountLink flow, destination charge example). Cheatsheet additions for every new resource. |
| **Milestone smoke test** | Prove the whole stack plays nicely: create Product → Price → Customer → TestClock → Subscription → advance clock → assert Invoice paid → webhook dispatch via EventType. Catches integration bugs the per-phase tests can't. | Medium | All above | Runs in the integration suite against stripe-mock + a real stripe-test mode gated path. |

---

## Differentiators

Nice-to-have features that would elevate LatticeStripe above "just a wrapper." Not required for v2.0 — can ship as v0.4.x.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **BillingPortal.Session + BillingPortal.Configuration** | Customer self-service (update card, cancel sub, view invoices) for zero UI work. Extremely high value/complexity ratio for Accrue and similar consumers. | Low-Medium | Strong candidate for inclusion in v2.0 if Phase 19 has budget; otherwise v0.4.0. Session is write-only (create + retrieve); Configuration is full CRUD. |
| **CreditNote** + preview/2 | Refund/credit issuance with audit trail; preview-before-issue mirrors `Invoice.upcoming`. | Medium | Post-v2.0. Useful for dispute/refund workflows but not on Accrue's v1 critical path. |
| **TaxRate + TaxId** | Manual tax support (for shops that don't use Stripe Tax). | Low | Post-v2.0. Low effort; slot into v0.4.x when a consumer asks. |
| **CustomerBalanceTransaction** | Customer account credits (e.g. for refund-to-balance flows). | Low | Post-v2.0. Small shape, customer-scoped endpoints. |
| **Expand param builder** / atom-keyed expand | `expand: [:customer, :latest_invoice]` instead of `expand: ["customer", "latest_invoice"]`. | Low | Pure ergonomics — gap doc explicitly marks as non-blocking. Defer unless a cleanup sprint happens. |
| **Typed struct deserialization for expanded objects** (EXPD-02/03/05) | Make `expand: ["customer"]` return `%Customer{}` instead of a raw map. | **HIGH** — cross-cutting rewrite | Deliberately deferred from v1; promoting this should be its own milestone, not v2. It touches every resource module. Do NOT attempt during v2. |

---

## Anti-Features

Features that look tempting but would actively hurt the SDK.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|--------------------|
| **`Coupon.update/3`** | Stripe's API doesn't support it (only metadata is mutable and only in some API versions). Exposing an `update/3` that silently drops every field except metadata would violate "principle of least surprise." | Don't expose the function. Document in `@moduledoc` that Coupons are immutable; use `delete/2` + `create/2` to replace. |
| **`Price.delete/2`** | Stripe API forbids it. | Don't expose. Document that `update/3` with `active: false` is the archive path. Consider `Price.archive/2` as ergonomic alias (optional). |
| **Auto-defaulting `proration_behavior`** to `:create_prorations` | Stripe's real default varies by endpoint/version. Silently picking one would guarantee that SOME callers get behavior that differs from Stripe's direct API — breaking trust. | Pass-through Stripe's behavior by default (let the API use its own default); validate the value when provided; offer `require_explicit_proration: true` for strict callers. |
| **`Subscription.search/2` without documenting search-query syntax** | Stripe search uses a SQL-ish query language (`status:"active" AND created>1234567890`). Exposing `search/2` without linking to Stripe's query reference leaves callers stranded. | Always link to Stripe's search query docs in the `@doc` for every `search/2`. |
| **Wrapping `Stripe-Account` header as a typed Connect module** | The header is already supported at the Client + per-request level in v1 and works fine. Adding a `Connect.with_account/2` wrapper duplicates surface without value. | Document the existing `stripe_account` option in the Connect guide. Done. |
| **`upcoming/2` returning a different struct than `retrieve/2`** | Upcoming and regular invoices share the Invoice shape — Stripe returns the same object type. Diverging would break code that handles both. | Return `%Invoice{}` from both; document that `upcoming/2` invoices have no `id` (they don't exist yet) — callers must handle `id: nil`. |
| **Synthesizing `Invoice.lines` as a separate `list_lines/2` call** | Double-fetches: `retrieve/2` already returns lines nested in the Invoice response. | Surface `invoice.lines` as a typed field on the Invoice struct. Offer standalone `InvoiceLineItem.list/3` for the case where a caller has only an invoice_id and wants a paginated list, but don't force the round-trip. |
| **A `TestClock` helper that auto-attaches clocks to existing customers** | TestClocks can only be attached at customer *creation* time — you can't retrofit a clock onto an existing customer. A helper implying otherwise would produce confusing 400s. | Document the constraint loudly in `Billing.TestClock.@moduledoc`; show the correct pattern: create clock → create customer with `test_clock: clock_id` → create subscription. |
| **Exposing `Account.delete/2` without warning about live-mode rejection** | Stripe only allows deleting Custom accounts in live mode under specific conditions; Standard accounts effectively cannot be deleted by the platform. | Keep `delete/2` (it exists in the API) but document the constraint. Prefer `update/3` with rejection reasons for most cases. |
| **Auto-retrying 402 card_declined on Invoice.pay** | 402 is a business-level failure, not a transport failure. Retrying it makes nothing better and spams the customer. | v1 retry policy already excludes 4xx — confirm it still applies to Invoice.pay paths in Phase 14 tests. |
| **Exposing `PromotionCode.search/2` without verifying API support** | Stripe's published search-capable list does not include PromotionCode; shipping it would produce 404s at runtime. | Verify in Phase 12 against stripe-mock + live API before exposing. |

---

## Subscription Lifecycle Traps (must be documented in @moduledoc)

The Subscription status state machine is the #1 source of user bugs. The SDK cannot hide the complexity, but it can put the traps in writing.

**Status values** (string in Stripe, match exhaustively):
- `incomplete` — first invoice unpaid, still within 23-hour window
- `incomplete_expired` — **terminal**, first invoice went unpaid for 23 hours, invoice voided, no further invoices
- `trialing` — in trial, no charges yet
- `active` — fully paid and current
- `past_due` — renewal invoice failed, retry schedule active per dunning config
- `unpaid` — dunning exhausted, subscription held open but no service (platform decides)
- `canceled` — **terminal**
- `paused` — pause_collection set (different mechanism from pause/resume actions!)

**Traps to document:**

1. **The 23-hour window.** Verified: subscriptions created with `payment_behavior: "default_incomplete"` sit in `incomplete` for up to 23 hours waiting for first-invoice payment. Miss the window → `incomplete_expired`, which is **terminal and irreversible**. You can't revive; you must create a new subscription. The SDK should surface this prominently because webhook handlers that wait for `customer.subscription.updated` events forever will be silently stuck.

2. **`cancel_at_period_end` does NOT change status.** Setting `cancel_at_period_end: true` leaves `status: "active"` until the period actually ends. A naive `if sub.status == "canceled"` check will miss scheduled cancellations. Document: "to detect pending cancellation, check `cancel_at_period_end` and `cancel_at`, not `status`."

3. **`pause/3` and `resume/3` are TWO DIFFERENT mechanisms.** The v2 API exposes both:
   - `pause_collection` param (on Subscription.update) — stops invoice generation, sub stays `active`, no webhook status change. This is what most callers mean.
   - `Subscription.pause/3` action — separate endpoint, sets status to `paused`, fires `customer.subscription.paused` webhook.
   The SDK must choose which `pause/3` maps to. **Recommendation:** `LatticeStripe.Subscription.pause/3` maps to the dedicated action endpoint (clearer semantics, fires a real webhook); document that `pause_collection` is also available via `update/3` for the softer variant.

4. **`proration_behavior` default varies.** Subscription.update defaults to `create_prorations`; SubscriptionSchedule operations default differently. The `require_explicit_proration` flag exists specifically to force the caller to confront this.

5. **`trial_end: :now` ends the trial immediately** and triggers billing. Accept `:now` as an Elixir idiom atom, but pass through unix timestamps too. Document both paths.

6. **`latest_invoice.payment_intent.status` is where SCA / 3DS state lives**, not on the Subscription. Callers checking `subscription.status == "incomplete"` and nothing else will miss `requires_action` on the underlying PaymentIntent. Document the nested lookup pattern; consider an `Expand.latest_invoice_payment_intent` convenience.

---

## Invoice Lifecycle Traps

**Status state machine:** `draft` → `open` → (`paid` | `uncollectible` | `void`). Terminal: `paid`, `void`, `uncollectible`. (`uncollectible` can still be paid later and transition to `paid`.)

**Traps:**

1. **Stripe auto-creates invoices for subscriptions.** Explicit `Invoice.create/2` is for *out-of-cycle* invoices (e.g. one-off charges to an existing customer). Don't document `create/2` as the primary path — most callers should be reacting to `invoice.created` webhooks from subscription renewal.

2. **Drafts are editable, `open` invoices are not.** Once `finalize/2` is called, you can't edit line items. Document the cutoff.

3. **`upcoming/2` is a distinct endpoint.** `GET /v1/invoices/upcoming?customer=cus_xxx&subscription_items[0][price]=price_yyy` — it *synthesizes* a preview of the next invoice without creating a record. Used for proration previews before confirming a plan change. **Returns an Invoice-shaped object with `id: nil`.** Must not be confused with `retrieve/2` which takes an id.

4. **`void/2` vs `mark_uncollectible/2`.** Both are terminal-ish but mean different things:
   - `void/2` — "this invoice should never have existed," reverses the balance, no money was owed
   - `mark_uncollectible/2` — "we gave up trying to collect," balance stays, books it as bad debt
   Confusing these is a finance/reporting error. Document the distinction.

5. **`pay/3` with `paid_out_of_band: true`** marks an invoice paid without actually charging — useful when the customer wired you money. Expose but document clearly.

6. **Invoice line items come from multiple sources:** subscription items, one-off invoice items (`InvoiceItem.create`), and prorations generated by subscription updates. The SDK does NOT need to expose `InvoiceItem` as a separate resource in v2.0 (it's a tier-3+ ask), but the Invoice guide should explain where lines come from.

---

## SubscriptionSchedule Scenarios (why it exists)

Subscription alone cannot express:

1. **Planned upgrade on a future date.** "Charge the customer $10/mo for 3 months then switch them to $30/mo." A Schedule with two phases does this atomically; without it, you'd need a cron job calling `Subscription.update`.

2. **Phased intro pricing.** "50% off for 6 months, then full price." Same pattern — two phases with different prices on a single Schedule.

3. **Future start dates.** "Sub starts on 2026-05-01." Schedule.create with `start_date` in the future, no Subscription exists yet — it materializes on the start date.

4. **Atomic trial-then-paid transitions** with specific proration behavior across the boundary.

**`release/2` vs `cancel/2`:**
- `release/2` — detaches the Schedule from its live Subscription; Subscription continues in its current phase forever. Used when you want to "freeze" a plan change you no longer want to enforce.
- `cancel/2` — cancels the Schedule *and* the underlying Subscription.

Both are action endpoints (`POST /v1/subscription_schedules/{id}/release` and `/cancel`) — expose as named actions, not as `update/3` variations.

---

## Connect Account Type Cheat Sheet (for Connect guide)

| Aspect | Standard | Express | Custom |
|--------|----------|---------|--------|
| Dashboard | Full Stripe, user-owned | Stripe-hosted, Express UI | None — platform builds everything |
| Onboarding | AccountLink → Stripe-hosted | AccountLink → Express onboarding | Platform builds forms, API-driven |
| Disputes, refunds | Connected user handles | Connected user handles | Platform handles |
| Login | Full Stripe Dashboard | `LoginLink` magic links | None |
| Platform liability | Low | Medium | **High** — platform is the merchant of record for many purposes |
| KYC collected by | Stripe | Stripe | **Platform** |
| SDK differences | Same HTTP shape, differs only in `type` on create | Same | Same, but LoginLink works only for Express |

**Destination charges vs separate charges + transfers** (for the money-movement guide):

- **Destination charge:** Customer → Platform Stripe account → (automatic transfer on success) → Connected account. Single API call (PaymentIntent with `transfer_data.destination`). Simpler, preferred for most marketplaces. Stripe handles the transfer atomically.
- **Separate charges + transfers:** Customer → Platform balance → (explicit `Transfer.create`) → Connected account. Two API calls, more control over timing and amount (e.g. delayed transfers, split across multiple recipients). Required when transfer amount isn't a fixed % of the charge or is delayed.

Gap doc confirms both must be supported — destination charges work via v1 PaymentIntent pass-through (already supported); separate charges + transfers require the new `Transfer` resource.

---

## Feature Dependencies (topological order for roadmap)

```
Product ─┐
         ├─► Price ─┐
Coupon ──┼───► PromotionCode
         │         │
TestClock┤         ├─► Subscription ─┐
         │         │                  ├─► SubscriptionSchedule
         │         └─► Invoice ◄──────┘
         │                 │
         │                 └─► InvoiceLineItem (read-only, nested)
         │
Account ─┼─► AccountLink
         ├─► LoginLink
         ├─► Transfer ─► (reversals)
         └─► Payout ──► (reverse/cancel)
             Balance / BalanceTransaction (standalone)

EventType catalog — parallel to everything (references all new resource event names)
Search.stream! — parallel (blocks any resource that exposes search/2)
ProrationBehavior validator — parallel (blocks Subscription Phase 15 + Schedule Phase 16)
```

This matches the phase ordering already in PROJECT.md (12 Catalog → 13 TestClocks → 14 Invoices → 15 Subscriptions → 16 Schedules → 17 Connect Accounts → 18 Connect Money → 19 Cross-cutting).

---

## Search Capability Matrix

Stripe's `/v1/{resource}/search` endpoint is only supported on a specific set of resources. Verified from Stripe API docs.

| Resource | `search/2`? | Notes |
|----------|-------------|-------|
| Customer | ✓ (v1, shipped) | |
| PaymentIntent | ✓ (v1, shipped) | |
| Charge | ✓ | v1 doesn't expose Charge directly, not needed in v2 |
| Invoice | ✓ | Ship in Phase 14 |
| Subscription | ✓ | Ship in Phase 15 |
| Product | ✓ | Ship in Phase 12 |
| Price | ✓ | Ship in Phase 12 |
| **PromotionCode** | ? | Gap doc lists it as searchable, but Stripe's published search-capable list does NOT include PromotionCode. **VERIFY IN PHASE 12** — do not ship `PromotionCode.search/2` until confirmed against live API / openapi spec. Confidence: **LOW**. |
| Coupon | ✗ | Do NOT expose |
| SubscriptionSchedule | ✗ | Do NOT expose |
| Account | ✗ | Do NOT expose |
| Transfer | ✗ | Do NOT expose |
| Payout | ✗ | Do NOT expose |
| BalanceTransaction | ✗ | Do NOT expose |
| Invoice Line Item | ✗ | Nested list only |

Every `search/2` must use the new `LatticeStripe.Search.stream!/3` helper — not `List.stream!` — because Stripe's search pagination uses `page`/`next_page` tokens, not cursors.

---

## Webhook EventType Catalog (for Phase 19 auto-verify)

The exhaustive v2.0 target covers every event Stripe emits for the in-scope resources in API version `2026-03-25.dahlia`. Representative list (Phase 19 must auto-derive the complete set from Stripe's OpenAPI spec to avoid drift):

**Billing (subscription/invoice lifecycle):**
- `customer.subscription.created` / `.updated` / `.deleted` / `.paused` / `.resumed` / `.trial_will_end` / `.pending_update_applied` / `.pending_update_expired`
- `invoice.created` / `.finalized` / `.finalization_failed` / `.paid` / `.payment_failed` / `.payment_action_required` / `.upcoming` / `.marked_uncollectible` / `.voided` / `.sent` / `.updated` / `.deleted`
- `invoiceitem.created` / `.updated` / `.deleted`
- `price.created` / `.updated` / `.deleted`
- `product.created` / `.updated` / `.deleted`
- `coupon.created` / `.updated` / `.deleted`
- `promotion_code.created` / `.updated`
- `subscription_schedule.created` / `.updated` / `.canceled` / `.completed` / `.released` / `.aborted` / `.expiring`
- `billing.test_clock.created` / `.advancing` / `.ready` / `.deleted` / `.internal_failure`

**Connect (account + money movement):**
- `account.updated` / `.application.authorized` / `.application.deauthorized` / `.external_account.created` / `.external_account.updated` / `.external_account.deleted`
- `capability.updated`
- `person.created` / `.updated` / `.deleted`
- `transfer.created` / `.updated` / `.reversed` / `.paid` / `.failed`
- `payout.created` / `.updated` / `.paid` / `.failed` / `.canceled` / `.reconciliation_completed`
- `balance.available`

**Auto-verify strategy for Phase 19:** download the pinned API version's OpenAPI spec, filter event entries, assert every event appearing in spec has a constant in `LatticeStripe.EventType`, and vice versa. Run in CI so drift on API version bumps surfaces as a failing build, not a silent miss.

---

## MVP Recommendation for v2.0

The gap document and PROJECT.md already commit to Tier 1 + Tier 2 landing together as v0.3.0. This research confirms that's the right cut:

**Ship together (v0.3.0):**
1. Product, Price, Coupon, PromotionCode (Phase 12)
2. Billing.TestClock (Phase 13)
3. Invoice + InvoiceLineItem + `upcoming/2` (Phase 14)
4. Subscription with pause/resume/cancel and `ProrationBehavior` validator (Phase 15)
5. SubscriptionSchedule (Phase 16)
6. Account, AccountLink, LoginLink (Phase 17)
7. Transfer, Payout, Balance, BalanceTransaction (Phase 18)
8. `EventType` catalog + `Search.stream!` + Billing/Connect guides + milestone smoke test (Phase 19)

**Defer to v0.4.x:**
- BillingPortal (high-value, but not on Accrue critical path) — strong candidate if Phase 19 has budget
- CreditNote, TaxRate, TaxId, CustomerBalanceTransaction
- Billing Meter family (usage-based)
- Quote

**Do not attempt in v2.0:**
- Typed struct deserialization for expanded objects (EXPD-02/03/05) — rewrite-scale, own milestone
- Code generation from OpenAPI — ADVN-02, explicitly out of scope
- v2 thin events API namespace — ADVN-01, explicitly out of scope
- Specialist families (Tax, Identity, Treasury, Issuing, Terminal) — ADVN-03

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Subscription lifecycle states | HIGH | Verified via Stripe docs + independent ecosystem analyses |
| 23-hour incomplete_expired window | HIGH | Verified via Stripe docs |
| Search-capable resource list | HIGH overall, **LOW for PromotionCode** | Core list (Customer/PaymentIntent/Charge/Invoice/Subscription/Product/Price) is published and stable; PromotionCode unclear |
| Invoice lifecycle + `upcoming/2` semantics | HIGH | Well-documented, matches gap doc |
| Connect account type differences | HIGH | Core Stripe documentation |
| Destination vs separate charges/transfers | HIGH | Core Stripe documentation |
| TestClock attach-at-creation-only constraint | MEDIUM | Documented behavior; **confirm in Phase 13** against stripe-mock |
| Pause/resume having two mechanisms | MEDIUM | Both `pause_collection` param and dedicated pause action confirmed; exact webhook event names need OpenAPI verification in Phase 19 |
| Exhaustive EventType list | MEDIUM | Above list is representative; Phase 19 auto-verify is the real source of truth |
| SubscriptionSchedule release vs cancel semantics | HIGH | Well-documented |

---

## Sources

- [Stripe API — Subscription object](https://docs.stripe.com/api/subscriptions/object)
- [Stripe Billing — How subscriptions work](https://docs.stripe.com/billing/subscriptions/overview)
- [Stripe — Search](https://docs.stripe.com/search)
- [Stripe Search API Reference — pagination](https://docs.stripe.com/api/pagination/search)
- [Stripe Billing collection methods](https://docs.stripe.com/billing/collection-method)
- [Stripe changelog — subscriptions successfully created when first payment fails](https://docs.stripe.com/changelog/2019-03-14/subscriptions-successfully-created-first-payment-fails)
- [Peter Coles — Stripe subscription statuses explained](https://mrcoles.com/stripe-api-subscription-status/) (independent, MEDIUM confidence)
- [Onur Solmaz — Stripe subscription states](https://solmaz.io/stripe-subscription-states) (independent, MEDIUM confidence)
- `~/Downloads/lattice_stripe_billing_gap.txt` — authoritative v2.0 scope document
- `.planning/PROJECT.md` — Key Decisions on `proration_behavior`, phase split, TestClock pull-forward
