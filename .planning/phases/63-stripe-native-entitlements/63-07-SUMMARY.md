---
phase: 63-stripe-native-entitlements
plan: 07
subsystem: docs
tags: [stripe, entitlements, docs-truth, exdoc, prose-lock, gates, scope-fence]

# Dependency graph
requires:
  - phase: 63-01
    provides: "The ActiveEntitlement gate-fence admonition (`entitled?` / `gate` / `fail closed` / `stream!/3`) that this plan's L3 prose lock protects; the `refute function_exported?` structural locks that make refuting the helper name unnecessary here"
  - phase: 63-03
    provides: "The Feature `## Archiving` section and the `lookup_key` immutability prose that this plan's L3 lock protects"
  - phase: 63-04
    provides: "The ActiveEntitlementSummary `no top-level` id prose that this plan's L3 lock protects"
  - phase: 63-06
    provides: "guides/entitlements.md, its dual ExDoc registration and the Entitlements: module group; the guides/scope.md `entitled?` bullet — all four are what this plan locks"
  - phase: pre-existing library core
    provides: "test/lattice_stripe/docs_truth_test.exs, its docs_config/0 helper and the tax-guide lock used as the template; .planning/.../docs-warning-baseline.txt (42) captured before any lib change"
provides:
  - "The entitlements docs-truth lock: ExDoc placement (both registration halves + the three-module group), six guide prose anchors, two cross-links, and moduledoc source locks over all three entitlements modules"
  - "The extended guides/scope.md lock covering the refused `entitled?` gate helper and the entitlements.md pointer"
  - "A phase-end ExDoc warning count of 42 — exactly the clean-HEAD baseline, with zero warnings naming any entitlements file"
affects: [phase-65-object-types, phase-66-product-features, phase-67-module-grouping]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Lock the explanation, not only the code: `refute function_exported?` proves a helper is absent, `File.read!` + `=~` proves the *reason* it is absent is still written down"
    - "Assert presence, never refute it, for a refused API name — the name must stay greppable so a contributor searching for it lands on the rationale rather than on silence"
    - "Mutation-check a docs lock before trusting it: strip each anchored literal in turn, confirm exactly the intended assertion fails, restore"
    - "Differential docs gate over an absolute one: compare against a clean-HEAD baseline integer read with a fallback-free `cat`, so a missing baseline aborts the gate instead of passing vacuously"
    - "De-autolink rather than de-document: name the behavior of a `@moduledoc false` helper without writing its qualified `Mod.fun/arity`, which is what ExDoc autolinks and warns on"

key-files:
  created: []
  modified:
    - test/lattice_stripe/docs_truth_test.exs
    - lib/lattice_stripe/entitlements/active_entitlement.ex
    - lib/lattice_stripe/entitlements/feature.ex

key-decisions:
  - "D-23 L3 held: one new top-level docs-truth test locking ExDoc placement, guide prose, cross-links and all three moduledocs"
  - "D-24 held: `entitled?` is asserted PRESENT in three places (guide, ActiveEntitlement source, scope.md) and refuted nowhere; the new test contains zero `refute`"
  - "D-25 held: exactly three prose fences locked — the gate refusal, the summary's absent top-level id, the archiving vocabulary split. No pagination prose lock was added"
  - "The plan's `for source <- [...]` loop was taken literally rather than weakened: ActiveEntitlement did not cross-link the guide, so the cross-link was added to the source instead of the assertion being narrowed to the two modules that already had it"
  - "Gate 3's differential failure was answered as the plan instructs — fix the autolinks in the new files, never raise the baseline. The phase's entire +6 warning delta was closed; the count is now 42 = baseline"
  - "`mix ci` was still not used as a gate (research correction C-02) but was run informationally: it fails only at its final `docs --warnings-as-errors` step, on 42 pre-existing warnings, none of which name an entitlements file"

requirements-completed: [ENT-01, ENT-04, ENT-05]

