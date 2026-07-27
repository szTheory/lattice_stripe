---
phase: 61
slug: default-finch-pool-optional-application
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-27
---

# Phase 61 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) + Mox for Transport behaviour |
| **Config file** | none — existing `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/application_test.exs test/lattice_stripe/client_test.exs test/lattice_stripe/config_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15–40 seconds |

---

## Sampling Rate

- **After every task commit:** Run the quick command
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full `mix ci` must be green (format, compile --warnings-as-errors, credo --strict, test, docs --warnings-as-errors)
- **Max feedback latency:** ~40 seconds

---

## Per-Task Verification Map

Seeded — task IDs are filled by the planner/executor. Each DX-01 behavior maps to an automated ExUnit assertion.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 61-01-xx | 01 | 1 | DX-01 | — | `Client.new!/1` without `:finch` resolves to `LatticeStripe.Finch` (no ValidationError / enforce_keys error) | unit | `mix test test/lattice_stripe/client_test.exs` | ❌ W0 | ⬜ pending |
| 61-01-xx | 01 | 1 | DX-01 | — | Default Finch pool starts under `LatticeStripe.Application` supervision tree | unit | `mix test test/lattice_stripe/application_test.exs` | ❌ W0 | ⬜ pending |
| 61-01-xx | 01 | 1 | DX-01 | — | Explicit `finch:` still overrides the default; opt-out config prevents default pool start | unit | `mix test test/lattice_stripe/application_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/lattice_stripe/application_test.exs` — default pool starts; opt-out (`start_default_finch: false`) suppresses it; supervisor named
- [ ] `test/lattice_stripe/client_test.exs` — `new!/1` and `new/1` succeed without `:finch` (resolve to default); explicit `:finch` overrides; keyword-list contract preserved
- [ ] `test/lattice_stripe/config_test.exs` — NimbleOptions schema: `finch` no longer `required`, `default:` present; `api_key` still required

*Existing ExUnit + Mox infrastructure covers the transport layer; no new framework needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| A real live Stripe call through the default pool | DX-01 | Requires network + real key; live lane is opt-in | In `iex -S mix`: `LatticeStripe.Client.new!(api_key: System.get_env("STRIPE_TEST_KEY")) |> LatticeStripe.Customer.list()` returns `{:ok, _}` with no pool wiring |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 40s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
