# Phase 40: Mandate & SetupAttempt Integration Closure - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the remaining milestone verification gaps for the shipped Phase 35 authorization resources so AUTH-01 and AUTH-02 can be accepted as current, credible, and auditable.

This is a verification-closure phase, not a feature-design phase and not a general planning-truth cleanup pass. The shipped `Mandate` and `SetupAttempt` APIs, parsers, docs, and unit tests already exist. Phase 40 should add the missing Mandate integration evidence, create a closed `35-VERIFICATION.md`, and reconcile AUTH traceability without reopening the public API surface or broadening into adjacent phases.

</domain>

<decisions>
## Implementation Decisions

### Mandate integration proof shape

- **D-01:** Add a minimal shape-first `stripe-mock` integration test for `Mandate.retrieve/3` to close the explicit AUTH-01 audit gap.
- **D-02:** The Mandate integration proof should verify the real HTTP pipeline and typed top-level `%LatticeStripe.Mandate{}` decode, not attempt to prove rich business semantics or deep nested realism under `stripe-mock`.
- **D-03:** Keep parser-depth assertions such as enum atomization, nested `customer_acceptance`, expanded `payment_method`, and `extra` handling in unit tests, where they are deterministic and already established.
- **D-04:** Do not broaden Phase 40 into a combined “auth-family” integration module just for aesthetic grouping. `SetupAttempt` integration coverage already exists, and the missing gap is specifically Mandate retrieve coverage.

### Evidence scope and strictness

- **D-05:** Use fresh, targeted, phase-scoped commands as the primary proof posture for Phase 40.
- **D-06:** The verifier should prove exactly what the audit says is missing: fresh Mandate integration evidence for AUTH-01, current SetupAttempt closure evidence for AUTH-02, and a closed `35-VERIFICATION.md`.
- **D-07:** Do not require mandatory repo-wide `mix test` or `mix ci` to close this phase. Those may be included as optional supporting context only if they are already cheap and green.
- **D-08:** Do not rely on prior summaries or historical test passes alone. Fresh scoped reruns are required for verifier credibility.
- **D-09:** `stripe-mock` limitations must be stated explicitly in the verifier: it proves request routing, request encoding, and response-shape decoding sanity, not full real-Stripe lifecycle semantics.

### Allowed repair scope if verification exposes a gap

- **D-10:** Allow narrow evidence repairs only: the missing Mandate integration test, verifier artifact creation, and small fixture/test/doc alignment changes that are directly required to produce truthful AUTH proof.
- **D-11:** Do not use Phase 40 for moderate adjacent cleanup, stealth feature work, parser redesign, or public API reshaping.
- **D-12:** If verification exposes a substantive shipped-behavior defect rather than a proof gap, record it and route it to a follow-up phase or backlog item instead of expanding Phase 40 in place.

### Traceability scope and workflow posture

- **D-13:** Update the tightest required planning surface first: create `35-VERIFICATION.md` and update AUTH-01/AUTH-02 traceability in `.planning/REQUIREMENTS.md`.
- **D-14:** Purely mechanical adjacent planning fixes are allowed only when they are directly implied by the same fresh AUTH evidence and do not change the claimed scope of Phase 40.
- **D-15:** Do not fold broader neighboring planning-truth cleanup into this phase; that belongs to the existing reconciliation work already scoped later in the roadmap.
- **D-16:** Carry forward a standing workflow preference: for low- and medium-impact discuss/planning/verification decisions, GSD should default to research-backed agent recommendations and agent discretion rather than repeatedly asking the user to choose routine tradeoffs.
- **D-17:** Escalate to the user only when a decision materially affects shipped behavior, public API surface, milestone acceptance standards, phase scope, dependency footprint, or a credible user-facing / verifier-credibility risk.

### the agent's Discretion

- Exact naming and file placement of the Mandate integration test module, so long as it matches the repo’s existing integration-test conventions
- Exact targeted command set cited in `35-VERIFICATION.md`, provided it includes fresh AUTH-scoped unit and integration evidence
- Exact verifier table layout, wording, and score format, so long as the report is closed, audit-friendly, and explicit about `stripe-mock` scope
- Whether to include optional broader supporting evidence if it is already green and does not broaden the claimed closure scope

