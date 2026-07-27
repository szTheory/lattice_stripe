# Phase 60: CI Gate & Milestone Close - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 60-CI Gate & Milestone Close
**Areas discussed:** CI gate scope, Workflow approval, JTBD-MAP refresh, Milestone close depth
**Mode:** All areas auto-selected; research via parallel subagents + prompts subdir cross-reference; user requested one-shot coherent recommendations

---

## CI gate scope

| Option | Description | Selected |
|--------|-------------|----------|
| Remove `guides/**` only | Fixes guide PRs; README still bypasses CI | |
| Remove `guides/**` + `**.md`; keep `.planning/**` | Full CI on all user-facing docs; single required check | ✓ |
| Dedicated `docs_truth` workflow | ~1 min doc PRs; two required checks; path-list maintenance | |
| Shell fast-path in test job | Conditional `mix test` scope via git diff | |

**User's choice:** Remove `guides/**` + `**.md`; keep `.planning/**` only; full existing CI (Approach 4 / D-04..D-07)
**Notes:** Subagent research + `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` align: docs are product; skip-docs CI is anti-pattern. Req/Ecto/Phoenix/Broadway + stripe-node/python/ruby run full CI. `cheatsheet.cheatmd` covered because `guides/**` no longer ignored. Cost ~5–8 min/doc PR acceptable for maintenance-mode library.

---

## Workflow change approval

| Option | Description | Selected |
|--------|-------------|----------|
| Discuss-phase CONTEXT as approval record | D-01 block in 60-CONTEXT.md | ✓ |
| Separate chat sign-off only | Ephemeral; agents won't find it | |
| PR description only | Too late for GSD pre-edit execution | |
| ADR | Overkill for paths-ignore narrowing | |

**User's choice:** Phase 60 discuss with directive to research and lock decisions = explicit scoped approval (D-01..D-03)
**Notes:** STATE.md blocker cleared by recording approval in CONTEXT. Commit message references D-01. No workflow changes beyond paths-ignore.

---

## JTBD-MAP & planning truth

| Option | Description | Selected |
|--------|-------------|----------|
| Strong upgrade in Plan 1 with CI | Atomic but mixes CI + planning commits | |
| Strong upgrade in Plan 2; not blocked on CI-01 | Phase 58 payments precedent | ✓ |
| Wait for CI-01 before Strong | Misleading Partial rating post-Phase 59 | |
| Full Gap 3 collapse before CI-01 | Dishonest about enforcement | |

**User's choice:** Plan 1 = CI only; Plan 2 = JTBD Strong + Gap 3 collapse + resolved gaps + maintenance-first priority (D-08..D-15)
**Notes:** Hosted checkout row mirrors one-time payments. README note on Public package/docs row. Gap 3 removal and priority flip blocked until CI-01 merges.

---

## Milestone close depth

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal-but-audit-complete (2 plans) | CI + close ritual; Phase 59 has VERIFICATION | ✓ |
| v1.8 Phase 58 thorough (5 plans) | Overkill for 2-phase doc-only milestone | |
| Backfill 54-VERIFICATION now | Zero adopter impact; synthetic reconstruction | |
| Defer 54-VERIFICATION again | Third carry; record in audit tech_debt | ✓ |

**User's choice:** Minimal-but-audit-complete; defer PLAN-01 (D-16..D-19)
**Notes:** No Hex bump. Optional `v1.9` planning tag. Update CONTRIBUTING.md L83 in Plan 1.

---

## Claude's Discretion

- Exact JTBD-MAP prose wording
- Optional v1.9 git tag in Plan 2
- Live verification bash block in milestone audit

## Deferred Ideas

- 54-VERIFICATION backfill (PLAN-01)
- Dedicated docs_truth workflow (future if CI minutes become pain point)
- actionlint + CODEOWNERS on workflows
- payments.md wire-string comments; getting-started link format drift
