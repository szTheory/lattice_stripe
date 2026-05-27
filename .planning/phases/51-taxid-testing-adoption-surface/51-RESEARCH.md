# Phase 51: TaxId, Testing & Adoption Surface — Research

**Researched:** 2026-05-27  
**Confidence:** HIGH (CONTEXT locked; Stripe TaxId API dual-path verified; codebase precedents confirmed)

## RESEARCH COMPLETE

## Executive Summary

Phase 51 closes the v1.6 Tax family adoption surface: **dual-path `LatticeStripe.TaxId`**, public **Testing fixtures**, **five-type ObjectTypes expand proof**, canonical **`guides/tax.md`**, and **docs-truth** regression. Phases 49–50 delivered Calculation, Transaction, Settings, and Registration — this phase adds the fifth ObjectTypes entry (`tax_id`), promotes wire fixtures from `test/support`, and wires discovery.

**Highest risks:** Pitfall #5 (customer-only TaxId path — stripity_stripe footgun) and Pitfall #6 (expand returns raw maps). Prevention: per-path Mox URL assertions + `tax_object_types_expand_test.exs`.

## TaxId API (Verified)

Stripe exposes identical `tax_id` object on two URL families. **No update or search.**

### Top-level paths

| Verb | Method | Path | Arity |
|------|--------|------|-------|
| `create/3` | POST | `/v1/tax_ids` | `(client, params, opts \\ [])` |
| `retrieve/3` | GET | `/v1/tax_ids/:id` | `(client, id, opts \\ [])` |
| `list/3` | GET | `/v1/tax_ids` | `(client, params \\ %{}, opts \\ [])` |
| `delete/3` | DELETE | `/v1/tax_ids/:id` | `(client, id, opts \\ [])` |
| `stream!/3` | GET (paginated) | `/v1/tax_ids` | `(client, params \\ %{}, opts \\ [])` |

### Customer-nested paths

| Verb | Method | Path | Arity |
|------|--------|------|-------|
| `create/4` | POST | `/v1/customers/:customer_id/tax_ids` | `(client, customer_id, params, opts \\ [])` |
| `retrieve/4` | GET | `/v1/customers/:customer_id/tax_ids/:id` | `(client, customer_id, id, opts \\ [])` |
| `list/4` | GET | `/v1/customers/:customer_id/tax_ids` | `(client, customer_id, params \\ %{}, opts \\ [])` |
| `delete/4` | DELETE | `/v1/customers/:customer_id/tax_ids/:id` | `(client, customer_id, id, opts \\ [])` |
| `stream!/4` | GET (paginated) | `/v1/customers/:customer_id/tax_ids` | `(client, customer_id, params \\ %{}, opts \\ [])` |

**Routing rule:** When `customer_id` is the second positional argument after `client`, use nested paths; otherwise top-level. Match `LoginLink` path-scoped parent precedent (explicit arity = URL shape).

**Nested create:** Omit `"customer"` from request body on customer-nested create — Stripe infers from URL.

**Forbidden:** `update/*`, `search/*` (Coupon precedent — module surface negative tests).

**Wire object:** `tax_id` (top-level file `lib/lattice_stripe/tax_id.ex` per ARCHITECTURE.md Pattern 4).

### Struct typing (D-06)

| Module | Fields | Notes |
|--------|--------|-------|
| `TaxId` | `id`, `object`, `country`, `created`, `customer`, `customer_account`, `deleted`, `livemode`, `owner`, `type`, `value`, `verification` | `type` stays **string** (100+ enum values) |
| `TaxId.Verification` | `status`, `verified_address`, `verified_name` | Atomize `status`: `:pending`, `:verified`, `:unverified`, `:unavailable` |
| `TaxId.Owner` | `account`, `application`, `customer`, `customer_account`, `type` | Atomize `type`; expand refs via `ObjectTypes.maybe_deserialize/1` |
| Inspect | `value` field | Redact PII — `Account.Company` precedent |

## ObjectTypes (DX-01)

Existing (Phases 49–50):

```elixir
"tax.calculation" => LatticeStripe.Tax.Calculation,
"tax.transaction" => LatticeStripe.Tax.Transaction,
"tax.settings" => LatticeStripe.Tax.Settings,
"tax.registration" => LatticeStripe.Tax.Registration,
```

**Phase 51 adds:**

```elixir
"tax_id" => LatticeStripe.TaxId,
```

**Expand proof file:** `test/lattice_stripe/tax_object_types_expand_test.exs` — four scenarios from CONTEXT D-05. **Dispatch** stays in `object_types_test.exs` including `fetch_module/1` for all five types.

## Testing Fixtures (DX-02)

