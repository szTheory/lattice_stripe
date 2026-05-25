# Phase 41: Quote Lifecycle E2E Verification - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the remaining milestone verification gaps for the shipped Quote resource so `QUOT-01` through `QUOT-05` can be accepted as current, credible, and auditable.

This is a verification-closure phase, not a new Quote feature phase. The Quote API, parser contracts, PDF surface, lifecycle verbs, fixtures, unit tests, and a narrow integration suite already exist from Phase 36. Phase 41 should add the missing integration evidence for quote lifecycle closure, create a closed `36-VERIFICATION.md`, and reconcile Quote traceability without broadening into Accrue-owned orchestration, general roadmap cleanup, or fresh Quote API design.

</domain>

<decisions>
## Implementation Decisions

### Lifecycle proof depth

- **D-01:** Use a **hybrid verification posture**. Integration tests must prove the Quote lifecycle edges that `stripe-mock` can truthfully cover, while unit tests remain the source of truth for parser depth, empty-param contracts, expanded-object decoding, and nuanced lifecycle semantics.
- **D-02:** Phase 41 integration evidence must explicitly exercise:
  - `Quote.pdf/3`
  - `Quote.accept/3`
  - `Quote.cancel/3`
  - one narrow quote-to-downstream follow-through hop after acceptance
- **D-03:** Do **not** treat `stripe-mock` as a real Quote state-machine oracle. Verifier wording must say that the integration evidence proves request routing, request encoding, binary transport, and typed decode sanity under `stripe-mock`, not full real-Stripe lifecycle semantics.
- **D-04:** Do **not** close Phase 41 with unit-only proof. The audit explicitly calls out missing integration evidence for Quote lifecycle closure, and the verifier should require fresh targeted Quote integration runs.

### Quote-to-invoice follow-through

- **D-05:** The correct follow-through depth is: `Quote.create/3 -> Quote.finalize/4 -> Quote.accept/3 -> inspect returned downstream reference -> retrieve exactly one linked downstream Stripe resource -> stop`.
- **D-06:** Prefer downstream follow-through in this order when present in the accepted quote response:
  - `invoice`
  - otherwise `subscription`
  - otherwise `subscription_schedule`
- **D-07:** Follow-through retrieval should assert **typed top-level decode only**. Do not assert invoice payment behavior, subscription activation timing, webhook ordering, or any broader multi-resource business workflow semantics.
- **D-08:** This is the least-surprise proof for a low-level Stripe SDK: it demonstrates the handoff users actually care about after `accept/3` without drifting into Accrue-owned orchestration or fake end-to-end billing-theater.

### PDF proof strictness

- **D-09:** `Quote.pdf/3` should be treated as an **expected integration-proof requirement** for Phase 41 because the audit explicitly flags missing Quote PDF integration coverage and PDF download is exactly the kind of wire-contract check `stripe-mock` is good at.
- **D-10:** The default success path is a real integration call that proves `Quote.pdf/3` returns raw binary over HTTP and does not leak a decoded struct or `%Response{}` wrapper.
- **D-11:** A fallback to unit/transport-only proof is allowed **only** if a concrete `stripe-mock` limitation is reproduced and documented in the verifier with the failure shape, date, and explicit note that live Stripe/test-environment proof remains outstanding.
- **D-12:** Even when integration passes, the verifier must not claim PDF rendering fidelity or business-semantic quote correctness. The proof is transport and binary-response handling only.

### Allowed repair scope

- **D-13:** Allow **narrow evidence repairs only**:
  - Quote integration-test additions or tightening for `pdf/3`, `accept/3`, `cancel/3`, and one downstream follow-through hop
  - small fixture or helper adjustments required to make those proofs executable and truthful
  - tiny support-code or wiring fixes only when they are strictly evidence-enabling for already-shipped Quote behavior
  - `36-VERIFICATION.md` creation plus QUOT-only traceability updates
- **D-14:** Do **not** reopen Quote API design, add new helper verbs, expand parser trees beyond the shipped Phase 36 contract, or perform opportunistic cleanup in unrelated resources, guides, or planning families.
- **D-15:** Do **not** absorb broad roadmap/requirements truth reconciliation in Phase 41. Keep planning-document edits tightly scoped to `36-VERIFICATION.md` and `QUOT-01` through `QUOT-05`. Broader planning-truth cleanup remains Phase 42 work.
- **D-16:** If verification reveals a substantive shipped Quote behavior defect rather than a proof gap, record it and route it to follow-up work instead of stretching Phase 41 into a hidden repair phase.

