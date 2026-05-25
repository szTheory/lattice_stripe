# Phase 42: Planning Truth Reconciliation - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Align the v1.3 planning surface with repo reality so downstream planning, milestone audit, and future contributors can trust the roadmap, requirements, state, and verifier story without reverse-engineering recent closure work.

This phase is a planning-truth and mechanical-closure phase. It may package and reconcile already-shipped evidence where the roadmap explicitly requires that packaging, but it must not reopen SDK behavior, invent external proof, or blur the line between closed verifier truth and still-pending real-authority proof.

</domain>

<decisions>
## Implementation Decisions

### Status truth model

- **D-01:** Use a **layered evidence model**, not a binary “done or not” model and not a claims-first roadmap model. Planning artifacts must distinguish shipped capability, locally bounded proof, closed verifier truth, and environment-blocked proof instead of flattening them into one status word.
- **D-02:** Reserve top-level phase `Complete` semantics for phases whose **authoritative phase truth is actually closed** for the purpose that artifact is representing. Do not use `Complete` as shorthand for “implementation landed at some point” when the real state is still open or externally blocked.
- **D-03:** Treat `pending-external-verification` as a first-class truthful state for environment-bound follow-through work. Do not hide that state behind `Not started`, `Complete`, or caveat-heavy footnotes.
- **D-04:** In `REQUIREMENTS.md`, keep the two layers conceptually separate:
  - checklist rows represent whether the capability is present in repo truth
  - traceability/status rows represent whether the requirement family has milestone-ready verification closure
- **D-05:** Avoid vocabulary sprawl. Reuse the repo’s existing strong terms where possible:
  - verifier frontmatter: `closed` or `pending-external-verification`
  - traceability rows: `Verified` when closure is real; explicit pending wording when closure is intentionally still open
  - roadmap status column: plain-language lifecycle states that match actual phase reality
- **D-06:** Do not resurrect vague states like `human_needed` when the real issue is narrower. Prefer explicit blocker language that names the actual authority gap.

### Phase 42 scope boundary

