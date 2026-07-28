---
phase: 63-stripe-native-entitlements
plan: 02
subsystem: api
tags: [stripe, entitlements, pagination, streaming, security, mox, exunit, tdd]

# Dependency graph
requires:
  - phase: 63-01
    provides: "LatticeStripe.Entitlements.ActiveEntitlement (@list_path, list/3, from_map/1), LatticeStripe.Test.Fixtures.Entitlements, TestHelpers.list_json/3"
  - phase: pre-existing library core
    provides: "LatticeStripe.List.stream!/2 and its cursor state machine (base_params preservation, _last_id cursor, idempotency_key strip), LatticeStripe.Resource, LatticeStripe.Client, LatticeStripe.MockTransport"
provides:
  - "LatticeStripe.Entitlements.ActiveEntitlement.retrieve/3 and retrieve!/3 — GET /v1/entitlements/active_entitlements/{id} returning a single typed struct"
  - "LatticeStripe.Entitlements.ActiveEntitlement.stream!/3 — lazy auto-paginating stream of %ActiveEntitlement{} with an eager pre-network customer guard and no non-bang twin"
  - "test/lattice_stripe/entitlements/active_entitlement_stream_test.exs — the ENT-02 pagination proof, including the named T-63-02 cross-tenant regression guard"
affects: [63-04, 63-05, 63-06, 63-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "stream!/3 = require_param! guard → %Request{} → LatticeStripe.List.stream!/2 → Stream.map(&from_map/1); the cursor state machine is never re-grown per resource"
    - "Eager guard placement ahead of Stream.resource/3's deferred start function, proven by an assert_raise with no Enum step and zero Mox expectations (Pitfall 6)"
    - "Retrieve path composed as @list_path <> \"/#{id}\" so the canonical path string stays declared exactly once (D-06)"
    - "Pagination proven Mox-at-Transport in a dedicated file with chained ordered expect/3 calls; verify_on_exit! is the call counter (D-21)"
    - "Mutation-checked security test: dropping base_params in List.build_next_page_request/1 fails exactly the one named test that guards it"

key-files:
  created:
    - test/lattice_stripe/entitlements/active_entitlement_stream_test.exs
  modified:
    - lib/lattice_stripe/entitlements/active_entitlement.ex
    - test/lattice_stripe/entitlements/active_entitlement_test.exs

key-decisions:
  - "D-06 held: retrieve/3 composes @list_path <> \"/#{id}\" rather than re-declaring the path — the canonical string still appears exactly once in the module"
  - "D-11 held: is_binary(id) is retrieve/3's only guard; no id in [nil, \"\"] ArgumentError clauses were added"
  - "D-10 / Pitfall 6: the customer guard is stream!/3's FIRST statement, so it raises at call time rather than on the first Enum step"
  - "D-21: the pagination proof lives in its own file, not folded into active_entitlement_test.exs"
  - "D-22: the cross-tenant guard is named \"page 2 preserves the customer filter\" verbatim and carries an in-file comment stating the leak consequence so it is not simplified away"
  - "D-25 honored: no assertion greps documentation prose for a generic has_more sentence"
  - "stream!/3 ships with no non-bang stream/3 twin, locked structurally at arities 1/2/3"

patterns-established:
  - "Two guard tests per required param (absent map, unrelated-keys map) mirroring the list/3 pair — presence, not emptiness"
  - "Local list_response/2 + error_response/1 helpers in the stream test file, wrapping the shared fixture in the raw transport tuple"

requirements-completed: [ENT-02, ENT-03]

coverage:
  - id: D9
    description: "ENT-03: retrieve/3 GETs /v1/entitlements/active_entitlements/{id} and returns a single typed %ActiveEntitlement{}; retrieve!/3 returns the bare struct and raises LatticeStripe.Error on a Stripe error payload"
    requirement: ENT-03
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#GETs /v1/entitlements/active_entitlements/{id} and returns a typed struct"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#returns the bare struct on success"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#raises LatticeStripe.Error when Stripe returns an error payload"
        status: pass
    human_judgment: false
  - id: D10
    description: "ENT-02: stream!/3 auto-follows has_more, emits every item from every page as a typed struct in wire order with no duplicates at the seam, and the page-2 cursor is starting_after = the LAST id of page 1"
    requirement: ENT-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_stream_test.exs#page 2 request uses starting_after from the last id of page 1"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_stream_test.exs#items from every page are emitted in wire order as typed structs"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_stream_test.exs#streaming N pages makes exactly N transport calls"
        status: pass
    human_judgment: false
  - id: D11
    description: "T-63-02 (high, Information Disclosure): the customer filter survives cursor construction — page 2 still carries customer=cus_123. Mutation-checked: zeroing base_params in List.build_next_page_request/1 fails exactly this test and no other."
    requirement: ENT-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_stream_test.exs#page 2 preserves the customer filter"
        status: pass
      - kind: other
        ref: "fail-first mutation: base_params = %{} in lib/lattice_stripe/list.ex:246 → '10 tests, 1 failure', the failure being this test; reverted immediately, git status clean on list.ex"
        status: pass
    human_judgment: false
  - id: D12
    description: "T-63-03 / T-63-05: the stripe-account header carries to the page-2 request; the idempotency-key header does not"
    requirement: ENT-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_stream_test.exs#the stripe-account header carries to page 2"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_stream_test.exs#no idempotency-key is sent on page 2"
        status: pass
    human_judgment: false
  - id: D13
    description: "ENT-02 prohibition: enumeration is complete or it fails loudly — a 500 on page 2 raises LatticeStripe.Error rather than silently truncating"
    requirement: ENT-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_stream_test.exs#a 500 on page 2 raises LatticeStripe.Error"
        status: pass
    human_judgment: false
  - id: D14
    description: "The stream is lazy and total at the boundaries: Stream.take/2 over a two-page stream makes exactly one transport call, and an empty first page yields [] from exactly one call"
    requirement: ENT-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_stream_test.exs#Stream.take/2 on a two-page stream fetches only page 1"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_stream_test.exs#an empty first page yields an empty list in one call"
        status: pass
    human_judgment: false
  - id: D15
    description: "Order stability under ties: entitlements sharing a lookup_key keep their relative wire order across the page seam"
    requirement: ENT-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_stream_test.exs#entitlements sharing a lookup_key keep their relative wire order across the page seam"
        status: pass
    human_judgment: false
  - id: D16
    description: "D-10 / Pitfall 6: stream!/3 raises ArgumentError at CALL time with no Enum step and zero Mox expectations consumed, and the surface lock forbids a non-bang stream/1,2,3 twin"
    requirement: ENT-02
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#stream!/3 raises ArgumentError at call time, before any Enum step"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#stream!/3 raises when params carry only unrelated keys — presence, not emptiness"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/active_entitlement_test.exs#stream! has no non-bang twin — auto-pagination raises, it does not return tuples"
        status: pass
    human_judgment: false

# Metrics
duration: 3min
completed: 2026-07-28
status: complete
---

# Phase 63 Plan 02: ActiveEntitlement Read Surface and the Pagination Proof Summary

**`stream!/3` now enumerates every page of a customer's active entitlements as typed structs — lazily, in wire order, failing loudly rather than truncating — and the page-2 request is proven to still carry the `customer` filter, the `stripe-account` header, and no idempotency key.**

## Performance

- **Duration:** ~3 min (first commit 2026-07-28 11:14:40 -0400 → last 11:17:31 -0400)
- **Tasks:** 2 of 2
- **Files modified:** 3 (1 created, 2 modified) — 414 insertions, 10 deletions

## Accomplishments

- **The reconciler-critical function ships, and it grows no new machinery.** `stream!/3` is four
  statements: the `customer` guard, a `%Request{}`, `LatticeStripe.List.stream!/2`, and
  `Stream.map(&from_map/1)`. The entire cursor state machine — `base_params` preservation, the
  `_last_id` forward cursor, the `idempotency_key` strip on page fetches — stays owned by
  `LatticeStripe.List`, which already works. This is the bug class that shipped in stripe-node,
  stripe-php, stripe-java and both Stripe-sync-engine forks, and the fix is *not* to re-implement
  pagination per resource.
- **The guard raises at the call site, not three frames into a lazy stream.** `Stream.resource/3`
  defers its start function, so a guard built lazily would surface an `ArgumentError` on the first
  `Enum` step with a stack trace far from the caller. `Resource.require_param!/3` is `stream!/3`'s
  literal first statement, and the proof is an `assert_raise` with **no `Enum` step at all** and
  **zero Mox expectations** — `verify_on_exit!` is what shows no transport call was attempted.
- **T-63-02 is mitigated by a test that was mutation-checked, not merely written.** The plan's
  fail-first criterion was run: setting `base_params = %{}` in
  `LatticeStripe.List.build_next_page_request/1` produced `10 tests, 1 failure`, and the one failure
  was `"page 2 preserves the customer filter"`. The mutation was reverted immediately and
  `git status` on `list.ex` is clean. That test is therefore known to be load-bearing rather than
  merely green — if `base_params` preservation regresses, the reconciler streams the entire
  account's entitlements instead of one customer's, and this test is what stops it.
- **Both Connect scoping and idempotency semantics are locked on requests the caller never builds.**
  Page ≥2 requests are constructed by the SDK, so the caller has no opportunity to re-assert
  scoping. `{"stripe-account", "acct_connected"}` is asserted present in the page-2 header list
  (T-63-03), and `idempotency-key` is asserted **absent** from the outgoing page-2 request rather
  than grepped from source (T-63-05) — the point is the header, not the code that omits it.
- **ENT-03 landed on the single canonical path.** `retrieve/3` builds `@list_path <> "/#{id}"`, so
  `grep -c '"/v1/entitlements/active_entitlements"'` still returns exactly `1` (D-06). Its only
  guard is `when is_binary(id)` — no `id in [nil, ""]` clauses, per D-11, since that pattern is a
  5-of-55 minority in this repo and adopting it in a flagship module would fake a house rule.
- **The moduledoc now tells the truth about truncation.** It names `stream!/3` explicitly (a string
  63-07's docs-truth test will lock), states that `limit` defaults to 10 so a bare `list/3` returns a
  *partial* set, and the `@doc` on `stream!/3` shows `Stream.take/2` alongside `Enum.to_list/1` so
  the memory tradeoff (T-63-07, accepted) is visible at the call site.

## Task Commits

Each task was committed atomically:

1. **Task 1: retrieve/3 and stream!/3 on the ActiveEntitlement read surface** (TDD, two commits)
   - `6083f3c` (test) — RED: retrieve/retrieve!/eager-guard/surface-lock tests, 6 failures against the 63-01 module
   - `b8e88af` (feat) — GREEN: `RETRIEVE` section, `LIST + STREAM` section, moduledoc update
2. **Task 2: the ten-assertion pagination proof** — `e8a47f6` (test)

No REFACTOR commit was needed: `mix format --check-formatted` and `mix credo --strict` were both
clean on the GREEN commit as written.

**Plan metadata:** see the `docs(63-02)` commit that carries this SUMMARY.

## Files Created/Modified

- `lib/lattice_stripe/entitlements/active_entitlement.ex` (modified, +84/-10) — new `RETRIEVE`
  banner section with `retrieve/3` (`when is_binary(id)`, path composed from `@list_path`) and
  `retrieve!/3`; the `LIST` section renamed to `LIST + STREAM` and given `stream!/3` with the eager
  `customer` guard, a two-line comment recording *why* the guard's position matters, and a second
  comment recording that the cursor state machine deliberately is not re-grown here. Moduledoc:
  the read surface is now enumerated (`list/3`, `stream!/3`, `retrieve/3`), the truncation paragraph
  says why `stream!/3` is the reconciler's entry point, the `entitled?` admonition's "once it lands"
  hedge is replaced by the shipped `stream!/3`, and the usage example shows the streaming form.
- `test/lattice_stripe/entitlements/active_entitlement_stream_test.exs` (new, 268 lines, 10 tests) —
  four `describe` blocks: cursor construction, enumeration, page-2 request scoping, and error
  propagation. Local `list_response/2`, `error_response/1`, `entitlement/2` and `customer_params/0`
  helpers. The file's `@moduledoc` records why it exists as a separate file and why stripe-mock
  cannot substitute for it.
- `test/lattice_stripe/entitlements/active_entitlement_test.exs` (modified, +62) — `retrieve/3` and
  `retrieve!/3` describe blocks, two `stream!/3` pre-network guard tests, `stream!`'s non-bang-twin
  refutation, and three added positive `function_exported?` assertions. 16 tests → 22.

## Decisions Made

- **`retrieve/3` passes `params: %{}`**, matching `Billing.Meter.retrieve/3` exactly. Retrieval takes
  no filters; `opts` is where `expand` would go if a caller wanted it.
- **The stream test file defines its own `error_response/1`** rather than using
  `TestHelpers.error_response/0`, which is hardcoded to 400. Assertion 8 is specifically about a
  **500** on page 2 — a server error mid-enumeration is the realistic truncation scenario, and a
  400 would be a different (and less interesting) story about a malformed cursor. The local helper
  mirrors `list_test.exs`'s own `error_response/1`, so this converges with the house pattern rather
  than diverging from it.
- **Two guard tests were written for `stream!/3`, not one.** The plan's `<behavior>` named one
  (`%{}`); the second (`%{"limit" => "100"}`) mirrors the `list/3` pair from 63-01 and is what
  actually proves "presence, not emptiness" — an empty-map-only test passes even under a guard that
  wrongly checks `params != %{}`.
- **`mix ci` was deliberately not run** (plan verification step 6, research correction C-02). Its
  `docs --warnings-as-errors` step is RED at clean HEAD with a recorded 42-warning baseline. The
  five individual gates were run instead and are all green.

## Deviations from Plan

### Auto-fixed Issues

None. No bug, missing-critical-functionality, or blocking issue was encountered — the plan's action
text compiled and passed on first write for both tasks.

### Additive judgment calls (no rule invoked, recorded for the record)

**1. A second `stream!/3` guard test beyond the one the plan named**
- **Found during:** Task 1 (RED)
- **Rationale:** The plan's `<behavior>` specified one missing-`customer` case. 63-01 established a
  two-test pair for `list/3` (absent map, unrelated-keys map) precisely because only the second
  distinguishes a presence check from an emptiness check. Writing only the first would have left
  `stream!/3` less well guarded than `list/3` on the identical requirement.
- **Files modified:** `test/lattice_stripe/entitlements/active_entitlement_test.exs`
- **Committed in:** `6083f3c`

**2. `refute function_exported?(ActiveEntitlement, :stream, 1)` and `:stream, 2` alongside `:stream, 3`**
- **Found during:** Task 1 (RED)
- **Rationale:** The plan's acceptance criterion named arity 3 only. Because `stream!/3` has two
  defaulted arguments, a hypothetical non-bang twin would export arities 1, 2, **and** 3 — refuting
  only arity 3 would let a `def stream(client, params)` slip through. This mirrors 63-01's
  `entitled?` lock, which refutes 2/3/4 for the same reason.
- **Files modified:** `test/lattice_stripe/entitlements/active_entitlement_test.exs`
- **Committed in:** `6083f3c`

---

**Total deviations:** 0 rule-invoking deviations; 2 additive test-strengthening judgment calls.
**Impact on plan:** None on surface or behavior. Both additions strengthen locks the plan already
required and weaken no acceptance criterion. Test count for the stream file is exactly the ten the
plan specified; the two extras are in `active_entitlement_test.exs`, whose count the plan did not fix.

## Issues Encountered

None. RED produced exactly the 6 expected failures; GREEN cleared them with no iteration; the Task 2
file passed on first run.

### Verification results

| Check | Result |
|---|---|
| `mix format --check-formatted` | exit 0 |
| `mix compile --warnings-as-errors` | exit 0 |
| `mix test test/lattice_stripe/entitlements/` | **32 tests, 0 failures** |
| `mix test` (full unit suite) | **2146 tests, 0 failures, 1 skipped (197 excluded)** |
| `mix credo --strict` | 2202 mods/funs, found no issues |
| `mix test .../active_entitlement_stream_test.exs` | **10 tests, 0 failures** (plan required exactly 10) |
| `grep -c '"/v1/entitlements/active_entitlements"'` on the module | `1` ✓ (D-06) |
| `grep -c 'id in \[nil'` on the module | `0` ✓ (D-11) |
| `grep -c 'starting_after=ent_b'` on the stream test | `2` ✓ (≥1 required) |
| lowercase `stripe-account` / `idempotency-key` in stream test | present ✓ |
| `assert_raise LatticeStripe.Error` in stream test | present ✓ |
| `use ExUnit.Case, async: true` in stream test | present ✓ |
| generic `auto-follows` prose grep in stream test | `0` ✓ (D-25 honored) |
| fail-first mutation of `base_params` | `10 tests, 1 failure` — the named guard ✓, reverted, `list.ex` clean |

`mix ci` was intentionally not run (see Decisions).

## TDD Gate Compliance

Task 1's gates are present and correctly ordered in git log: RED `6083f3c` (`test`) → GREEN
`b8e88af` (`feat`). No REFACTOR commit was produced because no cleanup was warranted — format and
credo were clean as written. Task 2 is `e8a47f6` (`test`), which adds no production behavior and is
therefore RED-only by nature; its "GREEN" is that the Task 1 implementation already satisfies it, and
the mutation check is what proves the tests are not vacuous.

## Known Stubs

None. Every function this plan added is fully implemented and exercised by a test; there are no
placeholder returns, hardcoded values, or TODO/FIXME markers in any file touched.

## Threat Flags

None. This plan added no new network endpoints beyond the two GET reads the threat model already
covers, no auth paths, no file access, and no schema changes. `retrieve/3` reads a single object by
id on a path the caller supplies; the 404 case flows through the existing shared
`LatticeStripe.Error` path.

**ENT-03 flagged assumption resolved:** the plan carried ENT-03 as *unclassified* by the edge probe.
Manual review during execution confirms both candidate shapes are already handled without new
predicates — a non-`String` id is excluded by the `when is_binary(id)` guard (a
`FunctionClauseError`, which is correct for a type violation), and a 404 flows through
`Resource.unwrap_singular/2`'s existing `{:error, %Error{}}` branch, covered by
`"raises LatticeStripe.Error when Stripe returns an error payload"`. No new assumption was silently
adopted.

## User Setup Required

None — no external service configuration. This plan installs zero packages; `mix.exs` `deps/0` is
untouched (T-63-SC).

## Next Phase Readiness

**Ready.** Wave 3 is unblocked:

- **63-04** (`ActiveEntitlementSummary`) can now implement D-03's blessed reconciler call
  `stream_entitlements!/3` by delegating straight to `ActiveEntitlement.stream!(client, %{"customer"
  => customer, "limit" => "100"}, opts)` — the function exists, the guard is eager, and the
  pagination contract behind it is proven. Its fixture's un-rewritten webhook url is still waiting.
- **63-05 / 63-06** (guide + integration tests) can document `stream!/3` as shipped surface. Note
  for the integration plan: stripe-mock returns one item per list and ignores
  `limit`/`starting_after`, so it can prove the *call* works but cannot prove pagination — that
  proof lives here and only here.
- **63-07**'s docs-truth test can lock the literal `stream!/3` in the `ActiveEntitlement` moduledoc;
  the differential docs gate still measures against the recorded baseline of `42`.

**Carried forward:** `stream!/3` with no non-bang twin, and the eager-guard placement, become part
of the published semver contract when v1.10 tags — same one-way status as D-16.

## Self-Check: PASSED

All claimed files exist on disk (`active_entitlement.ex`, `active_entitlement_stream_test.exs`,
`active_entitlement_test.exs`, this SUMMARY) and all three claimed commits resolve in `git log`
(`6083f3c`, `b8e88af`, `e8a47f6`). The stream test file is 268 lines as stated.

---
*Phase: 63-stripe-native-entitlements*
*Completed: 2026-07-28*
