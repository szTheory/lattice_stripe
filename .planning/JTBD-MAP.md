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
| One-time payments | Core | Strong | Partial | Shipped; **payments.md has API example bugs** (status atoms, search arity) — fix in v1.8 |
| Hosted checkout | Core | Strong | Strong | Shipped and documented |
| Subscription signup and lifecycle | Core | Strong | Strong | Shipped and documented |
| Customer self-service portal sessions | Core | Strong | Good | Shipped and documented |
| Usage-based billing primitives | Core | Strong | Good | Shipped and documented |
| Invoice lifecycle | Core | Strong | Good | Shipped and documented |
| Connect foundations | Core for platforms | Strong | Good | Shipped and documented |
| Reliability, telemetry, testing | Core | Strong | Strong | Shipped and documented |
| Product and Price catalog design | Foundational | Strong | Thin | Shipped but under-documented |
| BillingPortal configuration strategy | Important | Strong | Thin | Shipped but under-documented |
| Complete end-to-end SaaS recipes | Important | Strong | Strong | Shipped (4 flagship guides, v1.4) |
| File and FileLink workflows | Important dependency | Strong | Thin | Shipped but under-documented |
| Disputes and evidence lifecycle | High leverage | Strong | Partial | Shipped but under-documented |
| Credit-note workflows | High leverage | Strong | Partial | Shipped but under-documented |
| Mandate and SetupAttempt diagnostics | Medium | Strong | Thin | Shipped but under-documented |
| Quote-to-invoice workflow | High leverage for B2B | Strong | Good | Shipped (flagship guide + code) |
| Tax (Calculation, Transaction, Settings, Registration, TaxId) | Core for tax-region SaaS | Strong | Strong | Shipped and documented (v1.6) |
| Thin-event webhook support | Important platform wedge | Strong | Strong | Shipped and documented (v1.5) |
| Charge audit and reconciliation | Important for support/ops | Strong | Partial | Shipped (v1.7); list/search/update/capture in code; payments guide routing gap |
| Production operator guides | Foundational for prod readiness | Strong | Good | Shipped (v1.7): production-checklist + event-debugging; Charge update/capture not in operator route |
| Public package/docs/version truth | Foundational | Strong | Partial | Hex 1.7.0 + lockstep `~> 1.7` on seven install surfaces; getting-started prose drift (lines 20–21) |

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

### Gap 1: Doc-routing polish (post-v1.7 audit tech debt)

Code and install pins are aligned at 1.7.0. Remaining adopter-facing gaps are doc routing, not API surface:

- **`guides/getting-started.md` lines 20–21** — prose claims `1.3.x` is current published Hex surface; install snippet correctly says `~> 1.7`. Not locked by docs_truth (README refute only).
- **Charge reconciliation discovery** — `guides/payments.md` does not route list/search/update/capture; operator guides document list/search only (CHRG-03/04/05 from v1.7 audit).
- **`guides/payments.md` canonical guide bugs** — L89–101 match status as strings but SDK returns atoms; L197 stream filter uses `"succeeded"`; L208–213 documents wrong `search/3` arity (map arg vs query string). Not locked by docs_truth body checks.
- **Cosmetic planning drift** — MILESTONES.md v1.7 header and RETROSPECTIVE historical bullets reference pre-publish state.

**Planned:** v1.8 Adopter Truth & Doc Routing Polish (~2–3 phases).

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

## Recommended Priority Order

Post-v1.7 assessment (2026-05-27):

1. **v1.8 Adopter Truth & Doc Routing Polish** — getting-started prose, Charge doc routing, payments.md API example fixes, docs_truth prose lock, planning cosmetic fixes
2. **Maintenance mode** — bugfixes, Stripe API drift, adopter-driven narrow additions only
3. **Specialist breadth families** — Identity, Financial Connections, Terminal, Issuing, Treasury only if real adopter pull appears
4. **Deferred Tax narrow reqs** — TAX-01 (tax_codes), TAX-02 (transaction list) — adopter pull only
5. **Long-tail narrative docs** — Product/Price catalog, disputes deep playbooks — opportunistic, not milestone-grade

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
