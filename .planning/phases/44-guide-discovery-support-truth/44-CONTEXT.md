# Phase 44: Guide Discovery & Support Truth - Context

**Gathered:** 2026-05-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the already-shipped high-leverage LatticeStripe surfaces easier to discover from the main public entry points without turning the docs into a second billing product or a broad rewrite of every guide.

This phase is about docs information architecture, guide routing, cross-links, and support-truth posture for the shipped `1.3.x` surface. It does **not** add new SDK capabilities, broaden recipes into Accrue-style workflow ownership, or change the already-accepted Phase `41.1` external-proof boundary.

</domain>

<decisions>
## Implementation Decisions

### Canonical docs architecture

- **D-01:** The canonical docs map should stay **surface-first**, not task-first. Stable top-level guide homes remain organized around shipped Stripe surface areas and operational concerns.
- **D-02:** **Task-first guidance is a routing layer**, not a competing canonical map. `guides/user-flows-and-jtbd.md` and `guides/recipes.md` should route evaluators into the right canonical guides instead of becoming a second equal-weight documentation tree.
- **D-03:** `guides/getting-started.md` remains the HexDocs landing page. That is the least-surprise default for Elixir/HexDocs users and should not be replaced by a broader conceptual or workflow-first page.
- **D-04:** ExDoc guide organization should reflect explicit entry-point roles instead of one flat “Guides” bucket. Planning may reorganize extras/groups to distinguish “start here”, canonical surface guides, and operations/DX guidance.

### Discovery and prominence strategy

- **D-05:** Phase 44 should use a **split-prominence model by entry point**, not one universal ranking for every docs surface.
- **D-06:** `README.md` and `guides/user-flows-and-jtbd.md` should lead discovery with the **runtime billing spine** that serious SaaS evaluators care about most: subscriptions/recurring billing, customer portal follow-through, webhook-confirmed truth, metering runtime/reconciliation, Connect, and operations/troubleshooting.
- **D-07:** `guides/getting-started.md` should stay **payments/checkout-first for first success**, then branch clearly into the higher-leverage recurring-billing, webhook, Connect, metering, testing, and troubleshooting paths.
- **D-08:** `guides/recipes.md` should remain a compact bridge from jobs to primitives and canonical guides, not a cookbook that becomes the primary source of API behavior truth.
- **D-09:** The guide graph should elevate **webhooks, testing, error handling, customer portal, metering, and Connect** as first-class follow-through surfaces because they create evaluator trust and reflect the real maturity of the shipped SDK.

### Support-truth posture

- **D-10:** The default support-truth posture is **explicit inline honesty at the point of use**. High-stakes operational boundaries should be stated where users copy, evaluate, or act, not hidden behind cross-links.
- **D-11:** A centralized support-truth or orientation page is acceptable only as a **secondary synthesis page**, not as the sole place where critical caveats live.
- **D-12:** Critical truth statements should stay short, repeated only where omission would create false confidence, and phrased as operational fact rather than apology.
- **D-13:** The core vocabulary should stay consistent across guides: `accepted`, `confirmed`, `authoritative`, `webhook-confirmed`, `supported`, `bounded`, and `pending external verification`.
- **D-14:** The project’s strongest existing truth rule remains canonical in public docs: **API responses tell you what Stripe accepted now; webhooks or follow-up authority confirm what became true.**
- **D-15:** Public docs must remain honest about bounded proof. Future operator guidance, especially quote-related follow-through, must preserve the explicit Phase `41.1` external-verification boundary instead of smoothing it away.

### Scope discipline and ecosystem fit

- **D-16:** Phase 44 should follow the mature Elixir OSS pattern: stable reference/surface docs first, with onboarding and workflow-routing layers on top. Do not copy Stripe’s full product-doc IA wholesale, because LatticeStripe is a library, not Stripe’s end-user platform.
- **D-17:** The docs should optimize for **serious Elixir/Phoenix SaaS evaluators** rather than the broadest generic payments funnel. This milestone is adoption closure, not growth-hack top-of-funnel simplification.
- **D-18:** The docs must not drift into Accrue territory. Cross-resource stories may explain primitives and truthful follow-through, but must stop short of app-owned billing-engine orchestration, entitlement logic, dunning policy, or operator UX ownership.

