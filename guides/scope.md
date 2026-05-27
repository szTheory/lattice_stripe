# LatticeStripe v1.x Scope

LatticeStripe is a production-grade HTTP client SDK for the Stripe API. As of **1.7.0**,
the **v1.x** line targets mainstream SaaS integrations: payments, billing, usage
metering, Connect, tax on custom flows, webhooks, and operator diagnostics.

## Intended audience

This SDK fits teams building mainstream SaaS products that need Stripe coverage that is
correct, documented, and unsurprising in Elixir — without carrying every specialist
Stripe product family in the typed surface.

## What v1.x includes

Positive coverage clusters shipped and documented in v1.x:

- **Payments** — PaymentIntents, Charges (list/search/update/capture), Customers, PaymentMethods
- **Billing** — Subscriptions, Invoices, Quotes, Checkout, Customer Portal, Credit Notes
- **Metering** — Usage records and billing-meter reconciliation paths
- **Connect** — Accounts, transfers, and money-movement primitives for platforms
- **Tax core** — Calculations, Transactions, Settings, Registrations, Tax IDs (v1.6)
- **Webhooks** — Signature verification, thin events, fetch-after-verify helpers (v1.5)
- **Operator guides** — Production checklist, event debugging, testing, error handling

For job-to-primitive routing, see [User Flows & JTBD](user-flows-and-jtbd.md).

## Deferred by design

v1.x is in **maintenance mode** for scope breadth: new resource families ship only on
**adopter pull** (real production need), not speculative completeness.

- **Specialist Stripe families:** Identity; Treasury; Issuing; Terminal; Financial
  Connections; Climate; Sigma; Reporting — specialist products with narrow adopter
  pull relative to mainstream SaaS billing.
- **Tax narrow follow-ups:** Tax Code lookup (`/v1/tax_codes`); Tax Transaction list
  (if Stripe adds the endpoint) — lookup/list gaps only, not missing Tax core.

## Tax note

v1.6 shipped Tax **core** (Calculation, Transaction, Settings, Registration, TaxId).
The deferred items above are narrow follow-ups. Tax is not incomplete for mainstream
custom-flow calculate → record → reverse integrations.

## Escape hatch

Unwrapped Stripe endpoints remain available via `LatticeStripe.Client.request/2`.
See [Extending LatticeStripe](extending-lattice-stripe.md) for patterns that stay
compatible with the SDK error and telemetry model.

## Accrue boundary

LatticeStripe stays lower-level than [Accrue](https://github.com/sztheory/accrue).
Filing, returns preparation, and nexus monitoring belong in your application or
downstream billing layers — not in this HTTP client.

## Maintenance and adopter pull

After **1.7.0**, v1.x work is **maintenance and adoption-driven**: bugfixes, Stripe API
drift, and narrow additions when real adopters need them. There is no planned new
resource-family breadth in v1.x absent fresh adopter pull.

## Requesting coverage

Open a GitHub issue to describe your use case. That helps prioritize adopter pull;
it is not a roadmap commitment to ship a typed module.
