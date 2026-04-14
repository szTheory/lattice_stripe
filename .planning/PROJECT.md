# LatticeStripe

## What This Is

A production-grade, idiomatic Elixir SDK for the Stripe API. LatticeStripe aims to be the default Stripe integration for the Elixir ecosystem — reliable enough for production SaaS, ergonomic enough that Elixir developers feel at home immediately. **Shipped v1.0.0 to Hex.pm on 2026-04-13** with full Payments + Billing + Connect coverage. Hex package: `lattice_stripe`, module prefix: `LatticeStripe`.

## Core Value

Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising. **Still the right priority** — validated by v1.0 shipping with a downstream consumer (Accrue) already building on top.

## Current Milestone: v1.1 Accrue unblockers (metering + portal)

**Goal:** Unblock Accrue Phase 4 by adding three Stripe resources: `Billing.Meter`, `Billing.MeterEvent` (+ `MeterEventAdjustment`), and `BillingPortal.Session`.

**Target features:**
- `LatticeStripe.Billing.Meter` CRUDL + `deactivate/reactivate` verbs + 4 nested typed structs
- `LatticeStripe.Billing.MeterEvent.create/3` + `MeterEventAdjustment.create/3` — fire-and-forget usage reporting
- `LatticeStripe.BillingPortal.Session.create/3` — create-only with `FlowData` nested struct
- New `guides/metering.md` + extended `guides/customer-portal.md`

**Scope & constraints:** Locked decisions D1-D5 in `.planning/v1.1-accrue-context.md` — bundled metering phase, `MeterEventAdjustment` included with MeterEvent, `meter_event_stream` and `BillingPortal.Configuration` deferred to v1.2+. **No release phase** — post-1.0 release-please config makes 1.0→1.1 zero-touch; do NOT add "Phase 22" by analogy with Phase 19.

## Current State (post-v1.0)

**Shipped:** v1.0.0 live on `hex.pm/packages/lattice_stripe`. 17 phases complete (1-11, 14-19; phases 12/13 were intentionally obliterated and rebuilt in Phase 14). ~47 plans executed. Nine-group ExDoc `groups_for_modules` layout, 16 guides, `api_stability.md` semver contract published, `test/readme_test.exs` quickstart harness, `CHANGELOG.md` with v1.0.0 Highlights, release pipeline fully automated via release-please + Hex publish.

**Downstream consumer:** The downstream lib is named **Accrue** — Laravel Cashier / Ruby `pay` analogue for Elixir. Accrue has its own GSD planning in a separate repo. Accrue Phase 3 (Core Subscription Lifecycle) is fully unblocked by LatticeStripe 1.0. Accrue Phase 4 (Advanced Billing + Checkout/Portal) drives LatticeStripe v1.1 scope.

