# User Flows & JTBD

Most Stripe SDK docs answer, "What does this module do?"

That is useful when you already know the shape of your integration. It is less useful when
you are building a SaaS and the real question is, "What billing job am I trying to get done,
and which path through Stripe should I choose?"

This guide is the answer to that second question.

It explains LatticeStripe from the point of view of an experienced Elixir/Phoenix engineer
building a real product: signups, upgrades, failed payments, usage billing, invoices,
marketplace payouts, and the operational glue that keeps those flows honest in production.

## The Mental Model

LatticeStripe is not a billing product. It is the Elixir-shaped control surface for Stripe.
The library gives you typed structs, predictable function shapes, guards around a few nasty
footguns, and good Phoenix ergonomics. Stripe still owns the money movement and most of the
state machines.

Four ideas make the rest of the guide easier to hold in your head:

### 1. Your app starts flows. Webhooks confirm reality.

Creating a PaymentIntent, Subscription, Invoice, or Customer Portal session is usually the
beginning of a story, not the end of it.

The authoritative state changes often happen later:

- a payment succeeds or fails
- a subscription renews or goes past due
- a customer cancels through the portal
- a meter event is accepted, then later rejected during reconciliation

If you only remember one thing, remember this:

**API responses tell you what Stripe accepted right now. Webhooks tell you what became true.**

### 2. Some flows are app-owned. Some are Stripe-hosted.

LatticeStripe supports both:

- **App-owned flows** where your app creates and updates objects directly
- **Stripe-hosted flows** where you redirect to Checkout or the Customer Portal

Stripe-hosted flows are often the shortest path to shipping. App-owned flows buy you more
control. The right choice depends on whether you want speed, custom UX, or fine-grained
business rules.

### 3. Billing setup and billing runtime are different jobs.

There is a "set up the catalog" phase and a "run the business every day" phase.

- **Catalog/setup**: Product, Price, portal configuration, meter definitions
- **Runtime**: create customers, charge, subscribe, invoice, report usage, reconcile failures

Most SaaS teams should treat catalog setup as deploy-time or admin-time work, and runtime
billing as the code path end users actually exercise.

### 4. Idempotency is part of the happy path.

Stripe integrations live in a world of retries, double-clicks, background jobs, webhook
replays, and network hiccups. LatticeStripe gives you good primitives here, but your product
logic still needs stable keys and replay-safe workflows.

This matters most for:

- subscription signup
- invoice creation
- refunds
- metering events
- any job queue that can retry

## Start Here By Situation

Use this guide as a routing layer, not as the final source of API truth.

- **First payment or first hosted checkout flow**:
  [Payments](payments.md), [Checkout](checkout.md), then [Webhooks](webhooks.md)
- **Recurring billing and self-serve lifecycle**:
  [Checkout Signup and Portal Follow-Through](checkout-signup-and-portal.md),
  [Subscriptions](subscriptions.md), [Customer Portal](customer-portal.md), [Invoices](invoices.md)
- **Usage-based billing and reconciliation**:
  [Metering Runtime and Reconciliation](metering-runtime-and-reconciliation.md),
  [Metering](metering.md), [Webhooks](webhooks.md), [Testing](testing.md)
- **Custom payment flows with standalone Stripe Tax (not only Checkout/Invoices)**:
  [Tax](tax.md), [Payments](payments.md), [Testing](testing.md)
- **Marketplace or platform work**:
  [Connect Platform Flow](connect-platform-flow.md), [Connect](connect.md),
  [Connect Accounts](connect-accounts.md), [Connect Money Movement](connect-money-movement.md)
- **Quote-driven billing follow-through**:
  [Quote to Billing Operator Flow](quote-to-billing-operator.md), [Invoices](invoices.md),
  [Subscriptions](subscriptions.md), [Webhooks](webhooks.md)
- **Runtime truth, support, and debugging**:
  [Production Checklist](production-checklist.md), [Event Debugging](event-debugging.md), [Webhooks](webhooks.md), [Error Handling](error-handling.md), [Testing](testing.md), [Webhooks: Thin Events](webhooks-thin-events.md)

