# Phase 54: Release Truth Capstone — Research

**Researched:** 2026-05-27
**Status:** Complete

## RESEARCH COMPLETE

## Executive Summary

Phase 54 is a **release engineering + docs-truth capstone**, not new SDK surface. Repo truth today: `mix.exs` `@version` is `"1.3.0"`, Hex last published **1.1.0** (`.release-please-manifest.json` also `"1.1.0"`), and public install lines are **split across bands** (`~> 1.3` on README/getting-started/cheatsheet, `~> 1.5` on thin-events guide, `~> 1.7` on operator guides, `~> 1.1` on opentelemetry). `docs_truth_test.exs` encodes the B2 canary architecture (18+ tests) and will **fail intentionally** until lockstep flip + test migration.

**Recommended plan split:** 4 plans in 3 waves — version/CHANGELOG → lockstep docs + README → docs_truth refactor → Hex publish (manual, `autonomous: false`).

---

## Current State Audit

| Surface | Current pin | Target |
|---------|-------------|--------|
| `mix.exs` | `1.3.0` | `1.7.0` |
| `README.md` Installation | `~> 1.3` | `~> 1.7` |
| `guides/getting-started.md` | `~> 1.3` | `~> 1.7` |
| `guides/cheatsheet.cheatmd` | `~> 1.3` | `~> 1.7` |
| `guides/webhooks-thin-events.md` | `~> 1.5` | `~> 1.7` |
| `guides/production-checklist.md` | `~> 1.7` | verify only |
| `guides/event-debugging.md` | `~> 1.7` | verify only |
| `guides/opentelemetry.md` | `~> 1.1` | `~> 1.7` |
| `guides/api_stability.md` | `~> 1.0` | **exclude** (API stability policy) |

**README gaps for success criterion #5:**
- Release-status blockquote still says `1.3.x` current line
- HexDocs "Payments and billing" cluster lacks `tax.html` and `LatticeStripe.Charge.html`
- No Charge mention in Features (add per D-03 milestone bullet)

**CHANGELOG gaps:**
- `[Unreleased]` contains nested `### [1.5.0]` draft with pre-release blockquote — promote to `## [1.5.0]` per D-02
- Missing `## [1.4.0]`, `## [1.6.0]`, `## [1.7.0]` milestone sections
- Missing top banner explaining Hex 1.1.0 → 1.7.0 jump

---

## CHANGELOG Source Material

| Section | Primary sources |
|---------|-----------------|
| 1.4.0 Adoption | `.planning/milestones/v1.4-ROADMAP.md`, Phase 43–46 summaries |
| 1.5.0 Thin events | Existing Unreleased draft, Phase 47–48, `guides/webhooks-thin-events.md` |
| 1.6.0 Tax | `.planning/milestones/v1.6-ROADMAP.md`, Phases 49–51 |
| 1.7.0 Capstone | Phases 52–53, install flip, Charge + operator guides |

**Migration fences:** Only WEBFIX-01 (`tolerance: 0`) under 1.5.0 `### Fixed` — matches 1.3.0 precedent.

---

## docs-truth Test Migration (D-05)

**Delete:** canary tests at lines ~266, ~327, ~400 (1.3 cheatsheet, 1.5 thin-events, 1.7 operator-only).

**Add SSOT pattern:**
```elixir
@install_surfaces [
  "README.md",
  "guides/getting-started.md",
  "guides/cheatsheet.cheatmd",
  "guides/webhooks-thin-events.md",
  "guides/production-checklist.md",
  "guides/event-debugging.md",
  "guides/opentelemetry.md"
]

defp expected_install_snippet do
  major_minor = LatticeStripe.MixProject.project()[:version] |> String.split(".") |> Enum.take(2) |> Enum.join(".")
  "{:lattice_stripe, \"~> #{major_minor}\"}"
end
```

**Trim** hardcoded `~> 1.3` from readme/getting-started tests; keep cross-link graph asserts.

**Keep unchanged:** tax, thin-events content locks, operator content locks, WEBFIX-01 grep, Plug moduledoc.

---

## Hex Publish Path (D-04)

- **Single publish at 1.7.0** — no intermediate 1.4–1.6 Hex tarballs
- **Manual maintainer publish** recommended: manifest drift (`1.1.0`), `release.yml` `publish-hex` runs `mix hex.publish --yes` **without** `mix test` gate
- **Preflight:** format, compile --warnings-as-errors, credo, test, docs, hex.build, hex.publish --dry-run
- **Post-publish:** `.release-please-manifest.json` → `"1.7.0"`; tag `v1.7.0` before publish (docs_source_ref)

---

## Validation Architecture

| Property | Value |
|----------|-------|
| Framework | ExUnit (Mix) |
| Config | `mix.exs` test paths |
| Quick run | `mix test test/lattice_stripe/docs_truth_test.exs --warnings-as-errors` |
| Full suite | `mix test --warnings-as-errors` |
| Estimated runtime | ~60–120s full suite |

**Per-plan verify focus:**
- 54-01: grep `1.7.0` in mix.exs + CHANGELOG section headers
- 54-02: rg install pins on 7 surfaces
- 54-03: docs_truth_test green
- 54-04: `mix hex.info lattice_stripe 1.7.0` (manual)

---

## Risks & Footguns

1. Partial doc flip leaves mixed bands — atomic PR required (D-01)
2. Forgetting `opentelemetry.md` (`~> 1.1` today)
3. Leaving canary tests after flip — false green or false red
4. README still says `1.3.x` after publish
5. `release-please` manifest stale at 1.1.0
6. Publishing without `v1.7.0` tag breaks ExDoc source_ref

---

## Plan Wave Recommendation

| Wave | Plan | Requirements | autonomous |
|------|------|--------------|------------|
| 1 | 54-01 | REL-01, REL-02 | true |
| 2 | 54-02, 54-03 | REL-03 | true (02 before 03) |
| 3 | 54-04 | REL-04 | **false** (Hex credentials) |

---

*Phase: 54-release-truth-capstone*
