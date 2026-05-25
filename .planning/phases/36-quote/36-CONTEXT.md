# Phase 36: Quote - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Add low-level, Stripe-shaped Quote coverage for the proposal-to-invoice workflow:

- `LatticeStripe.Quote` CRUDL
- explicit lifecycle verbs for finalize, accept, and cancel
- line-item access for the Quote line-item surface
- PDF download as raw binary

This phase stays at direct Stripe resource coverage. It does not add billing-engine orchestration, quote approval workflows, readiness heuristics, or predictive helpers that belong closer to Accrue.

Requirements anchor: QUOT-01, QUOT-02, QUOT-03, QUOT-04, QUOT-05.

</domain>

<decisions>
## Implementation Decisions

### Typing depth and nested-structure boundary

- **D-01:** Use **selective typing**, not generator-style deep modeling. Quote should feel richer than a raw map wrapper, but it should not import the maintenance cost of a fully generated SDK surface.
- **D-02:** Add a dedicated `%LatticeStripe.Quote.LineItem{}` and use it for both Quote line-item endpoints. This is the highest-value nested type for discoverability, pattern matching, and ExDoc clarity.
- **D-03:** Add bounded nested structs for `%LatticeStripe.Quote.Computed{}` and `%LatticeStripe.Quote.StatusTransitions{}`. These are stable, developer-facing, and central to understanding quote state and totals.
- **D-04:** `automatic_tax` may be typed if the existing codebase already has a directly reusable bounded pattern; otherwise keep it as a raw map for this phase. The main rule is to avoid inventing a deep subtree just for Quote.
- **D-05:** Keep broad or fast-moving nested branches as raw maps in Phase 36, especially `subscription_data`, `invoice_settings`, and `from_quote`. They are real Stripe payloads, but not stable enough to justify hand-maintained nested struct trees here.
- **D-06:** Expandable top-level references should use the standard `is_map/1` guard + `ObjectTypes.maybe_deserialize/1` pattern. In particular: `customer`, `invoice`, `subscription`, and `subscription_schedule`.
- **D-07:** Register `"quote"` and `"quote_line_item"` in `LatticeStripe.ObjectTypes`. Also ensure the existing `Invoice.quote` back-reference can deserialize expanded Quote objects correctly.

### Lifecycle verbs and action semantics

- **D-08:** Keep Stripe-named explicit verbs: `Quote.finalize`, `Quote.accept`, and `Quote.cancel`. Do not hide state transitions behind `update/4`, `transition/4`, or higher-level helpers.
- **D-09:** `Quote.finalize/4` should accept a raw params map plus opts, following the existing `Invoice.finalize/4` action-verb pattern. Stripe exposes meaningful finalize-time input, and LatticeStripe should preserve that escape hatch.
- **D-10:** `Quote.accept/3` and `Quote.cancel/3` should be thin, parameterless lifecycle verbs plus opts only. They are clearer, less error-prone, and better aligned with the repo’s explicit irreversible-action style.
- **D-11:** Do not add predictive helpers like `what_will_be_created/1` in Phase 36. They are useful, but they are non-Stripe interpretation helpers and should be deferred until real demand justifies them.
- **D-12:** `@doc` for `accept/3` and `cancel/3` must call out their terminal/lifecycle consequences clearly. `accept/3` generates downstream billing objects; `cancel/3` ends the quote lifecycle. The docs should be explicit without adding runtime ceremony parameters.

### Line-item surface and PDF behavior

- **D-13:** Treat both Stripe Quote line-item endpoints as part of the same low-level Quote line-item surface. Ship:
  - `list_line_items/4`
  - `list_line_items!/4`
  - `stream_line_items!/4`
  - `list_computed_upfront_line_items/4`
  - `list_computed_upfront_line_items!/4`
  - `stream_computed_upfront_line_items!/4`
- **D-14:** This is not a new capability in the Accrue sense; it is necessary completeness for the Quote line-item API. Omitting `computed_upfront_line_items` would create a semantic footgun where upfront charges disappear from the SDK surface.
- **D-15:** `Quote.pdf/3` should return `{:ok, binary()} | {:error, Error.t()}` at the resource layer. Do not leak `%Response{}` from the public Quote API just because the underlying transport uses `Client.download/2`.
- **D-16:** `Quote.pdf!/3` should return raw binary or raise `LatticeStripe.Error`, matching the normal bang/non-bang public contract.
- **D-17:** Do not add local status validation for PDF availability. Document the precondition prominently instead: Stripe only provides PDFs for finalized/open or accepted quotes; `draft` and `canceled` requests may 404.
- **D-18:** Docs must distinguish three concepts cleanly:
  - embedded quote `line_items` / `computed.*.line_items` are partial object snapshots
  - `list_line_items/4` is the paginated quoted-input surface
  - `list_computed_upfront_line_items/4` is the paginated upfront-only computed surface

