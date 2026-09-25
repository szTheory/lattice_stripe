# JTBD Map

This document is the living map of what LatticeStripe helps a SaaS integrator accomplish,
what is already covered well, what is only partially covered, and where future milestone work
should go next.

It is intentionally more forward-looking than the public guides.

## How To Use This File

Use this file for four recurring jobs:

1. explain the current user-flow surface area without re-reading the whole repo
2. identify shipped capability that still lacks strong narrative docs
3. prioritize the next milestone by user-value, not by API trivia
4. decide when additional JTBD mapping has stopped paying for itself

Boundary reminder:

LatticeStripe should become feature-complete enough as a **Stripe SDK**, not as a Phoenix billing engine. When a candidate wedge starts coordinating multiple Stripe primitives into app-owned business workflows, entitlement logic, dunning policy, or operator UX, it is probably Accrue scope rather than LatticeStripe scope.

When updating this file, review in this order:

1. `CHANGELOG.md`
2. `.planning/ROADMAP.md`
3. `README.md`
4. `guides/`
5. newly added public modules and integration tests

## Audience and Domain Lenses

Use these segments to find distinct Stripe contracts and failure modes, not as a promise to
implement every industry workflow. A domain-neutral sample adopter should cover the common
SDK path; add a separate profile only when it exercises a meaningfully different contract.

| Adopter context | Typical jobs | Distinct SDK pressure | Boundary |
| --- | --- | --- | --- |
| Consumer SaaS / B2C | Hosted checkout, subscriptions, saved payment methods, refunds | Fast onboarding, payment-method variation, webhook correctness, retry/idempotency | Product access and customer lifecycle policy stay in the app |
| B2B SaaS | Quotes, invoicing, tax, manual collection, subscription changes | Long-lived billing objects, decimal quantities, invoice line-item depth, reconciliation | Contract terms, revenue policy, and collections strategy stay in the app |
| Usage-priced or AI products | Record, correct, stream, and reconcile usage | High-volume writes, idempotency, asynchronous aggregation and error reports | Usage metering and local ledgers stay app-owned |
| Commerce and digital goods / games | One-time or recurring purchases, refunds, disputes | Payment-method coverage, latency expectations, retries, and support investigations | Inventory, entitlements, game state, and fulfillment stay in the app |
| Connect marketplace / platform | Onboard connected accounts and move/reconcile funds | Per-request tenant context, header suppression, account-specific permissions, observability | Marketplace policy, seller risk, and payout orchestration stay in the app |
| Regulated or high-sensitivity domains | Use Stripe without leaking unrelated domain data into payment metadata | Data minimization, safe inspection/logging, explicit errors, reviewable boundaries | LatticeStripe does not certify compliance or carry clinical, legal, or other domain policy |
| Finance, support, and on-call operators | Reconcile payments, inspect failures, respond to disputes and webhook incidents | Request IDs, actionable error metadata, safe retries, pagination and partial-failure truth | Case management and operational policy stay in the adopting system |
| Elixir application and library maintainers | Install, configure, upgrade, test, and extend the SDK | Minimum Elixir/OTP compatibility, predictable public API, supervision and optional-dependency behavior | The SDK owns Stripe HTTP contracts and supported extension points |

### Common denominator and edge-profile rule

The common adopter spine is a server-side Elixir application that creates or retrieves
Stripe resources, handles API errors and retries, verifies webhook input, and turns typed
Stripe responses into application-owned state. The preferred confidence model is one small
Phoenix app importing LatticeStripe as a dependency, with optional profiles for B2B invoicing,
usage reconciliation, and Connect tenant context. Profiles exist to validate different SDK
contracts, not to implement sample billing products. Include edge cases when they are shared
across adopters: unknown fields, pagination boundaries, delayed webhook delivery, invalid
signatures, retries/idempotency, partial stream failures, tenant override/suppression, and
secret-safe inspection. Do not create one digital twin per industry.

## Flow Inventory

### Payments

- create customers
- create and confirm PaymentIntents
- save payment methods with SetupIntents and PaymentMethods
- refund payments
- run hosted payment collection with Checkout

### Recurring billing

- create subscriptions directly
- create subscription signups through Checkout
- update, cancel, resume, and pause subscriptions
- define phased billing with Subscription Schedules
- manage subscription self-service with the Customer Portal

### Usage billing

- define meters
- ingest usage with MeterEvent
- correct usage with MeterEventAdjustment
- scale ingestion with MeterEventStream

### Invoicing and collections

- create draft invoices
- add invoice items
- finalize, pay, send, void, search, and inspect line items

