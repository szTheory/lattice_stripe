# Phase 75: Typed Contract Updates - Context

**Gathered:** 2026-09-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Make evidence-qualified, high-value Stripe response fields on already-supported resources available as useful typed data while preserving `extra`, existing public behavior, and the default Stripe API version. Phase 74 selected no fields: implementation is conditional on first reopening candidates and establishing exact drift-inventory membership plus immutable GA OpenAPI snapshot identity and exact schema paths. If no candidate passes, do not invent a selection or expand scope; record that no field is eligible and stop implementation planning pending evidence.

</domain>

<decisions>
## Implementation Decisions

### Field eligibility and API-version contract
- **D-01:** Reopen Phase 74 candidates individually. A field is eligible only after exact inventory membership and its exact path in an immutable GA OpenAPI snapshot are established, with the stable source, minimum API version, and fixture provenance recorded. Select only eligible fields that solve a clear, costly adopter job; if none qualify, leave the implementation unstarted rather than promoting on changelog prose, a candidate count, or mutable schema evidence.
- **D-02:** Keep the default API version at `2026-03-25.dahlia`. A later-version field must name its minimum Stripe API version and the response/event surfaces where it is available, as supported by evidence. A default API pin change remains a separate compatibility decision requiring the Phase 74 D-10 review.

### Typed response shape
- **D-03:** Add qualified fields additively to the existing resource structs and `@type t` definitions, following each resource's established `@known_fields` and `from_map/1` decoder pattern. Do not introduce strict response schemas, per-API-version resource modules, Ecto schemas, or a new modeling dependency for this bounded response-decoding work.
- **D-04:** Preserve the unknown-key `extra` contract. Represent absent/nullable fields consistently with the verified schema and existing decoder conventions, normally as `nil`. For fields confirmed expandable, retain the established ID-string, expanded-resource, or `nil` union. Keep enum-like Stripe values open to new strings; do not introduce closed enums without an upstream stability guarantee.

### Proof and adopter documentation
- **D-05:** For each selected field, add focused decoder coverage for evidence-supported cases: ordinary value, omission/null behavior, ID/expanded form when applicable, unknown enum-like values when applicable, and retention of unrelated unknown response keys in `extra`. Assert only behavior the SDK actually promises; these are decoder checks, not claims about live Stripe behavior.
- **D-06:** Record fixture provenance accurately (captured or schema-derived), including API version and immutable GA snapshot identity/path. Update the field's public type/module documentation and changelog with its adopter meaning, minimum API version, and proven endpoint/event availability. Update a canonical guide only when it materially helps an adopter complete the relevant job.
- **D-07:** Keep proof proportional to the change: focused tests and compatibility review are the default. A broad API-version matrix or Phoenix/Plug/provider integration proof is warranted only if the selected change actually crosses those boundaries. This is a headless library change; its UX surface is the API and HexDocs, not a visual UI.

### the agent's Discretion
- After the evidence gate passes, choose the eligible field cluster by adopter consequence and coherence, with priority for reconciliation, money movement, and other costly operational work as established in Phase 74.
- Follow the closest existing resource decoder, fixture, and test pattern; use only field-specific shape cases supported by the immutable schema evidence.
- If evidence reveals request semantics, webhook behavior, or a compatibility impact beyond additive response decoding, surface that boundary for replanning instead of implying this phase proves it.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and contract decisions
- `.planning/ROADMAP.md` §"Phase 75: Typed Contract Updates" — goal, requirements, success criteria, and phase boundary.
- `.planning/REQUIREMENTS.md` §"Stripe API Contract Freshness" — DRIFT-02 through DRIFT-04 requirements.
- `.planning/PROJECT.md` §"Maintainer Intent" and §"Verification and Automation Default" — adopter-first scope, preservation goals, and proportionate automated proof.
- `.planning/phases/74-versioned-stripe-drift-triage/74-TRIAGE.md` — candidate ledger, evidence gaps, API pin decision, and D-10 compatibility boundary. No candidate is currently selected.
- `.planning/phases/74-versioned-stripe-drift-triage/74-CONTEXT.md` — locked prior decisions and decoding constraints.
- `.planning/phases/74-versioned-stripe-drift-triage/74-01-SUMMARY.md` — explicit Phase 75 readiness caveat: reopen evidence before implementation.
- `.planning/threads/v1-12-next-milestone-assessment.md` — dated drift discovery context; its count-only note is not exact-path evidence.

