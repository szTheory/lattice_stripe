---
phase: 63-stripe-native-entitlements
plan: 01
subsystem: api
tags: [stripe, entitlements, elixir, mox, exunit, tdd, tracer]

# Dependency graph
requires:
  - phase: pre-existing library core
    provides: "LatticeStripe.Resource (require_param!/3, unwrap_list/2, unwrap_bang!/1), LatticeStripe.Client, LatticeStripe.Request, LatticeStripe.List, LatticeStripe.TestHelpers, LatticeStripe.MockTransport"
provides:
  - "LatticeStripe.Entitlements.ActiveEntitlement — list/3, list!/3, from_map/1, list_path/0, and the canonical @list_path \"/v1/entitlements/active_entitlements\""
  - "LatticeStripe.Entitlements.Feature — decode half (struct, @type t, from_map/1, list_path/0) and the D-15 cross-reference moduledoc"
  - "LatticeStripe.Test.Fixtures.Entitlements — four wire-shaped fixture functions with the exact names Phase 65 promotes, carrying the D-27/C-01 promotion header"
  - "LatticeStripe.TestHelpers.list_json/3 — backward-compatible has_more third arg (D-28)"
  - "docs-warning-baseline.txt — clean-HEAD ExDoc warning count (42) for the 63-07 differential docs gate"
  - "The parentless Entitlements namespace layout (D-16) proven end-to-end — the shape every later Phase 63 plan expands from"
affects: [63-02, 63-03, 63-04, 63-05, 63-06, 63-07, phase-65-object-types, phase-66-product-features]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single-owner canonical path: @list_path + @doc false list_path/0 accessor (D-06)"
    - "Three-clause idempotent from_map/1 with the struct clause preceding the is_map/1 clause (D-07)"
    - "Expandable-field decode by calling the sibling module's from_map/1 directly, never via ObjectTypes (F-09)"
    - "Pre-network required-param guard via Resource.require_param!/3, proven with zero Mox expectations (C-07)"
    - "L1 structural surface lock via refute/assert function_exported? (D-23)"
    - "Rejected-helper name kept PRESENT in prose, absence proven structurally (D-24)"

key-files:
  created:
    - lib/lattice_stripe/entitlements/active_entitlement.ex
    - lib/lattice_stripe/entitlements/feature.ex
    - test/support/fixtures/entitlements.ex
    - test/lattice_stripe/entitlements/active_entitlement_test.exs
    - .planning/phases/63-stripe-native-entitlements/docs-warning-baseline.txt
  modified:
    - test/support/test_helpers.ex

key-decisions:
  - "D-16 (one-way): no parent lib/lattice_stripe/entitlements.ex; LatticeStripe.Entitlements.ActiveEntitlement is the published semver name once v1.10 tags"
  - "D-06: ActiveEntitlement owns the canonical list path as a single @list_path attribute; 63-02 stream!/3 and 63-04's summary url rewrite read it rather than re-declaring it"
  - "T-63-04 / D-23: no entitled?-style per-request network gate helper, forbidden structurally by refute function_exported? at arities 2/3/4"
  - "D-24: the rejected name entitled? stays present in the moduledoc admonition for discoverability; the test never refutes it against module source"
  - "Feature.ex ships decode-only in this plan; its verb surface and remaining moduledoc sections land in 63-03"

patterns-established:
  - "Entitlements module skeleton: @moduledoc, aliases, @list_path, @known_fields sigil, @type t before defstruct, 77-column banner comments, verb pipe, then DECODE section"
  - "Private fixtures under LatticeStripe.Test.Fixtures.* with a promotion header naming the Phase 65 move AND module rename (C-01)"
  - "Mox-at-Transport unit harness: async: true, import Mox, import LatticeStripe.TestHelpers, setup :verify_on_exit!, GET params asserted as substrings of req.url"

requirements-completed: [ENT-01]

