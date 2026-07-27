# Phase 60: CI Gate & Milestone Close - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Close v1.9 by (1) making CI enforce `docs_truth` on guide and markdown PRs, (2) refreshing planning truth (JTBD-MAP, milestone audit, archive), and (3) transitioning to maintenance posture. Doc-only milestone — no Hex bump, no new API breadth.

**In scope:** CI-01, JTBD-01, milestone close artifacts (audit, archive, PROJECT/STATE/MILESTONES/RETROSPECTIVE), CONTRIBUTING.md CI note fix.

**Out of scope:** Hex version bump, CHANGELOG v1.9 section, new Stripe API modules, payments.md wire-string comment polish, link format drift, 54-VERIFICATION backfill (deferred again), separate docs_truth workflow, actionlint/CODEOWNERS (future hygiene).

</domain>

<decisions>
## Implementation Decisions

### CI workflow change authorization
- **D-01:** Maintainer explicitly approves editing `.github/workflows/ci.yml` for CI-01 only — granted via Phase 60 discuss-phase (2026-05-27) with directive to research and lock scoped workflow change.
- **D-02:** Approved scope: narrow `paths-ignore` only — remove `**.md` and `guides/**`; keep `.planning/**` ignored. No new jobs, actions, permissions, secrets, or shell path logic in Phase 60.
- **D-03:** Commit message must document CI-01 rationale and reference `60-CONTEXT.md` D-01 approval.

### CI gate scope (paths-ignore strategy)
- **D-04:** Replace current `paths-ignore` (`**.md`, `.planning/**`, `guides/**`) with **`.planning/**` only** on both `push` and `pull_request` triggers.
- **D-05:** Run **full existing CI** (lint + test matrix + integration) on doc/guide PRs — do **not** add a separate `docs_truth` workflow or `dorny/paths-filter` job in Phase 60.
- **D-06:** Rationale: simplest correct diff; satisfies CI-01 for all `.md` guides, root `README.md`, and `guides/cheatsheet.cheatmd`; matches idiomatic Elixir OSS (Req, Ecto, Phoenix, Broadway run full CI with no doc ignores) and Stripe official SDKs (full CI on every PR); ~5–8 min doc PR cost is acceptable for a maintenance-mode library with infrequent doc edits; avoids branch-protection dual-check complexity and required-check deadlock footguns.
- **D-07:** Rejected alternatives: (1) remove `guides/**` only — leaves README unguarded; (3) dedicated docs_truth workflow — faster but two required checks + path-list drift; shell `git diff` fast-path — fragile, not least surprise.

### Plan sequencing
- **D-08:** **Plan 1 (60-01):** CI-01 only — edit `ci.yml`, update `CONTRIBUTING.md` L83 (remove "CI skipped for docs-only" note), update `STATE.md` blocker. **No JTBD-MAP edits** in Plan 1.
- **D-09:** **Plan 2 (60-02):** JTBD-01 + milestone close — JTBD-MAP refresh, `60-VERIFICATION.md`, `v1.9-MILESTONE-AUDIT.md`, archive ROADMAP/REQUIREMENTS, update MILESTONES/RETROSPECTIVE/PROJECT/STATE to maintenance posture.

