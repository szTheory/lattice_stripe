# LatticeStripe Scope

LatticeStripe is a production-grade HTTP client SDK for Stripe. The published **2.2** line
targets mainstream SaaS integrations: payments, billing, usage metering, Connect, tax on
custom flows, entitlement reconciliation, webhooks, and operator diagnostics.

## Intended audience

This SDK fits Elixir teams that want correct, documented, unsurprising Stripe primitives
without carrying every specialist Stripe product family in the typed surface. Applications
own product policy and durable workflow state; LatticeStripe owns the Stripe HTTP boundary,
typed resources, retries, errors, telemetry, and testing ergonomics.

## Current typed coverage

- **Payments** — PaymentIntents, Charges for reconciliation, Customers, PaymentMethods,
  SetupIntents, Refunds, Disputes, Files, Mandates, and SetupAttempts
- **Billing** — Subscriptions, Invoices, Quotes, Checkout, Customer Portal, Credit Notes,
  Products, Prices, coupons, and promotion codes
- **Metering** — meters, usage events and adjustments, summaries, and asynchronous error
  reconciliation
- **Entitlements** — feature catalog management, Product Feature attachments, active
  entitlement reads, and summary-webhook decoding for local access snapshots
- **Connect** — accounts, onboarding, transfers, payouts, balances, external accounts, and
  money-movement reconciliation primitives
- **Tax** — Calculations, Transactions, Settings, Registrations, and Tax IDs
- **Webhooks** — snapshot signature verification, thin events, fetch-after-verify helpers,
  and Phoenix-ready request-body handling
- **Operations and DX** — structured errors, retry evidence, telemetry, public fixtures,
  Test Clocks, production checks, and debugging guides

For job-to-primitive routing, see [User Flows & JTBD](user-flows-and-jtbd.md).

## Deferred by design

The 2.2 line is maintenance- and adoption-driven for breadth. New resource families ship
when an adopter brings a concrete production job, not to chase endpoint-count completeness.

- **Specialist Stripe families:** Identity; Treasury; Issuing; Terminal; Financial
  Connections; Climate; Sigma; Reporting. These are substantial products with narrower
  pull than the mainstream SaaS billing surface.
- **Tax narrow follow-ups:** Tax Code lookup (`/v1/tax_codes`) and Tax Transaction list if
  Stripe adds that endpoint. These are lookup/list gaps, not missing calculate → record →
  reverse coverage.
- **Per-request entitlement gates:** there is no `entitled?` helper and no authorization
  predicate that calls Stripe on the request path. Network authorization can fail open under
  partition. Reconcile entitlements from the summary webhook, gate against a local store,
  and fail closed on staleness; see [Entitlements](entitlements.md).
- **Usage reads grouped by a custom dimension:** on the generally available API,
  dimensions are write-only. Use one meter per dimension value or retain your own event
  store alongside Stripe; choose before designing the payload. See
  [The payload contract](metering.md#the-payload-contract).

## Escape hatch

Unwrapped Stripe endpoints remain available through `LatticeStripe.Client.request/2`. Use
the public request, error, and extension contracts rather than copying internal modules. See
[Extending LatticeStripe](extending-lattice-stripe.md).

## Product-policy boundary

LatticeStripe stays lower-level than application billing and tax policy. Filing, returns
preparation, nexus monitoring, pricing decisions, authorization policy, and durable workflow
state belong in your application or a downstream layer such as
[Accrue](https://github.com/sztheory/accrue). Keeping that boundary explicit lets the SDK
remain useful across different Elixir architectures.

## Maintenance and adopter pull

The published release is 2.2.1, a compatibility-preserving quality patch focused on
reliability, internal consistency, documentation truth, and release hygiene. It does not
expand the public resource surface. Further work is reactive and adopter-driven.

Beyond that patch, maintenance includes bug fixes, Stripe API drift, security and dependency
work, and narrow additions supported by a real adopter job. There is no promise of speculative
endpoint parity.

## Requesting coverage

Open a GitHub feature request with the job you need to complete, the Stripe resource or
endpoint involved, the input and output your application needs, and why
`LatticeStripe.Client.request/2` is insufficient. That evidence helps prioritize adopter pull;
an issue is not a roadmap commitment.

## See also

- [User Flows & JTBD](user-flows-and-jtbd.md) — choose a path by application job
- [API Stability](api_stability.md) — the 2.x compatibility contract
- [Extending LatticeStripe](extending-lattice-stripe.md) — supported extension points and
  unwrapped endpoints
- [Testing](testing.md) — fixtures, transport tests, stripe-mock, and Stripe test mode
