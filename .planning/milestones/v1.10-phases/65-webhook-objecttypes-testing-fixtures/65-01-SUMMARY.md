---
phase: 65-webhook-objecttypes-testing-fixtures
plan: 01
subsystem: testing
tags: [elixir, stripe, entitlements, exdoc, hex, fixtures, webhooks]

requires:
  - phase: 63-entitlements
    provides: LatticeStripe.Entitlements.ActiveEntitlement / ActiveEntitlementSummary structs and from_map/1 decoders
  - phase: 64-meter-event-summary-reads
    provides: the docs_truth_test.exs ExDoc group-membership assertion shape and the 38-warning ExDoc baseline
provides:
  - "@object_map row \"entitlements.active_entitlement\" — maybe_deserialize/1 now types entitlement webhook payloads"
  - "Public LatticeStripe.Testing.Fixtures.Entitlements (moved from test/support/, ships in the Hex tarball)"
  - "LatticeStripe.Testing.active_entitlement/1 and active_entitlement_summary/1 typed wrappers"
  - "Proof that a test/support/ -> lib/ promotion compiles under MIX_ENV=prod and adds zero ExDoc warnings"
affects: [65-02 metering fixtures, 65-03 core billing fixtures, 65-04 remaining registry rows, 65-05 invoice fixtures, 65-06 docs sweep]

tech-stack:
  added: []
  patterns:
    - "Fixture promotion: git mv test/support/fixtures/X.ex -> lib/lattice_stripe/testing/fixtures/X.ex, rename LatticeStripe.Test.Fixtures.X -> LatticeStripe.Testing.Fixtures.X, swap @moduledoc false for a real @moduledoc, add one @spec per builder, register in mix.exs groups_for_modules[:Testing] and guides/testing.md — all in ONE commit"
    - "Tracer assertion form: feed the PUBLIC fixture (not an inline map) through ObjectTypes.maybe_deserialize/1 so one assertion crosses both the registry row and the published surface"

key-files:
  created:
    - lib/lattice_stripe/testing/fixtures/entitlements.ex
  modified:
    - lib/lattice_stripe/object_types.ex
    - lib/lattice_stripe/testing.ex
    - mix.exs
    - guides/testing.md
    - test/lattice_stripe/object_types_test.exs
    - test/lattice_stripe/testing_test.exs
    - test/lattice_stripe/docs_truth_test.exs

key-decisions:
  - "The promotion is a git mv (history follows) plus a module rename, NOT a copy — no private twin of the entitlements fixture remains anywhere in the tree"
  - "active_entitlement_list_json/2 stays in-module rather than delegating to LatticeStripe.TestHelpers.list_json/3, because TestHelpers lives in test/support/ and is unreachable from lib/ under MIX_ENV=prod"
  - "Builder bodies transferred byte-unchanged, including the trailing |> Map.merge(overrides) pipe form (not normalized to TaxId's Map.merge(canonical, overrides) call form)"
  - "The registry row was appended near the billing.meter family at the end of @object_map, not in global alphabetical position — the map is only roughly alphabetical through transfer_reversal and mix format does not reorder map keys"
  - "The new tracer test aliases the fixture module (EntitlementsFixture) rather than calling it fully-qualified — mix credo --strict Design.AliasUsage flags the nested call"

patterns-established:
  - "ExDoc group membership is asserted, not assumed: the docs-truth test was mutation-checked by removing the mix.exs entry, which fails exactly that one test"
  - "MIX_ENV=prod mix compile is the gate that proves a lib/ crossing is clean; CI does not run it, so each promoting plan runs it locally"

requirements-completed: [OBJ-01, OBJ-02]

