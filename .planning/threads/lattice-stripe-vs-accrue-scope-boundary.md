# LatticeStripe vs Accrue Scope Boundary

Updated: 2026-05-24

## Why this thread exists

LatticeStripe is approaching "done enough" as a Stripe SDK. The main strategic risk is no longer missing foundation; it is accidentally rebuilding higher-level billing-product behavior that already belongs in `~/projects/accrue`.

Use this thread during milestone research, roadmap updates, and GSD planning passes.

## LatticeStripe owns

- Stripe-shaped resource coverage and typed structs
- Direct endpoint verbs and low-level ergonomics
- Transport, upload/download, retries, idempotency, pagination, expand deserialization
- Webhook verification primitives
- Telemetry, testing helpers, and SDK-level guides

## Accrue owns

- App-facing billing facade and business workflows
- Subscription/business-policy orchestration across multiple resources
- Entitlements and access gating
- Dunning journeys and recovery policy
- Admin/operator/customer product surfaces
- Provider-honest billing-engine behavior beyond direct Stripe wrappers

## Decision rule

If the work maps closely to one Stripe resource family or endpoint surface, it is probably LatticeStripe scope.

If the work coordinates multiple resources into app-owned billing behavior, lifecycle policy, recovery policy, entitlement checks, or operator UX, it is probably Accrue scope.

If a candidate would make LatticeStripe feel like a second Cashier/Pay analogue, reject it here and route it to Accrue.

## Current implications for v1.3

- `Dispute` fits LatticeStripe cleanly: direct Stripe API coverage, typed evidence structs, explicit low-level verbs.
- `CreditNote` fits if kept to CRUDL/preview/void/line-item access only.
- `Quote` fits if kept to resource coverage, verbs, line items, and PDF download only.
- `Mandate` and `SetupAttempt` fit as read-only Stripe diagnostics.
- Public docs may teach primitive usage and bounded recipes, but should not turn into the canonical higher-level SaaS billing architecture package. Point up to Accrue when the story becomes workflow-owned.

## Standing reminder for future GSD work

Before approving a milestone wedge, ask:

1. Does this remove a common need for raw HTTP against Stripe?
2. Is the value primarily direct Stripe API coverage rather than billing-engine orchestration?
3. Would shipping this here create overlap with Accrue's public value proposition?

If question 3 is "yes", stop and reconsider scope.