### Marketplace and platform money movement

- create and manage Connect accounts
- onboard with AccountLinks and LoginLinks
- move funds with Transfers and TransferReversals
- manage payouts and reconcile balances
- act on behalf of connected accounts

### Ops, reliability, and integration hygiene

- verify and route webhooks
- instrument with telemetry and OpenTelemetry
- tune retries, batching, and circuit breakers
- test with mocks, webhook helpers, stripe-mock, and test clocks
- detect Stripe API drift

### File-backed and evidence-oriented workflows

- upload files
- create and manage file links
- download binary content

## Coverage Matrix

| Flow | Product value | Code coverage | Narrative doc coverage | Status |
| --- | --- | --- | --- | --- |
| One-time payments | Core | Strong | Strong | Shipped; payments.md examples fixed (Phase 57) + docs_truth locked |
| Hosted checkout | Core | Strong | Strong | Shipped; checkout.md examples fixed (Phase 59) + docs_truth locked |
| Subscription signup and lifecycle | Core | Strong | Strong | Shipped and documented |
| Customer self-service portal sessions | Core | Strong | Good | Shipped and documented |
| Usage-based billing primitives | Core | Strong | Good | Shipped and documented |
| Invoice lifecycle | Core | Strong | Good | Shipped and documented |
| Connect foundations | Core for platforms | Strong | Good | Shipped and documented |
| Reliability, telemetry, testing | Core | Strong | Strong | Shipped and documented |
| Product and Price catalog design | Foundational | Strong | Good | Shipped; catalog strategy in subscriptions.md (quick 260527-tp8) |
| BillingPortal configuration strategy | Important | Strong | Thin | Shipped but under-documented |
| Complete end-to-end SaaS recipes | Important | Strong | Strong | Shipped (4 flagship guides, v1.4) |
| File and FileLink workflows | Important dependency | Strong | Thin | Shipped but under-documented |
| Disputes and evidence lifecycle | High leverage | Strong | Good | Shipped; File→evidence spine in recipes.md (quick 260527-tm1) |
| Credit-note workflows | High leverage | Strong | Partial | Shipped but under-documented |
| Mandate and SetupAttempt diagnostics | Medium | Strong | Good | Shipped; diagnostics recipe in recipes.md (quick 260527-tp8) |
| Quote-to-invoice workflow | High leverage for B2B | Strong | Good | Shipped (flagship guide + code) |
| Tax (Calculation, Transaction, Settings, Registration, TaxId) | Core for tax-region SaaS | Strong | Strong | Shipped and documented (v1.6) |
| Thin-event webhook support | Important platform wedge | Strong | Strong | Shipped and documented (v1.5) |
| Charge audit and reconciliation | Important for support/ops | Strong | Good/Strong | Shipped; `#charge-reconciliation` in payments.md + operator cross-links (Phase 57) |
| Production operator guides | Foundational for prod readiness | Strong | Good/Strong | Shipped; update/capture routed in production-checklist + event-debugging (Phase 57) |
| Public package/docs/version truth | Foundational | Strong | Strong | Hex 1.7.0 + lockstep `~> 1.7`; getting-started prose SSOT locked (Phase 56); README error taxonomy locked (Phase 59) |

## Current Best-Fit User Stories

LatticeStripe is already a good fit today for these integrator stories:

- "I need to accept one-time payments in a Phoenix app."
- "I need recurring billing with sane subscription lifecycle primitives."
- "I want Stripe-hosted checkout and self-service billing instead of building those screens myself."
- "I need usage-based billing with idempotent event reporting and reconciliation awareness."
- "I run a platform and need Connect account onboarding plus money movement."
- "I care about webhooks, retries, telemetry, and testing as first-class concerns."
- "I need explicit Tax API coverage for custom checkout flows and tax-region compliance."
- "I need modern thin-event webhooks with fetch-after-verify, not just snapshot payloads."

- "I need Charge list/search/update/capture for support, reconciliation, and legacy migration workflows."

## Biggest Gaps

v1.9 closed the doc/CI honesty wedge (checkout guide, README error taxonomy, docs_truth locks, CI-01 paths-ignore). Doc-routing polish for getting-started and payments.md shipped in v1.8 (Phases 56–57).

### Doc defects — resolved (quick task 260527-tkc, 2026-05-28)

- ~~`guides/payments.md` unclosed Search fence~~ — fixed; docs_truth lock
- ~~`guides/customer-portal.md` Dashboard-only portal config claim~~ — fixed; `BillingPortal.Configuration` documented; docs_truth lock
- ~~`guides/user-flows-and-jtbd.md` stale "Still missing" inventory~~ — refreshed; `recipes.md` in reading order; docs_truth lock