- **D-07:** Scope Phase 42 as **planning-plus-mechanical-closure**, not strict paperwork-only reconciliation and not a broad cleanup phase.
- **D-08:** Phase 42 is allowed to create and close `37-VERIFICATION.md` if that closure is based on already-shipped Phase 37 work plus fresh, narrowly scoped docs/truth checks needed to package the evidence honestly.
- **D-09:** Phase 42 is allowed to reconcile `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and `.planning/v1.3-v1.3-MILESTONE-AUDIT.md` so they reflect the real execution state of phases 35-37 and the already-existing closure outcomes of phases 40 and 41.1.
- **D-10:** Phase 42 must stay out of product/runtime work. No new SDK behavior, no new Stripe resource coverage, no parser redesign, no opportunistic DX feature expansion, and no Accrue-shaped workflow abstraction belongs here.
- **D-11:** Phase 42 must not fake closure for environment-dependent proof. In particular, it must not convert Phase `41.1` from `pending-external-verification` to closed unless fresh external proof is actually produced in the proper environment.
- **D-12:** Closure phases do not automatically require a second-order self-verifier artifact. If a closure phase’s own deliverable was to create/update another phase’s verifier and that deliverable is already truthfully summarized, Phase 42 may reconcile top-level roadmap state without inventing recursive “verification of the verification phase” theater.

### Audit closure target

- **D-13:** Target a **repo-truth audit pass**, not a hard-everything-closed milestone gate and not an optimistic “close enough” pass.
- **D-14:** The rerun audit should pass once planning artifacts no longer make stale or inaccurate claims, even if one explicitly named environment-proof follow-up remains open in Phase `41.1`.
- **D-15:** The audit result should say, in substance: planning truth now matches repo reality; one external-proof item remains open; that open item is an environment-verification gap, not an unimplemented SDK-surface gap.
- **D-16:** Do not reopen already-verified requirement families just because a separate follow-up phase still exists. `QUOT-01` through `QUOT-05` remain verified under the bounded Phase 41 closure; Phase `41.1` is a separate downstream follow-through proof track.

### Decision posture for downstream agents

- **D-17:** Carry forward the user’s standing preference: routine discuss/planning/verification/reconciliation tradeoffs should default to cohesive agent recommendations and agent discretion.
- **D-18:** Escalate only when a decision would materially affect shipped SDK behavior, public API surface, milestone semantics, dependency footprint, or the credibility of a verifier/audit claim.

### the agent's Discretion

- Exact naming of any new audit verdict or summary wording, as long as it preserves the repo-truth vs external-proof distinction.
- Exact table wording and row formatting in `ROADMAP.md`, `REQUIREMENTS.md`, and audit docs, as long as the layered-truth model stays intact.
- Whether `STATE.md` records Phase 42 as a reconciliation pass against phases 35-37 specifically or as a broader v1.3 planning-truth update, as long as it does not imply extra runtime work happened.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone context
- `.planning/ROADMAP.md` — Phase 42 goal, success criteria, and the currently stale progress rows that this phase must reconcile
- `.planning/REQUIREMENTS.md` — DX, AUTH, and QUOT requirement truth layers plus current checklist/traceability mismatch
- `.planning/PROJECT.md` — repo philosophy: explicitness, least surprise, truthful boundaries, and SDK-vs-Accrue scope discipline
- `.planning/STATE.md` — current milestone state and the already-carried concern about public/planning truth drift
- `.planning/v1.3-v1.3-MILESTONE-AUDIT.md` — exact planning-truth gaps that Phase 42 is closing

### Prior phase artifacts that define the current truth
- `.planning/phases/37-dx-polish/37-CONTEXT.md` — locked DX-phase scope and documentation-truth decisions
- `.planning/phases/37-dx-polish/37-VALIDATION.md` — expected verification contract for the DX work that still lacks packaged verifier closure
- `.planning/phases/37-dx-polish/37-01-SUMMARY.md` — fixture-builder work completed in Phase 37
- `.planning/phases/37-dx-polish/37-02-SUMMARY.md` — webhook/testing/recipes docs work completed in Phase 37
- `.planning/phases/37-dx-polish/37-03-SUMMARY.md` — docs-truth/version-story work completed in Phase 37
- `.planning/phases/35-mandate-setupattempt/35-VERIFICATION.md` — concrete example of a closed verifier created later by a closure phase
- `.planning/phases/36-quote/36-VERIFICATION.md` — closed verifier that explicitly bounds local mock truth and hands off the remaining downstream proof
- `.planning/phases/40-mandate-setupattempt-integration-closure/40-CONTEXT.md` — neighboring closure-phase scope discipline and shift-left preference precedent
- `.planning/phases/40-mandate-setupattempt-integration-closure/40-02-SUMMARY.md` — evidence that Phase 40 already closed the AUTH family without broad roadmap cleanup
- `.planning/phases/41-quote-lifecycle-e2e-verification/41-CONTEXT.md` — bounded Quote closure posture and explicit deferral of broader planning-truth cleanup to Phase 42
- `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-CONTEXT.md` — explicit separation of the downstream external-proof follow-up from planning-truth work
- `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md` — honest `pending-external-verification` artifact that must remain truthful
- `.planning/threads/lattice-stripe-vs-accrue-scope-boundary.md` — prevent reconciliation work from drifting into higher-level product/system redesign

### Prompt corpus that should shape recommendations
- `prompts/elixir-best-practices-deep-research.md` — explicit APIs, stable semantics, assertive truth, and low-magic Elixir library posture
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — OSS library ergonomics, focused public surface, and release/docs hygiene
- `prompts/phoenix-best-practices-deep-research.md` — focused-scope changes, clear boundaries, and compile-time-truth bias in the ecosystem
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — user-trust and high-leverage workflow emphasis for a Stripe SDK
- `prompts/stripe-sdk-api-surface-area-deep-research.md` — truth around local vs external Stripe proof, versioning, and realistic testing boundaries
- `prompts/payments_domain_field_guide.md` — “truth comes from the real authority” framing for asynchronous payment/workflow behavior

### External ecosystem references
- `https://docs.stripe.com/testing-use-cases` — Stripe sandbox guidance and the distinction between simulated and real-authority proof
- `https://docs.stripe.com/api/quotes/accept` — Quote accept contract that still claims downstream object creation, which is why Phase 41.1 must remain honest about missing external proof
- `https://raw.githubusercontent.com/phoenixframework/phoenix/main/CONTRIBUTING.md` — focused-scope patch discipline and example/testing guidance
- `https://raw.githubusercontent.com/elixir-lang/elixir/main/CONTRIBUTING.md` — targeted test loops, full-suite confirmation, and evidence-oriented contribution norms
- `https://raw.githubusercontent.com/elixir-ecto/ecto/master/README.md` — stable-version/support messaging pattern from a mature Elixir OSS library

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Closed verifier artifacts already exist for the underlying feature phases that Phase 42 must represent truthfully: `33-VERIFICATION.md`, `34-VERIFICATION.md`, `35-VERIFICATION.md`, and `36-VERIFICATION.md`.
- Phase 37 already produced the docs-truth enforcement asset that a mechanical verifier can lean on: `test/lattice_stripe/docs_truth_test.exs`.
- The repo already has strong neighboring closure-phase examples for structure and wording: `39-VERIFICATION.md` and `41.1-VERIFICATION.md`.

