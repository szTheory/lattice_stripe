---
phase: 02-error-handling-retry
plan: 03
subsystem: client
tags: [retry, idempotency, telemetry, error-handling, bang-variant]
dependency_graph:
  requires: [02-01, 02-02]
  provides: [retry-enabled-client, auto-idempotency, bang-variant, non-json-handling]
  affects: [all-future-api-calls]
tech_stack:
  added: []
  patterns:
    - retry loop via recursive private functions with attempt counter
    - 3-tuple {:error, error, headers} for internal header threading without API leakage
    - retry_state map to bundle multiple loop parameters (keeps arity under 9)
    - UUID v4 generation via :crypto.strong_rand_bytes/1 with RFC 4122 bit manipulation
    - non-bang json_codec.decode/1 for graceful non-JSON response handling
key_files:
  created: []
  modified:
    - lib/lattice_stripe/client.ex
    - test/lattice_stripe/client_test.exs
    - test/test_helper.exs
decisions:
  - key: Option B for header threading — 3-tuple {:error, error, headers} internally, strip to {:error, error} at public boundary
    rationale: Keeps response headers available for retry loop (Stripe-Should-Retry, Retry-After) without leaking implementation details to callers
  - key: retry_state map bundles {method, idempotency_key, max_retries, attempt, total_attempts}
    rationale: Keeps arity of maybe_retry/apply_retry_decision under Credo limit of 8
  - key: Formatting-only changes to retry_strategy.ex and retry_strategy_test.exs included
    rationale: mix format ran on these files during formatting pass; changes are whitespace only
metrics:
  duration_minutes: 12
  completed_date: "2026-04-02"
  tasks_completed: 1
  files_modified: 5
---

# Phase 02 Plan 03: Client Retry Loop, Auto-Idempotency, Bang Variant Summary

**One-liner:** Retry-enabled Client.request/2 with idk_ltc_ UUID v4 idempotency keys, request!/2 bang variant, graceful non-JSON handling, and per-retry telemetry events.

## What Was Built

### Task 1: Wire retry loop, auto-idempotency, non-JSON handling into Client.request/2

Restructured `LatticeStripe.Client` to integrate all Phase 2 retry/idempotency infrastructure:

**Retry loop** (`do_request_with_retries/7`): Calls `RetryStrategy.retry?/2` after each failure. Respects `max_retries` (overridable per-request). Uses `Process.sleep/1` for delays. Recursively retries until max attempts or strategy says `:stop`. Returns `{result, total_attempts}` tuple for telemetry.

**Auto-idempotency** (`resolve_idempotency_key/2`, `generate_idempotency_key/0`): Generates `idk_ltc_`-prefixed UUID v4 for POST requests using `:crypto.strong_rand_bytes/1`. User-provided key takes precedence. Key resolved once before retry loop and reused across all attempts.

**Non-JSON handling** (`decode_response/4`, `build_non_json_error/4`): Uses non-bang `json_codec.decode/1` instead of `decode!/1`. On decode failure builds `%Error{type: :api_error, raw_body: %{"_raw" => truncated}}` with body truncated at 500 bytes.

**Header threading** (`do_request/2` returns `{:error, error, resp_headers}` 3-tuple): Response headers available internally for retry context (Stripe-Should-Retry, Retry-After) without being exposed in the public API.

**Stripe-Should-Retry** (`parse_stripe_should_retry/1`): Parses header string `"true"/"false"` to boolean before building retry context. Feeds into `RetryStrategy.Default.retry?/2` as `stripe_should_retry` context key.

**Bang variant** (`request!/2`): Thin wrapper — calls `request/2`, returns decoded map on success, raises `LatticeStripe.Error` on failure (after retries exhausted).

**Per-retry telemetry**: Emits `[:lattice_stripe, :request, :retry]` with measurements `{attempt, delay_ms}` and metadata `{method, path, error_type, status}`. Stop event metadata enriched with `attempts`, `retries`, `idempotency_key`.

**MockRetryStrategy**: Added `Mox.defmock(LatticeStripe.MockRetryStrategy, for: LatticeStripe.RetryStrategy)` to `test/test_helper.exs`. Used in 26 new client tests with zero-delay stubs.

## Acceptance Criteria Verification

- `lib/lattice_stripe/client.ex` contains `def request!(%__MODULE__{} = client, %Request{} = req)` — YES
- `lib/lattice_stripe/client.ex` contains `defp do_request_with_retries(` — YES
- `lib/lattice_stripe/client.ex` contains `defp generate_idempotency_key` — YES
- `lib/lattice_stripe/client.ex` contains `"idk_ltc_"` prefix string — YES
- `lib/lattice_stripe/client.ex` contains `:crypto.strong_rand_bytes(16)` — YES
- `lib/lattice_stripe/client.ex` contains `client.retry_strategy.retry?(` — YES
- `lib/lattice_stripe/client.ex` contains `Process.sleep(delay_ms)` — YES
- `lib/lattice_stripe/client.ex` contains `[:lattice_stripe, :request, :retry]` — YES
- `lib/lattice_stripe/client.ex` contains `json_codec.decode(` (non-bang) — YES
- `lib/lattice_stripe/client.ex` contains `%{"_raw" =>` for non-JSON raw_body — YES
- `test/test_helper.exs` contains `MockRetryStrategy` — YES
- `test/lattice_stripe/client_test.exs` contains tests for retry loop, idempotency, bang variant — YES
- `mix test test/lattice_stripe/client_test.exs` exits 0 — YES (52 tests, 0 failures)
- `mix test` (full suite) exits 0 — YES (161 tests, 0 failures)

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 (GREEN) | 9501f91 | feat(02-03): wire retry loop, auto-idempotency, bang variant, non-JSON handling into Client |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Credo] Extracted retry helpers to reduce nesting depth**
- **Found during:** Task 1 (Credo check)
- **Issue:** `do_request_with_retries` had `case` inside `if` inside `case` (depth 3, max 2)
- **Fix:** Extracted `maybe_retry/5` and `apply_retry_decision/5` with a `retry_state` map to bundle params under arity limit
- **Files modified:** `lib/lattice_stripe/client.ex`

**2. [Rule 2 - Credo] Extracted `do_request` sub-functions**
- **Found during:** Task 1 (Credo check)
- **Issue:** `do_request` had `if` inside `case` inside `case` (depth 3)
- **Fix:** Extracted `decode_response/4`, `build_decoded_response/4`, `build_non_json_error/4`
- **Files modified:** `lib/lattice_stripe/client.ex`

**3. [Rule 2 - Formatting] Pre-existing formatting in retry files**
- **Found during:** Task 1 (mix format pass)
- **Issue:** `retry_strategy.ex` and `retry_strategy_test.exs` had long single-line maps
- **Fix:** `mix format` reformatted them (whitespace only, no logic changes)
- **Files modified:** `lib/lattice_stripe/retry_strategy.ex`, `test/lattice_stripe/retry_strategy_test.exs`

### Pre-existing Issues (Deferred)

See `.planning/phases/02-error-handling-retry/deferred-items.md` for pre-existing Credo issues in `retry_strategy.ex` and `form_encoder.ex` that are out of scope for this plan.

## Known Stubs

None — all data flows are wired. The retry loop, idempotency key generation, and non-JSON handling are all connected end-to-end.
