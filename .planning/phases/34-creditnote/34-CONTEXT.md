# Phase 34: CreditNote - Context

**Gathered:** 2026-05-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Add direct Stripe `CreditNote` coverage only: create, retrieve, update, list, preview, void, issued-note line-item access, preview line-item access, and typed deserialization for the resource plus its line items.

This phase stays firmly on the LatticeStripe side of the boundary: Stripe-shaped resource coverage and ergonomic low-level verbs. No higher-level billing orchestration, refund policy workflows, accounting abstractions, or Accrue-style business logic.

Requirements: CRDN-01, CRDN-02, CRDN-03, CRDN-04, CRDN-05, CRDN-06

</domain>

<decisions>
## Implementation Decisions

### API naming and symmetry

- **D-01:** Use `CreditNote.preview/3` as the canonical preview API, not `create_preview/3`. Stripe names the endpoint as preview, the roadmap/requirements already lock `preview/3`, and adding an Invoice-style `create_preview` alias would introduce avoidable surface inconsistency.
- **D-02:** Use `CreditNote.list_preview_line_items/3` as the canonical preview-lines API. Do not name it `preview_lines/3` or `create_preview_lines/3`; the longer name is more explicit and aligns with the existing `list_line_items/4` family.
- **D-03:** Issued-note line items follow the existing nested-list pattern already used by `Invoice` and `Checkout.Session`: `list_line_items/4`, `list_line_items!/4`, and `stream_line_items!/4`.
- **D-04:** Add `list_preview_line_items!/3` and `stream_preview_line_items!/3` as DX-oriented symmetry helpers even though only non-bang list access is required by the roadmap. The endpoint is paginated, the implementation cost is low, and this keeps preview-line handling coherent with the rest of the library.

### Mutation surface and verb semantics

- **D-05:** `create/3` and `preview/3` both accept raw params maps and pass them through to Stripe. Do not add builders, one-off helper DSLs, or client-side enum wrappers in this phase. Credit note params are complex and evolving; the library should remain Stripe-shaped and unsurprising.
- **D-06:** `update/4` remains a raw pass-through update entry point even though Stripe currently documents only `memo` and `metadata`. Document the narrow practical use, but do not artificially reject unknown keys client-side; Stripe drift should fail at Stripe, not inside LatticeStripe.
- **D-07:** `void/3` is an explicit verb with signature `void(client, id, opts \\ [])`. No params map. It sends an empty `POST /v1/credit_notes/:id/void`, matching the Stripe API and the pattern established by `Dispute.close/3`.
- **D-08:** `void/3` docs must include a dedicated `## Irreversibility` section and must clearly state the invoice-state constraint: credit notes can be created only for finalized invoices, and voiding is valid only when the credit note is attached to an open invoice.

### Typing and deserialization depth

- **D-09:** Model one top-level `%LatticeStripe.CreditNote{}` struct plus one nested `%LatticeStripe.CreditNote.LineItem{}` struct. This is the right depth for v1.3: it captures the important developer-facing objects without exploding the API surface.
- **D-10:** Leave aggregate or highly nested billing detail fields as raw maps/lists for now: `refunds`, `discount_amounts`, `pretax_credit_amounts`, `total_taxes`, `shipping_cost`, and nested tax-rate payloads do not get dedicated structs in this phase.
- **D-11:** Embedded `lines` on the credit note deserialize into `%LatticeStripe.List{data: [%CreditNote.LineItem{}, ...]}` using the same nested-list pattern used by `Invoice.lines`.
- **D-12:** Register both `"credit_note"` and `"credit_note_line_item"` in `LatticeStripe.ObjectTypes`. Top-level expandable references like `customer`, `invoice`, and `customer_balance_transaction` should use `ObjectTypes.maybe_deserialize/1` where the target type already exists.

### Enum modeling

- **D-13:** Atomize top-level `CreditNote.status` (`issued`, `void`), `CreditNote.reason` (`duplicate`, `fraudulent`, `order_change`, `product_unsatisfactory`), and `CreditNote.type` (`pre_payment`, `post_payment`, `mixed`) at parse time with string pass-through for unknown future values.
- **D-14:** Keep `CreditNote.LineItem.type` as a string, not an atom. This matches the existing `Invoice.LineItem` convention and avoids introducing a second line-item enum style in the same library. The developer still gets a typed struct and can branch on `"invoice_line_item"` vs `"custom_line_item"` explicitly.

