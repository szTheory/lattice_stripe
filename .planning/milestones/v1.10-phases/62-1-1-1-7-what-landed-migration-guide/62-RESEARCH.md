# Phase 62: "1.1 → 1.7 What Landed" Migration Guide - Research

**Researched:** 2026-08-24  
**Domain:** Version-pinned HexDocs migration documentation and semantic documentation contracts  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Historical Version Boundary

- **D-01:** Keep the guide strictly scoped to the 1.1 → 1.7 leg. Preserve the historical `{:lattice_stripe, "~> 1.7"}` dependency example and the prominent scope banner.
- **D-02:** Keep only a thin, generic handoff to the 2.0 migration and current Getting Started material. Do not turn this page into a rolling 1.1 → current guide or enumerate later-release conveniences inline.
- **D-03:** Remove the default-Finch paragraph from the 1.7 dependency step and remove `default Finch pool` from the 1.7 version-table row. Tag `v1.7.13` still required callers to supply `:finch`; the default pool arrived in Phase 61 and shipped in 2.0. Keeping it in the 1.7 path violates principle of least surprise and gives adopters instructions that cannot work on the stated dependency.
- **D-04:** Current-release setup advice, including the optional application and default Finch pool, belongs in current Getting Started and Client Configuration documentation. This guide may link there after the historical leg but must not restate post-1.7 behavior as 1.7 behavior.

#### Inventory and Information Architecture

- **D-05:** Use an action-first, two-tier structure: target/scope selection; a two-minute mandatory migration checklist; then optional capabilities the adopter may choose to use. Keep the version-by-version table as an appendix, not the primary navigation.
- **D-06:** Preserve the existing three `Affected if` checks and before/after Elixir snippets for expanded fields, finite status atoms, and `tolerance: 0`. Give readers an explicit safe exit when none applies, followed by a test-before-deploy action. Describe `tolerance: 0` precisely as an observed behavior change that reconciled implementation with the documented contract, while retaining the production replay-protection warning.
- **D-07:** Organize additive capabilities by consumer job first and familiar ExDoc family second. Each inventory row should answer: **Need / surface / minimum call / canonical next step**. This lets Phoenix/Elixir maintainers start from their application responsibility without losing the library's established sidebar vocabulary.
- **D-08:** Make the inventory genuinely complete for the 1.1 → 1.7 interval. It must cover every Phase 62 requirement surface and also the v1.3 additions currently visible only in the appendix: `File`/`FileLink`, `Mandate`, and `SetupAttempt`. A page promising "everything that landed" must not silently omit public surfaces from its main catalogue.
- **D-09:** Keep code examples selective and decision-bearing rather than duplicating canonical guides. Use before/after code for caller-visible changes; use one minimum viable snippet per important family; retain the Configuration → Session portal example; either show fetch-after-verify for thin events or narrow the surrounding claim; and identify TestClock/fixture APIs with version-accurate names.
- **D-10:** Keep user-facing copy at the consumer-contract level: the module, verb, input shape, return shape, safety condition, and next guide. Do not expose GSD phases, internal clauses, or implementation history unless it changes the caller's required action.
- **D-11:** Reuse ExDoc's existing documentation design system: semantic headings, warning/info callouts, prose before code, short fenced Elixir examples, descriptive links, and the dedicated **Upgrading** sidebar group. Correct the current `Part 2` / `Part 3` references so visible headings and navigation labels agree. No custom graphics or application UI work is warranted.

#### Drift Protection and Verification

- **D-12:** Keep `mix ci` and `mix docs --warnings-as-errors` as the baseline syntax, reference, formatting, and build gate, but do not treat them as proof of historical semantics. The current false Finch claim already demonstrates that limitation.
- **D-13:** Add one compact semantic contract to the existing `LatticeStripe.DocsTruthTest`. Protect only high-value adopter-facing invariants: the guide remains an ExDoc extra in the **Upgrading** group; its scope is 1.1 → 1.7; `~> 1.7` is deliberately historical; the 2.0 handoff remains; the three behavior checks remain; required inventory/canonical routes remain; and post-1.7 Finch claims are absent from the historical leg.
- **D-14:** Prefer a small number of behavior-oriented positive and negative assertions over line snapshots or exact-paragraph locks. Copy edits must remain cheap. Do not add rendered-HTML snapshots, blocking network link checks, git-tag-dependent CI, or a second release-capability manifest for this phase.
- **D-15:** Preserve the zero-library-code boundary. The allowed implementation surface is the guide, ExDoc registration if correction is needed, and the focused docs-truth regression test; no production modules or API behavior change in Phase 62.