### the agent's Discretion

- Exact ExDoc grouping names and the final guide-bucket labeling
- Exact wording of the route-by-intent sections in README and Getting Started
- Exact cross-link placement and “read next” ordering inside individual guides
- Whether a small centralized support-truth/orientation page is worthwhile, as long as it remains secondary to inline truth

</decisions>

<specifics>
## Specific Ideas

- Treat the docs system as a **ladder**, not a flat list:
  - `README.md` = first impression and route by intent
  - `guides/getting-started.md` = first successful API call
  - `guides/user-flows-and-jtbd.md` = evaluator mental model
  - canonical surface guides = stable truth for each Stripe family
  - `guides/recipes.md` = compact bridge from jobs to primitives
  - `guides/webhooks.md`, `guides/testing.md`, `guides/error-handling.md` = trust rails
- The apparent tension between “surface-first” and “task-first” is resolved by role separation:
  - canonical docs architecture stays surface-first
  - discovery and evaluation routing can be task-first where appropriate
- The public story should make the repo feel like a mature Elixir SDK:
  - easy first-run success
  - explicit operational truth
  - obvious paths into recurring billing, metering, Connect, and webhook-driven reality
- Strong ecosystem pattern to emulate:
  - Elixir/HexDocs libraries keep a stable reference spine
  - Stripe-style workflow guides are useful as routing aids
  - critical caveats appear inline at the action point

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone truth
- `.planning/PROJECT.md` — v1.4 adoption-closure goal, shipped-surface posture, and scope philosophy
- `.planning/REQUIREMENTS.md` — `VERIFY-02`, `GUIDE-01`, and `GUIDE-02`
- `.planning/STATE.md` — current milestone position and Phase 44 focus
- `.planning/ROADMAP.md` — Phase 44 goal and plan split
- `.planning/threads/v1-4-adoption-closure.md` — milestone rationale, done-enough bar, and non-goals
- `.planning/threads/lattice-stripe-vs-accrue-scope-boundary.md` — SDK-vs-Accrue scope rule

### Prior decisions that constrain this phase
- `.planning/phases/10-documentation-guides/10-CONTEXT.md` — ExDoc landing-page and guide-organization precedent
- `.planning/phases/37-dx-polish/37-CONTEXT.md` — webhook/testing/recipes/doc-truth posture and “one clear path” preference
- `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-CONTEXT.md` — explicit downstream-proof boundary that docs must preserve honestly
- `.planning/phases/42-planning-truth-reconciliation/42-CONTEXT.md` — layered truth model and explicit pending-external-verification semantics
- `.planning/phases/43-public-truth-baseline/43-RESEARCH.md` — public-truth baseline and anti-scope-creep reminder
- `.planning/phases/43-public-truth-baseline/43-PATTERNS.md` — current public entry-point and docs-truth guardrails

### Current docs entry points and guide graph
- `README.md` — repo landing page and current feature/discovery story
- `guides/getting-started.md` — HexDocs main page and first-run onboarding path
- `guides/user-flows-and-jtbd.md` — task-first evaluator/orientation guide
- `guides/recipes.md` — bridge from jobs to primitives
- `guides/subscriptions.md` — recurring-billing canonical guide
- `guides/customer-portal.md` — self-serve billing/runtime follow-through
- `guides/metering.md` — usage billing and reconciliation path
- `guides/connect.md` — conceptual Connect landing guide
- `guides/connect-accounts.md` — Connect account lifecycle guide
- `guides/connect-money-movement.md` — money-movement guide
- `guides/webhooks.md` — canonical async truth and raw-body guide
- `guides/testing.md` — testing surface and proof-boundary guide
- `guides/error-handling.md` — troubleshooting and support-facing error story
- `guides/payments.md` — payment primitive guide
- `guides/checkout.md` — hosted payments/subscription entry path
- `mix.exs` — ExDoc `main`, `extras`, and grouping configuration
- `test/lattice_stripe/docs_truth_test.exs` — docs-truth guardrail on high-visibility public surfaces

### Prompt corpus to honor
- `prompts/elixir-best-practices-deep-research.md`
- `prompts/elixir-opensource-libs-best-practices-deep-research.md`
- `prompts/phoenix-best-practices-deep-research.md`
- `prompts/stripe-lib-priority-user-flows-deep-research.md`
- `prompts/stripe-sdk-api-surface-area-deep-research.md`
- `prompts/payments_domain_field_guide.md`
- `prompts/The definitive Stripe library gap in Elixir - a master research document.md`

