# Phase 45: Flagship Recipes I - Research

**Researched:** 2026-05-26  
**Domain:** flagship SaaS recipe docs for hosted subscription signup, portal follow-through, and metering runtime/reconciliation  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

The bullets below are copied verbatim from `.planning/phases/45-flagship-recipes-i/45-CONTEXT.md`. [VERIFIED: local file .planning/phases/45-flagship-recipes-i/45-CONTEXT.md]

### Locked Decisions

- **D-01:** These flagship guides should be **workflow playbooks, not endpoint tours**. They should teach the operational spine of the flow, then route readers into canonical guides for deeper API truth.
- **D-02:** The durable truth model stays explicit everywhere: **API responses tell you what Stripe accepted now; webhooks or authoritative follow-up reads tell you what became true.**
- **D-03:** The guides should prefer **one recommended path** for each workflow rather than presenting multiple equal-weight approaches up front.
- **D-04:** The guides should stay **library-scoped and primitive-first**. They may show thin Phoenix integration examples, but must not drift into app-owned billing orchestration, entitlement logic, dunning policy, or operator UI ownership.
- **D-05:** The flagship guides should be **fuller and more concrete than the compact entries in `guides/recipes.md`**, but they still remain routing layers into canonical surface docs rather than becoming a second complete reference tree.
- **D-06:** The flagship signup recipe should use a **hosted recurring-billing spine**:
  `Customer` lookup/create -> `Checkout.Session.create(mode: "subscription")` -> webhook-confirmed provisioning -> later `BillingPortal.Session.create/3` follow-through.
- **D-07:** The recipe should frame **Checkout as the fastest safe path to production recurring billing** for serious Phoenix/Elixir SaaS teams who want strong defaults with minimal custom payment UI.
- **D-08:** The recipe should keep the Phoenix posture thin and idiomatic:
  controller/action creates the Checkout session and redirects;
  webhook handler verifies raw-body signatures and hands off quickly;
  any app state change is driven from webhook-confirmed subscription/invoice/payment truth rather than browser redirects.
- **D-09:** Any success-page retrieval after Checkout should be presented as an **idempotent UX optimization**, not as fulfillment authority.
- **D-10:** The recipe should explicitly encourage **customer reuse** when starting Checkout subscription flows so the guide does not accidentally teach duplicate-customer or duplicate-subscription confusion.
- **D-11:** The portal portion should teach **runtime self-serve follow-through**, not a policy engine.
- **D-12:** The recipe should show:
  one default portal-homepage session example;
  plus at most **two targeted deep-link examples** chosen from `payment_method_update`, `subscription_cancel`, and `subscription_update`.
- **D-13:** Portal guidance must include a short inline **limitations/truth callout**:
  portal is a strong default for common recurring SaaS flows, but it is not a universal control plane for complex subscription shapes.
- **D-14:** The recipe must not imply that LatticeStripe owns portal configuration policy or subscription UX orchestration. Where portal limitations matter, the guide should route users back to canonical subscription primitives instead of inventing helper abstractions.
- **D-15:** Portal session security remains part of the flagship story: `session.url` is a bearer credential, must be redirected to immediately, and must not be logged or persisted.
- **D-16:** The metering flagship guide should be **runtime-first**, not setup-first.
- **D-17:** The guide should open with a short prerequisite/setup-once section that points to canonical meter, price, and subscription setup docs, then spend most of its weight on the live runtime path:
  report usage -> classify sync failures -> reconcile async failures via webhooks -> correct mistakes via adjustments -> test/replay safely.
- **D-18:** Metering should be presented as **event ingestion**, not as a synchronous counter update API.
- **D-19:** The guide must emphasize **two-layer idempotency** and deterministic correlation:
  stable event identifiers, transport idempotency, and metadata/correlation keys that make reconciliation possible.
- **D-20:** The reconciliation story should be explicit about asynchronous failure and operator truth:
  a successful meter-event create response means accepted for processing, not necessarily billed correctly.
- **D-21:** The guide should include a short operator tail covering:
  webhook-confirmed error handling, correction via `MeterEventAdjustment`, testing posture, and the most important runtime footguns.
- **D-22:** The guide should not present search or immediate re-query patterns as authoritative read-after-write confirmation for usage billing.
- **D-23:** Phase 45 should preserve the Phase 44 docs architecture:
  flagship guides are **task-first routing aids layered over canonical surface docs**, not competing replacements for them.
- **D-24:** Each flagship guide should cross-link aggressively to the canonical docs that own deeper truth:
  Checkout, Subscriptions, Customer Portal, Metering, Webhooks, Testing, and Error Handling as appropriate.
- **D-25:** The recommended tone is **assertive, concrete, and low-magic**:
  show the safe path, explain why it is the safe path, and name the escape hatches without equal-weighting them.
- **D-26:** The guides should call out the most important footguns inline at the action point rather than hiding them in distant support notes.
- **D-27:** Copy-pasteable examples should remain **runtime-config-friendly and Phoenix-friendly**, matching prior guidance to prefer explicit runtime configuration and thin web-layer coordination.

### Claude's Discretion

- Exact guide titles, section names, and ordering
- Which two portal deep-link flows are the best fit for the flagship recipe, as long as the set stays bounded
- Exact meter-runtime example domain and event naming
- Exact wording of inline caveats and “read next” routing blocks
- Whether each flagship guide lives as its own guide file or another equivalent public-doc shape, as long as discovery and truth goals are met

