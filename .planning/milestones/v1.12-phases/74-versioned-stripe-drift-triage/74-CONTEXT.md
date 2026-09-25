# Phase 74: Versioned Stripe Drift Triage - Context

**Gathered:** 2026-09-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Classify candidate field changes in already-supported Stripe resources against stable, versioned Stripe evidence and select a bounded set by adopter value, operational consequence, and safe typing implications. This phase produces an actionable selection and deferral record for Phase 75. It does not implement typed fields, add resource families, or change the default Stripe API version.

</domain>

<decisions>
## Implementation Decisions

### Stripe source and version evidence
- **D-01:** Treat `mix lattice_stripe.check_drift` and its OpenAPI `master` comparison as candidate discovery, not proof that a field is stable or applicable to the SDK's default API version.
- **D-02:** A candidate considered for promotion must have a stable, versioned Stripe source (changelog or versioned API reference) and corroboration from a GA OpenAPI source. Record the exact source, API version, GA/preview status, and whether the field applies to the current pin or a later stable version.
- **D-03:** Classify findings as current stable, later stable, preview-only, or unconfirmed/schema noise. Preview-only and unconfirmed findings are not promoted. Later-stable fields may be selected only when their minimum API version is explicit and a versioned fixture can prove decoding; the default pin need not move to expose an opt-in newer contract.
- **D-04:** A test-mode/runtime probe is corroborating behavior evidence after source qualification; it cannot establish GA status or replace versioned source provenance.

### Candidate prioritization
- **D-05:** After the stable-source and type/decode safety gates, prioritize by the adopter job improved, operational consequence of missing the field, and whether related fields form a coherent resource-level addition.
- **D-06:** Apply extra weight to fields that can affect money movement, tax, fulfillment state, webhook interpretation/routing, Connect tenant context, or financial reconciliation. Keep LatticeStripe's boundary at Stripe-shaped primitives; application policy remains with the adopter.
- **D-07:** Do not rank by raw candidate count, recency, fixed numeric score, or a per-resource quota. Record the reason for each selected or deferred candidate so the ranking remains explainable without creating scoring ceremony.

### Triage record and API pin
- **D-08:** Use a concise, human-reviewable Markdown triage record as the phase's decision artifact; do not add a generator/validator or create one issue per field for this bounded review.
- **D-09:** For selected and deferred candidates, record resource and field path, stable source/API version and status, current-pin applicability, adopter job, semantic rationale, type/decode implications, and disposition. Every deferral records why it waits and what evidence would reopen it.
- **D-10:** Keep the default API version at `2026-03-25.dahlia` in this milestone. Consider a pin change only through a separate compatibility review covering the intervening Stripe changelog, request semantics, response decoding, webhook event/version behavior, supported adopter flows, and package SemVer impact. Date freshness or a single successful fixture is insufficient evidence.
- **D-11:** Any selected optional response field preserves the existing `extra` behavior for unknown response keys. Stripe enum-like values remain open where upstream can add values; do not turn a convenient current value list into a closed consumer contract without a Stripe stability guarantee.

### the agent's Discretion
- Exact Markdown layout, grouping of candidates into coherent field clusters, and concise wording of evidence summaries, provided every selected/deferred row carries D-09 evidence.
- The concrete shortlist, after inspecting current versioned Stripe sources and applying D-01–D-07; do not infer scope from the raw 104-field count.
- Whether a source ambiguity is recorded as `unconfirmed/schema noise` or deferred pending further source confirmation; do not promote it while unresolved.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and adopter jobs
- `.planning/ROADMAP.md` §"Phase 74: Versioned Stripe Drift Triage" — phase goal, success criteria, dependencies, and scope boundary.
- `.planning/REQUIREMENTS.md` §"Stripe API Contract Freshness" — DRIFT-01 definition.
- `.planning/PROJECT.md` §"Maintainer Intent" and §"Key Decisions" — Pareto/adopter focus, API pin rule, and maintenance boundary.
- `.planning/JTBD-MAP.md` §"Audience and Domain Lenses" and §"Ops, reliability, and integration hygiene" — adopter jobs and SDK/application boundary.
- `.planning/threads/v1-12-next-milestone-assessment.md` §"Stripe API Freshness Findings" and §"Candidate Wedges" — current drift counts, source-date evidence, examples, and overbuild line.