coverage:
  - id: D1
    description: "A docs-truth test fails if guides/entitlements.md is dropped from either extras: or the Canonical Guides group"
    requirement: ENT-01
    verification:
      - kind: unit
        ref: "test/lattice_stripe/docs_truth_test.exs#entitlements guide locks ExDoc placement, content anchors, cross-links, and moduledocs"
        status: pass
      - kind: other
        ref: "Mutation: deleting line 48 of mix.exs (the extras: entry) while leaving the Canonical Guides entry intact => 1 failure at `assert \"guides/entitlements.md\" in docs[:extras]`; restored"
        status: pass
    human_judgment: false
  - id: D2
    description: "A docs-truth test fails if the Entitlements module group is removed from mix.exs or loses a module"
    requirement: ENT-01
    verification:
      - kind: unit
        ref: "docs[:groups_for_modules][:Entitlements] asserted to contain all three module atoms"
        status: pass
    human_judgment: false
  - id: D3
    description: "T-63-04 (high, EoP): a docs-truth test fails if the ActiveEntitlement moduledoc loses `gate`, `fail closed`, or `stream!/3`"
    requirement: ENT-01
    verification:
      - kind: other
        ref: "Mutation: s/fail closed/fail safely/g over active_entitlement.ex => 1 failure at `assert active_entitlement =~ \"fail closed\"`; restored"
        status: pass
    human_judgment: false
  - id: D4
    description: "A docs-truth test fails if the ActiveEntitlementSummary moduledoc loses `no top-level`"
    requirement: ENT-05
    verification:
      - kind: other
        ref: "Mutation: s/no top-level/none/g over active_entitlement_summary.ex => 1 failure at `assert summary =~ \"no top-level\"`; restored"
        status: pass
    human_judgment: false
  - id: D5
    description: "T-63-08 (medium, Tampering): the archiving vocabulary warning cannot be silently deleted"
    requirement: ENT-04
    verification:
      - kind: unit
        ref: "`assert feature =~ \"## Archiving\"` and `assert feature =~ \"immutable\"` against feature.ex source"
        status: pass
    human_judgment: false
  - id: D6
    description: "`entitled?` is asserted present and never refuted"
    requirement: ENT-01
    verification:
      - kind: other
        ref: "grep -c '\"entitled?\"' docs_truth_test.exs => 3 (guide, ActiveEntitlement source, scope.md); awk over the new test | grep -c refute => 0"
        status: pass
    human_judgment: false
  - id: D7
    description: "T-63-17 (medium, Repudiation): the guides/scope.md lock now covers the refused gate helper alongside its existing anchors"
    requirement: ENT-01
    verification:
      - kind: other
        ref: "Mutation: s/entitled?/is_entitled/g over guides/scope.md => 1 failure at `assert scope =~ \"entitled?\"`; the four pre-existing anchors (Identity, Reporting/Sigma, adopter pull/maintenance mode, Client.request) still pass; restored"
        status: pass
    human_judgment: false
  - id: D8
    description: "Exactly three prose locks for this family; no generic pagination sentence is locked"
    requirement: ENT-05
    verification:
      - kind: other
        ref: "The new test asserts no `has_more` / `starting_after` / pagination prose against any source; the ten-assertion stream suite from 63-02 remains the structural proof"
        status: pass
    human_judgment: true
    rationale: "How much prose to freeze is a calibration call with costs in both directions: too few locks and safety-critical wording rots silently, too many and ordinary documentation edits start failing CI. A test can count the locks but cannot judge whether three is the right number for this family."
  - id: D9
    description: "T-63-19 (high, Repudiation): all five phase gates green, measured rather than asserted"
    requirement: ENT-01
    verification:
      - kind: other
        ref: "unit 2188 tests 0 failures; integration 7 tests 0 failures against stripe-mock:12111; mix docs exit 0; credo --strict 2225 mods/funs no issues; docs-truth 49 tests 0 failures"
        status: pass
    human_judgment: false
  - id: D10
    description: "mix docs emits no warning naming the new surface and the total has not risen above the clean-HEAD baseline"
    requirement: ENT-01
    verification:
      - kind: other
        ref: "baseline=42 current=42 surface=0 — differential PASS and surface PASS, with the baseline read by a fallback-free `cat`"
        status: pass
    human_judgment: false