coverage:
  - id: D1
    description: "ActiveEntitlement.list/3 issues one GET to /v1/entitlements/active_entitlements with the customer filter and returns {:ok, %Response{data: %List{data: [%ActiveEntitlement{}]}}} — typed structs, not raw maps"
    requirement: ENT-01
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#GETs /v1/entitlements/active_entitlements with the customer filter"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#returns the response directly"
        status: pass
    human_judgment: false
  - id: D2
    description: "The expandable feature field decodes to %Entitlements.Feature{} when Stripe expands it and stays the bare feat_ id string when it does not"
    requirement: ENT-01
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#decodes an expanded feature into a %Feature{}"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#leaves an unexpanded feature as the bare id string"
        status: pass
    human_judgment: false
  - id: D3
    description: "from_map/1 is total and idempotent — nil maps to nil, an already-decoded struct returns unchanged, unknown wire keys land in :extra"
    requirement: ENT-01
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#returns nil for nil"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#is idempotent"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#captures unknown wire keys in :extra"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#returns nil for nil and is idempotent"
        status: pass
    human_judgment: false
  - id: D4
    description: "Decoding is order- and identity-preserving: an empty page is a typed empty %List{}, and two entitlements sharing a lookup_key stay two distinct structs in wire order"
    requirement: ENT-01
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#returns a typed empty list for an empty page"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#keeps entitlements sharing a lookup_key as distinct structs in wire order"
        status: pass
    human_judgment: false
  - id: D5
    description: "T-63-01: the customer filter is mandatory and enforced BEFORE any transport call — list/3 without it raises ArgumentError with zero Mox expectations consumed"
    requirement: ENT-01
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#list/3 raises ArgumentError with no customer param and makes no transport call"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#list/3 raises when params carry only unrelated keys — presence, not emptiness"
        status: pass
    human_judgment: false
  - id: D6
    description: "T-63-04: no per-request network gate helper exists and the module is read-only — entitled?/2,3,4, create, update, and delete are all structurally absent while the shipped read surface is pinned positively"
    requirement: ENT-01
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#does not export a per-request network gate helper"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#does not export write verbs — active entitlements are read-only"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#exports the shipped read surface"
        status: pass
    human_judgment: false
  - id: D7
    description: "Test-support scaffolding for the whole phase: four wire-shaped fixtures with the exact Phase 65 promotion names, and TestHelpers.list_json/3 widened backward-compatibly"
    verification:
      - kind: unit
        ref: "mix test — 2130 tests, 0 failures, 1 skipped (every pre-existing list_json/1 and /2 call site still green)"
        status: pass
    human_judgment: false
  - id: D8
    description: "Clean-HEAD ExDoc warning baseline captured as a plain integer (42) for the 63-07 differential docs gate"
    verification:
      - kind: other
        ref: "test -s .planning/phases/63-stripe-native-entitlements/docs-warning-baseline.txt && grep -qE '^[0-9]+$' on it"
        status: pass
    human_judgment: false

# Metrics
duration: 5min
completed: 2026-07-28
status: complete
---

# Phase 63 Plan 01: Typed Active Entitlement List (Tracer) Summary

**A customer's active entitlements now list end-to-end as typed `%ActiveEntitlement{}` structs with a typed nested `%Feature{}`, behind a pre-network `customer` guard and a structural lock that forbids the `entitled?` gate helper.**

## Performance

- **Duration:** ~5 min (first commit 2026-07-27 23:12:17 -0400 → last 23:15:40 -0400), plus a later verification/finalization pass
- **Tasks:** 2 of 2
- **Files modified:** 6 (5 created, 1 modified)

## Accomplishments

