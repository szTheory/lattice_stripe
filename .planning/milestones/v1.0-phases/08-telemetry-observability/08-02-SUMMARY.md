---
phase: 08-telemetry-observability
plan: "02"
subsystem: telemetry
tags: [telemetry, observability, webhook, logger, elixir, testing]

dependency_graph:
  requires:
    - phase: 08-01
      provides: LatticeStripe.Telemetry module with request_span/4, emit_retry/5, and stubs for webhook_verify_span/2 and attach_default_logger/1
  provides:
    - webhook_verify_span/2 fully implemented with :telemetry.span emitting start/stop/exception events
    - attach_default_logger/1 fully implemented with Logger handler producing structured one-liner output
    - handle_default_log/4 public handler function for Logger integration
    - build_webhook_stop_metadata/2 private helper with ok/error clauses
    - construct_event/4 in Webhook module wrapped in telemetry span
    - 30 telemetry metadata contract tests covering all event types
  affects:
    - lib/lattice_stripe/webhook.ex (calls Telemetry.webhook_verify_span)

tech_stack:
  added: []
  patterns:
    - Telemetry metadata contract tests treating event schema as public API
    - :telemetry.span/3 for webhook verification span (mirrors request span pattern)
    - Default logger via :telemetry.attach with named handler ID for safe idempotent calls

key_files:
  created:
    - test/lattice_stripe/telemetry_test.exs
  modified:
    - lib/lattice_stripe/telemetry.ex
    - lib/lattice_stripe/webhook.ex

key_decisions:
  - "webhook_verify_span always fires regardless of client.telemetry_enabled — infrastructure-level observability (D-02)"
  - "attach_default_logger/1 calls :telemetry.detach first (idempotent, safe to call multiple times)"
  - "handle_default_log/4 is public (@doc false) so :telemetry.attach can reference it as MFA for performance"
  - "Webhook tests use generate_test_signature with current timestamp to avoid :timestamp_expired in negative tests"

requirements-completed: [TLMT-01, TLMT-02, TLMT-03]

duration: 22min
completed: 2026-04-03
---

# Phase 08 Plan 02: Telemetry Webhook Span, Default Logger, and Metadata Contract Tests Summary

**Webhook verification emits :telemetry.span events via webhook_verify_span/2, attach_default_logger/1 produces structured "POST /v1/customers => 200 in 145ms (1 attempt, req_xxx)" log lines, and 30 metadata contract tests treat telemetry event schemas as public API**

## Performance

- **Duration:** ~22 min
- **Started:** 2026-04-03T12:00:00Z
- **Completed:** 2026-04-03T12:22:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Replaced `webhook_verify_span/2` stub with full `:telemetry.span` implementation emitting `[:lattice_stripe, :webhook, :verify, :start/stop/exception]`
- Replaced `attach_default_logger/1` stub with `:telemetry.attach` handler that logs structured one-liners via `Logger.log/2`
- Wrapped `construct_event/4` in `Webhook` module to call `Telemetry.webhook_verify_span/2`
- Created 30 metadata contract tests covering all event types, metadata fields, path parsing, webhook telemetry, telemetry toggle, and default logger format

## Task Commits

1. **Task 1: Implement webhook_verify_span, attach_default_logger, integrate webhook telemetry** - `63de0a4` (feat)
2. **Task 2: Comprehensive telemetry metadata contract tests** - `3a4fad2` (test)

## Files Created/Modified

- `lib/lattice_stripe/telemetry.ex` - Replaced two stubs with full implementations; added handle_default_log/4 and build_webhook_stop_metadata/2
- `lib/lattice_stripe/webhook.ex` - construct_event/4 body wrapped in LatticeStripe.Telemetry.webhook_verify_span/2
- `test/lattice_stripe/telemetry_test.exs` - Created: 30 metadata contract tests across 9 describe blocks

## Decisions Made

- `handle_default_log/4` is public with `@doc false` (not private defp) so `:telemetry.attach` can capture it as MFA (`&__MODULE__.handle_default_log/4`) — named function references are more performant than anonymous functions per telemetry documentation
- `attach_default_logger/1` calls `:telemetry.detach(@default_logger_id)` before attaching to allow idempotent calls without returning `{:error, :already_exists}`
- Webhook test for "error and :error_reason on failure" uses a current-timestamp bad signature (not a stale timestamp) to avoid `:timestamp_expired` masking the `:no_matching_signature` error
- `build_webhook_stop_metadata/2` stores `error_reason: nil` on success (not missing key) to maintain consistent metadata shape

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed stale timestamp in webhook error test**
- **Found during:** Task 2 (TDD RED run)
- **Issue:** Test used `"t=12345,v1=badsig"` which has a stale timestamp, so `construct_event/4` returned `{:error, :timestamp_expired}` instead of `{:error, :no_matching_signature}` — assertion failed
- **Fix:** Changed test to generate `t=#{System.system_time(:second)},v1=deadbeef...` (64-char hex) so timestamp check passes and HMAC check fires
- **Files modified:** test/lattice_stripe/telemetry_test.exs
- **Verification:** Test passes asserting `{:error, :no_matching_signature}` and `:error_reason` is atom
- **Committed in:** 3a4fad2 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug in test logic)
**Impact on plan:** Minor test fix, no scope creep.

## Issues Encountered

None beyond the stale timestamp deviation above.

## Known Stubs

None — all stubs from Plan 01 are now fully implemented.

## Next Phase Readiness

- Phase 08 (Telemetry/Observability) is now complete: request spans, retry events, webhook spans, default logger, full metadata contract test suite
- Phase 09 (Integration / stripe-mock) is the next phase — ready to proceed

---
*Phase: 08-telemetry-observability*
*Completed: 2026-04-03*
