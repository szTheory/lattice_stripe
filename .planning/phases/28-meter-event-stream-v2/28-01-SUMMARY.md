---
phase: 28-meter-event-stream-v2
plan: "01"
subsystem: billing/metering
tags:
  - session-struct
  - inspect-masking
  - security
  - fixtures
  - unit-tests
dependency_graph:
  requires: []
  provides:
    - LatticeStripe.Billing.MeterEventStream.Session struct
    - MeterEventStreamSession fixture
    - meter_event_stream_test.exs (Session describe blocks)
  affects:
    - test/support/fixtures/metering.ex (new nested module added)
    - test/lattice_stripe/billing/meter_event_stream_test.exs (new file)
tech_stack:
  added: []
  patterns:
    - from_map/1 with nil clause (matches BillingPortal.Session pattern)
    - Inspect protocol allowlist (authentication_token excluded as bearer credential)
    - Nested fixture defmodule inside LatticeStripe.Test.Fixtures.Metering
key_files:
  created:
    - lib/lattice_stripe/billing/meter_event_stream/session.ex
    - test/lattice_stripe/billing/meter_event_stream_test.exs
  modified:
    - test/support/fixtures/metering.ex
decisions:
  - "Session struct has no :extra field — v2 response shape is stable and well-defined"
  - "authentication_token excluded from Inspect allowlist — bearer credential for v2 event stream endpoint"
  - "from_map/1 maps string keys directly — no @known_fields indirection needed for 6-field stable struct"
metrics:
  duration: "2 minutes"
  completed: "2026-04-16T21:59:20Z"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 1
---

# Phase 28 Plan 01: MeterEventStream.Session Struct + Fixture + Tests Summary

**One-liner:** Session struct for Stripe v2 meter event stream with authentication_token bearer credential masked via Inspect protocol allowlist.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Session struct + from_map/1 + Inspect masking | 1ac33b3 | lib/lattice_stripe/billing/meter_event_stream/session.ex (created) |
| 2 | Session fixture + unit tests | 36be4aa | test/support/fixtures/metering.ex (modified), test/lattice_stripe/billing/meter_event_stream_test.exs (created) |

## What Was Built

### Session Struct (`lib/lattice_stripe/billing/meter_event_stream/session.ex`)

`LatticeStripe.Billing.MeterEventStream.Session` — a 6-field struct representing the short-lived session returned by Stripe's v2 meter event session creation endpoint:

- `id` — session identifier (`mes_*`)
- `object` — always `"v2.billing.meter_event_session"`
- `authentication_token` — bearer credential for the event stream endpoint (masked in Inspect)
- `created` — Unix timestamp of session creation
- `expires_at` — Unix timestamp when session expires (15-minute TTL)
- `livemode` — live vs. test mode flag

`from_map/1` has two clauses: `from_map(nil) -> nil` and `from_map(map) when is_map(map)` mapping string keys directly to struct fields. No `@known_fields` / `:extra` needed — the v2 response shape is stable.

The `Inspect` protocol implementation follows the allowlist pattern established by `MeterEvent` (masks `:payload`) and `BillingPortal.Session` (masks `:url`). The `authentication_token` field is intentionally absent from the rendered output — it is a bearer credential valid for the 15-minute session TTL.

### Fixture (`test/support/fixtures/metering.ex`)

`MeterEventStreamSession` nested module added after `MeterEventAdjustment` inside `LatticeStripe.Test.Fixtures.Metering`. `basic/1` returns a string-keyed v2 wire-format map with `authentication_token: "tok_test_abc"` — the test value chosen specifically so masking tests can `refute r =~ "tok_test_abc"`.

### Tests (`test/lattice_stripe/billing/meter_event_stream_test.exs`)

7 tests across two describe blocks:

**`Session.from_map/1` (3 tests):**
- Deserializes all 6 fields from v2 wire format
- Returns nil for nil input
- Handles fixture overrides correctly

**`Session Inspect masking` (4 tests — threat model T-28-01 and T-28-02):**
- Renders with `#LatticeStripe.Billing.MeterEventStream.Session<` prefix
- Token VALUE (`tok_test_abc`) absent from rendered string (T-28-01)
- Token KEY (`authentication_token:`) absent from rendered string (T-28-02)
- Structural fields (id, object, created, expires_at, livemode) present

## Verification Results

- `mix compile --warnings-as-errors` — zero warnings
- `mix test test/lattice_stripe/billing/meter_event_stream_test.exs` — 7 tests, 0 failures
- `mix test` (full suite) — 1713 tests, 0 failures (162 excluded; the 1 intermittent failure in `BatchTest` was confirmed as a pre-existing flaky timing issue unrelated to this plan)

## Deviations from Plan

None — plan executed exactly as written. The Inspect implementation and fixture match the plan spec verbatim. No unexpected complexity encountered.

## Threat Model Coverage

| ID | Threat | Status |
|----|--------|--------|
| T-28-01 | `authentication_token` value leaked in Inspect output | MITIGATED — `refute r =~ "tok_test_abc"` test passes |
| T-28-02 | `authentication_token` key name leaked in Inspect output | MITIGATED — `refute r =~ "authentication_token:"` test passes |

## Known Stubs

None — this plan delivers a complete, fully-wired data struct with real deserialization and security-correct Inspect masking. No placeholder values flow to any consumer.

## Threat Flags

None — new file introduces no network endpoints, no auth paths, no file access patterns, and no schema changes at trust boundaries. The Inspect masking positively reduces the threat surface for the authentication_token bearer credential.

## Self-Check: PASSED

- `lib/lattice_stripe/billing/meter_event_stream/session.ex` — FOUND
- `test/support/fixtures/metering.ex` — FOUND (contains `MeterEventStreamSession`)
- `test/lattice_stripe/billing/meter_event_stream_test.exs` — FOUND
- Commit `1ac33b3` — FOUND (Task 1)
- Commit `36be4aa` — FOUND (Task 2)