- **The tracer slice is real, not a stub.** `LatticeStripe.Entitlements.ActiveEntitlement.list/3` builds a `%Request{method: :get, path: @list_path}`, goes through `Client.request/2`, and comes back through `Resource.unwrap_list(&from_map/1)` as `{:ok, %Response{data: %List{data: [%ActiveEntitlement{}]}}}`. Every later Phase 63 plan now expands horizontally from a shape that has been proven once.
- **The expandable `feature` field types correctly in both directions** — a nested wire map becomes `%LatticeStripe.Entitlements.Feature{}`, a bare `"feat_123"` stays a string. The decode calls `Feature.from_map/1` *directly*, with a source comment recording why routing it through `ObjectTypes` (Phase 65's file) would be a false dependency that silently degrades to a raw map until that phase lands.
- **T-63-01 (tenant scoping) is mitigated pre-network.** `Resource.require_param!/3` makes `"customer"` mandatory, so an unscoped account-wide list cannot be constructed by omission. Two tests prove the raise with *zero* Mox expectations set, so `verify_on_exit!` itself is the evidence that no transport call was attempted.
- **T-63-04 (elevation of privilege) is mitigated structurally and editorially.** `refute function_exported?(ActiveEntitlement, :entitled?, 2/3/4)` is the mechanism that actually forbids the helper — a rename cannot defeat it the way it defeats a source grep. Alongside it, the `{: .warning}` moduledoc admonition names `entitled?` in prose so a contributor who greps for it lands on the explanation, and ships the working replacement (reconcile with `list/3`, persist locally, gate against the local store, **fail closed** when stale) rather than a bare refusal.
- **Phase-wide scaffolding landed with the tracer:** the private fixture module carries the exact four function names Phase 65 promotes plus a header naming the required *module rename* (not just the file move), and `TestHelpers.list_json/2` was widened to `/3` additively — all 2130 existing tests still pass.
- **The 63-07 differential docs gate has its input.** `mix docs --warnings-as-errors | grep -c 'warning:'` was captured on clean HEAD *before* any `lib/` change and recorded as the literal `42`, so the gate can measure a delta instead of trusting the stale figure CONTEXT.md quoted (C-02).

## Task Commits

Each task was committed atomically:

1. **Task 1: End-to-end "list a customer's active entitlements"** (TDD tracer, three commits)
   - `d9e9a05` (test) — RED: baseline capture, `list_json/3` widening, fixtures, and the full behavior test written before the lib modules existed
   - `27be626` (feat) — GREEN: `ActiveEntitlement` + `Feature` decode half
   - `878408a` (style) — REFACTOR: alias ordering for `mix credo --strict`
2. **Task 2: Lock the read-only surface and the pre-network guard** — `dcae050` (test)

**Plan metadata:** see the `docs(63-01)` commit that carries this SUMMARY.

## Files Created/Modified

- `lib/lattice_stripe/entitlements/active_entitlement.ex` (new, 161 lines) — the wire object `entitlements.active_entitlement`. `@list_path` as single source of truth + `list_path/0` accessor, `@known_fields ~w(id object feature lookup_key livemode)` (exactly the five fields the spec marks required, per C-03), `list/3` with the `require_param!` guard, the formulaic `list!/3` bang twin, and the three-clause `from_map/1`. The moduledoc is load-bearing: the `entitled?` warning admonition, the "`limit` defaults to 10, maxes at 100" truncation note, the "presence not emptiness" guard note, the "`lookup_key` mirrors the feature's, so no `expand` needed" note, and the `Product.Feature` cross-reference.
- `lib/lattice_stripe/entitlements/feature.ex` (new, 84 lines) — decode half only. Struct, `@type t`, idempotent `from_map/1`, `@list_path` + accessor, and the `## Relationship to other feature surfaces` section distinguishing this *definition* (`entitlements.feature` / `feat_`) from `LatticeStripe.Product.Feature`, the *attachment* (`product_feature` / `prodft_`) whose `entitlement_feature` field is never a bare id string (C-04).
- `test/support/fixtures/entitlements.ex` (new, 78 lines) — flat `LatticeStripe.Test.Fixtures.Entitlements` with `active_entitlement_json/1`, `feature_json/1`, `active_entitlement_summary_json/1`, `active_entitlement_list_json/2`. The summary fixture deliberately carries the **un-rewritten** webhook url `/v1/customer/cus_ABC123customer/entitlements` (C-06) so 63-04 can prove its rewrite.
- `test/lattice_stripe/entitlements/active_entitlement_test.exs` (new, 185 lines, 16 tests) — five `describe` blocks: `list/3`, `list!/3`, `ActiveEntitlement.from_map/1`, `Feature.from_map/1`, the pre-network guard, and the module-surface lock.
- `test/support/test_helpers.ex` (modified, +2/-2) — `list_json(items, url \\ "/v1/objects", has_more \\ false)`.
- `.planning/phases/63-stripe-native-entitlements/docs-warning-baseline.txt` (new) — `42`.

## Decisions Made

- **Feature.ex ships alias-free and gains a `list_path/0` accessor.** The plan's action text specified `alias LatticeStripe.{Client, Request, Resource}` on `Feature`, but the verb surface that would use those aliases does not land until 63-03. See Deviations — both adjustments exist to keep `mix compile --warnings-as-errors` (a per-task gate for this plan) green.
- **`@list_path` on `Feature` was kept rather than deferred**, because it is the same D-06 single-owner pattern and 63-03 will need it; the `@doc false` accessor is what makes it legal today.
- **`mix ci` was deliberately not run** — the alias includes `docs --warnings-as-errors`, which is RED at clean HEAD for pre-existing reasons (C-02). The plan's `<verification>` block calls this out explicitly; the 42-warning baseline is precisely how 63-07 will distinguish pre-existing noise from phase-introduced regressions.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `Feature` moduledoc-only module cannot carry unused aliases**
- **Found during:** Task 1 (GREEN step, `27be626`)
- **Issue:** The plan's action text specified `alias LatticeStripe.{Client, Request, Resource}` in `feature.ex`. In this plan `Feature` ships its decode half only — none of those three modules are referenced — so the aliases are unused and `mix compile --warnings-as-errors` (Task 1's own acceptance gate) fails.
- **Fix:** Omitted the alias line and left a `NOTE:` comment in its place recording that it lands in 63-03 alongside the verb surface, and why it cannot land now.
- **Files modified:** `lib/lattice_stripe/entitlements/feature.ex`
- **Verification:** `mix compile --warnings-as-errors` exits 0.
- **Committed in:** `27be626` (part of task commit)

