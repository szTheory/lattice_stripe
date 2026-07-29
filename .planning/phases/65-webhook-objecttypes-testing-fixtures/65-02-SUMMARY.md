---
phase: 65-webhook-objecttypes-testing-fixtures
plan: 02
subsystem: testing
tags: [elixir, stripe, metering, fixtures, exdoc, hex, semver]

requires:
  - phase: 65-webhook-objecttypes-testing-fixtures
    plan: 01
    provides: the test/support/ -> lib/ promotion recipe, the MIX_ENV=prod compile gate, and the docs-truth ExDoc group assertion shape
  - phase: 64-meter-event-summary-reads
    provides: LatticeStripe.Billing.MeterEvent / MeterEventSummary / MeterErrorReport structs and their from_map/from_event decoders
provides:
  - "Public LatticeStripe.Testing.Fixtures.MeterEvent (flat, depth-3)"
  - "Public LatticeStripe.Testing.Fixtures.MeterEventSummary (flat, depth-3)"
  - "Public LatticeStripe.Testing.Fixtures.MeterErrorReport (flat, depth-3)"
  - "LatticeStripe.Testing.meter_event/1 and meter_event_summary/1 typed wrappers"
  - "Q1 = flat-three — the binding public-API naming decision 65-04 writes dispatch tests against"
affects: [65-03 core billing fixtures, 65-04 remaining registry rows, 65-05 invoice fixtures, 65-06 docs sweep]

tech-stack:
  added: []
  patterns:
    - "Flat promotion of a nested fixture family: split the multi-module private file into one public file per promoted module, name them Testing.Fixtures.<Object> (never Testing.Fixtures.<Family>.<Object>), and leave un-promoted siblings behind in the reduced private file"
    - "Partial promotion leaves a reduced private remainder — the superseded in-source promotion header is replaced by a note recording the decision and why the remaining modules stay private, never deleted silently"
    - "Caller rewiring under a flat promotion: alias the promoted fixture with an explicit `as: <Object>Fixture` suffix, because the unsuffixed name collides with the Billing struct alias already in the same test module"

key-files:
  created:
    - lib/lattice_stripe/testing/fixtures/meter_event.ex
    - lib/lattice_stripe/testing/fixtures/meter_event_summary.ex
    - lib/lattice_stripe/testing/fixtures/meter_error_report.ex
  modified:
    - test/support/fixtures/metering.ex
    - lib/lattice_stripe/testing.ex
    - mix.exs
    - guides/testing.md
    - test/lattice_stripe/testing_test.exs
    - test/lattice_stripe/docs_truth_test.exs
    - test/lattice_stripe/object_types_test.exs
    - test/lattice_stripe/billing/meter_event_test.exs
    - test/lattice_stripe/billing/meter_event_summary_test.exs
    - test/lattice_stripe/billing/meter_event_summary_pagination_test.exs
    - test/lattice_stripe/billing/meter_guards_test.exs
    - test/lattice_stripe/billing/meter_error_report_test.exs

key-decisions:
  - "Q1 = flat-three (operator decision, one-way door): exactly three meter fixtures are promoted, flat, at depth 3 — Testing.Fixtures.MeterEvent, Testing.Fixtures.MeterEventSummary, Testing.Fixtures.MeterErrorReport"
  - "Meter, MeterEventAdjustment and MeterEventStreamSession stay PRIVATE in test/support/fixtures/metering.ex — no requirement names them and every promoted module is semver-covered at the Hex 1.8.0 tag"
  - "No LatticeStripe.Testing.Fixtures.Metering namespace module exists; the project has zero depth-4 public fixture names"
  - "The Phase-64 in-source header asking for a nested whole-file promotion is superseded and replaced by a note recording flat-three, not deleted silently"
  - "MeterEventStreamSession's authentication_token never crossed into lib/ — under flat-three that fixture does not move at all"
  - "No typed wrapper for MeterErrorReport: it is decoded by from_event/1, not from_map/1, so a from_map/1-shaped wrapper would misrepresent how the object is consumed"
  - "Promoted fixtures are aliased with an explicit `as: ...Fixture` suffix in callers, because the bare name collides with the LatticeStripe.Billing struct alias already present in the same test module"

