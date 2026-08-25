---
phase: 68
slug: reader-surface-repository-hygiene
status: validated
nyquist_compliant: false
wave_0_complete: true
created: 2026-08-25
---

# Phase 68 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | ExUnit + repository shell checks |
| Quick run | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` |
| Full suite | `mix ci` |

## Requirement Map

| Requirement | Automated evidence | Status |
|-------------|--------------------|--------|
| READ-01 | formatter, Credo, repository hygiene, and source scan | manual semantic review |
| READ-02 | real `mix ci` entry point plus close-time contributor-guide/source review | partial automation |
| READ-03 | `git check-ignore .planning/research/.cache/`; tracked prompt/archive layout | partial automation |

## Manual-Only Verifications

| Behavior | Requirement | Why manual | Result |
|----------|-------------|------------|--------|
| Comments retain useful rationale without decorative/history noise | READ-01 | Intent and explanatory value are semantic reader judgments; a broad word ban would reject legitimate domain history. | passed in close-time source audit |
| Contributor and prompt entry points route a fresh maintainer correctly | READ-02, READ-03 | Navigation quality is partly experiential. | passed in close-time integration audit |

## Validation Sign-Off

- [x] Every requirement has automated evidence or an explicit manual boundary.
- [x] No missing executable product behavior.
- [x] Manual reader-quality judgments are recorded rather than replaced by brittle grep rules.

**Approval:** validated 2026-08-25 (partial Nyquist; semantic reader review retained)
