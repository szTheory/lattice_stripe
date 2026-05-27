# Phase 46: Flagship Recipes II & Planning Truth Closure - Research

**Researched:** 2026-05-26 [VERIFIED: local command output]  
**Domain:** flagship Connect and Quote operator guides plus milestone-close planning-truth reconciliation for v1.4 adoption closure [VERIFIED: local files `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`]  
**Confidence:** HIGH [VERIFIED: local files + cited official docs]

<user_constraints>
## User Constraints (from CONTEXT.md)

The bullets below are copied verbatim from `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`. [VERIFIED: local file `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`]

### Locked Decisions

#### Cross-phase flagship posture

- **D-01:** Phase 46 inherits the Phase 45 flagship pattern unchanged: guides are **workflow playbooks, not endpoint tours**.
- **D-02:** Each guide should teach **one recommended path first**, then name the narrower cases that should switch to a different pattern without equal-weighting them.
- **D-03:** The durable truth model remains explicit everywhere: **API responses tell you what Stripe accepted now; webhooks or authoritative follow-up reads tell you what became true.**
- **D-04:** The guides must stay **library-scoped and primitive-first**. They may show thin Phoenix/Plug integration examples, but they must not become app-owned workflow products.
- **D-05:** Public docs should keep **critical truth at the action point**. Planning artifacts should carry any stronger audit-style boundary language.

#### Connect flagship spine

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

#### Quote-to-billing flagship posture

- **D-13:** The quote flagship guide should use a **concrete but bounded** operator path:
  `Quote.create -> Quote.finalize -> Quote.accept -> inspect returned downstream ref -> retrieve at most one linked downstream resource -> hand off to webhook/authoritative follow-up truth`.
- **D-14:** The guide should describe the downstream-reference inspection order explicitly:
  `invoice`, then `subscription`, then `subscription_schedule`.
- **D-15:** The guide must state clearly that `Quote.accept/3` proves **Stripe accepted the quote transition**, not that payment, provisioning, activation, or customer-visible billing state is fully settled.
- **D-16:** The guide should keep one concrete downstream operator step because serious evaluators need an actionable next move, not just a caveat memo.
- **D-17:** The guide must not imply that quote acceptance deterministically yields the same downstream object every time. The result depends on quote shape and timing.
- **D-18:** The guide must stop before entitlement logic, dunning policy, local billing-engine coordination, or operator UI decisions. Those belong in application code or Accrue.

#### Phase 41.1 proof-boundary disclosure

- **D-19:** Use a **bounded dual-placement** disclosure posture:
  one short inline truth callout in the public quote/operator guide,
  plus one explicit named proof-boundary section in planning/milestone-close artifacts.
- **D-20:** Public docs should explain the issue as a **proof boundary**, not as planning-history narration. Avoid naming `41.1` repeatedly in user-facing copy unless the internal phase reference is specifically useful.
- **D-21:** Planning artifacts must preserve `pending-external-verification` as a first-class truthful state for the accepted downstream Quote follow-through gap.
- **D-22:** Avoid caveat spam. The gap is real but narrow; repeating it everywhere would overstate its product significance.

#### Planning-truth closure posture

- **D-23:** The governing planning-close posture is:
  **v1.4 becomes close-ready when Phase 46 lands, while Phase `41.1` remains a separate accepted v1.3 follow-through item in `pending-external-verification`.**
- **D-24:** Phase 46 should reconcile the active planning truth and current-state trust anchors, not just the minimum active files:
  `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and `PROJECT.md`.
- **D-25:** Broader milestone-close wording may also update the current audit/close posture if needed, but must do so **without rewriting archived v1.3 history to pretend the prior boundary changed**.
- **D-26:** `PLAN-01` should be considered satisfied only when milestone artifacts are coherent **and** still preserve the explicit `41.1` external-proof boundary.
- **D-27:** Avoid vague language like “done except for some follow-up.” Use the repo’s stronger existing vocabulary:
  `closed`, `close-ready`, `pending-external-verification`, and plain-language milestone semantics that match real authority.

### Claude's Discretion

- Exact flagship guide filenames, titles, and section names
- Exact wording of the inline quote proof-boundary callout
- Exact wording and placement of the planning-truth boundary section
- Exact “switch to separate charges and transfers when…” copy, as long as destination charges remain the default
- Whether a current milestone-close artifact beyond the core planning files should be updated, as long as archived truth is not cosmetically rewritten

### Deferred Ideas (OUT OF SCOPE)

- Treating separate charges and transfers as the default Connect flagship path
- Any Connect guide that turns into marketplace ledger design, payout ops software, or account-lifecycle product strategy
- Any quote guide that turns into entitlement logic, dunning, provisioning, or app-owned billing orchestration
- Any attempt to close Phase `41.1` by wording alone without fresh external proof
- Any rewriting of archived v1.3 history to cosmetically flatten the accepted external-proof boundary
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RECIPE-03 | A developer can follow a flagship recipe for a Connect platform flow using shipped LatticeStripe primitives. | The shipped docs and code already expose the needed primitives and semantics: `guides/connect.md`, `guides/connect-accounts.md`, and `guides/connect-money-movement.md` already cover Express onboarding, AccountLinks, LoginLinks, destination charges, transfers, payouts, and webhook handoff; Stripe’s current Connect docs still position Express as the low-effort default and describe destination charges as the marketplace path when the platform charges and immediately transfers funds to one connected account. [VERIFIED: local files `guides/connect.md`, `guides/connect-accounts.md`, `guides/connect-money-movement.md`] [CITED: https://docs.stripe.com/connect/accounts?locale=en-GB] [CITED: https://docs.stripe.com/connect/charges?locale=en-GB] [CITED: https://docs.stripe.com/connect/destination-charges?locale=en-GB&platform=web&ui=elements] |
| RECIPE-04 | Quote-to-billing operator guidance explains the shipped flow honestly and preserves the explicit Phase `41.1` external-proof boundary. | The shipped Quote surface and current proof artifacts already define the narrow truthful path: `LatticeStripe.Quote` stops at the Stripe resource boundary, the integration test retrieves at most one downstream reference in `invoice -> subscription -> subscription_schedule` order, and the Phase `41.1` verifier remains explicitly `pending-external-verification` because the external sandbox proof failed at the credential gate. Stripe’s current Quote docs still say accepted quotes generate an invoice, subscription, or subscription schedule and emit `quote.accepted`, but they do not turn that into payment or provisioning proof. [VERIFIED: local files `lib/lattice_stripe/quote.ex`, `test/integration/quote_integration_test.exs`, `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md`] [CITED: https://docs.stripe.com/quotes] [CITED: https://docs.stripe.com/api/quotes/accept] [CITED: https://docs.stripe.com/billing/subscriptions/webhooks] |
| PLAN-01 | Roadmap, requirements, and state artifacts reflect v1.4 as an adoption-closure milestone and preserve the accepted Phase `41.1` follow-through truthfully. | The phase context locks the governing close posture, and the current planning files already show where reconciliation is needed: `PROJECT.md`, `ROADMAP.md`, and `STATE.md` describe v1.4 adoption closure, while `ROADMAP.md` still ends with the stale next-step pointer `Run $gsd-plan-phase 44` and `STATE.md` still says the current focus is Phase 45 verification. Phase 42 established the repo’s accepted truth model: verifier-backed closure with `pending-external-verification` preserved verbatim for environment-bound follow-through. [VERIFIED: local files `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`, `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, `.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md`] |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- The repo targets Elixir `~> 1.15` and the current local toolchain is Elixir 1.19.5 / Mix 1.19.5 on OTP 28, so any validation guidance should stay compatible with that baseline. [VERIFIED: local files `CLAUDE.md`, `mix.exs`] [VERIFIED: local command `mix --version`]  
- Dialyzer remains out of scope for this project, so validation should stay on ExUnit, docs-truth checks, and grep-backed artifact assertions. [VERIFIED: local file `CLAUDE.md`]  
- Dependencies should remain minimal; this phase has no evidence-based need for new runtime or dev dependencies beyond the existing Mix/ExUnit/ExDoc toolchain. [VERIFIED: local file `CLAUDE.md`] [VERIFIED: local files `mix.exs`, `test/lattice_stripe/docs_truth_test.exs`]  
- Planning artifacts are first-class deliverables in this repo’s workflow, so the plan should treat `PROJECT.md`, `ROADMAP.md`, `REQUIREMENTS.md`, and `STATE.md` updates as scoped execution work rather than post-hoc bookkeeping. [VERIFIED: local file `CLAUDE.md`] [VERIFIED: local files `.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md`, `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`]  
- No `AGENTS.md` exists at the repo root in this workspace, so `CLAUDE.md` is the active project instruction file. [VERIFIED: local command output]

