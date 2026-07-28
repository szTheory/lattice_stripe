---
phase: 63-stripe-native-entitlements
plan: 03
subsystem: api
tags: [stripe, entitlements, elixir, mox, exunit, tdd, moduledoc]

# Dependency graph
requires:
  - phase: 63-01
    provides: "LatticeStripe.Entitlements.Feature decode half (struct, @type t, from_map/1, @list_path), LatticeStripe.Test.Fixtures.Entitlements.feature_json/1, TestHelpers.list_json/3"
  - phase: pre-existing library core
    provides: "LatticeStripe.Resource (require_param!/3, unwrap_singular/2, unwrap_list/2, unwrap_bang!/1), LatticeStripe.Client, LatticeStripe.Request, LatticeStripe.List.stream!/2, LatticeStripe.MockTransport"
provides:
  - "LatticeStripe.Entitlements.Feature — the complete ENT-04 verb surface: create/3, create!/3, retrieve/3, retrieve!/3, update/4, update!/4, list/3, list!/3, stream!/3, from_map/1"
  - "The ## Archiving moduledoc section — the T-63-08 mitigation, and the only available one"
  - "The ## Using lookup_key as your system identifier moduledoc section — filter form, list-not-singleton, post-create immutability"
  - "test/lattice_stripe/entitlements/feature_test.exs — 29 tests including the D-23 L1 present/absent surface locks"
affects: [63-05, 63-06, 63-07, phase-65-object-types, phase-66-product-features]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single-owner canonical path extended to a full verb surface: five verbs compose from one @list_path, item paths as @list_path <> \"/{id}\" (D-06)"
    - "create/3 with NO params default — a defaulted empty map could only ever raise (D-14, Pitfall 5)"
    - "Two ordered pre-network require_param!/3 guards proven with ZERO Mox expectations (D-10, C-07)"
    - "Absent-verb lock refuting EVERY exported arity of a defaulted-arg verb, not just the highest (63-02 convention)"
    - "Landmine-in-moduledoc: an admonition placed where the reader hits it is the mitigation when no signature can carry the fact (D-09)"

key-files:
  created:
    - test/lattice_stripe/entitlements/feature_test.exs
  modified:
    - lib/lattice_stripe/entitlements/feature.ex

key-decisions:
  - "D-08 held: no archive/3, no unarchive/3, no set_active/4 — archiving is update/4 with active: false, and all three names are refuted structurally"
  - "D-14 held: create/3 takes params with no \\\\ %{} default; no custom Inspect impl; the ten-function surface is exactly as specified"
  - "D-12 held: no retrieve_by_lookup_key/3 — the lookup_key recipe is moduledoc-only, and a single-match list/3 is asserted to return a %List{} of one"
  - "D-13 held: Feature gets stream!/3 so the two entitlements modules ship identical pagination affordances"
  - "63-01 carry-forward resolved: alias LatticeStripe.{Client, Request, Resource} added, NOTE comment deleted, and the vestigial @doc false list_path/0 accessor removed now that five verbs read @list_path"
  - "Task order inverted to test-first (Task 3 → Task 1 → Task 2) so Task 1's tdd=\"true\" flag got a real RED gate; the plan itself placed Task 1's proof in Task 3's file"

requirements-completed: [ENT-04]

