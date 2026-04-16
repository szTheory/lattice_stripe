---
phase: 30-stripe-api-drift-detection
verified: 2026-04-16T19:32:00Z
status: human_needed
score: 7/7
overrides_applied: 0
human_verification:
  - test: "Run `mix lattice_stripe.check_drift` against the live Stripe spec"
    expected: "Command completes, prints either 'No drift detected' or a formatted drift report; exits 0 for no per-module drift and 1 when drift_count > 0"
    why_human: "Requires live network access to raw.githubusercontent.com to download spec3.json (~7.6MB); cannot be tested without network in CI-safe automated checks"
  - test: "Trigger the GitHub Actions drift workflow manually (workflow_dispatch)"
    expected: "Workflow runs to completion; if drift is found, a GitHub issue is created with label 'stripe-drift'; if no drift, workflow exits cleanly"
    why_human: "Requires GitHub Actions execution environment with GITHUB_TOKEN and gh CLI; cannot verify issue creation or exit code capture from local checks"
---

# Phase 30: Stripe API Drift Detection — Verification Report

**Phase Goal:** CI automatically detects when Stripe's OpenAPI specification adds new fields or resources that are not yet reflected in LatticeStripe's `@known_fields` — surfacing drift as a GitHub issue before it reaches users.
**Verified:** 2026-04-16T19:32:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Developer can run `mix lattice_stripe.check_drift` and see a drift report or clean message | VERIFIED | `mix help` shows task with shortdoc; task calls `Drift.run/1` and `Drift.format_report/1`; `Mix.shell().info/1` used exclusively (no `IO.puts`); exit logic: 0 for clean, 1 for drift |
| 2 | Mix task exits with code 1 when drift is found, 0 when clean | VERIFIED | `System.halt(1)` on `drift_count > 0` branch; new resources alone trigger informational output but NOT exit 1 per D-06 |
| 3 | GitHub Actions cron workflow runs weekly and creates/updates an issue on drift detection | VERIFIED | `cron: '0 9 * * 1'` (Monday 09:00 UTC) present; `workflow_dispatch` for manual trigger; issue create/update with `stripe-drift` label; `gh label create --force` for idempotent label provisioning |
| 4 | Duplicate drift issues are prevented via stripe-drift label search | VERIFIED | `gh issue list --label "stripe-drift" --state open --jq '.[0].number // empty'` finds existing open issue; comments on existing vs creates new |
| 5 | ObjectTypes.object_map/0 returns the full Stripe-object-type-to-module mapping at runtime | VERIFIED | `def object_map, do: @object_map` added; runtime check confirms 32 entries returned |
| 6 | Drift.run/1 returns {:ok, result} with additions, removals, and new_resources from a parsed spec | VERIFIED | Full implementation in `lib/lattice_stripe/drift.ex`; result map: `%{drift_count, modules, new_resources}`; all 23 unit tests pass |
| 7 | Source file parsing extracts @known_fields from both single-line and multi-line ~w[] forms | VERIFIED | Regex `~r/@known_fields\s+~w\[([^\]]+)\]/s` with `s` flag for multiline matching; test confirms `LatticeStripe.Invoice` (multiline `~w[]`) parsed correctly |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/lattice_stripe/object_types.ex` | object_map/0 public accessor | VERIFIED | Contains `def object_map, do: @object_map` at line 40; 32 entries in registry |
| `lib/lattice_stripe/drift.ex` | Core drift detection logic | VERIFIED | 232 lines; exports `run/1`, `format_report/1`, `resource_schemas/1`, `known_fields_for/1`, `compare/2`; all `@doc false` + `def` for testability |
| `test/lattice_stripe/drift_test.exs` | Unit tests for Drift module | VERIFIED | 314 lines, 23 tests, 4 describe blocks, all async: true, 0 failures |
| `test/support/fixtures/openapi_spec_fixture.ex` | Minimal OpenAPI spec fixture | VERIFIED | `defmodule LatticeStripe.Test.Fixtures.OpenApiSpec`; `minimal_spec/0` with customer/invoice/tax_calculation/coupon_applies_to/multi_enum_resource schemas |
| `lib/mix/tasks/lattice_stripe.check_drift.ex` | Mix task shell for drift detection | VERIFIED | 52 lines; `use Mix.Task`, `@shortdoc`, `@impl Mix.Task`, `Mix.Task.run("app.start")`, `System.halt(1)`, no `IO.puts` |
| `.github/workflows/drift.yml` | Weekly cron workflow | VERIFIED | Cron Monday 09:00 UTC + `workflow_dispatch`; `permissions: contents: read, issues: write` (no `contents: write`); issue deduplication via `stripe-drift` label |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/lattice_stripe/drift.ex` | `lib/lattice_stripe/object_types.ex` | `ObjectTypes.object_map/0` call | WIRED | `ObjectTypes.object_map()` called at line 18 in `run/1` via `with` chain |
| `lib/lattice_stripe/drift.ex` | source files | `module.__info__(:compile)[:source]` + `List.to_string/1` | WIRED | Both present at lines 165 and 170 respectively |
| `test/lattice_stripe/drift_test.exs` | `test/support/fixtures/openapi_spec_fixture.ex` | fixture alias | WIRED | `alias LatticeStripe.Test.Fixtures.OpenApiSpec` at line 5; `OpenApiSpec.minimal_spec()` called in 4 tests |
| `lib/mix/tasks/lattice_stripe.check_drift.ex` | `lib/lattice_stripe/drift.ex` | `Drift.run/1` and `Drift.format_report/1` | WIRED | `LatticeStripe.Drift.run(opts)` at line 34; `LatticeStripe.Drift.format_report(result)` at lines 38 and 45 |
| `.github/workflows/drift.yml` | `lib/mix/tasks/lattice_stripe.check_drift.ex` | `mix lattice_stripe.check_drift` command | WIRED | `mix lattice_stripe.check_drift 2>&1 | tee /tmp/drift_report.txt` at line 60 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `lib/lattice_stripe/drift.ex` | `spec` | `fetch_spec/0` via Finch HTTP to Stripe OpenAPI URL | Real HTTP fetch with Jason decode; temporary Finch pool started | FLOWING (network-dependent) |
| `lib/lattice_stripe/drift.ex` | `object_map` | `ObjectTypes.object_map/0` | Real compile-time `@object_map` with 32 entries | FLOWING (verified at runtime: 32 entries) |
| `lib/lattice_stripe/drift.ex` | `known_fields` | `known_fields_for/1` reads source file via `__info__(:compile)[:source]` | Real source file read + regex extraction; test confirms Customer and Invoice fields extracted correctly | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `ObjectTypes.object_map/0` returns 32+ entries at runtime | `mix run -e "IO.inspect(map_size(...), label: \"entries\")"` | `object_map entries: 32` | PASS |
| Mix task listed in `mix help` | `mix help \| grep check_drift` | `mix lattice_stripe.check_drift  # Check for Stripe API drift against @known_fields` | PASS |
| All drift unit tests pass (23 tests, no network) | `mix test test/lattice_stripe/drift_test.exs --trace` | 23 tests, 0 failures | PASS |
| Compilation clean | `mix compile --warnings-as-errors` | Exit 0, no output | PASS |
| End-to-end mix task with live spec | `mix lattice_stripe.check_drift` | Requires live network — not run locally | SKIP (human needed) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| DX-06 | 30-01-PLAN.md, 30-02-PLAN.md | CI detects Stripe OpenAPI spec drift via weekly cron + Mix task | SATISFIED | Core engine (Drift module, ObjectTypes accessor), Mix task, and GitHub Actions workflow all delivered and verified; unit tests pass; task listed in `mix help` |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/lattice_stripe/drift.ex` | 113 | `"New resources not yet implemented..."` string | Info | Report output text only — not a code stub; this is the intended user-facing message per D-02 |

No actionable anti-patterns found. The "not yet implemented" text is intentional report output per the plan specification.

### Human Verification Required

#### 1. Live Drift Check Execution

**Test:** Run `mix lattice_stripe.check_drift` in the project root against the live Stripe OpenAPI spec.
**Expected:** Command downloads spec3.json (~7.6MB) from raw.githubusercontent.com, compares all 32 registered modules' `@known_fields` against the live spec, and either prints "No drift detected. @known_fields are up to date." (exit 0) or a formatted drift report with `+`/`-` prefixed fields grouped by module (exit 1 if `drift_count > 0`). New resources section shows unregistered Stripe object types.
**Why human:** Requires live network access to raw.githubusercontent.com. The temporary Finch pool (`LatticeStripe.Drift.Finch`) must start successfully in the Mix task context.

#### 2. GitHub Actions Drift Workflow — End-to-End

**Test:** Trigger the drift workflow manually via the GitHub Actions "Run workflow" button (workflow_dispatch) on the main branch.
**Expected:** Workflow runs to completion (under 10 minutes). If drift is found (`exit_code == '1'`): a GitHub issue is created with title "Stripe API drift detected - YYYY-MM-DD", label "stripe-drift", and the drift report as body. On re-run with an existing open issue: a comment is added to the existing issue instead of creating a duplicate. The "stripe-drift" label is created idempotently on first run.
**Why human:** Requires GitHub Actions execution environment with GITHUB_TOKEN, `gh` CLI, and live internet access. Cannot verify issue creation or `PIPESTATUS` exit code capture from local checks.

### Gaps Summary

No gaps found. All 7 observable truths are verified. All artifacts exist, are substantive, and are wired. The two human verification items test live network and GitHub Actions runtime behavior — automated checks cannot substitute for these.

---

_Verified: 2026-04-16T19:32:00Z_
_Verifier: Claude (gsd-verifier)_
