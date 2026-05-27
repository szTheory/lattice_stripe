# Phase 58: Milestone Closure & Planning Truth - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Close v1.8 by refreshing planning artifacts to match post-Phase-56/57 adopter-facing reality, resolving optional tax proof hygiene, running milestone audit, and flipping PROJECT/STATE to maintenance posture — without new API breadth, Hex version bump, or stop-signal rewrite.

**In scope:** JTBD-MAP full post-v1.8 refresh (ROUTE-03); MILESTONES.md v1.7 audit footnote + v1.8 shipped section (PLAN-01); RETROSPECTIVE v1.8 entry + preserve v1.7 historical lessons (PLAN-02); commit tax proof files + CI adoption step atomically (PROOF-01); `/gsd-audit-milestone v1.8`; archive roadmap/requirements; maintenance posture in PROJECT/STATE/ROADMAP.

**Out of scope:** Hex 1.8.0 bump; README/`guides/scope.md` stop-signal rewrite (already at 1.7.0); CI paths-ignore (CI-01 future); new Stripe resource families; `guides/checkout.md` status bugs (deferred); `v1.7-MILESTONE-AUDIT.md` retro-edits (immutable audit snapshot).

</domain>

<decisions>
## Implementation Decisions

### JTBD-MAP refresh depth (Area 1 — Option B)

- **D-01:** **Full Gap 1 rewrite**, not surgical rows or minimal ROUTE-03 — Phase 58 success criterion #1 requires no stale gap claims anywhere in the map.
- **D-02:** Update coverage matrix rows:
  - One-time payments → narrative **Strong** (was Partial with v1.8 bug note)
  - Charge audit and reconciliation → **Good/Strong** with v1.8 routing refs
  - Production operator guides → **Good/Strong** (update/capture routed in Phase 57)
  - Public package/docs/version truth → **Strong** (getting-started prose fixed Phase 56)
- **D-03:** Move all v1.8-closed items from "Gap 1: Doc-routing polish" into **Resolved gaps** with v1.8 attribution:
  - getting-started prose drift
  - payments.md API example bugs
  - Charge reconciliation discovery gap
  - operator guide update/capture routing gap
  - cosmetic planning drift (this phase closes it)
- **D-04:** Delete or collapse Gap 1 section — replace with one-line pointer: "Doc-routing polish closed in v1.8 (Phases 56–58)."
- **D-05:** Rewrite **Recommended Priority Order** — **#1 maintenance mode** (Stripe API drift, adopter-pull narrow adds, bugfixes); v1.8 doc polish removed from active queue; Gap 2 narrative thin-docs unchanged; specialist/TAX narrow reqs unchanged.
- **D-06:** Add Maintenance Notes bullet: refresh this file at **milestone close** (not only milestone start); verify against `CHANGELOG.md`, `docs_truth_test.exs`, and shipped guides.
- **D-07:** Reject Option A (surgical) — leaves Gap 1 block and priority order contradicting shipped reality; repeats v1.7 partial-refresh footgun. Reject Option C (minimal ROUTE-03) — fails success criterion #1.

### Planning artifact cosmetics (Area 2 — Option B with surgical v1.7 edit)

- **D-08:** **Append v1.8 section** to top of `.planning/MILESTONES.md` — same shape as v1.7 (phases, key accomplishments, audit link, git range at close).
- **D-09:** **Edit v1.7 MILESTONES audit line only** — do not rewrite v1.7 accomplishments or stop-signal prose. Replace open-debt list with close-time truth + forward resolution:

  > **Audit:** PASSED — 13/13 requirements, 0 critical gaps, 4/5 E2E flows. **Tech debt at close:** missing `54-VERIFICATION.md`; doc-routing gaps (getting-started prose, payments/operator Charge routing). **Resolved in v1.8** (Phases 56–57). See [v1.7-MILESTONE-AUDIT.md](milestones/v1.7-MILESTONE-AUDIT.md).

