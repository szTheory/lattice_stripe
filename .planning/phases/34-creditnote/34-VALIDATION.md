---
phase: 34
slug: creditnote
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-24
---

# Phase 34 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Mox for unit tests and `stripe-mock` for integration |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/credit_note_test.exs` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | ~20 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/credit_note_test.exs`
- **After every plan wave:** Run `mix test test/lattice_stripe/credit_note_test.exs test/integration/credit_note_integration_test.exs`
- **Before `/gsd-verify-work`:** Full suite must be green via `mix ci`
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 34-01-01 | 01 | 1 | CRDN-06 | — | Line-item parsing preserves unknown Stripe fields in `extra`, keeps subtype strings unatomized, and fixture helpers encode finalized-invoice setup constraints | unit | `mix test test/lattice_stripe/object_types_test.exs` | ✅ | ⬜ pending |
| 34-01-02 | 01 | 1 | CRDN-06 | — | `credit_note` and `credit_note_line_item` registry dispatch resolves typed structs and Billing docs grouping stays aligned with Invoice | unit | `mix test test/lattice_stripe/object_types_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 34-02-01 | 02 | 2 | CRDN-01, CRDN-02, CRDN-03, CRDN-04, CRDN-05 | T-34-05 | Public API uses locked names, raw Stripe-shaped params, explicit `void/3`, and lifecycle caveat docs | unit | `mix test test/lattice_stripe/credit_note_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 34-02-02 | 02 | 2 | CRDN-01, CRDN-02, CRDN-03, CRDN-04, CRDN-05, CRDN-06 | T-34-04 / T-34-06 | Request shapes, parser behavior, bang helpers, and both line-item subtype variants remain stable under unit coverage | unit | `mix test test/lattice_stripe/credit_note_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 34-02-03 | 02 | 2 | CRDN-01, CRDN-02, CRDN-03, CRDN-04, CRDN-05 | T-34-07 | Integration coverage encodes finalized-invoice and open-invoice caveats honestly even when `stripe-mock` is permissive | integration | `mix test test/lattice_stripe/credit_note_test.exs test/integration/credit_note_integration_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/support/fixtures/credit_note.ex` — fixture maps for credit notes, both line-item subtypes, and finalized/open invoice helpers
- [ ] `test/lattice_stripe/credit_note_test.exs` — parser, enum, API surface, bang variant, embedded `lines`, and line-item subtype coverage
- [ ] `test/integration/credit_note_integration_test.exs` — route sanity for create/retrieve/update/list/preview/void/issued-lines/preview-lines
- [ ] `guides/credit_notes.md` — bounded guide examples for the two locked create/preview shapes plus lifecycle caveats

*Existing ExUnit, Mox, and `stripe-mock` infrastructure covers all framework requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Irreversibility wording and invoice-lifecycle caveats in moduledocs/@doc text | CRDN-02, CRDN-03 | Copy quality matters and automated tests cannot judge documentation clarity | Read generated `@doc` sections for `preview/3` and `void/3`; confirm they mention finalized-invoice creation constraint, open-invoice void constraint, and irreversible semantics clearly |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
