# Phase 44: Guide Discovery & Support Truth - Research

**Researched:** 2026-05-26  
**Domain:** docs entry-point routing, ExDoc guide organization, and support-truth posture for the shipped `1.3.x` surface  
**Confidence:** HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GUIDE-01 | Developers can find canonical guides for already-shipped high-leverage surfaces from the main docs entry points. | `README.md`, `guides/getting-started.md`, `guides/user-flows-and-jtbd.md`, and `guides/recipes.md` already exist, but route unevenly. README lists many guides flatly, Getting Started branches only lightly, and ExDoc still publishes nearly everything under one `Guides` bucket. |
| GUIDE-02 | Cross-links between recipes, resource guides, and onboarding docs make the shipped surface easier to navigate without guesswork. | The strongest guide content already exists in `guides/webhooks.md`, `guides/testing.md`, `guides/error-handling.md`, `guides/subscriptions.md`, `guides/customer-portal.md`, `guides/metering.md`, and Connect guides, but “read next” routing is inconsistent and not yet opinionated enough from the public entry points. |
| VERIFY-02 | Docs-truth coverage extends beyond README to the main onboarding and discovery surfaces adopters actually hit first. | `test/lattice_stripe/docs_truth_test.exs` currently guards install/version truth and basic ExDoc publication, but it does not assert route-by-intent links, grouped docs entry roles, or the presence of key discovery paths across README / Getting Started / JTBD / recipes. |
</phase_requirements>

## Summary

Phase 44 is not about creating new SDK capability or turning LatticeStripe into a workflow product. The repo already contains the high-leverage guide families Phase 44 needs: subscriptions, customer portal, metering, Connect, webhooks, testing, and error handling are all present and generally strong. The gap is discoverability and orientation: a serious evaluator can reach the right material, but the path is flatter and more incidental than it should be.

The strongest existing assets are:

- `guides/user-flows-and-jtbd.md` as the task-first routing layer
- `guides/webhooks.md`, `guides/testing.md`, and `guides/error-handling.md` as the trust-rail cluster
- `guides/subscriptions.md`, `guides/customer-portal.md`, `guides/metering.md`, and Connect guides as the canonical high-value surface guides
- `mix.exs` docs metadata, which already publishes all of those guides through ExDoc

The biggest current weaknesses are structural rather than content depth:

- `README.md` points to JTBD, but the rest of the guide list is a long flat catalog rather than a guided ladder.
- `guides/getting-started.md` still ends with a relatively narrow next-step set and does not clearly branch first-success users into recurring billing, portal follow-through, metering, Connect, testing, and troubleshooting.
- `mix.exs` groups all guide extras into one `Guides` bucket, which hides the difference between “start here”, canonical surface guides, and operations/DX guidance.
- `test/lattice_stripe/docs_truth_test.exs` does not yet protect these discovery paths, so guide-routing drift can happen without failing CI.

**Primary recommendation:** split the phase into two plans:

1. **Entry-point IA and prominence** — rework the main docs entry points and ExDoc grouping so adopters can discover the right canonical guides quickly.
2. **Support-truth and graph hardening** — add inline support-truth notes and explicit guide-graph routing at high-risk operational boundaries, then lock the discovery contract into docs-truth tests.

## Verified Current Truth

### Public entry points

- `README.md` already tells evaluators to start with `guides/user-flows-and-jtbd.md`, but the rest of the page still reads more like a broad feature catalog than a guided docs ladder.
- `guides/getting-started.md` remains the ExDoc `main` page and is the correct first-run landing page, but its “Next Steps” are payments/checkout/webhooks focused and do not strongly surface subscriptions, customer portal, metering, Connect, testing, or troubleshooting.
- `guides/user-flows-and-jtbd.md` already contains the right mental model for runtime billing truth: API acceptance now vs webhook-confirmed reality later.
- `guides/recipes.md` is intentionally compact and library-scoped; it should stay a bridge rather than becoming the new canonical guide tree.

### Canonical guides already worth routing to

