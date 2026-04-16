---
phase: 24-rate-limit-awareness-richer-errors
plan: "03"
subsystem: telemetry-docs
tags: [telemetry, documentation, rate-limiting, dx]
dependency_graph:
  requires: [24-01]
  provides: [telemetry-rate-limit-docs]
  affects: [guides/telemetry.md, lib/lattice_stripe/telemetry.ex]
tech_stack:
  added: []
  patterns: [moduledoc-table-sync, guide-section-pattern]
key_files:
  created: []
  modified:
    - lib/lattice_stripe/telemetry.ex
    - guides/telemetry.md
decisions:
  - "Rate Limiting section placed after Custom Telemetry Handlers as a top-level ## section, not nested, per RESEARCH.md discretion recommendation #6"
  - "Note on not atomizing :rate_limited_reason included in both guide and moduledoc to prevent BEAM atom table growth"
metrics:
  duration: "~6 minutes"
  completed: "2026-04-16T19:06:13Z"
  tasks_completed: 2
  files_modified: 2
---

# Phase 24 Plan 03: Telemetry Documentation for Rate Limiting Summary

**One-liner:** Added `:rate_limited_reason` to telemetry stop-event metadata table in both moduledoc and guide, plus new Rate Limiting guide section with Telemetry.Metrics counter example, custom handler recipe, and atom-safety warning.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Update Telemetry moduledoc stop-event metadata table | b8102f5 | lib/lattice_stripe/telemetry.ex |
| 2 | Add Rate Limiting section to guides/telemetry.md | da114c0 | guides/telemetry.md |

## What Was Built

### Task 1: Telemetry moduledoc update

Added the `:rate_limited_reason` row to the `[:lattice_stripe, :request, :stop]` metadata table in `lib/lattice_stripe/telemetry.ex`. The row was inserted before `:telemetry_span_context` (which auto-injected and stays last) and after `:idempotency_key`, matching the existing column format `| Key | Type | Description |` with `\\|` escaping for the pipe in the type column (Elixir string context).

Row added:
```
| `:rate_limited_reason` | `String.t() \| nil` | Stripe `Stripe-Rate-Limited-Reason` header value on 429 responses; `nil` for all non-429 responses. Do not atomize — values are Stripe-controlled strings. |
```

### Task 2: guides/telemetry.md updates

Three changes applied:

1. **Stop-event metadata table**: Added `:rate_limited_reason` row (using `\|` not `\\|` — guide markdown context, not Elixir string) before `:telemetry_span_context`.

2. **Quick Start log example**: Updated the 429 line to show the new suffix:
   ```
   [warning] POST /v1/payment_intents => 429 in 312ms (3 attempts, req_ghi789) (rate_limited: too_many_requests)
   ```

3. **New `## Rate Limiting` section**: Added as top-level section after "Custom Telemetry Handlers" and before "Integration with Telemetry.Metrics". Contains:
   - Explanation of when `:rate_limited_reason` is populated vs `nil`
   - Example default logger output showing the `(rate_limited: ...)` suffix
   - `### Monitoring Rate Limits with Telemetry.Metrics` subsection with `Telemetry.Metrics.counter` example using `keep:` filter to count only 429s
   - `### Custom Rate-Limit Handler` subsection with `:telemetry.attach` example filtering on `metadata[:rate_limited_reason]`
   - Note warning against converting the string value to an atom (Stripe-controlled values, BEAM atom table safety)

## Deviations from Plan

None — plan executed exactly as written.

## Decisions Made

- **Rate Limiting section placement**: After Custom Telemetry Handlers as a top-level `##` section, not nested under any existing section. This matches RESEARCH.md recommendation #6 (discrete operational concern deserves its own top-level section).
- **Moduledoc and guide in sync**: Both tables use identical content for the `:rate_limited_reason` row, differing only in pipe escaping (`\\|` in Elixir string vs `\|` in markdown).

## Known Stubs

None — documentation-only plan, no runtime code changes, no stub patterns applicable.

## Threat Flags

None — documentation-only plan. Example values used are generic Stripe strings ("too_many_requests"), no real API keys or PII.

## Self-Check: PASSED

- lib/lattice_stripe/telemetry.ex: FOUND
- guides/telemetry.md: FOUND
- 24-03-SUMMARY.md: FOUND
- Commit b8102f5: FOUND
- Commit da114c0: FOUND
