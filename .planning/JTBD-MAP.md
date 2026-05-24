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
| Disputes and evidence lifecycle | High leverage | Planned | Missing | Not shipped |
| Credit-note workflows | High leverage | Planned | Missing | Not shipped |
| Mandate and SetupAttempt diagnostics | Medium | Planned | Missing | Not shipped |
| Quote-to-invoice workflow | High leverage for B2B | Planned | Missing | Not shipped |

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

### Gap 2: Disputes are the largest missing operational workflow

Disputes are not edge-case API trivia. They are part of the real operating system of taking
payments at scale.

Why it should stay high priority:

- the repo already shipped File/FileLink, which is the hard dependency for evidence workflows
- disputes are painful enough that good SDK ergonomics have outsized value
- this closes an obvious "drop to raw HTTP" gap

### Gap 3: Credit notes and quotes complete the B2B billing story

Subscriptions and invoices are already strong. Credit notes and quotes are the natural next
steps for teams selling to finance-driven customers.

Why they matter:

- credit notes close the "fix the bill after issuance" loop
- quotes close the "proposal to invoice" loop
- together they move the library closer to "full SaaS billing toolkit" territory

### Gap 4: Catalog and portal-configuration guidance is thinner than it should be

The primitives exist, but the narrative advice is still light around:

- how to structure Product and Price for common SaaS pricing models
- when to rely on BillingPortal configuration vs app-owned subscription controls

This is a docs gap more than a code gap.

## Recommended Priority Order

Assuming the current roadmap and code surface stay roughly aligned, this is the recommended
JTBD-driven ordering:

1. **Disputes**
   This closes the most painful missing real-world payment workflow after File/FileLink.
2. **Credit notes**
   This completes the corrective side of invoice-driven billing.
3. **Quotes**
   This completes the front half of many B2B billing flows.
4. **DX recipes and guide stitching**
   This converts broad API coverage into faster successful integrations.
5. **Mandate and SetupAttempt**
   Useful and real, but lower leverage than the flows above for most SaaS teams.

## What "Feature-Complete Enough" Looks Like

Do not interpret "complete" as "Stripe has no endpoints left."

For JTBD purposes, LatticeStripe is feature-complete enough when all of these are true:

- a typical SaaS can implement one-time payments, recurring billing, usage billing, invoicing,
  customer self-service, and platform money movement without dropping to raw HTTP
- a typical B2B SaaS can handle quotes, invoices, credits, and post-issuance corrections
- a payments-heavy SaaS can handle disputes and evidence upload cleanly
- each common flow has one clearly recommended path in the docs
- the remaining gaps are mostly vertical-specific or low-frequency edge cases

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

## Maintenance Notes

When the user asks for an update in the future, answer in this order:

1. what changed in shipped capability
2. which user flows became clearer or broader
3. which important gaps remain
4. whether the priority order changed
5. whether the "feature-complete enough" threshold moved materially
