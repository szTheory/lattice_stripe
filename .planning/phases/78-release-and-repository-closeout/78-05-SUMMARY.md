---
phase: 78-release-and-repository-closeout
plan: 05
subsystem: release
tags: [release-please, hex, github, release-gate]
requires:
  - phase: 78-01
    provides: Exact-SHA post-publication evidence verifier
  - phase: 78-02
    provides: Release candidate compatibility preflight and protected merge workflow
  - phase: 78-03
    provides: Current open-PR disposition ledger and checker
provides:
  - Recorded hold for the unqualified 2.3.0 release candidate
  - Current evidence and concrete blockers required before a new release decision
affects: [release-closeout]
actuals:
  tokens: 1500
  tasks: 1
  commits: 4
tech-stack:
  added: []
  patterns: [Fail closed on missing candidate, unsynchronized release history, or dirty primary checkout]
key-files:
  created: [.planning/phases/78-release-and-repository-closeout/78-05-SUMMARY.md]
  modified: [.planning/STATE.md]
key-decisions:
  - "Hold publication; no concrete Release Please candidate exists to approve."
  - "Do not push the unreconciled local main history or touch unrelated dirty files as a release workaround."
patterns-established:
  - "A release decision is recorded only against a current candidate head after the candidate preflight passes."
requirements-completed: []
duration: 9min
completed: 2026-09-25
status: halted
---

# Phase 78 Plan 05: Release Candidate Decision Summary

**Publication of 2.3.0 is held because the required candidate and synchronized, clean release state are not available.**

## Decision

Hold the current release attempt. The requested publish checkpoint could not be satisfied: the candidate preflight failed before a concrete Release Please head could be reviewed. No push, merge, tag, or publication was performed.

## Evidence captured

- `bash scripts/maintainer/release_candidate_check.sh` blocked: expected one open Release Please PR, found zero.
- At pre-decision capture after refreshing `origin/main`, local `main` was 95 commits ahead and zero behind; `origin/main` was `a318624dbcf45546d66a4aaaece19dff42ba13ad`, while local `main` was `b88ce4a375fc7b986a15112c8053b1dd19dec7da`. The three hold-record commits already bring local `main` to 98 commits ahead, and this summary update will bring it to 99 ahead of that remote ref.
- The local API lock delta from `v2.2.2` is the four reviewed additions: `Invoice.amount_paid_off_stripe`, `Refund.customer`, `Refund.customer_account`, and `Refund.payment_method`. The default API version remains `2026-03-25.dahlia`.
- No local `v2.3.0` tag exists.
- Open PR #66 at `9b6d29dcf565cf03a529f8086eb3c3d93d985b27` has failing `Quality` and `ci-gate` checks and no maintainer reviews. Open PR #67 at `b88ce4a375fc7b986a15112c8053b1dd19dec7da` is a draft; its `Quality` and `ci-gate` checks also fail.
- The primary checkout contains unrelated modifications to `.agents/skills/lattice-verification-policy/SKILL.md`, `.planning/PROJECT.md`, `.planning/phases/75-typed-contract-updates/75-VERIFICATION.md`, and `.planning/state.json`, plus untracked `.gsd/`, `.planning/milestone.lock`, and `.planning/phases/76-phoenix-adopter-core-flow/COVERAGE.md`. These files were preserved.

## Issues and next actions

Plan 78-06 remains blocked by its explicit precondition: the exact candidate must first be approved for publication. Revisit only after a new Release Please PR exists, the local release history is integrated through normal protected review, the primary checkout is clean, the PR disposition ledger is current, and candidate preflight passes on the exact head. Then request approval for that concrete one-way transition.

---
*Phase: 78-release-and-repository-closeout*
*Completed: 2026-09-25*
