---
phase: 45
slug: flagship-recipes-i
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-26
---

# Phase 45 - Validation Strategy

> Per-phase validation contract for flagship recipe publication, discovery, and support-truth regression coverage.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit plus grep-backed docs assertions |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci` |
| **Estimated runtime** | ~10-30 seconds for targeted docs-truth checks |

## Sampling Rate

- After each task commit: run the task's `<automated>` command
- After Plan 01: rerun `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors`
- After Plan 02: rerun the targeted docs-truth test plus grep assertions over the flagship guides and their routing pages
- Before `$gsd-verify-work`: flagship guide publication, route anchors, and key support-truth notes must be green in both flagship paths

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 45-01-01 | 01 | 1 | RECIPE-01 | T-45-01, T-45-02, T-45-03 | The recurring-billing flagship guide recommends one safe hosted path, keeps webhook truth explicit, and names the main signup/portal footguns inline | grep | `rg -n 'Checkout|portal|webhook|redirect|payment_method_update|subscription_cancel|session.url|Read next' guides/checkout-signup-and-portal.md` | ❌ W0 | ⬜ pending |
| 45-01-02 | 01 | 1 | RECIPE-01, GUIDE-02, VERIFY-02 | T-45-03 | The recurring-billing flagship guide is discoverable from task-first routing pages, published in ExDoc, and protected by docs-truth assertions | unit + grep | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors && rg -n 'checkout-signup-and-portal|customer-portal|webhooks|groups_for_extras' guides/recipes.md guides/user-flows-and-jtbd.md guides/checkout.md guides/subscriptions.md guides/customer-portal.md guides/webhooks.md mix.exs test/lattice_stripe/docs_truth_test.exs` | ✅ shared / ❌ new guide | ⬜ pending |
| 45-02-01 | 02 | 2 | RECIPE-02 | T-45-04, T-45-05, T-45-06 | The metering flagship guide teaches runtime-first event ingestion, async reconciliation, correction, and replay posture without overclaiming synchronous truth | grep | `rg -n 'identifier|idempot|webhook|MeterEventAdjustment|accepted|reconcile|testing|Read next' guides/metering-runtime-and-reconciliation.md` | ❌ W0 | ⬜ pending |
| 45-02-02 | 02 | 2 | RECIPE-02, GUIDE-02, VERIFY-02 | T-45-06 | The metering flagship guide is discoverable from task-first routing pages, published in ExDoc, and protected by docs-truth assertions | unit + grep | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors && rg -n 'metering-runtime-and-reconciliation|MeterEventAdjustment|webhooks|testing|error-handling|groups_for_extras' guides/recipes.md guides/user-flows-and-jtbd.md guides/metering.md guides/webhooks.md guides/testing.md guides/error-handling.md mix.exs test/lattice_stripe/docs_truth_test.exs` | ✅ shared / ❌ new guide | ⬜ pending |

## Wave-Level Verification

- After Plan 01: `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors && rg -n 'checkout-signup-and-portal|customer-portal|webhooks|payment_method_update|subscription_cancel|session.url' guides/checkout-signup-and-portal.md guides/recipes.md guides/user-flows-and-jtbd.md guides/checkout.md guides/subscriptions.md guides/customer-portal.md guides/webhooks.md mix.exs test/lattice_stripe/docs_truth_test.exs`
- After Plan 02: `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors && rg -n 'metering-runtime-and-reconciliation|identifier|idempot|MeterEventAdjustment|accepted|reconcile|webhooks|testing|error-handling' guides/metering-runtime-and-reconciliation.md guides/recipes.md guides/user-flows-and-jtbd.md guides/metering.md guides/webhooks.md guides/testing.md guides/error-handling.md mix.exs test/lattice_stripe/docs_truth_test.exs`
- Before verification handoff: `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors && rg -n 'checkout-signup-and-portal|metering-runtime-and-reconciliation|webhook|redirect|session.url|identifier|idempot|MeterEventAdjustment' guides/recipes.md guides/user-flows-and-jtbd.md guides/*.md test/lattice_stripe/docs_truth_test.exs mix.exs`

## Wave 0 Requirements

- [ ] `.planning/phases/45-flagship-recipes-i/45-01-PLAN.md` exists
- [ ] `.planning/phases/45-flagship-recipes-i/45-02-PLAN.md` exists
- [ ] `guides/checkout-signup-and-portal.md` planned as a new published guide
- [ ] `guides/metering-runtime-and-reconciliation.md` planned as a new published guide

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The flagship guides feel fuller than `guides/recipes.md` without competing with canonical guides | RECIPE-01, RECIPE-02 | Grep can prove anchors but not whether the layering still feels honest | Read each flagship guide top-to-bottom and confirm it recommends one safe path, then routes outward instead of trying to replace Checkout, Portal, Metering, or Webhooks docs |
| Checkout and metering caveats are visible at the action point instead of buried | RECIPE-01, RECIPE-02 | Only a human can judge whether the warnings are timely and proportionate | Check that redirect truth, portal URL handling, async acceptance, idempotency, and correction posture appear exactly where those actions are introduced |
| Docs-truth assertions remain durable rather than prose-fragile | VERIFY-02 | Only a human can judge brittleness | Review `test/lattice_stripe/docs_truth_test.exs` and confirm assertions target filenames, route markers, or short truth anchors rather than long paragraphs |

## Validation Sign-Off

- [x] All tasks have automated verification
- [x] Sampling continuity is adequate for a small docs phase
- [x] No watch-mode or interactive dependencies
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-26
