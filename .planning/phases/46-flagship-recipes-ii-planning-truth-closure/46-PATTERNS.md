# Phase 46: Flagship Recipes II & Planning Truth Closure - Pattern Map

**Mapped:** 2026-05-26
**Files analyzed:** 10
**Analogs found:** 10 / 10

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `guides/connect-platform-flow.md` | component | transform | `guides/checkout-signup-and-portal.md` | exact |
| `guides/quote-to-billing-operator.md` | component | transform | `guides/checkout-signup-and-portal.md` | exact |
| `guides/recipes.md` | component | transform | `guides/recipes.md` | exact |
| `guides/user-flows-and-jtbd.md` | component | transform | `guides/user-flows-and-jtbd.md` | exact |
| `mix.exs` | config | transform | `mix.exs` | exact |
| `test/lattice_stripe/docs_truth_test.exs` | test | transform | `test/lattice_stripe/docs_truth_test.exs` | exact |
| `.planning/PROJECT.md` | config | transform | `.planning/PROJECT.md` | exact |
| `.planning/ROADMAP.md` | config | transform | `.planning/ROADMAP.md` | exact |
| `.planning/REQUIREMENTS.md` | config | transform | `.planning/REQUIREMENTS.md` | exact |
| `.planning/STATE.md` | config | transform | `.planning/STATE.md` | exact |

## Pattern Assignments

### `guides/connect-platform-flow.md` (component, transform)

**Primary analog:** `guides/checkout-signup-and-portal.md`

**Guide framing pattern** ([guides/checkout-signup-and-portal.md](/Users/jon/projects/lattice_stripe/guides/checkout-signup-and-portal.md:3), lines 3-9):
```markdown
Use this guide when you want the fastest safe recurring-billing path for a Phoenix or
Elixir SaaS: Stripe-hosted signup with Checkout, webhook-confirmed provisioning, and
Stripe-hosted follow-through for routine billing changes.

This is a workflow playbook, not a second API reference. It shows one recommended spine,
calls out the operational footguns inline, and routes you back to the canonical guides
when you need deeper surface detail.
```

**Recommended-spine pattern** ([guides/checkout-signup-and-portal.md](/Users/jon/projects/lattice_stripe/guides/checkout-signup-and-portal.md:11), lines 11-26):
```markdown
## Why this is the default hosted path

...

**Your app starts the flow. Webhooks confirm reality.**
```

**Thin Phoenix + bearer redirect pattern** ([guides/connect-accounts.md](/Users/jon/projects/lattice_stripe/guides/connect-accounts.md:79), lines 79-123):
```elixir
{:ok, link} = LatticeStripe.AccountLink.create(client, %{
  "account" => account.id,
  "type" => "account_onboarding",
  "refresh_url" => "https://myplatform.example.test/connect/refresh",
  "return_url" => "https://myplatform.example.test/connect/return"
})

redirect_user_to(link.url)
```

**Destination-charge default pattern** ([guides/connect-money-movement.md](/Users/jon/projects/lattice_stripe/guides/connect-money-movement.md:177), lines 177-212):
```elixir
{:ok, pi} =
  LatticeStripe.PaymentIntent.create(client, %{
    "amount" => 5000,
    "currency" => "usd",
    "payment_method_types" => ["card"],
    "application_fee_amount" => 500,
    "transfer_data" => %{"destination" => "acct_123"},
    "on_behalf_of" => "acct_123",
    "transfer_group" => "ORDER_42"
  })
```

**Switch-pattern section to copy** ([guides/connect-money-movement.md](/Users/jon/projects/lattice_stripe/guides/connect-money-movement.md:214), lines 214-258):
```markdown
## Separate charges and transfers

When a single order fans out to multiple connected accounts, or when the
merchant of record is the platform, use the separate-charges-and-transfers
pattern.
```

**Read-next section pattern** ([guides/checkout-signup-and-portal.md](/Users/jon/projects/lattice_stripe/guides/checkout-signup-and-portal.md:230), lines 230-237):
```markdown
## Read next

- [Checkout](checkout.md)
- [Subscriptions](subscriptions.md)
- [Customer Portal](customer-portal.md)
- [Webhooks](webhooks.md)
```