### Decision posture for downstream agents

- **D-17:** Shift ordinary planning and verification choices left to the agent for this phase. Downstream agents should prefer cohesive recommendations and agent discretion for routine tradeoffs instead of asking the user to adjudicate low-impact details repeatedly.
- **D-18:** Escalate only if a decision would materially affect:
  - shipped Quote behavior
  - public API surface
  - milestone acceptance standards
  - phase scope boundary
  - dependency footprint
  - verifier credibility
- **D-19:** Treat this as the standing workflow preference for Phase 41 planning and execution. If useful later, a broader GSD/process-level shift can be captured separately, but it should not broaden this phase’s implementation scope.

### the agent's Discretion

- Exact test naming and module structure for the new Quote integration coverage, as long as it stays aligned with current `test/integration/` conventions.
- Exact verifier table layout, wording, and score format, as long as the report is closed, audit-friendly, and explicit about `stripe-mock` limits.
- Whether the lifecycle proof uses `create -> cancel` or `finalize -> cancel`, as long as the chosen route is truthful and closes the explicit cancel-evidence gap.
- Whether the follow-through hop retrieves `Invoice`, `Subscription`, or `SubscriptionSchedule`, based on what the accepted Quote response actually exposes under `stripe-mock`.

</decisions>

<specifics>
## Specific Ideas

- The coherent recommendation set for Phase 41 is:
  - hybrid verification posture
  - one-hop downstream follow-through after accept
  - expected integration proof for `Quote.pdf/3`
  - narrow evidence repairs only
  - shift routine decisions left to the agent
- This matches the project’s philosophy in practice:
  - explicit and unsurprising public APIs
  - focused diffs
  - high-signal verification
  - no billing-engine orchestration inside LatticeStripe
- Main footguns to avoid:
  - pretending `stripe-mock` proves real quote lifecycle semantics
  - writing a verifier artifact that overclaims “end-to-end” behavior
  - broadening Phase 41 into Quote redesign or Phase 42 planning-truth cleanup
  - allowing “fallback” paths for PDF proof without a reproduced mock limitation

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone context
- `.planning/ROADMAP.md` — Phase 41 goal, audit gap wording, and success criteria
- `.planning/REQUIREMENTS.md` — `QUOT-01` through `QUOT-05` plus current traceability state
- `.planning/PROJECT.md` — SDK philosophy: explicit low-magic APIs, least surprise, and Stripe-shaped resource coverage
- `.planning/STATE.md` — current milestone position, prior closure posture, and Quote PDF pitfall
- `.planning/v1.3-v1.3-MILESTONE-AUDIT.md` — explicit Quote gaps: missing `36-VERIFICATION.md`, missing PDF integration proof, partial lifecycle follow-through, stale Quote tracking

### Prior Quote phase artifacts
- `.planning/phases/36-quote/36-CONTEXT.md` — locked Quote design decisions from the original feature phase
- `.planning/phases/36-quote/36-RESEARCH.md` — Quote implementation research and constraints
- `.planning/phases/36-quote/36-PATTERNS.md` — established code and test analogs for Quote
- `.planning/phases/36-quote/36-01-SUMMARY.md` — parser/object-registration/fixture completion evidence
- `.planning/phases/36-quote/36-02-SUMMARY.md` — public API, docs, and initial Quote test coverage evidence

### Verification-closure precedents
- `.planning/phases/38-dispute-evidence-e2e-verification/38-RESEARCH.md` — closure-phase framing for integration proof and audit closure
- `.planning/phases/38-dispute-evidence-e2e-verification/38-VALIDATION.md` — scoped verification posture for closure work
- `.planning/phases/39-credit-note-verification-closure/39-CONTEXT.md` — narrow proof-repair stance and shift-left workflow preference precedent
- `.planning/phases/39-credit-note-verification-closure/39-VERIFICATION.md` — current closure-verifier style
- `.planning/phases/40-mandate-setupattempt-integration-closure/40-CONTEXT.md` — AUTH closure scope discipline and escalation rules
- `.planning/phases/35-mandate-setupattempt/35-VERIFICATION.md` — fresh closure-verifier example with targeted unit + integration evidence

