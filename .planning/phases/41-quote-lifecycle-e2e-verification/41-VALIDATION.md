---
phase: 41
slug: quote-lifecycle-e2e-verification
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-25
---

# Phase 41 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Mox unit tests and `stripe-mock` integration tests |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/quote_test.exs --warnings-as-errors` |
| **Supporting regression** | `mix test test/lattice_stripe/object_types_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | ~30 seconds targeted; longer if `mix ci` is used |

---

## Sampling Rate

- **After every task commit:** Run the task's `<automated>` command
- **After every plan wave:** Run the wave-level command listed below
- **Before `/gsd-verify-work`:** Run `mix test test/lattice_stripe/object_types_test.exs test/lattice_stripe/quote_test.exs test/integration/quote_integration_test.exs --include integration`
- **Max feedback latency:** ~30 seconds for the targeted quote path

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 41-01-01 | 01 | 1 | QUOT-01, QUOT-03 | T-41-01 | Quote creation and route-sanity integration setup stay aligned with current Stripe-shaped request validation | integration | `mix test test/integration/quote_integration_test.exs --include integration` | ✅ but red | ⬜ pending |
| 41-01-02 | 01 | 1 | QUOT-04 | T-41-02 | `Quote.pdf/3` returns raw binary over HTTP without leaking a `%Response{}` wrapper | integration | `mix test test/integration/quote_integration_test.exs --include integration` | ❌ W0 | ⬜ pending |
| 41-01-03 | 01 | 1 | QUOT-02 | T-41-03 | `finalize/4`, `accept/3`, and `cancel/3` prove route/decode sanity while keeping `stripe-mock` lifecycle claims bounded | integration + unit | `mix test test/lattice_stripe/quote_test.exs test/integration/quote_integration_test.exs --include integration` | ✅ unit / ❌ full integration | ⬜ pending |
| 41-01-04 | 01 | 1 | QUOT-02 | T-41-04 | One bounded downstream follow-through is attempted once and either proves typed top-level retrieval or records a reproduced `stripe-mock` limitation honestly | integration + docs | `mix test test/integration/quote_integration_test.exs --include integration` | ❌ W0 | ⬜ pending |
| 41-02-01 | 02 | 2 | QUOT-01, QUOT-02, QUOT-03, QUOT-04, QUOT-05 | T-41-05 | `36-VERIFICATION.md` exists, is closed, and cites fresh Quote-scoped commands plus mock-scope notes | docs + evidence audit | `rg -n "status: closed|QUOT-0[1-5]|quote_test|quote_integration_test|stripe-mock|pdf" .planning/phases/36-quote/36-VERIFICATION.md` | ❌ W0 | ⬜ pending |
| 41-02-02 | 02 | 2 | QUOT-01, QUOT-02, QUOT-03, QUOT-04, QUOT-05 | T-41-06 | QUOT traceability rows reflect the closed verifier state and no longer remain pending | docs + traceability audit | `rg -n "QUOT-0[1-5]" .planning/REQUIREMENTS.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave-Level Verification

- **After Plan 01:** `mix test test/lattice_stripe/object_types_test.exs test/lattice_stripe/quote_test.exs test/integration/quote_integration_test.exs --include integration`
- **After Plan 02:** `rg -n "status: closed|QUOT-0[1-5]|quote_test|quote_integration_test|stripe-mock|pdf" .planning/phases/36-quote/36-VERIFICATION.md .planning/REQUIREMENTS.md`

---

## Wave 0 Requirements

- [ ] `test/support/fixtures/quote.ex` — integration quote builder updated to use a Product-backed `price_data.product` payload for current `stripe-mock`
- [ ] `test/integration/quote_integration_test.exs` — PDF, accept, cancel, and one bounded downstream follow-through attempt added
- [ ] `.planning/phases/36-quote/36-VERIFICATION.md` — closed verifier artifact created

*Existing ExUnit and integration infrastructure covers the rest.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `stripe-mock` is running and reachable on `localhost:12111` during Quote integration proof | QUOT-01, QUOT-02, QUOT-03, QUOT-04 | External Docker service cannot be guaranteed by static file review | Start `stripe/stripe-mock`, run `mix test test/integration/quote_integration_test.exs --include integration`, and confirm the suite reaches the Quote lifecycle probes without local transport hacks |
| The verifier stays honest about what `stripe-mock` does and does not prove | QUOT-02, QUOT-04 | A human must judge whether the wording overclaims real Stripe lifecycle semantics | Read `.planning/phases/36-quote/36-VERIFICATION.md` and confirm it frames integration evidence as routing/encoding/decode sanity plus any reproduced mock limitations |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references
- [x] No watch-mode flags
- [x] Feedback latency acceptable for targeted Quote work
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-25
