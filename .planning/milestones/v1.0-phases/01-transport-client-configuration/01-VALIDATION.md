---
phase: 1
slug: transport-client-configuration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-31
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib, ships with Elixir) |
| **Config file** | `test/test_helper.exs` (Plan 01 creation) |
| **Quick run command** | `mix test --max-failures 1` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test --max-failures 1`
- **After every plan wave:** Run `mix test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Test File | Status |
|---------|------|------|-------------|-----------|-------------------|-----------|--------|
| 01-01-01 | 01 | 1 | -- | setup | `mix compile --warnings-as-errors` | -- (no test file) | pending |
| 01-01-02 | 01 | 1 | -- | setup | `mix test && mix format --check-formatted` | test/test_helper.exs | pending |
| 01-02-01 | 02 | 2 | JSON-01, JSON-02 | unit | `mix test test/lattice_stripe/json_test.exs` | test/lattice_stripe/json_test.exs | pending |
| 01-02-02 | 02 | 2 | TRNS-04 | unit | `mix test test/lattice_stripe/form_encoder_test.exs` | test/lattice_stripe/form_encoder_test.exs | pending |
| 01-03-01 | 03 | 2 | TRNS-01, TRNS-03 | unit | `mix test test/lattice_stripe/transport_test.exs test/lattice_stripe/request_test.exs` | test/lattice_stripe/transport_test.exs, test/lattice_stripe/request_test.exs | pending |
| 01-03-02 | 03 | 2 | TRNS-03 | unit | `mix test test/lattice_stripe/error_test.exs` | test/lattice_stripe/error_test.exs | pending |
| 01-04-01 | 04 | 3 | CONF-01, CONF-02 | unit | `mix test test/lattice_stripe/config_test.exs` | test/lattice_stripe/config_test.exs | pending |
| 01-04-02 | 04 | 3 | TRNS-02, TRNS-05 | unit | `mix test test/lattice_stripe/transport/finch_test.exs` | test/lattice_stripe/transport/finch_test.exs | pending |
| 01-05-01 | 05 | 4 | CONF-03, CONF-04, CONF-05, TRNS-05 | compile | `mix compile --warnings-as-errors` | -- (compile check) | pending |
| 01-05-02 | 05 | 4 | CONF-03, CONF-04, CONF-05, TRNS-05 | unit (Mox) | `mix test test/lattice_stripe/client_test.exs` | test/lattice_stripe/client_test.exs | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `mix new lattice_stripe --module LatticeStripe` -- project scaffolding
- [ ] `mix.exs` -- add all Phase 1 dependencies (Finch, Jason, :telemetry, NimbleOptions, Mox, ExDoc, Credo)
- [ ] `test/test_helper.exs` -- Mox.defmock setup for MockTransport and MockJson
- [ ] `.formatter.exs` -- configure formatter
- [ ] `.credo.exs` -- configure Credo

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Finch pool user-managed | CONF-04 | Requires supervision tree | Verify no `start_link` or `Application.start` calls in library code |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
