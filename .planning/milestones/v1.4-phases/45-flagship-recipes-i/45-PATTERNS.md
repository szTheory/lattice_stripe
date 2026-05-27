# Phase 45: Flagship Recipes I - Patterns

## Closest Planning Analogs

### Primary analog: Phase 44 docs-routing plans

- `.planning/phases/44-guide-discovery-support-truth/44-01-PLAN.md`
- `.planning/phases/44-guide-discovery-support-truth/44-02-PLAN.md`

Why they match:

- same public-docs surface area
- same task-first routing constraints
- same `mix.exs` + `test/lattice_stripe/docs_truth_test.exs` verification shape
- same need to improve guidance without turning docs into a second canonical tree

Reuse from Phase 44:

- frontmatter shape with `must_haves`, `artifacts`, and `key_links`
- 2-task structure per plan
- grep-plus-ExUnit verification commands
- trust-boundary threat model focused on false confidence, discovery drift, and publication truth

### Secondary analog: Phase 35 two-plan split discipline

- `.planning/phases/35-mandate-setupattempt/35-01-PLAN.md`
- `.planning/phases/35-mandate-setupattempt/35-02-PLAN.md`

Why it helps:

- the phase split is clear: first establish one major deliverable, then follow with the second major deliverable while reusing the same structure
- Plan 02 can depend on Plan 01 when both plans touch shared routing and test files

## Recommended Phase 45 Split

### `45-01-PLAN.md`

Ownership:

- new flagship guide for Checkout signup plus portal follow-through
- shared discovery wiring for that guide
- docs-truth protection for that guide

Likely files:

- `guides/checkout-signup-and-portal.md`
- `guides/recipes.md`
- `guides/user-flows-and-jtbd.md`
- `guides/checkout.md`
- `guides/subscriptions.md`
- `guides/customer-portal.md`
- `guides/webhooks.md`
- `mix.exs`
- `test/lattice_stripe/docs_truth_test.exs`

Best task split:

1. draft the flagship guide itself
2. wire discovery, cross-links, publication, and regression assertions

### `45-02-PLAN.md`

Ownership:

- new flagship guide for metering runtime plus reconciliation
- shared discovery wiring for that guide
- docs-truth protection for that guide

Likely files:

- `guides/metering-runtime-and-reconciliation.md`
- `guides/recipes.md`
- `guides/user-flows-and-jtbd.md`
- `guides/metering.md`
- `guides/webhooks.md`
- `guides/testing.md`
- `guides/error-handling.md`
- `mix.exs`
- `test/lattice_stripe/docs_truth_test.exs`

Best task split:

1. draft the runtime-first metering flagship guide
2. wire discovery, cross-links, publication, and regression assertions

## File-Level Reuse Guidance

### New guide-file pattern

Use the repo's existing guide style:

- strong top-level framing
- one recommended path
- concise Elixir examples
- explicit "Read next" sections
- short inline truth notes near the action

Closest content analogs:

- `guides/recipes.md` for compact workflow framing
- `guides/customer-portal.md` for security/caveat tone
- `guides/metering.md` for runtime idempotency/reconciliation detail
- `guides/user-flows-and-jtbd.md` for the "accepted now vs became true later" wording pattern

### Shared routing-page pattern

When touching `guides/recipes.md` and `guides/user-flows-and-jtbd.md`:

- keep them as routing layers, not full duplicate walkthroughs
- add a short pointer to the new flagship guide
- keep canonical guides listed nearby so the flagship layer does not feel exclusive

### Publication/test pattern

Reuse the exact approach from Phase 44:

- `mix.exs` should continue to expose guide roles deliberately
- `test/lattice_stripe/docs_truth_test.exs` should assert filenames, group membership, and route anchors
- prefer link/anchor assertions over long prose snapshots

## Verification Patterns To Reuse

### Grep-backed docs checks

Use `rg` for:

- flagship guide filenames and references across `guides/` and `mix.exs`
- core truth anchors like `webhooks`, `redirect`, `payment_method_update`, `subscription_cancel`, `identifier`, `MeterEventAdjustment`

### Targeted ExUnit docs-truth run

Use:

```bash
mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors
```

This is the existing low-cost, high-signal regression net for guide publication and discovery drift.

## Planner Guardrails

- Keep both plans docs-only; do not invent runtime code changes.
- Keep Plan 02 dependent on Plan 01 because both will likely touch `mix.exs`, `guides/recipes.md`, `guides/user-flows-and-jtbd.md`, and `docs_truth_test.exs`.
- Treat new flagship guides as first-class published docs, not buried support notes.
- Encode the specific footguns in `must_haves.truths` and `threat_model`, because they are the easiest places for a docs phase to overclaim.

---
*Recommended analog set: 44-01, 44-02, 35-01, 35-02*
