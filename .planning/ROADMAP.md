# Roadmap: LatticeStripe

## Milestones

- ✅ **v1.0 — Foundation + Billing + Connect + 1.0 Release** — Phases 1-11, 14-19 (shipped 2026-04-13 to Hex.pm) — [archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 — Accrue unblockers (metering + portal)** — Phases 20-21 (shipped 2026-04-14) — [brief](v1.1-accrue-context.md)
- ✅ **v1.2 — Production Hardening & DX** — Phases 22-31 (shipped 2026-04-17) — [archive](milestones/v1.2-ROADMAP.md)
- ✅ **v1.3 — Production Coverage & Adoption Polish** — Phases 32-42 plus Phase 41.1 follow-through (shipped 2026-05-25) — [archive](milestones/v1.3-ROADMAP.md)
- ✅ **v1.4 — Adoption Closure** — Phases 43-46 (shipped 2026-05-27) — [archive](milestones/v1.4-ROADMAP.md)
- ✅ **v1.5 — Thin-Event Webhooks** — Phases 47-48 (shipped 2026-05-27) — [archive](milestones/v1.5-ROADMAP.md)
- ✅ **v1.6 — Tax** — Phases 49-51 (shipped 2026-05-27) — [archive](milestones/v1.6-ROADMAP.md)
- ✅ **v1.7 — Polish & Operator** — Phases 52-55 (shipped 2026-05-27, v1.x stop signal) — [archive](milestones/v1.7-ROADMAP.md)
- ✅ **v1.8 — Adopter Truth & Doc Routing Polish** — Phases 56-58 (shipped 2026-05-27) — [archive](milestones/v1.8-ROADMAP.md)
- ✅ **v1.9 — CI & Doc Honesty** — Phases 59-60 (shipped 2026-05-27) — [archive](milestones/v1.9-ROADMAP.md)
- 🚧 **v1.10 — Accrue Surface Closure (Hex 1.8.0)** — Phases 61-67 (in progress, opened 2026-07-27 under adopter-pull gate, SEED-005)

## Current Status

**Active milestone:** v1.10 Accrue Surface Closure (Hex 1.8.0) — **active build track** (the adopter-pull reopen gate fired; SEED-005).

**Goal:** Close the three verified `lattice_stripe` surface gaps blocking accrue — Stripe-native Entitlements, meter usage reads, and webhook object-type coverage — plus the default-Finch-pool DX fix and Product↔Feature, so accrue can adopt a current release. All additive → Hex minor bump to 1.8.0. Broad resource-family breadth (Identity, Treasury, Issuing, Terminal, etc.) stays deferred; this reopen is narrow and Accrue-driven.

**Sequencing (deliberate, low-risk-first per SEED-005):**

- **Wave 0 (first): de-risk & unblock** — Phase 61 default Finch pool (live consumer footgun) + Phase 62 "1.1 → 1.7 what landed" migration guide (zero-code; unblocks four accrue deferrals).
- **Wave 1: Entitlements** — Phase 63 (the flagship, pull/pagination shape; NO gate helper).
- **Wave 2: Meter reads + ObjectTypes/fixtures** — Phase 64 + Phase 65.
- **Wave 3: Product↔Feature + remaining DX/docs** — Phase 66 + Phase 67.

## Phases

- [x] **Phase 61: Default Finch Pool & Optional Application** - Live Stripe calls work without a manually-started Finch pool (Wave 0) (completed 2026-07-27)
- [ ] **Phase 62: "1.1 → 1.7 What Landed" Migration Guide** - Zero-code HexDocs guide enumerating every surface shipped since 1.1 (Wave 0)
- [x] **Phase 63: Stripe-Native Entitlements** - Pull/paginate active entitlements + manage entitlement features (Wave 1, flagship) (completed 2026-07-28)
- [x] **Phase 64: Meter Event-Summary Reads** - Read metered usage totals back from Stripe (Wave 2) (completed 2026-07-28)
- [x] **Phase 65: Webhook ObjectTypes & Testing Fixtures** - Four entitlement/meter object types deserialize; public fixtures (Wave 2) (completed 2026-07-29)
- [x] **Phase 66: Product ↔ Feature Attachment** - Typed attachment CRUD/enumeration with legacy Product marketing-field compatibility (Wave 3) (completed 2026-08-25)
- [ ] **Phase 67: DX Hardening & Milestone Doc Close** - Error `retry_after`, public `CacheBodyReader`, `Charge.create`-by-design docs (Wave 3)

## Phase Details

### Phase 61: Default Finch Pool & Optional Application

**Goal**: Developers can make live Stripe calls without manually starting a Finch pool.
**Depends on**: Nothing (Wave 0, first phase)
**Requirements**: DX-01
**Success Criteria** (what must be TRUE):

  1. An optional `LatticeStripe.Application` starts a default `LatticeStripe.Finch` pool, and the `:finch` option defaults to it.
  2. `Client.new!/1` succeeds without a `:finch` option and requests route through the default pool.
  3. An existing caller that passes `:finch` explicitly continues to work unchanged (backwards-compatible).
  4. `:finch` is no longer `required: true` in `config.ex` and is dropped from `@enforce_keys` in `client.ex`, proven by a test that constructs a client with no `:finch`.

**Build constraints**: Follow `lib/lattice_stripe/config.ex` (`required: true` at L34/L71) + `lib/lattice_stripe/client.ex` (`@enforce_keys` at L51). MUST NOT break SEED-005 §6 stability contracts: `Client.new!/1` takes a keyword list; per-request opts override per-client; nil `stripe_account` omits the `Stripe-Account` header; `api_version` default `2026-03-25.dahlia`.
**Plans**: 2 plans

- [x] 61-01-PLAN.md — Default Finch pool wired end-to-end: `LatticeStripe.Application` + `mod:`, relax config/client `:finch` requirements, opt-out toggle, tests (Wave 1)
- [x] 61-02-PLAN.md — Docs & CHANGELOG: guides note the default pool + optional `:finch` + opt-out (Wave 2)

### Phase 62: "1.1 → 1.7 What Landed" Migration Guide

**Goal**: Adopters pinned to 1.1 can discover every surface that shipped since 1.1 with before/after examples.
**Depends on**: Nothing (Wave 0, parallelizable with Phase 61)
**Requirements**: DOC-01
**Success Criteria** (what must be TRUE):

  1. A new HexDocs guide enumerates each surface shipped since 1.1 — BillingPortal.Configuration, Charge.list/search, TestHelpers.TestClock, Testing.Fixtures, Dispute, Tax.*, CreditNote, Payout, Quote, BalanceTransaction, EventNotification (thin events) — with before/after examples.
  2. The guide is registered in `mix.exs` ExDoc extras + a group, so `mix docs` builds without warnings.
  3. `mix ci` passes (`docs --warnings-as-errors`, `credo --strict`).

**Build constraints**: Zero library code — docs only. ExDoc group registration in `mix.exs` is mandatory or `mix ci` fails. Highlight BillingPortal.Configuration (unblocks an accrue portal-cancel dunning-bypass threat mitigation).
**Plans**: 2 plans

Plans:

- [x] 62-01-PLAN.md — Correct and complete the historical guide, lock its semantic contract, and run the strict docs/CI gate
- [x] 62-02-PLAN.md — Close the verification-boundary contradiction with immutable executor and lifecycle scope audits

### Phase 63: Stripe-Native Entitlements

**Goal**: Developers can pull and auto-paginate a customer's active entitlements and manage entitlement features.
**Depends on**: Phase 61 (Wave 0 de-risk; not a hard code dependency)
**Requirements**: ENT-01, ENT-02, ENT-03, ENT-04, ENT-05
**Success Criteria** (what must be TRUE):

  1. `LatticeStripe.Entitlements.ActiveEntitlement.list/3` returns a customer's active entitlements from `GET /v1/entitlements/active_entitlements` (customer filter).
  2. `ActiveEntitlement.stream!/3` auto-follows `has_more`/cursor across pages (the reconciler-critical piece for accrue).
  3. `ActiveEntitlement.retrieve/3` returns a single typed active entitlement by id.
  4. `LatticeStripe.Entitlements.Feature` supports create/retrieve/update/list over `/v1/entitlements/features`.
  5. An `active_entitlement_summary` payload with **no top-level `id`** deserializes into a typed struct without being dropped.

**Build constraints**: Follow `lib/lattice_stripe/charge.ex` full-resource template (`@known_fields`, `defstruct [..., object:, extra: %{}]`, `from_map/1`, `Resource.unwrap_*`) and `lib/lattice_stripe/list.ex` `List.stream!` for pagination. Deserializer MUST tolerate the missing top-level `id`. **Do NOT build a per-request `entitled?(customer, feature)` gate helper** (explicitly out of scope — pull/pagination shape only). New public modules need valid `@moduledoc`/`@doc` + ExDoc group registration in `mix.exs`.
**Plans**: 7/7 plans executed
**Wave 1**

- [x] 63-01-PLAN.md — TRACER: typed `ActiveEntitlement.list/3` end-to-end (fixtures, `list_json/3`, `Feature` decode, `list/3`, L1 surface locks) (Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 63-02-PLAN.md — `retrieve/3` + `stream!/3` and the ten-assertion pagination proof incl. "page 2 preserves the customer filter" (Wave 2)
- [x] 63-03-PLAN.md — `Entitlements.Feature` full verb surface, the archiving + `lookup_key` moduledocs, L2 locks (Wave 2)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 63-04-PLAN.md — `ActiveEntitlementSummary` with no `:id`, typed nested `%List{}`, cursor-order lock, `stream_entitlements!/3` (Wave 3)
- [x] 63-05-PLAN.md — stripe-mock integration proof for all six verbs + Phase 65 fixture-promotion handoff (Wave 3)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 63-06-PLAN.md — `guides/entitlements.md`, `guides/scope.md` fence, ExDoc registration in `mix.exs` (Wave 4)

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 63-07-PLAN.md — docs-truth locks (ExDoc placement + three prose fences) and the five phase gates (Wave 5)

### Phase 64: Meter Event-Summary Reads

**Goal**: Developers can read metered usage totals back from Stripe (accrue's entire usage-read surface is zero today).
**Depends on**: Phase 61 (Wave 0 de-risk; not a hard code dependency)
**Requirements**: MTR-01, MTR-02, MTR-03, MTR-04
**Success Criteria** (what must be TRUE):

  1. `LatticeStripe.Billing.MeterEventSummary.list/4` returns summaries from `GET /v1/billing/meters/:id/event_summaries` with `customer`, `start_time`, `end_time`, `value_grouping_window` params.
  2. `Billing.MeterEventSummary.stream!` auto-paginates meter event summaries.
  3. `LatticeStripe.Billing.MeterErrorReport` is a typed struct exposing `reason.error_types` (with nested `sample_errors`), deserializable from the `v1.billing.meter.error_report_triggered` v2 thin event via `from_event/1`.
  4. `Billing.MeterEvent.create/3` docs confirm arbitrary custom `payload` dimensions and decimal-string `value`s are accepted.

**Build constraints**: Follow the parent-scoped `/v1/parent/:id/child` path pattern in `lib/lattice_stripe/transfer_reversal.ex` (the primary template — flat, wire-named, already ships `list/4` + `stream!/4`) + `tax_id.ex` + `external_account.ex`. **Modules are FLAT at depth 2** (`Billing.MeterEventSummary`, `Billing.MeterErrorReport`), named after the wire `"object"` string — parent-scoping is expressed in the signature, not the module name. Zero of the ~50 request-owning modules in `lib/` sit at depth 3; in `"Billing Metering"` specifically, depth 3 *means* value object. Only `MeterErrorReport`'s sub-structs (`.Reason`, `.ErrorType`, `.SampleError`) nest, and they own no `%Request{}`. See Phase 64 CONTEXT D-01. **Do NOT add new metering write surfaces** — accrue uses exactly one (`MeterEvent.create/3`) and ignores the rest; all four writes already ship. New modules need `@moduledoc`/`@doc` + ExDoc group registration.
**Plans**: 10/10 plans executed
**Wave 1**

- [x] 64-01-PLAN.md — Tracer: end-to-end `MeterEventSummary.list/4` read slice + ExDoc registration + fixture (Wave 1, gated by the D-01 one-way module-name decision)
- [x] 64-02-PLAN.md — MTR-04 encoder truth tests (float cliff, decimal strings, payload pass-through) + the `drift.ex` known-fields regex fix (Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 64-03-PLAN.md — `list!/2..4`, `stream!/2..4`, the D-31 refutation set, and the full moduledoc (Wave 2)
- [x] 64-04-PLAN.md — `MeterErrorReport` + `.Reason`/`.ErrorType`/`.SampleError`, `from_event/1`, fixture, ObjectTypes dead-key lock (Wave 2)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 64-05-PLAN.md — GUARD-04 `check_summary_window!/2`, its two call sites, and the alignment matrix (Wave 3)
- [x] 64-06-PLAN.md — D-30's nine pagination assertions, two of them mutation-checked (Wave 3)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 64-07-PLAN.md — `guides/metering.md`: "Reading usage back", "The payload contract", and six corrections to false prose (Wave 4)
- [x] 64-09-PLAN.md — stripe-mock integration suite, ExDoc placement locks, clear the two metering docs warnings (Wave 4)

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 64-08-PLAN.md — Runtime-guide handler rewrite, `scope.md` dimension-read limit, `MeterEvent.create/3` `@doc` payload bullet (Wave 5 — cross-references headings 64-07 creates)

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 64-10-PLAN.md — D-29 five-step differential phase gate + operator sign-off (Wave 6)

### Phase 65: Webhook ObjectTypes & Testing Fixtures

**Goal**: The four missing entitlement/meter webhook object types deserialize into typed structs, and public fixtures cover them plus core billing objects.
**Depends on**: Phase 63 (Entitlements modules), Phase 64 (`MeterErrorReport` + `EventSummary` modules)
**Requirements**: OBJ-01, OBJ-02, OBJ-03
**Success Criteria** (what must be TRUE):

  1. `ObjectTypes.maybe_deserialize/1` returns typed structs for `entitlements.active_entitlement`, `entitlements.active_entitlement_summary`, `billing.meter_event`, `billing.meter_event_summary`. **`billing.meter_error_report` is deliberately NOT registered** — it is a v2 thin-event `data` payload with no `"object"` key, so `maybe_deserialize/1`'s dispatch can never reach it; registering it would create a dead key. It is decoded explicitly via `Billing.MeterErrorReport.from_event/1`. See Phase 64 CONTEXT F-13/D-14, and lock the absence with a `refute`.
  2. Each `object_types.ex` registration key matches the wire `"object"` string verbatim and maps to a module exposing `from_map/1`.
  3. Public `LatticeStripe.Testing.Fixtures` (with typed-conversion wrappers in `LatticeStripe.Testing`) exist for entitlement + meter objects, including the no-`id` summary.
  4. Public `Testing.Fixtures` exist for core billing objects — subscription, invoice, customer, payment_intent.

**Build constraints**: Register in `lib/lattice_stripe/object_types.ex` (`billing.meter_event` module already exists — registrable as-is). Each key → a module with `from_map/1`; the `active_entitlement_summary` key must tolerate the missing `id`. Follow existing `LatticeStripe.Testing` fixture patterns (e.g. `dispute/1`, `customer/1`). Phase 63's `test/support/fixtures/entitlements.ex` is a promotion target: move it to `lib/lattice_stripe/testing/fixtures/entitlements.ex` **and** rename the module from `LatticeStripe.Test.Fixtures.Entitlements` to `LatticeStripe.Testing.Fixtures.Entitlements` — this is a move *plus* a module rename, because the private test-support namespace (`LatticeStripe.Test.Fixtures.*`) differs from the public one (`LatticeStripe.Testing.Fixtures.*`) and a literal file move alone produces a compile error; carry the four function names (`active_entitlement_json/1`, `active_entitlement_summary_json/1`, `feature_json/1`, `active_entitlement_list_json/2`) and their bodies over unchanged rather than re-authoring them.
**Plans**: 6/6 plans executed

Plans:
**Wave 1**

- [x] 65-01-PLAN.md — TRACER: `entitlements.active_entitlement` end-to-end (registry row + fixture promotion + typed wrapper + ExDoc + guide) (Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 65-02-PLAN.md — meter fixture promotion; opens with the Q1 one-way `checkpoint:decision` on flat-vs-nested shape (Wave 2)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 65-03-PLAN.md — core-billing fixture promotion (customer, payment_intent, subscription); opens with the Q2 one-way `checkpoint:decision` on move-vs-duplicate (Wave 3)
- [x] 65-04-PLAN.md — remaining three `@object_map` rows + OBJ-01 completion; verifies the two Phase 64 locks (Wave 3)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 65-05-PLAN.md — the new `Testing.Fixtures.Invoice` module, lifted verbatim from `invoice_test.exs` (Wave 4)

**Wave 5** *(blocked on Wave 4 completion)*

- [ ] 65-06-PLAN.md — housekeeping ("five" → "four", stale v1.3 prose) + the five-step differential phase gate (Wave 5)

**Cross-cutting constraints:**

- MIX_ENV=prod mix compile succeeds.

### Phase 66: Product ↔ Feature Attachment

**Goal**: Developers can manage and completely enumerate typed Product Feature attachments, so consumers can derive an entitlement catalog from Stripe without misreading Product marketing display fields as access configuration.
**Depends on**: Phase 63 (entitlement `Feature` objects are what product features reference)
**Requirements**: PROD-01, PROD-02
**Success Criteria** (what must be TRUE):

  1. `LatticeStripe.Product.Feature` supports create/retrieve/list/stream/delete over the parent-scoped `/v1/products/:product/features` collection and `/v1/products/:product/features/:attachment` item paths.
  2. Exact `product_feature` wire objects deserialize into typed `%LatticeStripe.Product.Feature{}` attachments, including their nested `Entitlements.Feature` definition.
  3. Existing `Product.retrieve`/`list` preserve the independent raw-map shapes of legacy `Product.features` and current `Product.marketing_features`; catalog reads use `Product.Feature.list/4` or `stream!/4` (no break for current callers).

**Build constraints**: Follow the parent-scoped path pattern (`tax_id.ex`, `transfer_reversal.ex`). Preserve the existing raw `[map()]` Product marketing fields because they are display copy, not entitlement attachments. Type only the dedicated `product_feature` resource. New module needs `@moduledoc`/`@doc` + ExDoc group registration.
**Plans**: 5/5 plans executed
**Wave 1**

- [x] 66-01-PLAN.md

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 66-02-PLAN.md
- [x] 66-03-PLAN.md

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 66-04-PLAN.md

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 66-05-PLAN.md

### Phase 67: DX Hardening & Milestone Doc Close

**Goal**: Consumers can honor Stripe `Retry-After`, rely on a public `CacheBodyReader`, and read permanent guidance that `Charge.create` is absent by design.
**Depends on**: Phase 62 (migration-guide surface), Phase 66
**Requirements**: DX-02, DX-03, DOC-02
**Success Criteria** (what must be TRUE):

  1. `LatticeStripe.Error` exposes response `headers` (and/or a parsed `retry_after`) so a rate-limited consumer can honor Stripe's `Retry-After`.
  2. `LatticeStripe.Webhook.CacheBodyReader` is public (promoted out of `@moduledoc false`, given valid `@moduledoc`/`@doc` + ExDoc registration) and covered by the semver contract.
  3. Docs state permanently that `Charge.create` is absent by design and `PaymentIntent.create(confirm: true)` is the sanctioned path, with a docs-truth regression lock.

**Build constraints**: `lib/lattice_stripe/error.ex` currently has no `headers`/`retry_after` (Stripe sends `Retry-After` as a header). `lib/lattice_stripe/webhook/cache_body_reader.ex` is `@moduledoc false` at L3 — promotion is a semver contract, so ExDoc registration in `mix.exs` is required. Do not regress SEED-005 §6 contracts.
**Plans**: 3/5 plans executed

Plans:
**Wave 1**

- [x] 67-01-PLAN.md — Trace faithful final-response headers and strict Retry-After metadata through `LatticeStripe.Error`
- [x] 67-02-PLAN.md — Fix exact multi-chunk webhook raw-body accumulation before publication
- [x] 67-04-PLAN.md — Lock the permanent PaymentIntent-first Charge creation policy

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 67-03-PLAN.md — Publish, document, group, and semver-lock `CacheBodyReader`

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 67-05-PLAN.md — Run strict docs/API/CI convergence and hand off the milestone re-audit

## Progress (v1.10 — active)

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 61. Default Finch Pool & Optional Application | v1.10 | 2/2 | Complete    | 2026-07-27 |
| 62. "1.1 → 1.7 What Landed" Migration Guide | v1.10 | 2/2 | Complete    | 2026-08-24 |
| 63. Stripe-Native Entitlements | v1.10 | 7/7 | Complete    | 2026-07-28 |
| 64. Meter Event-Summary Reads | v1.10 | 10/10 | Complete    | 2026-07-28 |
| 65. Webhook ObjectTypes & Testing Fixtures | v1.10 | 6/6 | Complete    | 2026-07-29 |
| 66. Product ↔ Feature Attachment | v1.10 | 5/5 | Complete    | 2026-08-25 |
| 67. DX Hardening & Milestone Doc Close | v1.10 | 3/5 | In Progress|  |

## Next Step

**`/gsd-plan-phase 65`** — Webhook ObjectTypes & Testing Fixtures. Phase 64 deliberately left `lib/lattice_stripe/object_types.ex` byte-identical (verified at gate time), and 64-04 locked the absence of a `billing.meter_error_report` key by test, so Phase 65 owns every registry row. Phase 62 (migration guide, Wave 0, zero-code) remains unstarted and is parallelizable with it.