## The Jobs This Library Already Serves Well

### Job 1: "Take a payment without building a payments platform"

This is the first SaaS job: somebody wants to pay you.

You have two main paths:

- **PaymentIntent** when your app owns the payment flow
- **Checkout Session** when you want Stripe to host the payment page

Choose **PaymentIntent** when:

- you already have a custom app flow
- you need tighter control over confirmation or capture
- you are doing backend-heavy or Connect-heavy payment logic

Choose **Checkout** when:

- you want the fastest safe path to card collection
- you do not want to build payment UX
- you want Stripe to handle the hosted payment page and return flow

The important production rule is the same either way:

**Do not fulfill from the browser redirect alone. Fulfill from the webhook-confirmed outcome.**

Read next:

- [Payments](payments.md)
- [Checkout](checkout.md)
- [Webhooks](webhooks.md)
- [Tax](tax.md) when you calculate tax on a custom cart before charging (standalone `Tax.Calculation` API)

### Job 2: "Start and run recurring billing"

This is where a SaaS starts to feel like a business instead of a payment form.

LatticeStripe gives you three complementary tools:

- **Subscriptions** for direct recurring billing control
- **Checkout subscription mode** for hosted signup into recurring billing
- **Customer Portal** for self-serve changes after signup

A clean recurring billing story often looks like this:

1. Create or look up the customer
2. Start the subscription, either directly or through Checkout
3. Provision on the success webhook
4. Let Stripe drive renewals and retry logic
5. React to subscription and invoice webhooks as the subscription evolves
6. Send the customer to the portal for payment method updates, cancellations, and plan changes

This is one of the strongest stories in the library today. It already covers:

- lifecycle verbs like cancel and resume
- pause collection
- trial settings
- phased schedules
- proration guards
- portal deep links for cancellation, plan change, and payment method update

The part to internalize is that there is no single "subscriptions feature." There is a
runtime loop:

**signup -> provisioning -> renewal -> failure handling -> self-service changes -> reconciliation**

Read next:

- [Checkout Signup and Portal Follow-Through](checkout-signup-and-portal.md)
- [Subscriptions](subscriptions.md)
- [Customer Portal](customer-portal.md)
- [Invoices](invoices.md)
- [Webhooks](webhooks.md)

### Job 3: "Let the customer fix billing problems without opening a support ticket"

This is the self-serve retention job.

The Customer Portal is for the moment when you want to stop building one-off billing screens
and start delegating routine account maintenance to Stripe:

- update a card after a failed payment
- cancel a subscription
- change a plan
- confirm a pending subscription change
- review invoices

In product terms, the portal is not just convenience. It is often the cheapest way to reduce:

- support load
- involuntary churn
- risky custom billing UI

The most useful pattern is deep-linking into a specific task instead of dropping the user on
the portal home page. If a payment failed, send them directly to payment method update. If
they clicked "cancel," send them straight into the cancellation flow.

There is one major caveat from Stripe's own product behavior:

**Portal updates are not universal. Some subscription shapes, especially usage-based or more
complex configurations, have limitations.**

That makes the portal a strong default, not a universal escape hatch.

Read next:

- [Customer Portal](customer-portal.md)
- [Subscriptions](subscriptions.md)
- [Webhooks](webhooks.md)

### Job 4: "Charge for usage instead of seats or flat plans"

This is the modern SaaS pricing job.

LatticeStripe now covers the full metering spine:

- define what is being measured with **Meter**
- report usage with **MeterEvent**
- correct mistakes with **MeterEventAdjustment**
- use **MeterEventStream** when event volume grows beyond the simple path

The good news: the library already teaches the hot-path concerns well, especially around
two-layer idempotency.

The important mental shift: metering is not a synchronous "increment counter" API.

It is closer to event ingestion:

- your app reports a usage fact
- Stripe accepts it for processing
- Stripe later decides whether that fact mapped cleanly to customer + value + meter
- reconciliation happens asynchronously

