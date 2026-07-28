---
phase: 63-stripe-native-entitlements
plan: 06
subsystem: docs
tags: [stripe, entitlements, exdoc, guides, scope-fence, documentation]

# Dependency graph
requires:
  - phase: 63-01
    provides: "LatticeStripe.Entitlements.ActiveEntitlement and Feature decode halves; the guides/entitlements.md cross-links whose warnings this plan resolves"
  - phase: 63-02
    provides: "ActiveEntitlement.stream!/3 with its eager customer guard — the guide's complete-enumeration path"
  - phase: 63-03
    provides: "The complete Entitlements.Feature verb surface (create/3, retrieve/3, update/4, list/3, stream!/3 + bang twins) that the Managing features verb table documents"
  - phase: 63-04
    provides: "ActiveEntitlementSummary.from_map/1 and stream_entitlements!/3 — the reconciler pattern's two calls"
  - phase: pre-existing library core
    provides: "mix.exs docs/0 (extras, groups_for_extras, groups_for_modules); guides/scope.md as the docs-truth-locked deferred-scope contract; guides/tax.md as the canonical-guide precedent"
provides:
  - "guides/entitlements.md — the canonical Entitlements guide, 12 sections, Scope boundary first, with three pre-cut stubs for Phases 65 and 66"
  - "The fail-closed local-gate recipe: reconcile -> persist -> gate locally -> fail closed on staleness, shipped in the same section as the entitled? refusal"
  - "mix.exs docs/0 registration: guides/entitlements.md in both extras: and \"Canonical Guides\", plus the Entitlements: groups_for_modules group"
  - "guides/scope.md: the project-wide, permanent record of the refused per-request gate helper"
affects: [63-07, phase-65-object-types, phase-66-product-features, phase-67-module-grouping]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Refusal-with-replacement: a scope fence that names the rejected API (`entitled?`) and ships the working alternative as a numbered recipe in the same section, so the refusal is not read as an omission"
    - "Dual ExDoc registration as a single atomic edit: extras: and groups_for_extras together, because a file in a group but absent from extras: is silently dropped"
    - "Verb table over prose for a resource's surface, so a future verb appends one row instead of forcing a rewrite"
    - "Pre-cut stub sections that reserve document structure for named future phases, short enough to read as scaffolding rather than as unfinished work"
    - "Sibling module group rather than fold-in: \"Billing Metering\" already established that a Billing sub-product earns its own sidebar group"

key-files:
  created:
    - guides/entitlements.md
  modified:
    - mix.exs
    - guides/scope.md

key-decisions:
  - "D-18 held: spine-only guide, flat kebab-case filename, title `# Entitlements`, no new groups_for_extras group, no fifth Flagship Recipe"
  - "D-19.2 held: the ## Scope boundary section refuses `entitled?` by name AND ships the four-step fail-closed replacement; a refusal alone was treated as a prohibition violation, not a stylistic preference"
  - "D-19.3 held: guides/scope.md carries the fence as a Deferred-by-design bullet, naming `entitled?`, the fail-open-under-partition reason, and the entitlements.md pointer"
  - "D-17 held: new Entitlements: groups_for_modules group with exactly the three modules, between \"Billing Metering\" and Connect:"
  - "The reconciler example calls ActiveEntitlementSummary.from_map/1, NOT ObjectTypes.maybe_deserialize/1 as CONTEXT.md's <specifics> snippet shows — the ObjectTypes registry row is Phase 65, so maybe_deserialize/1 would return a raw map today and the example would not work"
  - "Every function in the guide was verified against module source with function_exported?/3 before the guide was committed; no surface was taken on trust from the plan text or from any prior SUMMARY"

requirements-completed: [ENT-01, ENT-02, ENT-03, ENT-04, ENT-05]

