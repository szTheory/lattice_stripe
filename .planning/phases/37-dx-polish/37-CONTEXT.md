# Phase 37: DX Polish - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Polish the public developer experience around the completed v1.3 surface so a new Elixir/Phoenix adopter can copy-paste a working webhook setup, discover realistic testing helpers, follow end-to-end workflow recipes, and trust that docs/examples/version references match the actual API surface.

This phase is documentation, testing-surface, and package-truth polish. It does **not** add new Stripe capabilities, app-level billing orchestration, Accrue-style product helpers, or release-operations work such as tagging/publishing.

Requirements anchor: DX-01, DX-02, DX-03, DX-04.

</domain>

<decisions>
## Implementation Decisions

### Webhook recipe stance

- **D-01:** `guides/webhooks.md` should present **one canonical Phoenix quickstart**: mount `LatticeStripe.Webhook.Plug` in `endpoint.ex` before `Plug.Parsers`, using the plug's `at:` path gate and a handler module.
- **D-02:** The `router forward + CacheBodyReader` pattern remains supported, but it is a **secondary / advanced alternative**, not an equal co-primary path in top-level docs.
- **D-03:** Webhook examples must emphasize the raw-body invariant clearly: signature verification must happen against the exact request bytes before JSON mutation.
- **D-04:** Public examples should prefer **runtime secret resolution** (`secret: {M, F, A}` or a zero-arity function) over compile-time `System.fetch_env!` in plug config examples.
- **D-05:** Docs must explicitly teach the webhook operating model already favored by the project: app flows start work, **webhooks confirm reality**.

### Fixture builder API shape

- **D-06:** Public v1.3 fixture builders should use a **mixed dual-surface design** with **raw maps as the canonical source of truth** and explicit typed/event wrappers layered on top.
- **D-07:** Resource-specific fixture builders should be exposed through a discoverable namespace such as `LatticeStripe.Testing.Fixtures.*`, with scenario-style helpers that return Stripe-shaped raw maps.
- **D-08:** `LatticeStripe.Testing` should stay focused on cross-resource helpers and thin wrappers, such as turning canonical fixture maps into signed webhook payloads, `%Event{}` structs, or decoded resource structs.
- **D-09:** Do **not** use option-driven polymorphism like `as: :map | :struct`. Separate functions/modules should expose separate return shapes.
- **D-10:** The fixture API should cover the v1.3 families explicitly: `File`, `FileLink`, `Dispute`, `CreditNote`, `Mandate`, `SetupAttempt`, and `Quote`.

### Recipes guide depth

- **D-11:** Add a **compact** `guides/recipes.md`, not a broad cookbook.
- **D-12:** The recipes guide should contain **three flagship workflows**, aligned to the v1.3 milestone and Phase 37 requirements:
  - dispute handling / evidence workflow
  - credit issuance / invoice adjustment workflow
  - quote-to-invoice workflow
- **D-13:** Each recipe should stay library-scoped: show the LatticeStripe calls, the webhook handoff, and the authoritative follow-up guides; avoid app-policy logic or Accrue-style orchestration.
- **D-14:** `guides/recipes.md` should bridge the conceptual JTBD guide and the deep topical guides, not replace either.

### Consistency sweep boundary

- **D-15:** The consistency sweep should cover the **full `guides/` tree plus `README.md`, `CHANGELOG.md`, and `mix.exs` doc/version truth**.
- **D-16:** The sweep should stop short of release-management work: no tagging, publishing, or release-please workflow redesign belongs in this phase.
- **D-17:** High-visibility trust gaps must be corrected in this phase, especially stale version references, stale install snippets, broken or missing guide indexes, mismatched examples, and stale docs source metadata.
- **D-18:** The public docs/package story on the branch should align to the **actual v1.3-capable codebase state** by the end of this phase, while keeping release status explicit in `CHANGELOG.md` rather than implying a publish action happened.

### Decision posture for downstream agents

- **D-19:** Downstream planning and implementation should default to **decisive recommendations** for routine forks instead of reopening low-impact gray areas.
- **D-20:** Only **very impactful** product-shaping decisions should be surfaced back to the user once this context is in place. Ordinary doc/test/API-shape choices should be resolved agent-side when a coherent default already exists.

### the agent's Discretion

- Exact public naming of fixture-builder modules and wrapper functions
- Exact ordering and presentation of the three recipes
- Which existing guides need only cross-link fixes versus example rewrites
- The exact wording and layout treatment of the webhook quickstart and troubleshooting sections
- The exact scope of README guide-list cleanup, as long as it reflects the real guide set and current API surface

</decisions>

<specifics>
## Specific Ideas

- The coherent recommendation set is: **one canonical webhook path, explicit test helpers, compact recipes, and a full docs/package-truth sweep**.
- This phase should feel like adopting a polished Elixir library, not reading a giant Stripe handbook. Prefer focused guides, explicit APIs, and copy-paste success over exhaustive branching.
- The biggest DX traps to avoid are:
  - presenting multiple equal webhook setup choices up front
  - hiding fixture return shapes behind magic options
  - turning `recipes.md` into a sprawling cookbook
  - leaving README / install snippets / version refs stale while polishing lower-visibility guides
