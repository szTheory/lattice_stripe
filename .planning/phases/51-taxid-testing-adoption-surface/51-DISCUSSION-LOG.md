# Phase 51: TaxId, Testing & Adoption Surface - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 51-TaxId, Testing & Adoption Surface
**Areas discussed:** TaxId dual-path API, guides/tax.md, Testing fixtures, docs-truth grep, ObjectTypes expand proof, TaxId struct typing

**Mode:** Research synthesis with parallel subagent analysis; user requested one-shot coherent recommendations across all six gray areas.

---

## TaxId dual-path API shape

| Option | Description | Selected |
|--------|-------------|----------|
| Positional `customer_id` after `client` | `create(client, cus_id, params, opts)` for nested path | ✓ |
| `customer:` in opts | Single arity; path hidden in keywords | |
| Two modules (`TaxId` + `Customer.TaxId`) | Duplicate surface | |
| Params-only routing (stripity_stripe style) | Top-level path unsupported | |

**User's choice:** Positional parent ID routing (locked STATE.md + research recommendation D-01)

**Notes:** Full CRUDL minus update; `stream!/3` and `stream!/4`; bang arities mirror non-bang; module-surface negative tests; moduledoc dual-path table first. Precedent: `LoginLink.create/4`. Rejects opts-based routing (collides with `stripe_account`, `idempotency_key`).

---

## `guides/tax.md` shape & discovery

| Option | Description | Selected |
|--------|-------------|----------|
| Canonical Guides ~280–350 lines | Domain workflow + configure-once + calc→txn spine | ✓ |
| Operations & DX ~150 lines | Trust-rail tier | |
| Flagship Recipe | Accrue-scale orchestration risk | |
| New ExDoc Tax group | Premature for one guide | |
| calc→txn only (no settings chapter) | Under-scoped vs Phase 50 deferrals | |

**User's choice:** Canonical Guide with Phase 48 discovery wiring pattern (D-02)

**Notes:** ExDoc `Canonical Guides` group; README route + JTBD Start Here + payments reverse-link; no new JTBD Job 8; Accrue fence once in guide opening.

---

## Testing fixture API

| Option | Description | Selected |
|--------|-------------|----------|
| Two layers: `Fixtures.Tax*_json/1` + `Testing.tax_*/1` | v1.3 CreditNote pattern | ✓ |
| Fixtures only | Adopters call `from_map/1` manually | |
| Top-level only (hide wire maps) | Breaks Mox canonical shape | |
| Include Settings/Registration public fixtures | DX-02 scope creep | |

**User's choice:** Promote calc/txn from test/support; add TaxId; `tax_` prefix; flat `Fixtures.TaxCalculation` modules (D-03)

**Notes:** Wire map canonical per `guides/testing.md`. Internal-only settings/registration fixtures remain in test/support.

---

## Docs-truth grep scope

| Option | Description | Selected |
|--------|-------------|----------|
| Centralize in `docs_truth_test.exs` (3A+3C+3D+3E) | Phase 48 contract | ✓ |
| Keep per-module grep in `transaction_test.exs` | Duplication risk | |
| Full markdown paragraph locks | Brittle | |

**User's choice:** Centralize; migrate Phase 49 partial grep; semantic anchors per module (D-04)

**Notes:** Skip 3B install canary unless staggered `~> 1.6` in guide only. Replace Phase 51 placeholder greps with `guides/tax.md` link greps after guide ships.

---

## ObjectTypes expand proof

| Option | Description | Selected |
|--------|-------------|----------|
| Hybrid: dispatch in `object_types_test.exs` + new `tax_object_types_expand_test.exs` | Separates registry vs parent wiring | ✓ |
| All in `object_types_test.exs` | Mixes concerns | |
| Type `Customer.tax_ids` expand | Conflicts Phase 49 D-01 | |

**User's choice:** Add `tax_id` registry; five-type `fetch_module`; expand customer/product/tax_id scenarios (D-05)

**Notes:** Event `data` and `customer_details.tax_ids` explicitly out of scope. Optional `fetch_related_object` test at planner discretion.

---

## TaxId struct typing

| Option | Description | Selected |
|--------|-------------|----------|
| `%TaxId{}` + `Verification` + `Owner` submodules; string `type` | Bounded stripe-ruby shape without codegen depth | ✓ |
| Flat struct; verification as map | Loses status atomization | |
| Atomize 100+ `type` values | Maintenance churn | |
| Struct `CustomerDetails.tax_ids` elements | Violates Phase 49 D-01 | |

**User's choice:** D-06 package with Inspect redact on `value`

**Notes:** Moduledoc links to Stripe for formats; no country matrix inline.

---

## Claude's Discretion

- Exact `@known_fields` after Stripe verification
- JTBD job number for tax discovery route
- Optional `fetch_related_object` Mox test
- Guide section ordering within D-02 outline
- ExDoc `groups_for_modules` Tax sidebar

## Deferred Ideas

- Customer `tax_ids` expand typing
- Event `data` typed as Tax objects
- Public Settings/Registration Testing fixtures
- Tax Code lookup (v1.7)
- Request param builders
- Chained settings→registration→calc integration spec
