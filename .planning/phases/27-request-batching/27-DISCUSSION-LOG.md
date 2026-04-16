# Phase 27: Request Batching - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 27-request-batching
**Mode:** --auto (all decisions auto-selected with recommended defaults)
**Areas discussed:** Input format, Concurrency control, Timeout behavior, Result contract, Telemetry, API surface

---

## Input Format

| Option | Description | Selected |
|--------|-------------|----------|
| MFA tuples only | `{module, :function, args}` — explicit, inspectable, debuggable | ✓ |
| MFA + anonymous functions | Also accept `fn -> ... end` closures | |
| Keyword shorthand | `[customer: {:retrieve, ["cus_123"]}]` sugar | |

**User's choice:** [auto] MFA tuples only (recommended default)
**Notes:** Anonymous functions harder to log/debug. MFA tuples match roadmap's stated contract.

---

## Concurrency Control

| Option | Description | Selected |
|--------|-------------|----------|
| Configurable with default | `max_concurrency` opt, default `System.schedulers_online()` | ✓ |
| Fixed concurrency | Hardcoded value (e.g., 8) | |
| Unlimited | No max_concurrency cap | |

**User's choice:** [auto] Configurable with sensible default (recommended default)
**Notes:** Maps directly to `Task.async_stream`'s `:max_concurrency`. Sensible default scales with hardware.

---

## Timeout Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Per-task via Client | Inherit Client's timeout cascade, no batch timeout | ✓ |
| Batch-level timeout | Single timeout for entire batch | |
| Both | Per-task + batch-level combined | |

**User's choice:** [auto] Per-task via Client (recommended default)
**Notes:** Avoids double-timeout conflicts. Client already has three-tier timeout cascade.

---

## Result Contract

| Option | Description | Selected |
|--------|-------------|----------|
| Always-ok wrapper | `{:ok, [per_call_results]}` — batch always succeeds, individual calls may fail | ✓ |
| Fail-fast | First error fails the whole batch | |
| Threshold | Fail batch if >N% of tasks fail | |

**User's choice:** [auto] Always-ok wrapper (recommended default)
**Notes:** Matches OTP conventions. Top-level error only for argument validation failures.

---

## Telemetry

| Option | Description | Selected |
|--------|-------------|----------|
| Per-request only | Rely on existing request telemetry events | ✓ |
| Batch-level events | Add `[:lattice_stripe, :batch, :start/:stop]` | |
| Both | Per-request + batch-level | |

**User's choice:** [auto] Per-request only (recommended default)
**Notes:** Avoids duplication. Users can correlate concurrent requests by timing.

---

## API Surface

| Option | Description | Selected |
|--------|-------------|----------|
| `run/2` only | Single function, no bang variant | ✓ |
| `run/2` + `run!/2` | Add bang variant | |
| `run/2` + `map/2` | Add map-style variant | |

**User's choice:** [auto] `run/2` only (recommended default)
**Notes:** Batch always returns `{:ok, results}`, nothing to bang on. Keep API minimal.

---

## Claude's Discretion

- `ordered: false` option, internal structure, MFA validation, test organization, @doc examples

## Deferred Ideas

None