- The user preference for this phase and future similar discuss passes is clear: **shift recommendation-making left**. Default to coherent agent-side decisions for ordinary tradeoffs and only interrupt on truly consequential forks.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone context
- `.planning/ROADMAP.md` — Phase 37 goal, dependency, and success criteria
- `.planning/REQUIREMENTS.md` — DX-01 through DX-04
- `.planning/PROJECT.md` — library philosophy, adoption goal, and current milestone framing
- `.planning/STATE.md` — v1.3 sequencing and the carried-forward docs-truth concern
- `.planning/threads/lattice-stripe-vs-accrue-scope-boundary.md` — maintain the SDK-vs-Accrue boundary

### Existing docs and code that define current behavior
- `guides/webhooks.md` — current webhook integration guide and areas to canonicalize
- `guides/testing.md` — current testing guidance and `LatticeStripe.Testing` posture
- `guides/user-flows-and-jtbd.md` — conceptual guide that `recipes.md` should bridge from
- `guides/customer-portal.md` — existing strong Phoenix-style end-to-end example pattern
- `README.md` — highest-visibility public entrypoint with current version drift
- `CHANGELOG.md` — release-status framing and migration/public truth
- `mix.exs` — ExDoc extras/groups, package version, and docs source metadata
- `lib/lattice_stripe/testing.ex` — current public testing API
- `lib/lattice_stripe/webhook/plug.ex` — canonical plug behavior and supported options
- `lib/lattice_stripe/webhook/cache_body_reader.ex` — secondary webhook path implementation
- `test/support/fixtures/` — existing canonical raw fixture sources, especially:
  - `dispute.ex`
  - `credit_note.ex`
  - `file.ex`
  - `file_link.ex`
  - `mandate.ex`
  - `setup_attempt.ex`
  - `quote.ex`

### Prior phase decisions that apply directly
- `.planning/phases/32-file-filelink/32-CONTEXT.md` — file/PDF flow context and testing implications
- `.planning/phases/33-disputes/33-CONTEXT.md` — disputes workflow surface and evidence semantics
- `.planning/phases/34-creditnote/34-CONTEXT.md` — credit-note workflow surface and line-item semantics
- `.planning/phases/35-mandate-setupattempt/35-CONTEXT.md` — read-only diagnostic resource posture
- `.planning/phases/36-quote/36-CONTEXT.md` — quote lifecycle and PDF/line-item semantics

### Local research prompts to honor
- `prompts/elixir-best-practices-deep-research.md`
- `prompts/elixir-opensource-libs-best-practices-deep-research.md`
- `prompts/phoenix-best-practices-deep-research.md`
- `prompts/stripe-lib-priority-user-flows-deep-research.md`
- `prompts/stripe-sdk-api-surface-area-deep-research.md`
- `prompts/payments_domain_field_guide.md`
- `prompts/The definitive Stripe library gap in Elixir - a master research document.md`

### External ecosystem references
- `https://docs.stripe.com/webhooks` — authoritative webhook behavior and raw-body requirement
- `https://docs.stripe.com/webhooks/signature` — signature-verification footguns and troubleshooting
- `https://hexdocs.pm/plug/Plug.Parsers.html` — official `:body_reader` behavior and raw-body caching pattern
- `https://hexdocs.pm/phoenix/Phoenix.Router.html#forward/4` — router `forward` behavior for the advanced webhook path
- `https://hexdocs.pm/ex_doc/ExDoc.html` — ExDoc guide/extras organization and docs metadata behavior
- `https://hex.pm/docs/publish` — Hex package metadata/docs publication expectations
- `https://hexdocs.pm/elixir/writing-documentation.html` — Elixir documentation guidance for examples and maintenance

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LatticeStripe.Webhook.Plug` already provides the low-magic happy path for Phoenix webhook handling.
- `LatticeStripe.Webhook.CacheBodyReader` already provides the advanced `Plug.Parsers` hook path.
- `LatticeStripe.Testing.generate_webhook_event/3` and `generate_webhook_payload/3` already establish the public wrapper pattern to build on.
- `test/support/fixtures/*.ex` already contains realistic, scenario-oriented raw fixture factories for the v1.3 resource families.
- `guides/customer-portal.md` already contains a strong Phoenix-oriented example style that can inform recipe-writing tone.

### Established Patterns
- The repo prefers explicit APIs, stable return shapes, and thin bang/non-bang distinctions over option-driven shape changes.
- Existing guides are strongest when they teach one clear path, then deep-link outward.
- The docs already carry the principle that webhooks, not redirects, confirm async billing truth.
- ExDoc extras are already the primary public docs structure; Phase 37 should improve that structure rather than replace it.

### Integration Points
- `guides/webhooks.md` — canonical webhook recipe rewrite
- `guides/testing.md` — new fixture-builder public story
- `guides/recipes.md` — new compact workflow guide
- `README.md` / `CHANGELOG.md` / `mix.exs` — package-truth alignment
- `lib/lattice_stripe/testing.ex` and new public fixture namespaces/modules — public testing-surface expansion

</code_context>

<deferred>
## Deferred Ideas

- Expanding `guides/recipes.md` into a much larger cookbook covering non-v1.3 workflow families
- Folding release automation, release-please tuning, tagging, or publish mechanics into this phase
- Higher-level workflow helpers that start to look like Accrue or app-owned billing abstractions
- Reopening ordinary gray-area decisions during planning/implementation unless a genuinely high-impact contradiction appears

</deferred>

---

*Phase: 37-dx-polish*
*Context gathered: 2026-05-25*
