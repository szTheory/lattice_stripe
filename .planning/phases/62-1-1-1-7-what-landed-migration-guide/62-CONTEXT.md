# Phase 62: "1.1 → 1.7 What Landed" Migration Guide - Context

**Gathered:** 2026-08-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a historically correct, zero-production-code HexDocs migration guide for adopters moving from LatticeStripe 1.1 to 1.7. The guide must let a maintainer quickly determine whether existing application code needs changes, show the exact required edits, and expose every additive surface shipped during that interval with clear next-step links. It remains an explicitly bounded historical guide, not a rolling guide to the current release.

The guide and ExDoc registration already exist from quick task `260729-h48`; planning should treat this as a focused correctness, completeness, and regression-lock pass rather than a greenfield writing task.

</domain>

<decisions>
## Implementation Decisions

### Historical Version Boundary

- **D-01:** Keep the guide strictly scoped to the 1.1 → 1.7 leg. Preserve the historical `{:lattice_stripe, "~> 1.7"}` dependency example and the prominent scope banner.
- **D-02:** Keep only a thin, generic handoff to the 2.0 migration and current Getting Started material. Do not turn this page into a rolling 1.1 → current guide or enumerate later-release conveniences inline.
- **D-03:** Remove the default-Finch paragraph from the 1.7 dependency step and remove `default Finch pool` from the 1.7 version-table row. Tag `v1.7.13` still required callers to supply `:finch`; the default pool arrived in Phase 61 and shipped in 2.0. Keeping it in the 1.7 path violates principle of least surprise and gives adopters instructions that cannot work on the stated dependency.
- **D-04:** Current-release setup advice, including the optional application and default Finch pool, belongs in current Getting Started and Client Configuration documentation. This guide may link there after the historical leg but must not restate post-1.7 behavior as 1.7 behavior.

### Inventory and Information Architecture

- **D-05:** Use an action-first, two-tier structure: target/scope selection; a two-minute mandatory migration checklist; then optional capabilities the adopter may choose to use. Keep the version-by-version table as an appendix, not the primary navigation.
- **D-06:** Preserve the existing three `Affected if` checks and before/after Elixir snippets for expanded fields, finite status atoms, and `tolerance: 0`. Give readers an explicit safe exit when none applies, followed by a test-before-deploy action. Describe `tolerance: 0` precisely as an observed behavior change that reconciled implementation with the documented contract, while retaining the production replay-protection warning.
- **D-07:** Organize additive capabilities by consumer job first and familiar ExDoc family second. Each inventory row should answer: **Need / surface / minimum call / canonical next step**. This lets Phoenix/Elixir maintainers start from their application responsibility without losing the library's established sidebar vocabulary.
- **D-08:** Make the inventory genuinely complete for the 1.1 → 1.7 interval. It must cover every Phase 62 requirement surface and also the v1.3 additions currently visible only in the appendix: `File`/`FileLink`, `Mandate`, and `SetupAttempt`. A page promising "everything that landed" must not silently omit public surfaces from its main catalogue.
- **D-09:** Keep code examples selective and decision-bearing rather than duplicating canonical guides. Use before/after code for caller-visible changes; use one minimum viable snippet per important family; retain the Configuration → Session portal example; either show fetch-after-verify for thin events or narrow the surrounding claim; and identify TestClock/fixture APIs with version-accurate names.
- **D-10:** Keep user-facing copy at the consumer-contract level: the module, verb, input shape, return shape, safety condition, and next guide. Do not expose GSD phases, internal clauses, or implementation history unless it changes the caller's required action.
- **D-11:** Reuse ExDoc's existing documentation design system: semantic headings, warning/info callouts, prose before code, short fenced Elixir examples, descriptive links, and the dedicated **Upgrading** sidebar group. Correct the current `Part 2` / `Part 3` references so visible headings and navigation labels agree. No custom graphics or application UI work is warranted.

### Drift Protection and Verification

- **D-12:** Keep `mix ci` and `mix docs --warnings-as-errors` as the baseline syntax, reference, formatting, and build gate, but do not treat them as proof of historical semantics. The current false Finch claim already demonstrates that limitation.
- **D-13:** Add one compact semantic contract to the existing `LatticeStripe.DocsTruthTest`. Protect only high-value adopter-facing invariants: the guide remains an ExDoc extra in the **Upgrading** group; its scope is 1.1 → 1.7; `~> 1.7` is deliberately historical; the 2.0 handoff remains; the three behavior checks remain; required inventory/canonical routes remain; and post-1.7 Finch claims are absent from the historical leg.
- **D-14:** Prefer a small number of behavior-oriented positive and negative assertions over line snapshots or exact-paragraph locks. Copy edits must remain cheap. Do not add rendered-HTML snapshots, blocking network link checks, git-tag-dependent CI, or a second release-capability manifest for this phase.
- **D-15:** Preserve the zero-library-code boundary. The allowed implementation surface is the guide, ExDoc registration if correction is needed, and the focused docs-truth regression test; no production modules or API behavior change in Phase 62.

### the agent's Discretion

