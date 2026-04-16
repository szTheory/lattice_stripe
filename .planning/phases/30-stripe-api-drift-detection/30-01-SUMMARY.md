---
phase: 30-stripe-api-drift-detection
plan: "01"
subsystem: drift-detection
tags: [drift, openapi, mix-task, dev-tooling, dx]
dependency_graph:
  requires:
    - lib/lattice_stripe/object_types.ex (pre-existing, modified)
    - Finch (already in deps)
    - Jason (already in deps)
  provides:
    - LatticeStripe.ObjectTypes.object_map/0
    - LatticeStripe.Drift.run/1
    - LatticeStripe.Drift.format_report/1
    - LatticeStripe.Drift.resource_schemas/1 (doc false, testable)
    - LatticeStripe.Drift.known_fields_for/1 (doc false, testable)
    - LatticeStripe.Drift.compare/2 (doc false, testable)
  affects: []
tech_stack:
  added: []
  patterns:
    - Source file parsing via module.__info__(:compile)[:source] + regex for @known_fields extraction
    - Temporary Finch pool start for dev/CI context outside supervision tree
    - Test fixture as minimal OpenAPI spec3.json-shaped map (no network in tests)
    - @doc false + def (not defp) for testable internal helpers
key_files:
  created:
    - lib/lattice_stripe/drift.ex
    - test/support/fixtures/openapi_spec_fixture.ex
    - test/lattice_stripe/drift_test.exs
  modified:
    - lib/lattice_stripe/object_types.ex (added def object_map/0)
decisions:
  - "Source file parsing via __info__(:compile)[:source] + regex is the only viable approach for @known_fields at runtime — module attributes are not persisted in BEAM bytecode (confirmed via mix run -e)"
  - "resource_schemas/1 keys by properties.object.enum[0] not schema name — avoids invoiceitem/invoice_item mismatch (Pitfall 2)"
  - "Temporary Finch pool (LatticeStripe.Drift.Finch) started in fetch_spec/0 — library has no Application module, Mix task context is outside supervision tree"
  - "All internal helpers are @doc false + def (not defp) to enable direct test calls without mocking — follows TestClock.Cleanup.parse_duration!/1 pattern"
  - "Test fixture uses minimal spec3.json-shaped map with deterministic customer/invoice/tax.calculation schemas — zero network calls in tests"
metrics:
  duration: "~15 minutes"
  completed: "2026-04-16"
  tasks_completed: 2
  tasks_total: 2
  files_created: 3
  files_modified: 1
  tests_added: 23
  test_suite_size: 1783
---

# Phase 30 Plan 01: Drift Detection Core Engine Summary

Implemented the core drift detection business logic for DX-06 (Stripe API drift detection). This is the pure-logic layer that Plan 02 (Mix task shell) will invoke.

## What Was Built

**`LatticeStripe.ObjectTypes.object_map/0`** — Single-line addition: `def object_map, do: @object_map`. Exposes the compile-time `@object_map` attribute at runtime, required because BEAM bytecode does not persist private module attributes. The registry has 32 entries.

**`LatticeStripe.Drift`** — Core drift detection module with `@moduledoc false` (internal dev tooling). Public API:
- `run/1` — Downloads Stripe spec, extracts first-class schemas, compares against `@known_fields` for each registered module, returns `{:ok, %{drift_count, modules, new_resources}}`
- `format_report/1` — Formats result into D-02 human-readable output: `+ additions (type)`, `- removals (warning: in @known_fields but not in spec)`, new resources section
- `resource_schemas/1` — Extracts first-class schemas from spec, keyed by `properties.object.enum[0]` (not schema name)
- `known_fields_for/1` — Reads source file via `__info__(:compile)[:source]`, applies `~r/@known_fields\s+~w\[([^\]]+)\]/s` regex
- `compare/2` — Pure `MapSet.difference` logic for additions/removals

**`test/support/fixtures/openapi_spec_fixture.ex`** — `LatticeStripe.Test.Fixtures.OpenApiSpec.minimal_spec/0` with:
- `"customer"` schema: includes `"new_spec_only_field"` (tests additions)
- `"invoice"` schema: minimal fields (tests removals when compared against full `@known_fields`)
- `"tax_calculation"` schema with `enum: ["tax.calculation"]` (tests schema name vs object type key distinction — Pitfall 2)
- `"coupon_applies_to"` schema: no object enum (tests non-first-class filtering)
- `"multi_enum_resource"` schema: two-element enum (tests multi-enum filtering)

**`test/lattice_stripe/drift_test.exs`** — 23 tests across 4 describe blocks. All async: true. Zero network calls.

## Threat Mitigations Applied

- **T-30-01 (Tampering):** `resource_schemas/1` guards on `get_in(spec, ["components", "schemas"])` returning nil; `Jason.decode/1` error propagates via `with` chain
- **T-30-02 (DoS):** `fetch_spec/0` passes `receive_timeout: 30_000` to `Finch.request/3`
- **T-30-03 (Tampering):** Source file parsing is read-only; no code execution from parsed content

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

### Notes

The `format_report/1` function has two heads: one pattern-matches `%{drift_count: 0, modules: [], new_resources: []}` for the clean case, and the general case handles any combination of drift + new resources (including the case where `drift_count: 0` but `new_resources` is non-empty). This edge case (new resources but no field drift) is handled correctly.

## Stub Tracking

No stubs. All functions are fully implemented. The `run/1` function makes a real network call to the Stripe OpenAPI spec — this is intentional for the Mix task context. Tests use fixture data exclusively.

## Self-Check

- [x] `lib/lattice_stripe/object_types.ex` — exists, contains `def object_map`
- [x] `lib/lattice_stripe/drift.ex` — exists, contains `defmodule LatticeStripe.Drift`
- [x] `test/support/fixtures/openapi_spec_fixture.ex` — exists, contains `def minimal_spec`
- [x] `test/lattice_stripe/drift_test.exs` — exists, 23 tests, all passing
- [x] `mix compile --warnings-as-errors` — exits 0
- [x] `mix test test/lattice_stripe/drift_test.exs` — 23 tests, 0 failures
- [x] `mix test` (full suite) — 1783 tests, 0 failures, 1 skipped
- [x] `LatticeStripe.ObjectTypes.object_map()` — returns map with 32 entries

## Self-Check: PASSED
