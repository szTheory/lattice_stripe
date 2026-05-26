# Phase 46: Flagship Recipes II & Planning Truth Closure - Context

**Gathered:** 2026-05-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 46 finishes the v1.4 adoption-closure milestone in two linked ways:

- publish the remaining flagship guides for the already-shipped `1.3.x` surface:
  - Connect platform flow
  - quote-to-billing operator guidance
- reconcile milestone-close planning truth so v1.4 can close honestly without flattening the accepted Phase `41.1` external-proof boundary into a false “everything is fully proved” story

This phase is still docs/truth work, not new SDK capability work. It must stay primitive-first, library-scoped, webhook-truthful, and explicitly outside Accrue-style orchestration, entitlement logic, dunning policy, or operator-product ownership.

</domain>

<decisions>
## Implementation Decisions

### Cross-phase flagship posture

- **D-01:** Phase 46 inherits the Phase 45 flagship pattern unchanged: guides are **workflow playbooks, not endpoint tours**.
- **D-02:** Each guide should teach **one recommended path first**, then name the narrower cases that should switch to a different pattern without equal-weighting them.
- **D-03:** The durable truth model remains explicit everywhere: **API responses tell you what Stripe accepted now; webhooks or authoritative follow-up reads tell you what became true.**
- **D-04:** The guides must stay **library-scoped and primitive-first**. They may show thin Phoenix/Plug integration examples, but they must not become app-owned workflow products.
- **D-05:** Public docs should keep **critical truth at the action point**. Planning artifacts should carry any stronger audit-style boundary language.

### Connect flagship spine

- **D-06:** The Connect flagship guide should use **Express onboarding -> destination charges -> payout/reconciliation** as the default platform flow.
- **D-07:** The guide should frame this path as the **shortest truthful route from onboarding to money movement** when each payment belongs to one connected account.
- **D-08:** The guide should keep the Phoenix posture thin and idiomatic:
  controller/action creates `AccountLink` or destination-charge `PaymentIntent`;
  redirect immediately to bearer URLs;
  webhook handler owns durable account/capability/payment/fee/payout truth.
- **D-09:** The guide must explicitly distinguish:
  `Transfer` = Stripe balance to connected Stripe balance;
  `Payout` = Stripe balance to bank/debit card.
- **D-10:** The guide should include a short **“switch patterns when…”** section that routes users to separate charges and transfers only when:
  one payment must split across multiple connected accounts,
  seller assignment is delayed,
  or transfer timing must be decoupled from the original charge.
- **D-11:** The guide must not present separate charges and transfers as a co-equal default, because that pushes the flagship story toward app-owned ledger/orchestration complexity too early.
- **D-12:** Connect guide callouts must include the most important inline footguns:
  `AccountLink`/`LoginLink` URLs are bearer credentials;
  raw-body webhook truth matters;
  `application_fee_amount`, `transfer_data.destination`, `on_behalf_of`, and `transfer_group` are load-bearing parameters;
  polling is not the authority path.

### Quote-to-billing flagship posture

- **D-13:** The quote flagship guide should use a **concrete but bounded** operator path:
  `Quote.create -> Quote.finalize -> Quote.accept -> inspect returned downstream ref -> retrieve at most one linked downstream resource -> hand off to webhook/authoritative follow-up truth`.
- **D-14:** The guide should describe the downstream-reference inspection order explicitly:
  `invoice`, then `subscription`, then `subscription_schedule`.
- **D-15:** The guide must state clearly that `Quote.accept/3` proves **Stripe accepted the quote transition**, not that payment, provisioning, activation, or customer-visible billing state is fully settled.
- **D-16:** The guide should keep one concrete downstream operator step because serious evaluators need an actionable next move, not just a caveat memo.
- **D-17:** The guide must not imply that quote acceptance deterministically yields the same downstream object every time. The result depends on quote shape and timing.
- **D-18:** The guide must stop before entitlement logic, dunning policy, local billing-engine coordination, or operator UI decisions. Those belong in application code or Accrue.

### Phase 41.1 proof-boundary disclosure

- **D-19:** Use a **bounded dual-placement** disclosure posture:
  one short inline truth callout in the public quote/operator guide,
  plus one explicit named proof-boundary section in planning/milestone-close artifacts.
- **D-20:** Public docs should explain the issue as a **proof boundary**, not as planning-history narration. Avoid naming `41.1` repeatedly in user-facing copy unless the internal phase reference is specifically useful.
- **D-21:** Planning artifacts must preserve `pending-external-verification` as a first-class truthful state for the accepted downstream Quote follow-through gap.
- **D-22:** Avoid caveat spam. The gap is real but narrow; repeating it everywhere would overstate its product significance.