- **D-10:** **Leave `milestones/v1.7-MILESTONE-AUDIT.md` immutable** — append-only audit trail; v1.8 gets its own `v1.8-MILESTONE-AUDIT.md` at close.
- **D-11:** **Append v1.8 section** to `.planning/RETROSPECTIVE.md` — what worked (describe-per-guide docs_truth pattern 56→57; JTBD-at-close); lessons (post-stop milestones = doc polish only; verify untracked proof at assessment).
- **D-12:** **Preserve v1.7 RETROSPECTIVE "partial close before REL-04" bullet** — accurate process archaeology; PLAN-02 is publish-state accuracy, not erasing lessons.
- **D-13:** v1.8 MILESTONES key accomplishments (5 bullets):
  1. getting-started release-status prose + docs_truth prose SSOT locks (TRUTH-01/02, Phase 56)
  2. payments.md atom status, stream filter, search/3 fixes + VERIFY-04 locks (GUIDE-01..03, Phase 57)
  3. PI-first Charge reconciliation section in payments.md (ROUTE-01, Phase 57)
  4. operator guide update/capture routing spines (ROUTE-02, Phase 57)
  5. planning truth close — JTBD-MAP refresh, MILESTONES/RETROSPECTIVE, tax proof commit (ROUTE-03, PLAN-01/02, PROOF-01, Phase 58)
- **D-14:** Reject Option A alone — hides v1.8 from milestone history. Reject Option C — mis-targets RETROSPECTIVE without MILESTONES v1.8 record.

### Tax proof file disposition (Area 3 — Option A)

- **D-15:** **Commit both** untracked test files in one atomic commit with the unstaged `ci.yml` adoption-contract step.
- **D-16:** Files to commit:
  - `test/lattice_stripe/tax/adoption_contract_test.exs`
  - `test/integration/tax_id_integration_test.exs`
  - `.github/workflows/ci.yml` (Tax adoption contract step — already in working tree diff)
- **D-17:** Rationale: CI references adoption contract on 1.19/OTP 28 — untracked file breaks fresh clone; integration completes Mox + stripe-mock pyramid for TaxId (matches 37 other `test/integration/*_integration_test.exs`); v1.6 audit claims stripe-mock TaxId proof.
- **D-18:** Adoption contract retains unique value despite partial overlap with `docs_truth_test.exs`: UAT-4 (fixtures + `testing.md`), UAT-6 (Phase 51 placeholder guard), explicit UAT-1..8 checklist gate.
- **D-19:** Minor follow-up in same commit or plan: update adoption contract `@moduledoc` to reference `milestones/v1.6-MILESTONE-AUDIT.md` instead of missing `.planning/phases/51-taxid-testing-adoption-surface/51-UAT.md`.
- **D-20:** Suggested commit message shape: `test(tax): commit Phase 51 proof tests wired by CI and milestone audit`
- **D-21:** Reject Option B — PROOF-01 half-resolved; false integration proof narrative. Reject Option C — must revert ci.yml step; rewrites v1.6 audit evidence.

### Milestone close ritual (Area 4 — Option A, audit-first entry)

- **D-22:** **Full close package** — Phase 58 success criterion #5 requires audit + posture flip; Option B under-delivers.
- **D-23:** **Audit as mandatory step 1** (`/gsd-audit-milestone v1.8`) before archive — v1.7 retrospective lesson; expect **passed with tech debt** (CI-01 paths-ignore still deferred).
- **D-24:** Write `.planning/milestones/v1.8-MILESTONE-AUDIT.md` from audit output.
- **D-25:** Archive via `/gsd-complete-milestone v1.8` (or manual equivalent):
  - `.planning/ROADMAP.md` → `milestones/v1.8-ROADMAP.md`
  - `.planning/REQUIREMENTS.md` → `milestones/v1.8-REQUIREMENTS.md`
  - Optionally move phases 56–58 → `milestones/v1.8-phases/` (v1.5 pattern)
