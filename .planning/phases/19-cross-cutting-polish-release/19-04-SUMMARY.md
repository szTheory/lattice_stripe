---
phase: 19
plan: 04
subsystem: release
tags: [release, release-please, changelog, v1-cut, checkpoint]
requires:
  - 19-01 merged (ExDoc module groups + @moduledoc false)
  - 19-02 merged (guide editorial pass, api_stability.md)
  - 19-03 merged (README v1.0 feature groups + readme_test)
provides:
  - release-please-config.json with "release-as": "1.0.0" (D-09)
  - CHANGELOG.md v1.0.0 Highlights narrative, staged for the release-please PR (D-12, D-13, D-14)
  - Documented post-release follow-up (remove release-as, flip bump-minor-pre-major) — NOT executed
affects:
  - v1.0.0 publish (Hex + HexDocs) — blocked on the D-11 human checkpoint
tech-stack:
  added: []
  patterns:
    - "release-as manifest key (not Release-As commit footer) drives 0.x → 1.0 promotion under squash-merge (D-09 + D-10)"
    - "Curated CHANGELOG Highlights live in CHANGELOG.md, not GitHub Release body (D-13)"
key-files:
  created: []
  modified:
    - release-please-config.json
    - CHANGELOG.md
decisions:
  - id: D-09
    summary: "Drove 0.x → 1.0.0 via release-please-config.json release-as key (not commit footer)."
  - id: D-10
    summary: "Avoided Release-As: commit footer; incompatible with squash-merge per release-please-action #952."
  - id: D-11
    summary: "Gated the actual v1.0.0 PR merge / tag publish on a human checkpoint — not auto-advanced."
  - id: D-12
    summary: "Staged a curated CHANGELOG Highlights block for the human to lift onto the release-please PR branch before merge."
  - id: D-13
    summary: "Curated highlights live in CHANGELOG.md (which ships on HexDocs) — Phase 11 D-19 'no manual curation' scopes to GitHub Release bodies only."
  - id: D-14
    summary: "4-sentence Foundation / Billing / Connect / Stability narrative, ~300 words, matching Req/Oban/Phoenix/stripe-node patterns."
metrics:
  duration: "~10m"
  completed: "2026-04-13"
  tasks_completed: 1.5
  tasks_total: 3
  tasks_blocked: 1.5
---

# Phase 19 Plan 04: Release Please 1.0.0 Cut Summary

One-liner: Staged release-please-config.json for 1.0.0 promotion and drafted the CHANGELOG Highlights narrative; the actual release cut (PR merge + Hex publish + tag) is paused at the D-11 human checkpoint.

## What Shipped In This Plan

1. **`release-please-config.json` → `"release-as": "1.0.0"` added** inside `packages."."`. All other keys unchanged — `bump-minor-pre-major: true`, `bump-patch-for-minor-pre-major: false`, `release-type: elixir`, and the `changelog-sections` block are all byte-identical to the pre-task state. `.release-please-manifest.json` untouched (release-please-action will bump it on PR merge). Commit: `a49696d chore(release): promote to 1.0.0 via release-please release-as key`.

2. **`CHANGELOG.md` → v1.0.0 Highlights narrative staged** under the `## [Unreleased]` heading, fenced by an HTML comment that instructs the human (during the Task 2 checkpoint) to lift the `### Highlights` block onto the release-please PR branch directly under the generated `## [1.0.0](...)` heading. The narrative follows D-14 exactly:
   - 4-sentence Foundation / Billing / Connect / Stability paragraph (~150 words)
   - "What's in the box" bullet list (Payments / Billing / Connect / Webhooks / Operational glue)
   - "Upgrading from 0.2.x" note covering the `@moduledoc false` internals
   - "Supported versions" (Elixir 1.15+ on OTP 26+, tested up to 1.19/28)
   Cross-references `guides/api_stability.md` (Plan 19-02 artifact). Commit: `a0abf72 docs(changelog): stage v1.0 highlights narrative for release-please PR`.

## What Is NOT Done (Blocked On The Human Checkpoint)

Per the worktree objective, this agent does NOT auto-advance past D-11. The following steps are intentionally left for the human:

- **Push** the two commits (`a49696d`, `a0abf72`) to `main` — orchestrator / human owns this push.
- **Observe** release-please-action run on the push and open a Release PR titled `chore: release 1.0.0` with a generated `## [1.0.0](...)` heading.
- **Verify** the PR diff shows `+## [1.0.0]` (NOT `+## [0.3.0]`) via `gh pr diff <PR_NUMBER> -- CHANGELOG.md` and that `.release-please-manifest.json` flips from `0.2.0` to `1.0.0`.
- **Check out** the release-please PR branch, move the staged `### Highlights` block from its current Unreleased home to directly below the generated `## [1.0.0](...)` heading, delete the staging HTML comment, commit as `docs(changelog): add v1.0 highlights`, and push.
- **Run `mix ci`** on the PR branch — must be green before merge.
- **Squash-merge** the Release PR via `gh pr merge <PR_NUMBER> --squash --subject "chore: release 1.0.0"`.
- **Watch** the Phase 11 automation fire: release-please workflow → GitHub Release v1.0.0 → Hex publish workflow → `mix hex.publish --yes` → HexDocs.
- **Verify** `mix hex.info lattice_stripe` shows `1.0.0` and `https://hexdocs.pm/lattice_stripe/1.0.0/` renders with the nine D-19 module groups and 16 D-17 guides.

