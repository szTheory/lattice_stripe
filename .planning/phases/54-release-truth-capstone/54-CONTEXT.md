# Phase 54: Release Truth Capstone - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Reconcile **public install and release truth** with shipped code: bump `mix.exs` to `1.7.0`, document v1.4–v1.7 milestone work in CHANGELOG, flip all adopter-facing install anchors to `{:lattice_stripe, "~> 1.7"}` in one lockstep change with docs-truth regression, refresh README release narrative and HexDocs index for v1.4–v1.7 surfaces, and publish **one** Hex package at `1.7.0`.

**In scope:** REL-01 through REL-04; docs-truth test migration; README release-status block + HexDocs cluster patches (ROADMAP success criterion #5); sync `.release-please-manifest.json` after publish.

**Explicitly out of scope:** New SDK API or guides; Phase 55 v1.x stop signal and Phase 41.1 retirement (CLOSE-01/02); `guides/charges.md`; sweeping `.planning/` historical version strings; editing `guides/api_stability.md` (`~> 1.0` is API-stability policy, not package install); LiveBook/notebook hygiene unless trivial.

**Hex reality (verified):** Last published Hex version is **1.1.0** (2026-04-14). Repo `mix.exs` is `1.3.0` with v1.4–v1.7 code on disk. Capstone publishes **1.1.0 → 1.7.0** in one artifact; CHANGELOG must say so honestly.

</domain>

<decisions>
## Implementation Decisions

### Install-line lockstep scope (D-01)
- **D-01:** **Single atomic flip** of every public `{:lattice_stripe, "~> X.Y"}` install snippet to `{:lattice_stripe, "~> 1.7"}` in the same commit/PR as `mix.exs` `1.7.0` and docs-truth updates.
- **Lockstep file list (7 surfaces):**
  1. `README.md` (Installation block)
  2. `guides/getting-started.md` (ExDoc `main` — highest-risk drift surface per Phase 43)
  3. `guides/cheatsheet.cheatmd`
  4. `guides/webhooks-thin-events.md` (`1.5` → `1.7`)
  5. `guides/production-checklist.md` (already `1.7` — verify only)
  6. `guides/event-debugging.md` (already `1.7` — verify only)
  7. `guides/opentelemetry.md` (`1.1` → `1.7`) — **required** despite absent from REL-03 literal text; published ExDoc Operations & DX surface
- **Exclude:** `guides/api_stability.md` (`~> 1.0` semver policy prose); `.planning/**`; optional `notebooks/stripe_explorer.livemd` comment only.
- **Retire B2 canary architecture:** Phase 48/53 per-guide version bands end at capstone; no post-54 multi-band install truth in public docs.
- **Ecosystem alignment:** Finch/Req/NimbleOptions pattern — one canonical Hex semver band on README + getting-started; guides teach usage, not alternate pins (stripity_stripe: one README band; Stripe official SDKs pin via package manager, not scattered doc versions).

### CHANGELOG shape and depth (D-02)
- **D-02:** **Option A — four milestone sections + one Hex release** (not a single flattened 1.7.0-only entry, not retroactive dated fake releases).
- **Top banner (new):** Publishing note — Hex last published **1.1.0**; sections **1.4.0–1.6.0** are milestone checkpoints included in **1.7.0**; install `{:lattice_stripe, "~> 1.7"}`.
- **Structure:**
  - `## [Unreleased]` — empty after ship (`_No unreleased changes._`)
  - `## [1.7.0]` — **only section with date + GitHub compare link** (`v1.3.0...v1.7.0` or `v1.1.0...v1.7.0` per tag reality); `### Highlights` + short **Upgrading from 1.1.x/1.3.x** paragraph; `### Added`/`Changed` for v1.7-only deltas (Charge, operator guides, install/docs-truth flip)
  - `## [1.6.0] — Tax` — subline: *Milestone included in 1.7.0. Not published separately to Hex.*
  - `## [1.5.0] — Thin-Event Webhooks` — **promote** existing Unreleased draft (WEBFIX-01, thin-event helpers, `webhooks-thin-events.md`); remove nested `### [1.5.0]` under Unreleased and pre-release blockquote
  - `## [1.4.0] — Adoption Closure` — recipes, docs-truth baseline, discovery ladder
  - `## [1.3.0]` — **unchanged** historical entry below
- **Migration depth:** Match **1.3.0** precedent — fenced `elixir` migration blocks only for behavior-breaking `### Changed`. **WEBFIX-01** (`tolerance: 0`) gets short migration callout under `### Fixed` in 1.5.0 section. Tax, Charge expansion, operator guides, thin-event helpers are **additive** (module/guide bullets, no fences).
- **Keep a Changelog:** `## [x.y.z]` headings; `### Added`/`Changed`/`Fixed`; bold lead-ins; guide paths as `` `guides/foo.md` ``.

### README release-status and HexDocs index (D-03)
- **D-03:** **Option B — milestone bullets** in README release-status blockquote (not minimal version-only, not full CHANGELOG duplicate, not “since 1.3” table).
- **Release-status content:**
  - Lead: **`1.7.x`** is current published line on Hex (wording only after REL-04 succeeds, or “will publish as 1.7.0” in pre-publish PR — implementer chooses honesty window)
  - Four bullets: **1.4** adoption/recipes, **1.5** thin events + guide link, **1.6** Tax + guide link, **1.7** Charge list/search/update/capture (PI-first; no create) + operator playbooks with links
  - Link: `CHANGELOG.md#170` (anchor adjust if needed)
  - **Do not** include Phase 55 language: “done for v1.x scope”, “complete Stripe SDK”, or deferred-family lists
- **HexDocs index (minimal, criterion #5):**
  - **Payments and billing cluster:** add [Tax](https://hexdocs.pm/lattice_stripe/tax.html)
  - **Operations and DX cluster:** add [Charge API](https://hexdocs.pm/lattice_stripe/LatticeStripe.Charge.html) moduledoc link (no `guides/charges.md`)
  - Do **not** duplicate flagship recipe URLs (already under Start here / Recipes)
  - Optional one-liner under clusters pointing to CHANGELOG — planner discretion; not required if milestone block suffices
- **Hybrid CHANGELOG relationship:** README carries milestone labels; depth/migrations/WEBFIX live in CHANGELOG only. Avoid `What's new in v1.x` headers (`docs_truth_test` already guards stale version headers).

### Hex publish execution (D-04)
- **D-04:** **Single Hex publish at 1.7.0** — reject sequential 1.4/1.5/1.6 Hex publishes (immutable wrong tarballs, `--replace` footgun, no adopter benefit).
- **Capstone path (recommended):** **Manual maintainer publish** for 1.7.0 after full preflight, given manifest drift (`release-please` manifest vs `mix.exs`) and unpushed local commits; **keep** existing `release.yml` for future releases.
- **Preflight checklist (gate before publish):**
  ```bash
  mix format --check-formatted
  mix compile --warnings-as-errors
  mix credo --strict
  mix test
  mix docs
  mix hex.build && mix hex.build --unpack
  mix hex.publish --dry-run
  ```
- **Publish steps:**
  1. Merge Phase 54 PR to `main`; `git push origin main`
  2. `git tag -a v1.7.0 -m "Release 1.7.0"`; `git push origin v1.7.0`
  3. `mix hex.publish --yes`
  4. Verify `mix hex.info lattice_stripe 1.7.0` and hexdocs.pm/lattice_stripe/1.7.0
  5. Set `.release-please-manifest.json` to `"1.7.0"`; optionally one-shot `"release-as": "1.7.0"` in `release-please-config.json` then remove after successful publish (Phase 19 v1.0.0 pattern)
- **Future hardening (planner discretion, not blocking 54):** Add `mix test` (and optionally `mix docs`) to `publish-hex` job before `mix hex.publish --yes`.
- **Upgrader message:** CHANGELOG 1.7.0 Highlights must note jump from last Hex **1.1.0**; `~> 1.1` resolves to 1.7.0.

### docs-truth test migration (D-05)
- **D-05:** **Hybrid C + SSOT** — derive expected install snippet from `LatticeStripe.MixProject.project()[:version]` (`"1.7.0"` → `{:lattice_stripe, "~> 1.7"}`); scan explicit `@install_surfaces` list; **retire** per-version canary tests.
- **New tests:**
  - `"public install line matches mix.exs and all install surfaces"` — foreach path in `@install_surfaces`, assert derived snippet
  - `"no stale lattice_stripe install pins on public surfaces"` — foreach path × stale pins (`1.1`, `1.2`, `1.3`, `1.5`), `refute`
  - `"changelog records the shipped 1.7 release truth"` — `## [1.7.0]` + shipped-surface phrasing (replace 1.3-only test)
- **Delete:** `"cheatsheet keeps the published 1.3 install truth"`; `"webhooks-thin-events guide is the v1.5 install-line canary"`; `"operator guides are the v1.7 install-line canary"`.
- **Trim version asserts from:** readme ladder test, getting-started branches test (keep cross-link asserts).
- **Add README regression (criterion #5):** release block mentions `1.7`, tax/thin-events/operator themes; HexDocs cluster includes `tax.html` and `LatticeStripe.Charge.html`.
- **Keep unchanged:** all content-lock tests (tax, thin-events, operator, cross-link graph, WEBFIX-01 CHANGELOG grep, Plug `@moduledoc`).
- **Implement order:** (1) `mix.exs` 1.7.0, (2) CHANGELOG, (3) lockstep doc flip, (4) run docs_truth (expect red), (5) refactor tests, (6) full `mix test`, (7) Hex publish.

### Claude's Discretion
- Exact CHANGELOG bullet wording and compare-link base tag (`v1.1.0` vs `v1.3.0`)
- Whether to add optional CHANGELOG one-liner under README HexDocs clusters
- `release-as` vs purely manual publish for this capstone
- Exact `docs_truth_test` helper function names
- Notebook comment update

### Folded Todos
_None — `todo.match-phase` returned no matches._

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` — Phase 54 goal, success criteria, REL-01–04
- `.planning/REQUIREMENTS.md` — REL-01–04, out-of-scope table
- `.planning/PROJECT.md` — Hex capstone folded into v1.7; post-v1.6 state
- `.planning/threads/v1-7-next-milestone-assessment.md` — install truth as top adopter friction; release capstone wedge

### Prior phase decisions (canary → capstone)
- `.planning/milestones/v1.5-phases/48-thin-event-adoption-surface-guide-integration-verification/48-CONTEXT.md` — D-03 3B install canary; lockstep flip deferred to release prep
- `.planning/phases/53-operator-guides/53-CONTEXT.md` — D-04 v1.7 canary on operator guides only; global flip deferred to Phase 54
- `.planning/milestones/v1.4-phases/43-public-truth-baseline/43-CONTEXT.md` — Phase 43 getting-started drift lesson; docs-truth expansion

### Milestone archives (CHANGELOG source material)
- `.planning/milestones/v1.4-ROADMAP.md` — adoption closure
- `.planning/milestones/v1.5-ROADMAP.md` — thin events
- `.planning/milestones/v1.6-ROADMAP.md` — tax
- `.planning/phases/52-charge-surface-expansion/52-CONTEXT.md` — Charge surface for 1.7.0 bullets
- `.planning/phases/53-operator-guides/53-CONTEXT.md` — operator guides for 1.7.0 bullets

### Research & OSS best practices
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — changelog, Hex metadata, versioned ExDoc source_ref
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — release-please + `mix hex.publish --yes` pipeline
- `prompts/elixir-best-practices-deep-research.md` — library UX, least surprise
- `CHANGELOG.md` — existing 1.3.0 entry + Unreleased 1.5.0 draft to promote

### Implementation targets
- `mix.exs` — `@version`, `docs_source_ref/0`, ExDoc extras
- `README.md` — release-status block, Installation, HexDocs index
- `test/lattice_stripe/docs_truth_test.exs` — install truth contract
- `.github/workflows/release.yml` — post-54 automation
- `release-please-config.json` — manifest sync after publish

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `docs_truth_test.exs` — 18+ tests; Phase 48/53 content locks are templates for new README/CHANGELOG assertions
- `release.yml` + `release-please-config.json` — automation exists; needs manifest repair after capstone
- Phase 48 B2 comments in docs_truth (lines 327–333) document intentional pre-capstone failure mode

### Established Patterns
- **Lockstep flip:** changing global install line without updating all assertions must fail CI (Phase 48 design)
- **Docs-truth as adopter regression:** grep anchors, not full prose snapshots
- **Single Hex band:** Ecto/Finch/Req — one `~> MAJOR.MINOR` on onboarding surfaces
- **CHANGELOG:** 1.3.0-style migration fences only when behavior breaks caller assumptions

### Integration Points
- REL-01 + REL-03 + REL-02 land in one PR wave before REL-04
- `docs_source_ref` uses `v#{@version}` — tag `v1.7.0` must exist when publishing
- Phase 55 consumes published 1.7.0 truth for stop-signal narrative

</code_context>

<specifics>
## Specific Ideas

- **Stripe SDK lesson:** Official SDKs don’t scatter semver in README — package manager + changelog carry version truth; LatticeStripe’s Hex-native `~> 1.7` must be singular everywhere.
- **Phase 43 lesson:** Never assert install line on README alone — global sweep + getting-started mandatory.
- **Hex gap honesty:** Banner must say last Hex was **1.1.0**, not imply 1.4–1.6 were on Hex.
- **WEBFIX-01:** Only migration-worthy behavior change in the 1.4–1.7 bundle; testing-only `tolerance: 0` callout preserved.
- **Charge bullet:** “list/search/update/capture (PI-first; no create)” in README milestone line — matches Phase 52 D-06.
- **Footgun list:** partial doc flip; opentelemetry drift; leaving canary tests; README `1.3.x` after publish; `release-please` manifest at 1.1.0; publish job without tests.

</specifics>

<deferred>
## Deferred Ideas

- **Phase 55 v1.x stop signal** — PROJECT.md, MILESTONES.md, “done for intended scope” (CLOSE-02)
- **Phase 41.1 retirement** — `accepted-external-verification` (CLOSE-01)
- **`publish-hex` job test gate** — recommended follow-up, not blocking 54
- **Notebook/livemd install comment** — optional hygiene
- **Intermediate Hex versions 1.4–1.6** — rejected

</deferred>

---

*Phase: 54-release-truth-capstone*
*Context gathered: 2026-05-27*