### JTBD-MAP & planning truth refresh
- **D-10:** Upgrade hosted checkout row: Narrative doc coverage **Partial → Strong** with text mirroring one-time payments row: `Shipped; checkout.md examples fixed (Phase 59) + docs_truth locked`.
- **D-11:** Append README lock note to Public package/docs/version truth row: `README error taxonomy locked (Phase 59)`.
- **D-12:** Biggest Gaps intro → v1.9 close wording after CI-01 ships; **remove Gap 3 entirely** (checkout/README/CI-01 all resolved).
- **D-13:** Add Resolved gaps bullets: Phase 59 checkout/README/docs_truth items + Phase 60 CI-01 item.
- **D-14:** Flip Recommended Priority Order to **maintenance-first** (#1) only after CI-01 merges — remove v1.9 recommended line.
- **D-15:** Strong narrative upgrade is **not blocked on CI-01** (Phase 58 precedent: payments Strong while CI-01 open). Gap 3 collapse and priority flip **are blocked on CI-01**.

### Milestone close depth
- **D-16:** **Minimal-but-audit-complete** close — 2 plans, not v1.8 Phase 58's 5-plan overhead. Phase 59 already has full VERIFICATION (6/6).
- **D-17:** **Defer PLAN-01** (`54-VERIFICATION.md` backfill) again — record third carry in `v1.9-MILESTONE-AUDIT.md` tech_debt; zero adopter impact; synthetic reconstruction without phase SUMMARY files.
- **D-18:** No Hex bump; `@version` stays `1.7.0`. Optional git tag `v1.9` (planning tag, not `v1.9.0`).
- **D-19:** Post-close maintenance posture: STATE `status: maintenance`; PROJECT latest shipped v1.9; done estimate ~94–96%; forward posture unchanged (Stripe drift, adopter-pull narrow adds only).

### Claude's Discretion
- Exact JTBD-MAP prose wording (must satisfy D-10..D-14 intent).
- Whether optional `v1.9` git tag ships in Plan 2.
- Exact live verification bash block in milestone audit.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase requirements
- `.planning/ROADMAP.md` — Phase 60 success criteria (CI-01, JTBD-01, PLAN-01 optional)
- `.planning/REQUIREMENTS.md` — CI-01, JTBD-01, PLAN-01 definitions and traceability

### Prior phase context
- `.planning/phases/59-checkout-guide-readme-truth/59-CONTEXT.md` — deferred CI-01/JTBD-01; per-surface docs_truth describes (D-16)
- `.planning/phases/59-checkout-guide-readme-truth/59-VERIFICATION.md` — Phase 59 evidence for JTBD Strong upgrade

### CI & workflow
- `.github/workflows/ci.yml` — current paths-ignore (edit target)
- `CONTRIBUTING.md` — L83 stale "CI skipped for docs-only" note (must update post-CI-01)
- `test/lattice_stripe/docs_truth_test.exs` — 26 tests enforced via `mix test` in test job

### Milestone close precedent
- `.planning/milestones/v1.8-MILESTONE-AUDIT.md` — audit structure and tech_debt pattern
- `.planning/milestones/v1.7-MILESTONE-AUDIT.md` — 54-VERIFICATION gap precedent
- `.planning/JTBD-MAP.md` — JTBD-01 edit target

### Assessment & vision
- `.planning/threads/v1-9-next-milestone-assessment.md` — CI honesty wedge rationale
- `.planning/PROJECT.md` — core value: copy-paste correct, unsurprising; maintenance mode posture

### Research (prompts)
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — docs are product; CI validates docs; least-privilege; no skip-docs anti-pattern
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — README + guides + grep-locked examples as four-layer docs model
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — Checkout Tier 2 "boringly reliable"; copy-paste examples are highest-risk DX surface

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.github/workflows/ci.yml` — three jobs (lint, test matrix, integration); `docs_truth` runs inside `mix test`; concurrency already configured.
- `test/lattice_stripe/docs_truth_test.exs` — 26 tests across getting-started, payments, checkout, README, install pins, scope boundaries.
- Phase 58 milestone close playbook — audit → archive → MILESTONES/RETROSPECTIVE/PROJECT/STATE updates.

### Established Patterns
- Doc-only milestones: no Hex bump (v1.8 precedent); optional planning git tag without `.0` suffix.
- JTBD-MAP refresh at **milestone close**, not start (v1.8 RETROSPECTIVE lesson).
- Narrative Strong = guide exists + copy-paste correct + docs_truth describe lock (Phase 57/58/59 playbook). CI enforcement is separate gap dimension.
- Per-surface docs_truth describes — do not consolidate (Phase 59 D-16).

### Integration Points
- `paths-ignore` in `ci.yml` — sole CI-01 edit surface.
- `CONTRIBUTING.md` L83 — must align with post-CI-01 reality.
- `.planning/JTBD-MAP.md` — hosted checkout row L88, Gap 3 section L128–133, priority order L156–163.
- `STATE.md` — CI-01 blocker clears after Plan 1 merge.

</code_context>

<specifics>
## Specific Ideas

- "Checkout should feel boringly reliable" — Tier 2 DX priority; CI gate makes Phase 59 locks real, not theater.
- Phase 59 per-surface describes were designed for Phase 60 enforceability — full CI on guide PRs is the payoff.
- Stripe Python SDK runs `typecheck-examples` in lint — aspirational future enhancement, not Phase 60 scope.
- Elixir OSS norm: libraries don't paths-ignore docs; LatticeStripe was an outlier saving minutes on planning edits.
- Sibling-guide audit lesson (payments fixed → checkout missed) belongs in v1.9 RETROSPECTIVE.

</specifics>

<deferred>
## Deferred Ideas

- **PLAN-01:** `54-VERIFICATION.md` backfill — third carry; defer to opportunistic planning hygiene sprint.
- **Dedicated docs_truth workflow** — revisit only if doc PR volume makes full CI minutes a measured pain point.
- **actionlint + CODEOWNERS on `.github/workflows/**`** — future supply-chain hardening per CI research doc.
- **payments.md wire-string output comments** — REQUIREMENTS polish tier.
- **getting-started Read next link format drift** — maintenance backlog.

</deferred>

---

*Phase: 60-ci-gate-milestone-close*
*Context gathered: 2026-05-27*
