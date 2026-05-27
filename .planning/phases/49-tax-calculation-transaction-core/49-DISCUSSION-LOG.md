# Phase 49: Tax Calculation & Transaction Core - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 49 — Tax Calculation & Transaction Core
**Areas discussed:** Nested struct typing, Integration spec breadth, Moduledoc scope boundary, ObjectTypes registration timing

---

## Nested Struct Typing Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Full nested structs | Every Stripe sub-object gets a module (codegen depth) | |
| Pragmatic partial typing | Typed top-level + line items + first-order nests; maps for volatile/expand-only | ✓ |
| Minimal typing | Top-level fields only; nested objects stay as maps | |

**User's choice:** Pragmatic partial typing (research-synthesized recommendation; user requested one-shot coherent decisions)
**Notes:** Subagent research compared Quote/CreditNote/Dispute/Meter patterns vs stripe-ruby/node/go codegen depth. ROADMAP SC#1 requires typed line items when expanded — minimal typing fails verification. Full nesting violates bounded-typing philosophy and Quote `pricing` footgun lessons. Shared `Tax.TaxBreakdown` if shapes match; separate Calculation/Transaction LineItem modules per ARCHITECTURE.md.

---

## Integration Spec Breadth

| Option | Description | Selected |
|--------|-------------|----------|
| Chain only | create calc → create_from_calculation → retrieve txn | |
| Chain + reversal | Above + create_reversal/3 in same Mox chain | ✓ |
| Full verb coverage | Chain + reversal + both list_line_items + error paths in integration file | |

**User's choice:** Chain + reversal
**Notes:** Phase 48 D-02 Mox-at-Transport precedent; stripe-mock stateless (cannot chain calc IDs). list_line_items and error paths (expired calc, duplicate reference) deferred to unit tests per credit_note_test.exs split. Dynamic references via `System.unique_integer/1`.

---

## Moduledoc Scope Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Brief cross-reference | One paragraph + AutomaticTax link | ✓ (refined) |
| Dedicated Scope section | Full in/out bullet list in moduledocs | |
| Minimal | Expiry + reference only; scope in Phase 51 guide | |

**User's choice:** Structured relationship paragraph (Option A refined)
**Notes:** Not full REQUIREMENTS.md bullet list — creates drift with Phase 51 guide. AutomaticTax fence + operational traps (90-day, reference uniqueness) required at ExDoc discovery (ROADMAP SC#6, Pitfall #4). Full Accrue fence deferred to `guides/tax.md`. Matches Quote/Meter voice.

---

## ObjectTypes Registration Timing

| Option | Description | Selected |
|--------|-------------|----------|
| Register both in Phase 49 | tax.calculation + tax.transaction at module ship | ✓ |
| Defer all to Phase 51 | DX-01 batch registration | |
| Register Calculation only | Partial family registration | |

**User's choice:** Register both in Phase 49
**Notes:** ROADMAP already incremental (Phase 50 registers settings/registration). Partial defer creates expand-path raw maps inside typed parents. ~4 lines; Pitfall #6 co-registration. Phase 51 DX-01 remains five-type expand proof, not first registration point for calc/txn.

---

## Claude's Discretion

- Exact `@known_fields` after Stripe doc verification in plan-phase
- Shared vs duplicated TaxBreakdown module
- Unit test file split vs merge
- Optional stripe-mock smoke test

## Deferred Ideas

- Full Accrue moduledoc bullet list → Phase 51 guide
- Testing fixtures, docs-truth, expand proof → Phase 51
- Tax param builders → out of scope
- Tax Code lookup → v1.7+