coverage:
  - id: D1
    description: "ObjectTypes.maybe_deserialize/1 returns %ActiveEntitlement{id: \"ent_123\"} when fed the public fixture map — registry row and promoted fixture work together end-to-end"
    requirement: OBJ-01
    verification:
      - kind: unit
        ref: "test/lattice_stripe/object_types_test.exs#dispatches the public entitlement fixture to ActiveEntitlement.from_map/1"
        status: pass
      - kind: other
        ref: "mix run -e 'IO.inspect(LatticeStripe.ObjectTypes.fetch_module(\"entitlements.active_entitlement\"))' -> {:ok, LatticeStripe.Entitlements.ActiveEntitlement}"
        status: pass
    human_judgment: false
  - id: D2
    description: "LatticeStripe.Testing.Fixtures.Entitlements is public, callable from lib/, and ships in the Hex tarball (files: [\"lib\", ...])"
    requirement: OBJ-02
    verification:
      - kind: other
        ref: "MIX_ENV=prod mix compile — exit 0"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/testing_test.exs#promoted entitlement builders are callable at arity 0 (OBJ-02 empty-input edge)"
        status: pass
    human_judgment: false
  - id: D3
    description: "LatticeStripe.Testing.active_entitlement/1 and active_entitlement_summary/1 convert fixture maps into typed structs, and the summary keeps its no-:id contract"
    requirement: OBJ-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/testing_test.exs#return typed entitlement structs from the promoted public fixtures"
        status: pass
    human_judgment: false
  - id: D4
    description: "OBJ-02 empty/edge coverage: every builder is callable at arity 0, overrides win over canonical values, and active_entitlement_list_json/0 returns a one-element list envelope"
    requirement: OBJ-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/testing_test.exs#entitlement builder overrides win over the canonical value"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/testing_test.exs#active_entitlement_list_json/0 returns a one-element list envelope"
        status: pass
    human_judgment: false
  - id: D5
    description: "No private twin remains: test/support/fixtures/entitlements.ex is gone and zero references to LatticeStripe.Test.Fixtures.Entitlements survive"
    requirement: OBJ-02
    verification:
      - kind: other
        ref: "grep -r 'LatticeStripe.Test.Fixtures.Entitlements' test/ lib/ -> 0 matches; [ -f test/support/fixtures/entitlements.ex ] -> false"
        status: pass
      - kind: unit
        ref: "mix test — 2311 tests, 0 failures (suite would not compile if any caller alias were stale)"
        status: pass
    human_judgment: false
  - id: D6
    description: "The fixture is registered with ExDoc (mix.exs groups_for_modules[:Testing]) and named in guides/testing.md, so an adopter can discover it"
    requirement: OBJ-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/docs_truth_test.exs#the promoted entitlements fixture keeps its ExDoc placement and guide mention"
        status: pass
      - kind: other
        ref: "mutation check — removing the mix.exs Testing: entry fails exactly that test and nothing else (2311 tests, 1 failure); restored"
        status: pass
    human_judgment: false

duration: 5min
completed: 2026-07-29
status: complete
---

# Phase 65 Plan 01: Entitlements Tracer Summary

**One Stripe object (`entitlements.active_entitlement`) wired end-to-end — registry row, `test/support/` → `lib/` fixture promotion, typed wrappers, ExDoc registration, and guide mention — proving the Phase 65 promotion mechanism under `MIX_ENV=prod` before four expansion plans repeat it.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-07-29T02:13:55Z
- **Completed:** 2026-07-29T02:19:14Z
- **Tasks:** 2
- **Files modified:** 12 (1 moved+renamed, 11 edited)

## Accomplishments

- **`@object_map` grew 48 → 49.** `mix run -e 'IO.puts(map_size(LatticeStripe.ObjectTypes.object_map()))'` prints **49**, and `fetch_module("entitlements.active_entitlement")` returns `{:ok, LatticeStripe.Entitlements.ActiveEntitlement}`. Entitlement webhook payloads that previously fell through `maybe_deserialize/1` as raw maps now decode into typed structs.
- **The phase's first `test/support/` → `lib/` crossing is proven.** `MIX_ENV=prod mix compile` **exits 0** — the promoted file references no test-only module (notably it does not reach for `LatticeStripe.TestHelpers.list_json/3`, which is unreachable from `lib/`). 65-02, 65-03 and 65-05 each repeat this crossing and can now rely on the mechanism rather than re-proving it.
- **The fixture is discoverable, not just published.** It carries a real `@moduledoc` (zero `@moduledoc false`), four `@spec` lines, a `mix.exs` `groups_for_modules[:Testing]` entry, and a `guides/testing.md` bullet — and the ExDoc placement is locked by a **mutation-checked** docs-truth test.
- **Zero docs regression.** `mix docs` warnings held at the **38** baseline, with **0** warnings matching `entitlement|meter|testing|fixture`.
- **No private twin.** `test/support/fixtures/entitlements.ex` no longer exists and `grep -r 'LatticeStripe.Test.Fixtures.Entitlements' test/ lib/` returns nothing — the `Dispute` drift hazard is not reproduced.

## Task Commits

1. **Task 1 (tracer): End-to-end entitlement deserialization from a public fixture** — `90852b3` (feat)
2. **Task 2: Lock the public surface — builder, wrapper, and ExDoc-placement assertions** — `12f4eae` (test)

