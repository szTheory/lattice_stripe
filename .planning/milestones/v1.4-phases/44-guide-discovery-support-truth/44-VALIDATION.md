---
phase: 44
slug: guide-discovery-support-truth
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-26
---

# Phase 44 - Validation Strategy

> Per-phase validation contract for guide discovery, support-truth, and docs-routing regression coverage.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit plus grep-backed docs assertions |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | ~10-30 seconds for targeted docs-truth checks |

## Sampling Rate

- After each task commit: run the task’s `<automated>` command
- After Plan 01: `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors`
- After Plan 02: rerun the targeted docs-truth test plus the phase grep assertions over the touched discovery guides
- Before `$gsd-verify-work`: targeted docs-truth tests must be green and the route-by-intent / support-truth anchors must be present in the public entry surfaces

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 44-01-01 | 01 | 1 | GUIDE-01 | T-44-01 | README, Getting Started, JTBD, and recipes expose clear paths into subscriptions, customer portal, metering, Connect, and trust rails | grep | `rg -n 'user-flows-and-jtbd|subscriptions|customer-portal|metering|connect|webhooks|testing|error-handling|recipes' README.md guides/getting-started.md guides/user-flows-and-jtbd.md guides/recipes.md` | ✅ | ⬜ pending |
| 44-01-02 | 01 | 1 | GUIDE-01, GUIDE-02 | T-44-02 | ExDoc grouping distinguishes entry points, canonical guides, and operations/DX guidance without replacing `getting-started` as main | unit + grep | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors && rg -n 'main: \"getting-started\"|groups_for_extras|Start Here|Canonical|Operations|DX|Guides' mix.exs test/lattice_stripe/docs_truth_test.exs` | ✅ | ⬜ pending |
| 44-02-01 | 02 | 2 | GUIDE-02 | T-44-03 | High-leverage canonical guides include honest inline support-truth notes and explicit read-next routing to the right follow-through guides | grep | `rg -n 'webhooks confirm reality|authoritative|redirect|accepted now|became true|See also|Read next' guides/webhooks.md guides/testing.md guides/error-handling.md guides/subscriptions.md guides/customer-portal.md guides/metering.md guides/connect.md guides/connect-accounts.md guides/connect-money-movement.md` | ✅ | ⬜ pending |
| 44-02-02 | 02 | 2 | VERIFY-02 | T-44-04 | Docs-truth tests fail when discovery links, entry roles, or support-truth route anchors drift on the public onboarding surfaces | unit | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` | ✅ | ⬜ pending |

## Wave-Level Verification

- After Plan 01: `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors && rg -n 'user-flows-and-jtbd|subscriptions|customer-portal|metering|connect|webhooks|testing|error-handling|groups_for_extras|getting-started' README.md guides/getting-started.md guides/user-flows-and-jtbd.md guides/recipes.md mix.exs`
- After Plan 02: `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors && rg -n 'webhooks confirm reality|authoritative|redirect|accepted now|became true|See also|Read next' guides/webhooks.md guides/testing.md guides/error-handling.md guides/subscriptions.md guides/customer-portal.md guides/metering.md guides/connect.md guides/connect-accounts.md guides/connect-money-movement.md`
- Before verification handoff: `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors && rg -n 'user-flows-and-jtbd|subscriptions|customer-portal|metering|connect|webhooks|testing|error-handling|authoritative|redirect' README.md guides/getting-started.md guides/user-flows-and-jtbd.md guides/recipes.md guides/webhooks.md guides/customer-portal.md guides/error-handling.md`

## Wave 0 Requirements

- [ ] `.planning/phases/44-guide-discovery-support-truth/44-01-PLAN.md` exists
- [ ] `.planning/phases/44-guide-discovery-support-truth/44-02-PLAN.md` exists

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The public docs ladder feels intentional instead of flat | GUIDE-01 | Grep can prove links exist but not whether the route hierarchy is obvious | Read `README.md` and `guides/getting-started.md` top-to-bottom and confirm the next step for a serious SaaS evaluator is obvious at each stage |
| Support-truth notes are honest but not overbearing | GUIDE-02 | Only a human can judge tone and repetition | Read the touched canonical guides and confirm the caveats are visible at the right action points without turning the docs into apology text |
| Discovery tests assert durable route anchors rather than prose snapshots | VERIFY-02 | Only a human can judge brittleness | Review `test/lattice_stripe/docs_truth_test.exs` and confirm assertions target links, guide roles, or short truth markers rather than long paragraphs |

## Validation Sign-Off

- [x] All tasks have automated verification
- [x] Sampling continuity is adequate for a small docs-routing phase
- [x] No watch-mode or interactive dependencies
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-26
