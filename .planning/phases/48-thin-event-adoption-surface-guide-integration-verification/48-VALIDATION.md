---
phase: 48
slug: thin-event-adoption-surface-guide-integration-verification
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-27
---

# Phase 48 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
>
> Source: `48-RESEARCH.md` §"Validation Architecture". Phase 48 is a docs+tests phase with zero new public `lib/` API surface (apart from one `@moduledoc` substring edit). Dimension 8 is satisfied via tests + docs-truth grep, not via synthesized property tests.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir stdlib) + Mox `~> 1.2` (existing dev/test dep, configured in `test/test_helper.exs`) |
| **Config file** | `test/test_helper.exs` — existing, no changes needed |
| **Quick run command** | `mix test test/lattice_stripe/webhook/thin_event_test.exs test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` |
| **Full suite command** | `mix test --warnings-as-errors` |
| **CI gate command** | `mix ci` (existing alias: format check + warnings-as-errors compile + Credo strict + full test suite + docs --warnings-as-errors) |
| **Estimated runtime (quick)** | ~5 seconds (small new file + docs-truth greps) |
| **Estimated runtime (full)** | ~25 seconds (entire 177-test suite + Phase 48 additions) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/webhook/thin_event_test.exs test/lattice_stripe/docs_truth_test.exs --warnings-as-errors`
- **After every plan wave:** Run `mix test --warnings-as-errors`
- **Before `/gsd:verify-work`:** `mix ci` must be green
- **Max feedback latency:** ~5 seconds (quick), ~25 seconds (full)

---

## Per-Task Verification Map

> Populated by the planner. Each task in each PLAN.md gets a row here once planning lands.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 48-XX-YY | XX | N | GUIDE-03 / VERIFY-03 | — | N/A — docs+tests; no new lib/ surface beyond `@moduledoc` edit | docs-truth grep / integration (Mox) | `mix test test/lattice_stripe/docs_truth_test.exs -x` or `mix test test/lattice_stripe/webhook/thin_event_test.exs -x` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Wave 0 (test infrastructure) for Phase 48 has NO framework install — Mox + ExUnit are pre-existing. Wave 0 work is **creating the stubs** the rest of the phase asserts against:

- [ ] `test/lattice_stripe/webhook/thin_event_test.exs` — new file with 5 `describe` blocks (per `48-RESEARCH.md` test idiom template). Stubs OK at Wave 0; full bodies fill in during the plan's main wave.
- [ ] `test/lattice_stripe/docs_truth_test.exs` — extension stubs for D-03 sub-decisions 3A/3B/3C/3D/3E. The new `test "..."` blocks may be present (skipping or pending) before the guide content lands; assertions fail until the guide is shipped.
- [ ] `guides/webhooks-thin-events.md` — new file, even a header-only stub OK at Wave 0 so docs-truth tests can flip from RED → GREEN incrementally.

Mox at `LatticeStripe.Transport` boundary is already configured via the existing `LatticeStripe.MockTransport` (used by `test/lattice_stripe/webhook/fetch_test.exs`). No new Mox setup required.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ExDoc rendering of `guides/webhooks-thin-events.md` in `Operations & DX` group | GUIDE-03 | Automated docs-truth grep locks the `mix.exs` config + extras list; **visual rendering** of the rendered HTML (headings, code blocks, cross-link anchors resolving) is harder to assert automatically. | `mix docs --warnings-as-errors && open doc/index.html` — confirm guide appears under `Operations & DX` group, all code blocks render, all cross-links to `webhooks.md`/`testing.md`/`error-handling.md` resolve. |
| Hex.pm `mix.exs` `package: extra_files` includes the new guide (release-prep, deferred) | — | Out of Phase 48 scope (the v1.5 install-line refresh and package file list flip is deferred per CONTEXT.md `<deferred>`). | N/A — release-prep step, not Phase 48. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < ~5s for quick runs
- [ ] `nyquist_compliant: true` set in frontmatter once planner fills the per-task map

**Approval:** pending — planner populates the per-task map; validation auditor confirms during execution.
