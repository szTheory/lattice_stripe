---
phase: 36
slug: quote
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-25
---

# Phase 36 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Mox for unit tests and `stripe-mock` for integration |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/quote_test.exs` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | ~25 seconds |

---

## Sampling Rate

- **After every task commit:** Run the task’s `<automated>` command
- **After every plan wave:** Run `mix test test/lattice_stripe/object_types_test.exs test/lattice_stripe/quote_test.exs --warnings-as-errors`
- **Before `/gsd-verify-work`:** Full suite must be green via `mix ci`
- **Max feedback latency:** 25 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 36-01-01 | 01 | 1 | QUOT-05 | T-36-01 | Quote parser contracts preserve Stripe shape, selective nested structs, and unknown fields in `extra` | unit | `mix test test/lattice_stripe/object_types_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 36-01-02 | 01 | 1 | QUOT-01, QUOT-02, QUOT-05 | T-36-02 | Quote and Quote.LineItem object dispatch works and expanded `Invoice.quote` no longer degrades to raw maps | unit | `mix test test/lattice_stripe/object_types_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 36-02-01 | 02 | 2 | QUOT-01, QUOT-02 | T-36-03 | CRUDL and lifecycle verbs preserve raw Stripe params, explicit action names, and clear irreversible docs | unit | `mix test test/lattice_stripe/quote_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 36-02-02 | 02 | 2 | QUOT-03, QUOT-04, QUOT-05 | T-36-04 / T-36-05 | Both line-item endpoint families return typed structs and `pdf/3` returns binary instead of leaking `%Response{}` | unit | `mix test test/lattice_stripe/quote_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 36-02-03 | 02 | 2 | QUOT-01, QUOT-02, QUOT-03 | T-36-06 | Integration coverage proves primary Quote routes and at least one line-item route against `stripe-mock` without depending on local workflow helpers | integration | `mix test test/lattice_stripe/quote_test.exs test/integration/quote_integration_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/support/fixtures/quote.ex` — fixture maps for quote objects, line items, computed branches, and expanded downstream references
- [ ] `test/lattice_stripe/quote_test.exs` — unit coverage for CRUDL, lifecycle verbs, line-item routes, PDF binary contract, enum atomization, and expandable-field parsing
- [ ] `test/integration/quote_integration_test.exs` — route sanity for the primary Quote surface

*Existing ExUnit, Mox, and `stripe-mock` infrastructure covers all framework requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Moduledoc and `@doc` clarity for quote lifecycle and PDF preconditions | QUOT-02, QUOT-04 | Automated tests cannot judge whether docs clearly explain finalize/accept/cancel consequences or the PDF 404 caveat | Read `LatticeStripe.Quote` docs and confirm they distinguish draft/open/accepted/canceled states, explain what `accept/3` generates, and state that PDF retrieval can 404 for non-finalized quotes |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 25s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-25