coverage:
  - id: D1
    description: "A reader arriving at the published docs finds the Entitlements guide in the Canonical Guides sidebar group, between customer-portal and metering"
    requirement: ENT-01
    verification:
      - kind: other
        ref: "LatticeStripe.MixProject.project()[:docs] — \"guides/entitlements.md\" in :extras => true; in groups_for_extras[\"Canonical Guides\"] => true; awk over the Canonical Guides tuple lists customer-portal, entitlements, metering in that order"
        status: pass
    human_judgment: false
  - id: D2
    description: "The three Entitlements modules appear together under their own sidebar group adjacent to Billing Metering"
    requirement: ENT-01
    verification:
      - kind: other
        ref: "Keyword.keys(docs[:groups_for_modules]) => [..., :\"Billing Metering\", :Entitlements, :Connect, ...]; the group holds exactly ActiveEntitlement, ActiveEntitlementSummary, Feature"
        status: pass
    human_judgment: false
  - id: D3
    description: "T-63-04 (high, Elevation of Privilege): the Scope boundary section refuses the per-request gate helper by name AND ships the working fail-closed replacement in the same section"
    requirement: ENT-01
    verification:
      - kind: other
        ref: "guides/entitlements.md ## Scope boundary — contains the literals `entitled?`, `gate`, `fails **open**`, and `fail closed`, followed by the four-step numbered recipe (reconcile / persist / gate locally / fail closed on staleness)"
        status: pass
    human_judgment: true
  - id: D4
    description: "The reconciler example is one call with no has_more branch — the reader never learns that Stripe inlines ten"
    requirement: ENT-05
    verification:
      - kind: other
        ref: "guides/entitlements.md ## The reconciler pattern — the code block contains no `has_more`, no `starting_after`, and exactly one stream_entitlements!/3 call piped into Enum.to_list/1"
        status: pass
    human_judgment: false
  - id: D5
    description: "T-63-17 (medium, Repudiation): the refused gate helper is recorded on the project-wide, docs-truth-locked deferred-scope page, not only in a phase artifact"
    requirement: ENT-01
    verification:
      - kind: other
        ref: "guides/scope.md ## Deferred by design — new bullet contains `entitled?`, `fails open`, and `[Entitlements](entitlements.md)`; the pre-existing Identity / Reporting / adopter pull / Client.request anchors are intact"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/docs_truth_test.exs#guides/scope.md is the canonical deferred-scope contract"
        status: pass
    human_judgment: false
  - id: D6
    description: "The Managing features section is a verb table, so a future verb appends one row rather than rewriting prose"
    requirement: ENT-04
    verification:
      - kind: other
        ref: "awk '/^## Managing features/,/^## lookup_key/' guides/entitlements.md | grep -c '^|' => 7 (header, separator, 5 verb rows)"
        status: pass
    human_judgment: false
  - id: D7
    description: "Three pre-cut stub sections exist for Attaching features to products, Testing, and Webhooks, so Phases 65 and 66 append rather than restructure"
    requirement: ENT-01
    verification:
      - kind: other
        ref: "guides/entitlements.md — the three headings exist, each with one paragraph naming what will live there and pointing at the guide (testing.md / webhooks.md) that covers the pattern today"
        status: pass
    human_judgment: true
  - id: D8
    description: "mix docs builds the guide with no new warnings and no warning naming the new surface"
    requirement: ENT-01
    verification:
      - kind: other
        ref: "mix docs exit 0; warning count 52 -> 48; the diff of before/after warnings is exactly the removal of 4x `documentation references file \"guides/entitlements.md\" but it does not exist`; grep -c 'guides/entitlements.md' on the after-output => 0"
        status: pass
    human_judgment: false
  - id: D9
    description: "Every function documented in the guide exists at the documented arity, and every claimed absence is a real absence"
    requirement: ENT-01
    verification:
      - kind: other
        ref: "function_exported?/3 over all 19 documented m:f/a (all true) and over entitled?/2,3, ActiveEntitlement.create/3, Feature.archive/3, Feature.unarchive/3, Feature.delete/3, Feature.retrieve_by_lookup_key/3, ActiveEntitlementSummary.retrieve/3 (all false); Map.has_key?(%ActiveEntitlementSummary{}, :id) => false"
        status: pass
    human_judgment: false

# Metrics
duration: 6min
completed: 2026-07-28
status: complete
---

# Phase 63 Plan 06: The Canonical Entitlements Guide Summary

**`guides/entitlements.md` ships as a 294-line spine with the `entitled?` refusal and its four-step fail-closed replacement in the same section, registered in both ExDoc surfaces alongside a new three-module `Entitlements:` sidebar group — and the four transient "guide does not exist" warnings this phase has been carrying are gone.**

## Performance

- **Duration:** ~6 min (first commit 2026-07-28 11:56:21 -0400 → last 11:57:37 -0400, plus verification)
- **Tasks:** 2 of 2
- **Files:** 3 (1 created, 2 modified)

## Accomplishments