# Metrics
duration: 12min
completed: 2026-07-28
status: complete
---

# Phase 63 Plan 07: Locking the Explanation Summary

**The gate fence, the missing top-level id and the archiving vocabulary split are now enforced by a docs-truth test that four independent mutations prove will bite — and the phase closes its docs debt entirely, landing at exactly the 42-warning clean-HEAD baseline with zero warnings naming any entitlements file.**

## Performance

- **Duration:** ~12 min
- **Tasks:** 2 of 2
- **Files:** 3 modified (1 test, 2 lib moduledocs)

## Accomplishments

- **The explanation is now load-bearing, not decorative.** Plans 63-01 and 63-03 locked the *code* — `refute function_exported?` proves `entitled?/2` and `Feature.archive/3` will never exist. Those locks say nothing about *why*. The new test reads all three `lib/` sources with `File.read!` and asserts the reason is still written down: `gate`, `fail closed`, `stream!/3` and `entitled?` on `ActiveEntitlement`; `no top-level` on the summary; `## Archiving` and `immutable` on `Feature`. Delete the admonition in a future cleanup and the suite goes red.
- **`entitled?` is asserted present in three places and refuted in none.** `grep -c '"entitled?"'` over the test file returns **3** — once against the guide, once against the `ActiveEntitlement` source, once against `guides/scope.md`. The new test body contains zero `refute`. This is D-24 taken literally: refuting the name in a source file would forbid the very documentation the fence depends on, and the name has to stay greppable so a contributor who searches for it lands on the four-step fail-closed recipe rather than on silence.
- **Both halves of the ExDoc registration are locked, and the mutation proves the pairing matters.** Deleting only the `extras:` entry from `mix.exs` — leaving the `"Canonical Guides"` entry perfectly intact, which is exactly how a guide gets silently dropped from a build with no error — produces one failure at `assert "guides/entitlements.md" in docs[:extras]`. The `:Entitlements` module group is locked the same way, asserting all three module atoms rather than merely that the key exists.
- **The phase's docs debt is closed, not merely bounded.** Gate 3 initially came in at **48 vs a baseline of 42** and failed. The plan is explicit about the correct response — *fix the autolinks in the new files rather than raise the baseline* — so the three `LatticeStripe.Resource.require_param!/3` prose sites added by 63-01 and 63-03 were reworded to document the guard's behavior without naming the `@moduledoc false` helper that ExDoc autolinks and warns on. The count is now **42 = 42**, and `grep 'warning:' | grep -ci 'entitle'` returns **0**. Phase 63 ends contributing exactly zero warnings.
- **Every lock was mutation-checked before being trusted.** Four separate mutations were applied, each observed to fail *exactly* the intended assertion, each restored: strip `fail closed` from the `ActiveEntitlement` moduledoc; drop the `extras:` registration; strip `no top-level` from the summary; strip `entitled?` from `guides/scope.md`. A lock that has never been seen to fail is a lock nobody has any reason to believe in.
- **All five gates are green, measured rather than asserted.** Unit **2188 tests, 0 failures, 1 skipped (204 excluded)**; integration **7 tests, 0 failures** against `stripe-mock` on 12111; `mix docs` **exit 0**; `mix credo --strict` **2225 mods/funs, found no issues**; docs-truth **49 tests, 0 failures**. Test counts are reported by shape, never hardcoded into an assertion.

## Where the plan text disagreed with the real source

**One disagreement, resolved toward the plan by changing the source rather than the assertion.**

The plan's `<behavior>` requires that *all three* entitlements sources match `"guides/entitlements.md"` via a `for source <- [...]` loop. Only two did. `feature.ex:14` and `active_entitlement_summary.ex:15` each carried `See [Entitlements](guides/entitlements.md) for the end-to-end story.`; `active_entitlement.ex` carried no guide reference at all — which is consistent with 63-06's record that the four transient guide-link warnings came from exactly two files.