## Summary

Phase 46 should be planned as two tightly-coupled workstreams: publish two new flagship guide surfaces and then reconcile milestone-close truth against the repo’s accepted verifier-first status model. The guide work is not greenfield. Phase 45 already established the flagship recipe publication pattern in `mix.exs`, `guides/recipes.md`, `guides/user-flows-and-jtbd.md`, and `test/lattice_stripe/docs_truth_test.exs`, so Phase 46 should extend that exact architecture rather than inventing a new docs shape. [VERIFIED: local files `mix.exs`, `guides/checkout-signup-and-portal.md`, `guides/metering-runtime-and-reconciliation.md`, `guides/recipes.md`, `guides/user-flows-and-jtbd.md`, `test/lattice_stripe/docs_truth_test.exs`, `.planning/phases/45-flagship-recipes-i/45-RESEARCH.md`]

For the Connect guide, the strongest default story is already visible in both repo truth and Stripe’s current docs: Express onboarding is the low-friction account type, destination charges are the clean default when one payment belongs to one connected account, and the durable truth still lives in webhooks rather than in redirect handlers or polling. The flagship guide should therefore stitch together `Account.create/3`, `AccountLink.create/3`, `LoginLink.create/3`, destination-charge `PaymentIntent.create/3`, and payout/reconciliation callouts into one asserted path, then route narrower split-funds or delayed-assignment cases to separate charges and transfers without equal-weighting them. [VERIFIED: local files `guides/connect.md`, `guides/connect-accounts.md`, `guides/connect-money-movement.md`, `.planning/phases/17-connect-accounts-links/17-CONTEXT.md`, `.planning/phases/18-connect-money-movement/18-CONTEXT.md`] [CITED: https://docs.stripe.com/connect/accounts?locale=en-GB] [CITED: https://docs.stripe.com/connect/charges?locale=en-GB] [CITED: https://docs.stripe.com/connect/destination-charges?locale=en-GB&platform=web&ui=elements] [CITED: https://docs.stripe.com/webhooks?locale=en-GB]

For the quote guide and planning-truth closure, the repo already has the right authority boundary: `Quote.accept/3` proves Stripe accepted the transition and may expose one downstream reference, but Phase `41.1` remains `pending-external-verification` because no valid sandbox credential has yet proved that reference in a real external environment. Public docs should express that as a narrow proof boundary at the action point, while planning artifacts should preserve the stronger named `pending-external-verification` state. The plan should also budget for current planning drift that is already visible in repo truth, including the stale roadmap next-step pointer and the stale current-focus wording in `STATE.md`. [VERIFIED: local files `lib/lattice_stripe/quote.ex`, `test/integration/quote_integration_test.exs`, `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, `.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md`] [CITED: https://docs.stripe.com/quotes] [CITED: https://docs.stripe.com/api/quotes/accept] [CITED: https://docs.stripe.com/billing/subscriptions/webhooks]

**Primary recommendation:** add two new flagship guides into the existing `Flagship Recipes` publication lane, extend `docs_truth_test.exs` to lock their publication and truth rails, and treat planning-truth reconciliation as a separate second pass that updates `PROJECT.md`, `ROADMAP.md`, `REQUIREMENTS.md`, and `STATE.md` while keeping Phase `41.1` explicitly `pending-external-verification`. [VERIFIED: local files `mix.exs`, `test/lattice_stripe/docs_truth_test.exs`, `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Publish Connect flagship guide and route it through the docs graph | Repository / Public Docs [VERIFIED: local files `mix.exs`, `guides/recipes.md`, `guides/user-flows-and-jtbd.md`] | API / Backend semantics [VERIFIED: local guide files] | The deliverable is a docs surface, but the truth it teaches is mostly backend-owned: account creation, hosted redirects, destination-charge creation, and webhook-driven state. [VERIFIED: local files `guides/connect-accounts.md`, `guides/connect-money-movement.md`] |
| Publish quote-to-billing operator guide with bounded proof language | Repository / Public Docs [VERIFIED: local files `guides/recipes.md`, `test/lattice_stripe/docs_truth_test.exs`] | API / Backend semantics [VERIFIED: local files `lib/lattice_stripe/quote.ex`, `test/integration/quote_integration_test.exs`] | The guide is public documentation, but it must stay anchored to the existing Quote lifecycle API and external-proof boundary rather than inventing app workflow ownership. [VERIFIED: local files `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md`, `.planning/threads/lattice-stripe-vs-accrue-scope-boundary.md`] |
| Preserve v1.4 close-ready truth while Phase `41.1` stays open | Repository / Planning Artifacts [VERIFIED: local files `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, `.planning/REQUIREMENTS.md`] | Verifier Artifacts [VERIFIED: local files `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md`, `.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md`] | Milestone semantics are documentary outputs that must be downstream of existing verifier truth, not parallel to it. [VERIFIED: local files `.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md`, `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`] |
| Enforce flagship publication and routing truth | Test Evidence [VERIFIED: local file `test/lattice_stripe/docs_truth_test.exs`] | Repository / Public Docs [VERIFIED: local files `mix.exs`, guide files] | The repo already uses `docs_truth_test.exs` as the regression net for guide publication, cross-links, and truth callouts. [VERIFIED: local file `test/lattice_stripe/docs_truth_test.exs`] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ExDoc extras + `groups_for_extras` in `mix.exs` | repo-local current [VERIFIED: local file `mix.exs`] | publish flagship guides in the existing `Flagship Recipes` lane and keep docs discovery layered [VERIFIED: local file `mix.exs`] | Phase 45 already established the public-doc shape the repo now tests and ships. [VERIFIED: local files `mix.exs`, `test/lattice_stripe/docs_truth_test.exs`] |
| `test/lattice_stripe/docs_truth_test.exs` | repo-local current [VERIFIED: local file `test/lattice_stripe/docs_truth_test.exs`] | lock guide publication, cross-links, and inline truth rails [VERIFIED: local file `test/lattice_stripe/docs_truth_test.exs`] | It already asserts the flagship-recipe pattern and is the least-surprise place to extend for Phase 46. [VERIFIED: local file `test/lattice_stripe/docs_truth_test.exs`] |
| Existing canonical Connect guides | repo-local current [VERIFIED: local files `guides/connect.md`, `guides/connect-accounts.md`, `guides/connect-money-movement.md`] | deeper reference truth for account lifecycle, charge patterns, and payouts [VERIFIED: local guide files] | The flagship guide should route into these instead of duplicating their reference detail. [VERIFIED: local files `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`, `guides/connect.md`] |
| Existing Quote API + proof artifacts | repo-local current [VERIFIED: local files `lib/lattice_stripe/quote.ex`, `test/integration/quote_integration_test.exs`, `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md`] | bounded operator path and proof-boundary anchor for the quote flagship guide [VERIFIED: local files] | The guide should teach the shipped boundary, not speculate beyond it. [VERIFIED: local files `lib/lattice_stripe/quote.ex`, `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md`] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Official Stripe docs | current pages opened 2026-05-26 [CITED: https://docs.stripe.com/connect/accounts?locale=en-GB] | verify current Connect, Quote, and webhook semantics against repo guidance [CITED: official Stripe docs listed in Sources] | Use for current behavioral claims that could drift from training or from older repo assumptions. [CITED: official Stripe docs listed in Sources] |
| `guides/recipes.md` + `guides/user-flows-and-jtbd.md` | repo-local current [VERIFIED: local files `guides/recipes.md`, `guides/user-flows-and-jtbd.md`] | route evaluators into the new flagship guides [VERIFIED: local guide files] | Update whenever a flagship guide is added so the task-first graph stays coherent. [VERIFIED: local file `test/lattice_stripe/docs_truth_test.exs`] |
| Planning truth anchors | repo-local current [VERIFIED: local files `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`] | carry the v1.4 close-ready story and preserve the Phase `41.1` boundary [VERIFIED: local planning files] | Update in the second pass after public guide truth is settled. [VERIFIED: local files `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`, `.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md`] |
| `rg` | 15.1.0 [VERIFIED: local command `rg --version`] | fast deterministic assertions over planning and docs artifacts [VERIFIED: local command output] | Use for plan verification gates around route wiring and planning vocabulary. [VERIFIED: local files `.planning/phases/42-planning-truth-reconciliation/42-02-PLAN.md`, `.planning/phases/42-planning-truth-reconciliation/42-VALIDATION.md`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Express onboarding plus destination charges as the flagship Connect default [VERIFIED: local phase context] | direct charges or separate charges and transfers as a co-equal opening story [VERIFIED: local guide files] | Stripe and repo truth both support those paths, but they fit different jobs; leading with them would either undersell platform control needs or overcomplicate the default one-seller flow. [VERIFIED: local files `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`, `guides/connect.md`] [CITED: https://docs.stripe.com/connect/charges?locale=en-GB] |
| One inline quote proof-boundary callout plus stronger planning-artifact wording [VERIFIED: local phase context] | repeated public caveats or planning-history narration in user-facing docs [VERIFIED: local phase context] | Repetition would overstate a narrow gap and violate the locked bounded dual-placement posture. [VERIFIED: local file `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`] |
| Reuse `docs_truth_test.exs` for flagship-publication regression [VERIFIED: local file `test/lattice_stripe/docs_truth_test.exs`] | create a separate bespoke docs harness for Phase 46 [ASSUMED] | A new harness could isolate concerns, but the repo already centralizes public-doc truth assertions in one file and there is no evidence that fragmentation helps here. [VERIFIED: local file `test/lattice_stripe/docs_truth_test.exs`] |
| Preserve `pending-external-verification` verbatim for Phase `41.1` [VERIFIED: local files `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md`, `.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md`] | mark the follow-through “closed enough” once v1.4 is close-ready [VERIFIED: local phase context] | Shorter wording would make the milestone headline neater, but it would contradict the repo’s accepted truth model and the actual failed sandbox proof. [VERIFIED: local files `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md`, `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`] |

**Installation:**
```bash
# No new packages or dependencies are recommended for this phase.
```

**Version verification:** This phase relies on the existing Elixir/Mix docs toolchain rather than new libraries; the current local runtime was verified as OTP 28 / Mix 1.19.5 and `ripgrep 15.1.0` on 2026-05-26. [VERIFIED: local commands `mix --version`, `rg --version`]

## Architecture Patterns

### System Architecture Diagram

```text
Top-level evaluator entry points
README / Getting Started / JTBD / Recipes
          |
          v
Flagship guide 1: Connect platform flow
          |
          +--> Connect Accounts (Express onboarding, AccountLink/LoginLink)
          |
          +--> Connect Money Movement (destination charge, transfer vs payout)
          |
          +--> Webhooks / Error Handling
          |
          v
Thin Phoenix action examples + webhook-owned durable truth

Top-level evaluator entry points
README / Getting Started / JTBD / Recipes
          |
          v
Flagship guide 2: Quote-to-billing operator flow
          |
          +--> Quote.create -> finalize -> accept
          |
          +--> inspect invoice | subscription | subscription_schedule
          |
          +--> retrieve at most one linked resource
          |
          +--> hand off to webhook / authoritative follow-up truth
          |
          v
Inline proof-boundary callout (public docs)

Verifier / planning truth inputs
41.1-VERIFICATION.md + PROJECT/ROADMAP/REQUIREMENTS/STATE
          |
          v
Phase 46 planning-truth reconciliation pass
          |
          v
v1.4 close-ready language preserved alongside explicit 41.1 pending-external-verification
```

The public-doc lane and planning-truth lane share one governing rule: recommend one concrete path, but keep the durable truth at the point where a reader would otherwise over-assume. [VERIFIED: local files `.planning/phases/45-flagship-recipes-i/45-RESEARCH.md`, `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`, `guides/checkout-signup-and-portal.md`, `guides/metering-runtime-and-reconciliation.md`]

### Recommended Project Structure

```text
guides/
├── connect-platform-flow.md              # new flagship Connect guide [ASSUMED]
├── quote-to-billing-operator.md          # new flagship Quote guide [ASSUMED]
├── recipes.md                            # route into both new guides [VERIFIED: local file]
└── user-flows-and-jtbd.md                # route into both new guides [VERIFIED: local file]

mix.exs                                   # publish both guides in "Flagship Recipes" [VERIFIED: local file]
test/lattice_stripe/docs_truth_test.exs   # assert publication, routing, and truth anchors [VERIFIED: local file]

.planning/
├── PROJECT.md                            # close-ready milestone posture [VERIFIED: local file]
├── ROADMAP.md                            # phase/next-step truth [VERIFIED: local file]
├── REQUIREMENTS.md                       # RECIPE-03/04 and PLAN-01 closure rows [VERIFIED: local file]
└── STATE.md                              # current position / blocker truth [VERIFIED: local file]
```

### Pattern 1: Flagship Guide as Routing Layer, Not Replacement

**What:** Publish a workflow playbook that recommends one path first, then routes outward to canonical guides for deeper API truth. [VERIFIED: local files `.planning/phases/45-flagship-recipes-i/45-RESEARCH.md`, `guides/checkout-signup-and-portal.md`, `guides/metering-runtime-and-reconciliation.md`]  
**When to use:** Every flagship guide in v1.4. [VERIFIED: local files `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`, `mix.exs`]  
**Example:**
```markdown
<!-- Source: guides/checkout-signup-and-portal.md -->
This is a workflow playbook, not a second API reference.
...
## Read next
- [Checkout](checkout.md)
- [Subscriptions](subscriptions.md)
- [Customer Portal](customer-portal.md)
```

### Pattern 2: Thin Web Layer, Webhook-Owned Durable Truth

**What:** Keep browser/controller actions responsible for creating hosted URLs or request objects, then hand durable state ownership to webhook handlers. [VERIFIED: local files `guides/connect-accounts.md`, `guides/checkout-signup-and-portal.md`]  
**When to use:** Hosted Connect onboarding, destination-charge creation, and quote/operator flows that have async downstream truth. [VERIFIED: local phase context + local guide files]  
**Example:**
```elixir
// Source: guides/connect-accounts.md
{:ok, link} = LatticeStripe.AccountLink.create(client, %{
  "account" => account.id,
  "type" => "account_onboarding",
  "refresh_url" => "...",
  "return_url" => "..."
})

redirect_user_to(link.url)
```

### Pattern 3: Bounded Downstream Inspection for Quotes

**What:** After `Quote.accept/3`, inspect the returned reference in `invoice -> subscription -> subscription_schedule` order, retrieve at most one linked resource, and stop before broader billing orchestration claims. [VERIFIED: local files `test/integration/quote_integration_test.exs`, `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-CONTEXT.md`]  
**When to use:** Public operator guidance and planning-truth wording around quote follow-through. [VERIFIED: local file `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`]  
**Example:**
```elixir
// Source: test/integration/quote_integration_test.exs
cond do
  is_binary(quote.invoice) -> {:invoice, quote.invoice}
  is_binary(quote.subscription) -> {:subscription, quote.subscription}
  is_binary(quote.subscription_schedule) -> {:subscription_schedule, quote.subscription_schedule}
  true -> :none
end
```

### Pattern 4: Verifier-Backed Planning Closure

**What:** Update milestone-close wording only after checking the authoritative verifier artifact and current planning-surface drift. [VERIFIED: local files `.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md`, `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`]  
**When to use:** `PLAN-01` reconciliation across `PROJECT.md`, `ROADMAP.md`, `REQUIREMENTS.md`, and `STATE.md`. [VERIFIED: local file `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`]  
**Example:**
```markdown
<!-- Source: .planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md -->
status: pending-external-verification
...
No further code gap exists inside this phase's current implementation scope.
The remaining gap is environment truth, not SDK surface implementation.
```

### Anti-Patterns to Avoid

- **Equal-weighting separate charges and transfers with destination charges:** This contradicts the locked default posture and front-loads orchestration complexity into the flagship path. [VERIFIED: local file `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`] [CITED: https://docs.stripe.com/connect/charges?locale=en-GB]
- **Treating redirect handlers or polling as the authority path:** Stripe’s current docs still require webhook-backed confirmation for reliable fulfillment, and the repo already mirrors that rule in shipped guides. [VERIFIED: local files `guides/connect-accounts.md`, `guides/checkout-signup-and-portal.md`] [CITED: https://docs.stripe.com/checkout/fulfillment] [CITED: https://docs.stripe.com/webhooks?locale=en-GB]
- **Implying `Quote.accept/3` proves downstream billing completion:** Current Stripe docs and repo proof only support accepted transition plus a bounded downstream reference story. [VERIFIED: local files `lib/lattice_stripe/quote.ex`, `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md`] [CITED: https://docs.stripe.com/api/quotes/accept]
- **Closing Phase `41.1` by milestone wording alone:** The external probe is still failed due expired credentials, so changing language without new proof would rewrite truth. [VERIFIED: local file `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md`] 
- **Adding guides without publication/test wiring:** The repo’s docs graph is deliberately asserted in `mix.exs` and `docs_truth_test.exs`, so unpublished or unlinked guides would regress the phase’s purpose. [VERIFIED: local files `mix.exs`, `test/lattice_stripe/docs_truth_test.exs`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Connect flagship default [VERIFIED: local phase context] | a custom “platform billing engine” narrative or multi-party ledger abstraction [VERIFIED: local scope thread] | Express onboarding + destination-charge + payout/reconciliation routing through existing canonical guides [VERIFIED: local guide files] | The repo owns Stripe primitives and guidance, not Accrue-style orchestration. [VERIFIED: local file `.planning/threads/lattice-stripe-vs-accrue-scope-boundary.md`] |
| Webhook raw-body handling guidance [VERIFIED: local phase context] | ad hoc signature-verification body handling examples [VERIFIED: local guide files] | the existing raw-body / `Plug.Conn.read_body/2` posture already used by the repo’s webhook guidance [VERIFIED: local file `guides/webhooks.md`] [CITED: https://docs.stripe.com/webhooks?locale=en-GB] [CITED: https://hexdocs.pm/plug/Plug.Conn.html] | Raw-body integrity is easy to get subtly wrong and should not be re-invented in flagship docs. [CITED: https://docs.stripe.com/webhooks?locale=en-GB] |
| Quote follow-through certainty [VERIFIED: local proof artifacts] | a deterministic “quote always becomes invoice X” helper narrative [VERIFIED: local phase context] | bounded downstream inspection order plus webhook/authoritative follow-up truth [VERIFIED: local files `test/integration/quote_integration_test.exs`, `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-CONTEXT.md`] | Stripe’s current docs and local proof both show multiple downstream outcomes, so deterministic storytelling would be false precision. [CITED: https://docs.stripe.com/quotes] [CITED: https://docs.stripe.com/api/quotes/accept] |
| Planning status vocabulary [VERIFIED: local phase context] | fresh milestone-close wording such as “mostly done” or “done except follow-up” [VERIFIED: local phase context] | the repo’s existing truth vocabulary: `closed`, `close-ready`, `pending-external-verification` [VERIFIED: local files `.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md`, `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`] | Existing vocabulary is already tied to verifier semantics and avoids ambiguity for later planning passes. [VERIFIED: local files `.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md`, `.planning/STATE.md`] |

**Key insight:** The hard work in this phase is not new API teaching. It is choosing one safe path, preserving the repo’s authority boundaries, and wiring every new public or planning statement into the docs/test/verifier graph that already exists. [VERIFIED: local files `mix.exs`, `test/lattice_stripe/docs_truth_test.exs`, `.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md`, `.planning/phases/45-flagship-recipes-i/45-RESEARCH.md`]

## Common Pitfalls

### Pitfall 1: Making Separate Charges and Transfers Look Like the Default
**What goes wrong:** The Connect guide starts with the most flexible pattern instead of the shortest truthful one. [VERIFIED: local phase context]  
**Why it happens:** Connect has three charge patterns, and it is tempting to present them symmetrically. [VERIFIED: local file `guides/connect.md`] [CITED: https://docs.stripe.com/connect/charges?locale=en-GB]  
**How to avoid:** Lead with Express + destination charges for one-payment/one-connected-account flows, then add a short “switch patterns when...” section for split or delayed-assignment cases. [VERIFIED: local file `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`]  
**Warning signs:** The draft guide spends as much space on `Transfer.create/3` fan-out as on destination charges, or uses separate charges and transfers in the first example. [VERIFIED: local files `guides/connect-money-movement.md`, `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`]

### Pitfall 2: Hiding Durable Truth Behind Redirect Success
**What goes wrong:** Docs imply that `return_url`, success pages, or immediate polling are sufficient to trust onboarding, payment, or quote follow-through state. [VERIFIED: local files `guides/connect-accounts.md`, `guides/checkout-signup-and-portal.md`]  
**Why it happens:** Redirect-heavy flows feel complete in the browser even when Stripe’s state transitions continue asynchronously. [CITED: https://docs.stripe.com/checkout/fulfillment] [CITED: https://docs.stripe.com/webhooks?locale=en-GB]  
**How to avoid:** Keep webhook ownership explicit at each action point and treat return pages as UX or control handoff, not authority. [VERIFIED: local phase context + local guide files]  
**Warning signs:** Phrases like “after the user returns, mark the account onboarded” or “after accept, billing is active” appear without webhook or follow-up-read language. [VERIFIED: local phase context]

### Pitfall 3: Overclaiming Quote Acceptance Semantics
**What goes wrong:** The quote guide collapses accepted transition, downstream object creation, payment, and provisioning into one story. [VERIFIED: local phase context]  
**Why it happens:** Stripe’s Quote flow can create several downstream object types, and the temptation is to summarize all of them as settled billing truth. [CITED: https://docs.stripe.com/quotes] [CITED: https://docs.stripe.com/api/quotes/accept]  
**How to avoid:** Keep the guide to the narrow operator spine: accept, inspect the first available downstream reference in the locked order, retrieve one linked object, then hand off to webhooks or authoritative follow-up reads. [VERIFIED: local files `test/integration/quote_integration_test.exs`, `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-CONTEXT.md`]  
**Warning signs:** The guide says or implies that an accepted quote always creates the same downstream object, or that that object is already safe to use as payment/provisioning truth. [VERIFIED: local phase context]

### Pitfall 4: Flattening the `41.1` Boundary During Milestone Close
**What goes wrong:** Planning files mark v1.4 closed in a way that silently erases the accepted external-proof follow-through gap from v1.3 history. [VERIFIED: local files `.planning/PROJECT.md`, `.planning/STATE.md`, `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md`]  
**Why it happens:** Milestone-close editing often optimizes for neat summaries instead of authority-preserving wording. [VERIFIED: local file `.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md`]  
**How to avoid:** Use the locked close-ready posture verbatim and preserve `pending-external-verification` exactly where `41.1` appears. [VERIFIED: local file `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`]  
**Warning signs:** New copy uses phrases like “fully proved,” “all follow-through closed,” or “done except some follow-up” without naming the explicit `41.1` state. [VERIFIED: local phase context]

### Pitfall 5: Forgetting the Docs Graph and Test Graph
**What goes wrong:** New guide files land, but `mix.exs`, `recipes.md`, `user-flows-and-jtbd.md`, or `docs_truth_test.exs` do not change with them. [VERIFIED: local files `mix.exs`, `guides/recipes.md`, `guides/user-flows-and-jtbd.md`, `test/lattice_stripe/docs_truth_test.exs`]  
**Why it happens:** The guide body feels like the main deliverable, so publication and routing steps look secondary. [VERIFIED: local files `.planning/phases/45-flagship-recipes-i/45-RESEARCH.md`, `test/lattice_stripe/docs_truth_test.exs`]  
**How to avoid:** Plan guide publication, entry-point routing, and docs-truth assertions as part of the same slice, not as cleanup. [VERIFIED: local files `mix.exs`, `test/lattice_stripe/docs_truth_test.exs`]  
**Warning signs:** A guide exists on disk but is absent from `docs[:extras]`, from the `Flagship Recipes` group, or from the recipes/JTBD routing layers. [VERIFIED: local file `mix.exs`]

## Code Examples

Verified patterns from shipped repo truth and official docs:

### Express Onboarding Then Immediate Redirect
```elixir
// Source: guides/connect-accounts.md
{:ok, link} = LatticeStripe.AccountLink.create(client, %{
  "account" => account.id,
  "type" => "account_onboarding",
  "refresh_url" => "https://example.test/connect/refresh",
  "return_url" => "https://example.test/connect/return"
})

redirect_user_to(link.url)
```
[VERIFIED: local file `guides/connect-accounts.md`]

### Destination Charge Default Path
```elixir
// Source: guides/connect.md
{:ok, pi} =
  LatticeStripe.PaymentIntent.create(client, %{
    "amount" => 5000,
    "currency" => "usd",
    "application_fee_amount" => 500,
    "transfer_data" => %{"destination" => "acct_connected"},
    "on_behalf_of" => "acct_connected"
  })
```
[VERIFIED: local file `guides/connect.md`] [CITED: https://docs.stripe.com/connect/destination-charges?locale=en-GB&platform=web&ui=elements]

### Quote Accept with Bounded Downstream Inspection
```elixir
// Source: test/integration/quote_integration_test.exs
{:ok, open_quote} = LatticeStripe.Quote.finalize(client, quote.id, %{})
{:ok, accepted_quote} = LatticeStripe.Quote.accept(client, open_quote.id)

case accepted_quote do
  %{invoice: invoice_id} when is_binary(invoice_id) ->
    LatticeStripe.Invoice.retrieve(client, invoice_id)

  %{subscription: subscription_id} when is_binary(subscription_id) ->
    LatticeStripe.Subscription.retrieve(client, subscription_id)

  %{subscription_schedule: schedule_id} when is_binary(schedule_id) ->
    LatticeStripe.SubscriptionSchedule.retrieve(client, schedule_id)
end
```
[VERIFIED: local file `test/integration/quote_integration_test.exs`] [CITED: https://docs.stripe.com/api/quotes/accept]

### Webhooks Must Return Quickly
```text
// Source: https://docs.stripe.com/webhooks?locale=en-GB
Return a 2xx response before slow business logic.
```
[CITED: https://docs.stripe.com/webhooks?locale=en-GB]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Canonical reference guides only, with compact recipes as side notes [VERIFIED: local repo history via current guide graph] | flagship workflow playbooks layered over canonical guides and grouped explicitly in ExDoc [VERIFIED: local files `mix.exs`, `guides/checkout-signup-and-portal.md`, `guides/metering-runtime-and-reconciliation.md`] | Changed in Phase 45 on 2026-05-26. [VERIFIED: local files `.planning/phases/45-flagship-recipes-i/45-RESEARCH.md`, `.planning/STATE.md`] | Phase 46 should extend the same public-doc architecture instead of inventing a second routing model. [VERIFIED: local files `mix.exs`, `test/lattice_stripe/docs_truth_test.exs`] |
| Connect guides that present all charge patterns conceptually [VERIFIED: local file `guides/connect.md`] | one asserted default path first, then bounded switch criteria [VERIFIED: local file `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`] | Current locked posture for Phase 46 as of 2026-05-26. [VERIFIED: local phase context] | The new flagship Connect guide should optimize for evaluator clarity, not theoretical completeness. [VERIFIED: local phase context] |
| “Quote accepted” summarized as general follow-through success [VERIFIED: older compact recipe wording in `guides/recipes.md`] | bounded proof language: accepted transition, maybe one downstream ref, then webhook/follow-up truth [VERIFIED: local files `guides/recipes.md`, `test/integration/quote_integration_test.exs`, `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md`] | Strengthened through Phases 41, 41.1, 42, and now locked again in Phase 46. [VERIFIED: local planning files] | The new quote guide can be concrete without overclaiming what the repo has not externally proved. [VERIFIED: local phase context] |
| Milestone closure as a binary headline [ASSUMED] | close-ready milestone posture plus explicit `pending-external-verification` for environment-bound follow-through [VERIFIED: local files `.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md`, `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`] | Established by Phase 42 on 2026-05-25 and reused in Phase 46. [VERIFIED: local files `.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md`, `.planning/MILESTONES.md`] | `PLAN-01` should reconcile wording without erasing prior accepted history. [VERIFIED: local phase context] |

**Deprecated/outdated:**

- Treating direct charges or separate charges and transfers as the first thing every Connect evaluator should learn is outdated for this phase’s flagship purpose. [VERIFIED: local phase context] [CITED: https://docs.stripe.com/connect/accounts?locale=en-GB] [CITED: https://docs.stripe.com/connect/charges?locale=en-GB]
- Treating redirect pages or immediate polling as fulfillment authority is explicitly rejected by current Stripe docs and by the repo’s shipped flagship recipe pattern. [VERIFIED: local file `guides/checkout-signup-and-portal.md`] [CITED: https://docs.stripe.com/checkout/fulfillment]
- Treating `41.1` as closed by summary wording alone is outdated relative to the current verifier artifact. [VERIFIED: local file `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md`]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `connect-platform-flow.md` and `quote-to-billing-operator.md` are good filename candidates for the new guides. | Recommended Project Structure | Low; planner can choose different names as long as publication and routing are updated consistently. |
| A2 | Reusing `docs_truth_test.exs` is preferable to introducing a new docs-only test file for Phase 46. | Alternatives Considered / Validation Architecture | Low; a separate test file would be acceptable if the team wants finer separation. |
| A3 | Earlier milestone-closure posture was more binary before the Phase 42 truth-model refinement. | State of the Art | Low; the recommendation does not depend on the historical label being exact, only on current verified posture. |

## Open Questions

1. **What should the two new flagship guide filenames be?**
   What we know: the repo already uses descriptive dashed filenames for flagship guides and groups them explicitly under `Flagship Recipes`. [VERIFIED: local files `mix.exs`, `guides/checkout-signup-and-portal.md`, `guides/metering-runtime-and-reconciliation.md`]
   What's unclear: whether the Connect and Quote guides should optimize for task phrasing, operator phrasing, or compact nouns in the filename. [VERIFIED: local phase context]
   Recommendation: keep the naming pattern task-first and long-form enough to be self-explanatory in ExDoc navigation. [VERIFIED: local files `mix.exs`, `guides/checkout-signup-and-portal.md`]

2. **Should Phase 46 update a broader milestone-close artifact beyond the core four planning files?**
   What we know: the phase context allows a broader milestone-close wording update if needed, and `MILESTONES.md` still acts as a high-level trust anchor for archived v1.3 accomplishment wording. [VERIFIED: local files `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`, `.planning/MILESTONES.md`]
   What's unclear: whether the current milestone-close posture is sufficiently represented after updating only `PROJECT.md`, `ROADMAP.md`, `REQUIREMENTS.md`, and `STATE.md`. [VERIFIED: local files `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`]
   Recommendation: inspect `MILESTONES.md` and `.planning/v1.3-v1.3-MILESTONE-AUDIT.md` during planning, but only schedule edits if the close-ready wording would otherwise conflict with the core files. [VERIFIED: local files `.planning/MILESTONES.md`, `.planning/v1.3-v1.3-MILESTONE-AUDIT.md`, `.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md`]

3. **How much automated coverage should `PLAN-01` have?**
   What we know: the repo already uses grep-backed planning artifact assertions in Phase 42 validation and uses `docs_truth_test.exs` for public-doc truth. [VERIFIED: local files `.planning/phases/42-planning-truth-reconciliation/42-VALIDATION.md`, `test/lattice_stripe/docs_truth_test.exs`]
   What's unclear: whether this phase should add a dedicated planning-truth ExUnit file or stay with grep-backed plan verification only. [VERIFIED: local file `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`]
   Recommendation: keep public-doc assertions in `docs_truth_test.exs` and use grep-backed validation for planning artifacts unless the planner sees repeated drift that justifies a dedicated planning-truth test. [VERIFIED: local files `test/lattice_stripe/docs_truth_test.exs`, `.planning/phases/42-planning-truth-reconciliation/42-VALIDATION.md`]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Mix / ExUnit | docs-truth regression runs and any targeted validation command | ✓ [VERIFIED: local command output] | Mix 1.19.5 on OTP 28 [VERIFIED: local command `mix --version`] | — |
| `rg` | grep-backed planning and docs assertions | ✓ [VERIFIED: local command output] | 15.1.0 [VERIFIED: local command `rg --version`] | `grep`, but slower and less convenient [ASSUMED] |
| Node | existing GSD tooling and some planning helpers | ✓ [VERIFIED: local command output] | v22.14.0 [VERIFIED: local command `node --version`] | — |

**Missing dependencies with no fallback:**
- None found in the current workspace for planning and validation of this docs/truth phase. [VERIFIED: local command output]

**Missing dependencies with fallback:**
- None found. [VERIFIED: local command output]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit on Elixir 1.19.5 / Mix 1.19.5 in the current workspace. [VERIFIED: local files `test/test_helper.exs`, `test/lattice_stripe/docs_truth_test.exs`] [VERIFIED: local command `mix --version`] |
| Config file | none; standard Mix/ExUnit layout. [VERIFIED: local files `mix.exs`, `test/test_helper.exs`] |
| Quick run command | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` [VERIFIED: local file `test/lattice_stripe/docs_truth_test.exs`] |
| Full suite command | `mix test` [ASSUMED] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RECIPE-03 | Connect flagship guide is published, linked from the entry points, and preserves the Express/destination-charge/webhook-truth default. [VERIFIED: local files `.planning/REQUIREMENTS.md`, `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`] | docs-truth unit + grep | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` [VERIFIED: local file `test/lattice_stripe/docs_truth_test.exs`] | ✅ existing file; new assertions required. [VERIFIED: local file `test/lattice_stripe/docs_truth_test.exs`] |
| RECIPE-04 | Quote flagship guide is published, linked, and preserves the bounded downstream-inspection and proof-boundary wording. [VERIFIED: local files `.planning/REQUIREMENTS.md`, `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`] | docs-truth unit + grep | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` [VERIFIED: local file `test/lattice_stripe/docs_truth_test.exs`] | ✅ existing file; new assertions required. [VERIFIED: local file `test/lattice_stripe/docs_truth_test.exs`] |
| PLAN-01 | Core planning artifacts say v1.4 is close-ready while preserving Phase `41.1` as `pending-external-verification`. [VERIFIED: local files `.planning/REQUIREMENTS.md`, `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`] | grep-backed artifact verification | `rg -n 'close-ready|pending-external-verification|Phase 41\\.1|adoption-closure|Phase 46' .planning/PROJECT.md .planning/ROADMAP.md .planning/REQUIREMENTS.md .planning/STATE.md` [VERIFIED: local phase-42 validation pattern + local file state] | ✅ command pattern exists; dedicated test file does not. [VERIFIED: local file `.planning/phases/42-planning-truth-reconciliation/42-VALIDATION.md`] |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` plus targeted `rg` over the touched planning files. [VERIFIED: local files `test/lattice_stripe/docs_truth_test.exs`, `.planning/phases/42-planning-truth-reconciliation/42-VALIDATION.md`]
- **Per wave merge:** `mix test` plus the `PLAN-01` grep command above. [ASSUMED]
- **Phase gate:** flagship docs are published and cross-linked, then the four core planning files explicitly preserve `close-ready` and `pending-external-verification` semantics before `/gsd-verify-work`. [VERIFIED: local file `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`]

### Wave 0 Gaps

- `test/lattice_stripe/docs_truth_test.exs` needs assertions for the two new flagship guide filenames, their presence in `docs[:extras]`, and their presence in the `Flagship Recipes` group. [VERIFIED: local file `test/lattice_stripe/docs_truth_test.exs`]
- The same test file should assert that `guides/recipes.md` and `guides/user-flows-and-jtbd.md` route into the new Connect and Quote flagship guides. [VERIFIED: local files `guides/recipes.md`, `guides/user-flows-and-jtbd.md`, `test/lattice_stripe/docs_truth_test.exs`]
- The same test file should assert durable anchor phrases for the Connect and Quote guides, such as `destination charges`, `application_fee_amount`, `transfer_group`, `invoice`, `subscription_schedule`, and `pending-external-verification`-adjacent proof-boundary wording where appropriate. [VERIFIED: local phase context + local file `test/lattice_stripe/docs_truth_test.exs`] [ASSUMED]
- No dedicated automated planning-truth test file exists today; `PLAN-01` verification currently depends on grep-backed artifact assertions. [VERIFIED: local files `.planning/phases/42-planning-truth-reconciliation/42-VALIDATION.md`, `test/`] 

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | This phase does not introduce auth logic and should not imply that portal or account-link redirects authenticate durable business state. [VERIFIED: local guide files `guides/connect-accounts.md`, `guides/checkout-signup-and-portal.md`] |
| V3 Session Management | yes | Treat `AccountLink`, `LoginLink`, and portal `session.url` values as bearer credentials and redirect immediately without logging or persistence. [VERIFIED: local files `guides/connect-accounts.md`, `guides/customer-portal.md`] |
| V4 Access Control | yes | Keep LatticeStripe docs out of operator-product or entitlement policy design and route those concerns to application code or Accrue. [VERIFIED: local files `.planning/threads/lattice-stripe-vs-accrue-scope-boundary.md`, `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`] |
| V5 Input Validation | yes | Preserve raw-body webhook verification guidance and do not soften it in flagship docs. [VERIFIED: local file `guides/webhooks.md`] [CITED: https://docs.stripe.com/webhooks?locale=en-GB] [CITED: https://hexdocs.pm/plug/Plug.Conn.html] |
| V6 Cryptography | yes | Keep Stripe signature verification and secure raw-body handling as the only documented authenticity mechanism for webhook truth. [VERIFIED: local file `guides/webhooks.md`] [CITED: https://docs.stripe.com/webhooks?locale=en-GB] |

### Known Threat Patterns for This Phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Logging or storing bearer URLs from `AccountLink`, `LoginLink`, or portal sessions | Information Disclosure | Keep the warning inline at the action point and avoid examples that persist these URLs. [VERIFIED: local files `guides/connect-accounts.md`, `guides/customer-portal.md`] |
| Fulfilling platform or quote state from redirects alone | Tampering | Teach webhook-confirmed and follow-up-read truth only. [VERIFIED: local files `guides/connect-accounts.md`, `guides/checkout-signup-and-portal.md`] [CITED: https://docs.stripe.com/checkout/fulfillment] |
| Mutated webhook body before signature verification | Spoofing | Preserve the raw-body requirement and existing Plug posture. [VERIFIED: local file `guides/webhooks.md`] [CITED: https://docs.stripe.com/webhooks?locale=en-GB] [CITED: https://hexdocs.pm/plug/Plug.Conn.html] |
| Overstated quote proof that hides the missing external environment evidence | Repudiation | Keep the proof boundary explicit in public docs and preserve `pending-external-verification` in planning docs. [VERIFIED: local files `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md`, `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md` - locked scope, close posture, and required guide truth.
- `.planning/PROJECT.md` - v1.4 adoption-closure posture and milestone scope.
- `.planning/ROADMAP.md` - Phase 46 plan split and current roadmap drift.
- `.planning/REQUIREMENTS.md` - `RECIPE-03`, `RECIPE-04`, and `PLAN-01`.
- `.planning/STATE.md` - current milestone position and stale focus wording that Phase 46 must reconcile.
- `.planning/threads/v1-4-adoption-closure.md` - done-enough bar for v1.4.
- `.planning/threads/lattice-stripe-vs-accrue-scope-boundary.md` - scope boundary against billing-engine behavior.
- `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md` - authoritative external-proof boundary status.
- `.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md` - existing repo truth model for reconciliation work.
- `.planning/phases/45-flagship-recipes-i/45-RESEARCH.md` - established flagship-guide architecture pattern.
- `mix.exs` - current ExDoc extras and `Flagship Recipes` group.
- `guides/connect.md` - current conceptual Connect framing and charge-pattern split.
- `guides/connect-accounts.md` - current Express onboarding, AccountLink, LoginLink, and webhook handoff posture.
- `guides/connect-money-movement.md` - destination charges, transfers, payouts, and reconciliation distinctions.
- `guides/recipes.md` and `guides/user-flows-and-jtbd.md` - task-first routing layers that need new flagship links.
- `lib/lattice_stripe/quote.ex` - current Quote lifecycle boundary.
- `test/integration/quote_integration_test.exs` - bounded downstream-inspection order.
- `test/lattice_stripe/docs_truth_test.exs` - current docs publication and routing assertions.
- https://docs.stripe.com/connect/accounts?locale=en-GB - current Express connected-account posture.
- https://docs.stripe.com/connect/charges?locale=en-GB - current charge-pattern comparison and switch criteria.
- https://docs.stripe.com/connect/destination-charges?locale=en-GB&platform=web&ui=elements - current destination-charge semantics and `on_behalf_of` note.
- https://docs.stripe.com/webhooks?locale=en-GB - raw-body signature and quick-2xx webhook posture.
- https://docs.stripe.com/quotes - current Quote lifecycle and downstream-object outcomes.
- https://docs.stripe.com/api/quotes/accept - current `accept` contract and returned object semantics.
- https://docs.stripe.com/billing/subscriptions/webhooks - current invoice/subscription webhook authority.
- https://docs.stripe.com/checkout/fulfillment - explicit webhook-required fulfillment posture.
- https://hexdocs.pm/plug/Plug.Conn.html - `read_body/2` contract relevant to raw-body guidance.

### Secondary (MEDIUM confidence)

- `.planning/MILESTONES.md` - broader milestone history and current archived v1.3 wording.
- https://hexdocs.pm/ecto/getting-started.html - evidence that mature Elixir docs keep a stable onboarding/reference split.
- https://hexdocs.pm/oban/Oban.html - evidence that mature Elixir docs use layered quickstart plus deeper operational material.

### Tertiary (LOW confidence)

- None beyond the assumptions explicitly logged above. [VERIFIED: this document]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - the phase reuses a verified local docs/test/publication stack and official Stripe docs for current semantics. [VERIFIED: local files `mix.exs`, `test/lattice_stripe/docs_truth_test.exs`, guide files] [CITED: official Stripe docs listed above]
- Architecture: HIGH - the existing repo pattern from Phases 42 and 45 aligns cleanly with the locked Phase 46 scope. [VERIFIED: local files `.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md`, `.planning/phases/45-flagship-recipes-i/45-RESEARCH.md`, `.planning/phases/46-flagship-recipes-ii-planning-truth-closure/46-CONTEXT.md`]
- Pitfalls: HIGH - the main failure modes are already documented in current local guides, proof artifacts, and Stripe’s current webhook/Connect/Quote docs. [VERIFIED: local files `guides/connect-accounts.md`, `guides/connect-money-movement.md`, `guides/checkout-signup-and-portal.md`, `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md`] [CITED: official Stripe docs listed above]

**Research date:** 2026-05-26 [VERIFIED: local command output]  
**Valid until:** 2026-06-25 for repo-local truth; re-check Stripe docs sooner if Connect or Quote lifecycle docs materially change. [CITED: official Stripe docs listed above]
