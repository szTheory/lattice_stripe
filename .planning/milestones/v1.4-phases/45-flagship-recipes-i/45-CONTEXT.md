# Phase 45: Flagship Recipes I - Context

**Gathered:** 2026-05-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Publish the first two flagship SaaS flow guides for the already-shipped `1.3.x` surface:

- Checkout signup plus portal follow-through
- Metering runtime plus reconciliation

These guides should feel concrete, operator-useful, and evaluator-friendly while staying firmly inside the LatticeStripe boundary: primitive-first, library-scoped, webhook-truthful, and explicitly not a billing-engine or app-workflow abstraction layer.

</domain>

<decisions>
## Implementation Decisions

### Flagship recipe posture

- **D-01:** These flagship guides should be **workflow playbooks, not endpoint tours**. They should teach the operational spine of the flow, then route readers into canonical guides for deeper API truth.
- **D-02:** The durable truth model stays explicit everywhere: **API responses tell you what Stripe accepted now; webhooks or authoritative follow-up reads tell you what became true.**
- **D-03:** The guides should prefer **one recommended path** for each workflow rather than presenting multiple equal-weight approaches up front.
- **D-04:** The guides should stay **library-scoped and primitive-first**. They may show thin Phoenix integration examples, but must not drift into app-owned billing orchestration, entitlement logic, dunning policy, or operator UI ownership.
- **D-05:** The flagship guides should be **fuller and more concrete than the compact entries in `guides/recipes.md`**, but they still remain routing layers into canonical surface docs rather than becoming a second complete reference tree.

### Checkout signup plus portal follow-through

- **D-06:** The flagship signup recipe should use a **hosted recurring-billing spine**:
  `Customer` lookup/create -> `Checkout.Session.create(mode: "subscription")` -> webhook-confirmed provisioning -> later `BillingPortal.Session.create/3` follow-through.
- **D-07:** The recipe should frame **Checkout as the fastest safe path to production recurring billing** for serious Phoenix/Elixir SaaS teams who want strong defaults with minimal custom payment UI.
- **D-08:** The recipe should keep the Phoenix posture thin and idiomatic:
  controller/action creates the Checkout session and redirects;
  webhook handler verifies raw-body signatures and hands off quickly;
  any app state change is driven from webhook-confirmed subscription/invoice/payment truth rather than browser redirects.
- **D-09:** Any success-page retrieval after Checkout should be presented as an **idempotent UX optimization**, not as fulfillment authority.
- **D-10:** The recipe should explicitly encourage **customer reuse** when starting Checkout subscription flows so the guide does not accidentally teach duplicate-customer or duplicate-subscription confusion.

### Portal follow-through depth

- **D-11:** The portal portion should teach **runtime self-serve follow-through**, not a policy engine.
- **D-12:** The recipe should show:
  one default portal-homepage session example;
  plus at most **two targeted deep-link examples** chosen from `payment_method_update`, `subscription_cancel`, and `subscription_update`.
- **D-13:** Portal guidance must include a short inline **limitations/truth callout**:
  portal is a strong default for common recurring SaaS flows, but it is not a universal control plane for complex subscription shapes.
- **D-14:** The recipe must not imply that LatticeStripe owns portal configuration policy or subscription UX orchestration. Where portal limitations matter, the guide should route users back to canonical subscription primitives instead of inventing helper abstractions.
- **D-15:** Portal session security remains part of the flagship story: `session.url` is a bearer credential, must be redirected to immediately, and must not be logged or persisted.

### Metering runtime plus reconciliation

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

### Information architecture and DX shape

- **D-23:** Phase 45 should preserve the Phase 44 docs architecture:
  flagship guides are **task-first routing aids layered over canonical surface docs**, not competing replacements for them.
- **D-24:** Each flagship guide should cross-link aggressively to the canonical docs that own deeper truth:
  Checkout, Subscriptions, Customer Portal, Metering, Webhooks, Testing, and Error Handling as appropriate.
- **D-25:** The recommended tone is **assertive, concrete, and low-magic**:
  show the safe path, explain why it is the safe path, and name the escape hatches without equal-weighting them.
- **D-26:** The guides should call out the most important footguns inline at the action point rather than hiding them in distant support notes.
- **D-27:** Copy-pasteable examples should remain **runtime-config-friendly and Phoenix-friendly**, matching prior guidance to prefer explicit runtime configuration and thin web-layer coordination.

