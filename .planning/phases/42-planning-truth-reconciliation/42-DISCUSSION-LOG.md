# Phase 42: Planning Truth Reconciliation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `42-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-05-25
**Phase:** 42-planning-truth-reconciliation
**Mode:** discuss all + research-first synthesis
**Areas discussed:** status truth model, Phase 42 scope boundary, audit closure target

---

## Inputs considered

### Local planning artifacts

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/PROJECT.md`
- `.planning/STATE.md`
- `.planning/v1.3-v1.3-MILESTONE-AUDIT.md`
- `.planning/phases/37-dx-polish/37-CONTEXT.md`
- `.planning/phases/37-dx-polish/37-VALIDATION.md`
- `.planning/phases/37-dx-polish/37-03-SUMMARY.md`
- `.planning/phases/35-mandate-setupattempt/35-VERIFICATION.md`
- `.planning/phases/36-quote/36-VERIFICATION.md`
- `.planning/phases/39-credit-note-verification-closure/39-VERIFICATION.md`
- `.planning/phases/40-mandate-setupattempt-integration-closure/40-CONTEXT.md`
- `.planning/phases/40-mandate-setupattempt-integration-closure/40-02-SUMMARY.md`
- `.planning/phases/41-quote-lifecycle-e2e-verification/41-CONTEXT.md`
- `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-CONTEXT.md`
- `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md`
- `.planning/threads/lattice-stripe-vs-accrue-scope-boundary.md`

### Prompt corpus consulted

- `prompts/elixir-best-practices-deep-research.md`
- `prompts/elixir-opensource-libs-best-practices-deep-research.md`
- `prompts/phoenix-best-practices-deep-research.md`
- `prompts/stripe-lib-priority-user-flows-deep-research.md`
- `prompts/stripe-sdk-api-surface-area-deep-research.md`
- `prompts/payments_domain_field_guide.md`

### External references consulted

- Stripe testing use-cases docs
- Stripe Quote accept API docs
- Phoenix contributing guide
- Elixir contributing guide
- Ecto README

### Parallel research threads

- `Status truth model` — pros/cons of binary closure-only vs layered evidence vs claims-first roadmap truth
- `Phase 42 scope boundary` — pros/cons of paperwork-only vs planning-plus-mechanical-closure vs broad cleanup
- `Audit closure target` — pros/cons of hard-pass vs repo-truth pass vs optimistic closure

## Status truth model

| Option | Description | Selected |
|--------|-------------|----------|
| Binary closure-only model | Top-level `Complete` means one thing: fully closed verifier truth | |
| Layered evidence model | Distinguish shipped capability, closed verifier truth, and external-proof blockers explicitly | ✓ |
| Claims-first / notes-second model | Mark shipped work complete at top level and push nuance into deeper docs | |

**User's choice:** Layered evidence model
**Notes:** This best matches the repo’s existing truthful-authority posture. It preserves least surprise better than claims-first bookkeeping and avoids the false “not done” semantics of a pure binary model for already-shipped work. Canonical statuses should stay small and disciplined: use explicit pending-external language where needed rather than vague human-needed states.

---

## Phase 42 Scope Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Strict paperwork-only reconciliation | Update roadmap/requirements/state/audit docs only | |
| Planning-plus-mechanical-closure reconciliation | Reconcile planning artifacts and package missing verifier closure when already-shipped evidence exists | ✓ |
| Broad cleanup phase | Absorb adjacent verification/doc/code cleanup until the audit stops complaining | |

**User's choice:** Planning-plus-mechanical-closure reconciliation
**Notes:** This is the strongest fit for Phase 42’s roadmap goal and for mature Elixir OSS patch discipline. It allows truthful packaging of `37-VERIFICATION.md` and top-level reconciliation without reopening SDK behavior or inventing sandbox proof. It also preserves the repo’s prior closure-phase boundaries and avoids hidden scope creep.

---

## Audit Closure Target

| Option | Description | Selected |
|--------|-------------|----------|
| Hard-pass target | Milestone cannot pass until every proof, including external follow-through, is fully closed | |
| Repo-truth target | Audit passes once planning artifacts are truthful and any remaining external-proof item is explicitly open | ✓ |
| Optimistic closure target | Treat the milestone as effectively closed and bury the external-proof nuance in caveats | |

**User's choice:** Repo-truth target
**Notes:** This keeps the audit honest without letting a single environment-bound proof hold the entire planning surface hostage. Phase `41.1` should remain visibly `pending-external-verification`; the audit may pass only in the narrower sense that no stale or inaccurate planning claims remain.

---

## Synthesized Final Recommendations

1. Adopt a layered evidence model across planning artifacts.
2. Scope Phase 42 as planning-plus-mechanical-closure.
3. Package and close `37-VERIFICATION.md` only from already-shipped evidence plus fresh narrow truth checks.
4. Reconcile roadmap and requirements so `Complete` and `Verified` mean what they currently imply.
5. Keep Phase `41.1` explicitly open as `pending-external-verification`.
6. Let the milestone audit pass on planning truth only if it explicitly names the remaining external-proof gap instead of hiding it.

## the agent's Discretion

- Exact wording of the layered statuses in roadmap/audit docs
- Exact audit verdict label, as long as it preserves the repo-truth distinction
- Exact phrasing for closure-phase semantics so the repo does not drift into recursive verification ceremony

## Deferred Ideas

- Shift this “agent decides routine tradeoffs” preference left across GSD more broadly, not just inside Phase 42.
- Standardize the planning/audit status taxonomy across all GSD workflows in a dedicated process/tooling follow-up.

---

*Decision log written: 2026-05-25*
