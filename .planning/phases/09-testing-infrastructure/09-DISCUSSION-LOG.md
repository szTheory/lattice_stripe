# Phase 9: Testing Infrastructure - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-03
**Phase:** 09-testing-infrastructure
**Areas discussed:** stripe-mock integration, test helper scope, coverage gaps, CI quality gates
**Mode:** auto (all decisions auto-selected)

---

## stripe-mock Integration Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Tagged integration tests | @tag :integration, skipped by default, Docker-based stripe-mock | ✓ |
| Always-on integration | Run stripe-mock tests in every mix test invocation | |
| Separate test suite | Entirely separate mix task for integration tests | |

**User's choice:** [auto] Tagged integration tests (recommended default)
**Notes:** Standard Elixir pattern. Non-disruptive to existing fast test suite. stripe-mock via Docker on ports 12111-12112.

---

## Test Helper Module Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Webhook event helpers | generate_webhook_event/2 + generate_webhook_payload/2 for downstream users | ✓ |
| Full test toolkit | Mock transport + test client + fixtures + webhook helpers | |
| Minimal helpers | Just re-export generate_test_signature from Webhook | |

**User's choice:** [auto] Webhook event helpers (recommended default)
**Notes:** Downstream users' primary pain point is testing webhook handlers. Internal test infrastructure stays internal.

---

## Coverage Gap Analysis

| Option | Description | Selected |
|--------|-------------|----------|
| Audit and fill gaps | Review 535 tests against success criteria, add what's missing | ✓ |
| Rewrite from scratch | Start fresh with new test organization | |
| Integration-only focus | Only add stripe-mock tests, skip unit test audit | |

**User's choice:** [auto] Audit and fill gaps (recommended default)
**Notes:** Existing tests are strong. Main gaps: integration tests (TEST-01) and public Testing module (TEST-04).

---

## CI Quality Gates

| Option | Description | Selected |
|--------|-------------|----------|
| mix ci alias | Local alias running format+compile+credo+test+docs, Phase 11 wires to GHA | ✓ |
| mix task | Custom Mix task with progress reporting | |
| Script-based | Shell script checked into repo | |

**User's choice:** [auto] mix ci alias (recommended default)
**Notes:** Clean separation — Phase 9 makes checks work locally, Phase 11 runs them in CI.

---

## Claude's Discretion

- Integration test granularity per resource
- Test file organization (tags vs directories)
- Fixture reuse strategy for integration tests

## Deferred Ideas

None