### the agent's Discretion

- Exact guide titles, section names, and ordering
- Which two portal deep-link flows are the best fit for the flagship recipe, as long as the set stays bounded
- Exact meter-runtime example domain and event naming
- Exact wording of inline caveats and “read next” routing blocks
- Whether each flagship guide lives as its own guide file or another equivalent public-doc shape, as long as discovery and truth goals are met

</decisions>

<specifics>
## Specific Ideas

- The checkout recipe should feel like:
  “start recurring billing quickly with hosted Checkout, then operate the lifecycle honestly with webhooks and portal follow-through.”
- The metering recipe should feel like:
  “report usage on the hot path without lying to yourself about billing truth, then reconcile and correct like an operator.”
- The strongest ecosystem lesson to preserve is that **mature billing docs either stay low-magic and webhook-centric, or they take ownership of app state by syncing Stripe into their own product layer**. LatticeStripe must stay on the first side of that line.
- The flagship guides should make the repo feel like a mature Elixir library:
  one clear path, strong cross-links, honest caveats, tuple-friendly examples, and no surprise abstractions.
- The recipes should explicitly acknowledge current Stripe reality where useful:
  hosted flows vs custom flows, async event truth, modern meter events instead of legacy usage records, and bounded support where product/runtime complexity exceeds the SDK layer.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone truth
- `.planning/PROJECT.md` — v1.4 adoption-closure goal, primitive-first recipe philosophy, and library scope
- `.planning/REQUIREMENTS.md` — `RECIPE-01` and `RECIPE-02`
- `.planning/ROADMAP.md` — Phase 45 goal and plan split
- `.planning/STATE.md` — current milestone position and readiness
- `.planning/threads/v1-4-adoption-closure.md` — adoption-closure rationale and flagship-guide expectations
- `.planning/threads/lattice-stripe-vs-accrue-scope-boundary.md` — hard SDK-vs-Accrue scope line

### Prior phase decisions that constrain this phase
- `.planning/phases/06-refunds-checkout/06-CONTEXT.md` — Checkout surface design and DX posture
- `.planning/phases/20-billing-metering/20-CONTEXT.md` — metering mental model, idempotency, and guard posture
- `.planning/phases/21-customer-portal/21-CONTEXT.md` — portal surface, deep-linking, security, and limits
- `.planning/phases/37-dx-polish/37-CONTEXT.md` — compact recipes precedent, one-clear-path preference, and webhook-truth posture
- `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-CONTEXT.md` — explicit bounded-proof language pattern
- `.planning/phases/42-planning-truth-reconciliation/42-CONTEXT.md` — layered truth model and pending-external-verification semantics
- `.planning/phases/44-guide-discovery-support-truth/44-CONTEXT.md` — task-first routing over canonical surface docs and inline support-truth rules

### Current local guides and tests
- `guides/recipes.md` — current compact workflow bridge that Phase 45 should deepen without replacing
- `guides/user-flows-and-jtbd.md` — task-first evaluator map and current recurring-billing / metering framing
- `guides/checkout.md` — canonical Checkout surface guide
- `guides/subscriptions.md` — canonical recurring-billing lifecycle guide
- `guides/customer-portal.md` — canonical portal guide and deep-link/runtime truth
- `guides/metering.md` — canonical meter, meter-event, adjustment, and reconciliation guide
- `guides/webhooks.md` — canonical async truth and raw-body verification guide
- `guides/testing.md` — testing posture and helper surface
- `guides/error-handling.md` — operational error and troubleshooting posture
- `README.md` — top-level public routing expectations
- `mix.exs` — ExDoc groups and guide publication model
- `test/lattice_stripe/docs_truth_test.exs` — current task-first-routing and canonical-guide-publication assertions

### Prompt corpus to honor
- `prompts/elixir-best-practices-deep-research.md`
- `prompts/elixir-opensource-libs-best-practices-deep-research.md`
- `prompts/phoenix-best-practices-deep-research.md`
- `prompts/stripe-lib-priority-user-flows-deep-research.md`
- `prompts/stripe-sdk-api-surface-area-deep-research.md`
- `prompts/payments_domain_field_guide.md`
- `prompts/The definitive Stripe library gap in Elixir - a master research document.md`
- `prompts/stripe-explanation-domain-language-deep-research.md`

