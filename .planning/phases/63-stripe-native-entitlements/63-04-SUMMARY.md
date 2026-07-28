---
phase: 63-stripe-native-entitlements
plan: 04
subsystem: api
tags: [stripe, entitlements, webhooks, pagination, deserialization, exunit, tdd]

# Dependency graph
requires:
  - phase: 63-01
    provides: "LatticeStripe.Entitlements.ActiveEntitlement (from_map/1, list_path/0), LatticeStripe.Test.Fixtures.Entitlements.active_entitlement_summary_json/1"
  - phase: 63-02
    provides: "ActiveEntitlement.stream!/3 with its eager customer guard and the proven cursor contract behind it"
  - phase: pre-existing library core
    provides: "LatticeStripe.List.from_json/3 (_last_id derivation), List.stream/2, build_next_page_request/1, LatticeStripe.Client"
provides:
  - "LatticeStripe.Entitlements.ActiveEntitlementSummary — typed decode of the webhook-only summary object, with NO :id field"
  - "ActiveEntitlementSummary.from_map/1 — nested entitlements envelope becomes a %LatticeStripe.List{} of %ActiveEntitlement{} with url, _params and _last_id all correct"
  - "ActiveEntitlementSummary.stream_entitlements!/3 — the blessed reconciler entry point; full canonical re-fetch at limit=100"
  - "test/lattice_stripe/entitlements/active_entitlement_summary_test.exs — the ENT-05 proof, including the mutation-checked ordering lock"
affects: [63-05, 63-06, 63-07, 65]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Nested typed %LatticeStripe.List{} built by the tax/calculation.ex idiom: List.from_json/3 on the RAW string-keyed map first, Enum.map typing in the struct update afterwards"
    - "Defensive nested-cursor rewrite: url ← ActiveEntitlement.list_path(), _params ← %{\"customer\" => customer}, _last_id derived from raw maps"
    - "A resource module with deliberately no :id field, with a source comment stating why so it is not 'fixed' later"
    - "The pure from_map/1 proof — no Mox, no transport — as the complete proof for an object no endpoint serves"
    - "Mutation-checked ordering lock: reversing the load-bearing call order fails exactly one named test"

key-files:
  created:
    - lib/lattice_stripe/entitlements/active_entitlement_summary.ex
    - test/lattice_stripe/entitlements/active_entitlement_summary_test.exs
  modified: []

key-decisions:
  - "D-02 held: entitlements is a typed %LatticeStripe.List{} whose data is [%ActiveEntitlement{}], not raw [map()]"
  - "F-02 held: the struct has no :id field at all, and the omission carries a source comment naming the spec reason"
  - "D-03 held: stream_entitlements!/3 is a full canonical re-fetch keyed on summary.customer; the inline page is ignored, not resumed from"
  - "D-04 held: url rewritten to the canonical path, _params populated, _last_id derived — so the reach-for-it List.stream/2 path is correct too"
  - "D-05 held and mutation-checked: reversing the parse_entitlements/2 call order fails exactly the _last_id test"
  - "The moduledoc reconciler example uses event.data[\"object\"] (the house idiom from webhook/handler.ex), not a fabricated event.data.object accessor"
  - "Surface lock refutes retrieve/retrieve! at arities 2 AND 3, and stream_entitlements at 2 AND 3 — the 63-02 every-arity convention"

patterns-established:
  - "Private summary_json/2 + entitlement/1 test helpers that override the fixture's nested envelope while preserving the webhook-shaped url, so the rewrite stays provable"

requirements-completed: [ENT-05]

