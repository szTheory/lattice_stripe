# Research Summary: LatticeStripe v1.2 Production Hardening & DX

**Synthesized:** 2026-04-16
**Sources:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md

## Executive Summary

LatticeStripe v1.1 is a published Elixir Stripe SDK with 84+ resource modules, 1,488 tests, and full coverage of Payments, Billing, Connect, Metering, and Customer Portal. The v1.2 milestone is hardening and DX polish on a stable, already-deployed library. The dominant constraint is backward compatibility: all 14 target features must slot into the existing architecture without breaking the `{:ok, struct} | {:error, %Error{}}` contract.

The recommended execution strategy is a 3-wave approach: Wave 1 addresses the #1 ergonomic gap (expand deserialization returning typed structs) along with BillingPortal.Configuration; Wave 2 adds rate-limit telemetry, concurrent helpers, per-operation timeouts, and richer errors; Wave 3 completes the story with the v2 metering endpoint, param builders, drift detection CI, and the Livebook notebook.

## Stack Additions

**Zero new runtime dependencies.** The v1.0/v1.1 `deps/0` block ships unchanged to users.

| Addition | Type | Purpose |
|----------|------|---------|
| `:fuse ~> 2.5` | User-side optional | Circuit breaker — documented, not bundled (starts OTP processes) |
| `opentelemetry_api ~> 1.5` | `only: :dev` | Guide doctest compilation only |
| `opentelemetry_telemetry ~> 1.1` | User-side | Bridge LatticeStripe telemetry to OTel (user declares) |
| Kino `~> 0.19` | In-notebook `Mix.install` | LiveBook notebook interactivity |

Anti-features explicitly rejected: `:fuse` as bundled dep (violates no-global-state), global rate-limit auto-throttling (blocks BEAM scheduler), automatic expand for all requests (obscures cost).

## Feature Classification

### Table Stakes (must ship)
- Expand deserialization (EXPD-02/03) — every official Stripe SDK does this
- Status atomization audit (EXPD-05) — consistency sweep
- BillingPortal.Configuration CRUDL — deferred from v1.1

### Differentiators (competitive edge)
- Rate-limit awareness via telemetry — no Elixir SDK does this
- Request batching / concurrent helpers — unique to LatticeStripe
- Richer error context with param suggestions — unique to LatticeStripe
- Circuit breaker guide — production-grade guidance
- OpenTelemetry integration guide — fills ecosystem gap
- Per-operation timeout tuning — fine-grained control

### Completeness (rounds out the story)
- meter_event_stream v2 — deferred from v1.1
- Changeset-style param builders — ergonomic sugar
- Stripe API drift detection — CI hygiene
- LiveBook notebook — onboarding artifact
- Connection warm-up helper — production convenience
- Performance guide — documentation

## Architecture Integration

All 14 features have clean integration points. No restructuring needed.

| Feature | Integration Point | Type |
|---------|-------------------|------|
| Expand deserialization | `from_map/1` in each resource | New `LatticeStripe.Expand` dispatch module |
| BillingPortal.Configuration | Existing resource pattern | New CRUDL module (standard) |
| Rate-limit awareness | `Telemetry.build_stop_metadata/4` | Additive metadata key |
| Richer errors | `Error.from_json/2` | Inline enrichment |
| Request batching | Wraps `Client.request/2` | New `LatticeStripe.Batch` module |
| Per-op timeouts | `Client` struct | New opt-in field (nil default) |
| Circuit breaker | `RetryStrategy` behaviour | Guide + example module |
| meter_event_stream | Client extension | `:auth_token` + `:content_type` opts |
| Changeset builders | Pre-Client | New builder modules |
| Drift detection | CI tooling | Mix task + GHA cron |
| LiveBook | `.livemd` file | No code changes |
| OTel guide | Documentation | No code changes |
| Performance guide | Documentation | No code changes |
| Connection warm-up | Finch API | Thin wrapper |

## Top 5 Pitfalls

1. **Expand field type union breaks downstream pattern matches silently** — `customer` changes from `String.t()` to `Customer.t() | String.t()`. Fix: `is_map(val)` guard in `from_map/1`, union `@type t()`, prominent CHANGELOG callout.

2. **Per-operation timeout defaults silently change existing behavior** — any hard-coded timeout constant changes behavior for all callers. Fix: opt-in via `operation_timeouts: nil` Client field.

3. **BillingPortal.Configuration 4-level nesting causes struct explosion** — ~10 nested modules that all drift with Stripe updates. Fix: cap at Level 2 typed, Level 3+ in `extra`.

4. **`Task.async_stream` in batch helper propagates raises to caller** — breaks `{:ok, ...} | {:error, ...}` contract. Fix: `try/rescue` per task, map `{:exit, :timeout}` to `{:error, %Error{}}`.

5. **meter_event_stream v2 requires session token auth** — cannot reuse `Client.request/2` as-is. Fix: `create_session/2` first, `expires_at` check before every send.

## Suggested Phase Structure (10 phases)

1. **Expand Deserialization** (EXPD-05 + EXPD-02/03) — status sweep + typed expand dispatch
2. **BillingPortal.Configuration CRUDL** — standard resource, can parallel with Phase 1
3. **Rate-Limit Awareness + Richer Errors** — both modify error path, group to minimize touchpoints
4. **Performance Guide + Per-Op Timeouts + Connection Warm-Up** — guide first, then helpers
5. **Request Batching** — pure utility on top of Client
6. **Circuit Breaker Guide + OpenTelemetry Guide** — documentation-only
7. **meter_event_stream v2** — most architecturally novel, deferred until simpler phases validate patterns
8. **Changeset-Style Param Builders** — scoped to SubscriptionSchedule + BillingPortal.FlowData
9. **Stripe API Drift Detection** — ships after Phase 1 establishes accurate `@known_fields` baselines
10. **LiveBook Notebook** — ships last, exercises complete v1.2 API surface

## Research Flags

**Needs additional research during planning:**
- Phase 7 (meter_event_stream): Confirm stripe-mock v2 endpoint support

**Standard patterns, skip research-phase:**
- All other phases map to well-established Elixir patterns

## Confidence: HIGH

All package versions confirmed on Hex.pm April 2026. All integration points mapped via direct codebase inspection. All pitfalls traced to specific code patterns with sources.