**Tracer feedback gate:** auto mode active (`workflow.auto_advance: true`), so the tracer's full `<verify>` chain was re-run after the Task 1 commit and before Task 2 — all six steps green.

## Files Created/Modified

- `lib/lattice_stripe/testing/fixtures/entitlements.ex` — **moved** from `test/support/fixtures/entitlements.ex` (git rename, 79% similarity) and renamed to `LatticeStripe.Testing.Fixtures.Entitlements`. Six-line PROMOTION TARGET header deleted, `@moduledoc false` replaced with "Canonical raw fixtures for Stripe entitlement objects.", four `@spec` lines added. All four builder bodies and `@doc`s transferred unchanged — including the `active_entitlement_summary_json/1` doc explaining that the nested `entitlements` url is the **un-rewritten** `/v1/customer/cus_ABC123customer/entitlements` webhook path that makes Phase 63 D-04's rewrite provable.
- `lib/lattice_stripe/object_types.ex` — one `@object_map` row: `"entitlements.active_entitlement" => LatticeStripe.Entitlements.ActiveEntitlement`, appended after `"line_item"` near the family-grouped tail.
- `lib/lattice_stripe/testing.ex` — `Entitlements` added to the single `alias LatticeStripe.{...}` block (between `Dispute` and `Event`) **in the same commit as its users**, plus `active_entitlement/1` and `active_entitlement_summary/1` in the `dispute/1` shape (`@doc`, `@spec`, one-line delegation).
- `mix.exs` — `LatticeStripe.Testing.Fixtures.Entitlements` appended to `groups_for_modules[:Testing]` after `...TaxId`. `files:` and `elixirc_paths/1` untouched.
- `guides/testing.md` — fixture bullet added to the public-fixture list; `active_entitlement/1` added to the typed-wrapper sentence. The stale "v1.3 resource families" claim was left alone (65-06 owns it).
- `test/lattice_stripe/object_types_test.exs` — the tracer test inside the existing `describe "maybe_deserialize/1"`, plus an `EntitlementsFixture` alias.
- `test/lattice_stripe/testing_test.exs` — three tests added to `describe "public fixture builders"` and one to `describe "typed wrappers"` (both extended, neither duplicated); `Entitlements` added to the alias block in the same edit as its first use.
- `test/lattice_stripe/docs_truth_test.exs` — ExDoc group-membership + guide-prose test in the Phase 63/64 shape, with a comment recording why it is structural.
- `test/lattice_stripe/entitlements/{active_entitlement,active_entitlement_summary,feature,active_entitlement_stream}_test.exs` — one-token alias retarget each, `Test.Fixtures` → `Testing.Fixtures`.

## Decisions Made

- **`active_entitlement_list_json/2` stays in-module.** Replacing it with `LatticeStripe.TestHelpers.list_json/3` would compile in `:test` and fail `MIX_ENV=prod mix compile`, because `TestHelpers` lives in `test/support/` (RESEARCH Pitfall 3). The duplication is the correct trade.
- **Bodies transferred verbatim, including the pipe form.** The promoted builders keep `%{...} |> Map.merge(overrides)` rather than being normalized to `TaxId`'s `Map.merge(canonical, overrides)` call form — the ROADMAP build constraint says bodies transfer unchanged, and re-authoring them is how a fixture silently drifts from what its callers assert.
- **The registry row went at the tail, not alphabetically.** `@object_map` is only roughly alphabetical through `"transfer_reversal"` and then appends by family; `mix format` never reorders map keys, so alphabetical placement would only look tidy while diverging from the file's actual convention.
- **`ActiveEntitlementSummary` was not touched.** Its missing `:id` is a deliberate match to Stripe's object (Phase 63 F-02), guarded by two in-source comments. Task 2 asserts the absence survives the new public wrapper via `refute Map.has_key?(summary, :id)`.
- **`reversibility: one-way` accepted without a checkpoint,** per the plan: the module name and all four function names are dictated verbatim by the locked ROADMAP Phase 65 build constraint, so the door was already chosen.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Aliased the fixture module in the tracer test to satisfy `mix credo --strict`**

