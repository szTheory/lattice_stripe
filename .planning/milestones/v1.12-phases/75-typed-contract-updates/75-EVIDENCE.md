# Phase 75 Candidate Evidence Refresh

**Captured:** 2026-09-24
**Purpose:** Refresh the Phase 74 evidence gate before planning field work.

## Exact drift inventory

`mix lattice_stripe.check_drift` completed its task on 2026-09-24. It exited with status 1 because it found drift (the task's documented drift-found exit), not because Mix startup or the fetch failed. The report covered 31 modules, with 113 actionable additions, 154 spec-mismatch warnings, and 98 unmodeled resources. This remains a point-in-time, non-exhaustive report: only the exact additions below are used for candidate membership.

| Resource | Exact addition reported by the drift task | Inventory result |
|---|---|---|
| Invoice | `amount_paid_off_stripe` | Present |
| Refund | `customer`, `customer_account`, `payment_method` | Present |
| InvoiceItem | `frozen_fields` | Present |
| Dispute | `payment_method_details.card.network` | Not reported as an exact inventory path; ineligible |
| Invoice / Subscription | `payment_settings.payment_method_types` | Not reported as an exact inventory path; ineligible |

The drift command compares top-level `@known_fields` against Stripe's legacy v1 OpenAPI file. It does not establish exact nested-property membership. Therefore schema presence alone does not qualify the Dispute or payment-settings leads.

## Immutable GA OpenAPI evidence

Stripe OpenAPI commit `c8faccbde66b784ea916d3c28f5790d7a9c9aee2` is the immutable snapshot used for this review. Stripe's repository README identifies `latest/` as the recommended GA spec and `/openapi/` as the continuously updated legacy v1 GA spec; the repository commit records an update to both. The latter is the source path used by `LatticeStripe.Drift`.

| Snapshot file at commit `c8faccbde66b784ea916d3c28f5790d7a9c9aee2` | SHA-256 | Use |
|---|---|---|
| `openapi/spec3.json` | `6b4680299e7b7743811c41537e828b0eae363a11cea44441511013b55e52f7ad` | Legacy v1 GA spec used by the drift task |
| `latest/openapi.spec3.json` | `2c31317cdff103e4495b5b3501004d9ddc0af61f43b0ab819e2db392eef008f6` | Recommended unified v1/v2 GA spec cross-check |

Pinned raw source: `https://raw.githubusercontent.com/stripe/openapi/c8faccbde66b784ea916d3c28f5790d7a9c9aee2/{openapi/spec3.json,latest/openapi.spec3.json}`.

Exact JSON Pointer evidence in both GA files:

| Candidate | JSON Pointer | Schema facts relevant to decoding |
|---|---|---|
| `Invoice.amount_paid_off_stripe` | `/components/schemas/invoice/properties/amount_paid_off_stripe` | Optional integer property; no `nullable: true` annotation. Changelog minimum: `2026-05-27.dahlia`; API request response only per the versioned changelog. |
| `Refund.customer` | `/components/schemas/refund/properties/customer` | Nullable; string ID or `customer` / `deleted_customer` object. Changelog minimum: `2026-07-29.dahlia`; refund endpoints. |
| `Refund.customer_account` | `/components/schemas/refund/properties/customer_account` | Nullable string ID. Changelog minimum: `2026-07-29.dahlia`; refund endpoints. |
| `Refund.payment_method` | `/components/schemas/refund/properties/payment_method` | Nullable; string ID or `payment_method` object. Changelog minimum: `2026-07-29.dahlia`; refund endpoints. |
| `InvoiceItem.frozen_fields` | `/components/schemas/invoiceitem/properties/frozen_fields` | Array of strings; schema currently lists `discounts`, `pricing`, and `quantity`. Keep the consumer type open to future values. Changelog minimum: `2026-08-26.dahlia`. |

The exact inventory and immutable GA schema checks both pass for the Invoice, Refund, and InvoiceItem additions. This does not imply the package's default API pin (`2026-03-25.dahlia`) serves these later-version fields. Preserve the existing pin and state each minimum version and proven surface in public docs.

## Stable-version source and fixture provenance

The existing Phase 74 candidate ledger records Stripe's stable, versioned changelog sources and minimum API versions for each lead. The Invoice field supports reconciliation of off-Stripe invoice payments. The Refund fields support refund/customer/payment-method attribution. InvoiceItem frozen fields can explain update failures but are a separate, lower-priority adopter job.

Fixture provenance for planned tests: **schema-derived**, not captured from a live Stripe account. Derive each fixture case from the pinned GA snapshot above and record the property pointer, source commit, and minimum API version beside the fixture. Fixtures prove decoder behavior only; they must not be described as captured Stripe responses or as evidence of live endpoint/event availability.

## Planning recommendation

Plan one coherent reconciliation slice around `Invoice.amount_paid_off_stripe` and `Refund.customer`, `Refund.customer_account`, and `Refund.payment_method`. These reported fields address money reconciliation and refund attribution together. Treat `InvoiceItem.frozen_fields` as eligible but lower-priority and independent; do not add it to the reconciliation slice. Keep the default API version unchanged. Preserve `extra`, the current struct/decoder conventions, and open upstream values. Document only the surfaces established by the versioned changelogs.

Nested Dispute network and payment-settings Billie fields remain deferred because the current drift inventory did not report their exact nested paths, even though both are present in the pinned GA schema. Do not select them under D-01 without an exact-path inventory source.
