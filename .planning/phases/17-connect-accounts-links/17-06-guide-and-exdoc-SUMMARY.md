---
phase: 17
plan: "06"
subsystem: connect
tags: [connect, stripe, docs, guides, exdoc]
dependency_graph:
  requires: [17-03, 17-04]
  provides: [guides/connect.md, mix.exs Connect group]
  affects: [HexDocs navigation, developer onboarding narrative]
tech_stack:
  added: []
  patterns: [ExDoc groups_for_modules, ExDoc extras, Connect onboarding narrative]
key_files:
  created:
    - guides/connect.md
  modified:
    - mix.exs
decisions:
  - "Connect group placed after Billing in groups_for_modules — follows wave order"
  - "guides/connect.md placed after subscriptions.md in extras — narrative order"
  - "Two T-17-02 bearer-token warnings included (AccountLink section + LoginLink section)"
metrics:
  duration: "~15 minutes"
  completed: "2026-04-13T00:29:20Z"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 1
---

# Phase 17 Plan 06: Guide and ExDoc Summary

Connect onboarding guide (238 lines, 8 sections) + ExDoc Connect module group (10 modules) wired into mix.exs.

## What Was Built

### Task 1: `guides/connect.md` (238 lines)

Eight sections covering the full Phase 17 developer surface:

| Section | Content |
|---|---|
| Acting on behalf of a connected account | Per-client and per-request `stripe_account:` idiom with full Option 1/2 code examples |
| Creating a connected account | `Account.create/3` example, Express/Standard/Custom account type guidance |
| Onboarding URL flow | Steps 1-3 (create account → account link → redirect), full runnable example, T-17-02 bearer-token warning |
| Login Links | `LoginLink.create/4` example, signature deviation noted, Express-only constraint, T-17-02 repeat |
| Handling capabilities | D-04b rationale, `update/4` nested-map idiom, `Capability.status_atom/1` pattern-match example |
| Rejecting an account | Three valid atoms (`:fraud`, `:terms_of_service`, `:other`), irreversibility warning |
| Webhook handoff | Phase 15 precedent callout, key Connect events table |
| What's next: money movement | Phase 18 forward pointer to payouts guide |

### Task 2: `mix.exs` ExDoc config (2 additions)

- **Connect module group** added after Billing group, 10 modules: `Account`, `AccountLink`, `LoginLink`, `Account.BusinessProfile`, `Account.Capability`, `Account.Company`, `Account.Individual`, `Account.Requirements`, `Account.Settings`, `Account.TosAcceptance`
- **`guides/connect.md` extra** added to extras list after `subscriptions.md`

## Verification Results

- `wc -l guides/connect.md` → 238 lines (above 150 minimum)
- All 18 acceptance criteria grep checks: PASS
- `mix docs` → exits 0, no warnings
- `mix compile --warnings-as-errors` → exits 0
- `doc/LatticeStripe.Account.html` generated and confirmed present
- `grep -l "Connect" doc/*.html` → Account, AccountLink, LoginLink all confirm Connect group in sidebar

## T-17-02 Warning Locations

Both required bearer-token warnings are present:

1. **AccountLink section** (Onboarding URL flow): `> #### Security: link.url is a short-lived bearer token {: .warning}` with explicit guidance against logging/storing
2. **LoginLink section** (Login Links): `> #### Security: link.url is a short-lived bearer token {: .warning}` — repeat warning specific to LoginLink

## mix.exs Diff Summary

Two surgical additions, zero other changes:

```
+          Connect: [
+            LatticeStripe.Account,
+            LatticeStripe.AccountLink,
+            LatticeStripe.LoginLink,
+            LatticeStripe.Account.BusinessProfile,
+            LatticeStripe.Account.Capability,
+            LatticeStripe.Account.Company,
+            LatticeStripe.Account.Individual,
+            LatticeStripe.Account.Requirements,
+            LatticeStripe.Account.Settings,
+            LatticeStripe.Account.TosAcceptance
+          ],
```

```
+          "guides/connect.md",
```

13 lines added total.

## Phase 17 Shippability Confirmation

Phase 17 (Connect Accounts & Account Links) is now complete end-to-end:

| Plan | Contents | Status |
|---|---|---|
| 17-01 | Wave0 bootstrap: stripe-mock fixtures, per-request header regression | DONE |
| 17-02 | Nested structs: 7 modules (BusinessProfile, Requirements, TosAcceptance, Company, Individual, Settings, Capability) | DONE |
| 17-03 | Account resource: CRUD + reject + stream + 51 tests | DONE |
| 17-04 | Link modules: AccountLink + LoginLink + 24 tests | DONE |
| 17-05 | Integration tests: stripe-mock coverage for lifecycle, reject, links | DONE |
| 17-06 | Guide + ExDoc: connect.md (238 lines) + mix.exs Connect group | DONE |

All CNCT-01 requirements are satisfied. Phase 17 is ready to merge.

## Commits

| Task | Commit | Files |
|---|---|---|
| Task 1: guides/connect.md | 874dda9 | guides/connect.md (created, 238 lines) |
| Task 2: mix.exs ExDoc config | 598e7d7 | mix.exs (+13 lines) |

## Deviations from Plan

None — plan executed exactly as written. Both tasks implemented to spec with all acceptance criteria passing on first attempt.

## Known Stubs

None — guide references live modules (`LatticeStripe.Account`, `LatticeStripe.AccountLink`, `LatticeStripe.LoginLink`) with real implementations shipped in Plans 17-03 and 17-04. No placeholder text or TODO items remain.

## Threat Flags

No new security surface introduced. This plan adds documentation only — no network endpoints, auth paths, file access patterns, or schema changes.

## Self-Check: PASSED

- `guides/connect.md` exists: FOUND
- `874dda9` commit exists: FOUND
- `598e7d7` commit exists: FOUND
- `mix.exs` has Connect group: FOUND
- `doc/LatticeStripe.Account.html` exists after mix docs: FOUND