- **The refusal ships with the replacement, which is the whole point of T-63-04.** `## Scope boundary` names `entitled?` in plain text, states that an authorization **gate** which makes a network call **fails open** under partition — the call times out, the pragmatic fallback lets the request through, and the customer gets access they did not buy — and then gives the working alternative as a four-step numbered recipe: reconcile with `stream_entitlements!/3` on the summary webhook, persist to a local store with a `reconciled_at` timestamp, gate locally on every request, and **fail closed** when the snapshot exceeds the freshness budget. The plan's one prohibition was that a refusal without an alternative is what the next contributor "fixes"; the recipe is what makes the fence hold.
- **The reconciler example is one call, and the reader never learns Stripe inlines ten.** No `has_more`, no `starting_after`, no cursor bookkeeping — `from_map/1`, pipe into `stream_entitlements!/3`, `Enum.to_list/1`, hand off. The three sentences that follow explain *why* it is a full canonical re-fetch rather than a resume: one call means one point in time, whereas resuming stitches a head captured when the webhook fired to a tail queried later.
- **`Managing features` is a table, so Phase 66 appends one row.** Five rows — `create/3`, `retrieve/3`, `update/4`, `list/3`, `stream!/3` — each with its HTTP method and path and a one-line purpose, with the bang twins named below it. The table states that there is no delete verb because Stripe ships no `DELETE`, that **archiving is `update/4` with `active: false`**, and repeats the `active`-field-versus-`archived`-filter split with the literal `%{"archived" => true}` prescription for catalog reconciliation.
- **Both ExDoc registrations landed together, because one alone is silently wrong.** `"guides/entitlements.md"` appears exactly twice in `mix.exs` — once in the flat `extras:` list and once in the `"Canonical Guides"` tuple between `"guides/customer-portal.md"` and `"guides/metering.md"`. A file listed in a group but absent from `extras:` is dropped from the build with no error, so these are one edit conceptually and were committed as one.
- **The three modules share a sibling group, not a fold-in.** `Entitlements:` sits between `"Billing Metering"` and `Connect:` in `groups_for_modules`. `"Billing Metering"` already established that a Billing sub-product earns its own group, and `Billing` already holds 22 modules. Phase 66 appends `LatticeStripe.Product.Feature` here with a one-line diff, which is what defuses the "two things called Feature" confusion at the point of discovery.
- **The phase's transient docs debt is discharged.** `mix docs` warning count moved **52 → 48**, and the before/after diff is *exactly* the removal of four `documentation references file "guides/entitlements.md" but it does not exist` warnings (one per output pass, from `feature.ex` and `active_entitlement_summary.ex`). Zero new warnings were introduced, and no remaining warning names the new guide.
- **Every documented function was verified against module source.** All 19 documented `m:f/a` were checked with `function_exported?/3` and all returned true; the eight names the guide claims are absent (`entitled?/2,3`, `ActiveEntitlement.create/3`, `Feature.archive/3`, `Feature.unarchive/3`, `Feature.delete/3`, `Feature.retrieve_by_lookup_key/3`, `ActiveEntitlementSummary.retrieve/3`) all returned false, and `%ActiveEntitlementSummary{}` has no `:id` key. Nothing in the guide was taken on trust from the plan text or from a prior SUMMARY.

## Where the plan text disagreed with the real module surface

**One material disagreement, resolved toward the source.**

CONTEXT.md's `<specifics>` block gives the headline reconciler snippet as:

```elixir
summary = ObjectTypes.maybe_deserialize(event.data["object"])
```

That call does not work today. `LatticeStripe.ObjectTypes` keys off the wire `"object"` string, and the registry row for `"entitlements.active_entitlement_summary"` is **Phase 65's** deliverable — explicitly fenced out of Phase 63 by the phase boundary and by 63-04's verification step 7 (`object_types.ex` must not be touched). A reader copying that line in v1.10 gets a raw string-keyed map back, and the following `stream_entitlements!/3` call raises a `FunctionClauseError` because it pattern-matches `%ActiveEntitlementSummary{customer: customer}`.

The guide therefore uses `ActiveEntitlementSummary.from_map/1`, which is exactly what the shipped `active_entitlement_summary.ex` moduledoc uses. The plan's own `<action>` text says only "deserialize the event object" and does not mandate `ObjectTypes`, so this is a correction inside the plan's own latitude rather than a departure from it. The `## Webhooks` stub records that automatic deserialization arrives with the registry entries, so the eventual `maybe_deserialize/1` form has a home to land in.

**Two smaller reconciliations, both toward the source:**

