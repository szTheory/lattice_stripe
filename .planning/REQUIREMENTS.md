# Requirements: LatticeStripe — v1.10 "Accrue Surface Closure" (Hex 1.8.0)

**Defined:** 2026-07-27
**Core Value:** Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.

Source: verified accrue gap brief (`.planning/research/accrue-gap-brief-2026-07-27.txt`, SEED-005). Every requirement closes a gap that currently blocks or degrades accrue, the downstream billing lib. "Developer" = the Elixir developer consuming LatticeStripe.

## v1 Requirements

### Entitlements

- [x] **ENT-01**: Developer can list a customer's active entitlements via `LatticeStripe.Entitlements.ActiveEntitlement.list/3` (`GET /v1/entitlements/active_entitlements`, customer filter)
- [x] **ENT-02**: Developer can auto-paginate all active entitlements via `ActiveEntitlement.stream!/3` (follows `has_more`/cursor — the load-bearing piece for accrue's reconciler)
- [x] **ENT-03**: Developer can retrieve a single active entitlement by id via `ActiveEntitlement.retrieve/3`
- [x] **ENT-04**: Developer can create, retrieve, update, and list entitlement features via `LatticeStripe.Entitlements.Feature` (`/v1/entitlements/features`)
- [x] **ENT-05**: `active_entitlement_summary` payloads (which have **no top-level `id`**) deserialize correctly without being dropped

### Metering Reads

- [x] **MTR-01**: Developer can read meter event summaries via `LatticeStripe.Billing.MeterEventSummary.list/4` (`GET /v1/billing/meters/:id/event_summaries`; params customer, start_time, end_time, value_grouping_window)
- [x] **MTR-02**: Developer can auto-paginate meter event summaries via `Billing.MeterEventSummary.stream!`
- [x] **MTR-03**: `LatticeStripe.Billing.MeterErrorReport` is a typed struct (exposing `reason.error_types`), deserialized from the `v1.billing.meter.error_report_triggered` v2 thin event via `from_event/1`
- [x] **MTR-04**: Docs confirm `Billing.MeterEvent.create/3` accepts arbitrary custom `payload` dimensions and decimal-string `value`s

### Object Types & Fixtures

- [x] **OBJ-01**: The four missing webhook object types deserialize via `ObjectTypes.maybe_deserialize/1` — `entitlements.active_entitlement`, `entitlements.active_entitlement_summary`, `billing.meter_event`, `billing.meter_event_summary`. (`billing.meter_error_report` is **excluded**: it is a v2 thin-event `data` payload carrying no `"object"` key, so `maybe_deserialize/1`'s `%{"object" => _}` dispatch can never reach it — see Phase 64 CONTEXT F-13/D-14. It is decoded explicitly via `MeterErrorReport.from_event/1`.)
- [x] **OBJ-02**: Public `LatticeStripe.Testing.Fixtures` exist for entitlement + meter objects (incl. the no-`id` summary), each with a typed-conversion wrapper in `LatticeStripe.Testing`
- [x] **OBJ-03**: Public `Testing.Fixtures` exist for core billing objects (subscription, invoice, customer, payment_intent)

### Product ↔ Feature

- [ ] **PROD-01**: Developer can attach, list, and delete product features via `LatticeStripe.Product.Feature` (`POST`/`GET`/`DELETE /v1/products/:id/features`)
- [ ] **PROD-02**: `Product.features` deserializes into a typed struct instead of a raw `[map()]`

### Developer Experience

- [x] **DX-01**: Developer can make live Stripe calls without manually starting a Finch pool — an optional `LatticeStripe.Application` starts a default `LatticeStripe.Finch` pool and the `:finch` option defaults to it (relax `required: true`; drop from `@enforce_keys`). Existing callers that pass `:finch` keep working (backwards-compatible)
- [ ] **DX-02**: `LatticeStripe.Error` exposes response `headers` (and/or a parsed `retry_after`) so consumers can honor Stripe's `Retry-After`
- [ ] **DX-03**: `LatticeStripe.Webhook.CacheBodyReader` is public and covered by the semver contract (promoted out of `@moduledoc false`)

### Docs

- [x] **DOC-01**: A "1.1 → 1.7: what landed" migration guide is published in HexDocs, enumerating every surface that shipped since 1.1 with before/after examples
- [ ] **DOC-02**: Docs state permanently that `Charge.create` is absent by design and `PaymentIntent.create(confirm: true)` is the sanctioned path

## v2 Requirements (deferred to SEED-006)

Lower-priority DX from brief §3.2, 3.5–3.9, 3.11 — real but non-blocking. Tracked in `.planning/seeds/SEED-006-accrue-dx-ergonomics.md`, not in this roadmap.

- **DX2-01**: Semver-gated struct-shape/value-type changes (opt-in `atomize_statuses`)
- **DX2-02**: Opt-in DateTime deserialization (`datetimes: true`)
- **DX2-03**: Canonical deep `Resource.to_map/1,2` with configurable key shape
- **DX2-04**: Per-request `platform_scoped: true` / `stripe_account: :none`
- **DX2-05**: Documented `idempotency_key_fn` client hook
- **DX2-06**: `Transport.Stub` returning typed core-billing structs
- **DX2-07**: Memoized/named client + telemetry/pagination/retries doc callouts

## Out of Scope

| Feature | Reason |
|---------|--------|
| Per-request `entitled?(customer, feature)` gate helper | Actively harmful for accrue — its entitlement gate path is fail-closed, local-only, network-free (merge-blocking CI gate). Would invite a network call on auth paths. Pull/pagination shape only. |
| Additional metering **write** surfaces | Accrue uses exactly one (`MeterEvent.create/3`) and ignores the rest; all four write surfaces already ship in 1.7.13. |
| Sigma, Reporting/RevRec, Radar, Terminal, Payment Links | Recorded accrue non-goals (brief §5); Sigma/Reporting are comparators, not targets. |
| Identity, Treasury, Issuing, Financial Connections, Climate | Broad resource-family breadth remains deferred per the v1.x stop; this reopen is narrow and Accrue-driven. |
| Doc-only re-explanation of already-shipped surfaces beyond the migration guide | Half of accrue's "gaps" already shipped (brief §4); DOC-01 covers this once. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ENT-01 | Phase 63 | Complete |
| ENT-02 | Phase 63 | Complete |
| ENT-03 | Phase 63 | Complete |
| ENT-04 | Phase 63 | Complete |
| ENT-05 | Phase 63 | Complete |
| MTR-01 | Phase 64 | Complete |
| MTR-02 | Phase 64 | Complete |
| MTR-03 | Phase 64 | Complete |
| MTR-04 | Phase 64 | Complete |
| OBJ-01 | Phase 65 | Complete |
| OBJ-02 | Phase 65 | Complete |
| OBJ-03 | Phase 65 | Complete |
| PROD-01 | Phase 66 | Pending |
| PROD-02 | Phase 66 | Pending |
| DX-01 | Phase 61 | Complete |
| DX-02 | Phase 67 | Pending |
| DX-03 | Phase 67 | Pending |
| DOC-01 | Phase 62 | Complete |
| DOC-02 | Phase 67 | Pending |

**Coverage:**

- v1 requirements: **19 total** (the enumerated list contains 19 distinct IDs — ENT×5, MTR×4, OBJ×3, PROD×2, DX×3, DOC×2; the earlier "17" header count was stale)
- Mapped to phases: 19/19 ✓
- Unmapped: 0

**Phase → requirement rollup:**

- Phase 61 (Wave 0): DX-01
- Phase 62 (Wave 0): DOC-01
- Phase 63 (Wave 1): ENT-01, ENT-02, ENT-03, ENT-04, ENT-05
- Phase 64 (Wave 2): MTR-01, MTR-02, MTR-03, MTR-04
- Phase 65 (Wave 2): OBJ-01, OBJ-02, OBJ-03
- Phase 66 (Wave 3): PROD-01, PROD-02
- Phase 67 (Wave 3): DX-02, DX-03, DOC-02

---
*Requirements defined: 2026-07-27*
*Last updated: 2026-07-27 after milestone v1.10 roadmap creation (traceability filled, 19/19 mapped)*
