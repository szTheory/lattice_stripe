---
phase: 37
slug: dx-polish
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-25
---

# Phase 37 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with existing unit/integration structure plus `mix docs` for docs build verification |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/lattice_stripe/testing_test.exs` |
| **Full suite command** | `mix ci` |
| **Docs verification** | `mix docs --warnings-as-errors` |
| **Estimated runtime** | ~30 seconds for targeted checks; longer for full suite |

---

## Sampling Rate

- **After every task commit:** Run the task’s `<automated>` command
- **After every plan wave:** Run the wave-level command listed below
- **Before `/gsd-verify-work`:** Run `mix ci` and `mix docs --warnings-as-errors`
- **Max feedback latency:** ~30 seconds for targeted checks

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 37-01-01 | 01 | 1 | DX-02 | T-37-01 | Public fixture builders return stable Stripe-shaped raw maps for all v1.3 families | unit | `mix test test/lattice_stripe/testing_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 37-01-02 | 01 | 1 | DX-02 | T-37-02 | Typed/event/webhook wrapper helpers stay explicit and align with existing `LatticeStripe.Testing` contracts | unit | `mix test test/lattice_stripe/testing_test.exs --warnings-as-errors` | ✅ | ⬜ pending |
| 37-02-01 | 02 | 2 | DX-01 | T-37-03 | Webhook guide teaches one canonical Phoenix path, raw-body invariant, and runtime secret resolution | docs build + manual | `mix docs --warnings-as-errors` | ✅ | ⬜ pending |
| 37-02-02 | 02 | 2 | DX-02, DX-03 | T-37-04 | Testing and recipes guides reference real public helpers and stay library-scoped | docs build + manual | `mix docs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 37-03-01 | 03 | 3 | DX-04 | T-37-05 | README, changelog, guide index, and ExDoc extras reflect the current v1.3-capable surface | docs build + unit | `mix test test/lattice_stripe/testing_test.exs --warnings-as-errors && mix docs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 37-03-02 | 03 | 3 | DX-04 | T-37-06 | Version/install snippets and high-visibility cross-links do not drift from actual package/docs configuration | unit or grep-backed test | `mix test test/lattice_stripe/testing_test.exs --warnings-as-errors` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave-Level Verification

- **After Plan 01:** `mix test test/lattice_stripe/testing_test.exs --warnings-as-errors`
- **After Plan 02:** `mix docs --warnings-as-errors`
- **After Plan 03:** `mix test test/lattice_stripe/testing_test.exs --warnings-as-errors && mix docs --warnings-as-errors`

---

## Wave 0 Requirements

- [ ] `lib/lattice_stripe/testing/fixtures/` public modules for all v1.3 resource families
- [ ] `guides/recipes.md`
- [ ] `mix.exs` docs extras entry for `guides/recipes.md`
- [ ] any new docs-truth tests introduced by the phase

*Existing ExUnit and docs infrastructure covers the rest.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Canonical webhook path is obvious to a new Phoenix user | DX-01 | Automated checks cannot judge guide clarity or recommendation hierarchy | Read `guides/webhooks.md` top-to-bottom and confirm the first complete setup path is `Webhook.Plug` in `endpoint.ex` before `Plug.Parsers`, with the advanced alternative clearly demoted |
| Recipes stay library-scoped and do not drift into Accrue-style orchestration | DX-03 | Scope quality is conceptual, not structural | Review each recipe in `guides/recipes.md` and confirm it teaches LatticeStripe calls, webhook handoff, and next-guide links without product-level orchestration helpers |
| Public trust surfaces are visibly aligned | DX-04 | Humans notice contradiction patterns faster than brittle string tests | Compare `README.md`, `CHANGELOG.md`, and `mix.exs` version/docs references and confirm they tell one coherent story |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references
- [x] No watch-mode flags
- [x] Feedback latency acceptable for docs-heavy work
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-25
