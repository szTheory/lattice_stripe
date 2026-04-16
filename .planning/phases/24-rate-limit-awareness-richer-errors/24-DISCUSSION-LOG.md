# Phase 24: Rate-Limit Awareness & Richer Errors - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 24-rate-limit-awareness-richer-errors
**Areas discussed:** Rate-limit telemetry, Fuzzy param source, Error enrichment, Telemetry guide update

---

## Rate-Limit Telemetry

| Option | Description | Selected |
|--------|-------------|----------|
| A: Extract in `build_stop_metadata` from existing structs | Centralized in telemetry module but requires adding headers to Error struct | |
| B: Thread raw headers into telemetry via span closure | Zero struct changes; headers threaded through closure return shape | ✓ |
| C: Parse header in `do_request`, attach as field on Error/Response | Rate-limit reason on core structs; couples header knowledge into response decoding | |

**User's choice:** Option B — thread via span closure
**Notes:** User requested deep research via parallel subagents. Research confirmed Option B avoids polluting public structs while leveraging existing header availability in both success (Response.headers) and error (3-tuple resp_headers) paths. Aligns with telemetry-only requirement scope.

---

## Fuzzy Param Source

| Option | Description | Selected |
|--------|-------------|----------|
| A: Per-resource `@valid_params` attributes | Precise per-operation but high maintenance across 40+ modules | |
| B: Shared global param registry | Single file, covers common params only | |
| C: `@known_fields` as proxy + exclusion list | Leverages existing module attributes, filtered by @response_only_fields | ✓ |
| D: Match against user's own params + Stripe error context | Zero maintenance but limited to Stripe-provided context | |

**User's choice:** Option C — `@known_fields` proxy with exclusion
**Notes:** Research confirmed substantial overlap between response fields and request params for most resources. Small exclusion list handles divergence. Natural upgrade path when Phase 30 (drift detection) lands per-operation param lists.

### Secondary: Algorithm Choice

| Option | Description | Selected |
|--------|-------------|----------|
| `String.jaro_distance/2` (stdlib, threshold 0.8) | Same algorithm Elixir compiler uses, zero deps | ✓ |
| Levenshtein edit distance | Custom impl needed, worse for transpositions | |

**User's choice:** Jaro distance (stdlib)
**Notes:** Threshold 0.8, minimum param length 4 chars.

---

## Error Enrichment

| Option | Description | Selected |
|--------|-------------|----------|
| A: Append to `:message` string only | Zero struct changes, auto-visible in logs/raise | ✓ |
| B: New `:suggestion` field + append to message | Programmatic access but adds struct field | |
| C: Lazy computation in `message/1` | Zero-cost construction but repeated computation | |
| D: Separate `Error.suggest/1` helper | Opt-in but invisible by default | |

**User's choice:** Option A — message-append only
**Notes:** Success criteria explicitly require suggestion in message and no struct field changes. Matches Stripe's own server-side error message pattern and Elixir compiler UndefinedFunctionError format.

### Secondary: Pipeline Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Inside `from_response/3` | Single construction site, param already extracted there | ✓ |
| Post-processing in `Client.request/2` | Keeps from_response pure but splits construction | |

**User's choice:** `from_response/3`

---

## Telemetry Guide Update

| Option | Description | Selected |
|--------|-------------|----------|
| A: Warning-level log + reason suffix | Immediate visibility, matches Oban pattern | |
| B: Log at configured level with reason suffix | Respects user's level choice | |
| C: No logger changes, doc-only | Zero log noise risk but no out-of-box visibility | |
| D: Warning-level log + dedicated guide section | Best discoverability, production-grade docs | ✓ |

**User's choice:** Option D — warning log + guide section
**Notes:** Matches "production-grade" mission. Existing telemetry guide already shows warning-level 429 examples — code should deliver on documented behavior. Concise "Rate Limiting" subsection with counter metric example and custom handler recipe.

---

## Claude's Discretion

- Fuzzy matching module structure (dedicated module vs private in Error)
- Exact `@response_only_fields` set
- Optional `Retry-After` capture
- Test structure
- Suggestion wording format
- Guide subsection placement

## Deferred Ideas

None — discussion stayed within phase scope.
