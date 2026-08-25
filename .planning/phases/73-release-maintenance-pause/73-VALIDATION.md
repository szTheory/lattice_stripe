---
phase: 73
slug: release-maintenance-pause
status: validated
nyquist_compliant: false
wave_0_complete: true
created: 2026-08-25
---

# Phase 73 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Local CI + GitHub/Hex/HexDocs operational probes |
| Quick run | `./scripts/maintainer/repo_hygiene_check.sh` |
| Full suite | `mix ci` plus exact-head remote `ci-gate` |

## Requirement Map

| Requirement | Evidence | Status |
|-------------|----------|--------|
| CLOSE-01 | current ledgers plus live issue/PR queries | manual operational verification |
| CLOSE-02 | `mix ci`, coverage, optional lanes, package build, hygiene, remote aggregate gate | covered |
| CLOSE-03 | GitHub Release/tag, release run, Hex checksum, and public HexDocs probes | manual external verification |
| CLOSE-04 | live branch/security/PR/issue/worktree state | manual operational verification |

## Manual-Only Verifications

| Behavior | Requirement | Why manual | Result |
|----------|-------------|------------|--------|
| Public release and docs resolve with recorded provenance | CLOSE-03 | Registries and hosted docs are external mutable services. | verified at close |
| Protected `main`, triage, and clean worktrees | CLOSE-01, CLOSE-04 | GitHub and filesystem operational state must be queried live. | verified at close |

## Validation Sign-Off

- [x] Deterministic release-candidate behavior is automated.
- [x] External proof boundaries are queried and recorded, never flattened into local tests.

**Approval:** validated 2026-08-25 (partial Nyquist; external operations retained)
