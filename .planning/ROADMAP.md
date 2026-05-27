# Roadmap: LatticeStripe

## Milestones

- ✅ **v1.0 — Foundation + Billing + Connect + 1.0 Release** — Phases 1-11, 14-19 (shipped 2026-04-13 to Hex.pm) — [archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 — Accrue unblockers (metering + portal)** — Phases 20-21 (shipped 2026-04-14) — [brief](v1.1-accrue-context.md)
- ✅ **v1.2 — Production Hardening & DX** — Phases 22-31 (shipped 2026-04-17) — [archive](milestones/v1.2-ROADMAP.md)
- ✅ **v1.3 — Production Coverage & Adoption Polish** — Phases 32-42 plus Phase 41.1 follow-through (shipped 2026-05-25 with accepted external-proof gap) — [archive](milestones/v1.3-ROADMAP.md)
- ✅ **v1.4 — Adoption Closure** — Phases 43-46 (shipped 2026-05-27, Phase 41.1 preserved as `pending-external-verification`) — [archive](milestones/v1.4-ROADMAP.md)
- ✅ **v1.5 — Thin-Event Webhooks** — Phases 47-48 (shipped 2026-05-27) — [archive](milestones/v1.5-ROADMAP.md)
- 🚧 **v1.6 — Tax** — Phases 49-51 (in progress, kicked off 2026-05-27)

## Phases

- [x] **Phase 49: Tax Calculation & Transaction Core** — Standalone Tax flow primitives: calculate tax, record transactions, reverse when needed, with integration proof of the calc→txn chain. (completed 2026-05-27)
- [x] **Phase 50: Tax Settings & Registration** — Account-level tax configuration: singleton settings and jurisdiction registration CRUDL. (completed 2026-05-27)
- [ ] **Phase 51: TaxId, Testing & Adoption Surface** — Complete the Tax family with dual-path TaxId, Testing fixtures, canonical guide, and docs-truth regression.

## Phase Details

### Phase 49: Tax Calculation & Transaction Core

**Goal**: Adopters can run the canonical standalone Tax API flow — create a tax calculation, record it as a transaction, and reverse when needed — with typed structs, explicit verb functions, and an integration spec proving the calculation→transaction chain.
**Depends on**: Nothing (first v1.6 phase; sits on top of shipped v1.0–v1.5 foundation)
**Requirements**: CALC-01, CALC-02, CALC-03, TXN-01, TXN-02, TXN-03, TXN-04, DX-03
**Success Criteria** (what must be TRUE):

  1. An adopter can call `Tax.Calculation.create/3` with `customer_details`, `line_items`, and `currency` params (string keys) and receive `{:ok, %Tax.Calculation{}}` with typed nested line items when expanded.
  2. An adopter can call `Tax.Calculation.retrieve/3` and `Tax.Calculation.list_line_items/3` to re-fetch a calculation and paginate its line items before the 90-day expiry window.
  3. An adopter can call `Tax.Transaction.create_from_calculation/3` with a calculation ID and globally unique `reference` to record tax liability, receiving `{:ok, %Tax.Transaction{}}`.
  4. An adopter can call `Tax.Transaction.create_reversal/3` to reverse a previously recorded transaction.
  5. An adopter can call `Tax.Transaction.retrieve/3` and `Tax.Transaction.list_line_items/3` to inspect recorded transactions and their line items.
  6. Moduledocs on Calculation and Transaction document the 90-day calculation expiry, globally unique `reference` requirement, and scope boundary with `Invoice.AutomaticTax`.
  7. Integration tests under `test/lattice_stripe/tax/` prove the calc→txn chain via Mox-at-Transport (create calculation → create_from_calculation → retrieve transaction).

**Plans**: 3 plans (2 waves)

- [x] 49-01-PLAN.md — Tax.Calculation + shared nested structs + ObjectTypes + unit tests (CALC-01..03)
- [x] 49-02-PLAN.md — Tax.Transaction verbs + moduledocs + ObjectTypes + unit tests (TXN-01..04, DX-03 moduledoc)
- [x] 49-03-PLAN.md — Mox chained integration spec calc→txn→reversal (DX-03)

### Phase 50: Tax Settings & Registration

**Goal**: Adopters can configure account-level tax behavior — read/update tax settings and manage jurisdiction registrations — using the codebase's first singleton resource pattern and standard CRUDL.
**Depends on**: Phase 49 (Calculation/Transaction core must land first; Settings/Registration enhance but don't block core flow)
**Requirements**: CONF-01, CONF-02, CONF-03, CONF-04
**Success Criteria** (what must be TRUE):

  1. An adopter can call `Tax.Settings.retrieve/2` (no ID param) to read account tax settings and `Tax.Settings.update/3` to configure defaults like `tax_code` and head office address.
  2. Settings uses singleton paths (`GET/POST /v1/tax/settings`) — not standard CRUD with resource ID.
  3. An adopter can call `Tax.Registration.create/3` with country and jurisdiction-specific `country_options` to enable tax collection in a region.
  4. An adopter can call `Tax.Registration.retrieve/3`, `Tax.Registration.update/3`, and `Tax.Registration.list/3` to manage existing registrations with pagination.
  5. ObjectTypes registry entries for `tax.settings` and `tax.registration` enable expand deserialization.
  6. Moduledocs clarify that Registration.create does not register with tax authorities — it tells Stripe where the business collects tax.

**Plans**: 2 plans (2 waves)

Plans:

- [x] 50-01-PLAN.md — Tax.Settings singleton + nested structs + `tax.settings` ObjectTypes + settings tests (CONF-01, CONF-02)
- [x] 50-02-PLAN.md — Tax.Registration CRUDL + moduledocs + `tax.registration` ObjectTypes + registration tests (CONF-03, CONF-04)

### Phase 51: TaxId, Testing & Adoption Surface

**Goal**: Adopters can manage customer tax IDs via both Stripe paths, generate test fixtures for all Tax resources, follow a canonical Tax guide, and rely on docs-truth regression to keep Tax moduledocs honest.
**Depends on**: Phase 50 (all Tax resource modules except TaxId must exist before adoption surface closes the family)
**Requirements**: TAXID-01, TAXID-02, TAXID-03, TAXID-04, DX-01, DX-02, DX-04, DX-05
**Success Criteria** (what must be TRUE):

  1. An adopter can create, retrieve, list, and delete tax IDs via both `/v1/tax_ids` (top-level) and `/v1/customers/:id/tax_ids` (customer-nested) paths from a single `LatticeStripe.TaxId` module with arity-based path routing.
  2. All five Tax object types (`tax.calculation`, `tax.transaction`, `tax.settings`, `tax.registration`, `tax_id`) are registered in ObjectTypes and deserialize correctly via expand.
  3. `LatticeStripe.Testing` exposes builders for Tax Calculation, Transaction, and TaxId that produce wire-format maps parseable by `from_map/1`.
  4. `guides/tax.md` is published teaching the standalone calculate → record → reverse flow, with explicit scope boundary (SDK primitives only; filing orchestration is Accrue).
  5. The guide is wired into ExDoc layered grouping and the JTBD discovery ladder.
  6. Docs-truth grep blocks lock Tax moduledoc examples and guide content against drift.

**Plans**: TBD (via `/gsd-plan-phase 51`)

## Outstanding Follow-Through

- **Phase 41.1** — `pending-external-verification` for real-sandbox Quote downstream follow-through proof. Accepted external-proof boundary, carried forward from v1.3 archive. Planned to ride along with v1.7 polish milestone.

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 49. Tax Calculation & Transaction Core | 3/3 | Complete    | 2026-05-27 |
| 50. Tax Settings & Registration | 2/2 | Complete    | 2026-05-27 |
| 51. TaxId, Testing & Adoption Surface | 0/? | Not started | — |

## Next Milestone

After v1.6 ships, run `/gsd-new-milestone` to start **v1.7 — Polish & Operator** (Charge surface gap, Phase 41.1 follow-through, production guides). Planned stop signal for v1.x scope.

## Next Step

Run `/gsd-discuss-phase 49` to gather context and negotiate scope, then `/gsd-plan-phase 49` to create execution plans.