coverage:
  - id: D1
    description: "ENT-05: an entitlements.active_entitlement_summary wire payload deserializes into a %ActiveEntitlementSummary{} — never a raw map, never nil — with customer, livemode and object populated"
    requirement: ENT-05
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_summary_test.exs#deserializes the published summary payload into a typed struct"
        status: pass
    human_judgment: false
  - id: D2
    description: "F-02: the struct has no :id field at all — asserted as a design decision, not merely observed"
    requirement: ENT-05
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_summary_test.exs#the struct has no :id field"
        status: pass
      - kind: other
        ref: "awk '/defstruct/,/\\]/' lib/lattice_stripe/entitlements/active_entitlement_summary.ex | grep -c ':id,' → 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "D-02: the nested entitlements field is a %LatticeStripe.List{} whose data is [%ActiveEntitlement{}], with has_more preserved from the wire"
    requirement: ENT-05
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_summary_test.exs#the nested entitlements field is a typed LatticeStripe.List"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_summary_test.exs#has_more is preserved from the wire"
        status: pass
    human_judgment: false
  - id: D4
    description: "D-05 / T-63-12 (medium, DoS): _last_id is non-nil and equals the id of the last RAW item — cursor derivation ran before the data was typed. Mutation-checked: typing data before List.from_json/3 fails exactly this test."
    requirement: ENT-05
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_summary_test.exs#_last_id is derived from the raw maps before typing"
        status: pass
      - kind: other
        ref: "fail-first mutation: typed data passed into List.from_json/3 in parse_entitlements/2 → '12 tests, 1 failure' (left: nil, right: \"ent_b\"); reverted immediately, git status clean on the module"
        status: pass
    human_judgment: false
  - id: D5
    description: "D-04 / Pitfall 2: the nested list's url is rewritten to /v1/entitlements/active_entitlements and is not the webhook-shaped path the fixture carried in"
    requirement: ENT-05
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_summary_test.exs#the nested list url is rewritten to the canonical path"
        status: pass
    human_judgment: false
  - id: D6
    description: "T-63-13 (high, Information Disclosure): the nested list's _params is %{\"customer\" => customer}, so a page-2 fetch off the nested list stays tenant-scoped"
    requirement: ENT-05
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_summary_test.exs#the nested list carries the customer filter in _params"
        status: pass
    human_judgment: false
  - id: D7
    description: "D-26: a summary whose nested data is [] with has_more: true still deserializes — the real 'customer paid but has no feature provisioned yet' Stripe state"
    requirement: ENT-05
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_summary_test.exs#an empty but truncated page still deserializes"
        status: pass
    human_judgment: false
  - id: D8
    description: "D-03 / T-63-11 (high, DoS): stream_entitlements!/3 performs a full canonical re-fetch keyed on summary.customer with limit 100 and ignores the inline page; no non-bang twin, and no retrieve at any arity"
    requirement: ENT-05
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_summary_test.exs#stream_entitlements! ships with no non-bang twin"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_summary_test.exs#there is no retrieve — no HTTP endpoint serves this object"
        status: pass
      - kind: other
        ref: "source: stream_entitlements!/3 delegates to ActiveEntitlement.stream!(client, %{\"customer\" => customer, \"limit\" => \"100\"}, opts); the transport-level pagination contract behind it is proven by 63-02's active_entitlement_stream_test.exs"
        status: pass
    human_judgment: false
  - id: D9
    description: "D-26 tail: from_map/1 is idempotent and nil-tolerant, and unknown wire keys land in extra"
    requirement: ENT-05
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_summary_test.exs#from_map/1 is idempotent and nil-tolerant"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_summary_test.exs#unknown wire keys land in extra"
        status: pass
    human_judgment: false

# Metrics
duration: 4min
completed: 2026-07-28
status: complete
---

# Phase 63 Plan 04: ActiveEntitlementSummary and the Cursor Ordering Lock Summary

**The webhook-only `entitlements.active_entitlement_summary` now decodes into a typed struct with no
`:id` field and a nested `%LatticeStripe.List{}` that is both typed *and* correctly cursored — and the
ordering hazard that shipped in five official Stripe SDKs is locked by a test that was mutation-checked,
not merely written.**

## Performance

- **Duration:** ~4 min
- **Tasks:** 2 of 2
- **Files created:** 2 (0 modified) — 1 module, 1 test file, 12 tests

## Accomplishments

- **The module ships with no `:id` field, and the absence is load-bearing rather than accidental.**
  The Stripe object has no `id` property — not even an optional one — and carries no `x-resourceId`,
  which is an independent structural confirmation that it is not an addressable resource. The
  `defstruct` carries a three-line comment saying exactly that, so a future contributor does not
  "fix" the omission, and `refute Map.has_key?(%ActiveEntitlementSummary{}, :id)` encodes the decision
  in the suite rather than leaving it as observed behavior.
