# Requirements: LatticeStripe v2.0 Billing & Connect

**Milestone:** v2.0 Billing & Connect
**Target Hex release:** `lattice_stripe` v0.3.0 (with optional v0.3.0-rc1 cut at Phase 16)
**Philosophy:** SDK-first. Every requirement serves the Elixir Stripe SDK mission (completeness, consistency, DX, correctness). Downstream consumers (notably Accrue) are canaries, not design drivers.

## v2.0 Requirements

Promoted from v1's deferred "v2 Requirements" list and expanded with new items surfaced during the v2.0 planning + research cycle.

### Billing — Catalog

- [ ] **BILL-01**: Developer can manage Products — create, retrieve, update, list, stream, search
- [ ] **BILL-02**: Developer can manage Prices — create, retrieve, update, list, stream, search (no delete; Stripe API constraint)
- [ ] **BILL-06**: Developer can manage Coupons — create, retrieve, delete, list, stream (no update; Stripe API constraint)
- [ ] **BILL-06b**: Developer can manage Promotion Codes — create, retrieve, update, list, stream. Search is NOT supported: verified against Stripe OpenAPI spec (`spec3.sdk.json`) during Phase 12 discussion — the `/v1/promotion_codes/search` endpoint does not exist (only 7 resources have search: charges, customers, invoices, payment_intents, prices, products, subscriptions). Discovery path is `list/2` with filters (`code`, `coupon`, `customer`, `active`) per https://docs.stripe.com/api/promotion_codes/list.

### Billing — Testing Infrastructure

- [ ] **BILL-08**: Developer can manage Billing Test Clocks — create, retrieve, list, stream, delete, advance
- [ ] **BILL-08b**: Developer can await asynchronous clock advancement via an SDK helper (`advance_and_wait/3` or equivalent) with configurable timeout, returning `{:error, :timeout}` on failure
- [ ] **BILL-08c**: Developer can use a high-level test helper module (`LatticeStripe.Testing.TestClock`) to coordinate test clock + subscription lifecycle fixtures in their own test suite

### Billing — Invoices

- [ ] **BILL-04**: Developer can manage Invoices — create, retrieve, update, list, stream, search
- [ ] **BILL-04b**: Developer can finalize, void, mark as uncollectible, pay, and send Invoices via dedicated action verbs
- [ ] **BILL-04c**: Developer can preview upcoming Invoice charges via `upcoming/2` returning an Invoice-shaped struct with `id: nil` (proration preview before confirming a plan change)
- [ ] **BILL-10**: Developer can list Invoice Line Items for an invoice (read-only child resource, also surfaced as `Invoice.lines` typed field)

### Billing — Subscriptions

- [ ] **BILL-03**: Developer can manage Subscriptions — create, retrieve, update, list, stream, search
- [ ] **BILL-03b**: Developer can cancel Subscriptions in two modes: immediate (`cancel/2`) and scheduled at period end (`cancel/3` with `cancel_at_period_end: true`)
- [ ] **BILL-03c**: Developer can pause and resume Subscriptions via dedicated action verbs (`pause/3`, `resume/3`) mapping to Stripe's dedicated endpoint
- [ ] **BILL-03d**: Developer can manage Subscription Items — create, retrieve, update, delete, list (search not supported by Stripe)
- [ ] **BILL-03e**: Subscription `@moduledoc` documents the complete lifecycle state machine — `incomplete → incomplete_expired` (23h one-way edge), `active → past_due → unpaid → canceled`, `cancel_at_period_end = true` keeping status `active` until period end, and webhook event sequence
- [ ] **BILL-03f**: Developer can query Subscription lifecycle helpers — `status_is_terminal?/1`, `cancellation_pending?/1`
- [ ] **UTIL-03**: `LatticeStripe.Billing.ProrationBehavior.validate!/1` validates `proration_behavior` values (`"create_prorations"`, `"always_invoice"`, `"none"`) with clear ArgumentError messages
- [ ] **UTIL-04**: Client struct gains additive `require_explicit_proration: boolean` field (default `false`). When `true`, calls to Subscription/Schedule/Invoice mutation functions that omit `proration_behavior` return `{:error, %Error{type: :proration_required}}`. When `false` (default), the param passes through to Stripe transparently, matching stripe-ruby/node/python SDK parity. Documented as opt-in strict mode, not surprising default.

