# LatticeStripe

## What This Is

A production-grade, idiomatic Elixir SDK for the Stripe API. LatticeStripe is the default Stripe integration for the Elixir ecosystem — reliable enough for production SaaS, ergonomic enough that Elixir developers feel at home immediately. GSD milestone v1.11 is a reader-first quality closure cycle on the 2.2.x package line, preserving the complete Payments, Billing, Connect, Tax, webhook, Entitlements, and operator surface while making the repository easier to trust and maintain. Hex package: `lattice_stripe`, module prefix: `LatticeStripe`.

## Core Value

Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising. **Still the right priority** — validated across eleven completed GSD milestones and by downstream adopter pull from Accrue.

## Current Milestone: v1.11 Reader-First Quality Closure

**Goal:** Turn the already-complete SDK into a clean, trustworthy maintenance
pause: reader-first internals, an exactly preserved public API, honest CI/security
and coverage signals, current adopter documentation, and a fully verified 2.2.x
release line.

**Target outcomes:**

- Remove decorative source noise, stale scaffolding, generated debris, and unclear repository entry points while preserving useful rationale.
- Consolidate safe internal mechanics and test fixtures where duplication obscures intent.
- Decompose the oversized client core and its characterization suite into cohesive private units without changing any public call shape or result.
- Ratchet CI, security, concurrency, optional-feature, packaging, and coverage checks only where the signal is truthful and maintainable.
- Make SemVer, tenant-header suppression, idempotency, pagination/streaming, testing, and release guidance explicit from the adopter's point of view.
- Close with green remote `main`, a stable 3,463-entry public API snapshot, triaged issues and PRs, clean worktrees, and package 2.2.1 published and verified.

**Scope boundary:** This is a quality milestone, not a feature milestone. No new
Stripe resource families, public convenience hooks, DSL/code generation,
provider-shaped abstractions, or speculative API changes are allowed. HexDocs and
the public Elixir API are the user interface; there is no web UI scope.

## Current State

**Shipped milestone:** v1.10 Accrue Surface Closure completed and archived on
2026-08-25: 19/19 requirements, 7/7 verified phases, 19/19 integration joins,
and 6/6 adopter flows. The close accepted bounded external-confidence, Nyquist,
and known-flake debt; none is a product-behavior blocker.

**Active milestone:** v1.11 Reader-First Quality Closure.

**Latest shipped milestone:** v1.10 Accrue Surface Closure — Entitlements, metering reads, webhook fixtures, Product Feature attachments, default Finch operation, and DX hardening. Package baseline: 2.2.0.

**Done estimate:** v1.10 is complete; v1.11 execution has started from the synchronized 2.2.0 release baseline.

**Post-v1.x posture:** One bounded quality-closure milestone, then reactive maintenance; no broad resource-family expansion and no marketing website.