### `guides/quote-to-billing-operator.md` (component, transform)

**Primary analog:** `guides/checkout-signup-and-portal.md`

**Supporting analogs:** `lib/lattice_stripe/quote.ex`, `test/integration/quote_integration_test.exs`, `guides/recipes.md`

**Flagship-guide framing pattern** ([guides/checkout-signup-and-portal.md](/Users/jon/projects/lattice_stripe/guides/checkout-signup-and-portal.md:7), lines 7-9):
```markdown
This is a workflow playbook, not a second API reference. It shows one recommended spine,
calls out the operational footguns inline, and routes you back to the canonical guides
when you need deeper surface detail.
```

**SDK-boundary wording to preserve** ([lib/lattice_stripe/quote.ex](/Users/jon/projects/lattice_stripe/lib/lattice_stripe/quote.ex:20), lines 20-23):
```elixir
Accepting a quote may create downstream billing objects such as an Invoice,
Subscription, or SubscriptionSchedule. This module intentionally stops at the
Stripe resource boundary and does not add application-level orchestration or
prediction helpers.
```

**Operator-path sequence to copy** ([test/integration/quote_integration_test.exs](/Users/jon/projects/lattice_stripe/test/integration/quote_integration_test.exs:79), lines 79-97):
```elixir
quote = create_quote!(client, %{"customer_email" => "quote-lifecycle@example.com"})

{:ok, finalized} = Quote.finalize(client, quote.id, %{})
assert {:ok, pdf_binary} = Quote.pdf(client, quote.id)
{:ok, accepted} = Quote.accept(client, quote.id)

assert_downstream_follow_through(client, accepted)
```

**Downstream inspection order to copy** ([test/integration/quote_integration_test.exs](/Users/jon/projects/lattice_stripe/test/integration/quote_integration_test.exs:124), lines 124-153):
```elixir
cond do
  is_binary(quote.invoice) -> {:invoice, quote.invoice}
  is_binary(quote.subscription) -> {:subscription, quote.subscription}
  is_binary(quote.subscription_schedule) ->
    {:subscription_schedule, quote.subscription_schedule}

  true ->
    :none
end
```

**Compact discovery wording already in repo** ([guides/recipes.md](/Users/jon/projects/lattice_stripe/guides/recipes.md:109), lines 109-145):
```markdown
Quote acceptance is the beginning of the downstream billing transition, not the final
state your app should trust on its own. Confirm invoice, subscription, or payment
follow-through from your webhook handlers and any follow-up retrievals you need for
the exact product workflow.
```

### `guides/recipes.md` (component, transform)

**Analog:** `guides/recipes.md`

**Routing-layer pattern** ([guides/recipes.md](/Users/jon/projects/lattice_stripe/guides/recipes.md:3), lines 3-23):
```markdown
This guide is a compact bridge between [User Flows & JTBD](user-flows-and-jtbd.md)
and the deeper resource guides. It stays library-scoped on purpose: the goal is to
show which LatticeStripe calls usually matter, where the webhook confirmation point
lives, and which guide to read next.
```

**Recipe entry pattern** ([guides/recipes.md](/Users/jon/projects/lattice_stripe/guides/recipes.md:109), lines 109-150):
```markdown
## Quote-to-invoice flow

### Job to be done
...
### Key calls
...
### Webhook confirmation point
...
### Read next
```

Planner note: add short pointers into the two new flagship guides, but keep canonical guides listed beside them. Do not turn `recipes.md` into a duplicate walkthrough.

### `guides/user-flows-and-jtbd.md` (component, transform)

**Analog:** `guides/user-flows-and-jtbd.md`

**Top-level truth model** ([guides/user-flows-and-jtbd.md](/Users/jon/projects/lattice_stripe/guides/user-flows-and-jtbd.md:24), lines 24-39):
```markdown
### 1. Your app starts flows. Webhooks confirm reality.
...
**API responses tell you what Stripe accepted right now. Webhooks tell you what became true.**
```

