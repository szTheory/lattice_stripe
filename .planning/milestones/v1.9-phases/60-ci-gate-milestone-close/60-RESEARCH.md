# Phase 60: CI Gate & Milestone Close — Research

**Researched:** 2026-05-27
**Phase:** 60-ci-gate-milestone-close
**Status:** Complete

## RESEARCH COMPLETE

## Summary

Phase 60 closes v1.9 with a **minimal two-plan split** already locked in CONTEXT: Plan 1 narrows CI `paths-ignore` (CI-01); Plan 2 refreshes JTBD-MAP and runs milestone-close artifacts (JTBD-01). PLAN-01 (`54-VERIFICATION.md` backfill) is explicitly deferred for the third time.

The correct CI fix is a **6-line deletion** in `.github/workflows/ci.yml` — remove `**.md` and `guides/**` from both `push` and `pull_request` `paths-ignore`, leaving only `.planning/**`. No new jobs, filters, or permissions. `docs_truth_test.exs` already runs inside the existing `test` job via `mix test`; full CI on doc PRs is the idiomatic Elixir OSS pattern and matches CONTEXT D-04..D-07.

## CI Workflow Analysis

### Current state (`.github/workflows/ci.yml`)

```yaml
paths-ignore:
  - "**.md"
  - ".planning/**"
  - "guides/**"
```

Both `push` (main) and `pull_request` triggers use identical ignores. Effect: any PR touching only `guides/**`, root `README.md`, or other `*.md` files skips **all three jobs** (lint, test matrix, integration) — including the 26 `docs_truth` tests in the test job.

### Target state (CI-01)

```yaml
paths-ignore:
  - ".planning/**"
```

**Triggers CI on:** `guides/**`, `README.md`, `guides/cheatsheet.cheatmd`, any root or nested `*.md` outside `.planning/`.

**Still skips CI on:** `.planning/**` only — planning edits remain fast; no adopter-facing doc risk.

### Rejected alternatives (from CONTEXT + OSS survey)

| Option | Why rejected |
|--------|--------------|
| Remove `guides/**` only, keep `**.md` | README and cheatsheet still unguarded |
| Dedicated `docs_truth` workflow + path filter | Two required checks, path-list drift, branch-protection footguns |
| Shell `git diff` fast-path in existing job | Fragile, surprising to contributors |

### Cost / tradeoff

- Doc-only PR CI: ~5–8 minutes (lint + 3-matrix test + integration with stripe-mock).
- Acceptable for maintenance-mode library with infrequent doc edits (CONTEXT D-06).
- Payoff: Phase 59 per-surface `docs_truth` describes become **enforced**, not theater.

### CONTRIBUTING.md alignment

Line 83 currently states docs-only PRs "may require maintainer bypass" because CI is skipped. After CI-01, replace with note that docs/guide changes run full CI including `docs_truth_test.exs`.

### Commit message requirement (D-03)

Must document CI-01 rationale and reference `60-CONTEXT.md` D-01 approval. Suggested subject:

`ci: narrow paths-ignore so guide/md PRs run docs_truth (CI-01)`

## JTBD-MAP Refresh (JTBD-01)

### Hosted checkout row (L88)

**Current:** `Partial` narrative — stale bug text from pre-Phase 59 assessment.

**Target (D-10):** `Strong` with text mirroring one-time payments row pattern:

`Shipped; checkout.md examples fixed (Phase 59) + docs_truth locked`

### Public package/docs row (D-11)

Append to existing narrative: `README error taxonomy locked (Phase 59)`.

### Gap 3 section (L128–133)

**Remove entirely** after CI-01 — all three items resolved:
- checkout.md atoms + callout + docs_truth (Phase 59)
- README error taxonomy (Phase 59)
- CI-01 (Phase 60 Plan 1)

### Biggest Gaps intro (D-12)

Update to v1.9 close wording — doc/CI honesty wedge closed.

### Resolved gaps bullets (D-13)

Add Phase 59 items + Phase 60 CI-01 item under resolved section.

### Recommended Priority Order (D-14)