| Public module | Wire helpers | `LatticeStripe.Testing` wrapper |
|---------------|--------------|--------------------------------|
| `Testing.Fixtures.TaxCalculation` | `tax_calculation_json/1`, `tax_calculation_line_item_json/1` | `tax_calculation/1` |
| `Testing.Fixtures.TaxTransaction` | `tax_transaction_json/1`, `tax_transaction_line_item_json/1` | `tax_transaction/1` |
| `Testing.Fixtures.TaxId` | `tax_id_json/1` | `tax_id/1` |

**Migration:** Move `test/support/fixtures/tax_calculation.ex` and `tax_transaction.ex` → `lib/lattice_stripe/testing/fixtures/`. Rename module prefix to `LatticeStripe.Testing.Fixtures.*`. Update `calculation_transaction_test.exs` imports. Delete support copies. Keep `tax_settings.ex` / `tax_registration.ex` internal-only.

**Default TaxId fixture:** EU VAT baseline — `"type" => "eu_vat"`, `"value" => "DE123456789"`, `"country" => "DE"`.

## Guide & Docs-Truth (DX-04, DX-05)

- **`guides/tax.md`:** ~280–350 lines, Canonical Guides tier (metering.md depth reference).
- **`mix.exs`:** Add to `extras` + `groups_for_extras["Canonical Guides"]`; add fixture modules to Testing group.
- **Discovery:** README route, JTBD Start Here, recipes bridge, payments reverse-link, invoices/subscriptions one-liners (Phase 48 D-04 pattern).
- **Moduledoc:** Replace `"A canonical tax guide ships in v1.6 Phase 51."` with link to `guides/tax.md` in all five Tax modules **before** docs-truth greps the link.
- **`docs_truth_test.exs`:** New describe blocks for guide (3A, 3C, 3D) + five moduledoc grep sets (3E). **Remove** partial moduledoc grep from `transaction_test.exs` if present.

## Codebase Patterns to Copy

| Pattern | Source | Apply to |
|---------|--------|----------|
| Path-scoped parent ID | `LoginLink` | TaxId nested arity |
| CRUDL minus update | `Coupon` | TaxId verbs + negative exports |
| `stream!/3` list pagination | `CreditNote` | TaxId list |
| Two-layer fixtures | `Testing.Fixtures.CreditNote` | Tax calc/txn/id |
| Expand-through-parent test | `credit_note` / invoice tests | `tax_object_types_expand_test.exs` |
| Docs-truth 3A–3E | Phase 48 `docs_truth_test.exs` | Tax blocks |
| Guide discovery | Phase 48 CONTEXT D-04 | README, JTBD, recipes |

## Validation Architecture

Nyquist validation applies. Automated verification uses ExUnit + Mox:

| Layer | Command | When |
|-------|---------|------|
| TaxId unit | `mix test test/lattice_stripe/tax_id_test.exs --no-start` | After Plan 01 |
| ObjectTypes dispatch | `mix test test/lattice_stripe/object_types_test.exs --no-start` | After Plan 01, 02 |
| Expand proof | `mix test test/lattice_stripe/tax_object_types_expand_test.exs --no-start` | After Plan 02 |
| Integration chain | `mix test test/lattice_stripe/tax/calculation_transaction_test.exs --no-start` | After fixture migration |
| Docs-truth | `mix test test/lattice_stripe/docs_truth_test.exs --no-start` | After Plan 04 |
| Full tax + docs | `mix test test/lattice_stripe/tax/ test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/tax_id_test.exs test/lattice_stripe/tax_object_types_expand_test.exs --no-start` | End of phase |
| Compile gate | `mix compile --warnings-as-errors` | Every plan |

**Estimated runtime:** ~25–40s for full phase test slice.

**Manual-only:** None required — stripe-mock smoke explicitly deferred (CONTEXT).

## Plan Wave Recommendation

| Plan | Wave | Delivers |
|------|------|----------|
| 51-01 | 1 | TaxId module + nested structs + ObjectTypes + tax_id_test |
| 51-02 | 2 | Testing fixtures + expand proof + fixture migration |
| 51-03 | 3 | guides/tax.md + discovery + moduledoc guide links |
| 51-04 | 4 | docs_truth_test.exs Tax blocks |

## Sources

- [Stripe Tax IDs API](https://docs.stripe.com/api/tax_ids)
- [Stripe Customer tax IDs](https://docs.stripe.com/billing/taxes/tax-ids)
- [Stripe Standalone Tax API](https://docs.stripe.com/tax/standalone-tax-api)
- `.planning/phases/51-taxid-testing-adoption-surface/51-CONTEXT.md`
- `.planning/research/PITFALLS.md` #5, #6
