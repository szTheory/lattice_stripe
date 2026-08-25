---
phase: 71
slug: reliability-ci-security
status: validated
nyquist_compliant: false
wave_0_complete: true
created: 2026-08-25
---

# Phase 71 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | ExUnit, GitHub Actions, actionlint, Hex tooling |
| Quick run | `mix test test/lattice_stripe/batch_test.exs test/lattice_stripe/client/request_building_test.exs --warnings-as-errors` |
| Full suite | `mix ci` plus required remote `ci-gate` |

## Requirement Map

| Requirements | Evidence | Status |
|--------------|----------|--------|
| REL-01, REL-02 | concurrency-focused tests; 100 focused and 10 full-suite stress runs; unique telemetry paths | covered |
| REL-03 | required Fuse and OpenTelemetry lanes; one documented stripe-mock skip | covered |
| REL-04, REL-06 | immutable workflow inputs, explicit gates, actionlint, matrix `fail-fast: false`, aggregate `ci-gate` | source/remote verified |
| REL-05 | enforced 80% floor; close result 80.57% with Finch success/failure proof | covered |
| SEC-01 | live GitHub protection and security settings | manual remote verification |

## Manual-Only Verifications

| Behavior | Requirement | Why manual | Result |
|----------|-------------|------------|--------|
| Branch protection and security automation match policy | SEC-01 | GitHub-hosted mutable state cannot be proven by local ExUnit. | verified live at close |
| Matrix continues after a failed leg | REL-06 | Workflow orchestration is source- and remote-run evidence. | verified by config and remote run |

## Validation Sign-Off

- [x] Every code path and CI lane has executable evidence.
- [x] Hosted-state checks remain explicit operational verification.

**Approval:** validated 2026-08-25 (partial Nyquist; live GitHub state retained)