- **Found during:** Task 1 (tracer verification chain)
- **Issue:** The tracer test called `LatticeStripe.Testing.Fixtures.Entitlements.active_entitlement_json()` fully-qualified, as the plan's action text describes. `mix credo --strict` — step 5 of the task's own `<verify>` chain — flagged it with `Design.AliasUsage` ("Nested modules could be aliased at the top of the invoking module", `object_types_test.exs:39:13`) and exited **2**. Credo was clean before this change, so the finding was introduced here.
- **Fix:** Added `alias LatticeStripe.Testing.Fixtures.Entitlements, as: EntitlementsFixture` at the top of `LatticeStripe.ObjectTypesTest` — matching the file's existing `MeterErrorReportFixture` alias convention — and called `EntitlementsFixture.active_entitlement_json()`. The assertion still consumes the **public** fixture, so the tracer property the plan cares about (crossing the registry AND the published surface in one line) is unchanged.
- **Files modified:** `test/lattice_stripe/object_types_test.exs`
- **Verification:** `mix credo --strict` exits **0**, "found no issues"; targeted and full suites green.
- **Committed in:** `90852b3` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Cosmetic call-site form only. No scope creep; the plan's stated intent (public fixture, not an inline map) is preserved exactly.

## Issues Encountered

- **`git add` pathspec on the moved-from path.** `git mv` had already staged the rename, so passing `test/support/fixtures/entitlements.ex` to `git add` aborted the whole `git add` invocation with `fatal: pathspec ... did not match any files`, leaving nothing staged. Re-run without the deleted path; the rename was already in the index (`R  test/support/... -> lib/...`).
- **Neither known pre-existing flake fired.** `client_test.exs:912` and `batch_test.exs:72` both passed on every run; no re-run was needed.

## Verification Results

| Gate | Result |
|---|---|
| `mix test` | **2311 tests, 0 failures**, 1 skipped (baseline 2305 → 2306 after Task 1 → 2311 after Task 2) |
| `mix format --check-formatted` | pass |
| `mix compile --warnings-as-errors` | pass (proves the `Entitlements` alias landed with its user) |
| `mix credo --strict` | exit 0, "found no issues" |
| `MIX_ENV=prod mix compile` | **exit 0** |
| `mix docs` warnings | **38** (== baseline); `entitlement\|meter\|testing\|fixture` matches: **0** |
| `map_size(object_map())` | **49** (48 at plan time + 1) |
| Secrets scrub (`sk_live\|pk_live\|whsec_\|rk_live\|acct_1`) | no matches, before and after the move (T-65-03 mitigated) |
| Mutation check (D6) | removing the `mix.exs` `Testing:` entry fails **exactly** the new docs-truth test (2311 tests, 1 failure); restored, `git diff mix.exs` empty |

## Known Stubs

None. No placeholder values, TODO/FIXME markers, or unwired data paths were introduced.

## Threat Flags

None. No new network endpoint, auth path, or schema change beyond the registry row already dispositioned as T-65-04 (`accept`) in the plan's threat model. T-65-03 (secrets crossing into `lib/`) was mitigated as specified: the grep was run before the move and re-verified after, both clean. Zero packages installed (T-65-SC holds).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **The promotion mechanism is proven and reusable.** 65-02 (metering), 65-03 (core billing) and 65-05 (invoice) can follow the exact recipe recorded under `patterns-established`: `git mv` + module rename + real `@moduledoc` + one `@spec` per builder + `mix.exs` group entry + guide bullet + caller alias retargets, all in one commit, gated by `MIX_ENV=prod mix compile`.
- **65-04 inherits a 49-row `@object_map`.** Its three remaining rows (`entitlements.active_entitlement_summary`, `billing.meter_event`, `billing.meter_event_summary`) take the map to 52. The `"entitlements.active_entitlement"` key is now covered by a test, so a later plan cannot silently drop it.
- **65-06 still owns two doc corrections** carried forward untouched here: the stale "v1.3 resource families" claim in `guides/testing.md`, and the `guides/getting-started.md` `../README.md` broken link noted in STATE.
- **No blockers.** The ExDoc warning count is unchanged at 38, so the differential docs gate remains usable for the rest of the phase.

## Self-Check: PASSED

- `lib/lattice_stripe/testing/fixtures/entitlements.ex` — exists
- `.planning/phases/65-webhook-objecttypes-testing-fixtures/65-01-SUMMARY.md` — exists
- `test/support/fixtures/entitlements.ex` — confirmed absent (intended)
- Commit `90852b3` — present in git log
- Commit `12f4eae` — present in git log

---
*Phase: 65-webhook-objecttypes-testing-fixtures*
*Completed: 2026-07-29*
