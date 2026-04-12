---
phase: 17
slug: connect-accounts-links
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-12
---

# Phase 17 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) + Mox 1.2 + stripe-mock (Docker) |
| **Config file** | `test/test_helper.exs`, `mix.exs` test aliases |
| **Quick run command** | `mix test test/lattice_stripe/account_test.exs test/lattice_stripe/account_link_test.exs test/lattice_stripe/login_link_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds (unit) / ~30 seconds (with integration via stripe-mock) |

---

## Sampling Rate

- **After every task commit:** Run the quick command for touched test files
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green + `mix credo --strict`
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

*Populated by planner during Step 8. Each task in the generated PLAN.md files maps to a
row here with its automated command and requirement reference.*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD     | TBD  | TBD  | CNCT-01     | —          | N/A             | unit      | `mix test`        | ❌ W0       | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/support/fixtures/account.json` — canonical Account fixture with nested business_profile/capabilities/requirements/settings/tos_acceptance
- [ ] `test/support/fixtures/account_link.json` — AccountLink fixture (url, expires_at, created, object)
- [ ] `test/support/fixtures/login_link.json` — LoginLink fixture (url, created, object)
- [ ] `test/lattice_stripe/account_test.exs` — unit test stubs (Mox-based) for CNCT-01 CRUD + reject + list
- [ ] `test/lattice_stripe/account_link_test.exs` — unit test stubs for create
- [ ] `test/lattice_stripe/login_link_test.exs` — unit test stubs for create
- [ ] `test/integration/account_integration_test.exs` — stripe-mock-backed lifecycle + reject
- [ ] `test/integration/account_link_integration_test.exs` — stripe-mock-backed create
- [ ] `test/integration/login_link_integration_test.exs` — stripe-mock-backed create

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| PII-safe Inspect output hides email/SSN fields | CNCT-01 | Requires visual inspection of `inspect/1` output | `iex -S mix` → build `%Account{email: "a@b.c", individual: %Individual{...}}` → `IO.inspect/1` → confirm redacted |
| `Stripe-Account` header actually reaches Stripe on per-request override | Success Criteria #3 | stripe-mock accepts any header; live verification requires real API keys | Run against real Stripe test keys with a test connected account; confirm via dashboard that the call landed on the connected account |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