### Billing — Schedules

- [ ] **BILL-09**: Developer can manage Subscription Schedules — create, retrieve, update, cancel, release, list, stream
- [ ] **BILL-09b**: Subscription struct surfaces `:schedule` as a typed field so callers can pattern-match `%Subscription{schedule: nil}` vs managed subscriptions
- [ ] **BILL-09c**: `Subscription.update/3` `@doc` warns prominently that mutations to a schedule-owned subscription will conflict with the schedule's phase transitions; recommends `SubscriptionSchedule.release/2` as the escape hatch

### Connect — Accounts & Links

- [ ] **CNCT-01**: Developer can manage connected Accounts — create, retrieve, update, delete (where Stripe permits), list, stream, with clear documentation of Standard/Express/Custom type constraints
- [ ] **CNCT-01b**: Developer can create AccountLinks for onboarding and update flows
- [ ] **CNCT-01c**: Developer can create LoginLinks for Express dashboard access
- [ ] **CNCT-06**: Developer can construct a Connect-scoped client via `LatticeStripe.Client.with_account/2` returning a new Client struct with the `Stripe-Account` header baked in, making per-tenant code paths explicit and greppable
- [ ] **CNCT-07**: `LatticeStripe.Connect` namespace module ships with a top-level warning documenting that `stripe_account` is a context switch (platform vs connected account are different data universes), with a Context Matrix table documenting which resources must/must-not carry the header

### Connect — Money Movement

- [ ] **CNCT-02**: Developer can create and retrieve Transfers, reverse them, update metadata, and list/stream
- [ ] **CNCT-02b**: Developer can create, retrieve, update, cancel, reverse Payouts and list/stream
- [ ] **CNCT-05**: Developer can retrieve Balance (singleton — no ID, scoped to Connect context via `stripe_account` header)
- [ ] **CNCT-05b**: Developer can retrieve and list/stream Balance Transactions
- [ ] **CNCT-04**: Connect guide documents destination charges (via existing v1 `PaymentIntent` with `transfer_data` / `on_behalf_of`) and separate charges + transfers patterns with working code examples

### Cross-cutting SDK utilities