- The plan's artifact inventory lists `Feature.list_path/0` among the phase's new functions. It does not exist — 63-03 removed it as dead once five verbs read `@list_path` directly, and recorded the removal. The guide does not reference it. `ActiveEntitlement.list_path/0` does exist but is `@doc false`, so referencing it from an extra would have produced a *new* "hidden" ExDoc warning; the guide does not reference it either.
- The guide deliberately does not autolink `LatticeStripe.Resource.require_param!/3` when describing the pre-network guard, because `LatticeStripe.Resource` is `@moduledoc false` and each such reference costs an ExDoc warning. The guard's *behavior* — raises `ArgumentError` before any network call, checks presence not emptiness — is documented in full without naming the private helper.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write the canonical Entitlements guide** — `359fdb9` (docs)
2. **Task 2: Register the guide and module group in ExDoc, and fence the gate helper project-wide** — `09184af` (docs)

**Plan metadata:** see the `docs(63-06)` commit that carries this SUMMARY.

## Files Created/Modified

- `guides/entitlements.md` (new, 294 lines) — twelve `##` sections in the reader-chain order the plan specifies, `## Scope boundary` first. An ASCII mental-model diagram in `tax.md`'s style traces Feature → product attachment → purchase → ActiveEntitlement → summary and names which links this library covers today. Cross-links are relative `.md` filenames only; `grep -c 'https://'` returns **0**.
- `mix.exs` (modified, +8 lines) — three scoped edits, all inside `docs/0`. `git diff` confirms `deps/0` and `aliases/0` are untouched, so T-63-SC holds: zero packages installed.
- `guides/scope.md` (modified, +6 lines) — one new **Deferred by design** bullet, in the format the existing entries use. All four docs-truth anchors (`Identity`, `Reporting`/`Sigma`, `adopter pull`/`maintenance mode`, `Client.request`) are intact and the suite is green.

## Decisions Made

- **`from_map/1` over `ObjectTypes.maybe_deserialize/1` in the reconciler example** — see the section above. This is the single most-copied snippet in the guide; shipping one that raises would have been worse than any prose defect.
- **The `## Webhooks` and `## Testing` stubs point at the guides that cover the pattern today** (`webhooks.md`, `testing.md`) rather than being pure placeholders. A stub that says only "coming in Phase 65" strands the reader; a stub that says "here is the general mechanism, the entitlements-specific fixtures land later" does not. Both stay short enough to read as deliberate scaffolding.
- **`## Attaching features to products` names `LatticeStripe.Product.Feature` and `prodft_` explicitly, while stating plainly that it is not yet part of the typed surface,** and points at `LatticeStripe.Client.request/2` as the escape hatch. Naming the future module in the stub is what makes Phase 66's append a one-section edit.
- **`ActiveEntitlement`'s read-only-ness is stated as a design fact, not an omission** — "Entitlements are derived from purchases; you change them by changing what the customer bought." That framing is what stops a reader filing the absent `create/3` as a gap.
- **`mix ci` was deliberately not run** — plan verification step 7 forbids it. It is RED at clean HEAD because its `docs --warnings-as-errors` step carries a 42-warning pre-existing baseline (research correction C-02). The six individual gates were run instead, and all six are green.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The plan's headline snippet source used a deserializer that does not resolve this object yet**

- **Found during:** Task 1
- **Issue:** CONTEXT.md's `<specifics>` reconciler snippet opens with `ObjectTypes.maybe_deserialize(event.data["object"])`. The `object_types.ex` registry row for `"entitlements.active_entitlement_summary"` is Phase 65 work and is explicitly fenced out of Phase 63. Copied as written into a v1.10 application, the call returns a raw map and the next line raises `FunctionClauseError`.
- **Fix:** The guide's reconciler uses `ActiveEntitlementSummary.from_map/1` — the form the shipped module's own moduledoc uses and the only form that works today. `## Webhooks` records that automatic deserialization lands with the registry entries.
- **Files modified:** `guides/entitlements.md`
- **Verification:** the guide's `stream_entitlements!/3` call receives a `%ActiveEntitlementSummary{}`, matching the function's `%__MODULE__{customer: customer}` head; `mix docs` exits 0 with no new warnings.
- **Committed in:** `359fdb9`

**2. [Rule 2 - Missing critical functionality] `fail closed` was present only in title case on first write**

