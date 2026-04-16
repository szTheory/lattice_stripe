---
phase: 30-stripe-api-drift-detection
plan: "02"
subsystem: drift-detection
tags: [drift, openapi, mix-task, github-actions, dx, ci]
dependency_graph:
  requires:
    - lib/lattice_stripe/drift.ex (from Plan 01)
    - lib/lattice_stripe/object_types.ex (from Plan 01)
    - .github/workflows/ci.yml (boilerplate reference)
  provides:
    - Mix.Tasks.LatticeStripe.CheckDrift (mix lattice_stripe.check_drift)
    - .github/workflows/drift.yml (weekly cron CI drift detection)
  affects:
    - DX-06 (completes requirement)
tech_stack:
  added: []
  patterns:
    - Mix task thin shell over pure-logic module (Drift.run/1 + Drift.format_report/1)
    - System.halt(1) for programmatic exit code (not Mix.raise which prints stacktrace)
    - GitHub Actions continue-on-error + PIPESTATUS exit code capture pattern
    - gh issue list --jq deduplication pattern for preventing duplicate issues
    - gh label create --force for idempotent label provisioning
key_files:
  created:
    - lib/mix/tasks/lattice_stripe.check_drift.ex
    - .github/workflows/drift.yml
  modified: []
decisions:
  - "System.halt(1) used for drift-found exit rather than Mix.raise — avoids unwanted stacktrace output on non-error condition"
  - "New resources (new_resources != []) are informational — printed via format_report but do NOT trigger exit code 1 per D-06"
  - "workflow_dispatch added alongside cron schedule for manual trigger without waiting for Monday"
  - "PIPESTATUS[0] captures Mix task exit code despite tee pipe swallowing it in the shell step"
  - "gh issue list --jq '.[0].number // empty' pattern safely returns empty string when no open issue exists"
metrics:
  duration: "~8 minutes"
  completed: "2026-04-16"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 0
  tests_added: 0
  test_suite_size: 1783
---

# Phase 30 Plan 02: Mix Task Shell and CI Workflow Summary

Delivered the two user-facing surfaces of DX-06 drift detection: a local `mix lattice_stripe.check_drift` command for developers and a weekly GitHub Actions workflow that opens/updates issues when drift is detected.

## What Was Built

**`Mix.Tasks.LatticeStripe.CheckDrift`** — Thin shell over `LatticeStripe.Drift`. Calls `Mix.Task.run("app.start")` to load all modules before invoking `Drift.run/1`. Output routing:
- `drift_count: 0` + no new resources → clean message
- `drift_count: 0` + new resources → `format_report/1` output (informational, exit 0)
- `drift_count > 0` → `format_report/1` output + `System.halt(1)` (exit 1)
- `{:error, reason}` → `Mix.raise/1` (fatal, with context message)

Uses `Mix.shell().info/1` exclusively for output (no `IO.puts`). Listed in `mix help` as "Check for Stripe API drift against @known_fields".

**`.github/workflows/drift.yml`** — Weekly cron (Mondays 09:00 UTC) + `workflow_dispatch` for manual trigger. Key design:
- Permissions: `contents: read` + `issues: write` only (T-30-04 mitigation — no `contents: write`)
- Idempotent label creation: `gh label create "stripe-drift" --force`
- Exit code capture: `PIPESTATUS[0]` via `tee /tmp/drift_report.txt` pipe
- Issue deduplication: `gh issue list --label "stripe-drift" --state open` to find existing open issue; adds comment if found, creates new issue if not
- Cache keys identical to `ci.yml` for shared dep/build cache hits

## Threat Mitigations Applied

- **T-30-04 (Elevation of Privilege):** Workflow permissions scoped to `contents: read, issues: write` only — no `contents: write`, no `pull-requests: write`; GITHUB_TOKEN cannot push code or merge PRs
- **T-30-05 (Spoofing):** Spec fetched by Drift.run/1 over HTTPS (implemented in Plan 01 via Finch with system CA store)
- **T-30-06 (Information Disclosure):** Accepted — drift report contains only public API field names

## Deviations from Plan

None — plan executed exactly as written.

## Stub Tracking

No stubs. Both files are fully implemented and functional.

## Self-Check

- [x] `lib/mix/tasks/lattice_stripe.check_drift.ex` — exists, contains `defmodule Mix.Tasks.LatticeStripe.CheckDrift`
- [x] `lib/mix/tasks/lattice_stripe.check_drift.ex` — contains `use Mix.Task`, `@shortdoc`, `@impl Mix.Task`
- [x] `lib/mix/tasks/lattice_stripe.check_drift.ex` — contains `Mix.Task.run("app.start")`
- [x] `lib/mix/tasks/lattice_stripe.check_drift.ex` — contains `LatticeStripe.Drift.run(` and `LatticeStripe.Drift.format_report(`
- [x] `lib/mix/tasks/lattice_stripe.check_drift.ex` — contains `System.halt(1)`, uses `Mix.shell().info(`, no `IO.puts`
- [x] `.github/workflows/drift.yml` — exists with all acceptance criteria verified
- [x] `mix compile --warnings-as-errors` — exits 0
- [x] `mix test` — 1783 tests, 0 failures, 1 skipped
- [x] `mix help | grep check_drift` — shows task with shortdoc

## Self-Check: PASSED