**2. [Rule 3 - Blocking] `Feature.@list_path` needs a reader to not be an unused module attribute**
- **Found during:** Task 1 (GREEN step, `27be626`)
- **Issue:** Same gate. The plan specified `@list_path "/v1/entitlements/features"` on `Feature` but no function reading it until 63-03, which produces `module attribute @list_path was set but never used`.
- **Fix:** Added `@doc false def list_path, do: @list_path` — the identical D-06 accessor `ActiveEntitlement` uses, so this is convergent with the house pattern rather than a workaround.
- **Files modified:** `lib/lattice_stripe/entitlements/feature.ex`
- **Verification:** `mix compile --warnings-as-errors` exits 0; `mix credo --strict` finds no issues.
- **Committed in:** `27be626` (part of task commit)

**3. [Rule 3 - Blocking] `Credo.Check.Readability.AliasOrder` on the two-alias `ActiveEntitlement` header**
- **Found during:** Task 1 (post-GREEN verification)
- **Issue:** The multi-alias `LatticeStripe.{Client, Request, Resource}` sorts before `LatticeStripe.Entitlements.Feature`; the original ordering failed `mix credo --strict`, which is verification step 5 for this plan.
- **Fix:** Reordered the two alias lines. Committed separately as a `style` commit so the GREEN commit stays a pure behavior commit.
- **Files modified:** `lib/lattice_stripe/entitlements/active_entitlement.ex`
- **Verification:** `mix credo --strict` → "2194 mods/funs, found no issues."
- **Committed in:** `878408a`

---

**Total deviations:** 3 auto-fixed (3× Rule 3 — blocking issues).
**Impact on plan:** None on behavior or surface. All three exist to satisfy gates the plan itself imposed (`--warnings-as-errors`, `credo --strict`) on a module that ships in two halves across two plans. No scope creep; no acceptance criterion was weakened. 63-03 must remember to add the alias line when it adds the verb surface.

## Issues Encountered

None. The RED→GREEN→REFACTOR cycle ran clean and every acceptance criterion was met on first verification.

### Verification results (re-run at finalization)

| Check | Result |
|---|---|
| `mix format --check-formatted` | exit 0 |
| `mix compile --warnings-as-errors` | exit 0 |
| `mix test test/lattice_stripe/entitlements/` | 16 tests, 0 failures |
| `mix test` (full suite) | **2130 tests, 0 failures, 1 skipped (197 excluded)** |
| `mix credo --strict` | 2194 mods/funs, no issues |
| `ls lib/lattice_stripe/entitlements.ex` | fails — no parent module (D-16) ✓ |
| `git diff --name-only 417edc5..HEAD` | 6 files, `object_types.ex` absent ✓ |
| `grep -c 'refute function_exported?(ActiveEntitlement, :entitled?'` | 3 ✓ |
| `grep -c 'has_more' test/support/test_helpers.ex` | 2 ✓ |
| baseline file matches `^[0-9]+$` | `42` ✓ |

`mix ci` was intentionally not run (see Decisions).

## TDD Gate Compliance

All three gates present and correctly ordered in git log: RED `d9e9a05` (test) → GREEN `27be626` (feat) → REFACTOR `878408a` (style/alias order). Task 2 added `dcae050` (test), which is lock-only and adds no production behavior.

## Known Stubs

None. `Feature`'s verb surface is absent by design (scoped to 63-03), not stubbed — there are no placeholder functions, no hardcoded returns, and no TODO markers in any file this plan touched.

## User Setup Required

None — no external service configuration required. This plan installs zero packages (T-63-SC: no `mix.exs` `deps/0` change).

## Next Phase Readiness

**Ready.** Wave 2 (63-02, 63-03) is unblocked and both can proceed in parallel:

- **63-02** (`retrieve/3` + `stream!/3` + pagination proof) reads `ActiveEntitlement.list_path/0` rather than re-declaring the path, and inherits the fixture + Mox harness shape verbatim. Its T-63-02 "page 2 preserves the customer filter" assertion is the page-2 half of T-63-01, which this plan only mitigated for page 1.
- **63-03** (`Feature` full verb surface) must **add** `alias LatticeStripe.{Client, Request, Resource}` to `feature.ex` — deliberately omitted here (Deviation 1) and marked with an in-source `NOTE:`.
- **63-04** (`ActiveEntitlementSummary`) has its fixture waiting, complete with the un-rewritten webhook url its rewrite must transform.
- **63-07**'s differential docs gate has its baseline: `42`.
- **Phase 65 / OBJ-02** inherits a fixture file whose promotion header states the move *and* the module rename; skipping the rename is a compile error, by design.

**Carried forward (one-way, for the record):** D-16 — the parentless layout and the name `LatticeStripe.Entitlements.ActiveEntitlement` become the published semver contract when v1.10 tags. Renaming after release is breaking.

---
*Phase: 63-stripe-native-entitlements*
*Completed: 2026-07-28*