### the agent's Discretion

- Exact headings and microcopy, provided they implement the action-first order and historical boundary above.
- Exact inventory-table wording and which representative snippet is used for each family, provided coverage is complete and examples remain version-accurate.
- Exact docs-truth anchor strings, provided each assertion protects a named user-harm regression and does not freeze whole paragraphs.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope. A rolling all-version migration system, rendered documentation snapshots, and blocking external-link checks were considered and rejected for this phase rather than deferred as planned work.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOC-01 | A `1.1 → 1.7: what landed` migration guide is published in HexDocs, enumerating every surface shipped since 1.1 with before/after examples. | Action-first guide structure; complete, job-routed inventory; existing ExDoc registration; focused semantic regression contract; CI/docs build gates. |
</phase_requirements>

## Summary

This is a corrective documentation pass, not a new SDK feature. The shipped guide already has the right core ingredients—scope banner, three precise affected-user predicates, concrete before/after Elixir, ExDoc registration, and canonical-guide links—but it currently assigns a post-1.7 default Finch pool to the historical 1.7 release and has an incomplete main capability catalogue. [VERIFIED: local guide, CHANGELOG, and `git show v1.7.13`] The planner should preserve its risk-first strength while changing its navigation from provider/release chronology to the maintainer's decision sequence: choose the target, check whether code changes, run application tests, then discover optional capabilities.

