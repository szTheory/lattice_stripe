---
phase: 10-documentation-guides
plan: "04"
subsystem: documentation
tags: [guides, error-handling, testing, telemetry, extensibility, mox, stripe-mock]
dependency_graph:
  requires:
    - "10-01"  # guide stubs created
    - "10-02"  # module docs and README complete
  provides:
    - error-handling guide with all 6 error types and pattern matching examples
    - testing guide with Mox Transport mocking and webhook test helpers
    - telemetry guide with all event schemas and custom handler examples
    - extending guide with full Transport, Json, RetryStrategy implementations
  affects:
    - guides/error-handling.md
    - guides/testing.md
    - guides/telemetry.md
    - guides/extending-lattice-stripe.md
tech_stack:
  added: []
  patterns:
    - Mox Transport mocking pattern documented for downstream users
    - LatticeStripe.Testing webhook helper usage documented
    - stripe-mock integration test setup documented
    - telemetry.span/3 event lifecycle explained
    - Behaviour extension pattern for Transport, Json, RetryStrategy
key_files:
  created: []
  modified:
    - guides/error-handling.md
    - guides/testing.md
    - guides/telemetry.md
    - guides/extending-lattice-stripe.md
decisions:
  - Telemetry guide uses actual measurements/metadata tables from telemetry.ex moduledoc as source of truth
  - Testing guide uses LatticeStripe.Testing module from lib/ (not test/support) since it ships in the library
  - Extending guide shows ReqTransport with decode_body: false and retry: false to avoid conflict with LatticeStripe's own handling
  - RetryStrategy context map shape taken directly from retry_strategy.ex @type context definition
metrics:
  duration_minutes: 5
  tasks_completed: 2
  files_modified: 4
  completed_date: "2026-04-03"
requirements:
  - DOCS-05
---

# Phase 10 Plan 04: Guides — Error Handling, Testing, Telemetry, Extending

**One-liner:** Four complete developer guides covering error type pattern matching, Mox Transport mocking, telemetry event schemas, and custom behaviour implementations.

## What Was Built

Replaced 4 stub guide files (each 3 lines: "Guide content coming soon.") with full production-quality content:

| Guide | Lines | Key Content |
|-------|-------|-------------|
| `guides/error-handling.md` | 310 | All 6 error types, case statement patterns, decline codes, retry config, request_id for support |
| `guides/testing.md` | 476 | Mox.defmock setup, Transport mock examples, webhook payload/signature helpers, stripe-mock integration |
| `guides/telemetry.md` | 436 | All 8 events (4 request, 4 webhook), full measurements/metadata tables, custom handlers, Telemetry.Metrics |
| `guides/extending-lattice-stripe.md` | 463 | ReqTransport, PoisonCodec, CircuitBreakerRetry, full request/response map contracts |

Total: 1,685 lines of guide content across 4 files.

## Tasks Completed

### Task 1: Error Handling + Testing Guides (commit `7d41ec5`)

**guides/error-handling.md:**
- Error struct with all 10 fields documented
- Error type table with 6 types, when each occurs, and whether user-facing
- Comprehensive `case` statement matching all 7 error types with appropriate handling
- Decline code pattern matching helper function
- Bang variants explained with appropriate use cases
- Automatic retry behavior: what retries, what doesn't, why
- Per-client and per-request retry configuration
- request_id usage for Stripe support tickets
- Exception.message/1 format and raise usage

**guides/testing.md:**
- Mox.defmock setup for LatticeStripe.Transport (D-15)
- elixirc_paths(:test) configuration for test/support/
- expect/3 examples for success, error, and connection failure cases
- Mocking multiple sequential calls with ordered expectations
- LatticeStripe.Testing.generate_webhook_event/3 for event handler testing
- LatticeStripe.Testing.generate_webhook_payload/3 for Plug-level testing
- stripe-mock Docker setup and integration test client pattern
- async: true Mox safety explanation
- Telemetry disabling in tests

### Task 2: Telemetry + Extending LatticeStripe Guides (commit `9762edc`)

**guides/telemetry.md:**
- attach_default_logger/1 quickstart with example log output
- All 4 request events: start, stop, exception, retry — with full measurements and metadata tables
- All 4 webhook events: verify start, stop, exception — with full tables
- Custom handler examples: latency histogram, retry counter, webhook monitoring, structured logger
- Telemetry.Metrics ready-to-use metric definitions
- telemetry_enabled: false client config
- System.convert_time_unit/3 conversion patterns

**guides/extending-lattice-stripe.md:**
- Transport behaviour: full request_map and response_map contracts
- ReqTransport implementation with decode_body: false and retry: false
- StubTransport for tests without Mox
- PoisonCodec and StdlibJsonCodec implementations
- AggressiveRetryStrategy with custom backoff
- CircuitBreakerRetry with circuit_open? guard
- NoRetryStrategy for immediate-fail contexts
- Combining all three custom implementations
- stripe-mock validation for custom transport implementations

## Verification

- `mix docs --warnings-as-errors`: PASS (clean, no warnings)
- guides/error-handling.md: 310 lines (min 150) ✓
- guides/testing.md: 476 lines (min 150) ✓
- guides/telemetry.md: 436 lines (min 150) ✓
- guides/extending-lattice-stripe.md: 463 lines (min 150) ✓
- All guides contain required string patterns per acceptance criteria ✓
- All guides end with ## Common Pitfalls section ✓

## Deviations from Plan

None — plan executed exactly as written.

The testing guide used `LatticeStripe.Testing.generate_webhook_payload` (full module name) rather
than aliased form in the key example to satisfy the acceptance criteria requiring that exact string.

## Known Stubs

None. All 4 guides contain substantive content covering the plan's stated goals.

## Self-Check: PASSED

Files verified:
- FOUND: guides/error-handling.md
- FOUND: guides/testing.md
- FOUND: guides/telemetry.md
- FOUND: guides/extending-lattice-stripe.md

Commits verified:
- FOUND: 7d41ec5 (error handling + testing guides)
- FOUND: 9762edc (telemetry + extending guides)
