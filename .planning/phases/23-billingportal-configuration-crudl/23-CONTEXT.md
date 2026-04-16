# Phase 23: BillingPortal.Configuration CRUDL - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Developers can create, retrieve, update, and list Stripe customer portal configurations — controlling branding, feature flags, and business info — using typed structs. Level 1+2 typed sub-structs, Level 3+ in `extra`. No DELETE endpoint (Stripe deactivates, not deletes). Includes upgrading Session.configuration to expandable.

</domain>

<decisions>
## Implementation Decisions

### D-01: Nesting Boundary — Features + 4 Typed Feature Sub-Structs

Type the Features object and 4 of the 5 feature sub-objects as dedicated modules. InvoiceHistory (single `enabled` boolean) stays as `map() | nil` inside Features — not worth a module for 1 field.

**Module allocation (6 total):**
1. `LatticeStripe.BillingPortal.Configuration` — top-level resource
2. `LatticeStripe.BillingPortal.Configuration.Features` — features container
3. `LatticeStripe.BillingPortal.Configuration.Features.SubscriptionCancel` — mode, proration_behavior, cancellation_reason (Level 3+ as maps)
4. `LatticeStripe.BillingPortal.Configuration.Features.SubscriptionUpdate` — products, schedule_at_period_end (Level 3+ as maps)
5. `LatticeStripe.BillingPortal.Configuration.Features.CustomerUpdate` — allowed_updates, enabled
6. `LatticeStripe.BillingPortal.Configuration.Features.PaymentMethodUpdate` — enabled

**Not typed (maps in parent struct):**
- `business_profile` — 3 scalar fields (headline, privacy_policy_url, terms_of_service_url), simple enough for map access
- `login_page` — 2 fields (enabled, url), trivial
- `invoice_history` — 1 field (enabled), single boolean not worth a module
- Level 3+ sub-objects inside feature sub-structs (cancellation_reason, products, adjustable_quantity) — stored in parent's `extra` or as `map() | nil` fields

**Why:** Official Stripe SDKs type all levels. FlowData precedent (parent + N typed children) maps directly. BusinessProfile/LoginPage are too shallow to justify modules. This spends the 6-module budget where developers actually pattern-match — on feature configuration.

### D-02: Configuration Lifecycle — Update-Only + @moduledoc Guidance

No `deactivate/3` or `activate/3` convenience helpers. Developers use `update(client, id, %{"active" => false})`.

**Why:** Every existing convenience method in LatticeStripe maps 1:1 to a distinct Stripe endpoint. Adding deactivate/activate as thin wrappers around `update` would break that convention and mislead devs into thinking a `/deactivate` endpoint exists. All official Stripe SDKs (Ruby, Python, Node) use generic update for this. The `@moduledoc` should explain:
- Configurations cannot be deleted, only deactivated via `update(active: false)`
- A configuration cannot be deactivated if it's the default (`is_default: true`)
- Stripe returns an error if you try — no client-side guard needed

### D-03: Session.configuration Upgrade — Expand in Phase 23

Upgrade `BillingPortal.Session.configuration` from `String.t() | nil` to `Configuration.t() | String.t() | nil` with an expand guard via `ObjectTypes.maybe_deserialize/1`.

**Changes required:**
- Add `"billing_portal.configuration" => LatticeStripe.BillingPortal.Configuration` to ObjectTypes `@object_map`
- Add `alias LatticeStripe.ObjectTypes` to Session (if not already present)
- Add expand guard on `configuration` field in Session's `from_map/1`
- Update Session's `@type t` for configuration field
- Add expand test to session_test.exs

**Why:** Phase 22 established expand guards across the entire SDK. Leaving Session.configuration as the sole string-only outlier creates inconsistency. The change is additive (typespec widens), backward-compatible, and stripity-stripe already types this as `binary() | Configuration.t()`. Phase 23 is the natural moment.

### D-04: Sub-Struct Naming — Mirror Stripe Field Names

Follow existing project convention: sub-struct module name mirrors the Stripe JSON field name, converted to PascalCase.