requirements-completed: [OBJ-02]

coverage:
  - id: D1
    description: "The three promoted meter fixture modules are public, callable from lib/, and each returns a string-keyed map"
    requirement: OBJ-02
    verification:
      - kind: other
        ref: "MIX_ENV=prod mix compile — exit 0"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/testing_test.exs#promoted meter builders are callable at arity 0 (OBJ-02 empty-input edge)"
        status: pass
      - kind: other
        ref: "mix run -e 'IO.puts(is_map(LatticeStripe.Testing.Fixtures.MeterEvent.basic()))' -> true"
        status: pass
    human_judgment: false
  - id: D2
    description: "Testing.meter_event/1 returns %Billing.MeterEvent{} and Testing.meter_event_summary/1 returns %Billing.MeterEventSummary{}"
    requirement: OBJ-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/testing_test.exs#return typed meter structs from the promoted public fixtures"
        status: pass
      - kind: other
        ref: "mix run -e '...Testing.meter_event(...).__struct__' -> LatticeStripe.Billing.MeterEvent"
        status: pass
    human_judgment: false
  - id: D3
    description: "OBJ-02 adjacency edge: no promoted module collides with a pre-existing public fixture name, and no promoted module retains a private twin"
    requirement: OBJ-02
    verification:
      - kind: other
        ref: "grep -rn 'Test.Fixtures.Metering.MeterEvent|...MeterEventSummary|...MeterErrorReport' test/ lib/ -> 0 matches; the reduced private file retains only Meter, MeterEventAdjustment, MeterEventStreamSession"
        status: pass
      - kind: unit
        ref: "mix test — 2315 tests, 0 failures (the suite would not compile if any caller alias were stale)"
        status: pass
    human_judgment: false
  - id: D4
    description: "OBJ-02 ordering edge: fixture maps are string-keyed with no observable key order; the only order-sensitive semantic is Map.merge/2 override precedence, where the caller-supplied key wins"
    requirement: OBJ-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/testing_test.exs#meter builder overrides win over the canonical value"
        status: pass
    human_judgment: false
  - id: D5
    description: "All metering caller test files compile and pass after the rename, including object_types_test.exs (caller #1)"
    requirement: OBJ-02
    verification:
      - kind: unit
        ref: "mix test test/lattice_stripe/billing/ test/lattice_stripe/object_types_test.exs test/lattice_stripe/testing_test.exs test/lattice_stripe/docs_truth_test.exs — 309 tests, 0 failures"
        status: pass
    human_judgment: false
  - id: D6
    description: "Every promoted meter fixture module appears in mix.exs groups_for_modules[:Testing] and in guides/testing.md"
    requirement: OBJ-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/docs_truth_test.exs#the promoted meter fixtures keep their ExDoc placement and guide mention"
        status: pass
      - kind: other
        ref: "mix docs exit 0; warnings 38 (== baseline); entitlement|meter|testing|fixture matches 0"
        status: pass
    human_judgment: false
  - id: D7
    description: "T-65-02 / T-65-06: the MeterEvent Inspect payload masking is untouched and the MeterErrorReport values transferred verbatim"
    requirement: OBJ-02
    verification:
      - kind: other
        ref: "git diff --exit-code lib/lattice_stripe/billing/meter_event.ex -> clean; line-by-line body diff of all three promoted modules vs the pre-move source -> 0 missing of 188 lines"
        status: pass
    human_judgment: false

duration: 7min
completed: 2026-07-29
status: complete
---

# Phase 65 Plan 02: Meter Fixture Promotion Summary

