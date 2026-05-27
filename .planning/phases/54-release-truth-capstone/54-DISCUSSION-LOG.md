# Phase 54: Release Truth Capstone - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 54-release-truth-capstone
**Areas discussed:** All five gray areas (user requested full research + one-shot recommendations)

---

## Install-line lockstep scope

| Option | Description | Selected |
|--------|-------------|----------|
| REL-03 literal only | README, getting-started, cheatsheet, thin-events | |
| **7-surface atomic flip + README narrative** | All install anchors including opentelemetry; retire canaries | ✓ |
| B + planning sweep | Also edit `.planning/` version strings | |
| Global rg-only | No explicit test list | |

**User's choice:** Delegated to research synthesis — **7-surface lockstep + opentelemetry + retire B2 canaries** (CONTEXT D-01).

**Notes:** Phase 48/53 canary architecture was scaffolding until capstone. Finch/Req/NimbleOptions use one README band. `opentelemetry.md` at `~> 1.1` is Phase-43-class blind spot.

---

## CHANGELOG shape and depth

| Option | Description | Selected |
|--------|-------------|----------|
| **Four `## [1.x.0]` sections + 1.7.0 Hex** | Milestone sections with “included in 1.7.0” disclaimer | ✓ |
| Single 1.7.0 with milestone `###` subheads | Honest single upgrade story | |
| Four sections + retroactive dates | Implies separate Hex releases | |
| Strict KAC — only 1.7.0 entry | Drops milestone narrative | |

**User's choice:** **Option A** with publishing banner; promote Unreleased 1.5.0 draft; WEBFIX-01 migration depth only (CONTEXT D-02).

**Notes:** Hex last published **1.1.0** (verified via `mix hex.info`). Keep 1.3.0 historical entry intact.

---

## README release-status and HexDocs index

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal version bump | “1.7.x on Hex” only | |
| **Milestone bullets (1.4–1.7)** | Compact shipped-surface map + CHANGELOG link | ✓ |
| “Since 1.3” table | High duplication | |
| CHANGELOG-only | Poor GitHub-first DX | |

**User's choice:** **Option B** + minimal HexDocs patches (Tax guide + Charge moduledoc); no Phase 55 stop signal (CONTEXT D-03).

---

## Hex publish execution

| Option | Description | Selected |
|--------|-------------|----------|
| **Manual capstone + keep release-please** | Preflight locally; tag v1.7.0; mix hex.publish | ✓ |
| GHA on tag only | New workflow | |
| release-please only | Manifest drift risk today | |
| Sequential 1.4→1.7 Hex publishes | Rejected | |

**User's choice:** **Single 1.7.0**; manual publish for capstone; sync manifest after; optional future `mix test` in publish job (CONTEXT D-04).

---

## docs-truth test migration

| Option | Description | Selected |
|--------|-------------|----------|
| Per-test bump to 1.7 | Fragmented | |
| Global sweep only | Misses content locks | |
| **Hybrid + SSOT from mix.exs** | Global install + stale refute + keep content locks | ✓ |
| Constant only, delete all per-file | Too thin | |

**User's choice:** Retire v1.5 and v1.7 canary tests; add global install + stale-pin refute; include opentelemetry in sweep (CONTEXT D-05).

---

## Claude's Discretion

- CHANGELOG compare base tag
- release-as one-shot vs purely manual publish
- Optional HexDocs CHANGELOG one-liner

## Deferred Ideas

- Phase 55 stop signal and Phase 41.1 retirement
- Intermediate Hex versions
- publish-hex test gate (follow-up)