The idiomatic Elixir/ExDoc solution is a Markdown extra under an intentional sidebar group with prose and examples as first-class library product surface. ExDoc explicitly supports extra pages and `groups_for_extras`; its static-page model makes durable filenames and build-time reference checking valuable. [CITED: https://ex-doc.hexdocs.pm/ExDoc.html] The existing `DocsTruthTest` is the correct local seam for the small set of historical and discoverability claims that compilation cannot prove; retain `mix ci` and `mix docs --warnings-as-errors` as complementary syntax/link/build gates. [VERIFIED: `mix.exs`, `docs_truth_test.exs`, and `.github/workflows/ci.yml`]

**Primary recommendation:** Make one action-first, complete historical guide plus one compact semantic `DocsTruthTest` contract; do not add runtime code, snapshots, network checks, or a release manifest.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Historical migration decisions and examples | Documentation / HexDocs | Test suite | A versioned guide is the user interface for this decision; ExUnit prevents high-value semantic drift. |
| Discoverability and sidebar placement | Documentation configuration (`mix.exs`) | Docs-truth test | ExDoc owns publication/grouping; a local assertion protects the contract ExDoc does not semantically validate. |
| Surface/history correctness | Release records (`CHANGELOG`, tags) | Guide prose | Release records establish the historical boundary; guide translates it into actions without duplicating implementation details. |
| Validation of syntax, internal references, format | Mix/ExDoc/CI | Docs-truth test | Existing `mix ci` catches malformed docs; semantic tests cover the facts a renderer cannot infer. |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| ExDoc | existing project dependency | Publish the guide as a HexDocs extra and group it in the sidebar | ExDoc is the standard Elixir documentation publisher and supports `extras` plus `groups_for_extras`. [CITED: https://ex-doc.hexdocs.pm/ExDoc.html] |
| ExUnit | Elixir stdlib | Execute docs-truth semantic contract | Existing test convention; deterministic and already required by CI. [VERIFIED: `test/lattice_stripe/docs_truth_test.exs`] |
| Mix aliases | existing project configuration | Run format, compile, Credo, test, API/version checks, and docs build | `mix ci` already composes the repository's required documentation-quality gate. [VERIFIED: `mix.exs`] |

### Supporting

| Tool / Source | Purpose | When to Use |
|---------------|---------|-------------|
| `CHANGELOG.md` and `v1.7.13` tag | Historical inventory and boundary proof | Validate every version-specific claim before it enters guide prose. |
| Canonical guides | Deep task workflows | Link from inventory rows; do not duplicate their multi-step flows. |
| Existing `LatticeStripe.DocsTruthTest` | Docs placement/prose patterns | Extend with one named migration-guide test, not a new suite. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Action-first guide with appendix chronology | Version-by-version guide as primary navigation | Better for archival release auditing, but forces an upgrading maintainer to infer impact and repeats the changelog. |
| Focused semantic assertions | Rendered-HTML snapshots | Snapshots are noisy on ExDoc/template changes and do not prove historical correctness. |
| Local docs-truth contract | Git-tag-dependent CI or a release-capability manifest | Can mechanically inspect history but adds a brittle checkout dependency or duplicate source of truth. |
| Existing ExDoc references gate | Blocking network link checker | Adds flake/rate-limit failure without proving historical semantic claims. |

**Installation:** None. This phase must not add dependencies. [VERIFIED: D-15]

## Architecture Patterns

### System Architecture Diagram

```text
Maintainer pinned to 1.1
          |
          v
[Scope / target selection]
          |
          v
[Three "Affected if" checks] -- none match --> [Safe exit + run application tests]
          |
          v
[Exact before/after changes + safety warning]
          |
          v
[Optional capability inventory by need + ExDoc family]
          |
          v
[Canonical guide / module docs] ---> implementation details remain there

Guide source + mix.exs grouping ---> ExDoc / HexDocs
Guide semantic anchors + docs config ---> DocsTruthTest ---> required CI lane
```

### Recommended Project Structure

```text
guides/
└── upgrading-1-1-to-1-7.md            # historical, action-first guide
test/lattice_stripe/
└── docs_truth_test.exs                # compact migration-guide contract
mix.exs                                # existing extras + Upgrading group; edit only if wrong
CHANGELOG.md                           # historical authority; not changed in this phase
```

### Pattern 1: Mandatory migration first; optional additions second

**What:** Put upgrade-risk triage ahead of the additive inventory: target selection → dependency pin → three affected predicates → tests → optional capability discovery → chronology appendix.

**When to use:** A backwards-compatible SDK minor-line migration that contains a small number of caller-visible behavior changes and many additive APIs.

**Why:** It answers the maintainer's first jobs—“Will my app break?” and “What exact edit do I make?”—before presenting breadth. This follows the project's own routing principle: guides are a routing layer, while canonical guides remain the final workflow truth. [VERIFIED: `guides/user-flows-and-jtbd.md`] Stripe separately documents SDK migration/versioning support, which supports separating actionable upgrade material from release chronology. [CITED: https://docs.stripe.com/sdks/versioning?lang=node&locale=en-GB]

### Pattern 2: Consumer-job row with familiar SDK family

**What:** Each inventory row uses `Need | surface | minimum call | canonical next step`, grouped under the existing ExDoc family.

**When to use:** All additive surfaces in this bounded interval.

**Example:**

```markdown
| Need | Surface | Minimum call | Next step |
|---|---|---|---|
| Control portal cancellation behavior | `BillingPortal.Configuration` + `Session` | `Configuration.create/3`, then `Session.create/3` with `configuration: config.id` | [Customer Portal](customer-portal.md#wire-a-configuration-into-sessions) |
```

**Rationale:** It hides provider-internal release history while exposing the module, verb, required input relationship, expected result, safety condition, and next action—the least-surprising API-doc contract for a Phoenix maintainer. [VERIFIED: D-07 and `guides/user-flows-and-jtbd.md`]

### Pattern 3: Small positive-and-negative semantic docs contract

**What:** Read the source guide and live `docs_config()` in the established test module; assert the handful of required routes/facts, then explicitly refute known historical contamination.

**When to use:** A user-harmful prose or discoverability invariant that `mix docs` cannot infer.

**Example:**

```elixir
test "1.1-to-1.7 guide remains historically scoped and discoverable" do
  guide = File.read!("guides/upgrading-1-1-to-1-7.md")
  groups = docs_config()[:groups_for_extras] |> Map.new()

  assert "guides/upgrading-1-1-to-1-7.md" in docs_config()[:extras]
  assert "guides/upgrading-1-1-to-1-7.md" in groups["Upgrading"]
  assert guide =~ "1.1 → 1.7"
  assert guide =~ ~s/{:lattice_stripe, "~> 1.7"}/
  assert guide =~ "2.0"
  refute guide =~ "default Finch pool"
end
```

Use intention-revealing anchors rather than paragraph snapshots; split/word anchors may differ in final copy, but each assertion must map to one named adopter harm. [VERIFIED: D-13 and D-14]

### Inventory coverage contract

The main catalogue must route every required historical surface, not merely name it in the appendix. [VERIFIED: ROADMAP Phase 62 and CHANGELOG 1.3–1.7]

| Consumer job / family | Required historical surface | Minimum viable call or relationship | Canonical route |
|-----------------------|-----------------------------|-------------------------------------|-----------------|
| Resolve payment disputes / retain evidence | `Dispute`; `File`; `FileLink` | `Dispute.retrieve/3`; `File.create/3` / `FileLink.create/3` as appropriate | Module docs / recipes |
| Collect and track mandate-backed payment setup | `Mandate`; `SetupAttempt` | `Mandate.retrieve/3`; `SetupAttempt.list/3` | Module docs |
| Issue billing corrections / quote work | `CreditNote`; `Quote` | `CreditNote.create/3`; `Quote.create/3` | `credit_notes.md`, `quote-to-billing-operator.md` |
| Set self-service cancellation policy | `BillingPortal.Configuration` → `BillingPortal.Session` | Create configuration, pass `config.id` to session | `customer-portal.md` |
| Calculate, record, reverse tax | `Tax.Calculation`, `Tax.Transaction`, `Tax.Settings`, `Tax.Registration`, `TaxId` | `Tax.Calculation.create/3`; route deeper workflow | `tax.md` |
| Verify then fetch authoritative webhook state | `EventNotification`, `parse_event_notification/4`, `fetch_event/3` | Verify/parse then fetch; make idempotency boundary explicit | `webhooks-thin-events.md` |
| Search/reconcile money movement | `Charge.list/3`, `Charge.search/3`, `Payout`, `BalanceTransaction` | Read/list/search before supporting/reconciling | module docs / Connect guides |
| Make billing tests deterministic | `TestHelpers.TestClock`, `Testing.TestClock`, `Testing.Fixtures` | Name the public API accurately; link rather than duplicate full test setup | `testing.md` |

### Anti-Patterns to Avoid

- **Current setup masquerading as historical setup:** Never state the default Finch pool is available under `~> 1.7`; `v1.7.13` required `:finch`. [VERIFIED: `git show v1.7.13:lib/lattice_stripe/config.ex`]
- **A capability list that calls itself complete while omitting File/FileLink, Mandate, or SetupAttempt:** A version appendix does not satisfy an action-oriented inventory. [VERIFIED: guide vs. CHANGELOG]
- **Duplicate canonical workflow:** A migration example establishes the minimum decision, then links out; it must not silently become the primary Tax, Portal, or webhook guide.
- **Thin-event safety implied by parse only:** Either show the fetch-after-verify follow-up or make the claim narrower. [VERIFIED: `LatticeStripe.Webhook` exports `parse_event_notification/4` and `fetch_event/3`]
- **Exact prose/HTML locking:** It makes harmless copy fixes expensive and produces noisy review rather than preventing user harm.
- **Internal implementation language in reader-facing prose:** “Phase,” private helper clauses, and planning history do not help an adopter decide or act.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Documentation navigation/site UI | A custom docs site, custom components, graphics, or CSS | Existing ExDoc extra, sidebar group, headings, callouts, and fenced code | Consistent HexDocs affordances, accessible semantic structure, zero new runtime/deployment surface. |
| Documentation test framework | A guide-specific parser/framework | Existing `LatticeStripe.DocsTruthTest` + ExUnit | Existing file/config patterns already execute in a named required CI lane. |
| Historical release database | A second capability manifest | Reviewed `CHANGELOG`/tags plus narrow semantic anchors | A one-off manifest would duplicate history and impose ongoing maintenance. |
| Network validation | Blocking link crawler | `mix docs --warnings-as-errors` for internal docs refs | Deterministic, local, and aligned with existing CI; network checks are flaky and do not prove history. |

**Key insight:** Documentation is the phase's product surface. Reuse the library's documentation system and test only the non-renderable, user-harmful semantics.

## Common Pitfalls

### Pitfall 1: Semantic truth passes all build gates

**What goes wrong:** `mix ci` renders valid docs with a false historical statement.

**Why it happens:** Renderers validate syntax/references, not whether a capability existed at a particular tag.

**How to avoid:** Add one focused docs-truth test with positive scope/inventory anchors and a negative default-Finch assertion.

**Warning signs:** The guide says a post-1.7 feature is part of `~> 1.7`, or a current install pin appears on a historical page.

### Pitfall 2: Release chronology becomes the user experience

**What goes wrong:** A maintainer scans releases and must manually infer impact, potentially missing the only breaking change that affects their code.

**Why it happens:** Changelogs are author/release oriented, whereas migration work is risk and task oriented.

**How to avoid:** Keep version rows as an appendix after “Affected if” triage and a safe exit.

### Pitfall 3: “Complete” inventory silently loses less-prominent resources

**What goes wrong:** File/FileLink, Mandate, or SetupAttempt are only in the appendix or absent entirely.

**Why it happens:** Major families get prose sections while smaller v1.3 additions are treated as release-note residue.

**How to avoid:** Treat the inventory table as auditable coverage; assert representative route anchors in `DocsTruthTest`.

### Pitfall 4: Example names drift across versions

**What goes wrong:** TestClock or fixture APIs are described using an inaccurate/current-only name, or thin-event prose claims a safe flow without the fetch operation.

**Why it happens:** Examples are copied from memory or later docs instead of version-authoritative source/module docs.

**How to avoid:** Verify every module/function/arity against the release record/current public module and link canonical guides for full workflows.

### Pitfall 5: Security warning is softened during copy edits

**What goes wrong:** A reader treats `tolerance: 0` as a general production convenience.

**Why it happens:** The behavior correction is framed as a simple upgrade fact rather than a replay-protection boundary.

**How to avoid:** Retain the explicit testing-only and production prohibition beside the before/after example; assert the safety anchor.

## Code Examples

### Historical dependency target (not current setup)

```elixir
# This is intentionally the 1.1 → 1.7 historical migration leg.
{:lattice_stripe, "~> 1.7"}
```

[VERIFIED: `CHANGELOG.md` 1.7.0 and D-01] Do not append default-Finch configuration here.

### Thin-event minimum safe flow

```elixir
with {:ok, notification} <-
       LatticeStripe.Webhook.parse_event_notification(payload, sig_header, secret, []),
     {:ok, event} <- LatticeStripe.Webhook.fetch_event(client, notification) do
  # Deduplicate/process from the verified event id before side effects.
end
```

[VERIFIED: `lib/lattice_stripe/webhook.ex`] Keep the canonical guide responsible for the complete webhook/idempotency workflow.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Build a chronology-first release note and rely on `mix docs` | Action-first migration guide + focused semantic docs contract | This phase | Reduces upgrade uncertainty and locks user-harmful historical/discoverability facts without freezing prose. |
| Present default Finch as a 1.7 convenience | Keep it exclusively in current 2.x setup docs, with only a thin current-doc handoff | Phase 61 / 2.0, after v1.7.13 | Prevents instructions that cannot work for the stated historical dependency. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Stripe's current versioning page is a useful general precedent for separating migration support from release chronology. | Architecture Patterns | Low: local locked decisions and repository evidence independently dictate the implementation. |

All other planning recommendations are constrained by verified local source, the locked CONTEXT.md, and official ExDoc/Elixir documentation.

## Open Questions

None. The context locks all material scope and design choices. The executor may choose concise anchor strings and representative snippets, but must validate every linked call against public source before committing.

## Environment Availability

Step 2.6: SKIPPED — this is an existing Elixir documentation/test workflow with no new external service, runtime, CLI, or package dependency. Existing Mix/ExDoc/ExUnit tooling is already required by the repository.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir stdlib) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/docs_truth_test.exs` |
| Full suite command | `mix ci` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOC-01 | Guide remains published as an Upgrading extra, strictly historical, complete enough to route required surfaces, and free of post-1.7 Finch claims | Semantic documentation regression | `mix test test/lattice_stripe/docs_truth_test.exs` | ✅ extend existing |
| DOC-01 | Guide’s references/format render warning-free with project docs | Documentation build | `mix docs --warnings-as-errors` | ✅ |
| DOC-01 | Full project quality/format/test/docs regressions are absent | Full CI alias | `mix ci` | ✅ |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/docs_truth_test.exs`
- **Per wave merge:** `mix docs --warnings-as-errors`
- **Phase gate:** `mix ci`

### Wave 0 Gaps

- [ ] Extend `test/lattice_stripe/docs_truth_test.exs` with the focused guide contract specified by D-13/D-14.

## Security Domain

Documentation integrity and security-boundary clarity apply even though this phase changes no runtime security code. [VERIFIED: D-06, D-15]

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | No | No authentication surface changes. |
| V3 Session Management | No | No session surface changes. |
| V4 Access Control | No | No authorization surface changes. |
| V5 Input Validation | No | Guide does not process untrusted input. |
| V6 Cryptography | Indirectly | Preserve the explicit warning that disabling webhook tolerance removes replay protection; do not claim a new cryptographic behavior. |

### Known Threat Patterns for Documentation

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Historical setup claim causes an insecure/misconfigured deployment | Tampering / Denial of Service | Bound guide to `v1.7.13` truth, exclude default Finch, route current setup to current guides. |
| `tolerance: 0` copied into production webhook configuration | Spoofing / Replay | Visible test-only prohibition beside the example and semantic test anchor. |
| Thin-event example processes unverified/stale payload as authoritative | Tampering | State verify-then-fetch boundary and link canonical idempotency workflow. |

## Sources

### Primary (HIGH confidence)

- `62-CONTEXT.md` — locked phase scope, architecture, inventory, verification, and exclusions.
- `CHANGELOG.md` §§ 1.3.0, 1.5.0, 1.6.0, 1.7.0, 2.0.0 — historical release inventory.
- `git show v1.7.13:lib/lattice_stripe/config.ex` — `:finch` was required in the stated historical target.
- `guides/upgrading-1-1-to-1-7.md`, `mix.exs`, `test/lattice_stripe/docs_truth_test.exs`, `.github/workflows/ci.yml` — current implementation and executable patterns.
- `guides/user-flows-and-jtbd.md` and named `prompts/` research — project’s consumer-job and docs-as-product strategy.

### Secondary (MEDIUM confidence)

- [ExDoc configuration](https://ex-doc.hexdocs.pm/ExDoc.html) — extras, sidebar groups, ordering, and static-doc link behavior.
- [Elixir library guidelines](https://elixir.hexdocs.pm/main/library-guidelines.html) — documentation as first-class library product and ExDoc extra pages.

### Tertiary (LOW confidence)

- [Stripe SDK versioning](https://docs.stripe.com/sdks/versioning?lang=node&locale=en-GB) — general migration-support precedent; local release evidence remains authoritative for Phase 62 facts.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — only existing, verified project tools are used.
- Architecture: HIGH — locked by CONTEXT.md and supported by local docs/CI patterns.
- Pitfalls: HIGH — directly observed in the current guide/history and project test conventions.

**Research date:** 2026-08-24  
**Valid until:** Stable until Phase 62 implementation changes the guide/test structure; re-check historical claims if release history is rewritten.