### External ecosystem references
- `https://hexdocs.pm/ex_doc/0.38.1/Mix.Tasks.Docs.html` — ExDoc grouping model for layered navigation
- `https://hexdocs.pm/ecto/getting-started.html` — Elixir precedent for strong onboarding + reference split
- `https://hexdocs.pm/ecto/api-reference.html` — reference-oriented canonical surface map
- `https://github.com/oban-bg/oban` — quickstart plus deeper guide split in mature Elixir OSS
- `https://docs.stripe.com/billing/subscriptions/build-subscriptions` — task-first integration routing precedent
- `https://docs.stripe.com/billing/subscriptions/webhooks` — webhook-confirmed billing truth
- `https://docs.stripe.com/billing/subscriptions/customer-portal` — self-serve runtime billing flow
- `https://docs.stripe.com/billing/subscriptions/usage-based/how-it-works` — usage-billing runtime framing
- `https://docs.stripe.com/payments/accept-a-payment?payment-ui=elements` — payments/checkout first-success path
- `https://docs.stripe.com/payments/checkout/custom-success-page?payment-ui=embedded-page` — redirect page is not fulfillment truth
- `https://docs.stripe.com/checkout/fulfillment` — webhook-confirmed order/payment fulfillment guidance
- `https://docs.stripe.com/webhooks` — delivery, retries, and raw-body verification truth
- `https://docs.stripe.com/api/versioning` — thin-event/versioning context for future support-truth notes
- `https://docs.stripe.com/api/quotes/accept` — quote accept contract that interacts with the Phase `41.1` boundary
- `https://github.com/pay-rails/pay` — mature billing-doc emphasis on subscriptions/webhooks/connect
- `https://laravel.com/docs/12.x/billing` — Cashier precedent for recurring-billing/runtime prominence
- `https://github.com/stripe/stripe-go` — reference-oriented official SDK posture
- `https://github.com/beam-community/stripity-stripe` — cautionary local-ecosystem contrast on discoverability and opinionated routing

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `guides/user-flows-and-jtbd.md` already provides the task-first orientation layer; it should be sharpened and routed, not replaced.
- `guides/recipes.md` already uses compact workflow slices with explicit webhook confirmation points.
- `guides/webhooks.md`, `guides/testing.md`, and `guides/error-handling.md` already form a strong trust-rail cluster for support truth.
- `mix.exs` already establishes `guides/getting-started.md` as the docs landing page and exposes a broad guide set through ExDoc extras.
- `test/lattice_stripe/docs_truth_test.exs` already guards high-visibility public truth and can support additional discovery/support-truth checks if needed.

### Established Patterns
- Public docs are strongest when they recommend one clear path and then deep-link outward.
- The repo already favors explicit, non-magical phrasing and bounded claims over glossy simplification.
- Existing JTBD and recipe guides already act as bridges; the missing piece is a clearer, more opinionated routing hierarchy from public entry points.
- Current guide cross-links are present but uneven; the discovery problem is more about hierarchy and prominence than about starting from zero.

### Integration Points
- `README.md` — route-by-intent framing and high-level surfaced priorities
- `guides/getting-started.md` — first-run path plus explicit branching
- `guides/user-flows-and-jtbd.md` — evaluator path and surfaced priorities
- `guides/recipes.md` — compact bridge and follow-through routing
- `mix.exs` — ExDoc extras/groups reorganization
- individual surface guides — improved “read next” graph and inline support-truth notes where omission would mislead

</code_context>

<deferred>
## Deferred Ideas

- Turning the docs into a broad rewrite of every guide — out of scope for Phase 44
- Turning recipes or JTBD guidance into Accrue-style workflow ownership or billing-engine architecture — out of scope
- Creating a large standalone support handbook that becomes the only place truth lives — not the default for this phase
- Any new Stripe surface, webhook implementation wedge, or resolution of the Phase `41.1` external-proof gap — separate future work

</deferred>

---

*Phase: 44-guide-discovery-support-truth*
*Context gathered: 2026-05-26*