- **Found during:** Task 1 (acceptance-criteria check)
- **Issue:** The plan requires the literal lowercase `fail closed`. The first draft had `**Fail closed on staleness.**` (sentence-initial capital) and nothing else, so the docs-truth-style grep the plan specifies — and the one 63-07 will write — would have failed against a guide that reads correctly to a human. A prose lock that a future test cannot match is a lock that does not exist.
- **Fix:** Step 4 of the recipe now reads "…**fail closed** — deny access and re-reconcile", giving the literal a stable, semantically load-bearing home rather than a cosmetic one.
- **Files modified:** `guides/entitlements.md`
- **Verification:** `grep -c 'fail closed' guides/entitlements.md` returns 1.
- **Committed in:** `359fdb9`

---

**Total deviations:** 2 auto-fixed (1× Rule 1, 1× Rule 2). No Rule 4 architectural decisions were needed and no checkpoint was reached.
**Impact on plan:** None on structure, section order, or registration. Deviation 1 makes the guide's most-copied snippet actually run; deviation 2 makes a plan-mandated literal greppable.

## Issues Encountered

None blocking.

**The remaining 48 `mix docs` warnings are entirely pre-existing.** Six of them mention an entitlements file, and all six are the same accepted warning from earlier plans in this phase: `documentation references function "LatticeStripe.Resource.require_param!/3" but it is hidden`, emitted from `feature.ex:118`, `active_entitlement.ex:132` and `active_entitlement.ex:33`, doubled across the HTML and markdown passes. 63-03's SUMMARY records that disposition as "accepted, and consistent" — `LatticeStripe.Resource` is `@moduledoc false`, and diverging in one of two sibling modules would be worse than the warning. This plan introduced none of them and introduced no new ones.

### `mix docs` warning count, before and after

| Point | Total warnings | Warnings naming `guides/entitlements.md` |
|---|---|---|
| Clean HEAD (recorded baseline) | 42 | 0 |
| Before this plan (phase HEAD, `2a722b7`) | **52** | **4** |
| After this plan (`09184af`) | **48** | **0** |

The before/after diff of the warning multiset is exactly one line: the removal of `4 × documentation references file "guides/entitlements.md" but it does not exist`. Nothing was added.

### Verification results

| Check | Result |
|---|---|
| `mix docs` | **exit 0**, 48 warnings (was 52) |
| `mix test test/lattice_stripe/docs_truth_test.exs` | **48 tests, 0 failures** |
| `mix test` (full unit suite) | **2187 tests, 0 failures, 1 skipped (204 excluded)** |
| `mix format --check-formatted` | exit 0 |
| `mix compile --warnings-as-errors` | exit 0 |
| `mix credo --strict` | 2225 mods/funs, found no issues |
| `git diff mix.exs` confined to `docs/0` | ✓ — `deps/0` and `aliases/0` untouched |
| `head -1 guides/entitlements.md` | `# Entitlements` ✓ |
| `grep -c '^## ' guides/entitlements.md` | `12` ✓ |
| first `^## ` heading | line 13, `## Scope boundary` ✓ |
| literals `entitled?` / `fail closed` / `stream_entitlements!` | 1 / 1 / 6 ✓ |
| literal `%{"archived" => true}` / `error-handling.md` | 1 / 2 ✓ |
| `grep -c 'https://' guides/entitlements.md` | `0` ✓ |
| Managing-features table rows (`awk … \| grep -c '^\|'`) | `7` ✓ (≥ 6 required) |
| `wc -l < guides/entitlements.md` | `294` ✓ (180–300 required) |
| `grep -c '"guides/entitlements.md"' mix.exs` | `2` ✓ |
| `awk '/Entitlements: \[/,/\]/' mix.exs \| grep -c 'LatticeStripe.Entitlements.'` | `3` ✓ |
| Canonical Guides order | customer-portal → entitlements → metering ✓ |
| `groups_for_modules` order | `"Billing Metering"` → `Entitlements` → `Connect` ✓ |
| `docs[:extras]` / `groups_for_extras["Canonical Guides"]` contain the guide | `true` / `true` ✓ |
| `guides/scope.md` retains `Identity` and `Client.request` | ✓ |
| all 19 documented `m:f/a` exported | ✓ |
| all 8 claimed-absent names refuted | ✓ |
| `mix ci` | **intentionally not run** — plan verification step 7 |

## TDD Gate Compliance

Not applicable — this plan carries `type: execute` with no `tdd="true"` task. It ships documentation and ExDoc configuration and changes no runtime behavior, so there is no RED/GREEN cycle to gate. Both commits are correctly typed `docs`.

