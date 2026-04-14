---
phase: 21
slug: customer-portal
status: planned
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-14
updated: 2026-04-14
---

# Phase 21 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/billing_portal/` |
| **Full suite command** | `mix test` |
| **Integration run** | `mix test --include integration` |
| **Estimated runtime** | ~30 seconds (full unit); ~5 seconds (portal subset); ~10 seconds (integration) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/billing_portal/`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite green + `mix test --include integration` green + `mix docs --warnings-as-errors` clean + `mix credo --strict` clean
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 21-01-T1 | 21-01 | 0 | TEST-04 | T-21-02 | Probe documents sub-field gap; fails closed on bad cases | probe | `elixir scripts/verify_portal_endpoint.exs` | ⬜ | ⬜ pending |
| 21-01-T2 | 21-01 | 0 | TEST-02 | T-21-01 | Fixture URLs are fake placeholders, not bearer creds | compile | `mix compile --warnings-as-errors` | ⬜ | ⬜ pending |
| 21-01-T3 | 21-01 | 0 | TEST-02 | T-21-01 | Test skeletons compile green before implementation | unit | `mix test test/lattice_stripe/billing_portal/ test/integration/billing_portal_session_integration_test.exs --include billing_portal --exclude integration` | ⬜ | ⬜ pending |
| 21-02-T1 | 21-02 | 1 | PORTAL-03 | T-21-03 | Unknown keys land in `:extra` without crashing decode | unit (tdd) | `mix test test/lattice_stripe/billing_portal/session/flow_data_test.exs` | ⬜ | ⬜ pending |
| 21-02-T2 | 21-02 | 1 | PORTAL-03 | T-21-03, T-21-04 | Forward-compat: `subscription_pause` lands in `:extra` | unit (tdd) | `mix test test/lattice_stripe/billing_portal/session/flow_data_test.exs` | ⬜ | ⬜ pending |
| 21-03-T1 | 21-03 | 2 | PORTAL-04 | T-21-06 | All 12 guard cases raise pre-network with actionable message; unknown-type binary catchall structurally blocks silent forwarding | unit (tdd) | `mix test test/lattice_stripe/billing_portal/guards_test.exs` | ⬜ | ⬜ pending |
| 21-03-T2 | 21-03 | 2 | PORTAL-01, PORTAL-02, PORTAL-05, PORTAL-06 + D-03 | T-21-05, T-21-07, T-21-10 | `defimpl Inspect` masks `:url` and `:flow`; `stripe_account:` opt threads; `refute inspect(session) =~ session.url` | unit (tdd, Mox) | `mix test test/lattice_stripe/billing_portal/session_test.exs test/lattice_stripe/billing_portal/guards_test.exs` | ⬜ | ⬜ pending |
| 21-04-T1 | 21-04 | 3 | PORTAL-01, TEST-05 | — | Integration proof that stripe-mock round-trip yields `%Session{url: non_empty_binary}` matching `^https://` | integration | `mix test test/integration/billing_portal_session_integration_test.exs --include integration` | ⬜ | ⬜ pending |
| 21-04-T2 | 21-04 | 3 | DOCS-02 | T-21-11, T-21-12, T-21-13 | Guide §Security teaches Inspect masking + HTTPS + webhooks-not-redirect | docs | `mix docs --warnings-as-errors` + 7-H2/line-count awk guard | ⬜ | ⬜ pending |
| 21-04-T3 | 21-04 | 3 | DOCS-03 | — | ExDoc Customer Portal group registers 6 modules, guide in extras | docs | `mix docs --warnings-as-errors` | ⬜ | ⬜ pending |

*Populated by planner. Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*
*Wave 0 checkboxes flip to ✅ when plan 21-01 completes.*

---

## Wave 0 Requirements

- [ ] `scripts/verify_portal_endpoint.exs` — stripe-mock probe covering TEST-04 sub-field gap
- [ ] `test/support/fixtures/billing_portal.ex` — `LatticeStripe.Test.Fixtures.BillingPortal.Session` with 5 builders (TEST-02)
- [ ] `test/lattice_stripe/billing_portal/session_test.exs` — unit stubs for PORTAL-01/02/05/06 + Inspect
- [ ] `test/lattice_stripe/billing_portal/guards_test.exs` — unit stubs for PORTAL-04 10-case matrix
- [ ] `test/lattice_stripe/billing_portal/session/flow_data_test.exs` — unit stubs for PORTAL-03 decode cases
- [ ] `test/integration/billing_portal_session_integration_test.exs` — stripe-mock integration stub (TEST-05 portal)

*Plan 21-01 lands all six. `wave_0_complete: true` flips after 21-01 SUMMARY.*

---

## Manual-Only Verifications

None. All phase behaviors have automated verification via ExUnit + stripe-mock + `mix docs`. The guide's prose quality (D-04 editorial envelope) is verified structurally via line-count and H2-count guards; subjective editorial review is captured in the final checker pass per GSD workflow, not as a manual-only item here.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (every row above has a command)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (session_test, guards_test, flow_data_test, integration_test all land in 21-01)
- [x] No watch-mode flags
- [x] Feedback latency < 30s (portal subset runs in ~5s per Phase 20 baseline)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** planner-approved · pending executor sign-off at Wave 0 completion
