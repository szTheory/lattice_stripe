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
| One-time payments | Core | Strong | Strong | Shipped and documented |
| Hosted checkout | Core | Strong | Strong | Shipped and documented |
| Subscription signup and lifecycle | Core | Strong | Strong | Shipped and documented |
| Customer self-service portal sessions | Core | Strong | Good | Shipped and documented |
| Usage-based billing primitives | Core | Strong | Good | Shipped and documented |
| Invoice lifecycle | Core | Strong | Good | Shipped and documented |
| Connect foundations | Core for platforms | Strong | Good | Shipped and documented |
| Reliability, telemetry, testing | Core | Strong | Strong | Shipped and documented |
| Product and Price catalog design | Foundational | Strong | Thin | Shipped but under-documented |
| BillingPortal configuration strategy | Important | Strong | Thin | Shipped but under-documented |
| Complete end-to-end SaaS recipes | Important | Partial | Thin | Partially covered |
| File and FileLink workflows | Important dependency | Strong | Thin | Shipped but under-documented |
| Disputes and evidence lifecycle | High leverage | Strong | Partial | Shipped but under-documented |
| Credit-note workflows | High leverage | Strong | Partial | Shipped but under-documented |
| Mandate and SetupAttempt diagnostics | Medium | Strong | Thin | Shipped but under-documented |
| Quote-to-invoice workflow | High leverage for B2B | Strong | Partial | Shipped but under-documented |
| Public package/docs/version truth | Foundational | Partial | Partial | Shipped surface exists but public truth lags |
| Thin-event webhook support | Important platform wedge | Missing | Missing | Not shipped |

## Current Best-Fit User Stories

LatticeStripe is already a good fit today for these integrator stories:

- "I need to accept one-time payments in a Phoenix app."
- "I need recurring billing with sane subscription lifecycle primitives."
- "I want Stripe-hosted checkout and self-service billing instead of building those screens myself."
- "I need usage-based billing with idempotent event reporting and reconciliation awareness."
- "I run a platform and need Connect account onboarding plus money movement."
- "I care about webhooks, retries, telemetry, and testing as first-class concerns."

## Biggest Gaps

### Gap 1: End-to-end recipes are behind the API surface

The codebase is broader than the current "how would I ship this in a SaaS?" guidance.

What is missing:

- one complete flow from Checkout signup to webhook provisioning to portal self-service
- one complete flow from metering to invoice review to customer communication
- one complete Connect recipe for a realistic platform
- one complete enterprise flow built around invoices, quotes, and later credits

Why this matters:

- this is where experienced engineers decide whether a library feels production-ready
- it reduces integration design churn more than another narrow endpoint wrapper often does

Boundary note:

- recipe work here should stay primitive-first and SDK-shaped
- if a recipe starts turning into a billing-facade or workflow-orchestration product, point up to Accrue instead of expanding LatticeStripe

### Gap 2: Public release truth and guide coverage lag the shipped surface

The repo now ships more than the public installer/docs story makes obvious.

What is happening:

- README, CHANGELOG, install snippets, and the cheatsheet still describe `1.3`
  as unreleased or show pre-1.0 setup
- the code/test/tag surface already includes File/FileLink, Dispute, CreditNote,
  Mandate, SetupAttempt, Quote, recipes, and webhook guidance
- a serious adopter can underestimate the library because the public story still
  reflects an older line

Why it should stay high priority:

- this is the fastest path from "strong repo" to "obviously adoptable OSS library"
- it reduces evaluation friction for new Phoenix SaaS teams more than another
  narrow Stripe family
- it is the cleanest precursor to deciding whether a new code wedge is still needed

### Gap 3: End-to-end recipes and operator guidance are still behind the API surface

The codebase is broader than the current "how would I ship this in a SaaS?" guidance.

What is still missing:

- one complete flow from Checkout signup to webhook provisioning to portal self-service
- one complete flow from metering to invoice review to customer communication
- one complete Connect recipe for a realistic platform
- one complete enterprise flow built around invoices, quotes, and later credits
- clearer public guidance around Product/Price catalog strategy and BillingPortal configuration strategy

Why this matters:

- this is where experienced engineers decide whether a library feels production-ready
- it reduces integration design churn more than another narrow endpoint wrapper often does

Boundary note:

- recipe work here should stay primitive-first and SDK-shaped
- if a recipe starts turning into a billing-facade or workflow-orchestration product, point up to Accrue instead of expanding LatticeStripe

### Gap 4: Thin-event webhook support is the biggest remaining code wedge

The current webhook surface is strong for snapshot-style events, but the project’s own
research already treats thin events as part of modern Stripe reality.

Why it matters:

- Stripe’s webhook story is increasingly two-track: snapshot events and thin events
- this fits the library’s existing strengths in webhook verification, event retrieval,
  testing helpers, and operator-facing guidance
- it strengthens the SDK without drifting into billing-engine behavior

## Recommended Priority Order

Assuming the current roadmap and code surface stay roughly aligned, this is the recommended
JTBD-driven ordering:

1. **Public truth + guide completion**
   This converts shipped breadth into faster, lower-friction adoption.
2. **Thin-event webhook support**
   This is the strongest remaining platform wedge that still fits LatticeStripe cleanly.
3. **Tax**
   This is the broadest remaining mainstream SaaS billing family after webhook modernization.
4. **Quote external proof closure**
   Worth closing honestly, but too narrow to drive a full milestone by itself.
5. **Specialist breadth families**
   Identity, Financial Connections, Terminal, Issuing, or Treasury only if real adopter pull appears.

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