**Release mechanics:** Post-1.0 cleanup (PR #8) removed `release-as` and flipped `bump-minor-pre-major` to `false`. Normal semver kicks in automatically — a `feat:` commit on main auto-bumps 1.0.0 → 1.1.0 via release-please, tag + Hex publish run automatically. Zero-touch releases going forward.

## Requirements

### Validated (v1.0)

All foundation, payment, webhook, telemetry, testing, docs, CI/CD, Billing, and Connect requirements from the original v1.0 charter shipped. The archived v1.0 requirements list with phase traceability lives at `.planning/milestones/v1.0-REQUIREMENTS.md`. Summary by tier:

**Foundation (Phases 1-3, 8)**
- ✓ Pluggable `Transport` behaviour with Finch default adapter — v1.0
- ✓ Explicit client configuration + per-request option overrides (`idempotency_key`, `stripe_account`, `api_key`, `stripe_version`, `expand`, `timeout`) — v1.0
- ✓ Structured error model with pattern-matchable `error_type()` atoms — v1.0
- ✓ Automatic retries honoring `Stripe-Should-Retry` + idempotency key generation/replay — v1.0
- ✓ Cursor-based list pagination with auto-pagination `stream!/2` — v1.0
- ✓ Search pagination, `expand:` support (IDs only; typed-struct expansion deferred — see Active), `Response` struct with request ID/headers — v1.0
- ✓ API version pinning per library release with per-client + per-request override — v1.0
- ✓ Telemetry events for request lifecycle + webhook verification spans — v1.0

**Payments (Phases 4-6)**
- ✓ Customers CRUDL + search — v1.0
- ✓ PaymentIntents — create, retrieve, update, confirm, capture, cancel, list, search — v1.0
- ✓ SetupIntents — create, retrieve, update, confirm, cancel, list — v1.0
- ✓ PaymentMethods — create, retrieve, update, list, attach, detach — v1.0
- ✓ Refunds — create, retrieve, update, cancel, list — v1.0
- ✓ Checkout.Session — create (payment/subscription/setup modes), retrieve, list, expire — v1.0

**Webhooks (Phase 7)**
- ✓ HMAC-SHA256 signature verification with timing-safe comparison and tolerance window — v1.0
- ✓ `Event` struct + `Webhook.Handler` behaviour + Phoenix `Webhook.Plug` with raw-body plumbing — v1.0
- ✓ `Webhook.generate_test_signature/3` test helper — v1.0

**Testing & Docs (Phases 9-10)**
- ✓ Integration specs via real Finch HTTP to `stripe-mock` — v1.0
- ✓ `LatticeStripe.Testing` public module with fixtures, `TestClock` support, `generate_webhook_payload/3` — v1.0
- ✓ ExDoc docs with 16 guides, nine-group module layout, `api_stability.md` semver contract — v1.0
- ✓ README with <60s quickstart + automated regression test (`test/readme_test.exs`) — v1.0
- ✓ Cheatsheet, getting-started, client-configuration, payments, checkout, webhooks, error-handling, metering guides — v1.0

**CI/CD (Phase 11)**
- ✓ GitHub Actions matrix: Elixir 1.15–1.19 × OTP 26–28, Lint, Integration Tests, stripe-mock Docker — v1.0
- ✓ Release Please with conventional commits → CHANGELOG + version bump + GitHub Release — v1.0
- ✓ Hex.pm auto-publish on release tag — v1.0
- ✓ Dependabot (hex + github-actions) with patch auto-merge — v1.0
- ✓ CONTRIBUTING, SECURITY, PR/issue templates, MIT LICENSE — v1.0

**Billing (Phases 14-16)**
- ✓ Invoice + InvoiceItem CRUDL with `finalize`, `pay`, `void`, `send`, `search` verbs — v1.0
- ✓ Subscription lifecycle (create, retrieve, update, cancel, resume, pause, list, search) with explicit verbs and proration guards — v1.0
- ✓ SubscriptionItem CRUDL — v1.0
- ✓ SubscriptionSchedule (phased scheduling) with `release`, `cancel`, proration-guard nested `subscription_details` check — v1.0

**Connect (Phases 17-18)**
- ✓ Account CRUDL + `reject` verb, Standard/Express/Custom types, `Account.Capability` nested struct with safe `status_atom/1` — v1.0
- ✓ PII-safe nested structs: `TosAcceptance`, `Company`, `Individual`, `BusinessProfile`, `Requirements`, `Settings` — v1.0
- ✓ AccountLink / LoginLink create-only with short-lived URLs — v1.0
- ✓ ExternalAccount polymorphic dispatcher (`BankAccount`, `Card`, `Unknown` fallback), full CRUDL on `/accounts/:id/external_accounts` — v1.0
- ✓ Charge retrieve-only (41-field struct) for Connect fee reconciliation — v1.0
- ✓ Transfer + TransferReversal CRUDL with embedded reversals decoding — v1.0
- ✓ Payout CRUDL + `cancel`, `reverse` verbs, nested `Payout.TraceId` struct — v1.0
- ✓ Balance singleton retrieve (no `:id`) + BalanceTransaction retrieve/list/stream with nested `FeeDetail` — v1.0

**Cross-cutting polish (Phase 19)**
- ✓ Public API surface locked via `@moduledoc false` on internals (D-04) — v1.0
- ✓ Nine-group ExDoc layout — v1.0
- ✓ `api_stability.md` publishing post-1.0 semver contract — v1.0
- ✓ Connect guide split into overview + accounts + money-movement — v1.0
- ✓ Release Please 1.0.0 cut with CHANGELOG Highlights narrative — v1.0

### Active (v1.1 — Accrue unblockers)

Scope locked in `.planning/v1.1-accrue-context.md`. Two phases, no release phase (zero-touch semver).

**Phase 20 — Billing metering (hot path)**
- [ ] `LatticeStripe.Billing.Meter` CRUDL + `deactivate/3` + `reactivate/3` verbs (no delete, no search)
- [ ] `LatticeStripe.Billing.Meter.DefaultAggregation` / `CustomerMapping` / `ValueSettings` / `StatusTransitions` nested typed structs
- [ ] `LatticeStripe.Billing.MeterEvent.create/3` — fire-and-forget usage reporting with `identifier:` idempotency
- [ ] `LatticeStripe.Billing.MeterEventAdjustment.create/3` — dunning-style corrections for over-reports
- [ ] `guides/metering.md` with usage-reporting idiom, reconciliation notes, webhook handoff pointers

**Phase 21 — Customer portal**
- [ ] `LatticeStripe.BillingPortal.Session.create/3` — create-only (no retrieve/list/update/delete), required `customer`, optional `return_url` / `configuration` / `locale` / `flow_data` / `on_behalf_of`
- [ ] `LatticeStripe.BillingPortal.Session.FlowData` nested struct (for deep-link flows: `subscription_cancel`, `payment_method_update`)
- [ ] `guides/customer-portal.md` extension with Accrue-style usage example

**Post-1.0 carry-overs** (deferred from original v1.0 charter)
- [ ] Expand-deserialization into typed structs (EXPD-02): currently `expand:` returns string IDs; deserializing into `%Resource{}` is deferred to v1.2+
- [ ] Nested expand dot-paths (EXPD-03): `expand: ["data.customer"]` parser support deferred to v1.2+
- [ ] Status-field atomization audit (EXPD-05): most resources already use atoms; sweep for any string-typed status fields deferred to v1.2+

### Out of Scope

**Permanently out of scope** (reasons still valid post-v1.0):
- Dialyzer/Dialyxir — explicitly excluded; typespecs are documentation-only, Credo strict handles lint
- Code generation from OpenAPI spec — v1 was fully handwritten for polish; generation remains a future consideration, not a v1.x goal
- Higher-level payment abstractions (Cashier/Pay analogue) — **this is Accrue** (separate repo, separate project, consuming LatticeStripe)
- Mobile/frontend SDK — backend only
- Thin event support (v2 webhook style) — v1 snapshot events ship; v2 thin events deferred to a future minor

**Deferred to v1.2+**:
- `/v1/billing/meter_event_stream` (high-throughput streaming variant) — Accrue doesn't need it, different semantics than fire-and-forget `meter_events`
- `BillingPortal.Configuration` CRUDL — Accrue manages portal config via Stripe dashboard for v1.1; full CRUDL with deep UX structs triples v1.1 scope
- Specialist families (Tax, Identity, Treasury, Issuing, Terminal) — not on Accrue's roadmap
- Full expand-deserialization story (EXPD-02/03/05)

**No longer out of scope** (shipped in v1.0):
- ~~Billing (subscriptions, invoices, products, prices) — future milestone~~ → shipped in Phases 14-16
- ~~Connect (platform accounts, transfers, payouts) — future milestone~~ → shipped in Phases 17-18

## Context

**Ecosystem gap:** At project start, the Elixir ecosystem lacked a modern, maintained Stripe SDK. `stripity_stripe` was outdated, with known issues (#208/#210 nested encoding bugs, #823 missing `id` in nested items) and did not reflect Stripe's evolution into a full money-workflow platform. LatticeStripe v1.0 fills that gap.

**Target users:** Elixir developers building SaaS applications who need to accept payments. Likely working at startups or integrating Stripe at their day job. They want a library that just works, has great docs, and doesn't surprise them. Early adopter signal: Accrue (downstream billing lib) is already consuming LatticeStripe `~> 1.0`.

**Design philosophy:**
- Pure-functional core — processes only when truly needed (connection pooling, not code organization)
- Behaviours for extensibility (Transport, RetryStrategy, Json)
- `{:ok, result} | {:error, reason}` everywhere, bang variants layered on top
- Pattern-matchable returns — domain-rich types, not boolean soup
- Principle of least surprise — Elixir developers feel at home immediately
- Explicit verbs for destructive/irreversible ops (`cancel`, `resume`, `deactivate`, `reject`) over flag-style `update` with magic params — lesson from stripe-ruby

**Testing philosophy:**
- Integration specs primary — real Finch HTTP to `stripe-mock`, exercises the real request pipeline
- Unit tests for pure logic (request building, response decoding, error normalization)
- Fixtures extracted into `test/support/fixtures/` per resource family
- Mox for behaviour-based mocking (Transport, RetryStrategy) in unit tests
- 1386 tests / 0 failures at v1.0 ship

**CI/CD philosophy:**
- Automated, AI-friendly maintenance — scan issues, iterate programmatically via gh CLI
- Fast CI with high signal-to-noise ratio (5 required checks complete in <40s)
- Release Please for automated versioning via conventional commits
- Hex publishing on release tag — no manual `mix hex.publish`
- Dependabot with patch-only auto-merge

## Constraints

- **Language**: Elixir 1.15+, OTP 26+ (tested up to 1.19 / OTP 28)
- **License**: MIT
- **No Dialyzer**: Typespecs for documentation only, not enforced
- **HTTP**: Transport behaviour with Finch as default adapter
- **JSON**: Jason (ecosystem standard)
- **Stripe API version**: pinned to `2026-03-25.dahlia` (current stable at v1.0 ship); per-request + per-client override supported
- **Dependencies**: Minimal — Finch, Jason, Telemetry, Plug (for webhook), NimbleOptions (optional)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Skip Dialyzer | Feels janky; specs + pattern matching provide better value | ✓ Good — Credo strict catches what typespecs would |
| Handwritten v1, no codegen | First principles; polish over breadth | ✓ Good — shipped 14 resource families hand-crafted |
| Finch as default transport | Modern Elixir HTTP standard; mint-based, performant | ✓ Good — zero transport issues in v1.0 |
| Transport behaviour | Library shouldn't force HTTP client choice | ✓ Good — enables Mox mocking in tests |
| LatticeStripe namespace | Unique on Hex, branded | ✓ Good — no namespace conflicts |
| Foundation-first architecture | HTTP/errors/pagination/webhooks solid before resource coverage | ✓ Good — no rework in later phases |
| Integration specs primary | Real boundaries over mocks | ✓ Good — `stripe-mock` caught API shape drift |
| `from_map/1` + `@known_fields` + `extra` pattern | Survive unknown Stripe fields without crashing | ✓ Good — Phase 14-18 inherited cleanly |
| Explicit verbs over flag-update | Cancel/resume/reject/deactivate as distinct functions | ✓ Good — no `update(...status: nil)` ambiguity |
| Nine-group ExDoc layout (D-19) | Groups ordered: Client, Payments, Billing, Connect, Webhooks, Testing, Errors/Types, Telemetry, Internals | ✓ Good — HexDocs reads cleanly |
| `@moduledoc false` on internals (D-04) | Public API surface locked at 1.0 via semver contract | ✓ Good — `api_stability.md` published |
| `Request` kept public (Rule 1 deviation) | `Client.request/2` @spec references `Request.t()` — hiding it breaks docs cross-refs | ✓ Good — caught at `mix docs --warnings-as-errors` time |
| `release-as: 1.0.0` one-shot for 0.x → 1.0 jump | release-please doesn't natively graduate from pre-major | ✓ Good — cleanup PR #8 removed it post-release |
| `bump-minor-pre-major: false` post-1.0 | Normal semver kicks in; `feat:` auto-bumps 1.x → 1.(x+1) | ✓ Good — verified zero-touch on PR #8 merge |
| PII-safe custom `Inspect` for BankAccount / Card / Customer | Prevents accidental logging of sensitive fields | ✓ Good — no PII leaks in v1.0 |
| MIT license | Maximum adoption | ✓ Good — standard for Elixir ecosystem |
| Elixir 1.15+ / OTP 26+ | ~2 year coverage | ✓ Good — no user complaints about minimums |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition` or inline):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state
5. Move shipped requirements to Validated, add next-milestone requirements to Active

---
*Last updated: 2026-04-13 — v1.1 milestone (Accrue unblockers) started. v1.0.0 live on Hex.pm.*