### Scope boundary and local research
- `.planning/threads/lattice-stripe-vs-accrue-scope-boundary.md` — Quote verification must stay at Stripe resource coverage, not billing-engine orchestration
- `prompts/elixir-best-practices-deep-research.md` — explicit return shapes, assertive APIs, and anti-footgun Elixir API design
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — Elixir OSS ergonomics, focused scope, and library-user expectations
- `prompts/stripe-sdk-api-surface-area-deep-research.md` — Stripe SDK testing, binary surfaces, and foundation-layer responsibilities
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — where Stripe SDKs should invest the most polish and proof
- `prompts/payments_domain_field_guide.md` — billing/payment lifecycle semantics and “don’t overclaim async behavior” grounding

### Existing code and test surfaces
- `lib/lattice_stripe/quote.ex` — shipped Quote API, lifecycle verbs, line-item helpers, and binary PDF contract
- `test/lattice_stripe/quote_test.exs` — current unit proof for request shape, parser behavior, `accept/3`, `cancel/3`, and `pdf/3`
- `test/integration/quote_integration_test.exs` — current narrow integration proof surface to extend
- `test/support/fixtures/quote.ex` — Quote fixture helpers for unit and integration coverage
- `lib/lattice_stripe/client.ex` — binary download path used by `Quote.pdf/3`
- `test/lattice_stripe/client_test.exs` — transport-level binary download proof already in place
- `lib/lattice_stripe/invoice.ex` — likely follow-through retrieval target and Quote back-reference precedent

### External references
- `https://docs.stripe.com/api/quotes` — canonical Quote endpoint inventory and lifecycle surface
- `https://docs.stripe.com/quotes/create` — Quote lifecycle overview, finalize/download/accept flow, and downstream object creation semantics
- `https://docs.stripe.com/api/quotes/pdf` — Quote PDF endpoint semantics and binary-return contract
- `https://docs.stripe.com/test-mode` — Stripe testing guidance and test-environment posture
- `https://github.com/stripe/stripe-mock` — official `stripe-mock` capabilities and limitations
- `https://github.com/stripe/stripe-ruby` — Stripe Ruby SDK development/testing posture using `stripe-mock`
- `https://hexdocs.pm/stripity_stripe/Stripe.Quote.html` — Elixir ecosystem Quote-surface precedent
- `https://github.com/elixir-ecto/ecto` — focused core tests plus separate heavier integration posture
- `https://raw.githubusercontent.com/elixir-lang/elixir/main/CONTRIBUTING.md` — targeted-test workflow precedent for serious Elixir OSS
- `https://raw.githubusercontent.com/phoenixframework/phoenix/main/CONTRIBUTING.md` — focused PR and verification discipline

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/integration/quote_integration_test.exs` already contains the right `stripe-mock` guard, `async: false` posture, and Quote integration harness.
- `test/support/fixtures/quote.ex` already provides draft/open/accepted/canceled Quote fixtures plus downstream-reference shapes.
- `test/lattice_stripe/quote_test.exs` already locks the public Quote contract for request shapes, parser semantics, and PDF unwrapping, so integration work can stay narrow.
- `lib/lattice_stripe/client.ex` plus `test/lattice_stripe/client_test.exs` already prove the generic binary download transport path that `Quote.pdf/3` depends on.

### Established Patterns
- Closure phases in this repo use fresh targeted unit + integration reruns backed by a closed verifier artifact.
- `stripe-mock` integration in this repo is treated as route/encoding/decode sanity, not as a source of full business-semantic truth.
- Resource-shaped SDK surfaces should demonstrate one clear next step after a lifecycle verb, not hide orchestration inside convenience helpers.
- Planning and requirements edits in closure phases should stay scoped to the requirement family being closed.

### Integration Points
- `test/integration/quote_integration_test.exs` — expand to cover PDF, accept, cancel, and one downstream follow-through hop
- `.planning/phases/36-quote/36-VERIFICATION.md` — new closed verifier artifact to create
- `.planning/REQUIREMENTS.md` — update `QUOT-01` through `QUOT-05` rows from pending to verified when proof is current
- Optional small Quote fixture/support adjustments only if needed to make the new integration evidence truthful and executable

</code_context>

<deferred>
## Deferred Ideas

- Any broader roadmap/requirements truth reconciliation beyond Quote rows remains deferred to Phase 42.
- Any real Quote behavior defect discovered during Phase 41 verification should become follow-up work instead of hidden expansion inside this closure phase.
- Any future desire to validate richer quote lifecycle semantics against real Stripe sandboxes or test mode should be separate from this `stripe-mock`-based closure phase.
- Any project-wide GSD/process change to make “shift-left agent discretion” the default across workflows should be captured separately from Phase 41 implementation work.

</deferred>

---

*Phase: 41-quote-lifecycle-e2e-verification*
*Context gathered: 2026-05-25*
