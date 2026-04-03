---
phase: 07-webhooks
plan: 01
subsystem: webhooks
tags: [webhook, hmac, event, signature-verification, plug-crypto]
dependency_graph:
  requires: [lib/lattice_stripe/resource.ex, lib/lattice_stripe/client.ex, lib/lattice_stripe/list.ex]
  provides: [LatticeStripe.Event, LatticeStripe.Webhook, LatticeStripe.Webhook.Handler, LatticeStripe.Webhook.SignatureVerificationError]
  affects: [phase-07-plan-02]
tech_stack:
  added: [plug_crypto ~> 2.0, plug ~> 1.16 (optional)]
  patterns: [HMAC-SHA256 timing-safe comparison, multi-secret rotation, tolerance-based replay protection, TDD red-green-refactor]
key_files:
  created:
    - lib/lattice_stripe/event.ex
    - lib/lattice_stripe/webhook.ex
    - lib/lattice_stripe/webhook/handler.ex
    - lib/lattice_stripe/webhook/signature_verification_error.ex
    - test/support/fixtures/event.ex
    - test/lattice_stripe/event_test.exs
    - test/lattice_stripe/webhook_test.exs
  modified:
    - mix.exs
    - mix.lock
decisions:
  - plug_crypto added as required runtime dep; plug added as optional (only needed for Plug.Webhook in plan 02)
  - Event.from_map/1 keeps data and request as raw maps (no further typing - event data varies by type)
  - Webhook uses Jason.decode! directly (not json_codec behaviour) since this is SDK metadata path
  - check_tolerance/2 with tolerance 0 always returns {:error, :timestamp_expired} - strict replay protection
  - Handler behaviour compiled unconditionally - no Code.ensure_loaded? guard needed since plug_crypto is required dep
metrics:
  duration_minutes: 15
  completed_date: "2026-04-03"
  tasks_completed: 2
  files_created_or_modified: 8
---

# Phase 07 Plan 01: Webhook Core Pipeline Summary

**One-liner:** HMAC-SHA256 webhook verification with timing-safe Plug.Crypto comparison, multi-secret rotation, configurable tolerance, and typed Event struct with retrieve/list/stream API resource.

## What Was Built

### LatticeStripe.Event (`lib/lattice_stripe/event.ex`)

Event struct following the established Customer/PaymentIntent pattern:
- `@known_fields` with all 10 Stripe event fields including `context` (newer Stripe field)
- `from_map/1` — infallible, keeps `data` and `request` as raw maps
- Read-only API: `retrieve/3`, `retrieve!/3`, `list/3`, `list!/3`, `stream!/3`
- `defimpl Inspect` — shows `id`, `type`, `object`, `created`, `livemode`; hides `data`, `request`, `account`, `extra`

### LatticeStripe.Webhook (`lib/lattice_stripe/webhook.ex`)

Pure-functional HMAC verification module — no Plug dependency:
- `construct_event/3,4` — verifies signature + decodes JSON + returns `%Event{}`
- `construct_event!/3,4` — bang variant raising `SignatureVerificationError`
- `verify_signature/3,4` — HMAC-SHA256 via `:crypto.mac` + `Plug.Crypto.secure_compare`
- `verify_signature!/3,4` — bang variant
- `generate_test_signature/2,3` — produces valid Stripe-Signature headers for tests
- Multi-secret support via list input (for secret rotation)
- Configurable tolerance window (default 300s) for replay attack protection

### LatticeStripe.Webhook.Handler (`lib/lattice_stripe/webhook/handler.ex`)

Behaviour for webhook dispatch:
- `@callback handle_event(Event.t()) :: :ok | {:ok, term()} | :error | {:error, term()}`
- Compiled unconditionally, no Plug imports

### LatticeStripe.Webhook.SignatureVerificationError (`lib/lattice_stripe/webhook/signature_verification_error.ex`)

Dedicated exception for verification failures:
- `defexception [:message, :reason]`
- 4 reason atoms: `:missing_header`, `:invalid_header`, `:no_matching_signature`, `:timestamp_expired`
- Default messages per reason atom
- Accepts `[reason: atom()]` or `[reason: atom(), message: String.t()]`

### Dependencies Updated (`mix.exs`)

- Added `{:plug_crypto, "~> 2.0"}` — required for `Plug.Crypto.secure_compare`
- Added `{:plug, "~> 1.16", optional: true}` — optional, used by Plug.Webhook in plan 02

## Commits

| Hash | Description |
|------|-------------|
| 1c04f4b | feat(07-01): add Event struct, Handler behaviour, SignatureVerificationError, deps |
| bf6b416 | test(07-01): add failing webhook tests for HMAC verification (TDD RED) |
| b524010 | feat(07-01): implement LatticeStripe.Webhook with HMAC-SHA256 verification |

## Test Results

- Event tests: 16 passing
- Webhook tests: 30 passing
- Full suite: 473 tests, 0 failures

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Inspect test assertion for "does NOT show data"**
- **Found during:** Task 1 test run
- **Issue:** Test checked `refute inspected =~ "payment_intent"` but `type: "payment_intent.succeeded"` appears in the inspect output (correctly) — the test was wrong
- **Fix:** Changed assertion to check data content specifically (`"pi_abc123"`, `"amount"`, `"currency"`) rather than the event type string which legitimately appears
- **Files modified:** `test/lattice_stripe/event_test.exs`
- **Commit:** 1c04f4b

**2. [Rule 1 - Formatting] Unused import in webhook_test.exs**
- **Found during:** Task 2 test run
- **Issue:** `import LatticeStripe.Test.Fixtures.Event` was not needed in webhook test
- **Fix:** Removed the unused import to eliminate warning
- **Files modified:** `test/lattice_stripe/webhook_test.exs`
- **Commit:** b524010

**3. [Rule 1 - Formatting] mix format violations in new files and pre-existing tests**
- **Found during:** Final verification
- **Issue:** Several files (including pre-existing test files from earlier phases) had formatting violations detected by `mix format --check-formatted`
- **Fix:** Ran `mix format` to auto-fix all violations
- **Files modified:** Multiple test files + `lib/lattice_stripe/webhook/signature_verification_error.ex`
- **Commit:** b524010

## Known Stubs

None — all functionality is fully wired. The `data` and `request` fields on `%Event{}` are intentionally kept as raw maps (not stubs) because Stripe event data varies by event type and will be accessed by user code directly.

## Self-Check: PASSED
