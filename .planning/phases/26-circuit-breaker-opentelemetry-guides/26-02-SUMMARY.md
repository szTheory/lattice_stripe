---
phase: 26-circuit-breaker-opentelemetry-guides
plan: "02"
subsystem: documentation
tags: [opentelemetry, otel, telemetry, tracing, guides, integration-test, honeycomb, datadog]
dependency_graph:
  requires:
    - lib/lattice_stripe/telemetry.ex
    - guides/telemetry.md
    - guides/circuit-breaker.md
  provides:
    - guides/opentelemetry.md
    - test/integration/opentelemetry_integration_test.exs
  affects:
    - mix.exs
    - mix.lock
tech_stack:
  added:
    - "opentelemetry_api ~> 1.4 (dev/test dependency)"
    - "opentelemetry ~> 1.5 (dev/test dependency)"
    - "opentelemetry_exporter ~> 1.8 (dev/test dependency)"
  patterns:
    - "Telemetry event bridge to OTel spans via :telemetry.attach_many/4"
    - "Stable OTel HTTP semantic conventions (http.request.method, http.response.status_code)"
    - "ExUnit.Case with @moduletag for tag-excluded integration tests"
key_files:
  created:
    - guides/opentelemetry.md
    - test/integration/opentelemetry_integration_test.exs
  modified:
    - mix.exs
    - mix.lock
decisions:
  - "opentelemetry_exporter listed before opentelemetry in deps for correct initialization order"
  - "Stable OTel semconv used throughout: http.request.method not http.method (deprecated since v1.20.0)"
  - "API key guidance uses config/runtime.exs with System.fetch_env! for Honeycomb; Datadog uses Agent on localhost (no secrets in config)"
metrics:
  duration: "~4 minutes"
  completed: "2026-04-16"
  tasks_completed: 3
  tasks_total: 3
  files_created: 2
  files_modified: 2
---

# Phase 26 Plan 02: OpenTelemetry Guide Summary

OpenTelemetry integration guide with complete `MyApp.StripeOtelHandler` bridging LatticeStripe telemetry events to OTel spans, Honeycomb and Datadog backend examples using stable semconv, and CI-excluded integration test verifying guide code compiles.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add opentelemetry deps and ExDoc extras entry | 8540866 | mix.exs, mix.lock |
| 2 | Write guides/opentelemetry.md | 16bc014 | guides/opentelemetry.md |
| 3 | Create CI-excluded OTel integration test | 1bde286 | test/integration/opentelemetry_integration_test.exs |

## Verification Results

- `mix deps.get` — PASSED (opentelemetry_api 1.5.0, opentelemetry 1.7.0, opentelemetry_exporter 1.10.0 in lock)
- `mix compile --warnings-as-errors` — PASSED
- `mix test` — PASSED (1699 tests, 0 failures, 162 excluded — 5 otel_integration excluded)
- `mix test ... --include otel_integration` — PASSED (5 tests, 0 failures)
- `guides/opentelemetry.md` Honeycomb and Datadog examples — CONFIRMED
- Stable OTel semantic conventions used — CONFIRMED
- `@moduletag :otel_integration` tag excludes from default runs — CONFIRMED

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. The guide contains complete, working code examples verified by integration tests.

## Threat Flags

None. The guide uses `System.fetch_env!("HONEYCOMB_API_KEY")` in `config/runtime.exs` for Honeycomb API key handling (T-26-03 mitigation applied). Span attributes contain only operational data — no PII, no Stripe API keys (T-26-04 accepted).

## Self-Check: PASSED

- guides/opentelemetry.md: FOUND
- test/integration/opentelemetry_integration_test.exs: FOUND
- Commit 8540866: FOUND
- Commit 16bc014: FOUND
- Commit 1bde286: FOUND