**Three meter fixtures promoted from the private `test/support/` namespace into the public, flat `LatticeStripe.Testing.Fixtures.*` surface with typed wrappers, ExDoc registration and verbatim-preserved wire values — resolving a one-way public-API naming door in favour of the project's ten-for-ten flat convention over a superseded Phase-64 instruction to nest.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-07-29T02:24:39Z
- **Completed:** 2026-07-29T02:31:00Z
- **Tasks:** 2 (Task 1 = the Q1 checkpoint, resolved by the operator; Task 2 = implementation)
- **Files modified:** 15 (3 created, 12 edited)

## The Q1 Decision — recorded verbatim

**Selected option id: `flat-three`** — "Flat, promote three (RECOMMENDED — 65-RESEARCH.md § Q1)".

This decision is a **one-way door**: these module names become semver-covered public API on the Hex 1.8.0 tag, and renaming them afterwards is a breaking change for adopters. 65-04 writes dispatch tests against these exact names.

**The three public module names, in full:**

- `LatticeStripe.Testing.Fixtures.MeterEvent`
- `LatticeStripe.Testing.Fixtures.MeterEventSummary`
- `LatticeStripe.Testing.Fixtures.MeterErrorReport`

**What stays private, and why:** `Meter`, `MeterEventAdjustment` and `MeterEventStreamSession` remain in `test/support/fixtures/metering.ex` under `LatticeStripe.Test.Fixtures.Metering`. They are not promoted, not published, and their payloads — including `MeterEventStreamSession`'s `"authentication_token"` — never cross into `lib/`. No requirement names them, and every module promoted is semver surface the project must keep forever.

**No `LatticeStripe.Testing.Fixtures.Metering` namespace module was created.** The project still has zero depth-4 public fixture names.

**Rationale:** flat matches the established convention eleven-for-eleven across `lib/lattice_stripe/testing/fixtures/*.ex`; the Tax family was deliberately flattened on promotion for the same reason; module names become semver-covered public API at Hex 1.8.0, so the surface grows only where OBJ-01/OBJ-02 require it.

**Superseded authority:** the Phase-64 in-source header at `test/support/fixtures/metering.ex:1-6`, which instructed a nested `Testing.Fixtures.Metering` promotion, was deleted and replaced with a ten-line note recording that Phase 65 promoted three fixtures flat per Q1 = `flat-three` and that the remaining three are intentionally private. The header was not removed silently — deleting it without a replacement would have lost the reason.

## Task Commits

1. **Task 1: Q1 checkpoint (`checkpoint:decision`, gate="blocking")** — resolved by the operator as `flat-three`; no code artifact, recorded here and in STATE.md.
2. **Task 2: Promote the meter fixtures, add typed wrappers, and rewire all callers** — `c07d386` (feat)

## Accomplishments

- **Three fixtures crossed into `lib/` and `MIX_ENV=prod mix compile` exits 0** — none of the promoted modules reaches for `LatticeStripe.TestHelpers` or any other `test/support/` symbol. `MeterEventSummary.list_response/1` keeps building its own list envelope in-module, exactly as 65-01 established.
- **Wire values transferred verbatim, proven line-by-line.** A mechanical diff of all three promoted modules against their pre-move source found **0 missing lines out of 188** (`MeterEvent` 23, `MeterEventSummary` 36, `MeterErrorReport` 129). The `MeterErrorReport` 25-line provenance comment — the one recording that every id, message, code and timestamp is copied from Stripe's published example, and why a hand-invented fixture once shipped a broken adopter handler — carried over intact.
- **The typed wrappers landed with their alias in one commit.** `Billing` was added to the single `alias LatticeStripe.{...}` block in `lib/lattice_stripe/testing.ex` alphabetically ahead of `CreditNote`, in the same commit as `meter_event/1` and `meter_event_summary/1`. An alias landing ahead of its user fails `mix compile --warnings-as-errors` (STATE `[63-01]`); it did not.
- **`lib/lattice_stripe/billing/meter_event.ex` is byte-identical to its pre-plan state.** `git diff --exit-code` is clean, so the custom `defimpl Inspect` masking `:payload` (T-65-02) survives untouched.
- **Zero docs regression.** `mix docs` exits 0 with warnings held at the **38** baseline and **0** matches for `entitlement|meter|testing|fixture`. The gate substring list was not rescoped.