**Start-here routing pattern** ([guides/user-flows-and-jtbd.md](/Users/jon/projects/lattice_stripe/guides/user-flows-and-jtbd.md:75), lines 75-90):
```markdown
## Start Here By Situation

Use this guide as a routing layer, not as the final source of API truth.
```

**JTBD section shape** ([guides/user-flows-and-jtbd.md](/Users/jon/projects/lattice_stripe/guides/user-flows-and-jtbd.md:125), lines 125-164):
```markdown
### Job 2: "Start and run recurring billing"
...
Read next:

- [Checkout Signup and Portal Follow-Through](checkout-signup-and-portal.md)
- [Subscriptions](subscriptions.md)
```

Planner note: add a Connect flagship pointer under marketplace/platform work and a Quote flagship pointer under invoice-first or quote-related billing flow language, but keep this page as a router.

### `mix.exs` (config, transform)

**Analog:** `mix.exs`

**Docs extras pattern** ([mix.exs](/Users/jon/projects/lattice_stripe/mix.exs:18), lines 18-51):
```elixir
docs: [
  main: "getting-started",
  ...
  extras: [
    "guides/getting-started.md",
    "guides/user-flows-and-jtbd.md",
    "guides/checkout-signup-and-portal.md",
    "guides/metering-runtime-and-reconciliation.md",
    ...
  ],
```

**Flagship Recipes grouping pattern** ([mix.exs](/Users/jon/projects/lattice_stripe/mix.exs:52), lines 52-64):
```elixir
groups_for_extras: [
  {"Start Here", [...]},
  {"Flagship Recipes",
   [
     "guides/checkout-signup-and-portal.md",
     "guides/metering-runtime-and-reconciliation.md"
   ]},
```

Planner note: add both new guide paths to `extras` and to the `Flagship Recipes` group. Preserve the explicit subgrouping rather than moving them into `Canonical Guides`.

### `test/lattice_stripe/docs_truth_test.exs` (test, transform)

**Analog:** `test/lattice_stripe/docs_truth_test.exs`

**Docs config assertion pattern** ([test/lattice_stripe/docs_truth_test.exs](/Users/jon/projects/lattice_stripe/test/lattice_stripe/docs_truth_test.exs:8), lines 8-36):
```elixir
test "exdoc keeps the primary public truth surfaces published" do
  docs = docs_config()
  extras = docs[:extras]
  groups = docs[:groups_for_extras] |> Map.new()

  assert "guides/checkout-signup-and-portal.md" in extras
  assert "guides/metering-runtime-and-reconciliation.md" in extras
  assert "guides/checkout-signup-and-portal.md" in groups["Flagship Recipes"]
  assert "guides/metering-runtime-and-reconciliation.md" in groups["Flagship Recipes"]
end
```

**Routing-surface assertion pattern** ([test/lattice_stripe/docs_truth_test.exs](/Users/jon/projects/lattice_stripe/test/lattice_stripe/docs_truth_test.exs:69), lines 69-92):
```elixir
test "jtbd and recipes stay task-first routing layers into canonical guides" do
  jtbd = File.read!("guides/user-flows-and-jtbd.md")
  recipes = File.read!("guides/recipes.md")

  assert jtbd =~ "Use this guide as a routing layer"
  assert recipes =~ "canonical"
end
```

**Flagship guide anchor-phrase pattern** ([test/lattice_stripe/docs_truth_test.exs](/Users/jon/projects/lattice_stripe/test/lattice_stripe/docs_truth_test.exs:94), lines 94-123):
```elixir
assert checkout_recipe =~ "webhooks"
assert checkout_recipe =~ "payment_method_update"
assert checkout_recipe =~ "subscription_cancel"
assert checkout_recipe =~ "session.url"

assert metering_recipe =~ "identifier"
assert metering_recipe =~ "idempotency_key"
assert metering_recipe =~ "MeterEventAdjustment"
assert metering_recipe =~ "accepted for processing"
```

Planner note: reuse this exact test style for the new guides. Assert filenames, group membership, route references, and a few durable truth anchors like `destination charges`, `application_fee_amount`, `transfer_group`, `invoice`, `subscription_schedule`, and proof-boundary wording.

### `.planning/PROJECT.md` (config, transform)

