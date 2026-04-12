# Phase 16: Subscription Schedules - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in 16-CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 16-subscription-schedules
**Areas discussed:** Nested struct depth & reuse, Action verbs (cancel/release), Creation ergonomics, Proration guard + plan structure
**Mode:** Research-first one-shot — user requested "research all four using subagents, give your rec one shot"

---

## Research Method

Four `gsd-advisor-researcher` agents spawned in parallel, one per gray area. Each researched reference SDKs (stripity_stripe, Striped, stripe-ruby/node/go/java/python), Elixir ecosystem conventions (Ecto, Phoenix, NimbleOptions), Stripe API docs, and Phase 14/15 local precedent. Each returned a structured comparison table + rationale. Claude synthesized into one coherent recommendation and the user locked all 5 decisions in one pass.

---

## Area 1: Nested struct depth & SubscriptionItem reuse

### Sub-decision A — Depth/promotion strategy

| Option | Description | Selected |
|--------|-------------|----------|
| A1. Minimal (only `phases[]`) | 1 new struct; everything nested stays map | |
| A2. Medium (Phase reused for default_settings, CurrentPhase, PhaseItem, AddInvoiceItem, reuse AutomaticTax) | 4 new structs + 1 reuse; matches Phase 15's "5 promoted fields" budget | ✓ |
| A3. Deep (A2 + invoice_settings, transfer_data, billing_thresholds) | 8-12 new modules; promotion creep | |

### Sub-decision B — `phases[].items[]` modeling

| Option | Description | Selected |
|--------|-------------|----------|
| B1. Reuse `%SubscriptionItem{}` | Zero new modules but half-nil struct → `nil.id` bugs | |
| B2. New `%SubscriptionSchedule.PhaseItem{}` | Honors template-vs-instance distinction; matches stripe-go | ✓ |
| B3. Leave as plain map | Inconsistent with outer Phase struct being typed | |

**Key reasoning:** Phase items are templates (no `id`, has `price_data`) that Stripe materializes into live SubscriptionItems when phases activate. Shape divergence is load-bearing. Stripity_stripe's "all maps" is a codegen artifact, not a deliberate choice.

**User's choice:** A2 + B2 (locked via "Lock all 5").

---

## Area 2: Action verbs (cancel/release)

### Sub-decision A — `cancel` signature

| Option | Description | Selected |
|--------|-------------|----------|
| A1. `cancel(client, id, params \\ %{}, opts \\ [])` | Mirrors Phase 15 Subscription.cancel/4; matches stripity_stripe + Striped | ✓ |
| A2. `cancel(client, id, opts \\ [])` opts-only | Muddies Stripe-params vs transport-opts boundary | |
| A3. `cancel(client, id, invoice_now, prorate, opts)` positional | Elixir anti-pattern | |
| A4. Keyword mixing | Same boundary problem | |

### Sub-decision B — `release` signature

| Option | Description | Selected |
|--------|-------------|----------|
| B1. `release(client, id, params \\ %{}, opts \\ [])` | Symmetric with cancel/4 | ✓ |
| B2. `release(client, id, opts \\ [])` | Asymmetric for no real gain | |
| B3. Positional bool | Same anti-pattern | |

### Sub-decision C — Ancillary

- Pre-validate releasable state? **No.** TOCTOU; Phase 15 D5 "no fake ergonomics."
- Bang variants? **Yes**, `cancel!/4` and `release!/4` — mandatory for consistency.
- Document `release` destructiveness? **Yes**, in `@moduledoc` + `@doc` prose, explicit contrast with `cancel/4`.

**User's choice:** A1 + B1 + all of C (locked).

---

## Area 3: Creation ergonomics

| Option | Description | Selected |
|--------|-------------|----------|
| 1. Single `create/3` pass-through | Matches Phase 15 + every reference SDK; zero inconsistency debt | ✓ |
| 2. Single `create/3` + client-side validation | Ecto-shaped solution to an HTTP SDK problem; drift risk | |
| 3. `create/3` + `create_from_subscription/3` | Unmisusable but breaks SDK-wide single-create invariant | |

**Key finding:** stripity_stripe, stripe-ruby, stripe-node, stripe-go, stripe-java, stripe-python — every reference SDK uses single pass-through for SubscriptionSchedule create, despite its dual-mode quirk. Splitting for one resource creates permanent inconsistency debt.

**User's choice:** Option 1 (locked).

---

## Area 4: Proration guard depth + plan structure

### Sub-decision A — Guard depth

**Critical research finding:** Stripe does NOT accept `proration_behavior` at `phases[].items[]`. Only two legal paths exist: top-level and `phases[].proration_behavior`. Verified against the official Stripe API reference. This collapsed the decision.

| Option | Description | Selected |
|--------|-------------|----------|
| 1. No extension (top-level only) | Would miss legitimate per-phase intent; false-positive risk | |
| 2. Walk `phases[].proration_behavior` | Mirrors Phase 15 `items_has?/1` pattern; covers 100% of legal shapes | ✓ |
| 3. Walk `phases[].items[].proration_behavior` | Accepts illegal-per-Stripe shapes; encourages user errors | |
| 4. Middle ground | Subsumed by Option 2 given Stripe's actual surface | |

### Sub-decision B — Plan structure

| Option | Description | Selected |
|--------|-------------|----------|
| 1. 2 plans (struct+CRUD+actions+guard / integration+guide) | First plan would balloon past Phase 15's 569-LOC ceiling | |
| 2. 3 plans action-aligned (struct+CRUD / actions+guard / integration+guide) | Mirrors Phase 15 proven rhythm; cohesive concerns per plan | ✓ |
| 3. 3 plans layer-aligned (struct-only / CRUD+actions+guard / integration) | First plan becomes a stub with nothing to verify | |

**User's choice:** A-Option-2 + B-Option-2 (locked).

---

## Claude's Discretion

Areas where implementation details are left to the planner/executor:
- Exact `@known_fields` list on each new struct
- Test organization within each `*_test.exs`
- `guides/subscriptions.md` Schedules section placement
- Fixture JSON shape for `test/support/fixtures/subscription_schedule.ex`
- `SubscriptionSchedule.Phase` `@moduledoc` wording for dual usage

## Deferred Ideas

See `<deferred>` section in 16-CONTEXT.md. Notable rejects:
- `search` endpoint (Stripe doesn't expose)
- `create_from_subscription/3` helper
- Client-side creation-mode validation
- Client-side `cancel`/`release` state pre-validation
- Deep typed structs for `invoice_settings`, `transfer_data`, `billing_thresholds`
- Resource-specific telemetry events