### Established Patterns
- This repo uses verifier artifacts as the authoritative closure boundary for shipped requirement families.
- Closure phases are intentionally narrow: they package fresh scoped evidence and update traceability without reopening feature design.
- Honest mock/sandbox boundaries are already a norm here: local proof is closed where justified, and external-proof gaps are called out explicitly instead of buried.
- Requirement traceability uses `Verified` rows today; that vocabulary should remain the default unless a narrower explicit pending status is truly necessary.

### Integration Points
- `.planning/phases/42-planning-truth-reconciliation/42-*` — new context, discussion log, and later plan/summaries
- `.planning/phases/37-dx-polish/37-VERIFICATION.md` — likely new verifier artifact to create during execution
- `.planning/ROADMAP.md` — progress table and per-phase metadata reconciliation
- `.planning/REQUIREMENTS.md` — DX checklist and traceability reconciliation under the layered-truth model
- `.planning/STATE.md` — state/session truth update after reconciliation
- `.planning/v1.3-v1.3-MILESTONE-AUDIT.md` — rerun or rewrite to reflect planning-truth pass semantics

</code_context>

<specifics>
## Specific Ideas

- Treat planning truth the same way the repo treats webhook or downstream payment truth: top-level artifacts should reflect the most authoritative state available, not the neatest-looking story.
- The coherent recommendation set is:
  - layered evidence model
  - narrow planning-plus-mechanical-closure scope
  - repo-truth audit pass with explicit open external-proof note
  - decisive agent-side defaults for routine reconciliation choices
- The user’s explicit workflow preference should be preserved here and, where practical, shifted left in GSD generally:
  - prefer one-shot coherent recommendations
  - surface only very impactful forks
  - keep routine planning/verification semantics on agent discretion
- Closure-phase artifacts should stay honest and non-recursive. Creating “verification for the verification phase” should not become default ceremony unless the roadmap explicitly requires it.

</specifics>

<deferred>
## Deferred Ideas

- Broader GSD-wide harmonization of planning-status vocabulary and discuss/plan default escalation thresholds belongs in workflow/process work, not in the execution scope of Phase 42 itself.
- Any real Stripe sandbox run needed to close Phase `41.1` remains separate from planning-truth reconciliation.
- Any future desire to formalize a project-wide audit verdict taxonomy beyond this milestone should be handled as process/tooling follow-up rather than hidden inside the immediate v1.3 cleanup.

</deferred>

---

*Phase: 42-planning-truth-reconciliation*
*Context gathered: 2026-05-25*