### Testing and documentation posture

- **D-15:** Unit tests must cover both credit-note line-item subtypes: `"invoice_line_item"` and `"custom_line_item"`. This is a known footgun in Stripe’s API and should not be left to integration coverage alone.
- **D-16:** Integration fixtures for `CreditNote.create/3` must finalize the invoice first. Add a dedicated fixture/helper for “creditable invoice” setup instead of repeating finalize logic inline across tests.
- **D-17:** Void integration coverage must use a credit note attached to an open invoice, not a paid invoice. Tests should encode this operational precondition directly so the docs and code stay aligned.
- **D-18:** Module and guide examples must emphasize the two important create/preview shapes users are most likely to get wrong:
  1. crediting an existing invoice line item
  2. creating a custom credit line item

### the agent's Discretion

- Exact `@known_fields` coverage breadth and field ordering within `%CreditNote{}` and `%CreditNote.LineItem{}`
- Whether `%CreditNote{}` gets a custom `Inspect` implementation; default inspect is acceptable unless a concrete readability or secret-leak issue appears
- Internal helper extraction boundaries for line parsing and enum atomization
- Exact test helper naming in `test/support/fixtures/credit_note.ex`
- ExDoc grouping placement within Billing, as long as it remains consistent with existing invoice/subscription organization

</decisions>

<specifics>
## Specific Ideas

- Default recommendation set is intentionally auto-locked and cohesive: Stripe-shaped APIs, explicit verbs for irreversible actions, minimal but meaningful typing, and symmetry where it improves DX without inventing a new abstraction layer.
- The main tradeoff rejected here is “extra cleverness.” No builders, no changeset-style validation layer, no overloaded naming aliases, and no attempt to transform CreditNote into a workflow object. That keeps the API consistent with the project’s low-magic design and with successful official Stripe SDK patterns.
- The one deliberate ergonomics upgrade beyond the roadmap minimum is `stream_preview_line_items!/3` plus the bang variant for preview-line listing. This is a small, coherent surface addition that pays off for large credits and keeps preview pagination from feeling like a second-class API.
- Keep the moduledoc very explicit about invoice lifecycle constraints. The biggest likely user confusion is not function naming; it is trying to create a credit note on a draft invoice or trying to void one attached to a paid invoice.
- For create/preview examples, favor concrete, copy-pasteable shapes such as:

```elixir
CreditNote.preview(client, %{
  "invoice" => "in_123",
  "lines" => [
    %{
      "type" => "invoice_line_item",
      "invoice_line_item" => "il_123",
      "quantity" => 1
    }
  ]
})

CreditNote.create(client, %{
  "invoice" => "in_123",
  "lines" => [
    %{
      "type" => "custom_line_item",
      "description" => "Goodwill credit",
      "quantity" => 1,
      "unit_amount" => 500
    }
  ],
  "memo" => "Applied after support review"
})
```

- Treat “update is only memo/metadata in practice” as a documentation concern, not an API-shaping concern. This follows the project’s preference for direct Stripe coverage over local policy gates.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and scope docs
- `.planning/ROADMAP.md` — Phase 34 goal, dependency, and success criteria
- `.planning/REQUIREMENTS.md` — CRDN-01 through CRDN-06 requirements
- `.planning/STATE.md` — v1.3 sequencing and current milestone state
- `.planning/threads/lattice-stripe-vs-accrue-scope-boundary.md` — scope boundary; confirms CreditNote belongs here only as low-level resource coverage

### Existing project research
- `.planning/research/FEATURES.md` — confirmed CreditNote endpoints, field inventory, and previous research recommendations
- `.planning/research/PITFALLS.md` — phase-specific operational pitfalls: finalized-invoice precondition, open-invoice void semantics, and line-item subtype footguns
- `.planning/research/ARCHITECTURE.md` — recommended module layout and nested-struct depth for CreditNote
- `.planning/research/STACK.md` — confirms CreditNote fits the existing JSON request path with no new transport dependencies

### Local research prompts
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — explicit, stable OSS API design; runtime config; low-magic library UX
- `prompts/elixir-best-practices-deep-research.md` — stable return shapes, explicit functions, assertive modeling, and restraint around abstraction
- `prompts/stripe-sdk-api-surface-area-deep-research.md` — Stripe SDK breadth posture, preview compatibility, and escape-hatch philosophy
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — DX priorities and why billing/payment operational flows need polished ergonomics
- `prompts/payments_domain_field_guide.md` — invoice lifecycle vocabulary and billing-domain terminology
- `prompts/The definitive Stripe library gap in Elixir - a master research document.md` — overall Elixir ecosystem expectations for a first-class Stripe SDK

