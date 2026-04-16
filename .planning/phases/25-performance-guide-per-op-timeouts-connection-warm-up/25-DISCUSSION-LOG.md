# Phase 25: Performance Guide, Per-Op Timeouts & Connection Warm-Up - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 25-performance-guide-per-op-timeouts-connection-warm-up
**Mode:** --auto (all decisions auto-selected)
**Areas discussed:** Operation type classification, Timeout override precedence, Warm-up implementation, Performance guide structure

---

## Operation Type Classification

| Option | Description | Selected |
|--------|-------------|----------|
| Infer from method + path pattern | Classify by GET/POST/DELETE + path shape (list, retrieve, create, etc.) | ✓ |
| Explicit operation type in Request struct | Add an :operation field to %Request{} | |
| Resource module annotation | Each resource module declares its operation types | |

**User's choice:** [auto] Infer from method + path pattern (recommended default)
**Notes:** Matches existing `parse_resource_and_operation/2` pattern in Telemetry. No Request struct changes needed. Edge cases fall through to default timeout — correct behavior.

---

## Timeout Override Precedence

| Option | Description | Selected |
|--------|-------------|----------|
| per-request > operation > client | Three-tier: request opts highest, then per-op, then global default | ✓ |
| per-request > client (flat) | Only two tiers: request opts override client default | |

**User's choice:** [auto] per-request > operation > client (recommended default)
**Notes:** Preserves existing behavior for all callers who don't opt in. Only adds new behavior for explicit `operation_timeouts` users.

---

## Warm-Up Implementation

| Option | Description | Selected |
|--------|-------------|----------|
| GET to Stripe API root | Establish TLS + HTTP/2 connection via lightweight GET /v1/ | ✓ |
| Finch.connect/2 (if available) | Use Finch's native connection establishment | |
| HEAD request | Lighter than GET but Stripe behavior uncertain | |

**User's choice:** [auto] GET to Stripe API root (recommended default)
**Notes:** Stripe returns 404 at /v1/ but the connection is established. HEAD support is unreliable on Stripe's CDN. Direct Finch.connect/2 doesn't exist in the public API.

---

## Performance Guide Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Comprehensive (6 sections) | Pool sizing → supervision tree → per-op timeouts → warm-up → benchmarks → pitfalls | ✓ |
| Minimal (3 sections) | Pool sizing → timeouts → warm-up | |

**User's choice:** [auto] Comprehensive (6 sections) (recommended default)
**Notes:** Production-oriented guide should cover common pitfalls and benchmarking, not just feature docs.

---

## Claude's Discretion

- Exact Finch pool sizing numbers
- Whether to include `warm_up!/1` bang variant
- `classify_operation/1` test coverage depth
- Whether to emit telemetry from `warm_up/1`

## Deferred Ideas

None — discussion stayed within phase scope.
