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
- [ ] **Phase 63: Stripe-Native Entitlements** - Pull/paginate active entitlements + manage entitlement features (Wave 1, flagship)
- [ ] **Phase 64: Meter Event-Summary Reads** - Read metered usage totals back from Stripe (Wave 2)
- [ ] **Phase 65: Webhook ObjectTypes & Testing Fixtures** - Five entitlement/meter object types deserialize; public fixtures (Wave 2)
- [ ] **Phase 66: Product ↔ Feature Attachment** - Attach/list/delete product features + typed `Product.features` (Wave 3)
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
**Plans**: TBD

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
**Plans**: 4/7 plans executed
**Wave 1**

- [x] 63-01-PLAN.md — TRACER: typed `ActiveEntitlement.list/3` end-to-end (fixtures, `list_json/3`, `Feature` decode, `list/3`, L1 surface locks) (Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 63-02-PLAN.md — `retrieve/3` + `stream!/3` and the ten-assertion pagination proof incl. "page 2 preserves the customer filter" (Wave 2)
- [x] 63-03-PLAN.md — `Entitlements.Feature` full verb surface, the archiving + `lookup_key` moduledocs, L2 locks (Wave 2)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 63-04-PLAN.md — `ActiveEntitlementSummary` with no `:id`, typed nested `%List{}`, cursor-order lock, `stream_entitlements!/3` (Wave 3)
- [ ] 63-05-PLAN.md — stripe-mock integration proof for all six verbs + Phase 65 fixture-promotion handoff (Wave 3)

**Wave 4** *(blocked on Wave 3 completion)*

- [ ] 63-06-PLAN.md — `guides/entitlements.md`, `guides/scope.md` fence, ExDoc registration in `mix.exs` (Wave 4)

**Wave 5** *(blocked on Wave 4 completion)*

- [ ] 63-07-PLAN.md — docs-truth locks (ExDoc placement + three prose fences) and the five phase gates (Wave 5)

### Phase 64: Meter Event-Summary Reads

**Goal**: Developers can read metered usage totals back from Stripe (accrue's entire usage-read surface is zero today).
**Depends on**: Phase 61 (Wave 0 de-risk; not a hard code dependency)
**Requirements**: MTR-01, MTR-02, MTR-03, MTR-04
**Success Criteria** (what must be TRUE):

  1. `LatticeStripe.Billing.Meter.EventSummary.list/4` returns summaries from `GET /v1/billing/meters/:id/event_summaries` with `customer`, `start_time`, `end_time`, `value_grouping_window` params.
  2. `Billing.Meter.EventSummary.stream!` auto-paginates meter event summaries.
  3. `LatticeStripe.Billing.MeterErrorReport` is a typed struct exposing `validation_errors`, deserializable from a webhook payload.
  4. `Billing.MeterEvent.create/3` docs confirm arbitrary custom `payload` dimensions and decimal-string `value`s are accepted.

**Build constraints**: Follow the parent-scoped `/v1/parent/:id/child` path pattern in `lib/lattice_stripe/tax_id.ex` + `transfer_reversal.ex`, and the nested-namespace pattern in `lib/lattice_stripe/billing/meter.ex`. **Do NOT add new metering write surfaces** — accrue uses exactly one (`MeterEvent.create/3`) and ignores the rest; all four writes already ship. New modules need `@moduledoc`/`@doc` + ExDoc group registration.
**Plans**: TBD

### Phase 65: Webhook ObjectTypes & Testing Fixtures

**Goal**: The five missing entitlement/meter webhook object types deserialize into typed structs, and public fixtures cover them plus core billing objects.
**Depends on**: Phase 63 (Entitlements modules), Phase 64 (`MeterErrorReport` + `EventSummary` modules)
**Requirements**: OBJ-01, OBJ-02, OBJ-03
**Success Criteria** (what must be TRUE):

  1. `ObjectTypes.maybe_deserialize/1` returns typed structs for `entitlements.active_entitlement`, `entitlements.active_entitlement_summary`, `billing.meter_event`, `billing.meter_event_summary`, `billing.meter_error_report`.
  2. Each `object_types.ex` registration key matches the wire `"object"` string verbatim and maps to a module exposing `from_map/1`.
  3. Public `LatticeStripe.Testing.Fixtures` (with typed-conversion wrappers in `LatticeStripe.Testing`) exist for entitlement + meter objects, including the no-`id` summary.
  4. Public `Testing.Fixtures` exist for core billing objects — subscription, invoice, customer, payment_intent.

**Build constraints**: Register in `lib/lattice_stripe/object_types.ex` (`billing.meter_event` module already exists — registrable as-is). Each key → a module with `from_map/1`; the `active_entitlement_summary` key must tolerate the missing `id`. Follow existing `LatticeStripe.Testing` fixture patterns (e.g. `dispute/1`, `customer/1`). Phase 63's `test/support/fixtures/entitlements.ex` is a promotion target: move it to `lib/lattice_stripe/testing/fixtures/entitlements.ex` **and** rename the module from `LatticeStripe.Test.Fixtures.Entitlements` to `LatticeStripe.Testing.Fixtures.Entitlements` — this is a move *plus* a module rename, because the private test-support namespace (`LatticeStripe.Test.Fixtures.*`) differs from the public one (`LatticeStripe.Testing.Fixtures.*`) and a literal file move alone produces a compile error; carry the four function names (`active_entitlement_json/1`, `active_entitlement_summary_json/1`, `feature_json/1`, `active_entitlement_list_json/2`) and their bodies over unchanged rather than re-authoring them.
**Plans**: TBD

### Phase 66: Product ↔ Feature Attachment

**Goal**: Developers can manage product feature attachments and read a typed `Product.features`, so consumers can derive an entitlement catalog from Stripe.
**Depends on**: Phase 63 (entitlement `Feature` objects are what product features reference)
**Requirements**: PROD-01, PROD-02
**Success Criteria** (what must be TRUE):

  1. `LatticeStripe.Product.Feature` supports attach/list/delete over `POST`/`GET`/`DELETE /v1/products/:id/features`.
  2. `Product.features` deserializes into a typed struct instead of a raw `[map()]`.
  3. Existing `Product.retrieve`/`list` continue to return correctly with the newly-typed `features` field (no break for current callers).

**Build constraints**: Follow the parent-scoped path pattern (`tax_id.ex`, `transfer_reversal.ex`). Type the existing raw `[map()]` fields in `lib/lattice_stripe/product.ex` (`features` L67/L100/L408; `marketing_features` L70/L103/L411). New module needs `@moduledoc`/`@doc` + ExDoc group registration.
**Plans**: TBD

### Phase 67: DX Hardening & Milestone Doc Close

**Goal**: Consumers can honor Stripe `Retry-After`, rely on a public `CacheBodyReader`, and read permanent guidance that `Charge.create` is absent by design.
**Depends on**: Phase 62 (migration-guide surface), Phase 66
**Requirements**: DX-02, DX-03, DOC-02
**Success Criteria** (what must be TRUE):

  1. `LatticeStripe.Error` exposes response `headers` (and/or a parsed `retry_after`) so a rate-limited consumer can honor Stripe's `Retry-After`.
  2. `LatticeStripe.Webhook.CacheBodyReader` is public (promoted out of `@moduledoc false`, given valid `@moduledoc`/`@doc` + ExDoc registration) and covered by the semver contract.
  3. Docs state permanently that `Charge.create` is absent by design and `PaymentIntent.create(confirm: true)` is the sanctioned path, with a docs-truth regression lock.

**Build constraints**: `lib/lattice_stripe/error.ex` currently has no `headers`/`retry_after` (Stripe sends `Retry-After` as a header). `lib/lattice_stripe/webhook/cache_body_reader.ex` is `@moduledoc false` at L3 — promotion is a semver contract, so ExDoc registration in `mix.exs` is required. Do not regress SEED-005 §6 contracts.
**Plans**: TBD

## Progress (v1.10 — active)

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 61. Default Finch Pool & Optional Application | v1.10 | 2/2 | Complete    | 2026-07-27 |
| 62. "1.1 → 1.7 What Landed" Migration Guide | v1.10 | 0/? | Not started | - |
| 63. Stripe-Native Entitlements | v1.10 | 4/7 | In Progress|  |
| 64. Meter Event-Summary Reads | v1.10 | 0/? | Not started | - |
| 65. Webhook ObjectTypes & Testing Fixtures | v1.10 | 0/? | Not started | - |
| 66. Product ↔ Feature Attachment | v1.10 | 0/? | Not started | - |
| 67. DX Hardening & Milestone Doc Close | v1.10 | 0/? | Not started | - |

## Next Step

**`/gsd-plan-phase 61`** — plan the Wave 0 default Finch pool fix (the live accrue footgun). Phase 62 (migration guide) is parallelizable. Entitlements (Phase 63) is the flagship and should follow Wave 0.