## Follow-up (Task 3) — Documented, NOT Executed

After v1.0.0 is live on Hex, a SEPARATE follow-up PR (NOT in the Release PR itself, so the v1.0.0 tag reflects the `release-as` state) must:

1. Remove `"release-as": "1.0.0"` from `packages."."` — otherwise every subsequent release-please PR would keep proposing 1.0.0 (19-RESEARCH.md Pitfall 3).
2. Flip `"bump-minor-pre-major": true` → `"bump-minor-pre-major": false` — post-1.0 semver cadence (D-08): breaking → major, feat → minor, fix → patch.
3. Leave `"bump-patch-for-minor-pre-major"` as `false` (no change; key is only meaningful pre-1.0).

Commit message: `chore(release): restore normal semver cadence after v1.0.0`.

Acceptance criteria for Task 3 (verifiable when it lands):
- `grep -c '"release-as"' release-please-config.json` returns 0
- `grep -c '"bump-minor-pre-major": false' release-please-config.json` returns 1
- `grep -c '"bump-minor-pre-major": true' release-please-config.json` returns 0
- `python3 -c "import json; json.load(open('release-please-config.json'))"` exits 0
- `git diff --stat` shows only `release-please-config.json`

The next feature commit after that PR merges will open a release PR for 1.1.0 (or 1.0.1 for a fix), confirming normal cadence has resumed.

## Deviations from Plan

**1. [Scope-adjustment — worktree-bounded execution] Task 2 split into two halves**
- **Found during:** Task 2 kickoff.
- **Issue:** The plan's Task 2 is authored for a live environment with network + gh CLI access to the already-open release-please PR. A worktree agent cannot push to main, cannot observe release-please-action, and cannot edit a PR branch that does not yet exist.
- **Fix:** Staged the Highlights narrative inside the existing `## [Unreleased]` block in CHANGELOG.md, wrapped in an HTML comment that is both (a) harmless in rendered Markdown and (b) explicit instructions for the human continuation step. This satisfies the D-12/13/14 content requirement (narrative drafted and committed) while leaving the actual release-please PR mechanics (checkout, move-below-1.0.0-heading, push, ci, squash-merge) for the human.
- **Files modified:** `CHANGELOG.md`
- **Commit:** `a0abf72`
- **Rule:** This is a worktree-execution adaptation, not a Rule 1/2/3 auto-fix.

**2. [Scope-boundary] Task 3 NOT executed in this worktree**
- **Reason:** Task 3 MUST land AFTER v1.0.0 is tagged so that the v1.0.0 release reflects the `release-as` config state. Executing it now would corrupt the release-please state machine.
- **Status:** Documented in this SUMMARY under "Follow-up (Task 3)" for the human/orchestrator to open as a follow-up PR post-release.

## Auth / Network Gates

None encountered — all work in this plan is repo-local config + docs. The human checkpoint covers every network-dependent step (gh PR ops, Hex publish, HexDocs fetch).

## Threat Flags

None. This plan only touches `release-please-config.json` and `CHANGELOG.md`; no new network endpoints, auth paths, file access, or schema changes introduced beyond the `threat_model` in PLAN.md.

## Known Stubs

None.

## Self-Check: PASSED

- release-please-config.json: FOUND, `"release-as": "1.0.0"` present, valid JSON, `bump-minor-pre-major: true` still present (NOT flipped), `.release-please-manifest.json` untouched, no workflow files touched.
- CHANGELOG.md: FOUND, `### Highlights` section staged under `## [Unreleased]` with staging HTML comment.
- Commits:
  - `a49696d chore(release): promote to 1.0.0 via release-please release-as key` — FOUND
  - `a0abf72 docs(changelog): stage v1.0 highlights narrative for release-please PR` — FOUND

## Commits

| Task | Description | Commit |
|------|-------------|--------|
| 1 | release-please-config.json `release-as: 1.0.0` | a49696d |
| 2 (staged) | CHANGELOG.md v1.0 Highlights narrative staged for the release-please PR | a0abf72 |
| 2 (merge/publish) | Release PR merge + Hex publish | BLOCKED on D-11 human checkpoint |
| 3 | Post-release config cleanup | BLOCKED until v1.0.0 tagged on Hex |
