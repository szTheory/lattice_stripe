# Phase 23: BillingPortal.Configuration CRUDL - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 23-billingportal-configuration-crudl
**Areas discussed:** Nesting boundary, Configuration lifecycle, Session.configuration field upgrade, Sub-struct naming

---

## Nesting Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Features + all 5 feature sub-structs | 6/6 budget, full dot-access, matches official SDKs | |
| Features + 3 complex sub-structs | 5/6 budget, mixed access patterns | |
| Features + 4 sub-structs (skip InvoiceHistory) | 6/6 budget, types where it matters, skips trivial 1-field struct | ✓ |
| Features only, all feature areas as maps | 1/6 budget, map access throughout | |

**User's choice:** Features + 4 typed sub-structs (skip InvoiceHistory). BusinessProfile + LoginPage as maps.
**Notes:** Research showed official Stripe SDKs type everything but auto-generate from OpenAPI. LatticeStripe maintains by hand, so budget matters. InvoiceHistory has only `enabled` — not worth a module. 4 advisors researched ecosystem patterns (stripe-ruby, stripe-python, Elixir libs).

---

## Configuration Lifecycle

| Option | Description | Selected |
|--------|-------------|----------|
| update-only, no helpers | Consistent with official SDKs, no new API surface | |
| Add deactivate/3 + activate/3 | More discoverable but breaks "one function per endpoint" convention | |
| update-only + @moduledoc guidance | Zero bloat, docs explain soft-delete pattern and is_default constraint | ✓ |

**User's choice:** update-only + @moduledoc guidance
**Notes:** Every existing convenience method maps 1:1 to a distinct Stripe endpoint. Adding deactivate would be the first exception.

---

## Session.configuration Field Upgrade

| Option | Description | Selected |
|--------|-------------|----------|
| Upgrade in Phase 23 | Consistency, natural moment, additive change | ✓ |
| Defer to later phase | Zero risk but creates outlier | |

**User's choice:** Upgrade in Phase 23 alongside Configuration creation
**Notes:** Phase 22 just established expand guards across the entire SDK. Stripity-stripe already types this as `binary() | Configuration.t()`. Change is backward-compatible.

---

## Sub-struct Naming

| Option | Description | Selected |
|--------|-------------|----------|
| Configuration.Features.SubscriptionCancel | Mirrors Stripe hierarchy, consistent with FlowData precedent | ✓ |
| Configuration.SubscriptionCancel (flat) | Shorter paths but breaks Stripe hierarchy mapping | |
| Configuration.FeatureConfig (renamed) | More descriptive but diverges from field name convention | |

**User's choice:** Mirror Stripe field names under Configuration.Features.X
**Notes:** Existing convention mirrors Stripe JSON field names → PascalCase. Consistent with FlowData.SubscriptionCancel, Invoice.AutomaticTax.

## Claude's Discretion

- Exact fields per sub-struct (verify against Stripe API docs)
- Test fixture structure, @moduledoc wording, ~w[] convention

## Deferred Ideas

None — discussion stayed within phase scope.