coverage:
  - id: D1
    description: "create/3 POSTs /v1/entitlements/features and returns {:ok, %Feature{}} with lookup_key and name on the wire"
    requirement: ENT-04
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#POSTs /v1/entitlements/features and returns a typed struct"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#returns the bare struct on success (create!/3)"
        status: pass
    human_judgment: false
  - id: D2
    description: "T-63-08 half one / D-10: create/3 guards BOTH required params before any transport call, in wire order, and an empty params map names lookup_key first"
    requirement: ENT-04
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#raises ArgumentError naming lookup_key when it is absent, and makes no transport call"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#raises ArgumentError naming name when it is absent, and makes no transport call"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#guards in wire order — an empty params map names lookup_key first"
        status: pass
    human_judgment: false
  - id: D3
    description: "T-63-09: a retried create/3 carrying the same idempotency_key opt sends the same idempotency-key header on BOTH attempts, so Stripe de-duplicates rather than creating a second feature"
    requirement: ENT-04
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#sends a stable idempotency-key header on both of two identical create attempts"
        status: pass
    human_judgment: false
  - id: D4
    description: "retrieve/3 GETs the item path and update/4 POSTs it; update/4 with active: false is the archive operation and decodes an archived %Feature{active: false}"
    requirement: ENT-04
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#GETs /v1/entitlements/features/{id} and returns a typed struct"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#POSTs /v1/entitlements/features/{id} with active: false and decodes the archived feature"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#returns the bare struct on success (update!/4)"
        status: pass
    human_judgment: false
  - id: D5
    description: "list/3 passes archived and lookup_key filters through to the query string unchanged, and a single-match lookup_key filter returns a %LatticeStripe.List{} of one — a list, never a singleton"
    requirement: ENT-04
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#passes the archived filter through to the query string unchanged"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#a lookup_key filter matching exactly one feature still returns a %List{} of one"
        status: pass
    human_judgment: false
  - id: D6
    description: "Decoding is total and order-preserving: an empty page is a typed empty %List{}, and two features sharing a name keep their relative wire order"
    requirement: ENT-04
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#an empty page decodes to a typed empty list, not nil and not an error"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#two features sharing a name keep their relative wire order"
        status: pass
    human_judgment: false
  - id: D7
    description: "D-13: stream!/3 emits typed %Feature{} values and carries filters onto every page it fetches, so full catalog enumeration under a filter is not silently truncated at page 1"
    requirement: ENT-04
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#emits typed %Feature{} values over a single page"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#carries the archived filter onto every page it fetches"
        status: pass
    human_judgment: false
  - id: D8
    description: "from_map/1 is total and idempotent — nil maps to nil, an already-typed struct returns unchanged, unknown wire keys land in :extra"
    requirement: ENT-04
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#returns nil for nil"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#is idempotent on an already-typed struct"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#captures unknown wire keys in :extra"
        status: pass
    human_judgment: false
  - id: D9
    description: "D-23 L1: the COMPLETE surface is locked in both directions — every shipped function pinned at every exported arity, and delete, archive, unarchive, set_active, retrieve_by_lookup_key and a non-bang stream all refuted"
    requirement: ENT-04
    verification:
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#exports the complete shipped verb surface"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#does not export a delete verb — Stripe ships no DELETE for features"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#does not export archive or unarchive — archiving is update/4 with active: false"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#does not export a lookup_key retrieval helper"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/entitlements/feature_test.exs#stream! has no non-bang twin — auto-pagination raises, it does not return tuples"
        status: pass
    human_judgment: false
  - id: D10
    description: "T-63-08: the active-field vs archived-filter vocabulary split and its false-deletion consequence are documented in the moduledoc where the reader hits them; documentation is the only available mitigation because stripe-mock's response does not vary by filter"
    requirement: ENT-04
    verification:
      - kind: other
        ref: "lib/lattice_stripe/entitlements/feature.ex ## Archiving — contains both `active` and `archived`, the {: .warning} 'Archived is not deleted' admonition, and the literal %{\"archived\" => true} prescription; mix docs exits 0"
        status: pass
      - kind: other
        ref: "L3 prose lock deferred to the 63-07 docs-truth suite by plan instruction"
        status: deferred
    human_judgment: true
  - id: D11
    description: "D-12: lookup_key's post-create immutability is documented as the reason it is safe to key host configuration on, alongside the filter form and the list-not-singleton return shape"
    requirement: ENT-04
    verification:
      - kind: other
        ref: "lib/lattice_stripe/entitlements/feature.ex ## Using lookup_key as your system identifier — contains `immutable`, the filter recipe, and the no-retrieve_by_lookup_key rationale"
        status: pass
    human_judgment: true