</decisions>

<specifics>
## Specific Ideas

- The coherent recommendation set is:
  - minimal Mandate route-sanity integration proof
  - fresh targeted AUTH-scoped reruns
  - narrow evidence-repair allowance only
  - tight AUTH traceability updates
  - shift routine workflow choices left to the agent unless they are genuinely high-impact
- This best matches the project’s Elixir-first and least-surprise posture: targeted tests, explicit proof, low magic, and no fake confidence from stale paperwork or mock-driven overclaims.
- The main footguns to avoid are:
  - writing `35-VERIFICATION.md` without fresh Mandate integration evidence
  - pretending `stripe-mock` proves more than transport and decode sanity
  - broadening a closure phase into a hidden feature or planning-reconciliation phase
  - re-asking the user about routine verifier and planning mechanics after they explicitly asked for cohesive defaults

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone context
- `.planning/ROADMAP.md` — Phase 40 goal, gap-closure framing, and success criteria
- `.planning/REQUIREMENTS.md` — AUTH-01 and AUTH-02 requirement rows plus current traceability state
- `.planning/PROJECT.md` — SDK philosophy: narrow Stripe-shaped surfaces, least surprise, explicit API semantics, and high DX
- `.planning/STATE.md` — current milestone position and readiness to plan Phase 40
- `.planning/v1.3-v1.3-MILESTONE-AUDIT.md` — explicit audit gap: missing `35-VERIFICATION.md` and missing Mandate integration coverage

### Prior phase artifacts that define the shipped behavior
- `.planning/phases/35-mandate-setupattempt/35-CONTEXT.md` — locked Mandate and SetupAttempt design decisions from the original feature phase
- `.planning/phases/35-mandate-setupattempt/35-RESEARCH.md` — implementation research and Stripe-surface constraints
- `.planning/phases/35-mandate-setupattempt/35-VALIDATION.md` — original validation contract and proof expectations
- `.planning/phases/35-mandate-setupattempt/35-PATTERNS.md` — closest analogs for resource and test structure
- `.planning/phases/35-mandate-setupattempt/35-01-SUMMARY.md` — parser/object-registration/fixture completion evidence
- `.planning/phases/35-mandate-setupattempt/35-02-SUMMARY.md` — public API and test completion evidence

### Verification-closure precedents
- `.planning/phases/38-dispute-evidence-e2e-verification/38-RESEARCH.md` — closure-phase framing for evidence work versus feature work
- `.planning/phases/38-dispute-evidence-e2e-verification/38-VALIDATION.md` — scoped validation posture for closure phases
- `.planning/phases/39-credit-note-verification-closure/39-CONTEXT.md` — narrow proof-repair stance and shift-left process preference precedent
- `.planning/phases/39-credit-note-verification-closure/39-VERIFICATION.md` — current verifier style for a neighboring closure phase
- `.planning/phases/33-disputes/33-VERIFICATION.md` — closed verifier example with current requirement-table and artifact-verification posture

### Existing code and test surfaces
- `lib/lattice_stripe/mandate.ex` — shipped retrieve-only Mandate API and docs
- `lib/lattice_stripe/setup_attempt.ex` — shipped list-only SetupAttempt API and local required-filter validation
- `test/lattice_stripe/mandate_test.exs` — current unit coverage for request shape, parser behavior, and docs
- `test/lattice_stripe/setup_attempt_test.exs` — current unit coverage for AUTH-02 behavior
- `test/integration/setup_attempt_integration_test.exs` — existing integration proof for AUTH-02
- `test/integration/account_integration_test.exs` — integration style precedent for retrieve-only Stripe resource route sanity
- `test/support/fixtures/mandate.ex` — canonical Mandate fixture payloads available for proof-supporting assertions