**Analog:** `.planning/PROJECT.md`

**Milestone posture block** ([.planning/PROJECT.md](/Users/jon/projects/lattice_stripe/.planning/PROJECT.md:27), lines 27-39):
```markdown
## Current Milestone: v1.4 Adoption Closure

**Goal:** Make the shipped `1.3.x` surface obvious, trustworthy, and easier to evaluate
for serious Elixir and Phoenix SaaS teams.
...
- Planning truth preserves the narrow Phase `41.1` external Quote proof boundary
  instead of flattening it into a false full-close story.
```

**Close-posture wording pattern** ([.planning/PROJECT.md](/Users/jon/projects/lattice_stripe/.planning/PROJECT.md:21), lines 21-25):
```markdown
**Close posture:**

- v1.3 is archived and v1.4 is now the active milestone.
- One accepted follow-through remains outside the milestone headline: Phase `41.1`
  is still `pending-external-verification` for real-sandbox Quote downstream proof.
```

Planner note: update milestone-close wording here, but preserve the accepted-boundary language instead of collapsing it into full proof closure.

### `.planning/ROADMAP.md` (config, transform)

**Analog:** `.planning/ROADMAP.md`

**Milestone constraints pattern** ([.planning/ROADMAP.md](/Users/jon/projects/lattice_stripe/.planning/ROADMAP.md:11), lines 11-22):
```markdown
## Current Milestone: v1.4 Adoption Closure

**Goal:** Make the shipped `1.3.x` surface obvious, trustworthy, and easier to evaluate
for serious Elixir and Phoenix SaaS teams.

**Milestone constraints:**

- Keep recipe/operator guidance primitive-first and library-scoped.
- Preserve the accepted Phase `41.1` external-proof boundary truthfully instead of
  flattening it into a false close.
```

**Phase entry pattern** ([.planning/ROADMAP.md](/Users/jon/projects/lattice_stripe/.planning/ROADMAP.md:67), lines 67-83):
```markdown
### Phase 46: Flagship Recipes II & Planning Truth Closure
...
Plans:

- [ ] 46-01-PLAN.md — Connect platform flow and quote-to-billing operator guidance
- [ ] 46-02-PLAN.md — Reconcile roadmap, requirements, and state truth while preserving
  the explicit Phase `41.1` external-proof boundary
```

Planner note: `ROADMAP.md` is the main place to fix the stale next-step pointer and to shift the milestone from active execution to close-ready language once Phase 46 lands.

### `.planning/REQUIREMENTS.md` (config, transform)

**Analog:** `.planning/REQUIREMENTS.md`

**Requirement family pattern** ([.planning/REQUIREMENTS.md](/Users/jon/projects/lattice_stripe/.planning/REQUIREMENTS.md:24), lines 24-33):
```markdown
### Flagship Recipes

- [ ] **RECIPE-01**: ...
- [ ] **RECIPE-02**: ...
- [ ] **RECIPE-03**: A developer can follow a flagship recipe for a Connect platform flow
  using shipped LatticeStripe primitives.
- [ ] **RECIPE-04**: Quote-to-billing operator guidance explains the shipped flow honestly
  and preserves the explicit Phase `41.1` external-proof boundary.
```

**Traceability table pattern** ([.planning/REQUIREMENTS.md](/Users/jon/projects/lattice_stripe/.planning/REQUIREMENTS.md:53), lines 53-67):
```markdown
| Requirement | Phase | Status |
|-------------|-------|--------|
| RECIPE-03 | Phase 46 | Pending |
| RECIPE-04 | Phase 46 | Pending |
| PLAN-01 | Phase 46 | Pending |
```

**Layered-truth rule to reuse** ([.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md](/Users/jon/projects/lattice_stripe/.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md:180), lines 180-189):
```markdown
**What:** Keep shipped-capability checkboxes separate from traceability/verification status rows.
...
- [x] **QUOT-01**: ...
| QUOT-01 | Phase 41 | Verified |
```

Planner note: mark the checklist and traceability rows only when Phase 46 evidence exists, and keep `pending-external-verification` scoped to Phase `41.1`, not to the shipped recipe requirements themselves.

