# Phase 29: Changeset-Style Param Builders - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Developers building complex nested Stripe params for subscription schedules and billing portal flows have an optional fluent builder API that prevents typos in deeply nested keys and provides compile-assisted documentation — without replacing the existing map-based API. Scoped to `SubscriptionSchedule` phase params and `BillingPortal.Session` FlowData params.

</domain>

<decisions>
## Implementation Decisions

### Builder API Style

- **D-01:** Use pipe-based changeset style (`|>` chains) with data-first functions. Start with `new/0`, chain setter functions, end with `build/1` returning a plain map. This is the idiomatic Elixir pattern (Ecto, Ash, Req) and matches the phase name "Changeset-Style."

### Output Format

- **D-02:** `build/1` returns a plain string-keyed `map()` — not `{:ok, map}`, not a struct. The output is passed directly to existing resource functions (`SubscriptionSchedule.create/3`, `BillingPortal.Session.create/3`). No validation in builders — existing guards (`check_flow_data!/1`, `check_proration_required/2`) handle validation at the resource layer.

### Module Structure

- **D-03:** Two primary builder modules in `lib/lattice_stripe/builders/`:
  - `LatticeStripe.Builders.SubscriptionSchedule` — schedule creation params + phase construction helpers
  - `LatticeStripe.Builders.BillingPortal` — FlowData construction for portal session creation
  Phase/item sub-builders are nested functions or inner-module helpers within the parent, not a full sub-module hierarchy. Keeps the builder layer thin and simple.

### Scope

- **D-04:** "BillingPortal flows" means FlowData only — not Configuration params. FlowData is the deeply nested, error-prone shape that benefits from builder ergonomics. Configuration params (`business_profile`, `features`) are simpler maps that don't need builder assistance.

### Claude's Discretion

- Exact function names for setter functions (e.g., `customer/2` vs `set_customer/2`)
- Whether `add_phase/2` accepts a sub-builder struct or a map (recommend sub-builder for consistency)
- Internal representation — opaque struct or map accumulator during the chain
- Whether to provide convenience constructors like `Phase.with_price/2` for common patterns
- `@moduledoc` and `@doc` wording for the "optional" messaging
- Test strategy — unit tests asserting `build/1` produces correct map shapes

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### SubscriptionSchedule Param Shapes
- `lib/lattice_stripe/subscription_schedule.ex` — Target resource module; `create/3` and `update/3` param shapes
- `lib/lattice_stripe/subscription_schedule/phase.ex` — Phase struct fields define what builder functions to expose (items, add_invoice_items, iterations, proration_behavior, etc.)
- `lib/lattice_stripe/subscription_schedule/phase_item.ex` — PhaseItem fields for item construction helpers
- `lib/lattice_stripe/subscription_schedule/add_invoice_item.ex` — AddInvoiceItem fields

### BillingPortal FlowData Shapes
- `lib/lattice_stripe/billing_portal/session.ex` — Target resource; `create/3` accepts `"flow_data"` key
- `lib/lattice_stripe/billing_portal/session/flow_data.ex` — FlowData type dispatch (subscription_cancel, subscription_update, subscription_update_confirm, payment_method_update)
- `lib/lattice_stripe/billing_portal/session/flow_data/subscription_cancel.ex` — Required: subscription; optional: retention
- `lib/lattice_stripe/billing_portal/session/flow_data/subscription_update.ex` — Required: subscription
- `lib/lattice_stripe/billing_portal/session/flow_data/subscription_update_confirm.ex` — Required: subscription + items
- `lib/lattice_stripe/billing_portal/session/flow_data/after_completion.ex` — AfterCompletion sub-object

### Existing Guard Patterns
- `lib/lattice_stripe/billing_portal/guards.ex` — `check_flow_data!/1` validates flow shape pre-network; builders produce maps that pass these guards
- `lib/lattice_stripe/billing/guards.ex` — `check_proration_required/2` for schedule updates

### ExDoc Grouping
- `mix.exs` lines 51-170 — Add new "Param Builders" group for builder modules

### Conventions
- String-keyed params throughout SDK (Stripe wire format) — builders must output string keys
- `@known_fields ~w[...]` pattern for field whitelists

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SubscriptionSchedule.Phase` struct — field list defines builder setter functions
- `FlowData` polymorphic dispatch — `type` field determines required nested params
- `BillingPortal.Guards.check_flow_data!/1` — validates builder output correctness
- ExDoc group infrastructure — add "Param Builders" group to mix.exs

### Established Patterns
- String-keyed maps for all Stripe params
- `Map.split/2` for from_map/1 (builders go the other direction — map construction)
- No existing builder/fluent pattern — Phase 29 introduces this new idiom
- `@moduledoc` with usage examples is standard across all modules

### Integration Points
- `SubscriptionSchedule.create/3` — accepts builder `build/1` output directly
- `BillingPortal.Session.create/3` — accepts builder output in `"flow_data"` key
- `mix.exs` ExDoc groups — new "Param Builders" group
- No changes to existing resource modules required — builders are additive only

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches following existing patterns.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 29-changeset-style-param-builders*
*Context gathered: 2026-04-16*