Flip to **maintenance-first** (#1) only after CI-01 merges. Remove v1.9 recommended line.

**Sequencing note (D-15):** Strong narrative upgrade for hosted checkout is **not blocked** on CI-01 (can edit in Plan 2). Gap 3 removal and priority flip **are blocked** on CI-01 landing first — Plan 2 depends on Plan 1 in execution order.

## Milestone Close Playbook

Follow v1.8 audit structure (`milestones/v1.8-MILESTONE-AUDIT.md`):

1. **60-VERIFICATION.md** — cross-reference Phase 59 VERIFICATION + Plan 1 CI evidence + JTBD edits
2. **milestones/v1.9-MILESTONE-AUDIT.md** — frontmatter scores, tech_debt (PLAN-01 third carry), live verification bash block
3. **Archive** — copy active `.planning/ROADMAP.md` → `milestones/v1.9-ROADMAP.md`; copy `.planning/REQUIREMENTS.md` → `milestones/v1.9-REQUIREMENTS.md`
4. **MILESTONES.md** — prepend v1.9 section
5. **RETROSPECTIVE.md** — prepend v1.9 section (sibling-guide audit lesson: payments fixed → checkout missed)
6. **PROJECT.md** — latest shipped v1.9; maintenance posture; done ~94–96%
7. **STATE.md** — `status: maintenance`; clear CI-01 blocker; percent complete

### PLAN-01 deferral (D-17)

Record in v1.9 audit `tech_debt`:
- `54-VERIFICATION.md` still missing — third carry from v1.7/v1.8
- Zero adopter impact; synthetic reconstruction without Phase 54 SUMMARY files

### No Hex bump (D-18)

`@version` stays `1.7.0`. Optional git tag `v1.9` (planning tag, not `v1.9.0`) — executor discretion in Plan 2.

## Validation Architecture

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix |
| **Quick command** | `mix test test/lattice_stripe/docs_truth_test.exs` |
| **Full command** | `mix test` |
| **CI proof** | Workflow file grep + local docs_truth green |

### Per-plan verification

| Plan | Primary verify |
|------|----------------|
| 60-01 | `rg` ci.yml paths-ignore; CONTRIBUTING L83; `mix test docs_truth` |
| 60-02 | JTBD-MAP grep targets; 60-VERIFICATION.md exists; audit frontmatter |

### Manual-only

- GitHub Actions run on a doc-only PR (post-merge) — confirms CI actually triggers; optional smoke, not blocking Plan 1 acceptance if workflow YAML is correct.

## Standard Stack

No new dependencies. Existing: GitHub Actions, erlef/setup-beam, stripe-mock service, ExUnit.

## File Impact Summary

| File | Plan | Change |
|------|------|--------|
| `.github/workflows/ci.yml` | 60-01 | Remove `**.md`, `guides/**` from paths-ignore |
| `CONTRIBUTING.md` | 60-01 | Fix L83 CI note |
| `.planning/STATE.md` | 60-01, 60-02 | Clear CI-01 blocker; maintenance close |
| `.planning/JTBD-MAP.md` | 60-02 | Strong checkout, Gap 3 removal, priority flip |
| `.planning/phases/60-.../60-VERIFICATION.md` | 60-02 | New |
| `.planning/milestones/v1.9-MILESTONE-AUDIT.md` | 60-02 | New |
| `.planning/milestones/v1.9-ROADMAP.md` | 60-02 | Archive copy |
| `.planning/milestones/v1.9-REQUIREMENTS.md` | 60-02 | Archive copy |
| `.planning/MILESTONES.md` | 60-02 | Prepend v1.9 |
| `.planning/RETROSPECTIVE.md` | 60-02 | Prepend v1.9 |
| `.planning/PROJECT.md` | 60-02 | v1.9 shipped, maintenance |
| `.planning/ROADMAP.md` | 60-02 | Maintenance mode stub |

## Risks

| Risk | Mitigation |
|------|------------|
| Maintainer forgets CI now runs on docs | CONTRIBUTING.md update in Plan 1 |
| Plan 2 edits Gap 3 before CI-01 merges | `depends_on: [60-01]` on Plan 2 |
| Over-scoping milestone close | CONTEXT D-16: 2 plans only, defer PLAN-01 |

---

*Research complete — ready for planning*