### Planning-truth closure posture

- **D-23:** The governing planning-close posture is:
  **v1.4 becomes close-ready when Phase 46 lands, while Phase `41.1` remains a separate accepted v1.3 follow-through item in `pending-external-verification`.**
- **D-24:** Phase 46 should reconcile the active planning truth and current-state trust anchors, not just the minimum active files:
  `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and `PROJECT.md`.
- **D-25:** Broader milestone-close wording may also update the current audit/close posture if needed, but must do so **without rewriting archived v1.3 history to pretend the prior boundary changed**.
- **D-26:** `PLAN-01` should be considered satisfied only when milestone artifacts are coherent **and** still preserve the explicit `41.1` external-proof boundary.
- **D-27:** Avoid vague language like “done except for some follow-up.” Use the repo’s stronger existing vocabulary:
  `closed`, `close-ready`, `pending-external-verification`, and plain-language milestone semantics that match real authority.

### the agent's Discretion

- Exact flagship guide filenames, titles, and section names
- Exact wording of the inline quote proof-boundary callout
- Exact wording and placement of the planning-truth boundary section
- Exact “switch to separate charges and transfers when…” copy, as long as destination charges remain the default
- Whether a current milestone-close artifact beyond the core planning files should be updated, as long as archived truth is not cosmetically rewritten

</decisions>

<specifics>
## Specific Ideas

- The Connect guide should feel like:
  “Start with Express plus destination charges if one payment belongs to one connected account; this is the shortest truthful path from onboarding to money movement.”
- The quote guide should feel like:
  “Accepted quote transitions are real, but downstream billing truth still belongs to follow-up reads and webhooks; here is the exact next operator move without overstating proof.”
- The planning-close posture should feel like:
  “Adoption closure is complete when Phase 46 lands; one prior accepted external-proof follow-through remains explicitly open outside the milestone headline.”
- Strong ecosystem lesson to preserve:
  mature Elixir OSS docs keep a stable reference spine, task-first routing layers, and short inline caveats at the point where omission would create false confidence.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone truth
- `.planning/PROJECT.md` — v1.4 adoption-closure goal, library-scope posture, and current-state truth
- `.planning/REQUIREMENTS.md` — `RECIPE-03`, `RECIPE-04`, and `PLAN-01`
- `.planning/ROADMAP.md` — Phase 46 goal and plan split
- `.planning/STATE.md` — current milestone position and explicit `41.1` concern
- `.planning/threads/v1-4-adoption-closure.md` — milestone rationale, done-enough bar, and flagship-guide expectations
- `.planning/threads/lattice-stripe-vs-accrue-scope-boundary.md` — hard SDK-vs-Accrue scope line

### Prior phase decisions that constrain this phase
- `.planning/phases/17-connect-accounts-links/17-CONTEXT.md` — Express default, onboarding shape, capability truth, and bearer-URL rules
- `.planning/phases/18-connect-money-movement/18-CONTEXT.md` — destination charges, separate charges and transfers, payout/reconciliation rules, and Connect footguns
- `.planning/phases/36-quote/36-CONTEXT.md` — Quote lifecycle, explicit verbs, and SDK-boundary constraints
- `.planning/phases/41-quote-lifecycle-e2e-verification/41-CONTEXT.md` — bounded local Quote proof posture
- `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-CONTEXT.md` — exact downstream-follow-through boundary and target proof shape
- `.planning/phases/42-planning-truth-reconciliation/42-CONTEXT.md` — layered evidence model and explicit `pending-external-verification` semantics
- `.planning/phases/44-guide-discovery-support-truth/44-CONTEXT.md` — task-first routing over canonical docs and inline truth rules
- `.planning/phases/45-flagship-recipes-i/45-CONTEXT.md` — flagship recipe posture inherited by Phase 46
- `.planning/phases/45-flagship-recipes-i/45-RESEARCH.md` — flagship recipe architecture and docs-graph lessons from Phase 45

### Existing guides, code, and tests
- `guides/connect.md` — conceptual Connect landing guide
- `guides/connect-accounts.md` — account lifecycle and webhook-handoff posture
- `guides/connect-money-movement.md` — charge-pattern and payout/reconciliation truth
- `guides/recipes.md` — compact workflow bridge that Phase 46 should deepen without replacing
- `guides/user-flows-and-jtbd.md` — task-first evaluator map and flagship-routing layer
- `lib/lattice_stripe/quote.ex` — Quote lifecycle public API and current SDK-boundary language
- `test/integration/quote_integration_test.exs` — bounded local proof shape after `Quote.accept/3`
- `test/lattice_stripe/docs_truth_test.exs` — docs publication and routing truth assertions

### Prompt corpus to honor
- `prompts/elixir-best-practices-deep-research.md`
- `prompts/elixir-opensource-libs-best-practices-deep-research.md`
- `prompts/phoenix-best-practices-deep-research.md`
- `prompts/stripe-lib-priority-user-flows-deep-research.md`
- `prompts/stripe-sdk-api-surface-area-deep-research.md`
- `prompts/payments_domain_field_guide.md`
- `prompts/stripe-explanation-domain-language-deep-research.md`
- `prompts/The definitive Stripe library gap in Elixir - a master research document.md`

### External ecosystem references
- `https://docs.stripe.com/connect/accounts` — account-type responsibilities and Express default framing
- `https://docs.stripe.com/connect/charges` — charge-pattern comparison and destination-charge default boundaries
- `https://docs.stripe.com/connect/destination-charges` — destination-charge implementation semantics
- `https://docs.stripe.com/webhooks` — raw-body verification and webhook-delivery truth
- `https://docs.stripe.com/quotes` — Quote lifecycle and downstream object outcomes
- `https://docs.stripe.com/api/quotes/accept` — Quote accept contract
- `https://docs.stripe.com/billing/subscriptions/webhooks` — async subscription truth and webhook authority
- `https://docs.stripe.com/checkout/fulfillment` — point-of-use truth precedent: redirect is not fulfillment authority
- `https://hexdocs.pm/plug/Plug.Conn.html#read_body/2` — Plug raw-body handling constraint for webhook examples
- `https://hexdocs.pm/ecto/getting-started.html` — mature Elixir docs pattern: stable reference spine plus local caveats
- `https://hexdocs.pm/oban/Oban.html` — operational caveats at the action point in mature Elixir OSS docs
- `https://laravel.com/docs/12.x/billing` — successful higher-level billing docs posture to learn from without copying the abstraction boundary
- `https://dj-stripe.dev/docs/dev/usage/webhooks` — webhook-first follow-through posture in a successful Stripe-adjacent library
- `https://github.com/stripe/stripe-mock` — limits of local mock proof for downstream lifecycle claims

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `guides/connect.md`, `guides/connect-accounts.md`, and `guides/connect-money-movement.md` already contain the exact primitive surfaces Phase 46 should route through rather than replace.
- `guides/recipes.md` already contains a compact quote recipe entry that can be expanded into a flagship operator guide.
- `lib/lattice_stripe/quote.ex` already encodes the right low-magic Quote lifecycle surface and keeps orchestration out of the SDK.
- `test/integration/quote_integration_test.exs` already captures the bounded local post-accept proof posture that public docs must not overclaim beyond.
- `test/lattice_stripe/docs_truth_test.exs` already gives the repo a strong pattern for locking flagship-guide publication and routing truth.