- `features` → `Configuration.Features`
- `subscription_cancel` → `Configuration.Features.SubscriptionCancel`
- `subscription_update` → `Configuration.Features.SubscriptionUpdate`
- `customer_update` → `Configuration.Features.CustomerUpdate`
- `payment_method_update` → `Configuration.Features.PaymentMethodUpdate`

**Why:** Consistent with existing patterns (FlowData.SubscriptionCancel, Invoice.AutomaticTax, Subscription.CancellationDetails). Matches Stripe's own hierarchy. Developers can map between Stripe docs and LatticeStripe modules without guessing.

### Claude's Discretion

- Exact fields in each sub-struct (researcher should verify against current Stripe API docs)
- Whether `@known_fields` uses `~w[...]` or `~w(...)` (follow existing convention: `~w[...]`)
- Test fixture structure and assertion patterns
- `@moduledoc` wording for lifecycle guidance
- Whether to use `Map.split/2` or `Map.drop` in sub-struct from_map/1 (follow Phase 22 convention: `Map.split/2`)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### BillingPortal Namespace Patterns
- `lib/lattice_stripe/billing_portal/session.ex` — Reference for namespace patterns, defstruct, from_map/1, @type t, Inspect masking
- `lib/lattice_stripe/billing_portal/guards.ex` — Pre-flight validation guards
- `lib/lattice_stripe/billing_portal/session/flow_data.ex` — Parent + N typed children dispatch pattern (directly applicable to Features)

### CRUDL Operation Patterns
- `lib/lattice_stripe/customer.ex` — Full CRUDL + list + stream! + bang variants reference
- `lib/lattice_stripe/payment_intent.ex` — Custom operations reference (confirm/capture/cancel)

### Nested Struct Patterns
- `lib/lattice_stripe/invoice.ex` — Level 2 sub-structs (AutomaticTax, StatusTransitions) + Level 3+ as maps
- `lib/lattice_stripe/account.ex` — Multiple nested delegates in from_map/1 (Company, Settings)
- `lib/lattice_stripe/subscription/cancellation_details.ex` — Level 2 nested struct with PII masking

### Expand & ObjectTypes
- `lib/lattice_stripe/object_types.ex` — Registry where `"billing_portal.configuration"` must be added
- Phase 22 CONTEXT.md decisions (expand guard pattern, atomization pattern)

### ExDoc Grouping
- `mix.exs` lines 48-157 — "Customer Portal" group where Configuration modules must be added

### Project Architecture
- `.planning/research/PITFALLS.md` — Pitfall 8: nesting depth rules, 6-module cap
- `.planning/research/ARCHITECTURE.md` — Phase 23 architecture spec

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `BillingPortal.Session` module — namespace pattern, from_map/1 structure, Inspect impl
- `BillingPortal.Session.FlowData` — parent + typed children dispatch pattern (reuse for Features)
- `Customer` module — full CRUDL function signatures and test patterns
- `ObjectTypes.maybe_deserialize/1` — expand guard dispatch (Phase 22)
- `Resource.unwrap_singular/2`, `Resource.unwrap_list/2`, `Resource.unwrap_bang!/1` — result handling

### Established Patterns
- `Map.split/2` for from_map/1 (Phase 22 standard)
- `@known_fields ~w[...]` string sigil
- `defstruct` with `extra: %{}` for forward-compatibility
- Union typespecs for expandable fields: `Module.t() | String.t() | nil`
- Private `atomize_status/1` whitelists for finite status fields (if applicable)

### Integration Points
- `ObjectTypes.@object_map` — register `"billing_portal.configuration"`
- `mix.exs` ExDoc groups — add to "Customer Portal" group
- `BillingPortal.Session.from_map/1` — add expand guard on `configuration` field
- Session v1.1 `@moduledoc` comment — remove "planned for v1.2+" note, replace with reference to Configuration module

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

*Phase: 23-billingportal-configuration-crudl*
*Context gathered: 2026-04-16*