### Local research corpus
- `prompts/elixir-best-practices-deep-research.md` — targeted tests, explicit return shapes, assertive boundaries
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — Elixir OSS library UX, configurability, and maintenance posture
- `prompts/phoenix-best-practices-deep-research.md` — focused-patch and interface-boundary discipline relevant to contributor ergonomics
- `prompts/stripe-sdk-api-surface-area-deep-research.md` — Stripe SDK verification and surface-area tradeoffs
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — where Stripe SDKs should invest polish and proof credibility
- `prompts/payments_domain_field_guide.md` — payments semantics, lifecycle vocabulary, and testing caveats

### External ecosystem references
- `https://hexdocs.pm/mix/Mix.Tasks.Test.html` — targeted ExUnit/Mix verification flows
- `https://hexdocs.pm/ex_unit/main/ExUnit.html` — ExUnit structure and narrow test-run ergonomics
- `https://raw.githubusercontent.com/elixir-lang/elixir/main/CONTRIBUTING.md` — focused test-loop and patch-discipline precedent
- `https://raw.githubusercontent.com/phoenixframework/phoenix/main/CONTRIBUTING.md` — focused-scope PR and verification expectations
- `https://github.com/elixir-ecto/ecto` — split between focused tests and heavier integration workflows
- `https://github.com/stripe/stripe-mock` — explicit limits of `stripe-mock` as a sanity-check tool
- `https://docs.stripe.com/testing-use-cases` — Stripe testing guidance and limits of mock/sandbox evidence
- `https://docs.stripe.com/api/mandates/retrieve` — authoritative Mandate retrieve endpoint
- `https://github.com/stripe/stripe-ruby` — Stripe SDK maintenance and targeted test posture
- `https://hexdocs.pm/stripity_stripe/Stripe.Mandate.html` — closest Elixir ecosystem precedent for low-level Mandate surface
- `https://hexdocs.pm/stripity_stripe/Stripe.SetupAttempt.html` — closest Elixir ecosystem precedent for low-level SetupAttempt surface

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/integration/setup_attempt_integration_test.exs` already provides the exact style and setup pattern for a narrow AUTH integration proof under `stripe-mock`.
- `test/integration/account_integration_test.exs` provides the closest retrieve-only resource integration precedent, including shape-first assertions and explicit `stripe-mock` caveats.
- `test/lattice_stripe/mandate_test.exs` already covers parser-depth concerns that should not be duplicated in brittle integration assertions.
- `test/support/fixtures/mandate.ex` already provides canonical Mandate payload helpers for any proof-supporting unit or verifier references.

### Established Patterns
- Verification-closure phases in this repo create fresh verifier artifacts backed by fresh scoped commands rather than historical summaries alone.
- Integration tests in this repo use `stripe-mock` for route, encoding, and response-shape sanity, while documenting statelessness and semantic limits explicitly.
- Read-only Stripe resource integrations prefer narrow retrieve/list smoke coverage instead of elaborate mock-driven lifecycle theater.
- Planning-traceability updates in closure phases should stay scoped to the requirement family actually being closed.

### Integration Points
- `test/integration/mandate_integration_test.exs` or a similarly named module — the new Mandate integration proof surface this phase is expected to add
- `.planning/phases/35-mandate-setupattempt/35-VERIFICATION.md` — new verifier artifact to create and close
- `.planning/REQUIREMENTS.md` — AUTH-01 and AUTH-02 rows should be updated from pending to verified
- Optional: a small closure summary inside the Phase 40 directory if the planner wants parity with neighboring closure phases

</code_context>

<deferred>
## Deferred Ideas

- Broad planning-truth reconciliation for neighboring v1.3 phases remains deferred to the later roadmap work already scoped for that purpose.
- Any substantive AUTH behavior bug discovered during Phase 40 verification should become a follow-up phase or backlog item rather than hidden expansion here.
- Project-wide workflow implementation of the shift-left preference may be captured in future GSD/process artifacts, but should not be used to broaden the execution scope of Phase 40 itself.

</deferred>

---

*Phase: 40-mandate-setupattempt-integration-closure*
*Context gathered: 2026-05-25*
