# Phase 43: Public Truth Baseline - Research

**Researched:** 2026-05-26  
**Domain:** public docs truth and onboarding-surface regression coverage for the shipped `1.3.x` line  
**Confidence:** HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRUTH-01 | Public package, version, and install guidance agrees across README, CHANGELOG, `guides/getting-started.md`, cheatsheet, and HexDocs-facing extras. | Repo currently shows concrete drift: `README.md` and `guides/cheatsheet.cheatmd` say `~> 1.3`, while `guides/getting-started.md` still says `~> 1.2`. `mix.exs` publishes `1.3.0` and exposes `guides/getting-started.md`, `guides/cheatsheet.cheatmd`, and `CHANGELOG.md` to HexDocs. |
| TRUTH-02 | High-visibility docs accurately present the shipped `1.3.x` surface, including the major resource families and DX guides already in repo truth. | README and CHANGELOG already advertise the v1.3 surface; plan work should reconcile the rest of the onboarding/public surfaces rather than invent new marketing copy. |
| VERIFY-01 | Docs-truth regression checks fail when first-run onboarding install/version snippets drift from the shipped package line. | `test/lattice_stripe/docs_truth_test.exs` currently only asserts README version truth and that ExDoc includes `guides/recipes.md`, so onboarding drift like the stale Getting Started snippet can pass undetected. |
</phase_requirements>

## Summary

Phase 43 is a public-docs truth phase, not a feature-delivery phase. The repo already ships the `1.3.x` surface in code, changelog, README, ExDoc extras, and testing fixtures; the remaining problem is that a new adopter can still hit at least one first-run doc that understates the published line and the broader shipped surface.

The concrete mismatch is already visible in repo truth: `guides/getting-started.md` tells users to install `{:lattice_stripe, "~> 1.2"}` while `README.md`, `guides/cheatsheet.cheatmd`, `CHANGELOG.md`, and `mix.exs` all point at the shipped `1.3` line. The existing docs-truth regression test is too narrow to catch this because it only reads `README.md` and ExDoc extras.

**Primary recommendation:** split the phase into:
1. a reconciliation pass over the highest-visibility public docs surfaces; and
2. a regression-coverage pass that turns those public-truth expectations into targeted ExUnit assertions against the actual onboarding surfaces.

## Verified Current Truth

### Installation and published-version story

- `mix.exs` declares `@version "1.3.0"`.
- `README.md` install snippet uses `{:lattice_stripe, "~> 1.3"}` and calls the `1.3.x` line the current published surface.
- `guides/cheatsheet.cheatmd` install snippet uses `{:lattice_stripe, "~> 1.3"}`.
- `CHANGELOG.md` has a `1.3.0` release dated 2026-05-25 and explicitly says docs/package truth now align to the shipped `1.3.x` surface.
- `guides/getting-started.md` still uses `{:lattice_stripe, "~> 1.2"}` and is therefore stale relative to published repo truth.

### HexDocs-facing surfaces

- `mix.exs` sets ExDoc `main: "getting-started"`.
- `mix.exs` publishes `guides/getting-started.md`, `guides/cheatsheet.cheatmd`, and `CHANGELOG.md` as extras.
- Because Getting Started is the docs landing page, its stale install snippet is a higher-risk trust gap than a deeper guide inconsistency.

### Current regression coverage

- `test/lattice_stripe/docs_truth_test.exs` asserts:
  - ExDoc extras include `guides/recipes.md`
  - README links to `recipes.html`
  - README uses `{:lattice_stripe, "~> 1.3"}`
  - README no longer says `What's new in v1.1`
- It does **not** assert:
  - `guides/getting-started.md` install truth
  - cheatsheet install truth
  - changelog / published-version references
  - that the ExDoc main page and onboarding surfaces stay aligned

## Recommended Artifact Set

### 1. `43-01-PLAN.md`

Audit and reconcile the highest-visibility public docs surfaces:
- `README.md`
- `CHANGELOG.md`
- `guides/getting-started.md`
- `guides/cheatsheet.cheatmd`
- `mix.exs` docs metadata only if needed for truth alignment

### 2. `43-02-PLAN.md`

Expand docs-truth regression coverage so the phase does not rely on memory:
- extend `test/lattice_stripe/docs_truth_test.exs`
- assert onboarding/install truth on the actual first-run surfaces
- assert docs metadata needed to keep those surfaces publicly reachable

## Patterns To Reuse

### Pattern 1: Repo-truth-first docs edits

Use already-shipped repo truth as the source of public wording rather than writing new claims from memory. The authoritative anchors here are `mix.exs`, current README/changelog wording, and the existence of the shipped modules/guides already listed in the docs surface.

### Pattern 2: Narrow ExUnit file-content assertions

The existing `LatticeStripe.DocsTruthTest` pattern is deliberately lightweight: read the published docs file and assert for required snippets. Extend that pattern instead of introducing a new docs-lint tool or a heavy parser.

### Pattern 3: Highest-visibility first

Because `guides/getting-started.md` is the ExDoc main page and README is the repo landing page, drift there is more damaging than deeper-guide drift. Phase 43 should prioritize those surfaces before broader discovery work in Phase 44.

## Anti-Patterns To Avoid

- Do not broaden into general docs cleanup or style rewrites.
- Do not add new SDK features, guide families, or marketing claims.
- Do not make docs tests depend on live Hex or remote requests; keep them repo-local and deterministic.
- Do not let plan 02 quietly absorb Phase 44 guide-discovery scope. Coverage should protect truth on existing onboarding surfaces, not redesign the whole docs graph.

## Open Questions

None that block planning. The main facts are repo-local and already verified by direct file reads.

---
*Phase: 43-public-truth-baseline*
*Research captured: 2026-05-26*