### Documentation and DX posture

- **D-19:** Quote docs should be richer than minimal generated SDK docs. The moduledoc should teach the Quote lifecycle, explain what `accept/3` generates, and make the Stripe-vs-Accrue boundary obvious.
- **D-20:** Keep the docs at the SDK layer. Show how to call Quote endpoints correctly and what comes back, but do not teach quote approval systems, entitlement changes, or app-owned billing workflow orchestration.
- **D-21:** Examples should emphasize the real sequence:
  - create or update draft quote
  - finalize
  - inspect/download PDF
  - accept
  - then follow downstream invoice/subscription state through normal Stripe resources and webhooks
- **D-22:** Do not create a dedicated Quote guide in Phase 36 unless planning explicitly pulls forward Phase 37 docs work. Rich moduledoc + focused examples is the default recommendation for this phase.

### the agent's Discretion

- Exact `@known_fields` breadth and field ordering for `%Quote{}`, `%Quote.LineItem{}`, `%Quote.Computed{}`, and `%Quote.StatusTransitions{}`
- Whether `automatic_tax` should be a dedicated nested struct in Phase 36 or remain a raw map
- Exact helper extraction boundaries for line-item endpoint reuse and expandable-field parsing
- Whether custom `Inspect` is needed for Quote fields after reading the final field set
- Test helper naming and fixture module layout

</decisions>

<specifics>
## Specific Ideas

- The coherent recommendation set for this phase is: **selective typing, explicit Stripe verbs, complete line-item coverage, binary PDF download, rich moduledoc, and no workflow-owned convenience layer**.
- This is intentionally different from both extremes:
  - not a generated-SDK-style deep type tree
  - not a loose raw-map wrapper like older Stripe clients
- The main footguns to prevent are:
  - shipping only one Quote line-item endpoint and silently hiding upfront charges
  - typing broad volatile Quote branches so deeply that they become stale and misleading
  - treating `pdf/3` like a normal JSON endpoint
  - slipping into Accrue territory with predictive or orchestration helpers
- User preference for this discussion pass: bias toward decisive defaults and only surface materially impactful forks. Downstream planning should preserve that posture where practical.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and project context
- `.planning/ROADMAP.md` — Phase 36 goal, dependency, and success criteria
- `.planning/REQUIREMENTS.md` — QUOT-01 through QUOT-05
- `.planning/STATE.md` — v1.3 sequencing, Phase 32 download dependency, Quote PDF pitfall
- `.planning/PROJECT.md` — SDK philosophy, principle of least surprise, low-magic public API
- `.planning/threads/lattice-stripe-vs-accrue-scope-boundary.md` — Quote must stay at resource coverage, not billing-engine orchestration

### Prior phase decisions and patterns
- `.planning/phases/32-file-filelink/32-CONTEXT.md` — binary download transport decisions used by `Quote.pdf/3`
- `.planning/phases/33-disputes/33-CONTEXT.md` — explicit irreversible verb docs pattern and small public-surface discipline
- `.planning/phases/34-creditnote/34-CONTEXT.md` — line-item subresource coverage and selective typing posture
- `.planning/phases/35-mandate-setupattempt/35-CONTEXT.md` — bounded-struct vs raw-map decision rule for hand-written Stripe resources
- `.planning/phases/21-customer-portal/21-CONTEXT.md` — precedent for typing bounded high-signal nested objects instead of broad maps

### Existing code patterns to follow
- `lib/lattice_stripe/client.ex` — `Client.download/2` behavior and normal request pipeline
- `lib/lattice_stripe/resource.ex` — `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1`
- `lib/lattice_stripe/object_types.ex` — expand-deserialization registry
- `lib/lattice_stripe/invoice.ex` — `finalize/4`, expandable-field parsing, and `Invoice.quote` back-reference
- `lib/lattice_stripe/checkout/session.ex` — `list_line_items/4` and `stream_line_items!/4` pattern
- `lib/lattice_stripe/credit_note.ex` — line-item subresource pattern and selective typed-nesting precedent
- `lib/lattice_stripe/dispute.ex` — irreversible-action documentation posture
- `test/lattice_stripe/client_test.exs` — binary download behavior already exercised for the Quote PDF path