- Exact headings and microcopy, provided they implement the action-first order and historical boundary above.
- Exact inventory-table wording and which representative snippet is used for each family, provided coverage is complete and examples remain version-accurate.
- Exact docs-truth anchor strings, provided each assertion protects a named user-harm regression and does not freeze whole paragraphs.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and historical truth

- `.planning/ROADMAP.md` § Phase 62 — fixed goal, named surfaces, success criteria, and zero-library-code boundary.
- `.planning/REQUIREMENTS.md` § DOC-01 — milestone requirement mapped to Phase 62.
- `.planning/PROJECT.md` § Current Milestone v1.10 — adopter-pull context and project design philosophy.
- `CHANGELOG.md` §§ 1.3.0, 1.5.0, 1.6.0, 1.7.0, and 2.0.0 — authoritative release inventory and proof that default Finch is post-1.7.
- `.planning/phases/61-default-finch-pool-optional-application/61-CONTEXT.md` — locks the default Finch pool as a separate later phase.

### Existing deliverable

- `guides/upgrading-1-1-to-1-7.md` — existing guide to correct and complete rather than replace blindly.
- `.planning/quick/260729-h48-ship-upgrading-guide/260729-h48-PLAN.md` — why the orphaned guide was restored, its intended historical scope, and historical-pin safety.
- `.planning/quick/260729-h48-ship-upgrading-guide/260729-h48-SUMMARY.md` — shipped state and prior `mix ci` verification evidence.
- `mix.exs` § docs configuration — current ExDoc extras and **Upgrading** group integration.

### Documentation UX and project vision

- `guides/user-flows-and-jtbd.md` § The Mental Model and Start Here By Situation — established consumer-job language and routing pattern.
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` §§ Documentation and compatibility/evolution — ExDoc layers, migration guides, examples as contracts, and release-pinned docs.
- `prompts/stripe-sdk-api-surface-area-deep-research.md` § Versioning / migration jobs — migration support as a first-class SDK concern.
- `prompts/stripe-lib-priority-user-flows-deep-research.md` § Tier 7 — maintainer persona and version-aware migration JTBD.

### Verification patterns

- `test/lattice_stripe/docs_truth_test.exs` — established semantic documentation-contract patterns and live `docs_config()` assertions.
- `.github/workflows/ci.yml` § Docs Truth and Quality — required docs-truth and ExDoc-warning CI lanes.
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` § Docs build as a gate / ExDoc best practices — project-local rationale for treating documentation as product surface.

No project brandbook was found; the applicable design system is the established ExDoc structure and project-local JTBD/documentation research above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `guides/upgrading-1-1-to-1-7.md`: a substantial existing guide with strong risk-first callouts, three affected-user predicates, before/after examples, family sections, and a version appendix.
- `mix.exs` docs configuration: the guide is already published as an extra under a dedicated **Upgrading** group.
- `LatticeStripe.DocsTruthTest`: existing fast semantic checks for guide placement, API examples, stale prose, and cross-guide routing; extend this suite rather than creating a new test framework.
- Canonical guides such as `guides/customer-portal.md`, `guides/tax.md`, `guides/webhooks-thin-events.md`, and `guides/testing.md`: established destinations for detailed workflows the migration guide should not duplicate.

### Established Patterns

- Documentation is a first-class product and regression surface; `mix ci` runs tests plus `docs --warnings-as-errors`.
- Public docs use a layered ExDoc ladder and route readers by job before deep API reference.
- Docs-truth assertions lock semantic anchors and forbidden stale patterns where compiler/runtime checks cannot prove prose truth.
- Historical pins are excluded from current-version rewriting; the upgrading guide is intentionally absent from the current install-surface allowlist.

### Integration Points

- Edit `guides/upgrading-1-1-to-1-7.md` for chronology, navigation, inventory, and examples.
- Keep or verify `guides/upgrading-1-1-to-1-7.md` in `mix.exs` `extras` and `groups_for_extras["Upgrading"]`.
- Add the focused contract to `test/lattice_stripe/docs_truth_test.exs`; it already runs in the required `docs_truth` CI lane.

</code_context>

<specifics>
## Specific Ideas

- Recommended top-level reader path: **Choose target → Check three behavior changes → Run application tests → Discover optional additions → Follow canonical guides → Consult version appendix**.
- Recommended inventory labels should be outcome-oriented, such as “Resolve disputes,” “Control portal cancellation behavior,” “Calculate and record tax,” “Verify then fetch thin events,” “Reconcile money movement,” and “Make billing tests deterministic.”
- Successful SDKs separate required migration actions from release chronology. LatticeStripe should retain its particularly strong `Affected if` predicates and exact Elixir before/after patterns while avoiding a duplicate changelog.
- Accessibility here means semantic hierarchy, descriptive links, non-color-only callout labels, short code blocks, visible safety boundaries, and predictable ExDoc navigation; visual theming and custom UI are out of scope.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. A rolling all-version migration system, rendered documentation snapshots, and blocking external-link checks were considered and rejected for this phase rather than deferred as planned work.

</deferred>

---

*Phase: 62-1-1-1-7-what-landed-migration-guide*
*Context gathered: 2026-08-24*
