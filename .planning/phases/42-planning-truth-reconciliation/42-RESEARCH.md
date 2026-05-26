# Phase 42: Planning Truth Reconciliation - Research

**Researched:** 2026-05-25 [VERIFIED: command output]  
**Domain:** planning-truth reconciliation for repo-local roadmap, requirements, verifier, state, and milestone-audit artifacts [VERIFIED: file read]  
**Confidence:** HIGH [VERIFIED: file read + command output]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Status truth model

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

#### Phase 42 scope boundary

- **D-07:** Scope Phase 42 as **planning-plus-mechanical-closure**, not strict paperwork-only reconciliation and not a broad cleanup phase.
- **D-08:** Phase 42 is allowed to create and close `37-VERIFICATION.md` if that closure is based on already-shipped Phase 37 work plus fresh, narrowly scoped docs/truth checks needed to package the evidence honestly.
- **D-09:** Phase 42 is allowed to reconcile `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and `.planning/v1.3-v1.3-MILESTONE-AUDIT.md` so they reflect the real execution state of phases 35-37 and the already-existing closure outcomes of phases 40 and 41.1.
- **D-10:** Phase 42 must stay out of product/runtime work. No new SDK behavior, no new Stripe resource coverage, no parser redesign, no opportunistic DX feature expansion, and no Accrue-shaped workflow abstraction belongs here.
- **D-11:** Phase 42 must not fake closure for environment-dependent proof. In particular, it must not convert Phase `41.1` from `pending-external-verification` to closed unless fresh external proof is actually produced in the proper environment.
- **D-12:** Closure phases do not automatically require a second-order self-verifier artifact. If a closure phase’s own deliverable was to create/update another phase’s verifier and that deliverable is already truthfully summarized, Phase 42 may reconcile top-level roadmap state without inventing recursive “verification of the verification phase” theater.

#### Audit closure target

- **D-13:** Target a **repo-truth audit pass**, not a hard-everything-closed milestone gate and not an optimistic “close enough” pass.
- **D-14:** The rerun audit should pass once planning artifacts no longer make stale or inaccurate claims, even if one explicitly named environment-proof follow-up remains open in Phase `41.1`.
- **D-15:** The audit result should say, in substance: planning truth now matches repo reality; one external-proof item remains open; that open item is an environment-verification gap, not an unimplemented SDK-surface gap.
- **D-16:** Do not reopen already-verified requirement families just because a separate follow-up phase still exists. `QUOT-01` through `QUOT-05` remain verified under the bounded Phase 41 closure; Phase `41.1` is a separate downstream follow-through proof track.

#### Decision posture for downstream agents

- **D-17:** Carry forward the user’s standing preference: routine discuss/planning/verification/reconciliation tradeoffs should default to cohesive agent recommendations and agent discretion.
- **D-18:** Escalate only when a decision would materially affect shipped SDK behavior, public API surface, milestone semantics, dependency footprint, or the credibility of a verifier/audit claim.

### Claude's Discretion

- Exact naming of any new audit verdict or summary wording, as long as it preserves the repo-truth vs external-proof distinction.
- Exact table wording and row formatting in `ROADMAP.md`, `REQUIREMENTS.md`, and audit docs, as long as the layered-truth model stays intact.
- Whether `STATE.md` records Phase 42 as a reconciliation pass against phases 35-37 specifically or as a broader v1.3 planning-truth update, as long as it does not imply extra runtime work happened.

### Deferred Ideas (OUT OF SCOPE)

- Broader GSD-wide harmonization of planning-status vocabulary and discuss/plan default escalation thresholds belongs in workflow/process work, not in the execution scope of Phase 42 itself.
- Any real Stripe sandbox run needed to close Phase `41.1` remains separate from planning-truth reconciliation.
- Any future desire to formalize a project-wide audit verdict taxonomy beyond this milestone should be handled as process/tooling follow-up rather than hidden inside the immediate v1.3 cleanup.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DX-01 | Webhooks guide includes copy-paste Phoenix router + handler recipe [VERIFIED: `.planning/REQUIREMENTS.md`] | Close `37-VERIFICATION.md` using `37-02-SUMMARY.md`, `guides/webhooks.md`, and targeted grep/docs evidence; do not add new webhook behavior [VERIFIED: file read + codebase grep] |
| DX-02 | `LatticeStripe.Testing` exposes fixture builders for all v1.3 resource families [VERIFIED: `.planning/REQUIREMENTS.md`] | Use `37-01-SUMMARY.md`, `test/lattice_stripe/testing_test.exs`, and current green targeted test output as the closure anchor [VERIFIED: file read + command output] |
| DX-03 | `guides/recipes.md` provides end-to-end patterns for common workflows [VERIFIED: `.planning/REQUIREMENTS.md`] | Use `37-02-SUMMARY.md`, `guides/recipes.md`, and docs-truth checks; keep recipes library-scoped [VERIFIED: file read + codebase grep] |
| DX-04 | All guides have consistent version refs, cross-links, and current examples [VERIFIED: `.planning/REQUIREMENTS.md`] | Use `37-03-SUMMARY.md`, `test/lattice_stripe/docs_truth_test.exs`, and README/`mix.exs` version-story evidence; keep `1.3.0-dev` vs published `1.2.x` distinction intact [VERIFIED: file read + command output] |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Use Elixir `~> 1.15` semantics and stay compatible with the repo’s current local toolchain, which is Elixir 1.19.5 / Mix 1.19.5 on OTP 28 in this workspace [CITED: `CLAUDE.md`; VERIFIED: command output].  
- Do not add Dialyzer work; the project explicitly excludes it [CITED: `CLAUDE.md`].  
- Keep dependencies minimal and avoid unnecessary new tooling; this phase can use the existing Mix, ExUnit, docs, and planning-doc stack only [CITED: `CLAUDE.md`; VERIFIED: file read].  
- Stay inside the existing GSD workflow and treat planning artifacts as first-class deliverables rather than ad hoc edits [CITED: `CLAUDE.md`].  

## Summary

Phase 42 is a documentation-and-verifier reconciliation phase, not a product phase. The missing work is to package already-shipped DX evidence into a closed `37-VERIFICATION.md`, then propagate that truth into `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and the milestone audit without overstating the still-open external proof owned by Phase `41.1` [VERIFIED: `42-CONTEXT.md`; VERIFIED: `37-01-SUMMARY.md`; VERIFIED: `37-02-SUMMARY.md`; VERIFIED: `37-03-SUMMARY.md`; VERIFIED: `41.1-VERIFICATION.md`].