Written as specified, the test went **RED on the real repository** at `assert source =~ "guides/entitlements.md"`. That is the docs-truth mechanism working: it caught a genuine cross-link gap on its first run. Two responses were available — narrow the loop to the two modules that already linked, or make the third module true. Narrowing would have silently weakened the plan's spec *and* left the module carrying the gate fence as the one module with no pointer to the guide holding the full replacement recipe. The cross-link was added instead, in the identical sibling form, immediately after the admonition.

## Task Commits

Each task was committed atomically:

1. **Task 1: Lock the ExDoc placement and the three prose fences** — `bbaa20c` (docs: the ActiveEntitlement cross-link that turned the RED run GREEN) and `e8e3ba5` (test: the locks themselves)
2. **Task 2: Run the five phase gates, including the differential docs check** — `e0f6dda` (docs: the autolink fix that closed the 48 → 42 gap)

**Plan metadata:** see the `docs(63-07)` commit that carries this SUMMARY.

## Files Created/Modified

- `test/lattice_stripe/docs_truth_test.exs` (modified, +52 lines) — one new top-level test placed immediately after the tax-guide lock it was cloned from, plus two assertions appended to the existing `guides/scope.md` test. The suite went 48 → 49 tests.
- `lib/lattice_stripe/entitlements/active_entitlement.ex` (modified) — added the guide cross-link after the gate-fence admonition; reworded the two `require_param!/3` autolink sites (moduledoc and `list/3` `@doc`) to describe the guard without naming the hidden helper.
- `lib/lattice_stripe/entitlements/feature.ex` (modified) — reworded the one `require_param!/3` autolink site in the `create/3` `@doc`. Behavior documented unchanged: raises `ArgumentError` before any network call, checks key **presence, not value emptiness**, so a `lookup_key` of `""` or `nil` passes the guard and fails at Stripe.

No `mix.exs` change, no `deps/0` change, zero packages installed (T-63-SC holds for the whole phase).

## Decisions Made

- **The `for source` loop was taken literally.** See above — the source was made true rather than the assertion made smaller.
- **Gate 3's failure was fixed at the source, not at the baseline.** Raising the baseline from 42 to 48 would have been a one-character change that made the gate permanently vacuous for the exact class of regression it exists to catch. The plan forbids it in as many words; the +6 was closed instead.
- **De-autolink, do not de-document.** Every fact the three reworded passages carried — the guard raises before the network, it checks presence rather than emptiness, an empty-string value passes it — survives verbatim. What was removed is the qualified `LatticeStripe.Resource.require_param!/3` token, which is what ExDoc resolves and warns on because `Resource` is `@moduledoc false`. This is the precedent 63-06 already set in the guide, now applied to the sources it was derived from.
- **No test asserted the removed literal.** `grep -rn 'require_param' test/` was checked before touching the moduledocs: the only test references are direct calls in `resource_test.exs` and `billing/meter_test.exs`. No docs-truth lock anywhere in the repo anchors on `require_param!/3` prose.
- **Comments inside the new test avoid the token `refute`.** The plan's structural criterion counts `refute` occurrences in the `awk` block, so an explanatory comment containing the word "refuted" would have failed a criterion it was written to explain. Reworded to "never denied"; the count is 0.
- **`mix ci` was run informationally, never as a gate.** No command in Task 2 invoked it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `ActiveEntitlement` did not cross-link the guide, so a plan-mandated assertion could not pass**