### External ecosystem references
- `https://docs.stripe.com/billing/subscriptions/build-subscriptions?payment-ui=checkout&ui=embedded-form` — current Checkout-to-subscription integration spine and portal handoff
- `https://docs.stripe.com/billing/subscriptions/webhooks` — subscription lifecycle truth and required webhook events
- `https://docs.stripe.com/checkout/fulfillment` — redirect is not fulfillment authority
- `https://docs.stripe.com/api/checkout/sessions` — Checkout Session parameters and current object behavior
- `https://docs.stripe.com/api/customer_portal/sessions` — portal session contract
- `https://docs.stripe.com/billing/subscriptions/customer-portal` — portal capabilities and product limits
- `https://docs.stripe.com/customer-management/portal-deep-links` — targeted portal flows
- `https://docs.stripe.com/api/billing/meter-event/create` — meter event contract and identifier semantics
- `https://docs.stripe.com/billing/subscriptions/usage-based/recording-usage-api` — current usage-reporting workflow and idempotency guidance
- `https://docs.stripe.com/billing/subscriptions/usage-based/how-it-works` — meter-event runtime framing
- `https://github.com/stripe-samples/checkout-single-subscription` — current hosted-checkout subscription sample posture
- `https://github.com/stripe-samples/subscription-use-cases` — sample split between fixed-price and usage-based billing
- `https://github.com/pay-rails/pay/blob/main/docs/7_webhooks.md` — mature webhook-first billing-doc posture
- `https://github.com/dj-stripe/dj-stripe` — contrasting sync-Stripe-into-your-app model that LatticeStripe should not emulate
- `https://laravel.com/docs/11.x/billing` — successful higher-level Cashier posture to learn from while explicitly not copying its app-owned abstraction boundary
- `https://hexdocs.pm/ecto/getting-started.html` — Elixir precedent for strong onboarding plus stable reference spine
- `https://hexdocs.pm/ecto/api-reference.html` — canonical reference split pattern
- `https://hexdocs.pm/plug/Plug.Parsers.html` — raw-body/webhook handling precedent
- `https://hexdocs.pm/phoenix/Phoenix.Router.html` — thin Phoenix routing / forwarding precedent
- `https://hexdocs.pm/oban/Oban.html` — mature Elixir docs pattern for clear quickstart plus deeper operational truth

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `guides/recipes.md` already establishes the compact bridge posture that these flagship guides should expand from.
- `guides/customer-portal.md` already contains strong Phoenix-style examples, explicit session-url security rules, and concrete deep-link coverage.
- `guides/metering.md` already contains the strongest local runtime truth for meter events, idempotency, corrections, and reconciliation.
- `guides/webhooks.md`, `guides/testing.md`, and `guides/error-handling.md` already form the trust-rail cluster these flagship guides should route into.
- `test/lattice_stripe/docs_truth_test.exs` already encodes the rule that JTBD/recipes stay task-first routing layers into canonical guides.

### Established Patterns
- The repo is strongest when it recommends one clear path first, then points to deeper guides.
- Hosted flows are presented as valid high-leverage defaults when they reduce complexity without hiding operational truth.
- Public examples stay explicit, runtime-config-friendly, and honest about async boundaries.
- Support truth is stated inline at the point where omission would create false confidence.

### Integration Points
- new flagship guide(s) for Checkout signup plus portal follow-through
- new flagship guide(s) for metering runtime plus reconciliation
- `guides/recipes.md` and `guides/user-flows-and-jtbd.md` for routing into the new flagship surfaces
- `mix.exs` and docs-truth tests if publication/discovery wiring changes
- existing canonical guides for “read next” graph and inline truth consistency

</code_context>

<deferred>
## Deferred Ideas

- Any higher-level billing facade, customer/account domain model, or app-owned subscription orchestration belongs in Accrue, not in LatticeStripe docs or API shape.
- A broad cookbook covering many more workflows remains out of scope for Phase 45.
- Full setup-first guides for metering or custom-UI subscription orchestration are out of scope here; they can remain canonical-guide material or future secondary docs.
- Any attempt to hide webhook/state-machine complexity behind helper abstractions is out of scope for this phase.

</deferred>

---

*Phase: 45-flagship-recipes-i*
*Context gathered: 2026-05-26*