### Project research and API design guidance
- `prompts/README.md` — marks `payments_domain_field_guide.md` as current and archived prompt research as historical context.
- `prompts/payments_domain_field_guide.md` §"API versioning" and §"Testing" — Stripe contract vocabulary and versioned testing context.
- `prompts/archive/stripe-sdk-api-surface-area-deep-research.md` — commissioned SDK surface, versioning, and compatibility alternatives; historical input only.
- `prompts/archive/elixir-opensource-libs-best-practices-deep-research.md` — Elixir library API, error, and documentation ergonomics; historical input only.

### Existing drift and decoding implementation
- `lib/lattice_stripe/drift.ex` — current OpenAPI `master` source, `@known_fields` comparison, and report output.
- `lib/mix/tasks/lattice_stripe.check_drift.ex` — developer-facing drift task and exit behavior.
- `lib/lattice_stripe/subscription.ex` — representative `@known_fields`, struct, and tolerant `from_map/1` pattern; unknown fields are retained in `extra`.
- `guides/api_stability.md` — public package compatibility and SemVer contract.

### External authoritative evidence reviewed
- [Stripe API versioning](https://docs.stripe.com/api/versioning) — Stripe API release and version-upgrade guidance.
- [Stripe OpenAPI repository](https://github.com/stripe/openapi) — distinction between GA `/latest` and preview `/preview` specifications.
- [Stripe Node versioning policy](https://github.com/stripe/stripe-node#typescript-and-the-stripe-node-versioning-policy) — example of SDK types tracking an API version and risks when overriding it.
- [Stripe Ruby SDK](https://github.com/stripe/stripe-ruby) — generated type/API-version alignment and response access patterns.
- [Elixir typespecs](https://hexdocs.pm/elixir/typespecs.html) and [Ecto.Enum](https://hexdocs.pm/ecto/Ecto.Enum.html) — documentation/tooling role of typespecs and the closed-world behavior of declared enum values; Ecto is not the SDK's response contract.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LatticeStripe.Drift` and `Mix.Tasks.LatticeStripe.CheckDrift` already inventory field additions, apparent removals, and unmodeled types. Phase 74 can use their output as a lead list without treating it as versioned truth.
- Resource `@known_fields`, structs, and `from_map/1` are the established extension seam. For example, `Subscription.from_map/1` splits recognized keys from the response and retains the rest in `extra`.
- Existing synthetic resource fixtures and focused `from_map/1` tests can support the version-specific evidence handoff to Phase 75.

### Established Patterns
- The SDK is hand-written and Stripe-shaped, with explicit functions and typespecs; the project does not use Ecto schemas as its API model or a public code-generation DSL.
- Response decoding is forward-tolerant through `extra`; typed fields improve ergonomics without requiring an all-fields wrapper.
- `LatticeStripe.api_version/0` currently returns `2026-03-25.dahlia`; client configuration and docs share that default. A pin change therefore crosses source, test, and documentation surfaces and requires explicit compatibility review.
- ExDoc guides and error/return contracts are the library's user experience. No visual UI or separate brandbook applies to this headless package.

### Integration Points
- The drift report originates from `lib/lattice_stripe/drift.ex` and `.github/workflows/drift.yml`; Phase 74's triage artifact should preserve provenance alongside its decisions.
- Selected fields flow from this phase's evidence record into Phase 75's resource structs, decoders, fixtures, tests, and adopter documentation.
- Phase 75 should preserve existing API stability and `extra` tests while proving selected fields against the documented API version.

</code_context>

<specifics>
## Specific Ideas

- Keep the API pin unchanged at `2026-03-25.dahlia` unless separate compatibility evidence supports a deliberate move.
- Use stable, versioned sources to separate current stable fields from later stable, preview-only, and unconfirmed/noise candidates.
- Choose fields for common and costly adopter jobs, with extra attention to payment, tax, fulfillment, webhook, Connect, and reconciliation consequences.
- Keep Phase 74 evidence human-reviewable and scoped; avoid promoting all raw candidates or creating a permanent toolchain before this review demonstrates a need.
- Stripe API findings and public types should be version-aware; document a minimum version for any selected future-stable field rather than implying the default pin includes it.
</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 74 scope. Typed-field implementation belongs to Phase 75; API pin migration remains deferred pending compatibility evidence.

</deferred>

---

*Phase: 74-versioned-stripe-drift-triage*
*Context gathered: 2026-09-23*
