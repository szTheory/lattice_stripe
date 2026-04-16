---
phase: 28-meter-event-stream-v2
plan: "02"
subsystem: billing/metering
tags:
  - meter-event-stream
  - session-token-auth
  - dual-host
  - json-encoding
  - telemetry
  - unit-tests
  - exdoc
dependency_graph:
  requires:
    - 28-01 (Session struct + fixture)
  provides:
    - LatticeStripe.Billing.MeterEventStream module
    - create_session/2 and send_events/4 public API
    - MeterEventStream unit tests (20 tests via Mox)
    - MeterEventStream integration test skeleton (skipped)
    - ExDoc Billing Metering group updated
    - guides/metering.md v2 event stream section
  affects:
    - lib/lattice_stripe/billing/meter_event_stream.ex (new)
    - test/lattice_stripe/billing/meter_event_stream_test.exs (extended)
    - test/lattice_stripe/billing/meter_event_stream_integration_test.exs (new)
    - mix.exs (ExDoc groups)
    - guides/metering.md (v2 section appended)
tech_stack:
  added: []
  patterns:
    - Direct transport call bypassing Client.request/2 (dual-host architecture)
    - Session token auth separate from API key auth
    - JSON body encoding via client.json_codec.encode!/1
    - Client-side expiry check before network call
    - telemetry_wrap/3 private helper for conditional span emission
key_files:
  created:
    - lib/lattice_stripe/billing/meter_event_stream.ex
    - test/lattice_stripe/billing/meter_event_stream_integration_test.exs
  modified:
    - test/lattice_stripe/billing/meter_event_stream_test.exs
    - mix.exs
    - guides/metering.md
decisions:
  - "MeterEventStream bypasses Client.request/2 entirely — dual-host (api.stripe.com for session, meter-events.stripe.com for stream) requires bespoke header building"
  - "telemetry_wrap/3 implemented inline — no dependency on LatticeStripe.Telemetry internals; simpler and consistent with D-08 decision"
  - "handle_401/2 dispatches on billing_meter_event_session_expired code — normalizes to {:error, :session_expired} for ergonomic pattern matching"
  - "check_expiry/1 nil clause returns :ok — when expires_at is unknown, let server decide rather than fail-safe"
metrics:
  duration: "8 minutes"
  completed: "2026-04-16T22:05:00Z"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 3
---

# Phase 28 Plan 02: MeterEventStream Module + Tests + ExDoc + Guide Summary

**One-liner:** MeterEventStream v2 session-token API with dual-host transport calls, JSON encoding, client-side expiry guard, Mox unit tests, and metering guide v2 section.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | MeterEventStream module — create_session/2 + send_events/4 + telemetry | 984b1a4 | lib/lattice_stripe/billing/meter_event_stream.ex (created) |
| 2 | Unit tests + integration test skeleton + ExDoc + guide cross-link | f47a1e0 | test/lattice_stripe/billing/meter_event_stream_test.exs (extended), test/lattice_stripe/billing/meter_event_stream_integration_test.exs (created), mix.exs, guides/metering.md |

## What Was Built

### MeterEventStream Module (`lib/lattice_stripe/billing/meter_event_stream.ex`)

`LatticeStripe.Billing.MeterEventStream` — the most architecturally novel module in the codebase. It is the only module that:

1. Calls `client.transport.request/1` directly (bypasses `Client.request/2`)
2. Uses two different hosts (`api.stripe.com` for sessions, `meter-events.stripe.com` for events)
3. Uses JSON body encoding (not form-urlencoded)
4. Authenticates with a session token instead of the API key on the hot path

**`create_session/2`:**
- POSTs to `https://api.stripe.com/v2/billing/meter_event_session`
- Uses `Bearer #{client.api_key}` authentication
- Sends `Content-Type: application/json` with `"{}"` empty JSON body
- Decodes response via `Session.from_map/1` from Plan 01
- Wraps call in telemetry span `[:lattice_stripe, :meter_event_stream, :create_session]`

**`send_events/4`:**
- Validates events list is non-empty (returns `{:error, %Error{type: :invalid_request_error}}`)
- Checks `session.expires_at` client-side before any network call (returns `{:error, :session_expired}`)
- POSTs to `https://meter-events.stripe.com/v2/billing/meter_event_stream`
- Uses `Bearer #{session.authentication_token}` authentication (NOT the API key)
- Encodes body as `%{"events" => events}` JSON via `client.json_codec.encode!/1`
- Handles server 401 with `billing_meter_event_session_expired` code → `{:error, :session_expired}`
- Wraps call in telemetry span `[:lattice_stripe, :meter_event_stream, :send_events]`

**Private helpers:**
- `validate_events/1` — empty list guard
- `check_expiry/1` — client-side TTL check; nil `expires_at` passes through
- `handle_401/2` — session-expired normalization with fallthrough to `Error.from_response/3`
- `decode_error/3` — shared non-2xx error decoding
- `telemetry_wrap/3` — conditional `:telemetry.span/3` based on `client.telemetry_enabled`

