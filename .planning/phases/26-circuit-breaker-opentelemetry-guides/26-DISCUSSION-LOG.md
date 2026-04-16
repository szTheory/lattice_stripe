# Phase 26: Circuit Breaker & OpenTelemetry Guides - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 26-circuit-breaker-opentelemetry-guides
**Areas discussed:** Circuit breaker guide depth, OTel bridge approach, Guide placement, Verification strategy
**Mode:** --auto (all decisions auto-selected)

---

## Circuit Breaker Guide Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Full worked example with :fuse | Complete MyApp.FuseRetryStrategy with state machine prose, installation, monitoring, testing | ✓ |
| Minimal pointer to extending guide | Keep brief, just add :fuse dep details to existing example | |
| Cookbook-style snippets | Multiple small examples without full module | |

**User's choice:** [auto] Full worked example with :fuse (recommended default — SC-1 and SC-2 explicitly require complete module + prose explanation)
**Notes:** Existing extending guide sketch stays as-is; dedicated guide is the authoritative version.

---

## OTel Bridge Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated handler module | Single MyApp.StripeOtelHandler with :telemetry.attach_many/4 | ✓ |
| Inline handler functions | Anonymous functions passed directly to :telemetry.attach/4 | |
| Auto-bridge with opentelemetry_telemetry | Use the opentelemetry_telemetry library for zero-code bridging | |

**User's choice:** [auto] Dedicated handler module (recommended default — matches telemetry guide's existing patterns, most copy-paste-ready)
**Notes:** Claude has discretion on whether to also mention opentelemetry_telemetry as an alternative.

---

## Guide Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Guides group alongside existing guides | Same ExDoc group, after performance.md | ✓ |
| New "Advanced" group | Separate ExDoc group for advanced topics | |

**User's choice:** [auto] Guides group alongside existing guides (recommended default — consistent with all 18 existing guides)
**Notes:** Order: performance.md → circuit-breaker.md → opentelemetry.md flows the reliability narrative.

---

## Verification Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| CI-excluded integration test | Tagged tests that compile and run guide examples | ✓ |
| Doctests in guide | Elixir doctests embedded in the markdown | |
| Manual verification only | No automated verification | |

**User's choice:** [auto] CI-excluded integration test (recommended default — SC-4 mentions "doctest or CI-excluded integration test"; tagged tests are more realistic for examples requiring external deps)
**Notes:** Tags: @tag :otel_integration and @tag :fuse_integration, excluded from default mix test.

---

## Claude's Discretion

- Exact :fuse tolerance values
- opentelemetry_telemetry vs manual Tracer calls
- OTel span attribute naming
- Whether to include Grafana dashboard section
- Prose tone for state machine explanation
- Whether to trim extending guide's existing circuit breaker example

## Deferred Ideas

None — discussion stayed within phase scope.
