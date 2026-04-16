# Roadmap: LatticeStripe

## Milestones

- ✅ **v1.0 — Foundation + Billing + Connect + 1.0 Release** — Phases 1-11, 14-19 (shipped 2026-04-13 to Hex.pm) — [archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 — Accrue unblockers (metering + portal)** — Phases 20-21 (shipped 2026-04-14) — [brief](v1.1-accrue-context.md)
- 🚧 **v1.2 — Production Hardening & DX** — Phases 22-31 (in progress)

## Phases

<details>
<summary>✅ v1.0 — Foundation + Billing + Connect + 1.0 Release (Phases 1-11, 14-19) — SHIPPED 2026-04-13</summary>

- [x] Phase 1: Transport & Client Configuration (5/5 plans)
- [x] Phase 2: Error Handling & Retry (3/3 plans)
- [x] Phase 3: Pagination & Response (3/3 plans) — cursor lists, `stream!/2`, `expand:` (IDs), API version pinning
- [x] Phase 4: Customers & PaymentIntents (2/2 plans) — first resource modules, pattern validated
- [x] Phase 5: SetupIntents & PaymentMethods (2/2 plans)
- [x] Phase 6: Refunds & Checkout (2/2 plans)
- [x] Phase 7: Webhooks (2/2 plans) — HMAC + Event + Plug
- [x] Phase 8: Telemetry & Observability (2/2 plans) — request spans + webhook verify spans
- [x] Phase 9: Testing Infrastructure (3/3 plans) — stripe-mock integration, `LatticeStripe.Testing`
- [x] Phase 10: Documentation & Guides (3/3 plans) — ExDoc, 16 guides, cheatsheet, README quickstart
- [x] Phase 11: CI/CD & Release (3/3 plans) — Release Please, Hex auto-publish, Dependabot
- ~~Phases 12-13: Product/Price/Coupon/TestClock~~ — deleted in commit `39b98c9`, rebuilt in Phase 14
- [x] Phase 14: Invoices & Invoice Line Items (PR #4)
- [x] Phase 15: Subscriptions & Subscription Items (PR #4)
- [x] Phase 16: Subscription Schedules (PR #4)
- [x] Phase 17: Connect Accounts & Account Links (CNCT-01)
- [x] Phase 18: Connect Money Movement (CNCT-02..CNCT-05) — Transfer, Payout, Balance, BalanceTransaction, ExternalAccount, Charge
- [x] Phase 19: Cross-cutting Polish & v1.0 Release — API surface lock, nine-group ExDoc, `api_stability.md`, CHANGELOG Highlights, release-please 1.0.0 cut

See `.planning/milestones/v1.0-ROADMAP.md` for full phase details and decisions.

</details>

<details>
<summary>✅ v1.1 — Accrue unblockers (Phases 20-21) — SHIPPED 2026-04-14</summary>

- [x] **Phase 20: Billing Metering** — `Billing.Meter` CRUDL + `deactivate/reactivate`, four nested typed structs, `MeterEvent.create/3`, `MeterEventAdjustment.create/3`, integration tests, `guides/metering.md` (completed 2026-04-14)
- [x] **Phase 21: Customer Portal** — `BillingPortal.Session.create/3`, `Session.FlowData` nested struct, integration tests, `guides/customer-portal.md` (completed 2026-04-14)

</details>

### 🚧 v1.2 — Production Hardening & DX

- [x] **Phase 22: Expand Deserialization & Status Atomization** — typed struct dispatch for `expand:`, dot-path support, status field atomization sweep across 84+ modules, union type specs + CHANGELOG migration note (completed 2026-04-16)
- [x] **Phase 23: BillingPortal.Configuration CRUDL** — portal branding/features customization resource, Level 1+2 typed structs, Level 3+ in `extra` (completed 2026-04-16)
- [x] **Phase 24: Rate-Limit Awareness & Richer Errors** — `RateLimit-*` header capture via telemetry, fuzzy param name suggestions in `invalid_request_error` (completed 2026-04-16)
- [x] **Phase 25: Performance Guide, Per-Op Timeouts & Connection Warm-Up** — `guides/performance.md`, opt-in `Client` timeout field, Finch warm-up helper (completed 2026-04-16)
- [x] **Phase 26: Circuit Breaker & OpenTelemetry Guides** — `:fuse`-based `RetryStrategy` example guide, OTel integration guide with Honeycomb/Datadog examples (completed 2026-04-16)
- [x] **Phase 27: Request Batching** — `LatticeStripe.Batch` module with `Task.async_stream`, `try/rescue` per task, `{:ok, results} | {:error, reason}` contract (completed 2026-04-16)
- [x] **Phase 28: meter_event_stream v2** — `Billing.MeterEventStream` session-token API, `create_session/2`, event send loop, expiry handling (completed 2026-04-16)
- [ ] **Phase 29: Changeset-Style Param Builders** — optional fluent builders for `SubscriptionSchedule` phases and `BillingPortal` flows
- [ ] **Phase 30: Stripe API Drift Detection** — Mix task + GitHub Actions weekly cron, compares Stripe OpenAPI spec `@known_fields` against current modules
- [ ] **Phase 31: LiveBook Notebook** — `notebooks/stripe_explorer.livemd` interactive SDK exploration, exercises complete v1.2 API surface

## Phase Details

### Phase 20: Billing Metering
**Goal**: Elixir developers (and Accrue) can configure usage-based billing meters, report metered usage events with correct idempotency, and make corrections — all with behavior and failure modes clearly documented so the silent-failure modes of Stripe's async metering pipeline cannot silently corrupt billing data.
**Depends on**: Nothing new — all v1.0 infrastructure (Client, Transport, Resource helpers, Telemetry) unchanged.
**Requirements**: METER-01, METER-02, METER-03, METER-04, METER-05, METER-06, METER-07, METER-08, METER-09, EVENT-01, EVENT-02, EVENT-03, EVENT-04, EVENT-05, GUARD-01, GUARD-02, GUARD-03, TEST-01, TEST-03, TEST-05 (metering side), DOCS-01, DOCS-03 (Billing Metering group), DOCS-04
**Success Criteria** (what must be TRUE):
  1. A developer can call `Billing.Meter.create/3` with `formula: "sum"` and `value_settings` present, then report events via `MeterEvent.create/3`, and the phase's test suite passes against stripe-mock — including deactivate, reactivate, list-by-status, and adjust lifecycles.
  2. `Billing.Meter.create/3` raises `ArgumentError` with a clear message when `default_aggregation.formula` is `"sum"` or `"last"` and `value_settings` is absent from params — the silent-zero billing trap is blocked at call time, before any network round-trip.
  3. `MeterEvent.create/3` `@doc` documents both idempotency layers (`identifier` body field and `idempotency_key:` opt) with separate labeled explanations, and explicitly states that `{:ok, %MeterEvent{}}` is an "accepted for processing" acknowledgment — not a billing confirmation — with a pointer to the `v1.billing.meter.error_report_triggered` webhook.
  4. `MeterEventAdjustment.create/3` `@doc` shows the exact `cancel.identifier` nested param shape (not top-level `identifier`, not `id`) and unit tests assert correct `from_map/1` decoding of `cancel.identifier`.
  5. The new `guides/metering.md` contains a Monitoring section covering `v1.billing.meter.error_report_triggered` error codes, a two-layer idempotency example with a stable domain-derived `identifier`, a backdating window warning with exact error codes, and cross-links from `guides/billing.md` (or equivalent) land correctly.
**Plans:** 7/7 plans complete
Plans:
- [x] 20-01-PLAN.md — Wave 0 bootstrap (stripe-mock probe, fixtures, test skeletons)
- [x] 20-02-PLAN.md — Nested Meter.* typed structs (4 sub-modules)
- [x] 20-03-PLAN.md — Billing.Meter resource + GUARD-01 value_settings trap
- [x] 20-04-PLAN.md — Billing.MeterEvent + Inspect payload masking + async-ack @doc
- [x] 20-05-PLAN.md — Billing.MeterEventAdjustment + Cancel nested struct + GUARD-03 shape guard
- [x] 20-06-PLAN.md — guides/metering.md + ExDoc "Billing Metering" group + reciprocal crosslinks

### Phase 21: Customer Portal
**Goal**: Elixir developers (and Accrue) can create a Stripe customer portal session with a single function call, receiving a short-lived URL they can redirect customers to — with deep-link flow support and early validation that prevents server-side 400s for missing required sub-fields.
**Depends on**: Phase 20 (code-independent; Phase 20 must be planned first per locked D5, but no function in `BillingPortal.Session` calls anything in `Billing.Meter`)
**Requirements**: PORTAL-01, PORTAL-02, PORTAL-03, PORTAL-04, PORTAL-05, PORTAL-06, TEST-02, TEST-04, TEST-05 (portal side), DOCS-02, DOCS-03 (Customer Portal group)
**Success Criteria** (what must be TRUE):
  1. `BillingPortal.Session.create/3` with a valid `customer` ID returns `{:ok, %Session{url: url}}` where `url` is a non-empty string, verified in an integration test against stripe-mock.
  2. `Session.create/3` raises `ArgumentError` before any network call when `customer` is missing, and raises `ArgumentError` with a flow-type-specific message when `flow_data.type` is `"subscription_cancel"`, `"subscription_update"`, or `"subscription_update_confirm"` but the required nested sub-field (`subscription`, `items`) is absent.
  3. `Session.create/3` raises `ArgumentError` with a clear message when an unknown `flow_data.type` string is passed — unknown flow types are caught at the SDK boundary, not silently forwarded to Stripe.
  4. The `BillingPortal.Session` struct's `Inspect` implementation masks the `:url` field (the URL is a single-use auth token and must not appear in logs).
**Plans**: TBD
**UI hint**: no

### Phase 22: Expand Deserialization & Status Atomization
**Goal**: Developers who pass `expand:` options receive fully typed structs (not raw string IDs) in response fields, dot-path expand syntax works for nested list items, and every resource module consistently exposes `_atom` converters for status-like string fields.
**Depends on**: Phase 21 (all v1.0/v1.1 resource modules must be complete before the atomization sweep)
**Requirements**: EXPD-01, EXPD-02, EXPD-03, EXPD-04
**Success Criteria** (what must be TRUE):
  1. A developer who calls `PaymentIntent.retrieve/3` with `expand: ["customer"]` receives a `%Customer{}` struct in the `:customer` field — not a string ID — and the existing `{:ok, struct} | {:error, reason}` contract is unchanged.
  2. A developer can use dot-path expand syntax (`expand: ["data.customer"]`) when listing resources and receive `%Customer{}` structs in the nested `data` items.
  3. Every resource module that has a string `status` field (across all 84+ modules) exposes a `status_atom/1` (or equivalent `_atom`) converter function, audited and consistent.
  4. The `@type t()` spec for any expandable field uses a union type (`Customer.t() | String.t()`), and the CHANGELOG contains a migration note explaining the behavior change for callers who were pattern-matching on string IDs.
**Plans**: TBD

### Phase 23: BillingPortal.Configuration CRUDL
**Goal**: Developers can create, retrieve, update, and list Stripe customer portal configurations — controlling branding, feature flags, and business info — using typed structs without being surprised by Stripe's deeply nested config shape.
**Depends on**: Phase 21 (BillingPortal namespace must be established)
**Requirements**: FEAT-01
**Success Criteria** (what must be TRUE):
  1. A developer can call `BillingPortal.Configuration.create/3` with business profile and feature params and receive a `%Configuration{}` typed struct in response, verified in an integration test against stripe-mock.
  2. `BillingPortal.Configuration.list/2` returns `{:ok, %List{data: [%Configuration{}, ...]}}` and supports `stream!/2` auto-pagination.
  3. Level 1 and Level 2 nested objects (e.g., `features`, `business_profile`) are decoded into typed sub-structs; Level 3+ nesting is captured in the parent struct's `extra` map without crashing.
  4. The `BillingPortal.Configuration` module appears correctly in the ExDoc nine-group layout under the Billing group.
**Plans:** 3/3 plans complete
Plans:
- [x] 23-01-PLAN.md — Features container + 4 Level 2 sub-struct modules + fixtures + sub-struct unit tests
- [x] 23-02-PLAN.md — Top-level Configuration CRUDL resource module + unit tests
- [x] 23-03-PLAN.md — ObjectTypes registration + Session.configuration expand upgrade + ExDoc grouping + integration test
**UI hint**: no

### Phase 24: Rate-Limit Awareness & Richer Errors
**Goal**: Developers can observe Stripe rate-limit state via telemetry and receive actionable error messages that suggest the correct parameter name when they pass an invalid one — shrinking the feedback loop on the two most common integration pain points.
**Depends on**: Phase 22 (error path touched by both; expand changes must be stable before error enrichment)
**Requirements**: PERF-05, DX-01
**Success Criteria** (what must be TRUE):
  1. When Stripe returns a 429 response with a `Stripe-Rate-Limited-Reason` header, the telemetry stop event's metadata map includes a `:rate_limited_reason` key with the header value, observable by attaching a telemetry handler.
  2. When a developer passes an invalid parameter name (e.g., `payment_method_type` instead of `payment_method_types`) and Stripe returns an `invalid_request_error`, the `%Error{}` message includes a "Did you mean `:payment_method_types`?" suggestion computed via client-side fuzzy matching.
  3. The fuzzy param suggestion is purely additive — it does not change the `%Error{type}` atom, `%Error{code}` field, or any other existing `Error` struct fields, preserving all existing pattern-match contracts.
**Plans:** 3/3 plans complete
Plans:
- [x] 24-01-PLAN.md — Rate-limit telemetry pipeline (header threading + metadata enrichment + 429 warning escalation)
- [x] 24-02-PLAN.md — Fuzzy param suggestion in Error.from_response/3 (Jaro distance + global @known_fields pool)
- [x] 24-03-PLAN.md — Telemetry documentation (moduledoc table + guides/telemetry.md Rate Limiting section)

### Phase 25: Performance Guide, Per-Op Timeouts & Connection Warm-Up
**Goal**: Developers building production SaaS on LatticeStripe have a single authoritative reference for tuning Finch pool sizing, can configure resource-level timeout defaults without changing existing behavior, and can warm up connection pools on application start.
**Depends on**: Phase 24 (Client struct changes must be stable before timeout field is added)
**Requirements**: PERF-01, PERF-03, PERF-04
**Success Criteria** (what must be TRUE):
  1. A developer can read `guides/performance.md` and find production Finch pool sizing recommendations with supervision tree examples and throughput benchmarks — enough to configure a production pool without guessing.
  2. A developer can add `operation_timeouts: %{list: 60_000, search: 45_000}` to their `Client.new!/1` config and have those timeouts applied per operation type, with nil as the default (preserving the existing 30s behavior for all callers who do not opt in).
  3. A developer can call `LatticeStripe.warm_up/1` (or equivalent) on application start and have Finch connections pre-established, with the function returning `{:ok, :warmed}` on success.
  4. `guides/performance.md` includes a connection warm-up section with a complete `Application.start/2` example and explains what "warm" means in terms of observable behavior.
**Plans:** 3/3 plans complete
Plans:
- [x] 25-01-PLAN.md — Per-operation timeouts (Config schema + Client struct + classify_operation + timeout resolution + tests)
- [x] 25-02-PLAN.md — Connection warm-up (warm_up/1 + warm_up!/1 + Mox tests)
- [x] 25-03-PLAN.md — Performance guide (guides/performance.md + ExDoc wiring)

### Phase 26: Circuit Breaker & OpenTelemetry Guides
**Goal**: Developers who need cascading-failure protection or production observability have authoritative, worked-example guides — with copy-paste-ready code — without LatticeStripe bundling any new OTP processes or external runtime dependencies.
**Depends on**: Phase 25 (performance guide establishes the reliability narrative; OTel guide can reference telemetry event schema finalized in Phase 24)
**Requirements**: PERF-02, DX-04
**Success Criteria** (what must be TRUE):
  1. A developer can read a circuit breaker guide and implement `:fuse`-based protection using a custom `RetryStrategy` module — the guide includes a complete, copy-paste-ready `MyApp.FuseRetryStrategy` implementation with `:fuse` declared as a user-side dependency.
  2. The circuit breaker guide explains the failure/open/half-open state machine in prose, not just code, and explicitly documents why `:fuse` is not bundled.
  3. A developer can read an OpenTelemetry integration guide that shows how to bridge LatticeStripe telemetry events to `opentelemetry_api` with complete, runnable examples for at least two backends (Honeycomb and Datadog).
  4. The OTel guide's example code compiles cleanly (verified by doctest or a CI-excluded integration test) with `opentelemetry_api` declared as a `only: :dev` dependency.
**Plans:** 2/2 plans complete
Plans:
- [x] 26-01-PLAN.md — Config foundation + circuit breaker guide + :fuse integration test
- [x] 26-02-PLAN.md — OpenTelemetry guide + Honeycomb/Datadog examples + OTel integration test

### Phase 27: Request Batching
**Goal**: Developers can execute multiple independent Stripe API calls concurrently with a single ergonomic helper that returns structured results per-call without crashing the caller when individual requests fail or time out.
**Depends on**: Phase 24 (rate-limit awareness should be stable so batch can emit rate-limit telemetry accurately; DX-01 error enrichment applies to batch error results)
**Requirements**: DX-02
**Success Criteria** (what must be TRUE):
  1. A developer can call `LatticeStripe.Batch.run/2` (or equivalent) with a list of `{module, :function, args}` tuples and receive a list of `{:ok, result} | {:error, %Error{}}` tuples — one per input — preserving order.
  2. When an individual task raises or times out, its slot in the result list contains `{:error, %Error{}}` and the caller process is not crashed — all other tasks continue to completion.
  3. The module's `@doc` includes a "when to use" note explaining that `Batch.run/2` is for fan-out patterns (e.g., fetching customer + subscriptions + invoices in parallel) and is not a substitute for Stripe's native batch API.
**Plans:** 1/1 plans complete
Plans:
- [x] 27-01-PLAN.md — TDD: Batch.run/3 implementation + unit tests + ExDoc grouping

### Phase 28: meter_event_stream v2
**Goal**: Developers who need high-throughput metering can send batches of meter events via Stripe's v2 session-token API — creating a short-lived session, sending event batches within it, and handling session expiry gracefully.
**Depends on**: Phase 22 (expand deserialization must be stable; Phase 27 establishes concurrent request patterns that inform stream session management)
**Requirements**: FEAT-02
**Success Criteria** (what must be TRUE):
  1. A developer can call `LatticeStripe.Billing.MeterEventStream.create_session/2` and receive a session struct containing a token and `expires_at` timestamp.
  2. A developer can send a batch of meter events via `MeterEventStream.send_events/3` within an active session and receive `{:ok, results}` or a clear `{:error, :session_expired}` error when the session has expired.
  3. The module's `@doc` clearly documents that `MeterEventStream` cannot reuse `Client.request/2` directly — the session-token auth model is different — and shows the correct two-step (create session, send events) usage pattern.
  4. Integration tests against stripe-mock (or a documented skip with a clear stripe-mock support flag) cover the session create + event send lifecycle.
**Plans:** 2/2 plans complete
Plans:
- [x] 28-01-PLAN.md — Session struct + fixture + Inspect masking
- [x] 28-02-PLAN.md — MeterEventStream module + unit tests + integration skip + ExDoc + guide
**UI hint**: no

### Phase 29: Changeset-Style Param Builders
**Goal**: Developers building complex nested Stripe params for subscription schedules and billing portal flows have an optional fluent builder API that prevents typos in deeply nested keys and provides compile-assisted documentation — without replacing the existing map-based API.
**Depends on**: Phase 23 (BillingPortal.Configuration must be complete so FlowData builders have a stable target shape)
**Requirements**: DX-03
**Success Criteria** (what must be TRUE):
  1. A developer can use `LatticeStripe.Builders.SubscriptionSchedule` to construct a phase params map via chained function calls and pass the result directly to `SubscriptionSchedule.create/3` — the builder output is a plain map, not a special struct.
  2. A developer can use `LatticeStripe.Builders.BillingPortal` to construct `flow_data` params for portal session creation — builder functions match the valid `type` atoms documented in `BillingPortal.Session`.
  3. Both builder modules are marked `@doc` optional in their module docs — they coexist with the existing map-based API and do not replace it.
**Plans:** 2 plans
Plans:
- [ ] 29-01-PLAN.md — TDD: SubscriptionSchedule changeset-style builder (new/0, setter chain, phase sub-builder, build/1)
- [ ] 29-02-PLAN.md — TDD: BillingPortal FlowData builder (4 named constructors) + ExDoc Param Builders group

### Phase 30: Stripe API Drift Detection
**Goal**: CI automatically detects when Stripe's OpenAPI specification adds new fields or resources that are not yet reflected in LatticeStripe's `@known_fields` — surfacing drift as a PR comment or failed check before it reaches users.
**Depends on**: Phase 22 (the atomization sweep establishes accurate, consistent `@known_fields` baselines across all 84+ modules that drift detection will compare against)
**Requirements**: DX-06
**Success Criteria** (what must be TRUE):
  1. A developer can run `mix lattice_stripe.check_drift` locally and see a report listing any fields present in Stripe's published OpenAPI spec that are absent from the corresponding module's `@known_fields`.
  2. A GitHub Actions cron job runs `mix lattice_stripe.check_drift` weekly and opens a draft PR or creates an issue when drift is detected — with the diff clearly labeled per resource module.
  3. The Mix task exits with a non-zero code when drift is found, making it usable as a CI gate if desired.
**Plans**: TBD

### Phase 31: LiveBook Notebook
**Goal**: Developers new to LatticeStripe can explore the complete v1.2 API surface interactively — from basic auth through payments, subscriptions, metering, and portal flows — without reading documentation linearly.
**Depends on**: Phase 30 (all v1.2 features must be shipped and stable before the notebook exercises them)
**Requirements**: DX-05
**Success Criteria** (what must be TRUE):
  1. A developer can open `notebooks/stripe_explorer.livemd` in LiveBook and run all cells — the notebook installs dependencies via `Mix.install/2`, connects to stripe-mock (or documents how to configure a test API key), and produces visible output for each section.
  2. The notebook covers at least: client configuration, payment intent lifecycle, subscription creation, meter event reporting, and portal session creation — with explanatory prose between each section.
  3. The notebook's `Mix.install/2` block pins `lattice_stripe` to the released v1.2.x version (or `path: "."` for local development) and includes `kino` for interactive widgets.
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-11, 14-19 | v1.0 | All | ✅ Shipped | 2026-04-13 |
| 20. Billing Metering | v1.1 | 7/7 | ✅ Complete | 2026-04-14 |
| 21. Customer Portal | v1.1 | 4/4 | ✅ Complete | 2026-04-14 |
| 22. Expand Deserialization & Status Atomization | v1.2 | 4/4 | Complete    | 2026-04-16 |
| 23. BillingPortal.Configuration CRUDL | v1.2 | 3/3 | Complete    | 2026-04-16 |
| 24. Rate-Limit Awareness & Richer Errors | v1.2 | 3/3 | Complete    | 2026-04-16 |
| 25. Performance Guide, Per-Op Timeouts & Connection Warm-Up | v1.2 | 3/3 | Complete    | 2026-04-16 |
| 26. Circuit Breaker & OpenTelemetry Guides | v1.2 | 2/2 | Complete    | 2026-04-16 |
| 27. Request Batching | v1.2 | 1/1 | Complete    | 2026-04-16 |
| 28. meter_event_stream v2 | v1.2 | 2/2 | Complete    | 2026-04-16 |
| 29. Changeset-Style Param Builders | v1.2 | 0/2 | Not started | - |
| 30. Stripe API Drift Detection | v1.2 | 0/? | Not started | - |
| 31. LiveBook Notebook | v1.2 | 0/? | Not started | - |
