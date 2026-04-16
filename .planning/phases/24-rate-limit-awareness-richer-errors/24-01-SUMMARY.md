---
phase: 24-rate-limit-awareness-richer-errors
plan: "01"
subsystem: telemetry
tags: [telemetry, rate-limiting, observability, perf]
dependency_graph:
  requires: []
  provides: [rate_limited_reason telemetry metadata, 429 warning escalation]
  affects: [lib/lattice_stripe/client.ex, lib/lattice_stripe/telemetry.ex, test/lattice_stripe/telemetry_test.exs]
tech_stack:
  added: []
  patterns: [3-tuple closure return for resp_headers threading, header value as string (never atomized)]
key_files:
  created: []
  modified:
    - lib/lattice_stripe/client.ex
    - lib/lattice_stripe/telemetry.ex
    - test/lattice_stripe/telemetry_test.exs
decisions:
  - "Store rate_limited_reason as String.t() never atomize — prevents atom table exhaustion from Stripe-controlled header values (T-24-02)"
  - "parse_rate_limited_reason/1 lives in telemetry.ex (not client.ex) — it is a telemetry concern used only by build_stop_metadata"
  - "3-tuple {result, attempts, resp_headers} closure return shape threads headers to telemetry without changing public Client.request/2 API"
metrics:
  duration: "~3 minutes"
  completed: "2026-04-16"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 3
---

# Phase 24 Plan 01: Rate-Limit Telemetry Headers Summary

Rate-limit header threading from Stripe responses through the Client retry loop into telemetry stop event metadata, with 429 escalation to `:warning` log level and a reason suffix in the default logger.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Thread resp_headers through Client retry loop | 92baad0 | lib/lattice_stripe/client.ex |
| 2 | Enrich telemetry stop metadata with :rate_limited_reason and escalate 429 to :warning | 431f57e | lib/lattice_stripe/telemetry.ex, test/lattice_stripe/telemetry_test.exs |

## What Was Built

**Task 1 — client.ex 3-tuple return:**
- `do_request_with_retries/7` success branch now matches `{:ok, %Response{} = resp} = success` and returns `{success, total_attempts, resp.headers}`
- `maybe_retry/5` exhausted-retries else branch returns `{{:error, error}, total_attempts, resp_headers}`
- `apply_retry_decision/5` `:stop` branch returns `{{:error, error}, total, context.headers}` (headers already in context map from existing retry logic)
- Entry-point comment updated to document 3-tuple return shape

**Task 2 — telemetry.ex enrichment + log escalation:**
- `request_span/4` closure destructures `{result, attempts, resp_headers} = fun.()` and passes `resp_headers` to `build_stop_metadata`
- Disabled branch updated to `{result, _attempts, _resp_headers} = fun.()` (critical — avoids FunctionClauseError)
- All 3 `build_stop_metadata` clauses updated to arity 5 with `resp_headers` as 4th parameter
- All 3 clauses include `rate_limited_reason: parse_rate_limited_reason(resp_headers)` in Map.merge
- New `parse_rate_limited_reason/1` private function: case-insensitive header lookup returning raw string or nil
- `handle_default_log/4`: `rate_limit_suffix` binding with `Map.get(metadata, :rate_limited_reason)` and `effective_level` escalation for HTTP 429

**Test additions (telemetry_test.exs):**
- `rate_limited_response/1` helper with `stripe-rate-limited-reason` header
- 4 new tests in `describe "rate-limit telemetry"` block:
  1. `rate_limited_reason == "too_many_requests"` on 429 with header
  2. `rate_limited_reason == nil` on success
  3. `rate_limited_reason == nil` on non-429 API error
  4. Default logger logs `[warning]` with `(rate_limited: too_many_requests)` suffix on 429

## Deviations from Plan

None — plan executed exactly as written.

## Threat Model Compliance

| Threat ID | Mitigation | Status |
|-----------|-----------|--------|
| T-24-01 | rate_limited_reason is non-sensitive operational data — accepted | Confirmed: raw string in metadata only |
| T-24-02 | String.t() storage, never atomized — `parse_rate_limited_reason` returns `v` directly from header, no `String.to_atom` | Confirmed: implemented correctly |

## Known Stubs

None.

## Self-Check: PASSED

- `lib/lattice_stripe/client.ex` exists and contains `{success, total_attempts, resp.headers}`
- `lib/lattice_stripe/telemetry.ex` exists and contains `parse_rate_limited_reason`
- `test/lattice_stripe/telemetry_test.exs` exists and contains `rate_limited_reason`
- Commit 92baad0 exists (Task 1)
- Commit 431f57e exists (Task 2)
- `mix compile --warnings-as-errors` exits 0
- `mix test test/lattice_stripe/telemetry_test.exs` 53 tests, 0 failures
