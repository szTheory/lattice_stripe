---
phase: 17
slug: connect-accounts-links
status: planned
nyquist_compliant: true
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
| 17-01-T1 | 17-01 | 0 | CNCT-01 | T-17-INF-01 | synthetic PII only | fixtures | `mix compile --force --warnings-as-errors` | ✅ W0 | ✅ green |
| 17-01-T2 | 17-01 | 0 | CNCT-01 | T-17-03 | per-request stripe_account header wins | unit | `mix test test/lattice_stripe/client_stripe_account_header_test.exs` | ✅ W0 | ✅ green |
| 17-01-T3 | 17-01 | 0 | CNCT-01 | — | stripe-mock reject probe | script | `mix run scripts/verify_stripe_mock_reject.exs` | ✅ W0 | ✅ green |
| 17-02-T1 | 17-02 | 1 | CNCT-01 | T-17-FWDCOMPAT-01 | F-001 extra capture | unit | `mix test test/lattice_stripe/account/business_profile_test.exs test/lattice_stripe/account/requirements_test.exs test/lattice_stripe/account/settings_test.exs` | ❌ W0 | ⬜ pending |
| 17-02-T2 | 17-02 | 1 | CNCT-01 | T-17-01 | PII-safe Inspect redaction | unit | `mix test test/lattice_stripe/account/tos_acceptance_test.exs test/lattice_stripe/account/company_test.exs test/lattice_stripe/account/individual_test.exs` | ❌ W0 | ⬜ pending |
| 17-02-T3 | 17-02 | 1 | CNCT-01 | T-17-ATOM-01 | status_atom returns :unknown never String.to_atom | unit | `mix test test/lattice_stripe/account/capability_test.exs` | ❌ W0 | ⬜ pending |
| 17-03-T1 | 17-03 | 2 | CNCT-01 | T-17-04 | reject/4 atom guard closed enum | compile | `mix compile --force --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 17-03-T2 | 17-03 | 2 | CNCT-01 | T-17-04 T-17-CAPCFG-01 | reject guard + D-04b regression + Inspect smoke | unit | `mix test test/lattice_stripe/account_test.exs` | ❌ W0 | ⬜ pending |
| 17-04-T1 | 17-04 | 2 | CNCT-01 | T-17-02 T-17-VALIDATION-01 | AccountLink create-only + D-04c | unit | `mix test test/lattice_stripe/account_link_test.exs` | ❌ W0 | ⬜ pending |
| 17-04-T2 | 17-04 | 2 | CNCT-01 | T-17-02 T-17-INJECT-01 | LoginLink is_binary guard + deviation docs | unit | `mix test test/lattice_stripe/login_link_test.exs` | ❌ W0 | ⬜ pending |
| 17-05-T1 | 17-05 | 3 | CNCT-01 | T-17-04 | Account full-lifecycle stripe-mock | integration | `mix test test/integration/account_integration_test.exs --only integration` | ❌ W0 | ⬜ pending |
| 17-05-T2 | 17-05 | 3 | CNCT-01 | T-17-02 | AccountLink + LoginLink stripe-mock | integration | `mix test test/integration/account_link_integration_test.exs test/integration/login_link_integration_test.exs --only integration` | ❌ W0 | ⬜ pending |
| 17-06-T1 | 17-06 | 3 | CNCT-01 | T-17-02 T-17-DOCS-01 | Guide bearer-token warnings + webhook callout | docs | `test -f guides/connect.md && wc -l guides/connect.md` | ❌ W0 | ⬜ pending |
| 17-06-T2 | 17-06 | 3 | CNCT-01 | — | ExDoc Connect group wired | docs | `mix docs --warnings-as-errors` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/support/fixtures/account.ex` — canonical Account fixture with nested business_profile/capabilities/requirements/settings/tos_acceptance (note: .ex not .json — Elixir module fixtures per project convention)
- [x] `test/support/fixtures/account_link.ex` — AccountLink fixture (url, expires_at, created, object)
- [x] `test/support/fixtures/login_link.ex` — LoginLink fixture (url, created, object)
- [x] `test/lattice_stripe/client_stripe_account_header_test.exs` — T-17-03 regression guard (4 tests green)
- [x] `scripts/verify_stripe_mock_reject.exs` — stripe-mock reject probe script
- [ ] `test/lattice_stripe/account_test.exs` — unit test stubs (Mox-based) for CNCT-01 CRUD + reject + list
- [ ] `test/lattice_stripe/account_link_test.exs` — unit test stubs for create
- [ ] `test/lattice_stripe/login_link_test.exs` — unit test stubs for create
- [ ] `test/integration/account_integration_test.exs` — stripe-mock-backed lifecycle + reject
- [ ] `test/integration/account_link_integration_test.exs` — stripe-mock-backed create
- [ ] `test/integration/login_link_integration_test.exs` — stripe-mock-backed create

### reject endpoint: stripe-mock VERIFIED via scripts/verify_stripe_mock_reject.exs on 2026-04-12

`POST /v1/accounts/:id/reject` returns HTTP 200 from stripe-mock. Plan 17-05 integration test for reject SHOULD be written (not skipped).

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