## Files Created/Modified

- `lib/lattice_stripe/testing/fixtures/meter_event.ex` — **new**. `LatticeStripe.Testing.Fixtures.MeterEvent` with `basic/1`. Real `@moduledoc` ("Canonical raw fixtures for Stripe billing meter event objects."), one `@spec`. The `@doc` explaining that `payload` intentionally carries both the customer-mapping key and the value key is preserved — it is load-bearing for the Inspect-masking tests.
- `lib/lattice_stripe/testing/fixtures/meter_event_summary.ex` — **new**. `basic/1` and `list_response/1`. Both `@doc`s preserved, including the F-02 note (the object never says which customer it belongs to) and the F-05 note (`aggregated_value` is a float on the read path, carried as `42.5` precisely so a test can prove it is never coerced to an integer).
- `lib/lattice_stripe/testing/fixtures/meter_error_report.ex` — **new**. `basic/1`, `event/1`, `no_meter_found_event/1`, `meter_id/0`, plus both module attributes. The provenance comment and all four `@doc`s carried intact.
- `test/support/fixtures/metering.ex` — reduced from 332 to 118 lines. Retains only `Meter`, `MeterEventAdjustment` and `MeterEventStreamSession`. The six-line `# PROMOTION TARGET` header is gone (`grep -c` returns 0), replaced by the flat-three note.
- `lib/lattice_stripe/testing.ex` — `Billing` added to the alias block; `meter_event/1` and `meter_event_summary/1` added in the `dispute/1` shape (`@doc`, `@spec`, one-line delegation).
- `mix.exs` — three modules appended to `groups_for_modules[:Testing]` after `...Entitlements`. `files:` and `elixirc_paths/1` untouched; `deps/0` unchanged (T-65-SC holds).
- `guides/testing.md` — three fixture bullets added to the public-fixture list; `meter_event/1` added to the typed-wrapper sentence.
- `test/lattice_stripe/testing_test.exs` — two tests added to the existing `describe "public fixture builders"` and one to the existing `describe "typed wrappers"`. No new `describe` blocks. `Billing` added to the alias block in the same edit as its first use.
- `test/lattice_stripe/docs_truth_test.exs` — one ExDoc group-membership + guide-prose test in the Phase 64 metering-block shape.
- **Six caller files retargeted:** `object_types_test.exs` and `billing/meter_error_report_test.exs` (alias retarget only, call sites unchanged); `billing/meter_event_test.exs`, `billing/meter_event_summary_test.exs`, `billing/meter_event_summary_pagination_test.exs` and `billing/meter_guards_test.exs` (alias replaced plus call-site rewrites).

## Decisions Made

- **`as: ...Fixture` aliases were mandatory, not stylistic.** Under `flat-three` the promoted module `LatticeStripe.Testing.Fixtures.MeterEvent` shares its last segment with `LatticeStripe.Billing.MeterEvent`, which four of the six retargeted test modules already alias. A bare `alias LatticeStripe.Testing.Fixtures.MeterEvent` would shadow the struct alias and break every `%MeterEvent{}` match in the file. `MeterEventFixture` / `MeterEventSummaryFixture` follow the file's own pre-existing `MeterErrorReportFixture` convention.
- **Alias blocks were reordered where the retarget changed sort position.** In `object_types_test.exs` the fixture alias moved below `EntitlementsFixture`, because `Testing.Fixtures.Entitlements` sorts before `Testing.Fixtures.MeterErrorReport` and `mix credo --strict` enforces `Readability.AliasOrder`.
- **No `MeterErrorReport` typed wrapper**, per the plan: that object is decoded by `from_event/1`, and a `from_map/1`-shaped wrapper would teach adopters the wrong consumption path.
- **The `%MeterEvent{}` assertion matches on `event_name:`, not `object:`.** The struct is the EVENT-05 minimal shape and has no `:object` field, so `result.object` raises `KeyError`. A comment in the test records this so a future contributor does not "fix" it by adding the field.