- **D-26:** **ROADMAP.md** — mark v1.8 ✅ shipped; no active milestone; next = maintenance / adopter-pull only.
- **D-27:** **PROJECT.md** — latest shipped = v1.8; move Active reqs → Validated; replace "Current Milestone: v1.8" with **maintenance mode** section; **do not** rewrite v1.x stop signal (already at 1.7.0).
- **D-28:** **STATE.md** — `status: maintenance`; clear stale Phase 56 todos; `completed_phases: 3/3`; remove executing v1.8 drift.
- **D-29:** **Explicitly skip:** Hex 1.8.0 bump; README/scope stop-signal rewrite; new milestone kickoff.
- **D-30:** Ordered execution within Phase 58 plans:
  1. ROUTE-03 JTBD-MAP refresh
  2. PLAN-01/02 MILESTONES + RETROSPECTIVE
  3. PROOF-01 tax proof commit
  4. `/gsd-audit-milestone v1.8` → write v1.8-MILESTONE-AUDIT.md
  5. Append v1.8 MILESTONES/RETROSPECTIVE final audit line + git range
  6. `/gsd-complete-milestone v1.8` archive + posture flip

### Claude's Discretion

- Exact JTBD-MAP editorial wording and line-count tuning for coverage matrix cells.
- Whether to move phases 56–58 to `milestones/v1.8-phases/` vs leave in `.planning/phases/` (either acceptable; v1.5 pattern preferred if low friction).
- v1.8 RETROSPECTIVE "What Was Inefficient" bullets — capture only if audit surfaces genuine process debt.
- Git range and plan count in v1.8 MILESTONES section — fill at close time from git log.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` § Phase 58 — success criteria, ROUTE-03, PLAN-01/02, PROOF-01
- `.planning/REQUIREMENTS.md` § Planning Truth, Proof Hygiene — acceptance criteria
- `.planning/PROJECT.md` — v1.8 goal, JTBD refresh lesson, maintenance posture
- `.planning/STATE.md` — current executing state to flip at close
- `.planning/threads/v1-8-next-milestone-assessment.md` — wedge analysis, untracked proof finding, maintenance recommendation

### Prior phase outcomes (what planning must reflect)
- `.planning/phases/56-release-truth-getting-started/56-CONTEXT.md` — TRUTH-01/02 decisions
- `.planning/phases/56-release-truth-getting-started/56-VERIFICATION.md` — Phase 56 passed evidence
- `.planning/phases/57-payments-guide-charge-routing/57-CONTEXT.md` — GUIDE/ROUTE/VERIFY decisions; JTBD deferred here
- `.planning/phases/57-payments-guide-charge-routing/57-VERIFICATION.md` — Phase 57 7/7 passed

### Close templates & lessons
- `.planning/MILESTONES.md` — v1.7 section shape to mirror for v1.8 append
- `.planning/RETROSPECTIVE.md` § v1.7 — Phase 55 close pattern, audit-before-close lesson
- `.planning/milestones/v1.7-MILESTONE-AUDIT.md` — immutable; tech debt items resolved in v1.8
- `.planning/milestones/v1.7-ROADMAP.md` — archive pattern for v1.8-ROADMAP.md
- `.planning/milestones/v1.6-MILESTONE-AUDIT.md` — TaxId proof references, adoption contract role

### Artifacts to refresh
- `.planning/JTBD-MAP.md` — stale Gap 1, coverage matrix L87/L105–107, priority order L155
- `test/lattice_stripe/tax/adoption_contract_test.exs` — untracked; CI gate
- `test/integration/tax_id_integration_test.exs` — untracked; stripe-mock proof
- `.github/workflows/ci.yml` — unstaged adoption contract step L120–122

### Ecosystem research (prompts)
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — four doc layers, changelog/versioned docs, copy-pasteable guides as API contract
- `prompts/elixir-oss-lib-ci-cd-best-research.md` — CI honesty, test gates on fresh clone
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — Tier 1 payments polish, maintenance posture for SDK completeness

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 55 v1.7 close pattern — MILESTONES append, RETROSPECTIVE append, audit → archive → posture flip
- v1.6 MILESTONES "Outstanding follow-through (resolved at v1.7 close)" footnote pattern — template for v1.7 → v1.8 resolution line
- 37 tracked `test/integration/*_integration_test.exs` — TaxId integration follows established stripe-mock pattern
- `docs_truth_test.exs` — 24 tests post-Phase 57; planning refresh should cite this as adopter truth SSOT

### Established Patterns
- **Append-only milestone history** — never retro-edit `*-MILESTONE-AUDIT.md` snapshots
- **Planning map lags shipped reality** — v1.7 lesson drove v1.8; refresh at close prevents wrong `/gsd-new-milestone` scope
- **Mox unit + stripe-mock integration pyramid** — project testing philosophy; TaxId was missing integration half on branch
- **CI step + test file atomic commit** — adoption contract step without file breaks fresh clone

### Integration Points
- JTBD-MAP must reflect `guides/payments.md#charge-reconciliation`, operator guide cross-links, getting-started prose
- PROOF-01 commit unblocks CI matrix 1.19/OTP 28 gate
- complete-milestone flips PROJECT/STATE/ROADMAP consumed by next maintenance workstream

</code_context>

<specifics>
## Specific Ideas

### Coherent four-area package (research synthesis — user requested one-shot recommendations)

| Area | Decision | Why it coheres |
|------|----------|----------------|
| JTBD-MAP | Option B — full Gap 1 rewrite + maintenance-first priority | Closes ROUTE-03 completely; prevents v1.7-style stale map driving redundant milestones; aligns internal map with public docs_truth SSOT |
| Planning cosmetics | Option B — v1.8 append + v1.7 audit footnote | Append-only history; satisfies PLAN-01/02; preserves immutable v1.7 audit file and process lessons |
| Tax proof | Option A — commit both + ci.yml atomically | CI honesty; completes Mox+integration pyramid; matches v1.6 audit claims; ~230 lines standard test code |
| Close ritual | Option A via audit-first gate | Phase 58 SC #5; v1.7 "audit before complete-milestone" lesson; returns to maintenance posture without re-publishing stop signal |

### Cross-ecosystem lessons applied

**Do right (Stripe SDKs, Elixir OSS, LatticeStripe v1.7/v1.8):**
- Treat guides + docs_truth as adopter-facing truth; planning artifacts orient maintainers, not duplicate CHANGELOG (Req/Ecto/Phoenix pattern)
- Refresh capability maps at milestone **close**, not only start (PROJECT.md key decision)
- Append-only milestone records — rewrite audit snapshots falsifies history (v1.7 partial-close lesson)
- Mox + integration test pyramid for HTTP SDKs (Finch/Mox/stripe-mock stack)
- CI gates must reference tracked files — broken fresh clone is worst DX footgun

**Footguns avoided:**
- Surgical JTBD edit leaving Gap 1 block (next milestone picks finished work)
- Editing v1.7-MILESTONE-AUDIT.md (falsifies close-time verdict)
- Erasing RETROSPECTIVE "partial close" lesson (process archaeology loss)
- Committing ci.yml adoption step without test file (CI fails on clone)
- Partial close leaving STATE at "executing v1.8" (contradicts maintenance posture)
- Re-publishing v1.x stop signal or Hex 1.8.0 bump (out of scope; doc-only milestone)

### Example v1.8 MILESTONES.md opening (target)

```markdown
## v1.8 Adopter Truth & Doc Routing Polish (Shipped: 2026-05-27)

**Phases completed:** 3 phases (56–58), TBD plans

**Key accomplishments:**
- [5 bullets per D-13]

**Audit:** PASSED — see [v1.8-MILESTONE-AUDIT.md](milestones/v1.8-MILESTONE-AUDIT.md)
**Known deferred at close:** CI-01 paths-ignore (guide-only PRs skip docs_truth)
```

</specifics>

<deferred>
## Deferred Ideas

- **CI paths-ignore (CI-01)** — guide-only PRs skip docs_truth; awaiting explicit approval; note in v1.8 audit tech debt
- **`guides/checkout.md` status string bugs** — same class as payments.md; out of v1.8 scope (Phase 57 deferred)
- **`PaymentIntent.cancel/4` moduledoc string status** — internal inconsistency; separate cleanup
- **Hex 1.8.0 publish** — doc-only milestone; no version bump unless release policy changes
- **New milestone kickoff** — maintenance mode next; specialist/TAX narrow on adopter pull only

### Reviewed Todos (not folded)

- None matched via `todo.match-phase 58`

</deferred>

---

*Phase: 58-milestone-closure-planning-truth*
*Context gathered: 2026-05-27*