**Public surface:** [README.md](README.md) + [HexDocs](https://hexdocs.pm/lattice_stripe) + [guides/scope.md](guides/scope.md) — sufficient for an SDK; do not duplicate in a standalone site.

**Adoption:** Pure maintenance until external pull (no scheduled launch post). See `.planning/threads/post-v1x-maintenance-posture.md`.

**Latest archived milestone:** v1.10 Accrue Surface Closure (archived 2026-08-25)

**What shipped in v1.10:**

- **Runtime defaults** — optional `LatticeStripe.Application`, default Finch pool, explicit-pool compatibility, and opt-out behavior (DX-01, Phase 61).
- **Entitlements** — typed active-entitlement reads/streaming, Feature management, summary decoding, and fail-closed local authorization guidance (ENT-01..05, Phase 63).
- **Metering and webhook support** — event-summary reads/streaming, typed meter error reports, four exact object-type registrations, and public entitlement/meter/core-billing fixtures (MTR-01..04, OBJ-01..03, Phases 64-65).
- **Product Feature attachments** — typed create/retrieve/list/stream/delete with exact dispatch and raw Product marketing-field compatibility (PROD-01..02, Phase 66).
- **Adopter DX and truth** — historical migration guide, faithful error headers/`Retry-After`, public multi-chunk-safe `CacheBodyReader`, and permanent PaymentIntent-first Charge guidance (DOC-01..02, DX-02..03, Phases 62 and 67).

**What shipped in v1.8:**

- **Release truth** — getting-started release-status prose aligned to Hex 1.7.x; docs_truth SSOT locks for prose drift (TRUTH-01, TRUTH-02, Phase 56).
- **Payments guide correctness** — `guides/payments.md` atom status, stream filter, and `search/3` arity fixes with VERIFY-04 regression locks (GUIDE-01..03, Phase 57).
- **Charge reconciliation routing** — PI-first Charge section in payments.md plus operator guide update/capture spines (ROUTE-01, ROUTE-02, Phase 57).
- **Planning truth close** — JTBD-MAP post-v1.8 refresh, MILESTONES/RETROSPECTIVE cosmetics, tax proof commit, milestone audit (ROUTE-03, PLAN-01/02, PROOF-01, Phase 58).

**What shipped in v1.7:**

- **Charge surface expansion** — `LatticeStripe.Charge` list/search/update/capture parity with PI-first moduledoc, Mox wire tests, stripe-mock integration smokes, and docs-truth four-surface triangulation (CHRG-01..05).
- **Operator guides** — `guides/production-checklist.md` and `guides/event-debugging.md` wired into ExDoc Operations & DX, README hardening route, and JTBD operator route (OPS-01, OPS-02).
- **Release truth capstone** — `@version` 1.7.0, CHANGELOG v1.4–v1.7, lockstep `~> 1.7` install contract, SSOT docs-truth migration, Hex publish at 1.7.0 (REL-01..04).
- **v1.x stop signal** — Phase `41.1` retired as `accepted-external-verification`; library called "done for v1.x scope" in README, `guides/scope.md`, and planning artifacts (CLOSE-01, CLOSE-02).

**What shipped in v1.6:**

- **Tax Calculation & Transaction core** — `Tax.Calculation` and `Tax.Transaction` with nested structs, explicit verbs (`create_from_calculation/3`, `create_reversal/3`), moduledocs on 90-day expiry and `Invoice.AutomaticTax` boundary, and chained Mox-at-Transport integration spec proving calc→txn→reversal.
- **Tax Settings & Registration** — `Tax.Settings` singleton (`retrieve/2`, `update/3` on `/v1/tax/settings`) and `Tax.Registration` CRUDL with jurisdiction `country_options` and authority disclaimer moduledocs — first singleton resource pattern in the codebase.
- **TaxId dual-path surface** — top-level `LatticeStripe.TaxId` with guard-disambiguated routing for `/v1/tax_ids` and `/v1/customers/:id/tax_ids`, nested `Verification`/`Owner` structs, PII-redacted `Inspect`.
- **Adoption surface** — public `LatticeStripe.Testing` Tax fixtures, expand-through-parent proof for all five Tax object types, canonical `guides/tax.md` (351 lines) in ExDoc Canonical Guides + JTBD ladder, docs-truth grep locks on Tax moduledocs and guide content.

**What shipped in v1.5:**

- Thin-event SDK surface — `Webhook.parse_event_notification/4` (+ bang variant) verifies HMAC signatures and returns typed `EventNotification` structs exposing `id`, `type`, `created`, `context`, and a `related_object` reference, using the same error atoms as `construct_event/3`.
- Typed fetch-after-verify helpers — `Webhook.fetch_event/2,3` (`/v2/core/events/{id}`) and `Webhook.fetch_related_object/2,3` returning typed resources via the existing `ObjectTypes` registry (no new dispatch table), honoring per-request `:client`, `:api_version`, and `:idempotency_key`.
- `Event.t()` extended with a `related_object` field; net-new `EventNotification` + `EventNotification.RelatedObject` modules with custom `Inspect` impls; `ObjectTypes.fetch_module/1` typed-gate accessor.
- `Webhook.check_tolerance/2` `tolerance: 0` semantics reconciled across four surfaces (docstring, code clause, Plug NimbleOptions schema, tests) — `tolerance: 0` now disables the staleness check as the docstring promised, matching every canonical Stripe SDK. CHANGELOG entry + docs-truth grep regression lock the decision.
- Canonical guide `guides/webhooks-thin-events.md` published — Phoenix controller spine, fetch-after-verify, idempotency keyed on `event.id`, rate-limit guidance (<90/s), Connect/context-aware routing, verification-vs-payload-shape failure boundary; wired into ExDoc `Operations & DX` + README hardening-ops route + `guides/webhooks.md` closing section + JTBD Start Here Runtime route + Job 7 Read next.
- `LatticeStripe.Testing` thin-event helpers — `generate_thin_event_payload/3` (signed wire payload + matching `Stripe-Signature` header parseable by `parse_event_notification/4`) and `event_notification/1` (typed builder mirroring `dispute/1`/`customer/1`); snapshot helpers remain backwards-compatible.
- `test/lattice_stripe/webhook/thin_event_test.exs` chained Mox-at-Transport integration suite + five new docs-truth grep blocks (guide content lock, `~> 1.5` install canary, ExDoc placement, cross-link graph, Plug `@moduledoc` `tolerance: 0` testing-only).

**Outstanding follow-through (not milestone-blocking):**

- None — Phase `41.1` retired as `accepted-external-verification` in v1.7 (Phase 55).

## v1.x Status (historical post–1.7.0)

The library is **done for v1.x scope** — intended mainstream SaaS Stripe coverage is shipped and documented. Identity, Treasury, Issuing, Terminal, Financial Connections, Climate, Sigma, and Reporting remain deferred unless adopter pull justifies a future milestone.

**Forward posture:** Maintenance mode — bugfixes, Stripe API drift, adopter-driven narrow additions. No planned new resource-family breadth in v1.x absent fresh adopter pull.

## Maintenance Mode (post–v1.10)

**Latest shipped milestone:** v1.10 Accrue Surface Closure (archived 2026-08-25)

**Forward posture:** Maintenance mode — Stripe API drift, adopter-driven narrow additions, bugfixes. No planned new resource-family breadth absent fresh adopter pull.

**Release truth:** The v1.10 plan targeted Hex 1.8.0, but a public fixture rename correctly forced package 2.0.0; release metadata is now at 2.1.0. Do not collapse GSD milestone numbers into package versions.

See `.planning/milestones/v1.10-MILESTONE-AUDIT.md` for close-time audit evidence.

<details>
<summary>Archived v1.10 milestone context and original Hex 1.8.0 plan</summary>

## Reopen for Adopter Pull (2026-07-27) — v1.8.0 "Accrue Surface Closure"

**The documented reopen gate has fired.** Maintenance-mode posture always reserved
one trigger for new build: *"New Stripe resource families... deferred unless adopter
pull justifies a future milestone"* (Out of Scope, below). Accrue — the downstream
billing lib that already consumes LatticeStripe — has a **verified, blocking**
dependency on Stripe-native Entitlements plus a small set of surface gaps. A gap
scan of Accrue against its vendored `lattice_stripe` 1.7.13 source is captured at
`.planning/seeds/SEED-005-stripe-native-entitlements.md` (evidence:
`.planning/research/accrue-gap-brief-2026-07-27.txt`).

**This is a genuine code milestone (not doc-only): the next Hex release is a minor
bump to 1.8.0.** Scope is deliberately narrow — three genuinely-missing capabilities
(Entitlements, Billing.Meter event summaries, 5 ObjectTypes/fixtures), one live DX
footgun (default Finch pool), and Product↔Feature — all additive, all in service of
letting Accrue adopt a newer LatticeStripe. It does **not** reopen broad
resource-family breadth (Identity, Treasury, Issuing, Terminal, etc. stay deferred).

**Note the numbering divergence:** GSD planning milestones reached v1.9 (doc-only,
no Hex bump), so this is GSD-milestone **v1.10** even though the Hex tag is **1.8.0**.

## Current Milestone: v1.10 Accrue Surface Closure (Hex 1.8.0)

**Goal:** Close the three verified `lattice_stripe` surface gaps blocking accrue —
Stripe-native Entitlements, meter usage reads, and webhook object-type coverage —
plus the default-Finch-pool DX fix and Product↔Feature, so accrue can adopt a
current release. All additive → Hex minor bump to 1.8.0.

**Target features:**
- Entitlements: `ActiveEntitlement` (list/stream!/retrieve) + `Feature` CRUD (pull/pagination shape, no gate helper)
- Billing.Meter event-summary reads (accrue's entire usage-read surface today is zero)
- 5 webhook ObjectTypes + typed fixtures (entitlement/meter/core-billing; summary has no `id`)
- Optional `LatticeStripe.Application` + default Finch pool (fixes a live consumer footgun)
- Product↔Feature typed attachment CRUD/enumeration, while preserving raw Product marketing-display fields (lets consumers derive the entitlement catalog from the dedicated Stripe attachment endpoint)
- "1.1 → 1.7 what landed" migration guide (zero-code; unblocks four accrue deferrals)
- Retry-After response evidence, a public semver-locked webhook `CacheBodyReader`, and permanent PaymentIntent-first Charge initiation guidance

**Key context:** Driven by the verified accrue gap brief
(`.planning/research/accrue-gap-brief-2026-07-27.txt`, SEED-005). Lower-priority DX
(brief §3.2–3.11) is deferred to SEED-006. Stability contracts in SEED-005 §6 must
not break. Finch fix approach locked to the optional-Application + default-pool
option.

</details>

## Next Milestone Goals

Complete v1.11 at the point of diminishing returns: the code and docs are a joy to read, automation tells the truth, the public API is unchanged, package 2.2.1 is verified on every public surface, and the repository can return to reactive maintenance without a cleanup tail. SEED-006 remains a candidate inventory; only its documentation-only, compatibility-preserving guidance is in scope.

## Context

**Ecosystem gap:** At project start, the Elixir ecosystem lacked a modern, maintained Stripe SDK. `stripity_stripe` was outdated, with known issues around nested encoding and stale API coverage. LatticeStripe fills that gap with a production-minded Elixir-first surface.

**Target users:** Elixir developers building SaaS products who need Stripe integrations that are correct, documented, and unsurprising. Early adopter signal remains strong: Accrue already consumes LatticeStripe as a downstream billing layer.

**Codebase scale (post-v1.10):** `lib/` + `test/` contain 71,101 lines of Elixir source. The v1.10 range changed 291 files (+47,548/-603, including planning evidence) and closed with 2,440 tests, zero ExDoc warnings, and the public API lock passing.

**Design philosophy:**

- Pure-functional core; processes only where the runtime boundary needs them
- Behaviours for extensibility (`Transport`, `RetryStrategy`, `Json`)
- `{:ok, result} | {:error, reason}` everywhere, with bang variants layered on top
- Pattern-matchable returns and explicit verbs for destructive or irreversible operations
- Principle of least surprise for Elixir developers

**Testing philosophy:**

- Integration specs first, with real request-pipeline proof where feasible
- Shift-left verification by default when a flow can be executed truthfully in CI
- Unit tests for pure logic and Mox for behaviour contracts
- Docs-truth assertions are first-class regression coverage, not editorial cleanup

## Constraints

- **Language**: Elixir 1.15+, OTP 26+
- **License**: MIT
- **No Dialyzer**: Typespecs remain documentation-first
- **HTTP**: Finch default transport behind a behaviour boundary
- **JSON**: Jason

## Requirements

### Validated

- ✓ Tax Settings & Registration (CONF-01..04) — Phase 50, v1.6
- ✓ Tax Calculation & Transaction core (CALC-01..03, TXN-01..04, DX-03) — Phase 49, v1.6
- ✓ Production-grade transport, retry, pagination, telemetry foundation — v1.0
- ✓ Payments, Checkout, SetupIntents, Refunds, webhooks — v1.0
- ✓ Billing core (Invoice, Subscription, SubscriptionSchedule, SubscriptionItem) — v1.0
- ✓ Connect core (Accounts, AccountLinks, money movement) — v1.0
- ✓ Accrue unblockers (Meter, MeterEvent, BillingPortal.Session) — v1.1
- ✓ Production hardening (Configuration CRUDL, per-op timeouts, warm-up, circuit breaker, OpenTelemetry guides, batching, drift detection, LiveBook) — v1.2
- ✓ Production coverage (File/FileLink, Disputes, CreditNote, Mandate, SetupAttempt, Quote) — v1.3
- ✓ Public truth aligned across README, CHANGELOG, Getting Started, cheatsheet, mix.exs, HexDocs (TRUTH-01, TRUTH-02) — v1.4
- ✓ Docs-truth regression coverage extended beyond README (VERIFY-01, VERIFY-02) — v1.4
- ✓ Guide discovery ladder and layered ExDoc grouping (GUIDE-01, GUIDE-02) — v1.4
- ✓ Flagship recipes: Checkout+Portal, Metering runtime, Connect platform, Quote-to-billing (RECIPE-01..04) — v1.4
- ✓ Planning truth reflects close-ready posture while preserving Phase 41.1 external-proof boundary (PLAN-01) — v1.4
- ✓ Thin-event SDK surface: `Webhook.parse_event_notification/4`, typed `EventNotification`/`RelatedObject` structs, `Event.related_object` extension (THIN-01..04) — v1.5
- ✓ Webhook bug reconciliation: `Webhook.check_tolerance/2` `tolerance: 0` semantics aligned across docstring, code clause, Plug schema, and tests (WEBFIX-01) — v1.5
- ✓ `LatticeStripe.Testing` thin-event payload + notification helpers, snapshot helpers backwards-compatible (TESTING-01) — v1.5
- ✓ Canonical Phoenix thin-event guide wired into ExDoc + discovery ladder (GUIDE-03) — v1.5
- ✓ Integration coverage for thin-event happy-path, fetch-after-verify, malformed-payload, and `tolerance: 0` boundaries + docs-truth regression extension (VERIFY-03) — v1.5
- ✓ Tax Calculation & Transaction core (CALC-01..03, TXN-01..04, DX-03) — Phase 49, v1.6
- ✓ Tax Settings & Registration (CONF-01..04) — Phase 50, v1.6
- ✓ TaxId dual-path CRUDL (TAXID-01..04) — Phase 51, v1.6
- ✓ Tax ObjectTypes, Testing fixtures, canonical guide, docs-truth (DX-01, DX-02, DX-04, DX-05) — Phase 51, v1.6
- ✓ Charge list/search/update/capture surface (CHRG-01..05) — Phase 52, v1.7
- ✓ Operator guides: production checklist + event debugging (OPS-01, OPS-02) — Phase 53, v1.7
- ✓ Release truth: 1.7.0 version, CHANGELOG v1.4–v1.7, lockstep `~> 1.7` install contract, Hex publish (REL-01..04) — Phase 54, v1.7
- ✓ Phase 41.1 retired + v1.x stop signal (CLOSE-01, CLOSE-02) — Phase 55, v1.7
- ✓ Release-status prose truth in getting-started + docs_truth prose regression locks (TRUTH-01, TRUTH-02) — Phase 56, v1.8
- ✓ Canonical payments guide API examples (GUIDE-01..03) — Phase 57, v1.8
- ✓ Charge reconciliation doc routing in payments + operator guides (ROUTE-01, ROUTE-02) — Phase 57, v1.8
- ✓ docs_truth locks canonical payments guide API patterns (VERIFY-04) — Phase 57, v1.8
- ✓ MILESTONES v1.7 audit footnote + v1.8 draft section — Phase 58, v1.8
- ✓ PLAN-01 — `54-VERIFICATION.md` backfilled (retroactive, quick 260527-tqf, 2026-05-28)
- ✓ RETROSPECTIVE v1.8 entry + process lessons (PLAN-02) — Phase 58, v1.8
- ✓ JTBD-MAP post-v1.8 refresh (ROUTE-03) — Phase 58, v1.8
- ✓ Tax proof files tracked in CI (PROOF-01) — Phase 58, v1.8
- ✓ Checkout guide atom status + status-values callout (CHECKOUT-01, CHECKOUT-02) — Phase 59, v1.9
- ✓ Checkout guide docs_truth regression locks (CHECKOUT-03) — Phase 59, v1.9
- ✓ README error taxonomy canonical atoms + docs_truth lock (README-01, README-02) — Phase 59, v1.9
- ✓ docs_truth checkout.md content locks alongside payments (VERIFY-05) — Phase 59, v1.9
- ✓ Stripe-native entitlements read surface: `ActiveEntitlement` list/retrieve/`stream!`, `Feature` CRUDL, `ActiveEntitlementSummary` webhook decode + `stream_entitlements!/3` (ENT-01..05) — Phase 63, v1.10
- ✓ Historical 1.1 → 1.7 migration guide: action-first breaking-change triage, complete capability inventory, and semantic ExDoc regression contract (DOC-01) — Phase 62, v1.10
- ✓ Product Feature attachment surface: create/retrieve/list/`stream!`/delete, exact `product_feature` dispatch, raw Product marketing-field compatibility, and catalog-to-local-access guidance (PROD-01, PROD-02) — Phase 66, v1.10
- ✓ Default Finch pool and optional application startup with explicit-pool compatibility and opt-out (DX-01) — Phase 61, v1.10
- ✓ Meter event-summary reads/streaming, typed error reports, and payload-contract documentation (MTR-01..04) — Phase 64, v1.10
- ✓ Exact entitlement/meter webhook object dispatch and public entitlement/meter/core-billing fixtures (OBJ-01..03) — Phase 65, v1.10
- ✓ Faithful error response headers and strict `Retry-After` parsing (DX-02) — Phase 67, v1.10
- ✓ Public, semver-locked, multi-chunk-safe `Webhook.CacheBodyReader` (DX-03) — Phase 67, v1.10
- ✓ Permanent PaymentIntent-first Charge initiation guidance (DOC-02) — Phase 67, v1.10
- ✓ Guide-only changes run docs-truth CI; JTBD hosted-checkout truth refreshed (CI-01, JTBD-01) — Phase 60, v1.9

### Active

- Reader-first source, test, prompt, and repository organization with useful invariants preserved
- Cohesive private client internals and behavior-organized characterization coverage under an exact public API freeze
- Truthful CI/security/coverage/package gates, including optional-feature paths and known concurrency flakes
- Adopter-first SemVer, tenancy, idempotency, streaming, testing, and release documentation
- Verified 2.2.1 release and a clean maintenance handoff

### Out of Scope

- Billing-engine abstractions, entitlement logic, dunning workflows — belong downstream in Accrue or application code
- Resolving Phase 41.1 as a milestone-blocking requirement — retired as `accepted-external-verification` in v1.7
- New Stripe resource families in v1.x — v1.7 is the planned stop signal; Identity, Treasury, Issuing, Terminal, Financial Connections, Climate, Sigma, and Reporting deferred unless adopter pull justifies a future milestone
- Marketing / landing website — README + HexDocs are the public surface for this SDK; a separate site duplicates ExDoc and has low adoption ROI
- Per-request `entitled?(customer, feature)` gate helper — an authorization gate that makes a network call fails **open** under partition; the SDK ships the reconciler plus a local fail-closed recipe instead (D-19, Phase 63)
- Speculative DX surface from SEED-006: DateTime conversion, deep `to_map`, a second account-suppression option, function-valued idempotency keys, a fake/stub transport, named client registries, or webhook error unification — each expands compatibility burden without solving the reader-first closure goal
- Macro/DSL/code-generation rewrites, Dialyzer adoption, and vanity coverage targets — disproportionate migration/maintenance cost for this mature handwritten SDK

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Handwritten v1 surface | Polish and Elixir ergonomics mattered more than breadth-first codegen | ✓ Good |
| Integration-first proof posture | Real boundaries catch drift earlier than mock-only tests | ✓ Good |
| Explicit verbs over magical updates | Clearer SDK semantics for irreversible actions | ✓ Good |
| Shift-left verification default | Docs/example flows should become executable proof where feasible | ✓ Good |
| Refuse network-calling authorization gates | A gate that calls Stripe per request fails open under partition; reconcile-then-gate-locally is the correct shape | ✓ Good (Phase 63) |
| Keep LatticeStripe lower-level than Accrue | Billing-engine abstractions belong downstream, not in the SDK | ✓ Good |
| Prioritize adoption closure before new breadth | Public truth and guide clarity unlock more value than another narrow Stripe family | ✓ Good (v1.4 confirmed) |
| Treat public docs/support truth as milestone-grade | First-run trust and flagship guidance change adoption more than another small API family | ✓ Good (v1.4 confirmed) |
| Keep recipe/operator guidance primitive-first | Recipes should stitch shipped primitives together without becoming an app workflow product | ✓ Good (v1.4 confirmed) |
| Treat the library as near-done for scope | Remaining leverage is adopter truth + selected wedges, not missing foundation | ✓ Good |
| Docs-truth as verifier-worthy regression surface | A green narrow docs test can still hide adopter-facing drift; v1.4 found `~> 1.2` drift while older assertions stayed green | ✓ Good (validated by Phase 43 find) |
| Preserve Phase 41.1 as `pending-external-verification` boundary | Real-sandbox proof is valuable but should not flatten into a false close; honesty over headline | ✓ Good (carried through v1.4) |
| Layered ExDoc grouping (Start Here / Canonical / Operations / Flagship) | Flat extras list buried high-leverage guides; role-based grouping surfaces the right surface for the right reader | ✓ Good (v1.4) |
| Webhook-confirmed truth posture in flagship guides | Accepted-now-vs-confirmed-by-webhook framing avoids overclaiming synchronous authority for async billing flows | ✓ Good (v1.4) |
| Lead post-adoption with thin-event webhooks, then Tax, then polish-and-stop | Thin events are mainstream Stripe direction; webhook foundation is already strong so the wedge is additive; Tax is the broadest remaining mainstream family but bigger; v1.7 polish gives the project an honest stop point at "done for v1.x scope" | ✓ Confirmed by v1.5 (shipped 2026-05-27 in ~6 hours single-day; surface landed clean with 21 tests added) |
| Verify shipped surface against `lib/` source before every new milestone | Planning artifacts can be coherent and still miss real code-truth gaps (v1.5 assessment found `Charge` is unusually thin and the `tolerance: 0` webhook bug stayed open through v1.4 — neither captured in planning docs alone) | ✓ Validated by v1.5 (`tolerance: 0` bug discovered by source verification, not planning review) |
| Reuse existing dispatch tables for new resource families instead of growing new ones | `Webhook.fetch_related_object/2,3` typed-dispatches via the existing `ObjectTypes` registry. Resisting "new dispatch table" temptation kept v1.5 narrow and made the surface immediately benefit from `ObjectTypes` typed deserialization | ✓ Good (v1.5) |
| Treat docstring/code drift as bug, not as docstring-fix opportunity | WEBFIX-01 chose to fix the code clause to match the docstring (matching every canonical Stripe SDK and the more useful semantics) instead of the easier path of changing the docstring. CHANGELOG + docs-truth grep regression locks the decision against future "fix it to be stricter" drift | ✓ Good (v1.5 WEBFIX-01) |
| Four-surface triangulation for security-adjacent bug fixes | WEBFIX-01 reconciled `tolerance: 0` across (1) source docstring, (2) source code clause, (3) `Webhook.Plug` NimbleOptions schema, (4) tests + CHANGELOG + docs-truth grep — the four surfaces an adopter touches to reach the behavior. Single-surface fixes leave drift seams | ✓ Good (v1.5 pattern, reusable for Charge surface work in v1.7) |
| Top-level `TaxId` with arity-based dual-path routing | Single module covers `/v1/tax_ids` and `/v1/customers/:id/tax_ids` via guard-disambiguated arity — avoids duplicating Customer-scoped vs top-level modules | ✓ Good (v1.6) |
| Singleton resource pattern for `Tax.Settings` | First singleton in codebase (`GET/POST /v1/tax/settings`, no resource ID) — establishes pattern for future Stripe singletons | ✓ Good (v1.6) |
| SDK primitives only for Tax; Accrue owns filing | Phase 51 guide fences filing orchestration to Accrue once; prevents scope bleed into multi-jurisdiction filing automation | ✓ Good (v1.6) |
| Hex publish is stop-milestone capstone, not out-of-band | Out-of-band publish creates adopter truth lag (install `~> 1.3` while code ships v1.5/v1.6); fold release prep into v1.7 | ✓ Good (v1.7 REL-04) |
| v1.7 as planned v1.x stop signal | Polish + operator guides + release truth close remaining scope gaps honestly before declaring maintenance mode | ✓ Good (v1.7) |
| Retire Phase 41.1 as accepted external boundary | Real-sandbox proof valuable but should not block honest close; append-only retirement preserves audit trail | ✓ Good (v1.7 CLOSE-01) |
| Post-v1.7: no new code breadth; doc-routing polish is highest leverage | lib/ scan confirms Charge, operator guides, Hex 1.7.0 shipped; remaining gaps are getting-started prose, Charge doc routing, JTBD-MAP lag — not missing API families | ✓ Assessment (2026-05-27) |
| Refresh JTBD-MAP at milestone close, not just milestone start | v1.7 shipped but JTBD-MAP still described pre-v1.7 gaps until post-v1.7 assessment — causes wrong scope on `/gsd-new-milestone` | ✓ Assessment (2026-05-27) |
| docs_truth must cover canonical guide API examples | payments.md survived with string-vs-atom status bugs and wrong search arity because docs_truth locks cross-links/install pins but not canonical guide body examples | ✓ Assessment (2026-05-27 refresh) |
| CI paths-ignore on guides bypasses docs_truth | Guide-only PRs skip unit CI; highest-risk edit surface has weakest automated gate — fix requires explicit workflow approval | Pending approval |
| Post-v1.8 assessment: checkout.md + README + CI-01 are highest remaining adopter-truth gaps | lib/ + guides scan after v1.8 close found checkout.md L206 status-string bug (same class as pre-v1.8 payments.md), README error taxonomy drift, CI-01 still bypasses docs_truth on guide-only PRs; JTBD-MAP hosted checkout rating was overstated | ✓ Assessment (2026-05-27); v1.9 recommended |
| CI paths-ignore on guides bypasses docs_truth | Guide-only PRs skip unit CI; highest-risk edit surface has weakest automated gate | ✓ Good (v1.9 Phase 60 CI-01) |
| Post-v1.9 assessment: maintenance default; v1.10 optional | lib/ + guides scan confirms no API breadth wedge; remaining work is doc defects + Gap 2 narrative; structured milestone only if user wants closure | ✓ Assessment (2026-05-27) |
| docs_truth does not lock markdown fences or JTBD gap-inventory | payments.md unclosed fence survived v1.8–v1.9; portal Dashboard-only claim vs shipped Configuration CRUD; graduation to fence/portal/JTBD locks | ✓ Next-step assessment (2026-05-27) |
| No marketing website for LatticeStripe | SDK libs are discovered via Hex + README; ExDoc is the canonical reference; site would duplicate docs | ✓ Post-v1.x posture (2026-05-28) |
| Post-v1.x: reactive maintenance only | v1.x scope complete at Hex 1.7.0; act on bugs, Stripe drift, adopter pull — not proactive milestones | ✓ Post-v1.x posture (2026-05-28) |
| Adoption: pure silence default | No Forum/blog launch required for "done"; optional cross-link from Accrue when convenient | ✓ Post-v1.x posture (2026-05-28) |
| Reopen maintenance mode for v1.8.0 "Accrue Surface Closure" | The adopter-pull gate fired: Accrue has a verified, blocking need for Stripe-native Entitlements + a narrow set of surface gaps (SEED-005); scope is additive and Accrue-driven, not broad breadth | ✓ Reopen decision (2026-07-27) |
| Keep Product marketing display fields separate from typed entitlement attachments | Stripe's legacy `Product.features` and current `Product.marketing_features` contain pricing-table copy, not `product_feature` resources; typing those raw maps in a minor release would be semantically wrong and compatibility-breaking | ✓ Good (Phase 66) |
| Treat public fixture renames as breaking changes | Fixture builders are called from adopter test suites; aligning names required a major package bump rather than the planned 1.8.0 minor | ✓ Good (2.0.0 release) |
| Keep GSD milestone versions distinct from package versions | Planning advanced through doc-only v1.8/v1.9 while package releases followed SemVer; forcing them into lockstep obscures release truth | ✓ Good (v1.10 close) |
| Freeze the exact public API during v1.11 quality closure | A maintenance cleanup should reduce reader and operator cost without transferring migration cost to adopters; the existing 3,463-entry snapshot is the hard boundary | Active (v1.11) |
| Ratchet quality only where the signal is truthful | Stable 80% coverage, explicit optional-feature lanes, immutable CI inputs, and meaningful adapter tests are more valuable than vanity percentages or redundant tools | Active (v1.11) |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check -> still the right priority?
3. Audit Out of Scope -> reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-08-25 for v1.11 Reader-First Quality Closure.*