## Deviations from Plan

### Deviation 1 — six caller files needed edits, not nine (scope narrowing, no rule invoked)

The plan and the continuation brief both anticipated **nine** caller files. Walking the caller table row-by-row against the tree, as the plan's action text requires, showed that **three of the nine reference only fixtures that stay private under `flat-three`**:

| File | References | Action |
|---|---|---|
| `billing/meter_test.exs` | `Metering.Meter.basic/deactivated` only | **unchanged** — correctly keeps `alias LatticeStripe.Test.Fixtures.Metering` |
| `billing/meter_event_stream_test.exs` | `Metering.MeterEventStreamSession.basic` only | **unchanged** — same reason |
| `billing/meter_event_adjustment_test.exs` | `Metering.MeterEventAdjustment.basic` only | **unchanged** — same reason |

Editing these three would have been wrong: their fixtures did not move, so retargeting their aliases would not compile. This is the correct consequence of `flat-three` being a *partial* promotion — the plan's nine-file count was written before the option was selected and reflects the `nested-all-six` / `flat-all-six` worlds, where every caller shifts. The `files_modified` frontmatter list is therefore a superset of what was touched.

**Verification that no caller was missed:** `grep -rn 'Test.Fixtures.Metering.MeterEvent\b|...MeterEventSummary|...MeterErrorReport|Metering.MeterEvent.|Metering.MeterEventSummary.|Metering.MeterErrorReport.' test/ lib/` returns **0**, and the three remaining `Test.Fixtures.Metering` aliases resolve only to modules that still exist there. A missed caller would have been a compile error, not a silent bug.

### Auto-fixed Issues

None. No bug, missing-critical-functionality, or blocking issue was encountered. Notably the 65-01 `Design.AliasUsage` deviation did **not** recur — its lesson was inherited and applied from the start: every promoted fixture was aliased at the top of each caller module rather than called fully-qualified, so `mix credo --strict` was green on first run.

---

**Total deviations:** 1 (scope narrowing, decision-driven), 0 auto-fixed
**Impact on plan:** None on outcome. The plan's stated intent — no promoted fixture retains a private twin, every caller compiles against the new names — is satisfied exactly.

## Issues Encountered

- **A shell-quoting artifact briefly faked a body-transfer failure.** The first verbatim-diff pass reported six "MISSING" lines, all of the form `def basic(overrides \\ %{}) do`. The cause was backslash mangling in the shell loop, not real drift. Re-running the comparison in Python (escaping-safe) confirmed **0 missing lines of 188**. Worth recording because the naive shell form of this check will fire a false alarm on any Elixir default-argument head.
- **Neither known pre-existing flake fired.** `client_test.exs:912` and `batch_test.exs:72` both passed; no re-run was needed.
- **One pre-existing deprecation warning is emitted by `meter_test.exs:179`** (`Meter.status_atom/1`). It predates this plan, lives in a file this plan did not touch, and is out of scope per the executor scope boundary.

## Verification Results

The five-step differential phase gate from `65-VALIDATION.md`, plus the 65-01 prod-compile gate:

| Gate | Result |
|---|---|
| `mix format --check-formatted` | pass |
| `mix compile --warnings-as-errors` | pass (proves the `Billing` alias landed with its users) |
| `mix credo --strict` | **exit 0**, "2298 mods/funs, found no issues" |
| `mix test` | **2315 tests, 0 failures**, 1 skipped (baseline 2311 → +4 new) |
| Targeted suites (billing/ + object_types + testing + docs_truth) | **309 tests, 0 failures** |
| `mix docs` | exit 0; warnings **38** (== baseline); `entitlement\|meter\|testing\|fixture` matches **0** |
| `MIX_ENV=prod mix compile` | **exit 0** |
| `@moduledoc false` in the three promoted files | **0, 0, 0** |
| `grep -c 'PROMOTION TARGET' test/support/fixtures/metering.ex` | **0** |
| Provenance comment in promoted `meter_error_report.ex` | present |
| Secrets scrub (`sk_live\|pk_live\|whsec_\|rk_live\|acct_1`) on source and all three promoted files | **no matches** (T-65-03 mitigated) |
| `authentication_token` anywhere under `lib/lattice_stripe/testing/fixtures/` | **absent** |
| Body-transfer diff vs pre-move source | **0 missing of 188 lines** (T-65-06 mitigated) |
| `git diff --exit-code lib/lattice_stripe/billing/meter_event.ex` | clean (T-65-02 mitigated) |
| Old-path references to promoted modules in `test/` + `lib/` | **0** |
| `mix run` — `is_map(Fixtures.MeterEvent.basic())` | `true` |
| `mix run` — `Testing.meter_event(...).__struct__` | `LatticeStripe.Billing.MeterEvent` |

## Known Stubs

None. No placeholder values, TODO/FIXME markers, or unwired data paths were introduced. Every promoted fixture value is either verbatim from the pre-move private source or verbatim from Stripe's published example.

## Threat Flags

None. No new network endpoint, auth path, file access pattern, or schema change at a trust boundary. All three `mitigate` dispositions in the plan's threat register were applied and verified:

- **T-65-02** (Inspect masking on `%MeterEvent{}`) — `git diff --exit-code` on `lib/lattice_stripe/billing/meter_event.ex` is clean; the file was never opened for edit.
- **T-65-03** (secrets crossing into `lib/`) — the grep ran before the move and again on all three promoted files, both clean. Under `flat-three`, `MeterEventStreamSession`'s `tok_test_abc` does not move at all, which the `authentication_token` absence check confirms.
- **T-65-06** (tampering with `MeterErrorReport` wire values) — proven by the 188-line body-transfer diff plus the provenance-comment presence check.
- **T-65-SC** (package-manager installs) — zero packages installed; `mix.exs` `deps/0` unchanged.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **65-04 has its binding names.** Dispatch tests must be written against `LatticeStripe.Testing.Fixtures.MeterEvent` and `LatticeStripe.Testing.Fixtures.MeterEventSummary` — flat, depth-3, no `Metering` segment. Both are public and both have typed wrappers.
- **`@object_map` is untouched at 49 rows.** This plan added no registry rows; 65-04 still takes it to 52 with `entitlements.active_entitlement_summary`, `billing.meter_event` and `billing.meter_event_summary`.
- **The partial-promotion pattern is now proven** for 65-03 and 65-05: a private fixture file can be split rather than moved wholesale, and the un-promoted remainder keeps working with its original alias untouched.
- **The ExDoc warning count is still 38**, so the differential docs gate remains usable for the rest of the phase.
- **65-06 still owns two doc corrections** carried forward untouched: the stale "v1.3 resource families" claim in `guides/testing.md`, and the `guides/getting-started.md` `../README.md` broken link.
- **No blockers.**

## Self-Check: PASSED

- `lib/lattice_stripe/testing/fixtures/meter_event.ex` — exists
- `lib/lattice_stripe/testing/fixtures/meter_event_summary.ex` — exists
- `lib/lattice_stripe/testing/fixtures/meter_error_report.ex` — exists
- `test/support/fixtures/metering.ex` — exists, reduced to three private modules
- Commit `c07d386` — present in git log
- `.planning/phases/65-webhook-objecttypes-testing-fixtures/65-02-SUMMARY.md` — exists

---
*Phase: 65-webhook-objecttypes-testing-fixtures*
*Completed: 2026-07-29*