That means usage billing is one of the clearest examples of the rule from the top of this
guide:

**accepted now is not the same as billed correctly later**

If you are building usage-based pricing, you need all of these together:

- stable identifiers
- webhook handling
- replay-safe job logic
- a plan for late correction

Read next:

- [Metering Runtime and Reconciliation](metering-runtime-and-reconciliation.md)
- [Metering](metering.md)
- [Subscriptions](subscriptions.md)
- [Webhooks](webhooks.md)

### Job 5: "Bill later, not at checkout"

Some SaaS products are not card-now businesses.

You might:

- invoice after services are delivered
- let finance review draft invoices before they go out
- add ad hoc line items
- collect by ACH or manual payment later

That is the invoice-first job, and LatticeStripe already covers the core lifecycle well:

- draft invoice creation
- invoice items
- finalization
- payment collection
- send, void, search, and line item reading

This is the right path when your product looks more like consulting, enterprise SaaS,
annual contracting, or true-up billing than self-serve checkout.

The biggest footgun here is not technical sophistication. It is forgetting that Stripe will
auto-advance drafts unless you are explicit.

Read next:

- [Quote to Billing Operator Flow](quote-to-billing-operator.md)
- [Invoices](invoices.md)
- [Payments](payments.md)
- [Webhooks](webhooks.md)

### Job 6: "Run a marketplace or platform, not just a SaaS app"

Connect is the "money moves through us, but not only to us" job.

If your users are merchants, creators, vendors, or service providers, the real question is
usually not "do we support Connect?" It is "which money movement pattern matches our product?"

LatticeStripe supports the three important patterns:

- **Direct charges**
- **Destination charges**
- **Separate charges and transfers**

The product choice comes before the code choice:

- if the connected account is the merchant of record, lean direct
- if the platform charges and immediately routes funds, lean destination
- if one order splits across multiple parties, lean separate charges and transfers

This is one of the places where Stripe complexity is real. The library gives you the API
surface, but you still need clear product decisions about merchant of record, fee handling,
reconciliation, and operational ownership.

Read next:

- [Connect Platform Flow](connect-platform-flow.md)
- [Connect](connect.md)
- [Connect Accounts](connect-accounts.md)
- [Connect Money Movement](connect-money-movement.md)
- [Webhooks](webhooks.md)

### Job 7: "Sleep at night after shipping billing"

A billing library is only half about object creation. The other half is whether your team can
operate the integration under retries, outages, test clocks, webhook replays, and change over
time.

LatticeStripe has unusually strong coverage here for an SDK:

- webhook verification and Plug integration
- telemetry
- retry strategy hooks
- request batching
- circuit-breaker guidance
- testing helpers
- optional [Stripe explorer LiveBook](../notebooks/stripe_explorer.livemd) in the repo for interactive exploration

Maintainers can run `mix lattice_stripe.check_drift` to compare the SDK against
Stripe's OpenAPI spec — that is a release-tooling task, not a production runtime path.

This is not decorative. In practice, these are the tools that make the rest of the flows
safe enough to trust.

Read next:

- [Production Checklist](production-checklist.md)
- [Event Debugging](event-debugging.md)
- [Recipes](recipes.md) — disputes/files evidence spine (`File.create` → `update_evidence` →
  `submit_evidence`); Files, Disputes, and Mandates APIs are shipped — recipes carry the ops workflow
- [Testing](testing.md)
- [Telemetry](telemetry.md)
- [OpenTelemetry](opentelemetry.md)
- [Circuit Breaker](circuit-breaker.md)
- [Performance](performance.md)
- [Webhooks](webhooks.md)
- [Webhooks: Thin Events](webhooks-thin-events.md)

## Which Path Should You Choose?

### PaymentIntent vs Checkout

Choose **PaymentIntent** when control matters more than speed.

Choose **Checkout** when speed matters more than custom payment UX.

If you hear yourself saying, "We just need to start taking money this week," choose Checkout
first unless a real product constraint says otherwise.