### Gap 2: Narrative docs still thin for several shipped surfaces

Product/Price catalog strategy, BillingPortal configuration, disputes/files evidence, and mandate diagnostics remain recipe- or fixture-level only. These are polish, not milestone-blocking — defer unless adopter pull surfaces.

### Resolved gaps (do not re-prioritize)

- ~~End-to-end flagship recipes~~ — four guides shipped (v1.4)
- ~~Thin-event webhook support~~ — shipped (v1.5)
- ~~Tax resource family~~ — shipped (v1.6)
- ~~Charge list/search/update/capture~~ — shipped (v1.7)
- ~~Production operator guides~~ — production-checklist + event-debugging shipped (v1.7)
- ~~Public release truth / Hex publish~~ — 1.7.0 on Hex, lockstep `~> 1.7` install contract (v1.7)
- ~~v1.x stop signal~~ — README, scope.md, planning artifacts (v1.7)
- ~~getting-started release-status prose drift~~ — fixed Phase 56 (TRUTH-01/02)
- ~~payments.md API example bugs~~ — atom statuses, search/3 fixed Phase 57 (GUIDE-01..03)
- ~~Charge reconciliation discovery gap~~ — `payments.md#charge-reconciliation` Phase 57 (ROUTE-01)
- ~~operator guide update/capture routing~~ — Phase 57 (ROUTE-02)
- ~~cosmetic planning drift~~ — MILESTONES/RETROSPECTIVE/JTBD refresh Phase 58 (PLAN-01/02, ROUTE-03)
- ~~Phase 59: checkout.md atom stream filter + status-values callout + docs_truth describe locks~~
- ~~Phase 59: README canonical error atoms + docs_truth describe lock~~
- ~~Phase 60: CI-01 paths-ignore narrowed — guide/md PRs run full CI including docs_truth~~

## Recommended Priority Order

Post-v1.x posture (2026-05-28):

1. **Reactive maintenance** — bugs, Stripe drift, GitHub issues/PRs (default; no proactive work)
2. **Adopter-pull only** — TAX-01/02, specialist families, new resource modules (see `guides/scope.md`)
3. **Opportunistic doc** — BillingPortal narrative depth in `customer-portal.md` if an adopter asks
4. **No website** — README + HexDocs are the public surface

Assessment doc wedges and Gap 2 narratives closed 2026-05-28 (quick tasks tkc, tm1, tp8, tqf).

## What "Feature-Complete Enough" Looks Like

Do not interpret "complete" as "Stripe has no endpoints left."

For JTBD purposes, LatticeStripe is feature-complete enough when all of these are true:

- a typical SaaS can implement one-time payments, recurring billing, usage billing, invoicing,
  customer self-service, and platform money movement without dropping to raw HTTP
- a typical B2B SaaS can handle quotes, invoices, credits, and post-issuance corrections
- a payments-heavy SaaS can handle disputes and evidence upload cleanly
- each common flow has one clearly recommended path in the docs
- the remaining gaps are mostly vertical-specific or low-frequency edge cases

And these remain true:

- LatticeStripe still feels like a direct Stripe SDK, not a second Cashier/Pay analogue
- higher-level billing-engine behavior continues to live in Accrue rather than drifting downward into this repo

That is the real "done enough" threshold.

## Diminishing Returns Threshold

JTBD mapping work starts hitting diminishing returns when new research mostly discovers one of
these:

- obscure Stripe resources that do not change mainstream SaaS integration choices
- second-order variants of already well-mapped flows
- edge-case operational branches that matter only for narrow industries

A practical rule:

If a new capability does not either:

- remove a common need for raw HTTP
- simplify a common SaaS decision
- reduce a common production risk

then it is probably below the line for near-term JTBD prioritization.

Additional scope rule:

If a new capability primarily adds app-owned billing orchestration, entitlement logic, dunning policy, operator UX, or other higher-level business behavior rather than direct Stripe coverage, it is probably above LatticeStripe's scope line and belongs in Accrue.

## Maintenance Notes

When the user asks for an update in the future, answer in this order:

1. what changed in shipped capability
2. which user flows became clearer or broader
3. which important gaps remain
4. whether the priority order changed
5. whether the "feature-complete enough" threshold moved materially

- Refresh this file at **milestone close** (not only milestone start); verify against `CHANGELOG.md`, `docs_truth_test.exs`, and shipped guides.