# Metrics
duration: 3min
completed: 2026-07-28
status: complete
---

# Phase 63 Plan 03: Complete Entitlements Feature Surface Summary

**`LatticeStripe.Entitlements.Feature` now ships its complete Stripe surface — create/retrieve/update/list plus `stream!/3` — behind two ordered pre-network guards, with the `active`-versus-`archived` false-deletion landmine and `lookup_key`'s post-create immutability documented where a reader will actually hit them.**

## Performance

- **Duration:** ~3 min (first commit 2026-07-28 11:26:10 -0400 → last 11:29:20 -0400)
- **Tasks:** 3 of 3
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments

- **ENT-04's surface is complete, not partial.** Stripe ships `[get, post]` on `/v1/entitlements/features` and `[get, post]` on `/{id}` and nothing else (F-06), so `create/3`, `retrieve/3`, `update/4`, `list/3` — plus `stream!/3` — *is* the whole surface. All ten public functions compose from the single `@list_path` attribute; `grep -c '"/v1/entitlements/features"'` on the module returns **1**.
- **Both required create params are guarded before the network, in wire order.** `Resource.require_param!/3` raises `ArgumentError` naming `lookup_key` first, then `name`. Three tests prove it with **zero** Mox expectations set, so `verify_on_exit!` is itself the evidence that no transport call was attempted — a passing test here cannot be faked by a mock that happened not to be called.
- **T-63-08 is mitigated the only way it can be.** The `active` object field and the `archived` list filter are two words for one concept with inverted sense, and `list/3` silently returns a *filtered view*. Nothing in a function signature can surface that. The `## Archiving` section names both halves, quotes Stripe's own `active` field description so a future reader can verify the claim without leaving the docs, and carries an `{: .warning}` admonition — **"Archived is not deleted"** — stating the actual harm: a reconciler that passes no filter sees archived features vanish, diffs them as deletions, and can revoke access a customer still legitimately holds. The prescription is one literal string: `%{"archived" => true}`.
- **T-63-09 is proven on the retry, not just the first call.** A single `expect/3` with a count of `2` asserts `{"idempotency-key", "key_1"}` is present on **both** identical create attempts, which is the only shape that actually demonstrates de-duplication rather than mere header forwarding.
- **`lookup_key`'s real unlock is documented.** Not the filter form (obvious) but the immutability: the field is absent from the update request body schema entirely, so Stripe silently ignores an attempt to change it. That is what makes it safe to key host application configuration on the lookup key rather than on the generated `feat_` id. The section also states that a `lookup_key` filter returns a **list, not a singleton** — and a test asserts a single-match response still comes back as `%LatticeStripe.List{}` with `length(data) == 1`, which is what stops a future contributor "helpfully" unwrapping it and inventing multi-result semantics Stripe does not define.
- **The absent verbs are locked structurally, at every arity.** `delete/2,3`, `archive/2,3`, `unarchive/2,3`, `set_active/3,4`, `retrieve_by_lookup_key/2,3` and `stream/1,2,3` are all refuted. Refuting both arities of a defaulted-opts verb (63-02's convention) is what stops `def archive(client, id, opts \\ [])` slipping past a lock that only checked arity 3. With no Dialyzer and documentation-only typespecs, these locks are this project's *only* enforcement of public surface shape.
- **The 63-01 carry-forward is fully discharged** — see below.

## The 63-01 carry-forward

Plan 63-01 shipped `feature.ex` in two halves and left two deliberate artifacts for this plan. Both are resolved:

1. **The missing alias line.** `alias LatticeStripe.{Client, Request, Resource}` is now present, and the three-line in-source `NOTE:` comment that reserved its place is deleted. All three modules are genuinely referenced by the new verb surface, so `mix compile --warnings-as-errors` stays green — the exact gate that forced the omission in the first place.
2. **The vestigial `@doc false def list_path, do: @list_path` accessor is removed** rather than duplicated forward. 63-01 added it solely so `@list_path` would not trip `module attribute set but never used`; its own SUMMARY records that "the `@doc false` accessor is what makes it legal today". Five verbs read `@list_path` now, so the reason is gone. Nothing referenced `Feature.list_path/0` (`grep -rn` across `lib/` and `test/` confirms), and this plan's `must_haves` truth enumerates the exact shipped surface — ten functions, `list_path/0` not among them. `ActiveEntitlement.list_path/0` **stays**, because it has a live consumer: 63-04's summary url rewrite reads it (D-06). The asymmetry is deliberate and load-bearing, not an inconsistency.

## Task Commits

Each task was committed atomically:

1. **Task 3: Unit-test ENT-04 and lock the complete verb surface** — `a67d3b8` (test) — **RED**, 29 tests / 21 failures
2. **Task 1: Ship the complete Feature verb surface** — `34e2349` (feat) — **GREEN**
3. **Task 2: Write the two moduledoc sections that carry the invisible landmines** — `d047b95` (docs)

**Plan metadata:** see the `docs(63-03)` commit that carries this SUMMARY.

## Files Created/Modified

- `lib/lattice_stripe/entitlements/feature.ex` (modified, 84 → 308 lines) — four new banner-fenced verb sections in `meter.ex`'s exact order (`CREATE` → `RETRIEVE` → `UPDATE` → `LIST + STREAM`), with `from_map/1` still last under `DECODE`. `create/3` carries no `params` default; `update/4` carries the double guard `when is_binary(id) and is_map(params)`; `retrieve/3` carries `when is_binary(id)` only, with no `id in [nil, ""]` clause (D-11). The moduledoc gained `## Archiving` and `## Using lookup_key as your system identifier`, plus a surface-completeness paragraph and a relative `guides/entitlements.md` link. No `defimpl Inspect` (D-14).
- `test/lattice_stripe/entitlements/feature_test.exs` (new, 412 lines, 29 tests, `async: true`) — one `describe` block per verb plus a dedicated pre-network-guard block and the `describe "module surface"` L1 lock block. Filter and cursor assertions read `req.url` (GET params arrive query-encoded); body assertions read `req.body` (form-encoded); header assertions read `req.headers` with lowercase names.

## Decisions Made

- **Test-first ordering (Task 3 → Task 1 → Task 2).** Task 1 carried `tdd="true"` but its `<files>` listed only `feature.ex`, and its `<behavior>` block said "Proven by `feature_test.exs` in Task 3" — so executing the plan's literal 1→2→3 order would have produced a `tdd="true"` task with no RED gate at all. Writing Task 3's file first gave Task 1 a genuine RED (29 tests, 21 failures) and left every task still committed individually. See Deviations.
- **`Feature.list_path/0` removed, `ActiveEntitlement.list_path/0` kept.** Rationale above; the asymmetry tracks a real difference in consumers.
- **Surface locks refute extra arities beyond the plan's literal list.** The plan named `archive/3`, `unarchive/3`, `retrieve_by_lookup_key/3`; the file also refutes arity 2 of each, plus `set_active/3,4`. This follows 63-02's established convention of refuting *every* exported arity of a defaulted-arg verb. The `delete` grep count stays at exactly **2** as the acceptance criterion requires. `set_active` is refuted because the `## Archiving` section names it as the function the house verb doctrine *would* force — naming it in prose without locking it structurally is exactly the gap D-23 exists to close.
- **`mix ci` was deliberately not run** — verification step 7 of the plan forbids it; it is RED at clean HEAD because its `docs --warnings-as-errors` step carries a 42-warning pre-existing baseline (C-02).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Task 1's `tdd="true"` flag had no test file to make red**

- **Found during:** Task 1 (before implementation)
- **Issue:** Task 1 is marked `tdd="true"`, but its `<files>` element lists only `lib/lattice_stripe/entitlements/feature.ex` and its `<behavior>` block defers proof to `feature_test.exs`, which the plan assigns to Task 3. Executing 1→2→3 literally would mean a TDD task whose RED gate never existed — the tests would have been written against already-passing code.
- **Fix:** Executed Task 3's action first as the RED gate (`a67d3b8`, 29 tests / 21 failures), then Task 1 as GREEN (`34e2349`), then Task 2 (`d047b95`). Task 3's `<read_first>` names "the module as Tasks 1 and 2 left it", but every fact the test file needed was available from the plan's own `<behavior>` and `<action>` text plus 63-01's shipped decode half, so nothing was blocked. All three tasks remain individually committed and every acceptance criterion from all three tasks is met.
- **Files modified:** none beyond the plan's own two files
- **Verification:** RED observed and recorded before implementation; `mix test test/lattice_stripe/entitlements/` → 61 tests, 0 failures after GREEN.
- **Committed in:** commit ordering only

**2. [Rule 2 - Missing critical functionality] `Feature.list_path/0` reconciled rather than carried forward**

- **Found during:** Task 1
- **Issue:** 63-01 added `@doc false def list_path, do: @list_path` to `Feature` purely to keep `@list_path` from being an unused module attribute. This plan's `must_haves` truth enumerates the exact shipped surface and does not include it, and the phase's own artifact inventory assigns `list_path/0` to `ActiveEntitlement` only.
- **Fix:** Removed the accessor from `Feature`. Confirmed via `grep -rn "list_path" lib/ test/` that nothing referenced `Feature.list_path/0`. `ActiveEntitlement.list_path/0` is untouched — it has a live downstream consumer in 63-04.
- **Files modified:** `lib/lattice_stripe/entitlements/feature.ex`
- **Verification:** `mix compile --warnings-as-errors` exits 0 (five verbs now read `@list_path`); full suite green.
- **Committed in:** `34e2349`

**3. [Rule 2 - Missing critical functionality] Surface lock widened to every exported arity**

- **Found during:** Task 3
- **Issue:** The plan's acceptance criteria name `archive/3`, `unarchive/3` and `retrieve_by_lookup_key/3`. A future `def archive(client, id, opts \\ [])` exports arities **2 and 3**, so an arity-3-only refutation is a lock with a hole in it — the precise failure mode 63-02 identified and fixed for `stream!/3`.
- **Fix:** Added arity-2 refutations for all three, plus `set_active/3,4` because the moduledoc names `set_active` explicitly as the name the verb doctrine would force. `delete` deliberately left at exactly two refutations (arities 2 and 3) to satisfy the plan's `grep -c ... returns 2` criterion.
- **Files modified:** `test/lattice_stripe/entitlements/feature_test.exs`
- **Verification:** `grep -c 'refute function_exported?(Feature, :delete'` returns 2; all surface tests pass.
- **Committed in:** `a67d3b8`

---

**Total deviations:** 3 auto-fixed (1× Rule 3, 2× Rule 2). No Rule 4 architectural decisions were needed and no checkpoint was reached.
**Impact on plan:** None on behavior or shipped surface. Deviation 1 is ordering only. Deviations 2 and 3 both move the module *toward* the plan's stated truths rather than away from them.

## Issues Encountered

None blocking. Two new ExDoc warnings are introduced by this plan and are recorded here so 63-07's differential docs gate can attribute them:

| Warning | Source | Disposition |
|---|---|---|
| `documentation references file "guides/entitlements.md" but it does not exist` | the moduledoc guide cross-link Task 2 explicitly mandates | **Transient.** Resolves when 63-06 ships `guides/entitlements.md`. Writing the link now is what makes the guide discoverable the moment it lands. |
| `documentation references function "LatticeStripe.Resource.require_param!/3" but it is hidden` | `create/3`'s `@doc`, per D-10's instruction to note the presence-not-emptiness semantics | **Accepted, and consistent.** `LatticeStripe.Resource` is `@moduledoc false`. `ActiveEntitlement` carries the identical reference and the identical warning from 63-01/63-02; diverging in one of two sibling modules would be worse than the warning. |

Each renders in ExDoc's HTML, EPUB and markdown passes, so the raw `grep -c 'warning:'` count moved from 42 (clean-HEAD baseline) to 50 across the whole phase so far — 4 distinct warnings × 2 counted passes, split evenly between the two entitlements modules.

### Verification results

| Check | Result |
|---|---|
| `mix format --check-formatted` | exit 0 |
| `mix compile --warnings-as-errors` | exit 0 |
| `mix test test/lattice_stripe/entitlements/` | 61 tests, 0 failures |
| `mix test` (full suite) | **2175 tests, 0 failures, 1 skipped (197 excluded)** |
| `mix credo --strict` | 2213 mods/funs, found no issues |
| `mix docs` | exit 0 |
| `grep -c '"/v1/entitlements/features"' lib/.../feature.ex` | 1 ✓ |
| `grep -c 'defimpl Inspect' lib/.../feature.ex` | 0 ✓ |
| `grep -c 'https://' lib/.../feature.ex` | 0 ✓ |
| `grep -c 'refute function_exported?(Feature, :delete' test/.../feature_test.exs` | 2 ✓ |
| `grep -n 'def list_path' lib/.../feature.ex` | no match ✓ (carry-forward resolved) |
| `mix ci` | **intentionally not run** — plan verification step 7 |

## TDD Gate Compliance

All three gates present and correctly ordered in git log: **RED** `a67d3b8` (`test`, 29 tests / 21 failures) → **GREEN** `34e2349` (`feat`, 61 entitlements tests / 0 failures). No REFACTOR commit was needed — `mix format` and `mix credo --strict` were both clean on the first GREEN, so there was nothing to clean up and an empty refactor commit would have been noise. `d047b95` (`docs`) adds documentation only and changes no behavior.

## Known Stubs

None. Every function in `Feature` issues a real request through `Client.request/2` and decodes through `from_map/1`; there are no placeholder returns, no hardcoded empty collections, no TODO or FIXME markers, and no skipped tests in either file this plan touched. The verbs Stripe does not offer are *absent and structurally locked*, which is the opposite of stubbed.

## User Setup Required

None — no external service configuration required. This plan installs zero packages (T-63-SC: no `mix.exs` `deps/0` change).

## Next Phase Readiness

**Ready.** ENT-04 is complete and `Feature` is finished as a module — no later plan in this phase needs to add a verb to it.

- **63-06** (`guides/entitlements.md`) inherits a moduledoc that already links to the guide by its final path, so shipping the file closes the transient ExDoc warning above with no edit to `feature.ex`.
- **63-07**'s docs-truth suite has its L3 targets in place: the `## Archiving` and `## Using lookup_key as your system identifier` headings, the literal `%{"archived" => true}` prescription, and the `immutable` claim. Per this plan's instruction the L3 prose locks assert *presence* and were deliberately not written here.
- **Phase 66** (`Product.Feature`) can call `Feature.from_map/1` unconditionally on the `entitlement_feature` field — it is a direct `$ref`, never a bare id string (C-04), and the moduledoc says so.
- **Recorded for the register:** D-08 is *reversible by design*. If adopter pull ever justifies `archive/3`, adding it is an additive minor bump; the current absence deliberately buys that optionality rather than spending it.

## Self-Check: PASSED

All claimed files exist on disk (`lib/lattice_stripe/entitlements/feature.ex`, `test/lattice_stripe/entitlements/feature_test.exs`, this SUMMARY) and all three claimed commits resolve in `git log` (`a67d3b8`, `34e2349`, `d047b95`).

---
*Phase: 63-stripe-native-entitlements*
*Completed: 2026-07-28*