- [ ] **UTIL-01**: `LatticeStripe.EventType` exhaustive catalog of Stripe webhook event types for API version `2026-03-25.dahlia`, organized into groups (`billing_events/0`, `payment_events/0`, `connect_events/0`, `subscription_events/0`, `invoice_events/0`, `all/0`). Each event exposed as a `@attribute` and a matching `foo/0` function. Constants are strings (matching wire format), not atoms.
- [ ] **UTIL-01b**: Mix task `mix lattice_stripe.gen.event_types` fetches Stripe's OpenAPI spec (cached to `test/fixtures/stripe_openapi_events.json`) and emits a diff against the EventType module; weekly GitHub Actions workflow runs the diff check and opens an issue on drift
- [ ] **UTIL-01c**: ExUnit test tagged `:openapi_sync` diffs the vendored fixture against `LatticeStripe.EventType.all/0` to catch drift in CI
- [ ] **UTIL-02**: `LatticeStripe.Search` module ships as a thin documentation facade — every `search/2` `@doc` links to it, and the module explains the search pagination shape (`page`/`next_page` vs list's `starting_after`/`ending_before`). Search auto-pagination already works transparently via `List.stream!/2`; no new engine module.
- [ ] **UTIL-05**: `LatticeStripe.Event.created_at/1` helper returns a `DateTime` from the event's `created` unix timestamp, making "order by created time" ergonomic for out-of-order webhook handlers
- [ ] **UTIL-06**: Every `search/2` function's `@doc` includes an eventual-consistency callout warning that resources created within ~1 second may not yet appear in search results

### Testing & CI

- [ ] **TEST-07**: Integration test tier split — stripe-mock tier (fast, always runs) plus a new real-Stripe-test-mode tier tagged `:real_stripe` and gated by `STRIPE_TEST_SECRET_KEY` env var, running nightly in CI for stateful scenarios stripe-mock cannot simulate (subscription lifecycle, invoice auto-advance, test clock effects, schedule phase transitions)
- [ ] **TEST-08**: Integration test suite for every new resource passes against stripe-mock via the existing Docker infrastructure
- [ ] **TEST-09**: `test/support/billing_case.ex` ExUnit CaseTemplate coordinates test clock + customer + subscription fixtures with automatic clock cleanup (internal-only, not shipped in hex docs)
- [ ] **TEST-10**: `mix lattice_stripe.test_clock.cleanup` Mix task (or equivalent ExUnit helper) lists and deletes test clocks tagged with a test marker metadata key, preventing the 100-clock Stripe account limit from breaking CI

### Documentation

- [ ] **DOCS-05**: Billing guide (`guides/billing.md`) — install to first Subscription with explicit `proration_behavior`, explains the Stripe Billing data model for Elixir developers new to Stripe, covers every new resource with working code examples
- [ ] **DOCS-06**: Connect guide (`guides/connect.md`) — account type decision matrix (Standard/Express/Custom), Context Matrix for `stripe_account` header scoping, destination charges vs separate charges patterns, worked example using `Client.with_account/2`
- [ ] **DOCS-07**: Subscription lifecycle reference documentation — state machine diagram, every state transition documented, `incomplete_expired` 23-hour window called out, `cancel_at_period_end` behavior, `pause/resume` vs `pause_collection` param distinction
- [ ] **DOCS-08**: Invoice lifecycle reference documentation — draft/open/paid/uncollectible/void states, auto-advance behavior and the ~1h race window, canonical order of operations for manual invoicing
- [ ] **DOCS-09**: Testing guide updated with two-tier strategy, TestClock usage patterns, and `:real_stripe` tag convention
- [ ] **DOCS-10**: Webhooks guide updated with "Handling out-of-order events" section using `Event.created_at/1` helper and idempotent-upsert pattern
- [ ] **DOCS-11**: README "Billing" and "Connect" sections with short worked examples; updated version badge for v0.3.0

### Release

- [ ] **REL-01**: Conventional commit scope discipline documented in CONTRIBUTING — `feat(billing):`, `feat(connect):`, `feat(sdk):` conventions for Release Please v4
- [ ] **REL-02**: Milestone smoke test in Phase 19 exercises end-to-end Product → Price → Customer → Subscription (with explicit `proration_behavior`) → Invoice → pay against stripe-mock, proving the whole milestone composes into a working billing flow
- [ ] **REL-03**: Optional v0.3.0-rc1 pre-release mechanism decided at Phase 16 transition (manual tag vs Release Please prerelease manifest)
- [ ] **REL-04**: v0.3.0 final published to Hex via Release Please after Phase 19 merges to main

## Traceability

Every v2.0 requirement is mapped to exactly one phase. 53 of 53 mapped.

| Requirement | Phase    | Status  |
|-------------|----------|---------|
| BILL-01     | Phase 12 | Pending |
| BILL-02     | Phase 12 | Pending |
| BILL-06     | Phase 12 | Pending |
| BILL-06b    | Phase 12 | Pending |
| BILL-08     | Phase 13 | Pending |
| BILL-08b    | Phase 13 | Pending |
| BILL-08c    | Phase 13 | Pending |
| TEST-09     | Phase 13 | Pending |
| TEST-10     | Phase 13 | Pending |
| BILL-04     | Phase 14 | Pending |
| BILL-04b    | Phase 14 | Pending |
| BILL-04c    | Phase 14 | Pending |
| BILL-10     | Phase 14 | Pending |
| BILL-03     | Phase 15 | Pending |
| BILL-03b    | Phase 15 | Pending |
| BILL-03c    | Phase 15 | Pending |
| BILL-03d    | Phase 15 | Pending |
| BILL-03e    | Phase 15 | Pending |
| BILL-03f    | Phase 15 | Pending |
| UTIL-03     | Phase 15 | Pending |
| UTIL-04     | Phase 15 | Pending |
| BILL-09     | Phase 16 | Pending |
| BILL-09b    | Phase 16 | Pending |
| BILL-09c    | Phase 16 | Pending |
| REL-03      | Phase 16 | Pending |
| CNCT-01     | Phase 17 | Pending |
| CNCT-01b    | Phase 17 | Pending |
| CNCT-01c    | Phase 17 | Pending |
| CNCT-06     | Phase 17 | Pending |
| CNCT-07     | Phase 17 | Pending |
| CNCT-02     | Phase 18 | Pending |
| CNCT-02b    | Phase 18 | Pending |
| CNCT-05     | Phase 18 | Pending |
| CNCT-05b    | Phase 18 | Pending |
| CNCT-04     | Phase 18 | Pending |
| UTIL-01     | Phase 19 | Pending |
| UTIL-01b    | Phase 19 | Pending |
| UTIL-01c    | Phase 19 | Pending |
| UTIL-02     | Phase 19 | Pending |
| UTIL-05     | Phase 19 | Pending |
| UTIL-06     | Phase 19 | Pending |
| TEST-07     | Phase 19 | Pending |
| TEST-08     | Phase 19 | Pending |
| DOCS-05     | Phase 19 | Pending |
| DOCS-06     | Phase 19 | Pending |
| DOCS-07     | Phase 19 | Pending |
| DOCS-08     | Phase 19 | Pending |
| DOCS-09     | Phase 19 | Pending |
| DOCS-10     | Phase 19 | Pending |
| DOCS-11     | Phase 19 | Pending |
| REL-01      | Phase 19 | Pending |
| REL-02      | Phase 19 | Pending |
| REL-04      | Phase 19 | Pending |

## Future Requirements (Deferred Beyond v2.0)

### v0.4.x — Tier 3 High-Value

- **BILL-05**: BillingPortal Sessions and Configuration
- **BILL-12**: CreditNote with `preview/2` and `void/2`
- **BILL-13**: TaxRate
- **BILL-14**: TaxId (customer-scoped)
- **BILL-15**: CustomerBalanceTransaction (customer-scoped)

### v0.5.x — Tier 4 Usage-Based Billing

- **BILL-07**: Billing.Meter, Billing.MeterEvent, Billing.MeterEventAdjustment, Billing.MeterEventSummary

### v0.6.x — Tier 5 B2B Sales

- **BILL-16**: Quote lifecycle (create, retrieve, update, finalize, accept, cancel, list, line item listing)

### Carried Forward from v1 Known Gaps

- **EXPD-02**: Expanded objects deserialized into typed structs, unexpanded remain as string IDs
- **EXPD-03**: Nested expansion support (e.g., `expand: ["data.customer"]`)
- **EXPD-05**: Pattern-matchable domain types use atoms for status fields (e.g., `:succeeded`)

These can be promoted to a future milestone when typed-struct deserialization becomes a blocker.

### Always Deferred (Out of Scope)

- **CNCT-03**: Destination charges vs separate charge/transfer patterns as SDK primitives (documented in Connect guide instead — these are usage patterns, not new resources)
- **ADVN-01**: v2 API namespace support and thin events
- **ADVN-02**: Code generation from Stripe OpenAPI spec
- **ADVN-03**: Tax, Identity, Treasury, Issuing, Terminal resource coverage

## Out of Scope (Explicit Exclusions)

| Feature | Reason |
|---------|--------|
| Mandatory `proration_behavior` enforcement in default mode | Stripe's own SDKs (ruby/node/python) pass through to Stripe defaults; forcing a required keyword would surprise developers migrating from stripe-ruby. Strict mode ships as opt-in via `require_explicit_proration: true` client flag. |
| Higher-level billing abstractions (Pay gem style) | Accrue is the separate project being built for this. `lattice_stripe` is the SDK; opinionated wrappers live one layer up. |
| Global module-level configuration | v1 design decision — breaks multi-tenancy, test isolation, concurrent usage. Client struct remains passed explicitly. |
| Ecto dependency | v1 design decision — API client should not force Ecto on users. |
| Dialyzer/Dialyxir | v1 design decision — typespecs for documentation only. |
| Typed struct deserialization for expanded objects | Deferred to own milestone (EXPD-02/03/05). Requires careful type design; not additive to v2 scope. |
| Webhook event ordering guarantees at SDK level | Fundamentally impossible — at-least-once Stripe delivery semantics mean the SDK cannot guarantee ordering. We document the pattern (idempotent upsert by ID, order by `created`) and ship the `Event.created_at/1` helper instead. |
| Auto-retry on search eventual consistency | Hides the semantic from callers and wastes quota. stripe-ruby and stripe-node both document the delay without retrying; we match. |