The repo’s authoritative pattern is already established: feature or closure truth becomes milestone truth only after a verifier artifact exists in the right state, and adjacent closure phases update only the requirement family they own. Phase 42 should reuse that pattern for DX, then do one narrow planning-surface sync pass rather than inventing new status words or reopening runtime scope [VERIFIED: `35-VERIFICATION.md`; VERIFIED: `36-VERIFICATION.md`; VERIFIED: `39-VERIFICATION.md`; VERIFIED: `40-02-SUMMARY.md`; VERIFIED: `41-02-SUMMARY.md`].

`mix test test/lattice_stripe/testing_test.exs test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` is currently green, while `mix docs --warnings-as-errors` is still red due pre-existing warnings outside Phase 42 scope. The planner should therefore rely on targeted DX checks plus explicit grep-backed artifact assertions, and treat repo-wide docs-cleanliness as pre-existing debt unless the phase explicitly chooses to absorb it [VERIFIED: command output].

**Primary recommendation:** Create a closed `37-VERIFICATION.md` first, then propagate its truth outward in one family-scoped reconciliation pass that leaves Phase `41.1` explicitly `pending-external-verification` [VERIFIED: file read + command output].

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Package DX closure truth into `37-VERIFICATION.md` | Repository / Planning Artifacts [VERIFIED: file read] | Test Evidence [VERIFIED: file read] | The missing truth is documentary closure over already-shipped work, and the evidence comes from existing tests/summaries rather than new runtime code [VERIFIED: `42-CONTEXT.md`; VERIFIED: `37-VALIDATION.md`] |
| Reconcile DX checklist and traceability rows | Repository / Planning Artifacts [VERIFIED: file read] | Verifier Artifacts [VERIFIED: file read] | `REQUIREMENTS.md` is downstream of verifier truth, not peer to it [VERIFIED: `40-02-SUMMARY.md`; VERIFIED: `41-02-SUMMARY.md`] |
| Reconcile roadmap phase states and plan counts for phases 35-37 | Repository / Planning Artifacts [VERIFIED: file read] | Phase Summaries [VERIFIED: file read] | `ROADMAP.md` is stale today and must be updated to match actual execution artifacts already present in the repo [VERIFIED: `.planning/ROADMAP.md`; VERIFIED: codebase grep] |
| Preserve the open external-proof boundary for Phase `41.1` | Repository / Planning Artifacts [VERIFIED: file read] | External Verification Track [VERIFIED: file read] | The roadmap and audit must show that the remaining gap is environmental, not code-level [VERIFIED: `41.1-VERIFICATION.md`; VERIFIED: `42-CONTEXT.md`] |
| Refresh milestone-audit verdict | Repository / Planning Artifacts [VERIFIED: file read] | Verifier Artifacts [VERIFIED: file read] | The audit consumes repo truth from roadmap, requirements, and verifier files, so it should be updated last [VERIFIED: `.planning/v1.3-v1.3-MILESTONE-AUDIT.md`; VERIFIED: `42-CONTEXT.md`] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phase verifier artifact pattern (`*-VERIFICATION.md`) | repo-local current [VERIFIED: codebase grep] | authoritative closure source for a requirement family or feature phase [VERIFIED: file read] | Adjacent phases 35, 36, and 39 already treat verifier state as the source of milestone truth [VERIFIED: `35-VERIFICATION.md`; VERIFIED: `36-VERIFICATION.md`; VERIFIED: `39-VERIFICATION.md`] |
| `REQUIREMENTS.md` + `ROADMAP.md` reconciliation | repo-local current [VERIFIED: file read] | propagated planning truth layer [VERIFIED: file read] | Adjacent closure phases update these artifacts only after verifier closure and keep edits family-scoped [VERIFIED: `40-02-SUMMARY.md`; VERIFIED: `41-02-SUMMARY.md`] |
| ExUnit via Mix | Elixir 1.19.5 / Mix 1.19.5 [VERIFIED: command output] | targeted regression proof for fixture and docs-truth surfaces [VERIFIED: command output] | The DX phase already has focused tests that pass today and can be rerun quickly during reconciliation [VERIFIED: `37-VALIDATION.md`; VERIFIED: command output] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `rg` | 15.1.0 [VERIFIED: command output] | assert status words, requirement rows, and verifier anchors quickly [VERIFIED: file read] | Use for deterministic artifact checks before and after each planning-doc edit [VERIFIED: adjacent plan summaries + codebase grep] |
| `mix docs --warnings-as-errors` | ExDoc via existing repo alias [VERIFIED: `mix.exs`] | repo-wide docs build verification [VERIFIED: file read] | Use only as an informative signal unless the phase deliberately absorbs pre-existing docs warnings; it is currently red for unrelated warnings [VERIFIED: command output] |
| `.planning/v1.3-v1.3-MILESTONE-AUDIT.md` | repo-local current [VERIFIED: file read] | final planning-truth verdict artifact [VERIFIED: file read] | Update last, after verifier and planning-surface rows are reconciled [VERIFIED: `42-CONTEXT.md`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| closed `37-VERIFICATION.md` as the DX truth anchor [VERIFIED: `42-CONTEXT.md`] | update `ROADMAP.md` and `REQUIREMENTS.md` directly from summaries [VERIFIED: file read] | Faster, but it breaks the repo’s verifier-first truth model and makes the audit less credible [VERIFIED: `35-VERIFICATION.md`; VERIFIED: `39-VERIFICATION.md`; VERIFIED: `41-02-SUMMARY.md`] |
| explicit `pending-external-verification` for Phase `41.1` [VERIFIED: `41.1-VERIFICATION.md`] | mark `41.1` complete with a caveat [VERIFIED: file read] | Shorter wording, but directly violates D-03 and D-11 and hides the real authority gap [VERIFIED: `42-CONTEXT.md`] |
| targeted DX tests plus grep-backed planning assertions [VERIFIED: command output + codebase grep] | require `mix ci` or `mix docs --warnings-as-errors` to go fully green inside Phase 42 [VERIFIED: `mix.exs`; VERIFIED: command output] | Broader, but drags unrelated docs-warning debt into a reconciliation phase that is supposed to stay narrow [VERIFIED: command output] |

**Installation:**
```bash
# No additional packages. Use the existing repo toolchain.
```

**Version verification:** Local tool versions were verified on 2026-05-25 with `elixir --version`, `mix --version`, `rg --version`, and `node --version` [VERIFIED: command output].

## Architecture Patterns

### System Architecture Diagram

```text
Phase 37 summaries + DX tests
        |
        v
Fresh scoped DX checks -----> 37-VERIFICATION.md (status: closed)
        |                               |
        |                               v
        +----------------------> REQUIREMENTS.md (DX checklist + traceability)
                                        |
                                        v
ROADMAP.md (phases 35-37, 40, 41, 41.1, 42 status/progress)
                                        |
                                        v
STATE.md (current milestone focus / planning-truth note)
                                        |
                                        v
.planning/v1.3-v1.3-MILESTONE-AUDIT.md (repo-truth pass, explicit open external-proof note)
```

All arrows are one-way status propagation from evidence to verifier to planning surface; Phase `41.1` remains a separate input that contributes an explicit open-boundary note rather than a closure signal [VERIFIED: `41.1-VERIFICATION.md`; VERIFIED: `42-CONTEXT.md`].

### Recommended Project Structure

```text
.planning/
├── phases/37-dx-polish/37-VERIFICATION.md          # new closed DX verifier [VERIFIED: missing file + phase context]
├── ROADMAP.md                                      # phase states, plan counts, progress rows [VERIFIED: file read]
├── REQUIREMENTS.md                                 # DX checklist + traceability rows [VERIFIED: file read]
├── STATE.md                                        # milestone-focus and progress snapshot [VERIFIED: file read]
└── v1.3-v1.3-MILESTONE-AUDIT.md                    # refreshed planning-truth verdict [VERIFIED: file read]
```

### Pattern 1: Verifier-First Reconciliation

**What:** Create or close the phase verifier before editing propagated truth surfaces [VERIFIED: adjacent closure artifacts].  
**When to use:** Any time summaries exist but the audit still flags missing or stale closure state [VERIFIED: `.planning/v1.3-v1.3-MILESTONE-AUDIT.md`].  
**Example:**
```yaml
# Source: .planning/phases/35-mandate-setupattempt/35-VERIFICATION.md
phase: 35-mandate-setupattempt
verified: 2026-05-25T12:58:00Z
status: closed
score: 5/5
```

### Pattern 2: Layered Truth Propagation

**What:** Keep shipped-capability checkboxes separate from traceability/verification status rows [VERIFIED: D-04 + current `REQUIREMENTS.md` structure].  
**When to use:** When a capability is shipped and locally proven, but another follow-up phase remains open for a narrower external-proof concern [VERIFIED: `36-VERIFICATION.md`; VERIFIED: `41.1-VERIFICATION.md`].  
**Example:**
```markdown
# Source: .planning/REQUIREMENTS.md + .planning/phases/41-quote-lifecycle-e2e-verification/41-02-SUMMARY.md
- [x] **QUOT-01**: Developer can create, retrieve, update, list quotes with auto-pagination via `stream!/3`
| QUOT-01 | Phase 41 | Verified |
```

### Pattern 3: Family-Scoped Requirement Edits

**What:** Update only the requirement family closed by the current phase, not unrelated rows [VERIFIED: `40-02-SUMMARY.md`; VERIFIED: `41-02-SUMMARY.md`].  
**When to use:** Every closure or reconciliation pass that touches `REQUIREMENTS.md` [VERIFIED: file read].  
**Example:**
```markdown
# Source: .planning/phases/40-mandate-setupattempt-integration-closure/40-02-SUMMARY.md
- Updated only the AUTH checklist entries and AUTH traceability rows in `.planning/REQUIREMENTS.md` to `Verified`.
```

### Anti-Patterns to Avoid

- **Direct roadmap cleanup before DX verifier closure:** This breaks the repo’s evidence hierarchy and risks another audit failure [VERIFIED: `42-CONTEXT.md`; VERIFIED: `39-VERIFICATION.md`].
- **Marking Phase `41.1` complete because QUOT rows are already verified:** QUOT closure belongs to Phase 41, while Phase `41.1` remains explicitly open for external proof [VERIFIED: `36-VERIFICATION.md`; VERIFIED: `41.1-VERIFICATION.md`].
- **Using repo-wide docs warnings as a hidden scope bomb:** `mix docs --warnings-as-errors` is red today for unrelated warnings, so making that a mandatory closure gate would silently enlarge Phase 42 [VERIFIED: command output].
- **Reopening SDK code or guide content beyond packaging truth:** D-10 explicitly forbids new behavior or opportunistic DX expansion in this phase [VERIFIED: `42-CONTEXT.md`].

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| DX closure truth [VERIFIED: file read] | a new custom status rubric or “audit-only” mini-format [VERIFIED: file read] | the existing closed verifier pattern used by phases 35, 36, and 39 [VERIFIED: verifier files] | The repo already has an accepted closure grammar; inventing a second one lowers trust and raises planner ambiguity [VERIFIED: file read] |
| planning-surface truth propagation [VERIFIED: file read] | manual, unsourced wording changes based on memory [VERIFIED: file read] | summary-backed + grep-backed edits anchored in `37-VERIFICATION.md`, `35-VERIFICATION.md`, `36-VERIFICATION.md`, and `41.1-VERIFICATION.md` [VERIFIED: file read + codebase grep] | This phase is about documentary truth, so every status change needs a concrete artifact anchor [VERIFIED: `42-CONTEXT.md`] |
| external-proof handling [VERIFIED: file read] | vague blocker states like `human_needed` or hidden footnotes [VERIFIED: file read] | `pending-external-verification` with explicit environment wording [VERIFIED: `41.1-VERIFICATION.md`; VERIFIED: `42-CONTEXT.md`] | The narrower wording preserves credibility and prevents future planners from misreading the gap as unimplemented code [VERIFIED: file read] |
| audit rerun [VERIFIED: codebase grep] | a new one-off audit script for this phase [VERIFIED: codebase grep] | update the existing audit artifact directly with deterministic evidence sections and status wording [VERIFIED: `42-CONTEXT.md`; VERIFIED: `.planning/v1.3-v1.3-MILESTONE-AUDIT.md`] | No dedicated audit command was found in the repo, so a narrow artifact refresh is the least-surprise path [VERIFIED: codebase grep] |

**Key insight:** The repo already solved the hard problem: authoritative truth lives in verifier artifacts. Phase 42 should only package DX closure and propagate it honestly [VERIFIED: `35-VERIFICATION.md`; VERIFIED: `36-VERIFICATION.md`; VERIFIED: `39-VERIFICATION.md`; VERIFIED: `42-CONTEXT.md`].

## Common Pitfalls

### Pitfall 1: Collapsing “shipped” into “closed”

**What goes wrong:** A planner marks a phase `Complete` because summaries exist, even though no verifier exists or the verifier is still pending externally [VERIFIED: `.planning/ROADMAP.md`; VERIFIED: `41.1-VERIFICATION.md`].  
**Why it happens:** Summary files are easier to spot than verifier frontmatter [VERIFIED: codebase grep].  
**How to avoid:** Treat `status:` in the verifier as authoritative for closure semantics, and use summaries only as supporting evidence [VERIFIED: verifier files].  
**Warning signs:** `ROADMAP.md` says `Complete` while the corresponding verifier is missing or `pending-external-verification` [VERIFIED: file read + codebase grep].  

### Pitfall 2: Updating DX rows without closing `37-VERIFICATION.md`

**What goes wrong:** `DX-01` through `DX-04` become checked or `Verified`, but the milestone audit still has no accepted DX verifier artifact [VERIFIED: `.planning/v1.3-v1.3-MILESTONE-AUDIT.md`; VERIFIED: missing file check].  
**Why it happens:** The phase summaries already read like closure, so it is tempting to propagate from them directly [VERIFIED: `37-01-SUMMARY.md`; VERIFIED: `37-02-SUMMARY.md`; VERIFIED: `37-03-SUMMARY.md`].  
**How to avoid:** Make `37-VERIFICATION.md` the first execution task and reuse adjacent closure-phase structure [VERIFIED: `42-CONTEXT.md`; VERIFIED: adjacent verifier files].  
**Warning signs:** DX checkboxes flip before `test -f .planning/phases/37-dx-polish/37-VERIFICATION.md` returns `EXISTS` [VERIFIED: command output].  

### Pitfall 3: Accidentally closing Phase `41.1`

**What goes wrong:** The audit and roadmap start telling a “fully closed” quote story and erase the remaining environment-bound follow-through gap [VERIFIED: `41.1-VERIFICATION.md`; VERIFIED: `42-CONTEXT.md`].  
**Why it happens:** QUOT rows are already `Verified`, so downstream planners may conflate requirement-family closure with external follow-through closure [VERIFIED: `.planning/REQUIREMENTS.md`; VERIFIED: `36-VERIFICATION.md`].  
**How to avoid:** Preserve `pending-external-verification` verbatim in the roadmap and audit, and name the exact gap as external environment proof [VERIFIED: `41.1-VERIFICATION.md`].  
**Warning signs:** New wording replaces `pending-external-verification` with `Complete`, `Done`, or `Not started` for Phase `41.1` [VERIFIED: file read].  

### Pitfall 4: Treating `mix docs --warnings-as-errors` as a Phase 42 blocker

**What goes wrong:** The phase expands into unrelated docs-warning cleanup and loses its narrow reconciliation scope [VERIFIED: command output].  
**Why it happens:** `mix ci` includes `docs --warnings-as-errors`, and the phase is docs-adjacent [VERIFIED: `mix.exs`].  
**How to avoid:** Use targeted DX tests plus explicit warning acknowledgment; only absorb repo-wide docs warnings if the plan explicitly broadens scope [VERIFIED: command output; VERIFIED: `42-CONTEXT.md`].  
**Warning signs:** Phase tasks start touching hidden-module docs warnings in unrelated builders or mix tasks [VERIFIED: command output].  

## Code Examples

Verified patterns from repo-local sources:

### Closed DX Verifier Frontmatter

```yaml
# Source: adjacent closure pattern from .planning/phases/35-mandate-setupattempt/35-VERIFICATION.md
phase: 37-dx-polish
verified: 2026-05-25T...
status: closed
score: 4/4
```

### Requirement-Family Closure Row

```markdown
# Source: .planning/REQUIREMENTS.md after Phase 40 / 41 closures
| DX-01 | Phase 42 | Verified |
| DX-02 | Phase 42 | Verified |
| DX-03 | Phase 42 | Verified |
| DX-04 | Phase 42 | Verified |
```

### Truthful Open External-Proof Roadmap Row

```markdown
# Source: .planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md + D-03
| 41.1. Quote Downstream Follow-Through Verification | v1.3 | 2/2 | pending-external-verification | 2026-05-25 |
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| summaries imply closure [VERIFIED: stale roadmap + audit] | verifier artifact is the closure boundary [VERIFIED: `35-VERIFICATION.md`; VERIFIED: `36-VERIFICATION.md`; VERIFIED: `39-VERIFICATION.md`] | 2026-05-25 across Phases 39-41 [VERIFIED: verifier timestamps] | Phase 42 should create `37-VERIFICATION.md` before propagating DX truth [VERIFIED: file read] |
| binary done/not-done wording for all follow-up work [VERIFIED: historical audit language] | layered truth including `pending-external-verification` [VERIFIED: `41.1-VERIFICATION.md`; VERIFIED: D-03] | 2026-05-25 in Phase 41.1 [VERIFIED: verifier timestamp] | The roadmap and audit can pass while still naming one honest external-proof gap [VERIFIED: `42-CONTEXT.md`] |
| repo-wide docs build as an assumed gate for docs-adjacent phases [VERIFIED: `mix.exs`] | targeted DX test reruns plus explicit note about unrelated docs warnings [VERIFIED: command output; VERIFIED: `37-02-SUMMARY.md`] | 2026-05-25 in Phase 37 execution notes [VERIFIED: summary timestamp] | The planner should not silently convert Phase 42 into global docs-warning cleanup [VERIFIED: file read] |

**Deprecated/outdated:**

- `human_needed` for v1.3 follow-through truth is outdated for this scope because Phase `41.1` now uses `pending-external-verification` with narrower meaning [VERIFIED: `.planning/v1.3-v1.3-MILESTONE-AUDIT.md`; VERIFIED: `41.1-VERIFICATION.md`; VERIFIED: D-06].

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `42-RESEARCH.md` should be treated as current until 2026-06-24 unless the referenced planning artifacts change sooner [ASSUMED] | Metadata | Low; the planner may re-read current artifacts before execution anyway |

The draft contains no open assumptions about SDK behavior, milestone semantics, or closure truth; the only remaining assumption is the administrative freshness window above [VERIFIED: file read + command output].

## Open Questions (RESOLVED)

1. **What exact verdict word should the refreshed milestone audit use?** [RESOLVED]
   - Resolution: Keep the frontmatter/body verdict explicit about a repo-truth pass while one external-proof follow-up remains open. The exact label may stay concise, but the audit must say that planning truth now matches repo reality and that Phase `41.1` remains `pending-external-verification` because the remaining gap is environment-bound, not code-bound [VERIFIED: `42-CONTEXT.md`; VERIFIED: `41.1-VERIFICATION.md`].
   - Rationale: D-13 through D-15 require a truthful pass condition without inventing a nonexistent canonical audit taxonomy or flattening the remaining external-proof gap [VERIFIED: `42-CONTEXT.md`; VERIFIED: codebase grep].

2. **How should `ROADMAP.md` display Phase `41.1` status in the progress table?** [RESOLVED]
   - Resolution: Use the exact status string `pending-external-verification` in the progress table and related roadmap status surfaces, even if it is longer than neighboring rows [VERIFIED: `42-CONTEXT.md`; VERIFIED: `41.1-VERIFICATION.md`].
   - Rationale: D-03 and D-11 require the roadmap to preserve the real authority gap directly instead of hiding it behind `Complete`, `Not started`, or vague blocker wording [VERIFIED: `42-CONTEXT.md`].

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | targeted verification commands [VERIFIED: `37-VALIDATION.md`] | ✓ [VERIFIED: command output] | 1.19.5 [VERIFIED: command output] | — |
| Mix | test/docs aliases and targeted runs [VERIFIED: `mix.exs`] | ✓ [VERIFIED: command output] | 1.19.5 [VERIFIED: command output] | — |
| `rg` | deterministic artifact assertions [VERIFIED: adjacent plan/verifier usage + codebase grep] | ✓ [VERIFIED: command output] | 15.1.0 [VERIFIED: command output] | — |
| Node | optional graph/audit helper scripts in the broader GSD toolchain [VERIFIED: local repo context] | ✓ [VERIFIED: command output] | v22.14.0 [VERIFIED: command output] | — |

**Missing dependencies with no fallback:** None [VERIFIED: command output].

**Missing dependencies with fallback:** None in this workspace [VERIFIED: command output].

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with repo-local docs-truth tests and grep-backed artifact assertions [VERIFIED: `37-VALIDATION.md`; VERIFIED: codebase grep] |
| Config file | `test/test_helper.exs` [VERIFIED: `37-VALIDATION.md`] |
| Quick run command | `mix test test/lattice_stripe/testing_test.exs test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` [VERIFIED: command output] |
| Full suite command | `mix ci` [CITED: `mix.exs`] |

`mix ci` exists, but its docs step is currently red because `mix docs --warnings-as-errors` emits pre-existing warnings outside Phase 42 scope [VERIFIED: `mix.exs`; VERIFIED: command output].

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DX-01 | `guides/webhooks.md` still teaches one canonical Phoenix webhook path and that proof is packaged in `37-VERIFICATION.md` [VERIFIED: `37-02-SUMMARY.md`] | docs artifact + grep [VERIFIED: file read] | `rg -n 'Webhook\\.Plug|CacheBodyReader|raw-body|Phoenix' guides/webhooks.md .planning/phases/37-dx-polish/37-VERIFICATION.md` [VERIFIED: codebase grep pattern] | ❌ verifier / ✅ guide [VERIFIED: command output + file read] |
| DX-02 | fixture builders and explicit wrappers remain current [VERIFIED: `37-01-SUMMARY.md`] | unit [VERIFIED: file read] | `mix test test/lattice_stripe/testing_test.exs --warnings-as-errors` [VERIFIED: `37-VALIDATION.md`; VERIFIED: green within combined test run] | ✅ [VERIFIED: codebase grep] |
| DX-03 | recipes guide exists, stays library-scoped, and is referenced by docs-truth surface [VERIFIED: `37-02-SUMMARY.md`; VERIFIED: `37-03-SUMMARY.md`] | unit + docs artifact [VERIFIED: file read] | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors && rg -n 'dispute|credit|quote' guides/recipes.md` [VERIFIED: codebase grep + command output] | ✅ [VERIFIED: codebase grep] |
| DX-04 | version refs, cross-links, and current examples remain coherent [VERIFIED: `37-03-SUMMARY.md`; VERIFIED: `mix.exs`] | unit [VERIFIED: file read] | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` [VERIFIED: command output] | ✅ [VERIFIED: codebase grep] |

### Sampling Rate

- **Per task commit:** run the narrow command that matches the edited artifact family, plus a focused `rg` assertion on the touched planning file [VERIFIED: adjacent validation patterns + codebase grep].
- **Per wave merge:** `mix test test/lattice_stripe/testing_test.exs test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` and `rg -n 'DX-0[1-4]|status: closed|pending-external-verification|Phase 41\\.1|Plans:' .planning/REQUIREMENTS.md .planning/ROADMAP.md .planning/STATE.md .planning/v1.3-v1.3-MILESTONE-AUDIT.md .planning/phases/37-dx-polish/37-VERIFICATION.md` [VERIFIED: command output + codebase grep].
- **Phase gate:** the targeted DX tests are green, `37-VERIFICATION.md` exists with `status: closed`, DX rows are reconciled, and the audit artifact no longer claims stale planning truth [VERIFIED: phase context + current missing-file check].

### Wave 0 Gaps

- [ ] `.planning/phases/37-dx-polish/37-VERIFICATION.md` — missing and required for all downstream planning-truth propagation [VERIFIED: command output].
- [ ] No dedicated milestone-audit regeneration command was found; the planner should add explicit artifact-refresh and grep-assert tasks rather than assuming automation exists [VERIFIED: codebase grep].

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [VERIFIED: phase scope] | — |
| V3 Session Management | no [VERIFIED: phase scope] | — |
| V4 Access Control | no [VERIFIED: phase scope] | — |
| V5 Input Validation | yes [VERIFIED: phase scope + verifier/frontmatter editing] | constrain status words and requirement rows to existing repo vocabulary such as `closed`, `Verified`, and `pending-external-verification` [VERIFIED: `42-CONTEXT.md`; VERIFIED: existing verifier files] |
| V6 Cryptography | yes, indirectly [VERIFIED: phase materials include webhook/test commands] | never embed real Stripe secrets or webhook secrets into verifier or audit artifacts; keep any external-proof command as an env-var placeholder only [VERIFIED: `41.1-VERIFICATION.md`; VERIFIED: `37-02-SUMMARY.md`] |

### Known Threat Patterns for Planning-Truth Reconciliation

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| false closure claim in roadmap or requirements [VERIFIED: current stale rows] | Tampering | require a verifier artifact and exact supporting evidence before any status flip [VERIFIED: adjacent closure pattern] |
| erasing the `41.1` external-proof gap [VERIFIED: `41.1-VERIFICATION.md`] | Repudiation | preserve `pending-external-verification` verbatim in roadmap and audit wording [VERIFIED: D-03; VERIFIED: verifier file] |
| secret leakage in copied verification commands [VERIFIED: `41.1-VERIFICATION.md`] | Information Disclosure | keep env vars placeholder-only and do not paste live keys into docs or verification reports [VERIFIED: file read] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/42-planning-truth-reconciliation/42-CONTEXT.md` - locked scope, truth model, and audit target [VERIFIED: file read]
- `.planning/ROADMAP.md` - current stale phase states, progress rows, and Phase 42 success criteria [VERIFIED: file read]
- `.planning/REQUIREMENTS.md` - current DX checklist and traceability mismatch [VERIFIED: file read]
- `.planning/STATE.md` - current milestone-focus drift and stale progress snapshot [VERIFIED: file read]
- `.planning/v1.3-v1.3-MILESTONE-AUDIT.md` - exact planning-truth gaps still open [VERIFIED: file read]
- `.planning/phases/37-dx-polish/37-VALIDATION.md`, `37-01-SUMMARY.md`, `37-02-SUMMARY.md`, `37-03-SUMMARY.md` - shipped DX evidence and current validation contract [VERIFIED: file read]
- `.planning/phases/35-mandate-setupattempt/35-VERIFICATION.md`, `.planning/phases/36-quote/36-VERIFICATION.md`, `.planning/phases/39-credit-note-verification-closure/39-VERIFICATION.md`, `.planning/phases/41.1-quote-downstream-follow-through-verification/41.1-VERIFICATION.md` - accepted closure/open-boundary patterns [VERIFIED: file read]
- `mix.exs` - `ci` alias and docs/test configuration [VERIFIED: file read]
- Current command output: `elixir --version`, `mix --version`, `rg --version`, `node --version`, targeted `mix test`, and `mix docs --warnings-as-errors` [VERIFIED: command output]

### Secondary (MEDIUM confidence)

- `CLAUDE.md` - project-level constraints and workflow rules [CITED: `CLAUDE.md`]

### Tertiary (LOW confidence)

- None [VERIFIED: file read].

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - the phase relies on repo-local artifacts and current local tool versions already verified in this session [VERIFIED: file read + command output].
- Architecture: HIGH - adjacent closure phases and the locked Phase 42 context all point to one consistent verifier-first reconciliation pattern [VERIFIED: file read].
- Pitfalls: HIGH - the current stale roadmap, missing `37-VERIFICATION.md`, open `41.1` verifier, and red repo-wide docs build were all reproduced directly [VERIFIED: file read + command output].

**Research date:** 2026-05-25 [VERIFIED: command output]  
**Valid until:** 2026-06-24 for repo-local planning structure, or until Phase 42 materially changes the referenced artifacts [ASSUMED]