## Known Stubs

Three, and all three are **deliberate structural scaffolding**, declared as such by the plan's own `must_haves` truth ("Three pre-cut stub sections exist for Attaching features to products, Testing, and Webhooks, so Phases 65 and 66 append rather than restructure"):

| Section | File | Line | Resolved by | Why it is not a defect |
|---|---|---|---|---|
| `## Attaching features to products` | `guides/entitlements.md` | 241 | Phase 66 (`Product.Feature`) | The typed attachment surface does not exist yet. The section names the future module and ids, states plainly that it is not part of the typed surface today, and points at `LatticeStripe.Client.request/2` as the working escape hatch. |
| `## Testing` | `guides/entitlements.md` | 250 | Phase 65 (public `Testing.Fixtures`) | Entitlement fixtures are still private in `test/support/` (63-01, promote-by-move contract). The section says so and links `testing.md` for the Mox pattern the family already follows. |
| `## Webhooks` | `guides/entitlements.md` | 259 | Phase 65 (`object_types.ex` registry row) | Automatic deserialization needs the registry row. The section names the exact event type, gives the working explicit-decode form today, and links `webhooks.md` for verification and dispatch. |

None of the three prevents this plan's goal — a reader can reconcile entitlements end to end from the guide as shipped, using only surface that exists in v1.10. Each stub reserves space so the later phase appends rather than restructures, which is the stated design intent rather than an accepted shortfall.

## Threat Flags

None. This plan adds no network endpoint, no auth path, no file access and no schema change. `mix.exs` `deps/0` is untouched — zero packages installed (T-63-SC).

**T-63-04 (high, Elevation of Privilege) is mitigated as planned and is worth restating**, because it is the reason this plan exists in the shape it does. The trust boundary is *published documentation → the adopter's authorization code*: guidance that is wrong or incomplete here becomes an authorization defect in every downstream application. The mitigation is not the refusal — it is the refusal **plus** the fail-closed recipe in the same section, now present in all three surfaces D-19 requires (the `ActiveEntitlement` moduledoc admonition from 63-01, `## Scope boundary` here, and the `guides/scope.md` bullet).

**T-63-17 (medium, Repudiation) is mitigated:** the decision now lives on the project's canonical, docs-truth-locked deferred-scope page, not only in a phase artifact. 63-07 extends the existing `scope.md` lock to keep it from being deleted; the new prose was written to give that lock a stable literal (`entitled?`) to match.

## User Setup Required

None — no external service configuration, no packages installed, no environment variables.

## Next Phase Readiness

**Ready.** Phase 63's documentation surface is complete; only 63-07's locks remain.

- **63-07** has its literals in place to lock: in `guides/entitlements.md`, `entitled?`, `fail closed`, `stream_entitlements!`, `%{"archived" => true}` and the twelve `##` headings; in `guides/scope.md`, `entitled?` and `entitlements.md` alongside the four pre-existing anchors. The dual ExDoc registration can be asserted through the existing `docs_config/0` helper exactly as the tax guide's is at `docs_truth_test.exs:447-455`. Per this plan's scope, no new docs-truth assertions were written here.
- **Phase 65** appends to two named stubs (`## Testing`, `## Webhooks`) rather than restructuring, and can replace the guide's explicit `from_map/1` reconciler line with the `ObjectTypes.maybe_deserialize/1` form the moment the registry row lands — the sentence that will need editing is called out in `## Webhooks`.
- **Phase 66** appends one row to the `## Managing features` table if `Product.Feature` gains verbs, fills `## Attaching features to products`, and adds `LatticeStripe.Product.Feature` to the `Entitlements:` group in `mix.exs` as a one-line diff.
- **Phase 67** (the 32-module `groups_for_modules` backlog, including the whole `Tax.*` family) is untouched here by explicit scope fence. This plan added exactly one group and modified no existing one.
- **Carried forward:** D-19's three-surface fence is `one-way` **by intent** — the permanence is the feature. D-17's sidebar group is `reversible` at the cost of one commit and publishes no contract.

## Self-Check: PASSED

All claimed files exist on disk (`guides/entitlements.md`, `mix.exs`, `guides/scope.md`, and this SUMMARY) and both claimed commits resolve in `git log` (`359fdb9`, `09184af`).

---
*Phase: 63-stripe-native-entitlements*
*Completed: 2026-07-28*