- `guides/subscriptions.md` is a strong recurring-billing canonical guide.
- `guides/customer-portal.md` already explains deep-link flows and explicitly warns that portal redirects are not authoritative truth.
- `guides/webhooks.md` clearly states the raw-body invariant and the “webhooks confirm reality” rule.
- `guides/testing.md` already exposes the public testing-fixture surface.
- `guides/error-handling.md` already gives the structured operational error story.
- `guides/metering.md`, `guides/connect.md`, `guides/connect-accounts.md`, and `guides/connect-money-movement.md` provide the deeper surfaces the milestone wants adopters to discover earlier.

### ExDoc publication shape

- `mix.exs` keeps `main: "getting-started"` and publishes the main guide set as extras.
- `groups_for_extras` is still:

```elixir
groups_for_extras: [
  Guides: Path.wildcard("guides/*.{md,cheatmd}"),
  Changelog: ["CHANGELOG.md"]
]
```

This is functional but too flat for the Phase 44 discovery goal.

### Current regression coverage

`test/lattice_stripe/docs_truth_test.exs` asserts:

- ExDoc keeps `getting-started` as the main page
- key extras stay published
- README still points to recipes and the `1.3` line
- Getting Started and cheatsheet keep install truth
- CHANGELOG records the shipped `1.3.0` truth

It does **not** yet assert:

- README route-by-intent links to the highest-leverage guides
- Getting Started branches into recurring billing / portal / metering / Connect / trust rails
- JTBD or recipes remain reachable in the public discovery path
- ExDoc grouping reflects layered guide roles instead of one flat bucket

## Recommended Artifact Set

### 1. `44-01-PLAN.md`

Rework the main docs entry points and ExDoc grouping:

- `README.md`
- `guides/getting-started.md`
- `guides/user-flows-and-jtbd.md`
- `guides/recipes.md`
- `mix.exs`

The goal is to make the public ladder explicit:

- first impression (`README.md`)
- first success (`guides/getting-started.md`)
- evaluator orientation (`guides/user-flows-and-jtbd.md`)
- bridge layer (`guides/recipes.md`)
- grouped canonical guides in ExDoc

### 2. `44-02-PLAN.md`

Publish support-truth notes and lock the route graph into tests:

- strengthen inline support-truth and “read next” routing in the highest-leverage canonical guides
- optionally add a small secondary orientation/support-truth page only if it remains clearly secondary to inline truth
- extend `test/lattice_stripe/docs_truth_test.exs` so discovery and support-truth routing drift fails fast

## Patterns To Reuse

### Pattern 1: Keep the canonical map surface-first

Task-first docs are a routing layer, not a replacement for surface guides. Preserve `guides/user-flows-and-jtbd.md` and `guides/recipes.md` as entry aids while sending readers into the canonical surface guides.

### Pattern 2: Route from one clear path per entry point

The repo already reads best when one page recommends the next move directly. Avoid broad “everything is equally important” lists where the user still has to reverse-engineer the ideal path.

### Pattern 3: Inline support truth at the action point

The strongest docs already say things like “webhooks confirm reality” and “do not rely on redirect truth” inside the relevant guides. Reuse that posture instead of centralizing all caveats into one isolated page.

### Pattern 4: Lightweight docs-truth assertions

Continue the `File.read!/1` plus docs metadata assertion style in `test/lattice_stripe/docs_truth_test.exs`. Phase 44 needs better discovery coverage, not a heavier docs linting system.

## Anti-Patterns To Avoid

- Do not broaden into a full rewrite of every guide.
- Do not turn JTBD or recipes pages into a second canonical docs tree that competes with the surface guides.
- Do not present support-truth in a detached “caveats page” while omitting it where users actually act.
- Do not drift into Accrue-style workflow ownership, entitlement logic, or billing-engine architecture.
- Do not overfit regression tests to long prose blocks; assert durable links, guide roles, and route anchors instead.

## Open Questions

One discretionary choice remains for execution: whether a small centralized support-truth/orientation page adds enough value to justify itself. The context allows it only as a secondary synthesis page, so plans should keep it optional and avoid depending on it for critical truth.

---
*Phase: 44-guide-discovery-support-truth*
*Research captured: 2026-05-26*