### Established Patterns
- Public docs are strongest when they recommend one clear path, then deep-link outward.
- Webhooks, not redirects or immediate follow-up polling, are the durable authority for async billing/platform truth.
- The repo already distinguishes active planning truth from archived milestone history; Phase 46 should preserve that separation.
- Support-truth language is strongest when it is short, concrete, and stated at the point where omission would mislead.

### Integration Points
- new flagship guide for Connect platform flow
- new flagship guide for quote-to-billing operator follow-through
- `guides/recipes.md` and `guides/user-flows-and-jtbd.md` for routing into the new guides
- `mix.exs` and `test/lattice_stripe/docs_truth_test.exs` if publication/discovery wiring changes
- `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and `PROJECT.md` for milestone-close truth reconciliation

</code_context>

<deferred>
## Deferred Ideas

- Treating separate charges and transfers as the default Connect flagship path
- Any Connect guide that turns into marketplace ledger design, payout ops software, or account-lifecycle product strategy
- Any quote guide that turns into entitlement logic, dunning, provisioning, or app-owned billing orchestration
- Any attempt to close Phase `41.1` by wording alone without fresh external proof
- Any rewriting of archived v1.3 history to cosmetically flatten the accepted external-proof boundary

</deferred>

---

*Phase: 46-flagship-recipes-ii-planning-truth-closure*
*Context gathered: 2026-05-26*
