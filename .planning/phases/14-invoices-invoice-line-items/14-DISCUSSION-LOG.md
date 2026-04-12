# Phase 14: Invoices & Invoice Line Items - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 14-invoices-invoice-line-items
**Areas discussed:** Action verb surface, upcoming/2 shape, Auto-advance telemetry, Invoice Line Items, Invoice struct field typing, Invoice status atomization, Proration guard, Forbidden operations / lifecycle docs, Invoice search endpoint, InvoiceItem CRUD surface, Telemetry events for action verbs, guides/invoices.md scope

---

## Round 1 — Core Design Areas

### Action Verb Surface

| Option | Description | Selected |
|--------|-------------|----------|
| Mixed — bare + send_invoice | finalize/4, void/4, pay/4, send_invoice/4, mark_uncollectible/4. Bare verbs where safe, suffixed only for send (Kernel.send collision). Uniform arity. | ✓ |
| All suffixed | finalize_invoice/4, void_invoice/4, pay_invoice/4, send_invoice/4, mark_uncollectible/4. Matches official SDKs 1:1. | |
| All bare verbs | finalize/4, void/4, pay/4, send/4, mark_uncollectible/4. send/4 requires import Kernel, except: [send: 2]. | |

**User's choice:** Mixed — bare + send_invoice
**Notes:** Uniform arity (client, id, params \\ %{}, opts \\ []) for all verbs. Both tuple and bang variants.

---

### upcoming/2 Shape

| Option | Description | Selected |
|--------|-------------|----------|
| upcoming/3 returning %Invoice{id: nil} | Same struct, nil id. Legacy GET endpoint only. | |
| Both upcoming/3 AND create_preview/3 | Ship both legacy GET and new POST endpoints. Future-proofs for Stripe API migration. | ✓ |
| create_preview/3 only | New POST endpoint only. Breaks compat with older Stripe API versions. | |

**User's choice:** Both upcoming/3 AND create_preview/3
**Notes:** Researcher flagged Stripe deprecating upcoming in favor of create_preview as of API version 2025-03-31.basil.

---

### Auto-Advance Telemetry

| Option | Description | Selected |
|--------|-------------|----------|
| Pre-request telemetry + default logger | Fire event before HTTP call when auto_advance absent. Extend attach_default_logger/1. Layered docs. No opt-out. | ✓ |
| Post-request telemetry only | Fire after successful create. Telemetry-only, no Logger. | |
| Logger.warning always | Always emit Logger.warning. Simplest but opinionated. | |

**User's choice:** Pre-request telemetry + default logger
**Notes:** Event name: [:lattice_stripe, :invoice, :auto_advance_defaulted].

---

### Invoice Line Items

| Option | Description | Selected |
|--------|-------------|----------|
| Invoice.LineItem nested + parent-owned API | Nested module, Invoice.list_line_items/4 + stream. Matches Checkout.LineItem. | ✓ |
| Flat LatticeStripe.InvoiceLineItem | Flat namespace matching official SDKs. | |

**User's choice:** Invoice.LineItem nested + parent-owned API

| Option | Description | Selected |
|--------|-------------|----------|
| Include InvoiceItem in Phase 14 | Essential for canonical workflow. LatticeStripe.InvoiceItem flat CRUD. | ✓ |
| Defer to a later phase | Keep Phase 14 focused on Invoice + LineItem only. | |

**User's choice:** Include in Phase 14

---

## Round 2 — Additional Design Areas

### Invoice Struct Field Typing

| Option | Description | Selected |
|--------|-------------|----------|
| status_transitions + automatic_tax only | Two with clear pattern-match value. Everything else map(). | ✓ |
| + shipping_cost | Add shipping_cost for shipping invoices. | |
| status_transitions only | Minimal. | |

**User's choice:** status_transitions + automatic_tax only

---

### Invoice Status Atomization

| Option | Description | Selected |
|--------|-------------|----------|
| Atomize all 4 top-level enums, no predicates | status, collection_method, billing_reason, customer_tax_exempt. No paid?/1 etc. | ✓ |
| All 4 + status predicates | Plus Invoice.draft?/1, paid?/1, etc. | |
| status + collection_method only | Two most common. Breaks D-03 rule. | |

**User's choice:** Atomize all 4 top-level enums, no predicates

---

### Proration Guard

| Option | Description | Selected |
|--------|-------------|----------|
| Client field + shared guard module in Phase 14 | require_explicit_proration on Client + Billing.Guards module. Guards upcoming/3 and create_preview/3. | ✓ |
| Client field, inline guards | Same field but inline logic. Phase 15 must extract. | |
| Defer to Phase 15 | Phase 14 doesn't touch proration. SC-5 untestable. | |

**User's choice:** Client field + shared guard module in Phase 14

---

### Forbidden Operations / Lifecycle Docs

| Option | Description | Selected |
|--------|-------------|----------|
| State table in @moduledoc + per-function @doc | ASCII lifecycle table + per-function state notes. delete/3 exists. No client-side validation. | ✓ |
| Separate guides/invoices.md + minimal @moduledoc | Full guide, brief moduledoc. | |
| Per-function @doc only | No lifecycle overview. | |

**User's choice:** State table in @moduledoc + per-function @doc

---

## Round 3 — Final Areas

### Invoice Search Endpoint

| Option | Description | Selected |
|--------|-------------|----------|
| Standard pattern + upcoming note | D-04/D-10 pattern + note that upcoming invoices aren't searchable. | ✓ |
| Standard pattern only | No upcoming note. | |

**User's choice:** Standard pattern + upcoming note

---

### InvoiceItem CRUD Surface

| Option | Description | Selected |
|--------|-------------|----------|
| Accept as researched | Full CRUD + stream, no search, period typed, disambiguation, draft-only notes. | ✓ |
| Skip period typing | Keep period as map() too. | |

**User's choice:** Accept as researched

---

### Telemetry Events for Action Verbs

| Option | Description | Selected |
|--------|-------------|----------|
| Metadata-only, no per-verb events | Existing request events with :operation metadata sufficient. | ✓ |
| Add per-verb events | Dedicated [:lattice_stripe, :invoice, :finalize, :start|:stop] etc. | |

**User's choice:** Metadata-only, no per-verb events

---

### guides/invoices.md Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Focused 8-section guide | ~250-320 lines. Proration deferred. | |
| Comprehensive guide including proration | ~400 lines with proration preview and subscription invoice patterns. | ✓ |
| Minimal quick-reference | ~150 lines. Just workflow + auto-advance. | |

**User's choice:** Comprehensive guide including proration

---

## Claude's Discretion

- Exact module paths for nested structs
- Internal structure of Billing.Guards module
- Lifecycle state table format (ASCII art vs markdown table)
- InvoiceItem @known_fields exact list
- Guide section ordering and code example depth

## Deferred Ideas

- Shared LatticeStripe.Address struct (cross-cutting phase)
- Invoice.TransferData typing (Phase 17 Connect)
- Invoice.ShippingCost typing (if shipping invoices become focus)
- TaxRate resource (future phase)
- Status predicate helpers (if users request)
- Per-verb telemetry events (if users need)
- Client-side lifecycle state validation (rejected)
- Proration convenience wrapper (rejected)
- Auto-advance suppression config (if users request)