- **The ordering hazard is closed by call order and *proved* by mutation.** `parse_entitlements/2`
  calls `List.from_json(list, %{"customer" => customer}, [])` on the **raw string-keyed map** first and
  types `data` only in the struct update afterwards. The plan's fail-first criterion was executed:
  reversing that order (mapping `data` to `%ActiveEntitlement{}` structs before handing them to
  `from_json/3`) produced `12 tests, 1 failure`, and the one failure was
  `"_last_id is derived from the raw maps before typing"` with `left: nil, right: "ent_b"`. The
  mutation was reverted immediately and `git status` on the module was clean. That is what makes the
  test known-load-bearing: without it the reordering compiles, passes everything else, and either
  truncates a customer's entitlements at ten or re-requests page 1 forever.
- **Both the blessed path and the reach-for-it path are correct, not one correct and one quietly
  wrong.** D-03's `stream_entitlements!/3` does a full canonical re-fetch at `limit=100` and never
  touches the inline cursor. But a consumer who instead reaches for
  `LatticeStripe.List.stream(summary.entitlements, client)` also gets a working request, because D-04's
  five lines rewrite `url` to `/v1/entitlements/active_entitlements` (the webhook's
  `/v1/customer/cus_ABC123customer/entitlements` is not in Stripe's spec and 404s against stripe-mock),
  populate `_params` with the customer filter so page 2 stays tenant-scoped (T-63-13), and derive
  `_last_id` so `build_next_page_request/1` never falls to its empty-params branch (T-63-12).
- **The whole proof runs with zero transport and zero Mox — by necessity, not by shortcut.** Stripe
  serves this object from no HTTP endpoint, so a pure `from_map/1` transformation test is the only
  proof available. The test file's `@moduledoc` says so, so a future reader does not mistake the
  absence of a Mox block for an oversight and "add coverage" against an endpoint that does not exist.
- **The moduledoc makes the ten-item cap visible at the point of use (T-63-11).** It names the wire
  object, states plainly that the object is webhook-delivered and that the absence of `retrieve/2` is
  not a gap, quotes the exact webhook url string so the rewrite claim is verifiable by a reader, states
  the ten-inlined cap and why treating the inline page as a snapshot is the bug this module removes,
  and explains why a cursor-resume would be *worse* than a re-fetch (it stitches a head captured at
  webhook time to a tail queried later).

## Task Commits

Each task was committed atomically:

1. **Task 1: the summary module with correct cursor state and the canonical re-fetch helper** —
   `ff7df1c` (feat)
2. **Task 2: the pure `from_map/1` proof including the ordering lock** — `906477a` (test)

**Plan metadata:** see the `docs(63-04)` commit that carries this SUMMARY.

## Files Created/Modified

- `lib/lattice_stripe/entitlements/active_entitlement_summary.ex` (new, 170 lines) — the module.
  `@known_fields ~w(object customer entitlements livemode)` (no `"id"`), a `defstruct` with no `:id`
  and a comment explaining why, a `RECONCILE` section holding `stream_entitlements!/3`, and a `DECODE`
  section holding the three-clause `from_map/1` (struct clause before the `is_map/1` clause) and the
  three-clause `parse_entitlements/2` with a six-line comment above the matched clause naming the
  ordering requirement and its exact consequence.
- `test/lattice_stripe/entitlements/active_entitlement_summary_test.exs` (new, 149 lines, 12 tests) —
  two `describe` blocks: `from_map/1` (ten tests) and `surface` (two). Private `summary_json/2` and
  `entitlement/1` helpers override the fixture's nested envelope while preserving the webhook-shaped
  url, so the D-04 rewrite is provable rather than tautological.

## Decisions Made

- **The moduledoc's reconciler example accesses `event.data["object"]`, not `event.data.object`.**
  `%LatticeStripe.Event{}`'s `:data` is a raw string-keyed map — `event.data.object` would not compile
  for a user who copied it. `lib/lattice_stripe/webhook/handler.ex` and `guides/webhooks.md` both use
  the bracket form; this converges with them. The example is also shaped as a plain
  `reconcile_from_event/2` function with a following sentence pointing at
  `LatticeStripe.Webhook.Handler` for dispatch, rather than re-teaching the handler behaviour inline.
- **`mix ci` was deliberately not run** (plan verification step 8, research correction C-02). Its
  `docs --warnings-as-errors` step is RED at clean HEAD. The six individual gates were run instead.
- **The two new `mix docs` warnings are the known transient guide link, not a regression.** The
  phase's warning count moved 50 → 52; both new warnings are
  `documentation references file "guides/entitlements.md" but it does not exist`, emitted once per
  output format for this module's cross-link. `lib/lattice_stripe/entitlements/feature.ex` carries the
  identical link from 63-03. Plan 63-06 creates the guide and resolves all of them. Plain `mix docs`
  exits 0.

## Deviations from Plan

### Auto-fixed Issues

None. No bug, missing-critical-functionality, or blocking issue was encountered — the plan's action
text compiled and passed on first write for both tasks.

### Additive judgment calls (no rule invoked, recorded for the record)

**1. The surface lock refutes `retrieve!` and `stream_entitlements` in addition to `retrieve`**
- **Found during:** Task 2
- **Rationale:** The plan's acceptance criterion named `refute function_exported?(..., :retrieve, 3)`
  only. Following the surface-lock convention established in 63-02 and reinforced in 63-03 — refute
  *every* arity a defaulted-argument function would export — `retrieve(client, id, opts \\ [])` exports
  arities 2 and 3, so refuting only 3 leaves a hole. `retrieve!` is refuted for the same reason (a bang
  twin without a base function would be equally wrong here), and `stream_entitlements` at 2/3 locks the
  no-non-bang-twin stance that `ActiveEntitlement.stream!/3` already carries. Two positive
  `function_exported?` assertions for `stream_entitlements!/2,3` were added alongside so the refutations
  cannot pass vacuously against a mistyped module name.
- **Files modified:** `test/lattice_stripe/entitlements/active_entitlement_summary_test.exs`
- **Committed in:** `906477a`

**2. Two extra tests beyond the ten the `<behavior>` enumerated**
- **Found during:** Task 2
- **Rationale:** The plan's `<behavior>` listed ten test cases; the file has twelve, because the
  surface-lock block (the two `describe "surface"` tests) is required by Task 1's *acceptance criteria*
  (`refute function_exported?(..., :retrieve, 3)`) but was not listed among the behavior bullets. It
  had to live somewhere, and this is the only test file for the module.
- **Files modified:** `test/lattice_stripe/entitlements/active_entitlement_summary_test.exs`
- **Committed in:** `906477a`

---

**Total deviations:** 0 rule-invoking deviations; 2 additive test-strengthening judgment calls.
**Impact on plan:** None on surface or behavior. Both additions strengthen locks the plan's own
acceptance criteria already required and weaken no criterion.

## Issues Encountered

None. Both files passed their gates on first write. The one intentional failure was the fail-first
mutation check, which behaved exactly as the plan predicted.

### Verification results

| Check | Result |
|---|---|
| `mix format --check-formatted` | exit 0 |
| `mix compile --warnings-as-errors` | exit 0 |
| `mix test test/lattice_stripe/entitlements/` | **73 tests, 0 failures** |
| `mix test` (full unit suite) | **2187 tests, 0 failures, 1 skipped (197 excluded)** |
| `mix credo --strict` | 2224 mods/funs, found no issues |
| `mix docs` | exit 0 (52 warnings; +2 vs. the phase's 50, both the transient guide link) |
| `mix test .../active_entitlement_summary_test.exs` | **12 tests, 0 failures** |
| `git diff --name-only` includes `object_types.ex` | **no** ✓ (verification step 7) |
| `awk '/defstruct/,/\]/' module \| grep -c ':id,'` | `0` ✓ |
| `~w(object customer entitlements livemode)` in module | present ✓ |
| `List.from_json(list, %{"customer" => customer}, [])` in module | present ✓ |
| `ActiveEntitlement.list_path()` in module | present ✓ |
| `def stream_entitlements!` in module | present ✓ |
| `"limit" => "100"` in module | present ✓ |
| literal `no top-level` in moduledoc | present ✓ |
| literal `/v1/customer/cus_ABC123customer/entitlements` in moduledoc | present ✓ |
| `grep -c 'https://'` on module | `0` ✓ |
| `grep -c 'import Mox'` on test | `0` ✓ |
| `use ExUnit.Case, async: true` in test | present ✓ |
| fail-first mutation of the `parse_entitlements/2` call order | `12 tests, 1 failure` — the named `_last_id` lock ✓, reverted, module clean |

`mix ci` was intentionally not run (see Decisions).

## TDD Gate Compliance

Both tasks carry `tdd="true"`, but the plan splits implementation (Task 1, `<files>` = the module only)
from proof (Task 2, `<files>` = the test only) and states in Task 1's `<behavior>` that its contract is
"proven by Task 2". A strict RED commit inside Task 1 was therefore impossible without violating that
task's declared file scope. The gates present in `git log` are `ff7df1c` (`feat`) → `906477a` (`test`).

The RED guarantee is supplied instead by the plan's own designated mechanism: Task 2's fail-first
mutation criterion, which was executed and confirmed to fail exactly the one named test before being
reverted. That is a stronger guarantee than a conventional RED commit for this particular hazard —
a RED-first test would only have proven the function did not yet exist, whereas the mutation proves
the assertion catches the *specific* silent-reordering defect it was written for.

## Known Stubs

None. Every function this plan added is fully implemented and exercised by a test; there are no
placeholder returns, hardcoded values, or TODO/FIXME markers in either file.

## Threat Flags

None. This plan adds no new network endpoint — `stream_entitlements!/3` delegates to the already-shipped
`ActiveEntitlement.stream!/3` on the already-covered `/v1/entitlements/active_entitlements` path. No
auth path, no file access, no schema change at a trust boundary. `mix.exs` `deps/0` is untouched
(T-63-SC: zero packages installed).

**ENT-05 flagged assumption reviewed, not silently adopted.** The plan carried ENT-05 as *unclassified*
by the edge probe and asked for one manual confirmation the automated suite cannot make: that
`active_entitlement_summary_json/1` still matches the payload Stripe publishes for
`entitlements.active_entitlement_summary.updated`. Reviewed during execution against 63-RESEARCH.md's
verified record (correction C-06 pins the inlined url to `"/v1/customer/cus_ABC123customer/entitlements"`
and the inline cap to 10; F-02 records the spec's `required` set as exactly `customer`, `entitlements`,
`livemode`, `object` with no `id` property and no `x-resourceId`). The fixture's four top-level keys and
its nested envelope shape match that record exactly. **This remains a spec-and-research confirmation,
not a live-Stripe one** — assumption A1 (no live Stripe key available) still stands, and
`63-VALIDATION.md`'s listed manual verification is the place that gap is tracked. No predicate was
authored and none is assumed.

## User Setup Required

None — no external service configuration, no packages installed.

## Next Phase Readiness

**Ready.** Wave 3's remaining work is unblocked:

- **63-05 / 63-06** can document `ActiveEntitlementSummary.from_map/1` and `stream_entitlements!/3` as
  shipped surface. `guides/entitlements.md` should carry the webhook-reconciliation section, and
  creating it clears **all** outstanding `guides/entitlements.md` docs warnings (this module's two plus
  `feature.ex`'s), taking the phase's count back toward the recorded 42 baseline.
- **63-07**'s docs-truth test can lock the literals `no top-level` and
  `/v1/customer/cus_ABC123customer/entitlements` in this moduledoc — both are asserted-by-grep in this
  plan's acceptance criteria and are exactly the kind of claim that rots silently.
- **Phase 65** can add the `object_types.ex` registry row for
  `"entitlements.active_entitlement_summary"` pointing at this module's `from_map/1`. This plan
  deliberately did not touch `object_types.ex` (verification step 7), and the module exposes
  `from_map/1` directly, so nothing here depends on that row landing.
- **Note for 63-06's integration plan:** there is nothing to integration-test here. No HTTP endpoint
  serves this object, so stripe-mock cannot exercise it at all — the unit proof in this plan is the
  complete proof, by construction.

**Carried forward:** the `entitlements` field's `%LatticeStripe.List{}`-ness becomes a published semver
contract when v1.10 tags (D-02, costly reversibility). Its internal `_params` / `_opts` / `_last_id`
values remain documented non-contract and stay free to change. The absence of `:id` is likewise a
one-way door: adding it later is additive and safe, but nothing should.

## Self-Check: PASSED

Both claimed files exist on disk
(`lib/lattice_stripe/entitlements/active_entitlement_summary.ex`,
`test/lattice_stripe/entitlements/active_entitlement_summary_test.exs`, plus this SUMMARY) and both
claimed commits resolve in `git log` (`ff7df1c`, `906477a`).

---
*Phase: 63-stripe-native-entitlements*
*Completed: 2026-07-28*
