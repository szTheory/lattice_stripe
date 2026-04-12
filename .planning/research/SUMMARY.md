# Research Summary — v2.0 Billing & Connect

**Milestone:** lattice_stripe v2.0 (Hex target: `lattice_stripe` v0.3.0)
**Synthesized:** 2026-04-12
**Inputs:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md
**Overall confidence:** HIGH — the four research tracks converge cleanly with no contradictions.

## Executive Summary

v2.0 is a **pure resource-surface milestone**. The four research tracks agree: the v1 foundation (Client, Transport, Request, Response, Error, RetryStrategy, List, Resource, Webhook, Telemetry) is complete and load-bearing for every Billing and Connect resource the milestone needs. **Zero new runtime dependencies, zero new behaviours, zero modifications to HTTP/retry/pagination primitives.** Every new resource is a ~300–600 line module that copy-pastes the v1 `PaymentIntent` / `Checkout.Session` template against a new path.

The single most important decision is that **v2 ships a `require_explicit_proration` strict-mode flag** (default `false`) backed by a `LatticeStripe.Billing.ProrationBehavior` validator. This is a deliberate departure from Ruby/Node/Python SDK norms in favor of Elixir's explicitness bias — and it defuses the #1 Billing footgun (silent inheritance of Stripe's endpoint-dependent `proration_behavior` defaults, which vary across `create`/`update`/`cancel`/`schedule` paths).

The milestone splits across **eight phases (12–19)** in strictly topological order — catalog → test clocks → invoices → subscriptions → schedules → Connect accounts → Connect money → cross-cutting polish — with a clean v0.3.0-rc1 release boundary at Phase 16. Testing introduces a **two-tier integration gate**: stripe-mock (fast, always runs) plus a new real-Stripe-test-mode job (`@tag :real_stripe`, gated by `STRIPE_TEST_SECRET_KEY`, runs nightly) for stateful scenarios stripe-mock cannot simulate.

## Stack Decisions (no new deps)

| Area | v0.3.0 decision | Change from v0.2.0? |
|------|-----------------|---------------------|
| HTTP (Finch), JSON (Jason), Telemetry, NimbleOptions, Plug.Crypto, Plug | unchanged | No |
| Mox, ExDoc, Credo, MixAudit | unchanged | No |
| Stripe API pin (`2026-03-25.dahlia`) | unchanged — Dahlia breaks are client-side; Billing is additive | No |
| stripe-mock Docker integration | unchanged | No |
| **Real-Stripe test-mode tier** | NEW CI job, `@tag :real_stripe`, secret-gated | **New CI job only — zero Hex deps** |
| **EventType drift check** | vendored `test/fixtures/stripe_openapi_events.json` + mix refresh task + tagged diff test | **Test code only** |

`mix.exs` diff for v0.3.0 is **only** the `@version` bump.

## Feature Inventory

### Tier 1 — Must ship together for v0.3.0

- **Phase 12:** Product, Price, Coupon, PromotionCode
- **Phase 13:** Billing.TestClock (pulled forward)
- **Phase 14:** Invoice + Invoice.LineItem + `upcoming/2` (returns Invoice with `id: nil`)
- **Phase 15:** Subscription + Subscription.Item + pause/resume/cancel + `ProrationBehavior` validator + `require_explicit_proration` flag
- **Phase 16:** SubscriptionSchedule (release vs cancel)
- **Phase 17:** Account, AccountLink, LoginLink (write-only)
- **Phase 18:** Transfer (+ reversals), Payout, Balance (singleton), BalanceTransaction
- **Phase 19:** `LatticeStripe.EventType` exhaustive catalog + OpenAPI drift test + `LatticeStripe.Search` **thin facade** + Billing guide + Connect guide + milestone smoke test

### Tier 2 — Stretch goal for v0.3.0

- BillingPortal.Session + BillingPortal.Configuration (Phase 19 if budget remains)

### Deferred to v0.4.x+

- CreditNote, TaxRate, TaxId, CustomerBalanceTransaction, Billing Meter family, Quote

### Explicitly NOT in v2.0

- Typed struct deserialization for expanded objects (EXPD-02/03/05) — own milestone
- Code generation (ADVN-02), v2 thin events namespace (ADVN-01), specialist families (ADVN-03)

### Search Capability Matrix

- **Ship `search/2`:** Product, Price, Invoice, Subscription (all ride existing `List.stream!/2` search branch)
- **Do NOT expose:** Coupon, SubscriptionSchedule, Account, Transfer, Payout, BalanceTransaction, InvoiceLineItem
- **VERIFY IN PHASE 12 (LOW confidence):** PromotionCode — Stripe's published list excludes it but gap doc implies otherwise. Do not ship `PromotionCode.search/2` until confirmed.

