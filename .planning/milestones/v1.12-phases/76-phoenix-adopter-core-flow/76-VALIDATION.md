---
phase: "76"
slug: "phoenix-adopter-core-flow"
status: verified
nyquist_compliant: true
wave_0_complete: true
created: "2026-09-24"
---

# Phase 76 — Validation Strategy

> Per-phase validation contract and observed behavioral evidence for the Phoenix adopter core flow.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, with Phoenix.ConnTest and Mox |
| **Config file** | `test_apps/phoenix_adopter/test/test_helper.exs` |
| **Quick run command** | `cd test_apps/phoenix_adopter && HEX_HOME=/tmp/lattice_stripe_phase76_hex mix test test/core_flow_test.exs` |
| **Full suite command** | `cd test_apps/phoenix_adopter && HEX_HOME=/tmp/lattice_stripe_phase76_hex mix test` |
| **Observed full-suite result** | 9 tests, 0 failures (2026-09-24; isolated Hex cache) |

## Sampling Rate

- After changing the adopter host flow, run the focused `core_flow_test.exs` integration suite.
- Before phase verification, run the complete nested adopter suite with the isolated Hex cache command above.
- The nested project must be in the current directory for Mix to resolve its own lockfile and path dependency.

## Per-Requirement Verification Map

| Task ID | Requirement | Observable behavior | Test Type | Automated Command | Evidence | Status |
|---------|-------------|---------------------|------------|-------------------|----------|--------|
| 76-01-01 | ADOPT-01 | The nested Phoenix host starts its Endpoint and the SDK-owned single default Finch pool, then dispatches Checkout through the Endpoint. | integration | `cd test_apps/phoenix_adopter && HEX_HOME=/tmp/lattice_stripe_phase76_hex mix test test/core_flow_test.exs` | `test/core_flow_test.exs`, `host boots with checked-out dependency`; full suite rerun: 9 tests, 0 failures. | ✅ pass |
| 76-01-02 | ADOPT-02 | Phoenix Checkout posts subscription parameters through the injected transport, receives a typed Session, verifies unchanged signed webhook bytes, dispatches a typed test-mode Event, and rejects a modified body before host handling. | integration | `cd test_apps/phoenix_adopter && HEX_HOME=/tmp/lattice_stripe_phase76_hex mix test test/core_flow_test.exs` | `test/core_flow_test.exs`, `subscription checkout and signed completion event cross the host boundary` and `modified webhook body is rejected before handler dispatch`; full suite rerun: 9 tests, 0 failures. | ✅ pass |

## Manual-Only Verifications

None. This is a headless library integration harness with deterministic synthetic transport and webhook fixtures. The adopter test suite verifies the host boundary without live Stripe credentials or a listening server. Live delivery, durable processing, and duplicate-event handling are explicitly outside this phase's claims.

## Validation Sign-Off

- [x] Each phase requirement maps to a named behavioral integration test.
- [x] The full nested adopter suite was executed and passed (9 tests, 0 failures).
- [x] No human-only verification remains under the project verification policy.
- [x] `nyquist_compliant: true` reflects the observed automated coverage.
