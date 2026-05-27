# Phase 58: Milestone Closure & Planning Truth - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 58-milestone-closure-planning-truth
**Areas discussed:** JTBD-MAP refresh depth, Planning artifact cosmetics, Tax proof disposition, Milestone close ritual
**Mode:** All areas auto-selected; user requested one-shot research-backed recommendations

---

## JTBD-MAP refresh depth

| Option | Description | Selected |
|--------|-------------|----------|
| A — Surgical row fixes | Coverage matrix + charge row only | |
| B — Full Gap 1 rewrite | Resolved gaps + maintenance-first priority | ✓ |
| C — Minimal ROUTE-03 | Charge row + one gaps bullet | |

**User's choice:** Option B (research synthesis recommendation)
**Notes:** v1.7 footgun — JTBD stale after ship drove redundant v1.8 wedge. Full rewrite closes ROUTE-03 completely and aligns with PROJECT.md "refresh at milestone close" lesson. Elixir OSS pattern: CHANGELOG + docs_truth as adopter truth; planning map as maintainer orientation.

---

## Planning artifact cosmetics (PLAN-01/02)

| Option | Description | Selected |
|--------|-------------|----------|
| A — Patch v1.7 audit bullets only | Remove stale tech-debt items | |
| B — v1.8 append + v1.7 audit footnote | Full MILESTONES + RETROSPECTIVE v1.8 sections | ✓ |
| C — RETROSPECTIVE historical pass only | Fix pre-publish wording | |

**User's choice:** Option B with surgical v1.7 audit line edit (research synthesis)
**Notes:** Append-only milestone history. Leave v1.7-MILESTONE-AUDIT.md immutable. Preserve v1.7 RETROSPECTIVE "partial close before REL-04" process lesson. v1.6 "resolved at v1.7 close" footnote pattern applied v1.7 → v1.8.

---

## Tax proof file disposition (PROOF-01)

| Option | Description | Selected |
|--------|-------------|----------|
| A — Commit both files + ci.yml | Atomic CI honesty + integration pyramid | ✓ |
| B — Adoption contract only | Satisfy CI gate; defer integration | |
| C — Drop both with rationale | Revert ci.yml step | |

**User's choice:** Option A (research synthesis)
**Notes:** ci.yml adoption step already in working tree diff — untracked test breaks fresh clone on Elixir 1.19/OTP 28. Integration completes stripe-mock proof chain v1.6 audit references. Adoption contract has unique UAT-4/6 value despite partial docs_truth overlap.

---

## Milestone close ritual

| Option | Description | Selected |
|--------|-------------|----------|
| A — Full close package | Audit + archive + maintenance posture | ✓ |
| B — Planning-truth only | Defer audit/archive | |
| C — Audit-first only | Gate without close commitment | |

**User's choice:** Option A with C as entry gate (audit mandatory step 1)
**Notes:** Phase 58 SC #5 requires audit + posture flip. v1.7 lesson: audit before complete-milestone. No Hex 1.8.0 bump; no stop-signal rewrite (already 1.7.0). Returns PROJECT/STATE to maintenance mode assessment already recommended.

---

## Claude's Discretion

- Exact JTBD-MAP editorial wording
- Phase directory archive location (v1.8-phases/ vs in-place)
- v1.8 RETROSPECTIVE inefficiency bullets if audit surfaces process debt

## Deferred Ideas

- CI-01 paths-ignore
- checkout.md status bugs
- Hex 1.8.0 publish
- New milestone until adopter pull