## Architecture Decisions

### v1 foundation is frozen

`Client`, `Transport`, `Request`, `Response`, `Error`, `RetryStrategy`, `Json`, `FormEncoder`, `List` (including search pagination at `list.ex:245–275`), `Resource`, `Webhook`, `Telemetry` — all untouched. `Client.stripe_account` header plumbing (`client.ex:175, 422–424`) is already end-to-end; Connect gets it free.

### One additive `Client` field

`client.ex:52–64` gains `require_explicit_proration: false` (default off). Only v1 `Client` struct change.

### New modules (all follow v1 template)

| Module | Shape / notes |
|--------|---------------|
| All Billing + Connect resources | Standard v1 template, 300–600 LOC each |
| `Invoice.LineItem` / `Subscription.Item` | Nested child following `Checkout.LineItem` precedent |
| `LatticeStripe.BillingTestClock` | Plain resource module, ships in `lib/` |
| `LatticeStripe.Testing.TestClock` | High-level helper, **ships in `lib/`** (precedent: `LatticeStripe.Testing`) |
| `LatticeStripe.EventType` | Plain constants module (`@attr + def` + category lists). Rejected: behaviour, macro, atoms |
| `LatticeStripe.Billing.ProrationBehavior` | Standalone validator (`values/0`, `valid?/1`, `validate!/1`). **Ships in Phase 15**, not deferred to 19 |
| `LatticeStripe.Search` | **Thin facade — docs only**, points at `List.stream!/2`. Plan's "add `Search.stream!/3`" was outdated |
| `LatticeStripe.Client.with_account/2` | Ergonomic helper for Connect scoping. Decide in Phase 17 |
| `test/support/billing_case.ex` | Internal CaseTemplate, not shipped |

### Build order: **Order A (plan's proposed) — CONFIRMED**

Strictly topological, single-executor friendly, clean rc1 boundary at Phase 16. Orders B (Connect-first) and C (interleaved) rejected per ARCHITECTURE §9.

## Critical Pitfalls — Phase Assignments

**5 Critical, 8 High, 4 Medium.**

| ID | Pitfall | Primary phase | Mitigation |
|----|---------|---------------|------------|
| **C1** | `proration_behavior` default silently varies across create/update/cancel/schedule | **15** (also 14, 16) | `ProrationBehavior.validate!/1` + `require_explicit_proration` flag; never set SDK default |
| **C2** | Subscription `incomplete → incomplete_expired` is a **23-hour one-way edge** | **15** | State-machine `@moduledoc`; `status_is_terminal?/1`; document that it fires as `.updated` not `.deleted` |
| **C3** | Connect `Stripe-Account` is a context switch — cross-tenant leak risk | **17** | Telemetry metadata, Context matrix in Connect guide, `Client.with_account/2`, `LatticeStripe.Connect` warning module |
| **C4** | Invoice auto-finalization race (~1h after create if `auto_advance` omitted) | **14** | Document canonical order; telemetry warning when `auto_advance` unset; first-class `finalize/2`, `pay/2+3` |
| **C5** | SubscriptionSchedule **owns** its Subscription — direct mutations conflict | **16** (cross-link 15) | `Subscription.update/3` `@doc` warning when `sub.schedule` non-nil; surface `:schedule` typed field |

### HIGH pitfalls

- **H1** `cancel_at_period_end` leaves status `"active"` — **15**
- **H2** Webhook out-of-order delivery — **19** (Webhooks guide + `Event.created_at/1` helper)
- **H3** Search eventual consistency (~1s) — **12/14/15** per-resource docs + **19**
- **H4** TestClock fixture isolation + async advance + 100-clock limit — **13** (`advance_and_wait/3`, `mix lattice_stripe.test_clock.cleanup`)
- **H5** Meter events eventual consistency — **19 design note only** (v0.5.x)
- **H6** BillingPortal URL expiry — design note only (Tier 3)
- **H7** Standard Connect account immutability — **17**
- **H8** Form encoding for triple-nested shapes + multi-discount — **12 + 15** (FormEncoder test battery)

### MEDIUM (docs-only)

- **M1** EventType catalog drift — **19** (vendored fixture + mix task + weekly CI)
- **M2** Strict-mode flag departure from Ruby/Node norms — mitigated by opt-in default
- **M3** stripe-mock coverage gaps — **13** spike + **19** CONTRIBUTING strategy
- **M4** Conventional Commit scope discipline + rc1 mechanics — **19** + Phase 16 decision

## Phase-by-Phase Recommendations

