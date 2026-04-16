# Requirements: LatticeStripe v1.2 — Production Hardening & DX

**Defined:** 2026-04-16
**Milestone:** v1.2 (Production Hardening & DX)
**Core Value:** Elixir developers can integrate Stripe payments into their applications with confidence — correct, well-documented, and unsurprising.

## v1.2 Requirements

Requirements for v1.2 release. Each maps to roadmap phases.

### Expand Deserialization

- [ ] **EXPD-01**: Developer can pass `expand: ["customer"]` and receive a typed `%Customer{}` struct instead of a string ID in the response
- [ ] **EXPD-02**: Developer can use dot-path expand syntax (`expand: ["data.customer"]`) to expand nested list items
- [ ] **EXPD-03**: All status-like string fields across all 84+ resource modules have consistent `_atom` converter functions
- [ ] **EXPD-04**: Expanded fields use union types (`Customer.t() | String.t()`) in `@type t()` specs with clear CHANGELOG migration note

### Performance & Reliability

- [ ] **PERF-01**: Developer can read a `guides/performance.md` guide with production Finch pool sizing recommendations, supervision tree examples, and throughput tuning
- [ ] **PERF-02**: Developer can implement a circuit breaker pattern using a documented `RetryStrategy` example with `:fuse` (user-side dep, not bundled)
- [ ] **PERF-03**: Developer can call a connection warm-up helper to pre-establish Finch connections on application start
- [ ] **PERF-04**: Developer can configure per-operation timeout defaults via an opt-in `Client` field (nil default preserves existing 30s behavior)
- [ ] **PERF-05**: Rate-limit information from Stripe responses (`Stripe-Rate-Limited-Reason` on 429s) is exposed via telemetry stop event metadata

### Developer Experience

- [ ] **DX-01**: When a developer passes an invalid parameter name, the error message suggests the closest valid param name (client-side fuzzy matching)
- [ ] **DX-02**: Developer can execute multiple API calls concurrently via a `LatticeStripe.Batch` module using `Task.async_stream` with proper error handling (no linked task crashes)
- [ ] **DX-03**: Developer can use optional changeset-style param builders for complex nested params (scoped to SubscriptionSchedule phases and BillingPortal flows)
- [ ] **DX-04**: Developer can read an OpenTelemetry integration guide connecting LatticeStripe telemetry events to `opentelemetry_api` with worked examples (Honeycomb, Datadog)
- [ ] **DX-05**: Developer can explore the SDK interactively via a `notebooks/stripe_explorer.livemd` LiveBook notebook
- [ ] **DX-06**: CI detects when Stripe's OpenAPI spec adds new fields/resources not yet in LatticeStripe's `@known_fields` via a weekly cron job + Mix task

### Feature Completion

- [ ] **FEAT-01**: Developer can create, retrieve, update, and list `BillingPortal.Configuration` resources with typed structs (Level 1 + Level 2 typed, Level 3+ in `extra`)
- [ ] **FEAT-02**: Developer can send high-throughput meter events via `LatticeStripe.Billing.MeterEventStream` using Stripe's v2 session-token API (create session, send events, handle expiry)

## v1.3+ Requirements

Deferred to future release. Tracked but not in current roadmap.

### Specialist Stripe Families

- **SPEC-01**: Tax API (`/v1/tax/*`) resource modules
- **SPEC-02**: Identity API (`/v1/identity/*`) resource modules
- **SPEC-03**: Treasury API (`/v1/treasury/*`) resource modules
- **SPEC-04**: Issuing API (`/v1/issuing/*`) resource modules
- **SPEC-05**: Terminal API (`/v1/terminal/*`) resource modules

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| `:fuse` as bundled runtime dep | Starts OTP processes; violates library's no-global-state philosophy. Ship as user-side guide instead. |
| Global rate-limit auto-throttling | Blocks BEAM scheduler; application-layer concern, not SDK concern |
| Automatic `expand` on all requests | Obscures API cost; expand must be explicit per-request |
| Dialyzer/Dialyxir | Explicitly excluded per project constraints; typespecs are documentation-only |
| Code generation from OpenAPI spec | v1.x is handwritten for polish; generation is a future consideration |
| Ecto-based param builders | Database library has no place in an HTTP client SDK |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| EXPD-01 | Phase 22 | Pending |
| EXPD-02 | Phase 22 | Pending |
| EXPD-03 | Phase 22 | Pending |
| EXPD-04 | Phase 22 | Pending |
| PERF-01 | Phase 25 | Pending |
| PERF-02 | Phase 26 | Pending |
| PERF-03 | Phase 25 | Pending |
| PERF-04 | Phase 25 | Pending |
| PERF-05 | Phase 24 | Pending |
| DX-01 | Phase 24 | Pending |
| DX-02 | Phase 27 | Pending |
| DX-03 | Phase 29 | Pending |
| DX-04 | Phase 26 | Pending |
| DX-05 | Phase 31 | Pending |
| DX-06 | Phase 30 | Pending |
| FEAT-01 | Phase 23 | Pending |
| FEAT-02 | Phase 28 | Pending |

**Coverage:**
- v1.2 requirements: 17 total
- Mapped to phases: 17
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-16*
*Last updated: 2026-04-16 after roadmap creation (all 17 requirements mapped to Phases 22-31)*