### Local research and prompts
- `.planning/research/FEATURES.md` — Quote endpoint inventory, lifecycle, downstream object generation, and line-item semantics
- `.planning/research/PITFALLS.md` — PDF binary footgun, dual line-item endpoint risk, expandable-field guard risk
- `.planning/research/ARCHITECTURE.md` — Quote nested-struct sketch and binary download architecture
- `.planning/research/STACK.md` — PDF endpoint behavior and transport expectations
- `prompts/elixir-best-practices-deep-research.md` — stable return shapes, assertive APIs, no alternative return-type footguns
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — explicit public API, low-magic configuration, and OSS library ergonomics
- `prompts/stripe-sdk-api-surface-area-deep-research.md` — breadth posture, versioning pressure, escape-hatch philosophy
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — prioritize high-value Stripe workflows and production DX
- `prompts/payments_domain_field_guide.md` — billing/payment lifecycle vocabulary and state-machine grounding
- `prompts/The definitive Stripe library gap in Elixir - a master research document.md` — ecosystem gap, stripity limitations, and the need for first-class Stripe DX in Elixir

### External Stripe and ecosystem references
- `https://docs.stripe.com/api/quotes` — Quote endpoint inventory
- `https://docs.stripe.com/api/quotes/object` — Quote object fields and nested objects
- `https://docs.stripe.com/api/quotes/finalize` — finalize semantics and optional params
- `https://docs.stripe.com/api/quotes/accept` — accept semantics
- `https://docs.stripe.com/api/quotes/cancel` — cancel semantics
- `https://docs.stripe.com/api/quotes/pdf` — PDF endpoint behavior
- `https://docs.stripe.com/api/quotes/line_items` — quoted input line items
- `https://docs.stripe.com/api/quotes/line_items/upfront` — computed upfront line items
- `https://docs.stripe.com/quotes` — lifecycle and downstream object generation overview
- `https://hexdocs.pm/stripity_stripe/Stripe.Quote.html` — prior Elixir ecosystem precedent and cautionary comparison

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Client.download/2` already solves the transport problem for `Quote.pdf/3`
- `Checkout.Session.list_line_items/4` and `CreditNote.list_line_items/4` are direct templates for nested paginated subresource access
- `ObjectTypes.maybe_deserialize/1` plus `is_map/1` guards are the established expandable-field pattern
- `Invoice.finalize/4` is the closest action-verb precedent for a param-bearing Quote finalize endpoint
- `Dispute.close/3` is the closest thin irreversible-action precedent for `accept/3` and `cancel/3`

### Established Patterns
- Public APIs prefer stable tuple returns with bang variants layered on top
- Explicit verbs beat “magic update with flags” for lifecycle transitions
- Hand-written resources type bounded, high-signal nested objects and leave broad, volatile branches Stripe-shaped
- Nested paginated subresources should expose both list and stream surfaces
- Forward compatibility relies on `@known_fields` plus `extra`, not exhaustive modeling

### Integration Points
- `lib/lattice_stripe/quote.ex` — new top-level Quote resource module
- `lib/lattice_stripe/quote/line_item.ex` — typed line-item module
- `lib/lattice_stripe/quote/computed.ex` — bounded computed-summary module
- `lib/lattice_stripe/quote/status_transitions.ex` — lifecycle timestamp module
- `lib/lattice_stripe/object_types.ex` — add Quote object registrations
- `lib/lattice_stripe/invoice.ex` — ensure expanded `quote` back-reference deserializes correctly
- `test/support/fixtures/quote.ex` — fixture helpers for unit and integration coverage

</code_context>

<deferred>
## Deferred Ideas

- `Quote.what_will_be_created/1` or other predictive helpers
- Typed `subscription_data`, `invoice_settings`, or `from_quote` sub-struct trees if real downstream demand appears
- A dedicated Quote guide or broader quote-to-invoice recipe if Phase 37 intentionally pulls docs work forward
- Any readiness, approval, or orchestration helper that starts to look like billing-engine behavior

</deferred>

---

*Phase: 36-quote*
*Context gathered: 2026-05-25*