### `.planning/STATE.md` (config, transform)

**Analog:** `.planning/STATE.md`

**Frontmatter progress pattern** ([.planning/STATE.md](/Users/jon/projects/lattice_stripe/.planning/STATE.md:1), lines 1-15):
```yaml
gsd_state_version: 1.0
milestone: v1.4
status: ready_to_verify
stopped_at: Phase 45 complete (2/2) — ready to verify Phase 45
progress:
  total_phases: 4
  completed_phases: 3
  total_plans: 6
  completed_plans: 6
  percent: 75
```

**Current-position section pattern** ([.planning/STATE.md](/Users/jon/projects/lattice_stripe/.planning/STATE.md:26), lines 26-36):
```markdown
## Current Position

Milestone: v1.4 (Adoption Closure)
Phase: 45 (flagship-recipes-i) — COMPLETE
Plan: 2 of 2 complete
Status: Ready to verify Phase 45
```

**Concern vocabulary to preserve** ([.planning/STATE.md](/Users/jon/projects/lattice_stripe/.planning/STATE.md:68), lines 68-76):
```markdown
### Blockers/Concerns

- Phase 41.1 remains explicitly `pending-external-verification` until sandbox proof is
  produced or the follow-through is retired.
- Phase 41.1 is real but too narrow to justify the milestone headline; v1.4 should
  preserve that truth without letting it dominate scope.
```

Planner note: update current position to Phase 46 / milestone close-ready, but keep the blocker language explicit about the narrow remaining external-proof item.

## Shared Patterns

### Flagship Guide Spine
**Sources:** [guides/checkout-signup-and-portal.md](/Users/jon/projects/lattice_stripe/guides/checkout-signup-and-portal.md:7), [guides/metering-runtime-and-reconciliation.md](/Users/jon/projects/lattice_stripe/guides/metering-runtime-and-reconciliation.md:7)
**Apply to:** `guides/connect-platform-flow.md`, `guides/quote-to-billing-operator.md`
```markdown
This is a workflow playbook, not a second API reference.
...
## Read next
```

### Webhook-Owned Durable Truth
**Sources:** [guides/user-flows-and-jtbd.md](/Users/jon/projects/lattice_stripe/guides/user-flows-and-jtbd.md:24), [guides/connect-accounts.md](/Users/jon/projects/lattice_stripe/guides/connect-accounts.md:207), [guides/connect-money-movement.md](/Users/jon/projects/lattice_stripe/guides/connect-money-movement.md:209)
**Apply to:** both new guides, routing blurbs, docs-truth assertions
```markdown
**API responses tell you what Stripe accepted right now. Webhooks tell you what became true.**
```

### ExDoc Publication Contract
**Sources:** [mix.exs](/Users/jon/projects/lattice_stripe/mix.exs:23), [test/lattice_stripe/docs_truth_test.exs](/Users/jon/projects/lattice_stripe/test/lattice_stripe/docs_truth_test.exs:8)
**Apply to:** `mix.exs`, `test/lattice_stripe/docs_truth_test.exs`
```elixir
assert "guides/...new-guide..." in extras
assert "guides/...new-guide..." in groups["Flagship Recipes"]
```

### Planning Truth Vocabulary
**Sources:** [.planning/PROJECT.md](/Users/jon/projects/lattice_stripe/.planning/PROJECT.md:21), [.planning/ROADMAP.md](/Users/jon/projects/lattice_stripe/.planning/ROADMAP.md:17), [.planning/STATE.md](/Users/jon/projects/lattice_stripe/.planning/STATE.md:68), [.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md](/Users/jon/projects/lattice_stripe/.planning/phases/42-planning-truth-reconciliation/42-RESEARCH.md:14)
**Apply to:** `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`
```markdown
close-ready
pending-external-verification
preserve the accepted Phase `41.1` external-proof boundary truthfully
```

## No Analog Found

None. Every planned file has a strong repo-local analog or an existing same-file pattern.

## Metadata

**Analog search scope:** `guides/`, `lib/`, `test/`, `.planning/`, `mix.exs`, `CLAUDE.md`
**Files scanned:** 14
**Pattern extraction date:** 2026-05-26