### Deferred Ideas (OUT OF SCOPE)

- Any higher-level billing facade, customer/account domain model, or app-owned subscription orchestration belongs in Accrue, not in LatticeStripe docs or API shape.
- A broad cookbook covering many more workflows remains out of scope for Phase 45.
- Full setup-first guides for metering or custom-UI subscription orchestration are out of scope here; they can remain canonical-guide material or future secondary docs.
- Any attempt to hide webhook/state-machine complexity behind helper abstractions is out of scope for this phase.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RECIPE-01 | A developer can follow a flagship recipe for Checkout signup plus portal follow-through using shipped LatticeStripe primitives. | The local docs already expose the needed primitives and truth rails: `guides/checkout.md`, `guides/subscriptions.md`, `guides/customer-portal.md`, and `guides/webhooks.md` already cover hosted subscription Checkout, lifecycle webhooks, portal deep links, and redirect-not-authority rules. [VERIFIED: local files guides/checkout.md, guides/subscriptions.md, guides/customer-portal.md, guides/webhooks.md] Stripe’s current subscription Checkout guide also still recommends `checkout.session.completed`, `invoice.paid`, and `invoice.payment_failed`, then uses a customer portal session for follow-through. [CITED: https://docs.stripe.com/payments/checkout/build-subscriptions?locale=en-GB] |
| RECIPE-02 | A developer can follow a flagship recipe for metering runtime plus reconciliation using shipped LatticeStripe primitives. | The local docs already expose the needed runtime surfaces and operator truth: `guides/metering.md` teaches `Billing.MeterEvent`, `Billing.MeterEventAdjustment`, two-layer idempotency, and `v1.billing.meter.error_report_triggered`; `guides/webhooks.md`, `guides/testing.md`, and `guides/error-handling.md` provide the trust rails around them. [VERIFIED: local files guides/metering.md, guides/webhooks.md, guides/testing.md, guides/error-handling.md] Stripe’s current usage-based billing docs still describe meter events as asynchronous processing with explicit identifiers and webhook/error-report follow-through. [CITED: https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api?locale=en-GB] [CITED: https://docs.stripe.com/api/billing/meter-event/create?api-version=2025-06-30.preview] |
</phase_requirements>

## Summary

Phase 45 should ship exactly two flagship guides, each as a task-first routing layer over existing canonical docs rather than as a new workflow abstraction surface. The repo already has the primitives, trust language, and guide graph needed for both recipes: hosted Checkout, subscription lifecycle docs, portal deep links, metering runtime guidance, webhook truth, testing helpers, and error-handling posture are already present and consistent with the milestone boundary. [VERIFIED: local files .planning/ROADMAP.md, guides/checkout.md, guides/subscriptions.md, guides/customer-portal.md, guides/metering.md, guides/webhooks.md, guides/testing.md, guides/error-handling.md]

The first guide should teach a narrow recurring-billing spine: reuse or create the Stripe customer, create a subscription-mode Checkout Session, treat the browser success page as UX only, provision from webhook-confirmed truth, and then offer portal follow-through through one homepage example plus two targeted deep links. Stripe’s current docs still reinforce the same posture: `checkout.session.completed` starts the durable subscription record, `invoice.paid` and `invoice.payment_failed` drive the ongoing lifecycle, and the customer portal is the recommended self-serve follow-through surface. [CITED: https://docs.stripe.com/payments/checkout/build-subscriptions?locale=en-GB] [CITED: https://docs.stripe.com/checkout/fulfillment] [CITED: https://docs.stripe.com/billing/subscriptions/webhooks]

The second guide should teach runtime metering as event ingestion, not as read-after-write accounting. The local metering guide and current Stripe docs align on the operator model: meter-event creation is accepted-for-processing, stable identifiers and HTTP idempotency both matter, recent usage might not be visible immediately, and reconciliation happens asynchronously through error reports and corrective adjustments. That makes the right flagship story “report, classify, reconcile, correct, and test,” not “send event, immediately trust dashboard state.” [VERIFIED: local file guides/metering.md] [CITED: https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api?locale=en-GB] [CITED: https://docs.stripe.com/billing/subscriptions/usage-based/how-it-works] [CITED: https://docs.stripe.com/api/billing/meter-event/create?api-version=2025-06-30.preview]

**Primary recommendation:** create exactly two new flagship guide surfaces, one per roadmap plan, and wire each through `guides/recipes.md`, `guides/user-flows-and-jtbd.md`, ExDoc extras, and `test/lattice_stripe/docs_truth_test.exs` so the recipe entry points and truth rails stay locked. [VERIFIED: local files .planning/ROADMAP.md, mix.exs, test/lattice_stripe/docs_truth_test.exs]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Create recurring subscription signup entrypoint | Browser / Client | API / Backend | The browser only starts the hosted redirect; the backend creates the Checkout Session with secret-key access. [CITED: https://docs.stripe.com/payments/checkout/build-subscriptions?locale=en-GB] |
| Persist subscription/customer truth after signup | API / Backend | Frontend Server (SSR) | Subscription truth comes from webhook events and follow-up reads, not from the redirect page. [VERIFIED: local files guides/checkout.md, guides/subscriptions.md, guides/webhooks.md] [CITED: https://docs.stripe.com/checkout/fulfillment] [CITED: https://docs.stripe.com/billing/subscriptions/webhooks] |
| Open customer self-serve billing flows | API / Backend | Browser / Client | The backend creates portal sessions and returns a bearer URL; the browser immediately redirects. [VERIFIED: local file guides/customer-portal.md] [CITED: https://docs.stripe.com/api/customer_portal/sessions/create] |
| Manage recurring billing changes | Stripe-hosted surface | API / Backend | Checkout and the customer portal own the hosted UI, but the app backend still owns webhook handling and local state projection. [VERIFIED: local files guides/customer-portal.md, guides/webhooks.md] [CITED: https://docs.stripe.com/customer-management/portal-deep-links] |
| Report billable usage events | API / Backend | Background worker | Meter events are server-side writes with idempotency and correlation concerns; the browser should not own them. [VERIFIED: local file guides/metering.md] [CITED: https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api?locale=en-GB] |
| Reconcile usage-processing failures | API / Backend | Background worker | Stripe surfaces meter-processing failures asynchronously through webhook/error-report handling, which is backend/operator work. [VERIFIED: local files guides/metering.md, guides/webhooks.md] [CITED: https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api?locale=en-GB] |
| Publish flagship guides and truth checks | Frontend Server (SSR) | API / Backend | ExDoc publication and docs-truth assertions are the delivery surface for the recipes; no new runtime product tier is introduced. [VERIFIED: local files mix.exs, test/lattice_stripe/docs_truth_test.exs] |

## Project Constraints (from CLAUDE.md)

- Elixir must stay `1.15+` and OTP must stay `26+`; the current machine is on Elixir `1.19.5` and OTP `28`, so new docs/tests can assume the existing repo floor without raising it. [VERIFIED: local file CLAUDE.md] [VERIFIED: local command `elixir --version`]
- The library stays minimal-dependency, transport-behaviour-first, and JSON/Jason-based; Phase 45 should not add dependencies for documentation work. [VERIFIED: local file CLAUDE.md] [VERIFIED: local files mix.exs, mix.lock]
- The project is library-scoped, not a billing engine; recipe docs must not claim app-owned orchestration, entitlements, or dunning ownership that belongs in Accrue. [VERIFIED: local file CLAUDE.md] [VERIFIED: local file .planning/threads/lattice-stripe-vs-accrue-scope-boundary.md]
- Direct repo edits outside a GSD workflow are disallowed unless the user explicitly bypasses it; this research is already inside the requested GSD phase workflow. [VERIFIED: local file CLAUDE.md]

## Standard Stack

### Core

| Library / Surface | Version | Purpose | Why Standard |
|-------------------|---------|---------|--------------|
| `LatticeStripe.Checkout.Session` | `1.3.0` | Hosted recurring signup entrypoint for the first flagship recipe. [VERIFIED: local files mix.exs, guides/checkout.md] | The repo already documents subscription-mode Checkout as the safe hosted default, and Stripe’s current SaaS-subscription guide still centers Checkout plus webhook provisioning. [VERIFIED: local file guides/checkout.md] [CITED: https://docs.stripe.com/payments/checkout/build-subscriptions?locale=en-GB] |
| `LatticeStripe.BillingPortal.Session` | `1.3.0` | Hosted self-serve follow-through for payment-method updates and subscription changes. [VERIFIED: local files mix.exs, guides/customer-portal.md] | The local portal guide already covers homepage sessions plus deep-link flows, and Stripe still positions the customer portal as the standard follow-through surface for subscription management. [VERIFIED: local file guides/customer-portal.md] [CITED: https://docs.stripe.com/customer-management] [CITED: https://docs.stripe.com/customer-management/portal-deep-links] |
| `LatticeStripe.Billing.MeterEvent` + `LatticeStripe.Billing.MeterEventAdjustment` | `1.3.0` | Runtime usage ingestion and correction for the second flagship recipe. [VERIFIED: local files mix.exs, guides/metering.md] | The shipped metering guide already treats these as the canonical runtime and correction primitives, and Stripe’s current usage docs still center meter events with identifiers plus follow-up correction/reconciliation. [VERIFIED: local file guides/metering.md] [CITED: https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api?locale=en-GB] [CITED: https://docs.stripe.com/api/billing/meter-event/create?api-version=2025-06-30.preview] |
| `guides/webhooks.md` posture via `LatticeStripe.Webhook.Plug` | `1.3.0` | Truth rail for both recipes. [VERIFIED: local files mix.exs, guides/webhooks.md] | Both flagship flows depend on webhook-confirmed truth; the local guide and current Stripe docs agree that redirects and immediate API responses are not sufficient authority for durable state. [VERIFIED: local files guides/webhooks.md, guides/checkout.md, guides/customer-portal.md] [CITED: https://docs.stripe.com/checkout/fulfillment] [CITED: https://docs.stripe.com/billing/subscriptions/webhooks] |

### Supporting

| Library / Surface | Version | Purpose | When to Use |
|-------------------|---------|---------|-------------|
| ExDoc | `0.40.1` | Publish the new flagship guides and keep them in the existing guide ladder. [VERIFIED: local file mix.lock] | Use for new guide files, extras wiring, and “read next” discovery updates. [VERIFIED: local file mix.exs] |
| ExUnit docs-truth assertions | stdlib / Elixir `1.19.5` on this machine | Guard flagship guide publication and routing drift. [VERIFIED: local files test/lattice_stripe/docs_truth_test.exs, mix.exs] [VERIFIED: local command `mix --version`] | Use to assert the new guides are published, linked from recipes/JTBD, and keep redirect/webhook/metering truth language reachable. [VERIFIED: local file test/lattice_stripe/docs_truth_test.exs] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hosted Checkout signup recipe | Custom PaymentIntent or Elements flow | That broadens the flagship into app-owned UI and payment orchestration, which contradicts the phase boundary and weakens the “fastest safe path” posture. [VERIFIED: local file .planning/phases/45-flagship-recipes-i/45-CONTEXT.md] [CITED: https://docs.stripe.com/payments/checkout/build-subscriptions?locale=en-GB] |
| Portal follow-through via homepage + targeted deep links | Fully app-owned subscription-management UI | That moves LatticeStripe toward Cashier/Accrue-style workflow ownership and loses the current Stripe-hosted deep-link strengths already documented locally. [VERIFIED: local files .planning/threads/lattice-stripe-vs-accrue-scope-boundary.md, guides/customer-portal.md] [CITED: https://docs.stripe.com/customer-management/portal-deep-links] |
| Runtime meter-event ingestion | Nightly batch flush or read-after-write polling story | The local metering guide explicitly warns against batch flushes, and Stripe says event processing is asynchronous, so immediate confirmation stories are misleading. [VERIFIED: local file guides/metering.md] [CITED: https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api?locale=en-GB] |

**Installation:** no new dependencies; reuse the existing docs/test stack already declared in `mix.exs` and `mix.lock`. [VERIFIED: local files mix.exs, mix.lock]

## Recommended Artifact Set

1. `45-01-PLAN.md` should own one new flagship guide for Checkout signup plus portal follow-through, plus the minimum routing/test updates needed to publish it honestly. [VERIFIED: local file .planning/ROADMAP.md]
2. `45-02-PLAN.md` should own one new flagship guide for metering runtime plus reconciliation, plus the minimum routing/test updates needed to publish it honestly. [VERIFIED: local file .planning/ROADMAP.md]
3. Shared edits across the two plans should stay limited to guide discovery surfaces that already own routing truth: `guides/recipes.md`, `guides/user-flows-and-jtbd.md`, `mix.exs`, and `test/lattice_stripe/docs_truth_test.exs`. [VERIFIED: local files guides/recipes.md, guides/user-flows-and-jtbd.md, mix.exs, test/lattice_stripe/docs_truth_test.exs]

## Architecture Patterns

### System Architecture Diagram

```text
Checkout signup plus portal follow-through

User click
  -> Phoenix controller / action
  -> Customer lookup or create
  -> Checkout.Session.create(mode="subscription", customer=...)
  -> Redirect to Stripe Checkout
  -> Browser success page with session_id
      -> Optional session retrieval for UX only
  -> Stripe webhook delivery
      -> checkout.session.completed
      -> invoice.paid / invoice.payment_failed / customer.subscription.updated
  -> App persists subscription truth
  -> "Manage billing" action
      -> BillingPortal.Session.create(customer=..., return_url=..., flow_data?)
      -> Redirect to Stripe portal
      -> Portal deep-link action completes
      -> Webhook-confirmed local state projection
```

```text
Metering runtime plus reconciliation

Billable app event
  -> Server-side reporter builds stable identifier + correlation keys
  -> MeterEvent.create(..., identifier, idempotency_key)
  -> Immediate result classified as transient vs permanent transport/API outcome
  -> Stripe async processing pipeline
      -> success path contributes to billing
      -> failure path emits v1.billing.meter.error_report_triggered
  -> Webhook handler / operator job reconciles failures
  -> Optional MeterEventAdjustment correction
  -> Testing + replay harness proves reporter and webhook behavior
```

### Recommended Project Structure

```text
guides/
├── recipes.md                         # compact bridge; add links into the new flagship guides
├── user-flows-and-jtbd.md            # evaluator routing; add flagship-entry links
├── flagship-checkout-portal.md       # new Plan 45-01 guide
└── flagship-metering-reconciliation.md # new Plan 45-02 guide

test/lattice_stripe/
└── docs_truth_test.exs               # publication and routing assertions for both flagship guides
```

The exact filenames may vary, but two distinct public guide surfaces are the cleanest fit because ROADMAP already splits the phase into two plans and the flagship stories have different canonical clusters. [VERIFIED: local files .planning/ROADMAP.md, .planning/phases/45-flagship-recipes-i/45-CONTEXT.md]

### Pattern 1: Hosted subscription spine with webhook-owned truth

**What:** Teach `Customer` reuse -> `Checkout.Session.create(mode: "subscription")` -> webhook-confirmed provisioning -> portal follow-through as one end-to-end story. [VERIFIED: local file .planning/phases/45-flagship-recipes-i/45-CONTEXT.md]

**When to use:** Use this as the default flagship when the audience wants the fastest credible SaaS billing path with hosted UI and minimal custom payment surface. [CITED: https://docs.stripe.com/payments/checkout/build-subscriptions?locale=en-GB]

**Example:**

```elixir
# Source: guides/checkout.md + guides/customer-portal.md + guides/webhooks.md
{:ok, session} =
  LatticeStripe.Checkout.Session.create(client, %{
    "mode" => "subscription",
    "customer" => customer_id,
    "success_url" => "https://example.com/billing/success?session_id={CHECKOUT_SESSION_ID}",
    "cancel_url" => "https://example.com/pricing",
    "line_items" => [%{"price" => price_id, "quantity" => 1}]
  })

# Redirect now; persist truth from checkout.session.completed and invoice.* webhooks later.
redirect(conn, external: session.url)
```

### Pattern 2: Portal as bounded self-serve follow-through

**What:** Teach one homepage portal session plus two targeted deep links, with immediate redirect and explicit warning that `session.url` is a bearer credential and portal redirects are not authority. [VERIFIED: local file guides/customer-portal.md] [CITED: https://docs.stripe.com/customer-management/portal-deep-links]

**When to use:** Use when the customer already exists and the goal is payment-method recovery or routine subscription changes without inventing an app-owned billing console. [VERIFIED: local file guides/customer-portal.md] [CITED: https://docs.stripe.com/customer-management]

### Pattern 3: Runtime metering with asynchronous reconciliation

**What:** Teach the hot path as “emit a fact with stable identity, classify the immediate response, reconcile later through webhook/error-report handling, and correct with adjustments if needed.” [VERIFIED: local file guides/metering.md] [CITED: https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api?locale=en-GB]

**When to use:** Use when the audience needs a production operator story for usage billing rather than a setup-first explanation of meters and prices. [VERIFIED: local file .planning/phases/45-flagship-recipes-i/45-CONTEXT.md]

**Example:**

```elixir
# Source: guides/metering.md
event_id = "api_call:#{customer_id}:#{request_id}"

LatticeStripe.Billing.MeterEvent.create(client, %{
  "event_name" => "api_call",
  "payload" => %{"stripe_customer_id" => customer_id, "value" => "1"},
  "identifier" => event_id
}, idempotency_key: event_id)
```

### Anti-Patterns to Avoid

- **Redirect-as-authority:** Do not teach Checkout success pages or portal return URLs as fulfillment truth. [VERIFIED: local files guides/checkout.md, guides/customer-portal.md, guides/webhooks.md] [CITED: https://docs.stripe.com/checkout/fulfillment]
- **Duplicate-customer ambiguity:** Do not omit the “reuse existing customer when known” posture in the signup recipe. Stripe’s own one-subscription guidance keys off customer or email reuse, and the phase context locks this concern. [VERIFIED: local file .planning/phases/45-flagship-recipes-i/45-CONTEXT.md] [CITED: https://docs.stripe.com/payments/checkout/limit-subscriptions]
- **Portal-as-control-plane:** Do not imply that the customer portal handles every subscription shape or replaces canonical subscription primitives. [VERIFIED: local file guides/customer-portal.md] [CITED: https://docs.stripe.com/customer-management]
- **Synchronous metering fiction:** Do not present meter-event creation or immediate retrieval as proof that usage billed correctly. [VERIFIED: local file guides/metering.md] [CITED: https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api?locale=en-GB]
- **Accrue-style orchestration:** Do not add helper layers, entitlement policy, dunning policy, or operator UX ownership. [VERIFIED: local file .planning/threads/lattice-stripe-vs-accrue-scope-boundary.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Hosted subscription signup | Custom card form or business-workflow wrapper for the flagship path | `LatticeStripe.Checkout.Session` plus existing Checkout/Subcriptions/Webhooks guides | The hosted Stripe path already covers payment UI, SCA, and the current Stripe lifecycle story without forcing LatticeStripe into app-owned UX. [VERIFIED: local file guides/checkout.md] [CITED: https://docs.stripe.com/payments/checkout/build-subscriptions?locale=en-GB] |
| Self-serve billing management | Custom subscription-management console in the docs | `LatticeStripe.BillingPortal.Session` homepage + deep-link flows | Portal deep links already cover payment-method update and subscription change/cancel flows while keeping the SDK boundary clean. [VERIFIED: local file guides/customer-portal.md] [CITED: https://docs.stripe.com/customer-management/portal-deep-links] |
| Metering dedup and correction story | Ad-hoc counters, nightly flushes, or “just retry later” prose | Stable `identifier`, `idempotency_key`, webhook error reports, and `MeterEventAdjustment` | Metering edge cases are exactly where hand-rolled prose goes wrong; the shipped guide already encodes the guardrails, and Stripe’s current API still treats ingestion and processing as separate phases. [VERIFIED: local file guides/metering.md] [CITED: https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api?locale=en-GB] |
| Fulfillment authority | Browser redirect or success-page status check | Webhook-confirmed state projection | Stripe explicitly requires webhooks for reliable fulfillment, and the local docs already teach the same invariant. [VERIFIED: local files guides/checkout.md, guides/webhooks.md] [CITED: https://docs.stripe.com/checkout/fulfillment] |

**Key insight:** the flagship value comes from sequencing already-shipped primitives into a truthful operator story, not from inventing a higher-level workflow API. [VERIFIED: local files .planning/PROJECT.md, .planning/threads/lattice-stripe-vs-accrue-scope-boundary.md]

## Common Pitfalls

### Pitfall 1: Treating the Checkout success page as fulfillment truth

**What goes wrong:** The guide accidentally teaches provisioning from `success_url` or from a retrieved Checkout Session on page load. [VERIFIED: local file guides/checkout.md]  
**Why it happens:** Hosted flows look synchronous to the browser even though the durable lifecycle is webhook-driven. [CITED: https://docs.stripe.com/checkout/fulfillment]  
**How to avoid:** Present success-page retrieval strictly as a UX confirmation pattern and move durable provisioning into webhook examples. [VERIFIED: local files guides/checkout.md, guides/webhooks.md]  
**Warning signs:** Wording like “after redirect, mark the user subscribed” or examples that write app state in the controller before any webhook arrives. [VERIFIED: local files guides/checkout.md, guides/webhooks.md]

### Pitfall 2: Teaching portal URLs as ordinary links

**What goes wrong:** Users log, cache, or persist `session.url`, or assume the return redirect proves state change. [VERIFIED: local file guides/customer-portal.md]  
**Why it happens:** Portal sessions feel like generic redirect URLs unless the bearer-token and TTL rules are stated explicitly. [VERIFIED: local file guides/customer-portal.md] [CITED: https://docs.stripe.com/customer-management]  
**How to avoid:** Keep the existing security rule inline in the flagship guide and show immediate redirect only. [VERIFIED: local file guides/customer-portal.md]  
**Warning signs:** Example wrappers that return `session.url` for later storage, or prose that says “when the user returns, update the subscription.” [VERIFIED: local file guides/customer-portal.md]

### Pitfall 3: Presenting metering as a synchronous counter

**What goes wrong:** The guide implies a successful `MeterEvent.create/3` means usage was applied correctly and is immediately visible everywhere. [VERIFIED: local file guides/metering.md]  
**Why it happens:** The API call returns 200/201-style success, but Stripe processes usage asynchronously. [CITED: https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api?locale=en-GB]  
**How to avoid:** Center stable identifiers, webhook/error-report reconciliation, and adjustment-based correction in the main narrative. [VERIFIED: local file guides/metering.md]  
**Warning signs:** Read-after-write polling, dashboard-screenshot truth claims, or no mention of `v1.billing.meter.error_report_triggered`. [VERIFIED: local file guides/metering.md]

### Pitfall 4: Scope bleed into Accrue

**What goes wrong:** The recipe starts prescribing entitlements, dunning policy, internal account models, or admin workflows. [VERIFIED: local file .planning/threads/lattice-stripe-vs-accrue-scope-boundary.md]  
**Why it happens:** Flagship recipes naturally invite “and then your app should…” expansion unless the library boundary is enforced. [VERIFIED: local file .planning/phases/45-flagship-recipes-i/45-CONTEXT.md]  
**How to avoid:** Keep examples thin, Stripe-shaped, and webhook-centric; route product-policy concerns back to the application layer without trying to solve them here. [VERIFIED: local files .planning/threads/lattice-stripe-vs-accrue-scope-boundary.md, guides/webhooks.md]  
**Warning signs:** New helper modules, policy diagrams, or language that makes LatticeStripe sound like a SaaS billing engine. [VERIFIED: local file .planning/threads/lattice-stripe-vs-accrue-scope-boundary.md]

## Code Examples

Verified patterns from local truth and official docs:

### Checkout success page as UX only

```elixir
# Source: guides/checkout.md + Stripe Checkout fulfillment docs
def handle_success(conn, %{"session_id" => session_id}) do
  {:ok, session} = LatticeStripe.Checkout.Session.retrieve(client, session_id)

  render(conn, :success,
    customer_email: session.customer_details && session.customer_details.email
  )
end

# Durable provisioning still belongs in checkout.session.completed / invoice.* webhooks.
```

### Portal payment-method recovery deep link

```elixir
# Source: guides/customer-portal.md + Stripe portal deep links docs
{:ok, session} =
  LatticeStripe.BillingPortal.Session.create(client, %{
    "customer" => customer_id,
    "return_url" => "https://example.com/account",
    "flow_data" => %{"type" => "payment_method_update"}
  })

redirect(conn, external: session.url)
```

### Meter-event correction loop

```elixir
# Source: guides/metering.md
{:ok, _event} =
  LatticeStripe.Billing.MeterEvent.create(client, %{
    "event_name" => "api_call",
    "payload" => %{"stripe_customer_id" => customer_id, "value" => "1"},
    "identifier" => event_id
  }, idempotency_key: event_id)

# Later, if the event was a duplicate:
{:ok, _adjustment} =
  LatticeStripe.Billing.MeterEventAdjustment.create(client, %{
    "event_name" => "api_call",
    "cancel" => %{"identifier" => event_id}
  })
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| “Redirect means success” | Webhook-confirmed fulfillment and lifecycle handling | Current Stripe docs and current local guides as verified on 2026-05-26. [CITED: https://docs.stripe.com/checkout/fulfillment] [VERIFIED: local files guides/checkout.md, guides/webhooks.md] | The flagship recipe must teach redirects as UX only. [VERIFIED: local files guides/checkout.md, guides/webhooks.md] |
| “Portal is just a billing homepage” | Portal homepage plus bounded deep-link flows such as `payment_method_update`, `subscription_cancel`, and `subscription_update` | Current Stripe docs and current local guide as verified on 2026-05-26. [CITED: https://docs.stripe.com/customer-management/portal-deep-links] [VERIFIED: local file guides/customer-portal.md] | The portal portion can be concrete without becoming a custom billing UI guide. [VERIFIED: local files guides/customer-portal.md, .planning/phases/45-flagship-recipes-i/45-CONTEXT.md] |
| “Usage write accepted = billed correctly” | Meter events are identifiers plus async processing plus reconciliation | Current Stripe docs and current local guide as verified on 2026-05-26. [CITED: https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api?locale=en-GB] [VERIFIED: local file guides/metering.md] | The metering flagship should focus on reporting discipline and operator follow-through. [VERIFIED: local file guides/metering.md] |

**Deprecated/outdated:**

- Teaching metering through nightly batch flushes is explicitly rejected by the shipped local metering guide and should not appear in flagship docs. [VERIFIED: local file guides/metering.md]
- Teaching LatticeStripe as an Accrue-style workflow owner is out of scope for the milestone and contradicts the project boundary thread. [VERIFIED: local files .planning/threads/lattice-stripe-vs-accrue-scope-boundary.md, .planning/PROJECT.md]

## Assumptions Log

All material claims in this research were verified against local repo truth or cited current Stripe documentation during this session. [VERIFIED: local files and cited Stripe docs listed below]

## Open Questions

1. **Which two portal deep links should the flagship recipe keep?**
   What we know: the context allows at most two targeted deep-link examples, and the local guide already covers all four supported flow types. [VERIFIED: local files .planning/phases/45-flagship-recipes-i/45-CONTEXT.md, guides/customer-portal.md]
   What's unclear: whether the best flagship pair is `payment_method_update` + `subscription_cancel` or `payment_method_update` + `subscription_update`. [VERIFIED: local file .planning/phases/45-flagship-recipes-i/45-CONTEXT.md]
   Recommendation: default to `payment_method_update` + `subscription_cancel` because they best match the current Stripe “failed payment + cancellation risk” operator path and stay simpler than plan-change UI nuance. [CITED: https://docs.stripe.com/payments/checkout/build-subscriptions?locale=en-GB] [CITED: https://docs.stripe.com/customer-management/portal-deep-links]

2. **Where should the new guides live in ExDoc?**
   What we know: Phase 44 already split extras into `Start Here`, `Canonical Guides`, and `Operations & DX`, and the context allows a new public-doc shape as long as discovery stays honest. [VERIFIED: local files mix.exs, .planning/phases/45-flagship-recipes-i/45-CONTEXT.md]
   What's unclear: whether the flagship guides should sit in `Start Here` or form a small `Flagship Recipes` subgroup. [VERIFIED: local file mix.exs]
   Recommendation: keep them in `Start Here` unless publication density becomes confusing; the flagship guides are still routing aids, not canonical surface docs. [VERIFIED: local files mix.exs, .planning/phases/45-flagship-recipes-i/45-CONTEXT.md]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit on Elixir `1.19.5` in the current environment. [VERIFIED: local files test/lattice_stripe/docs_truth_test.exs, test/test_helper.exs] [VERIFIED: local command `mix --version`] |
| Config file | none; standard Mix/ExUnit project layout. [VERIFIED: local files mix.exs, test/test_helper.exs] |
| Quick run command | `mix test test/lattice_stripe/docs_truth_test.exs` [VERIFIED: local file test/lattice_stripe/docs_truth_test.exs] |
| Full suite command | `mix test` [VERIFIED: local file .github/workflows/ci.yml] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RECIPE-01 | Flagship Checkout + portal guide is published, linked from discovery surfaces, and preserves redirect/webhook truth. [VERIFIED: local files .planning/REQUIREMENTS.md, test/lattice_stripe/docs_truth_test.exs] | docs-truth unit | `mix test test/lattice_stripe/docs_truth_test.exs` | ✅ existing file; new assertions required. [VERIFIED: local file test/lattice_stripe/docs_truth_test.exs] |
| RECIPE-02 | Flagship metering + reconciliation guide is published, linked from discovery surfaces, and preserves async/idempotency/error-report truth. [VERIFIED: local files .planning/REQUIREMENTS.md, test/lattice_stripe/docs_truth_test.exs] | docs-truth unit | `mix test test/lattice_stripe/docs_truth_test.exs` | ✅ existing file; new assertions required. [VERIFIED: local file test/lattice_stripe/docs_truth_test.exs] |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/docs_truth_test.exs` [VERIFIED: local file test/lattice_stripe/docs_truth_test.exs]
- **Per wave merge:** `mix test` [VERIFIED: local file .github/workflows/ci.yml]
- **Phase gate:** Full docs-truth assertions for the two flagship guides must pass before `/gsd-verify-work`. [VERIFIED: local files .planning/REQUIREMENTS.md, test/lattice_stripe/docs_truth_test.exs]

### Wave 0 Gaps

- `test/lattice_stripe/docs_truth_test.exs` needs assertions that the two new flagship guides are published and linked from `guides/recipes.md` and `guides/user-flows-and-jtbd.md`. [VERIFIED: local files test/lattice_stripe/docs_truth_test.exs, guides/recipes.md, guides/user-flows-and-jtbd.md]
- The same test file should assert the flagship checkout guide retains redirect-not-authority wording and the flagship metering guide retains async-processing/idempotency/reconciliation wording at a durable anchor level. [VERIFIED: local files guides/checkout.md, guides/metering.md, test/lattice_stripe/docs_truth_test.exs]
- No new test framework install is needed. [VERIFIED: local files mix.exs, test/test_helper.exs]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | This phase does not add auth code, but portal return URLs must not be described as authentication. [VERIFIED: local file guides/customer-portal.md] |
| V3 Session Management | yes | Treat `BillingPortal.Session.url` as a bearer credential; redirect immediately and never log or persist it. [VERIFIED: local file guides/customer-portal.md] [CITED: https://docs.stripe.com/customer-management] |
| V4 Access Control | no | The phase is documentation-only and should not invent authorization policy. [VERIFIED: local files .planning/phases/45-flagship-recipes-i/45-CONTEXT.md, .planning/threads/lattice-stripe-vs-accrue-scope-boundary.md] |
| V5 Input Validation | yes | Webhook raw-body verification and stable string-keyed payload examples remain the standard control story. [VERIFIED: local files guides/webhooks.md, guides/metering.md] [CITED: https://docs.stripe.com/webhooks] |
| V6 Cryptography | yes | Keep `LatticeStripe.Webhook.Plug` / Stripe signature verification as the only documented webhook authenticity mechanism; do not hand-roll HMAC examples. [VERIFIED: local file guides/webhooks.md] [CITED: https://docs.stripe.com/webhooks/signature] |

### Known Threat Patterns for This Phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Fulfillment from browser redirect | Tampering | Teach webhook-confirmed provisioning only. [VERIFIED: local files guides/checkout.md, guides/webhooks.md] [CITED: https://docs.stripe.com/checkout/fulfillment] |
| Logging or caching portal session URLs | Information Disclosure | Keep the bearer-credential warning inline in the flagship guide and avoid examples that persist `session.url`. [VERIFIED: local file guides/customer-portal.md] |
| Mutated webhook body before verification | Spoofing | Keep the raw-body invariant and `Webhook.Plug` recommendation intact. [VERIFIED: local file guides/webhooks.md] [CITED: https://docs.stripe.com/webhooks/signature] |
| Duplicate or ambiguous usage events | Repudiation / Tampering | Require stable `identifier` plus `idempotency_key` in runtime metering examples. [VERIFIED: local file guides/metering.md] [CITED: https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api?locale=en-GB] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/45-flagship-recipes-i/45-CONTEXT.md` - locked recipe posture, scope, and plan split constraints.
- `.planning/ROADMAP.md` - Phase 45 goal and exact two-plan structure.
- `.planning/REQUIREMENTS.md` - `RECIPE-01` and `RECIPE-02`.
- `.planning/threads/lattice-stripe-vs-accrue-scope-boundary.md` - library boundary against Accrue-style workflow ownership.
- `guides/checkout.md` - local Checkout redirect/webhook posture.
- `guides/subscriptions.md` - local subscription lifecycle truth.
- `guides/customer-portal.md` - local portal deep links, security, and return-url truth.
- `guides/metering.md` - local metering idempotency, async reconciliation, and adjustments.
- `guides/webhooks.md` - local raw-body and webhook-confirmed truth posture.
- `guides/testing.md` - local docs/test helper posture for flagship-guide verification.
- `mix.exs` and `test/lattice_stripe/docs_truth_test.exs` - current docs publication and guardrail shape.
- https://docs.stripe.com/payments/checkout/build-subscriptions?locale=en-GB - current Checkout subscription flow, minimum events, and portal follow-through.
- https://docs.stripe.com/checkout/fulfillment - webhook-required fulfillment posture.
- https://docs.stripe.com/billing/subscriptions/webhooks - current subscription lifecycle webhook posture.
- https://docs.stripe.com/customer-management - current customer-portal capabilities, session expiry, and limits.
- https://docs.stripe.com/customer-management/portal-deep-links - current portal deep-link flows.
- https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api?locale=en-GB - current meter-event processing, idempotency, and async reconciliation posture.
- https://docs.stripe.com/api/billing/meter-event/create?api-version=2025-06-30.preview - current meter-event identifier contract.
- https://docs.stripe.com/billing/subscriptions/usage-based/how-it-works - current high-level meter-event runtime framing.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - all recommended surfaces already exist in repo truth and align with current Stripe docs. [VERIFIED: local files mix.exs, guides/checkout.md, guides/customer-portal.md, guides/metering.md] [CITED: https://docs.stripe.com/payments/checkout/build-subscriptions?locale=en-GB] [CITED: https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api?locale=en-GB]
- Architecture: HIGH - the roadmap, phase context, and existing local guides all point to the same two flagship stories with the same webhook-truth boundary. [VERIFIED: local files .planning/ROADMAP.md, .planning/phases/45-flagship-recipes-i/45-CONTEXT.md, guides/webhooks.md]
- Pitfalls: HIGH - the local guides already enumerate the main footguns, and current Stripe docs reinforce the same ones. [VERIFIED: local files guides/checkout.md, guides/customer-portal.md, guides/metering.md, guides/webhooks.md] [CITED: https://docs.stripe.com/checkout/fulfillment] [CITED: https://docs.stripe.com/customer-management] [CITED: https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api?locale=en-GB]

**Research date:** 2026-05-26  
**Valid until:** 2026-06-25 for local repo truth; re-check Stripe docs sooner if Stripe changes the billing/portal docs or meter-event API versions. [CITED: https://docs.stripe.com/payments/checkout/build-subscriptions?locale=en-GB] [CITED: https://docs.stripe.com/api/billing/meter-event/create?api-version=2025-06-30.preview]