### Unit Tests (`test/lattice_stripe/billing/meter_event_stream_test.exs`)

20 tests total (7 from Plan 01 + 13 new):

**`describe "create_session/2"` (6 tests):**
- Returns `%Session{}` struct on 200 with correct field values
- Sends API key auth header `Bearer sk_test_123` (not session token)
- Sends `Content-Type: application/json` header
- Sends empty JSON body `"{}"`
- Returns `%Error{type: :invalid_request_error}` on 400
- Returns `%Error{type: :connection_error}` on transport failure

**`describe "send_events/4"` (7 tests):**
- Returns `{:ok, %{}}` on successful 200 response
- Sends session token `Bearer tok_test_abc` (not API key `sk_test_123`)
- Sends JSON-encoded body containing `"events"` key with list
- Returns `{:error, :session_expired}` when `expires_at` is in the past (no Mox expect — no HTTP call)
- Returns `{:error, :session_expired}` on server 401 with `billing_meter_event_session_expired` code
- Returns `{:error, %Error{type: :invalid_request_error}}` with "empty" message for empty events list
- Returns `{:error, %Error{type: :api_error}}` on 500 response

### Integration Test Skeleton (`test/lattice_stripe/billing/meter_event_stream_integration_test.exs`)

Skipped via `@moduletag :skip` with documentation explaining why: stripe-mock v0.197.0 serves only the v1 OpenAPI spec and returns 404 for both v2 endpoints. The test shape is fully verified via Mox. The file includes the lifecycle test shape (create session → send events) ready to unskip when stripe-mock adds v2 support.

### ExDoc Groups (`mix.exs`)

`LatticeStripe.Billing.MeterEventStream` and `LatticeStripe.Billing.MeterEventStream.Session` added to the `"Billing Metering"` group after `MeterEventAdjustment.Cancel`.

### Metering Guide (`guides/metering.md`)

New `## High-throughput metering (v2 event stream)` section added before the existing `## See also` section. Contains:
- When to use v2 vs v1 (100+ events/second threshold)
- Comparison table of v1 vs v2 differences
- Two-step usage code examples (create_session + send_events)
- Session renewal pattern with GenServer example
- Empty events list behavior
- Telemetry attachment example for send latency
- Security note on authentication_token Inspect masking

## Verification Results

1. `mix compile --warnings-as-errors` — zero warnings
2. `mix test test/lattice_stripe/billing/meter_event_stream_test.exs --trace` — 20 tests, 0 failures
3. `mix test` — 1727 tests, 0 failures, 1 skipped (162 excluded)
4. `grep -c "FormEncoder" lib/lattice_stripe/billing/meter_event_stream.ex` — 0
5. `grep -c "Client\.request" lib/lattice_stripe/billing/meter_event_stream.ex` — 0
6. `grep "MeterEventStream" mix.exs` — 2 lines in Billing Metering group

## Deviations from Plan

None — plan executed exactly as written. The module structure, helper names, telemetry event names, error return shapes, test assertions, and guide content all match the plan spec verbatim.

## Threat Model Coverage

| ID | Threat | Status |
|----|--------|--------|
| T-28-03 | API key used for send_events instead of session token | MITIGATED — "sends API key auth" test verifies Bearer sk_test_123 for create_session; "sends session token auth" test verifies Bearer tok_test_abc for send_events |
| T-28-04 | Events sent to wrong host | MITIGATED — Mox expects match exact URLs: api.stripe.com for session, meter-events.stripe.com for stream |
| T-28-05 | Expired session token sent to Stripe | MITIGATED — "returns {:error, :session_expired} when expires_at is in the past" (no Mox expect = no HTTP call); "returns {:error, :session_expired} on server 401" test |
| T-28-06 | Form-encoded body sent instead of JSON | MITIGATED — "sends Content-Type application/json" test; grep confirms no FormEncoder in module |
| T-28-07 | Session token leaked in crash dumps | MITIGATED (inherited from Plan 01 Inspect masking) |

## Known Stubs

None — all code paths are wired. The integration test is intentionally skipped (not a stub) — it is fully formed but stripe-mock lacks v2 endpoint support.

## Threat Flags

None — new files introduce no new network endpoints, no new auth paths, no file access patterns, and no schema changes at trust boundaries. The module is a client of existing Stripe endpoints, not a server.

## Self-Check: PASSED

- `lib/lattice_stripe/billing/meter_event_stream.ex` — FOUND
- `test/lattice_stripe/billing/meter_event_stream_test.exs` — FOUND (contains describe "create_session/2" and describe "send_events/4")
- `test/lattice_stripe/billing/meter_event_stream_integration_test.exs` — FOUND (contains @moduletag :skip)
- `mix.exs` — FOUND (contains LatticeStripe.Billing.MeterEventStream,)
- `guides/metering.md` — FOUND (contains ## High-throughput metering (v2 event stream))
- Commit `984b1a4` — FOUND (Task 1)
- Commit `f47a1e0` — FOUND (Task 2)