- **Found during:** Task 1 (first run of the new test)
- **Issue:** The plan requires all three entitlements sources to match `"guides/entitlements.md"` in a shared loop. `active_entitlement.ex` had no such reference, so the test failed RED on the unmodified repository.
- **Fix:** Added `See [Entitlements](guides/entitlements.md) for the end-to-end story.` to the `ActiveEntitlement` moduledoc, directly after the gate-fence admonition, in the identical form used by its two siblings.
- **Files modified:** `lib/lattice_stripe/entitlements/active_entitlement.ex` (outside the plan's `files_modified`, which listed only the test)
- **Verification:** docs-truth 49 tests / 0 failures; `mix docs` exit 0 with no new warning — the link resolves because the guide is registered in `extras:`.
- **Committed in:** `bbaa20c`

**2. [Rule 3 - Blocking] Gate 3's differential check failed at 48 vs baseline 42**

- **Found during:** Task 2 (first differential run)
- **Issue:** The three `LatticeStripe.Resource.require_param!/3` prose references added by 63-01 and 63-03 (`active_entitlement.ex` moduledoc + `list/3` doc, `feature.ex` `create/3` doc) each emit a `documentation references function ... but it is hidden` warning, doubled across ExDoc's two output passes — exactly the phase's +6 delta. 63-03 recorded them as accepted; the plan's gate does not accept them.
- **Fix:** Reworded all three to document the guard's behavior without the qualified autolink, per the plan's own instruction to fix autolinks rather than raise the baseline.
- **Files modified:** `lib/lattice_stripe/entitlements/active_entitlement.ex`, `lib/lattice_stripe/entitlements/feature.ex` (both outside the plan's `files_modified`)
- **Verification:** `baseline=42 current=42 surface=0` — differential PASS, surface PASS. `mix format --check-formatted`, `mix compile --warnings-as-errors`, full suite and credo all re-run green afterwards.
- **Committed in:** `e0f6dda`

---

**Total deviations:** 2 auto-fixed, both Rule 3, both `lib/` moduledoc edits outside the plan's declared `files_modified`. No Rule 4 architectural decision was needed and no checkpoint was reached.
**Impact on plan:** None on the locks' shape, count or content. Both deviations move the repository toward what the plan asserts rather than moving the assertions toward the repository — which is the whole point of a docs-truth suite.

## Issues Encountered

None blocking.

### The five gates

| Gate | Command | Result |
|---|---|---|
| 1 — unit suite | `mix test` | **2188 tests, 0 failures, 1 skipped (204 excluded)** |
| 2 — integration | `mix test --include integration test/integration/entitlements_integration_test.exs` (stripe-mock on 12111) | **7 tests, 0 failures** |
| 3 — docs, plain | `mix docs` | **exit 0** |
| 3 — docs, differential | `mix docs --warnings-as-errors` vs baseline | **baseline=42 current=42 surface=0** — PASS |
| 4 — linter | `mix credo --strict` | **2225 mods/funs, found no issues** |
| 5 — docs-truth | `mix test test/lattice_stripe/docs_truth_test.exs` | **49 tests, 0 failures** |
| (support) | `mix format --check-formatted` / `mix compile --warnings-as-errors` | exit 0 / exit 0 |

### `mix docs` warning count across the phase

| Point | Total warnings | Warnings naming an entitlements file |
|---|---|---|
| Clean HEAD (recorded baseline) | **42** | 0 |
| After 63-01 … 63-05 | 52 | 10 (4 transient guide-link + 6 hidden-helper) |
| After 63-06 | 48 | 6 (hidden-helper only) |
| **After this plan** | **42** | **0** |

The remaining 42 are entirely pre-existing and untouched by Phase 63: hidden `Tax.*` / `TaxId.*` nested-struct types (24), `File.create/3` and `../README.md` / `../notebooks/stripe_explorer.livemd` references from guides authored long before this phase (10), hidden `ObjectTypes` / `BillingPortal.Guards` / `Webhook.check_tolerance` references (8), and two IAL warnings from `meter_event_stream.ex`. Closing them is Phase 67-shaped work across the `Tax` family and the guides, not entitlements work.

### `mix ci` status

**RED — exit 1, and it was RED at clean HEAD for the same reason.** Run informationally after both task commits, never as a gate (research correction C-02, and Task 2's acceptance criteria forbid invoking it):

| `ci` step | Result |
|---|---|
| `format --check-formatted` | pass |
| `compile --warnings-as-errors` | pass |
| `credo --strict` | pass — 2225 mods/funs, found no issues |
| `test` | pass — 2188 tests, 0 failures |
| `docs --warnings-as-errors` | **fail** — "generation for html, epub formats failed due to warnings while using the --warnings-as-errors option" |

The failing step trips on the 42 pre-existing warnings enumerated above. **Zero of them name an entitlements file** (`grep 'warning:' | grep -ci 'entitle'` => 0), so Phase 63's contribution to the red is now exactly nothing. `mix ci` turns green the day those 42 are cleared — a `Tax.*`-and-guides project, unrelated to this phase.

## TDD Gate Compliance

The plan marks Task 1 `tdd="true"`, and the cycle ran genuinely, though inverted from the usual shape because the deliverable *is* a test:

- **RED** — the test was written first and run against the unmodified repository. It failed at `assert source =~ "guides/entitlements.md"` because `ActiveEntitlement` carried no guide cross-link. Real RED on real drift, not a manufactured one.
- **GREEN** — the cross-link was added (`bbaa20c`); the suite went 49/0.
- **Fail-first confirmation** — four independent mutations were then applied and reverted, each failing exactly one intended assertion.

Commit typing reflects this: `bbaa20c` is `docs` (the source change that turned RED green), `e8e3ba5` is `test` (the locks). A red commit was deliberately not pushed into history; the RED run is recorded here instead.

## Known Stubs

None introduced by this plan. The three pre-cut stub sections in `guides/entitlements.md` (`## Attaching features to products`, `## Testing`, `## Webhooks`) are 63-06's deliberate scaffolding for Phases 65 and 66 and are documented in that plan's SUMMARY; this plan neither added to nor resolved them.

## Threat Flags

None. No network endpoint, auth path, file access pattern or schema change; `mix.exs` untouched.

**T-63-04 (high, Elevation of Privilege) — mitigated and now enforced.** The fail-open reasoning behind refusing a network gate previously existed only as prose that any cleanup could delete without breaking a build. It now fails the docs-truth lane: strip `fail closed` from the module, or `entitled?` from `guides/scope.md`, and CI goes red. Combined with 63-01's `refute function_exported?` locks, both the code's shape and the reason it has that shape are enforced.

**T-63-08 (medium, Tampering) — mitigated.** `## Archiving` and `immutable` are anchored against `feature.ex`, so the only mitigation for the archived-as-deleted landmine cannot be silently removed.

**T-63-19 (high, Repudiation) — mitigated, and it earned its keep this run.** The differential gate reads its baseline with a fallback-free `cat` and actually *failed* on first execution at 48 vs 42, which is the entire reason the phase's warning debt got closed instead of quietly inherited. A gate that had defaulted its baseline, or that had been the project's already-red `ci` alias, would have taught the reader to ignore it and the +6 would have shipped.

## User Setup Required

None. `stripe-mock` was started as a throwaway Docker container for Gate 2 (`docker run -d --rm -p 12111-12112:12111-12112 stripe/stripe-mock:latest`) and stopped afterwards.

## Next Phase Readiness

**Phase 63 is complete.** All seven plans executed; ENT-01 through ENT-05 are delivered and locked.

- **Phase 65** (object-type registry + public fixtures) appends to the `## Testing` and `## Webhooks` stubs and may replace the guide's explicit `from_map/1` reconciler line with `ObjectTypes.maybe_deserialize/1`. Note that the docs-truth lock anchors `stream_entitlements!` and the fence literals, not that specific call — the swap is free.
- **Phase 66** (`Product.Feature`) appends one row to the `## Managing features` table and one module atom to the `Entitlements:` group. The new lock asserts *membership*, not exact group contents, so an added module does not break it.
- **Phase 67** (module grouping) inherits the 42 remaining ExDoc warnings, which are now the only thing standing between this project and a green `mix ci`. They are concentrated in the `Tax.*` nested-struct types and three long-standing guide references.
- **Carried forward:** the `entitled?` fence is `one-way` by intent across all four surfaces (module admonition, guide, `scope.md`, docs-truth lock). The docs-truth locks themselves are `reversible` at the cost of one commit, but any reversal is now a visible, reviewable deletion rather than a silent drift.

## Self-Check: PASSED

All three modified files exist on disk and all three commits resolve in `git log`: `bbaa20c`, `e8e3ba5`, `e0f6dda`. The docs-truth suite is green at 49 tests / 0 failures and the differential docs gate reports `baseline=42 current=42 surface=0`.

---
*Phase: 63-stripe-native-entitlements*
*Completed: 2026-07-28*
</content>