### Direct subscription APIs vs Checkout subscription mode

Choose **Checkout subscription mode** when you want the shortest path to self-serve recurring
signup.

Choose **direct Subscription APIs** when signup is only one piece of a more custom account
creation or billing orchestration flow.

### Subscription updates in your app vs the Customer Portal

Choose the **Customer Portal** by default for routine self-service changes.

Choose **direct subscription mutations** when your business rules, pricing model, or UX exceed
what the portal can comfortably express.

### Invoices vs subscriptions

Choose **subscriptions** when the customer relationship is ongoing and predictable.

Choose **invoices** when each billing event is reviewed, assembled, or collected with more
human control.

### MeterEvent vs MeterEventStream

Choose **MeterEvent** when you want the simplest path and your usage volume is still ordinary.

Choose **MeterEventStream** when throughput becomes a first-order concern and the direct
single-event path stops being a comfortable fit.

### Direct charges vs destination charges vs separate charges and transfers

Use the Connect pattern that matches who should hold funds and who the merchant of record is.
This is a product architecture decision first and an API decision second.

## Production-Critical Truths

These are the rules most likely to save you from subtle bugs:

- **Webhooks are the source of truth for async state changes.**
- **Portal redirects and Checkout success redirects are not proof of state change.**
- **Metering is asynchronous, even when the create call succeeds.**
- **Idempotency belongs in app logic, not only at the HTTP layer.**
- **Catalog setup and runtime flows should usually be separated.**
- **Hosted Stripe flows are often the right default until you have a real reason to outgrow them.**

## What's Covered vs Where to Go Deeper

### Strong today

- direct payments
- hosted checkout
- subscription lifecycle management
- customer self-service portal sessions
- usage-based billing primitives
- invoice lifecycle
- Connect account and money-movement foundations
- operational glue: webhooks, retries, telemetry, testing

### Narrative gaps (API shipped; docs can go deeper)

Flagship recipe guides and [Recipes](recipes.md) already stitch common SaaS workflows
(checkout + portal, Connect platform, metering runtime, quote-to-billing). Remaining
narrative polish — not missing primitives:

- **Dispute and file evidence** — `recipes.md` documents File.create → `update_evidence` →
  `submit_evidence`; reason-specific field selection still adopter-owned
- **BillingPortal configuration** — programmatic CRUD is documented in
  [Customer Portal — Portal configurations](customer-portal.md#portal-configurations-programmatic-crud)

This guide routes you to the right canonical surface; recipes and flagship guides carry
the multi-module stories.

## A Practical Reading Order

If you are evaluating the library for your own SaaS, this is the shortest useful route:

1. [Getting Started](getting-started.md)
2. this guide
3. the guide that matches your first revenue path:
   - [Checkout](checkout.md)
   - [Payments](payments.md)
   - [Subscriptions](subscriptions.md)
   - [Invoices](invoices.md)
4. [Recipes](recipes.md) — compact job-to-primitive bridges and flagship guide entry points
5. [Webhooks](webhooks.md)
6. whichever operational guide matches your rollout needs:
   - [Production Checklist](production-checklist.md)
   - [Event Debugging](event-debugging.md)
   - [Recipes](recipes.md) — disputes, files, and evidence workflows
   - [Testing](testing.md)
   - [Telemetry](telemetry.md)
   - [Performance](performance.md)

If you are building a marketplace or platform, swap in the Connect guides early.

## The Short Version

If you want the one-paragraph summary:

LatticeStripe is already strong where most SaaS teams spend the bulk of their Stripe time:
payments, subscriptions, invoices, portal-driven self-service, metering, Connect, tax,
webhooks (including thin events), and production operator mechanics. The library's center of
gravity is "typed, idiomatic Elixir access to Stripe, with guards around expensive mistakes."
For v1.x scope the remaining delta is mostly narrative depth on secondary flows (disputes/files,
catalog design, mandate diagnostics) — not missing mainstream payment or billing primitives.
Use [Recipes](recipes.md) and the flagship guides when you need multi-module stories.