### Existing codebase patterns
- `lib/lattice_stripe/invoice.ex` — preview naming precedent, issued-line-item APIs, nested `lines` deserialization pattern
- `lib/lattice_stripe/invoice/line_item.ex` — nested line-item struct pattern and field-shape precedent
- `lib/lattice_stripe/checkout/session.ex` — `list_line_items/4` + `stream_line_items!/4` pattern for nested paginated sub-resources
- `lib/lattice_stripe/dispute.ex` — explicit irreversible-verb docs pattern and empty-body action endpoint pattern
- `lib/lattice_stripe/object_types.ex` — object registry for expandable deserialization
- `test/lattice_stripe/invoice_test.exs` — preview-lines and line-item testing patterns
- `test/lattice_stripe/dispute_test.exs` — action-verb request assertions and atomization tests

### External Stripe docs
- `https://docs.stripe.com/api/credit_notes` — authoritative endpoint inventory
- `https://docs.stripe.com/api/credit_notes/object` — CreditNote object fields, embedded `lines`, top-level enums
- `https://docs.stripe.com/api/credit_notes/create` — create semantics, post-payment allocation fields, and raw request shape
- `https://docs.stripe.com/api/credit_notes/update` — update scope (`memo`, `metadata`)
- `https://docs.stripe.com/api/credit_notes/preview` — preview endpoint and params
- `https://docs.stripe.com/api/credit_notes/preview_lines` — preview line-item pagination endpoint
- `https://docs.stripe.com/api/credit_notes/lines` — issued-note line-item pagination endpoint
- `https://docs.stripe.com/api/credit_notes/line_item` — line-item subtype rules and field shape
- `https://docs.stripe.com/api/credit_notes/void` — explicit void action endpoint
- `https://docs.stripe.com/invoicing/integration/programmatic-credit-notes` — operational guidance, especially finalized-invoice and open-invoice void constraints

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Invoice.list_line_items/4` and `Invoice.stream_line_items!/4` — direct template for issued credit-note line-item access
- `Invoice.create_preview_lines/3` — close structural precedent for preview-line listing, even though naming should differ
- `Checkout.Session.list_line_items/4` and `stream_line_items!/4` — clean nested paginated sub-resource API shape
- `Resource.unwrap_singular/2`, `unwrap_list/2`, and `unwrap_bang!/1` — standard singular/list/bang behavior
- `ObjectTypes.maybe_deserialize/1` — expandable field deserialization for `invoice`, `customer`, and existing related resources

### Established Patterns
- Explicit verbs for irreversible actions instead of status-mutation updates
- Raw params maps for complex Stripe payloads; avoid local DSLs unless a dedicated later phase justifies them
- Top-level enum atomization at parse time with forward-compatible string pass-through
- Nested sub-resource structs only when they are high-signal developer-facing objects
- `stream!/3` for top-level lists and `stream_line_items!/4`-style helpers for nested paginated collections

### Integration Points
- `lib/lattice_stripe/object_types.ex` — add `credit_note` and `credit_note_line_item`
- `lib/lattice_stripe/credit_note.ex` — new top-level resource module
- `lib/lattice_stripe/credit_note/line_item.ex` — new nested line-item module
- `test/support/fixtures/credit_note.ex` — new fixture module for unit and integration coverage
- ExDoc Billing grouping and fixture-builder promotion later in Phase 37

</code_context>

<deferred>
## Deferred Ideas

- Changeset-style or builder-style helpers for credit-note create/preview payloads — potentially useful later, but out of scope for this phase and too policy-heavy for the current project boundary
- Dedicated typed structs for refunds, shipping cost, tax aggregates, or pretax credit aggregates — defer unless a later phase proves real demand
- Compatibility alias names such as `preview_lines/3` or `create_preview/3` — rejected for now to keep the public surface smaller and more coherent
- Higher-level “issue credit from invoice line item” convenience workflows — this belongs closer to Accrue if it starts becoming orchestration rather than API coverage

</deferred>

---

*Phase: 34-creditnote*
*Context gathered: 2026-05-24*
