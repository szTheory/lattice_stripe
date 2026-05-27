---
phase: 48-thin-event-adoption-surface-guide-integration-verification
plan: "03"
subsystem: docs
tags: [webhooks, thin-events, discovery-ladder, jtbd, readme, docs-wiring]
dependency_graph:
  requires: ["48-02"]
  provides: ["GUIDE-03"]
  affects: ["README.md", "guides/webhooks.md", "guides/user-flows-and-jtbd.md"]
tech_stack:
  added: []
  patterns: ["discovery-ladder wiring", "reverse-link grep locks", "D-04 hardening-ops route"]
key_files:
  created: []
  modified:
    - README.md
    - guides/webhooks.md
    - guides/user-flows-and-jtbd.md
decisions:
  - "D-04 discovery wiring: three files updated with four distinct entry points into webhooks-thin-events.md"
  - "No Job 8 added: thin events wired as evolution of Job 7 per Phase 44 D-08 + CONTEXT.md deferred scope discipline"
  - "v1.3 Release status block and install line (~> 1.3) untouched per D-03 sub-decision 3B canary architecture"
metrics:
  duration: "~15 minutes"
  completed_date: "2026-05-27"
---

# Phase 48 Plan 03: Discovery Ladder Wiring for webhooks-thin-events.md Summary

Wire `guides/webhooks-thin-events.md` (created in Plan 02) into four discovery entry points across README.md, guides/webhooks.md, and guides/user-flows-and-jtbd.md per D-04.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Extend README.md hardening-ops route + Webhooks bullet | 3c68eed | README.md |
| 2 | Append Thin events section to guides/webhooks.md | 1c56587 | guides/webhooks.md |
| 3 | Extend user-flows-and-jtbd.md Start Here + Job 7 Read next | 7abf811 | guides/user-flows-and-jtbd.md |

## Edit Locations

### README.md

- **Edit 1 — hardening-ops route** (line 42): Appended `, [Webhooks: Thin Events](guides/webhooks-thin-events.md)` to the hardening-ops route list. Route now contains 4 links: error-handling.md, testing.md, webhooks.md, webhooks-thin-events.md.
- **Edit 2 — Webhooks bullet in Platform section** (line 126): Replaced `Phoenix-ready \`Webhook.Plug\` with raw-body capture and signature verification` with `Phoenix-ready \`Webhook.Plug\` snapshot path + thin-event (\`/v2/events\`) helpers for fetch-after-verify integration`. Surfaces both `thin-event` and `/v2/events` substrings.

### guides/webhooks.md

- **New section appended** (lines 218-224): New `## Thin events (\`/v2/events\`)` closing section after the existing `## See also` block. Contains lowercase `thin events` in body prose (satisfies Plan 04 `=~ "thin event"` grep) and `webhooks-thin-events.md` link target. Line count: 217 → 224 (+7 lines).

### guides/user-flows-and-jtbd.md

- **Edit 1 — Start Here Runtime truth route** (line 94): Appended `, [Webhooks: Thin Events](webhooks-thin-events.md)` to the Runtime truth, support, and debugging route list. Route now contains 4 links: webhooks.md, error-handling.md, testing.md, webhooks-thin-events.md.
- **Edit 2 — Job 7 Read next block** (line 339): Appended `- [Webhooks: Thin Events](webhooks-thin-events.md)` as the 7th and final bullet in the Job 7 Read next list (was 6 bullets).

## Verification Results

| Check | Result |
|-------|--------|
| `grep -c "webhooks-thin-events.md" README.md` | 1 (expected >= 1) |
| `grep -c "thin-event" README.md` | 2 (expected >= 1; both hardening-ops route link + Webhooks bullet) |
| `grep -c "/v2/events" README.md` | 1 (expected >= 1) |
| `grep -c '~> 1.3' README.md` | 1 (expected >= 1; canary preserved) |
| `grep -c "webhooks-thin-events.md" guides/webhooks.md` | 1 (expected >= 1) |
| `grep -c "thin event" guides/webhooks.md` | 2 (expected >= 1; body prose "thin events" + section title) |
| Last H2 in webhooks.md | `## Thin events (\`/v2/events\`)` (expected: new section is last H2) |
| `grep -c "webhooks-thin-events.md" guides/user-flows-and-jtbd.md` | 2 (expected exactly 2: Start Here + Job 7) |
| `grep -c "^## Job 8" guides/user-flows-and-jtbd.md` | 0 (expected 0; no peer Job 8 added) |

## Invariants Preserved

- **v1.3 Release status block**: Unchanged — `git diff` shows no edits in lines 8-11.
- **README install line (`~> 1.3`)**: Unchanged — canary architecture per D-03 sub-decision 3B.
- **JTBD Jobs 1-6 and their Read next blocks**: Byte-identical — only Job 7 Read next extended.
- **Other Start Here routes**: Byte-identical — only Runtime truth route extended.
- **Phase 44 D-08 scope discipline**: No Job 8 added; thin events wired as evolution of Job 7.

## mix docs --warnings-as-errors

Ran against main repo (deps not present in worktree). No cross-reference warnings for `webhooks-thin-events.md` links. Pre-existing warnings in `subscription_schedule.ex` (unrelated to this plan) were present before this plan and are out of scope.

## Deviations from Plan

None — plan executed exactly as written. All three tasks completed with surgical edits matching the exact `<interfaces>` specifications.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. This plan is documentation-only.

## Self-Check: PASSED

- README.md modified: confirmed (commit 3c68eed)
- guides/webhooks.md modified: confirmed (commit 1c56587)
- guides/user-flows-and-jtbd.md modified: confirmed (commit 7abf811)
- All grep assertions satisfied (verified above)
- No Job 8 added (0 matches)
- v1.3 install line preserved (1 match)
