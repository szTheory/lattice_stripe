# Phase 8: Telemetry & Observability - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-03
**Phase:** 08-telemetry-observability
**Areas discussed:** Event coverage scope, Metadata completeness, Consumer documentation, Test depth, Telemetry helper architecture, Refactoring existing telemetry code, Telemetry.Metrics examples in docs, Webhook telemetry event granularity

---

## Event Coverage Scope

| Option | Description | Selected |
|--------|-------------|----------|
| HTTP requests only | Keep telemetry strictly on request/retry cycle. Matches every other Stripe SDK. | |
| HTTP requests + webhook verification | Add webhook verify span. Catches misconfigured secrets via monitoring. Aligns with Elixir ecosystem norms. | ✓ |
| HTTP requests + webhook + pagination aggregate | Also emit pagination stop event with page_count/total_items. Most complete but most complex. | |

**User's choice:** HTTP requests + webhook verification (Option B)
**Notes:** Deep research conducted via 3 parallel subagents covering: Stripe SDK ecosystem (ruby/node/python/go/stripity_stripe), Elixir ecosystem best practices (Finch/Oban/Phoenix/Broadway/Tesla), and SRE/DevOps observability standards. User requested full examples, tradeoffs, ecosystem research before choosing.

---

## Metadata Completeness

| Option | Description | Selected |
|--------|-------------|----------|
| resource + operation | Add low-cardinality resource/operation to start+stop. Enables per-operation dashboards. | ✓ |
| api_version + stripe_account | Add structural metadata to start+stop. Useful for version mismatch debugging and Connect platforms. | ✓ |
| idempotency_key on start too | Extend idempotency_key to all events, not just error stop. High cardinality trace-level field. | |
| Minimal — keep as-is | Current metadata sufficient. | |

**User's choice:** resource + operation AND api_version + stripe_account
**Notes:** Multi-select question. User chose two of four options.

---

## Metadata Derivation

| Option | Description | Selected |
|--------|-------------|----------|
| Parse from path | Derive resource/operation from URL path pattern. Zero changes to resource modules. | ✓ |
| Pass explicitly from resource modules | Each resource module passes resource/operation in Request struct. More explicit but touches every module. | |
| You decide | Claude picks. | |

**User's choice:** Parse from path
**Notes:** None

---

## Consumer Documentation

| Option | Description | Selected |
|--------|-------------|----------|
| Telemetry module + default logger | LatticeStripe.Telemetry with @moduledoc event catalog + private helpers + attach_default_logger/1. Oban pattern. | ✓ |
| Telemetry module only, no logger | Event catalog + helpers, no default logger. Finch pattern. | |
| Document in Client moduledoc | No separate module. Ecto/Broadway pattern. | |

**User's choice:** Telemetry module + default logger
**Notes:** None

---

## Default Logger Format

| Option | Description | Selected |
|--------|-------------|----------|
| Structured one-liner | Single log line per request. Clean, greppable, Phoenix.Logger style. | ✓ |
| JSON structured log | JSON output for log aggregation tools. | |
| You decide | Claude picks. | |

**User's choice:** Structured one-liner
**Notes:** None

---

## Test Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Assert key metadata fields | Verify critical fields with correct values. ~10-15 test cases. | |
| Full metadata contract tests | Assert every metadata key, type, and value. Treat as public API contract. ~25-30 tests. Oban-level rigor. | ✓ |
| Minimal — event arrival only | Keep current tests. Trust :telemetry.span/3. | |

**User's choice:** Full metadata contract tests
**Notes:** None

---

## Telemetry Helper Architecture

| Option | Description | Selected |
|--------|-------------|----------|
| Centralized helpers | LatticeStripe.Telemetry owns all event names + provides private helpers. Client/Webhook call Telemetry functions. Finch pattern. | ✓ |
| Decentralized, docs-only | Telemetry module is purely documentation. Client/Webhook call :telemetry directly. Oban pattern. | |
| You decide | Claude picks. | |

**User's choice:** Centralized helpers
**Notes:** None

---

## Refactoring Existing Telemetry Code

| Option | Description | Selected |
|--------|-------------|----------|
| Extract and refactor | Move all telemetry logic from Client into Telemetry module. Client becomes consumer. | ✓ |
| Leave Client as-is, add new only | Keep existing inline code. Add new events in Telemetry module only. Less risk. | |
| You decide | Claude picks. | |

**User's choice:** Extract and refactor
**Notes:** None

---

## Telemetry.Metrics Examples in Docs

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, include examples | Copy-paste Telemetry.Metrics definitions in @moduledoc for Prometheus/StatsD. | ✓ |
| Event catalog only | Document events but no Metrics examples. | |
| You decide | Claude picks. | |

**User's choice:** Yes, include examples
**Notes:** None

---

## Webhook Telemetry Event Granularity

| Option | Description | Selected |
|--------|-------------|----------|
| Span | Use :telemetry.span/3 for consistency. Same attach pattern and exception handling. | ✓ |
| Standalone event | Single :telemetry.execute/3 after verification. Simpler, lighter. | |
| You decide | Claude picks. | |

**User's choice:** Span
**Notes:** Consistency with request telemetry was the deciding factor.

---

## Claude's Discretion

- Path parsing logic for resource/operation derivation
- Default logger handler ID naming
- Internal helper function signatures
- Telemetry.Metrics example specifics

## Deferred Ideas

- Pagination aggregate telemetry — add later if users request
- JSON decode sub-timing event
- Grafana dashboard JSON template (Phase 10)