**Phase 12 — Billing Catalog:** 4 standalone resources. No `Coupon.update/3`, no `Price.delete/2`. Verify PromotionCode search. Build FormEncoder unit test battery (H8) now. Research flag: **LOW**.

**Phase 13 — TestClocks (pulled forward):** `BillingTestClock` resource + `Testing.TestClock` helper + internal `billing_case.ex`. Ship `advance_and_wait/3` polling + cleanup task (H4). **Spike stripe-mock clock simulation** at phase start (M3). First real-API tier test. Research flag: **MEDIUM**.

**Phase 14 — Invoices + `upcoming/2`:** Invoice + Invoice.LineItem + finalize/pay/void/mark_uncollectible/send. Address **C4** (telemetry warning + canonical order docs) and **C1** for upcoming. `upcoming/2` explicitly returns Invoice with `id: nil`. Distinguish `void/2` vs `mark_uncollectible/2`. Real-API tier for auto-advance race. Research flag: **MEDIUM**.

**Phase 15 — Subscriptions + ProrationBehavior ships here:** Most semantics-heavy phase. Address **C1** (primary) + **C2** (23h window) + H1 + H8. Ship `ProrationBehavior.validate!/1` + `require_explicit_proration` + Config schema update. Exhaustive state machine `@moduledoc`. Both pause mechanisms documented (`pause_collection` param vs `pause/3` action; LatticeStripe `pause/3` → dedicated action). `status_is_terminal?/1`, `cancellation_pending?/1`. Real-API tier critical for C2 and proration math. Research flag: **HIGH**.

**Phase 16 — Subscription Schedules (+ v0.3.0-rc1 cut):** Address **C5**. Document release vs cancel. `Subscription.update/3` `@doc` warning when `sub.schedule` non-nil. Phase 16 end = **v0.3.0-rc1 tag decision point** (M4). Real-API tier for phase transitions. Research flag: **MEDIUM**.

**Phase 17 — Connect Accounts + Links:** Address **C3** + H7. Ship `Client.with_account/2` here. Connect guide with Context Matrix + three account-type decision matrix + destination vs separate charges. Heavy-PII Inspect on Account; hide `url` on AccountLink/LoginLink. Research flag: **LOW**.

**Phase 18 — Connect Money Movement:** Transfer (+ `Transfer.reverse/3` ergonomic), Payout, Balance singleton `retrieve/1`, BalanceTransaction read-only. Loud Transfer-vs-Payout distinction docs. Destination-charge + separate-charges patterns in guide. Research flag: **LOW**.

**Phase 19 — Cross-cutting Polish:** `LatticeStripe.EventType` exhaustive catalog + OpenAPI drift test + `LatticeStripe.Search` **facade** + Billing/Connect guides + milestone smoke test + release process docs. H2 (Webhooks ordering), H3 (search consistency per-resource callouts), M1/M3/M4 polish. H5/H6 design notes only. BillingPortal as stretch goal. Research flag: **MEDIUM**.

## Open Questions for Phase Discussions

1. **PromotionCode `search/2`** — verify in Phase 12 before exposing (LOW confidence)
2. **stripe-mock test clock fidelity** — spike at start of Phase 13
3. **`Client.with_account/2`** — ship in Phase 17 or defer (low risk either way)
4. **`require_explicit_proration` default for v1.0** — revisit at v1.0 boundary
5. **v0.3.0-rc1 mechanics** — manual git tag vs Release Please prerelease manifest (Phase 16 decision)
6. **EventType catalog storage** — vendored fixture vs fetch-at-test (vendored recommended)
7. **`Subscription.update/3` schedule-owned hard error** — docs-only for v0.3.0; revisit at v1.0

## Confidence Assessment

| Area | Level | Notes |
|------|-------|-------|
| Stack (no new deps) | **HIGH** | Every resource reduces to v1 primitives |
| Feature scope + dependency order | **HIGH** | Matches gap doc + PROJECT.md |
| Architecture fit (v1 template scales) | **HIGH** | File+line refs back every claim |
| Pitfall coverage (Stripe API) | **HIGH** | Stripe docs + community post-mortems |
| stripe-mock coverage assumptions | **MEDIUM** | Phase 13 spike de-risks; real-API tier backs up the rest |
| PromotionCode search capability | **LOW** | Conflicting signals; verify Phase 12 |
| EventType drift automation shape | **MEDIUM** | Novel for this repo (~150 LOC test code) |
| Strict-mode flag community reception | **MEDIUM** | Opt-in default de-risks |
| Release Please rc1 mechanics | **MEDIUM** | v0.2.0 shipped clean; prerelease config needs verification |

**Overall:** HIGH. Well-scoped additive milestone, complete v1 foundation, three LOW/MEDIUM points to resolve during phase planning, no contradictions between research tracks.