### Domain and project research
- `prompts/README.md` — identifies the current domain guide and establishes that archived prompt research is historical input subordinate to shipped code and current planning truth.
- `prompts/payments_domain_field_guide.md` §"API versioning" and §"Testing" — Stripe API/version vocabulary and test-context guidance.
- `prompts/archive/elixir-opensource-libs-best-practices-deep-research.md` — Elixir library API, typespec, documentation, compatibility, and dependency guidance; historical research, reconcile with current code.
- `prompts/archive/stripe-sdk-api-surface-area-deep-research.md` — Stripe SDK typing, versioning, and unknown-value escape-hatch tradeoffs; historical research.
- `prompts/archive/stripe-lib-priority-user-flows-deep-research.md` — adopter/job prioritization and costly payment/billing operational seams; historical research.
- `prompts/archive/stripe-explanation-domain-language-deep-research.md` — Stripe object relationships and versioned-domain context; historical research.

### Existing implementation, tests, and SemVer contract
- `lib/lattice_stripe/invoice.ex` and `test/lattice_stripe/invoice_test.exs` — representative Invoice struct, decoder, nested map handling, and `extra` coverage.
- `lib/lattice_stripe/refund.ex` and `test/lattice_stripe/refund_test.exs` — expandable-resource and unknown-field patterns relevant to Refund candidates.
- `lib/lattice_stripe/dispute.ex` and `test/lattice_stripe/dispute_test.exs` — nested response and unknown-value patterns relevant to Dispute candidates.
- `lib/lattice_stripe/invoice_item.ex` and `test/lattice_stripe/invoice_item_test.exs` — InvoiceItem decoding and unknown-field coverage.
- `lib/lattice_stripe/subscription.ex` and `test/lattice_stripe/subscription_test.exs` — expandable references, open-value fallback, and map-based payment settings.
- `guides/api_stability.md` — public struct compatibility and SemVer meaning of optional field additions.

### External authoritative references
- [Stripe API versioning](https://docs.stripe.com/api/versioning) — version-specific behavior and testing before upgrades.
- [Stripe OpenAPI repository](https://github.com/stripe/openapi) — GA versus preview specification sources.
- [Elixir typespecs](https://hexdocs.pm/elixir/typespecs.html) — typespecs as documentation and tooling, not runtime validation.
- [Ecto data mapping and validation](https://hexdocs.pm/ecto/data-mapping-and-validation.html) — Ecto schema/changeset use cases; not a requirement for this decoder boundary.
- [Stripe Node versioning and TypeScript policy](https://github.com/stripe/stripe-node#typescript-and-the-stripe-versioning-policy) — cross-language example of API/type version mismatch and open-enum handling.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Resource structs already use `@known_fields`, `from_map/1`, and `extra` to expose selected data while retaining unknown top-level response keys.
- Invoice and Subscription model `payment_settings` as maps today; no new nested type should be introduced without a qualified adopter need and stable schema evidence.
- Existing focused tests cover unknown-field retention and open response values, providing local patterns for narrow regressions.

### Established Patterns
- This is a hand-written Elixir SDK with public resource structs and typespecs. Typespecs document contracts and aid tools; decoder behavior is what determines runtime results.
- Expandable fields use a string ID, expanded resource struct, or `nil` where already supported.
- Unknown enum-like values remain usable through string fallbacks, and unknown response keys remain available in `extra`.
- `guides/api_stability.md` defines optional public struct fields as additive within the current major line, while field types and value representation are compatibility commitments.

### Integration Points
- Qualified response keys must be added consistently to the resource's known-field list, struct, typespec, decoder, focused tests/fixtures, public docs, and changelog.
- Later API-version availability is not implied by the package default or by webhook payloads; document only surfaces confirmed by candidate evidence.
- Phoenix/Plug host behavior and Ecto persistence are outside a pure resource-response decoder unless evidence shows the selected change crosses those integration boundaries.

</code_context>

<specifics>
## Specific Ideas

- Treat Phase 74's five leads as deferred, not selected: `Invoice.amount_paid_off_stripe`; `Refund.customer`, `Refund.customer_account`, and `Refund.payment_method`; `Dispute.payment_method_details.card.network`; `InvoiceItem.frozen_fields`; and Invoice/Subscription `payment_settings.payment_method_types` (Billie).
- Keep Phase 74's minimum-version annotations and requirement for immutable snapshot identity and exact schema paths. A changelog entry alone is insufficient selection evidence.
- Preserve the API pin and the response decoder's tolerant contract while making useful fields easier for adopters to discover and consume.
- Make fixture provenance explicit so schema-derived synthetic examples cannot be mistaken for captured Stripe responses.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 75 scope. Default API pin migration and broad multi-version response models remain separate compatibility work, not shortcuts for selecting fields.

</deferred>

---

*Phase: 75-typed-contract-updates*
*Context gathered: 2026-09-23*
