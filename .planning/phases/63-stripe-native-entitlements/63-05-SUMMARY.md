---
phase: 63-stripe-native-entitlements
plan: 05
subsystem: api
tags: [stripe, entitlements, integration-test, stripe-mock, exunit, roadmap]

# Dependency graph
requires:
  - phase: 63-02
    provides: "LatticeStripe.Entitlements.ActiveEntitlement — list/3, retrieve/3 and the mandatory pre-network customer guard"
  - phase: 63-03
    provides: "LatticeStripe.Entitlements.Feature — create/3, retrieve/3, update/4, list/3 composed from a single @list_path"
  - phase: 63-01
    provides: "test/support/fixtures/entitlements.ex and its PROMOTION TARGET header comment"
  - phase: pre-existing library core
    provides: "LatticeStripe.TestHelpers.test_integration_client/1, LatticeStripe.Transport.Finch, LatticeStripe.Response, LatticeStripe.List"
provides:
  - "test/integration/entitlements_integration_test.exs — real-routing proof for all six shipped verbs against stripe-mock v0.199.0"
  - "The loud-failure contract: setup_all raises with the exact docker command when nothing listens on 12111 — no @tag :skip, no capability probe"
  - ".planning/ROADMAP.md Phase 65 build constraint carrying the fixture move-plus-rename promotion contract"
affects: [63-06, 63-07, phase-65-object-types]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Integration setup_all that RAISES rather than skips — a silent skip is the fake-green failure mode this project has recorded values against (T-63-15)"
    - "Presence-not-count assertions against stripe-mock (`list.data != []`), because the mock returns one synthetic item per list regardless of the request"
    - "Deliberate non-assertion recorded in the moduledoc: pagination is structurally unprovable against stripe-mock, so the reason lives next to its absence"

key-files:
  created:
    - test/integration/entitlements_integration_test.exs
  modified:
    - .planning/ROADMAP.md

key-decisions:
  - "D-20 held in full: the integration leg carries zero capability probes and zero @tag :skip; the mock's absence is a hard raise carrying the copy-pasteable docker command"
  - "Pagination deliberately not asserted here — stripe-mock ignores page size and cursor and returns one item per list; that proof stays in 63-02's Mox multi-page suite"
  - "No raw-DELETE test written — the SDK exposes no delete verb, and its absence is already locked structurally in feature_test.exs; a DELETE test here would prove a Stripe fact, not an SDK fact"
  - "Seven tests, not six: Feature.list/3 gets two cases (bare and archived filter) exactly as the plan's action text prescribes"
  - "D-27's real deliverable is the ROADMAP build-constraints line, not the source comment — a comment inside a test file is unlikely to be read at Phase 65 planning time"

requirements-completed: [ENT-01, ENT-03, ENT-04]

coverage:
  - id: D1
    description: "ActiveEntitlement.list/3 routes to /v1/entitlements/active_entitlements against a server generated from Stripe's own OpenAPI spec, and decodes into a %Response{} wrapping a %List{} of %ActiveEntitlement{} structs"
    requirement: ENT-01
    verification:
      - kind: integration
        ref: "test/integration/entitlements_integration_test.exs#list/3 routes to the canonical list path and decodes typed items"
        status: pass
    human_judgment: false
  - id: D2
    description: "ActiveEntitlement.retrieve/3 routes to the item path and decodes a typed struct carrying the entitlements.active_entitlement object tag"
    requirement: ENT-01
    verification:
      - kind: integration
        ref: "test/integration/entitlements_integration_test.exs#retrieve/3 returns a typed struct with the entitlements object tag"
        status: pass
    human_judgment: false
  - id: D3
    description: "Feature.create/3 POSTs /v1/entitlements/features and the server echoes lookup_key and name back with active: true — proof the form-encoded body is accepted, not merely constructed"
    requirement: ENT-04
    verification:
      - kind: integration
        ref: "test/integration/entitlements_integration_test.exs#create/3 POSTs the list path and echoes the submitted fields"
        status: pass
    human_judgment: false
  - id: D4
    description: "Feature.retrieve/3 and update/4 both route to the item path and decode typed %Feature{} structs"
    requirement: ENT-04
    verification:
      - kind: integration
        ref: "test/integration/entitlements_integration_test.exs#retrieve/3 returns a typed struct"
        status: pass
      - kind: integration
        ref: "test/integration/entitlements_integration_test.exs#update/4 POSTs the item path and returns a typed struct"
        status: pass
    human_judgment: false
  - id: D5
    description: "Feature.list/3 routes to the canonical list path, and the archived filter is accepted with a 200 — acceptance only, since stripe-mock's synthetic response does not vary by filter"
    requirement: ENT-04
    verification:
      - kind: integration
        ref: "test/integration/entitlements_integration_test.exs#list/3 routes to the canonical list path"
        status: pass
      - kind: integration
        ref: "test/integration/entitlements_integration_test.exs#list/3 accepts the archived filter"
        status: pass
    human_judgment: false
  - id: D6
    description: "T-63-15: the suite never reports green when stripe-mock is absent — setup_all raises with the exact docker command, invalidating every test in the module"
    requirement: ENT-03
    verification:
      - kind: other
        ref: "Observed directly: container stopped, suite run -> RuntimeError 'stripe-mock not running on localhost:12111 — start with: docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest', reported as '7 tests, 0 failures, 7 invalid' with a non-zero exit"
        status: pass
    human_judgment: false
  - id: D7
    description: "Auto-pagination across pages for a customer with more than one active entitlement — stripe-mock returns exactly one synthetic item per list and ignores page size and cursor, so this is unprovable at this leg"
    requirement: ENT-01
    verification:
      - kind: other
        ref: "Mox multi-page proof in test/lattice_stripe/entitlements/active_entitlement_stream_test.exs (plan 63-02); live-Stripe confirmation remains a backstop truth with no live key in this environment (accepted risk A1)"
        status: deferred
    human_judgment: true
  - id: D8
    description: "D-27: Phase 65's build constraints record that the fixture promotion is a move PLUS a module rename, so it cannot be planned as a verbatim file move"
    requirement: ENT-03
    verification:
      - kind: other
        ref: ".planning/ROADMAP.md Phase 65 build-constraints line contains LatticeStripe.Testing.Fixtures.Entitlements, test/support/fixtures/entitlements.ex, and all four function names"
        status: pass
    human_judgment: true

# Metrics
duration: 8min
completed: 2026-07-28
status: complete
---

# Phase 63 Plan 05: stripe-mock Integration Proof Summary

**All six shipped entitlements verbs now round-trip against `stripe/stripe-mock` v0.199.0 — a real HTTP server generated from Stripe's own OpenAPI spec — and the suite raises with a copy-pasteable docker command rather than skipping when the mock is absent.**

## Performance

- **Duration:** ~8 min
- **Tasks:** 2 of 2
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments

- **The routing gap is closed for real, not simulated.** The Mox suites from 63-02/63-03 prove the SDK *constructs* the right requests; they cannot prove Stripe *accepts* them. `stripe-mock` v0.199.0 was pulled, started on 12111-12112, and all seven tests ran green against it — real HTTP, real form-encoded bodies, real JSON decode, real `%LatticeStripe.Response{}` and `%LatticeStripe.List{}` shapes. `Feature.create/3` sends `lookup_key` and `name` over the wire and the server echoes both back with `active: true`, which is a materially stronger claim than "the request struct had the right body".
- **T-63-15 is mitigated by construction and verified by experiment.** The `setup_all` `:gen_tcp.connect` probe raises on `{:error, _}`. This was not asserted from the source — the container was **stopped** and the suite re-run, producing `** (RuntimeError) stripe-mock not running on localhost:12111 — start with: docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest` and a `7 tests, 0 failures, 7 invalid` report with a non-zero exit. The file contains zero `@tag :skip` and zero capability probes, because a probe's failure mode *is* the silent skip this mitigates.
- **The two things stripe-mock cannot prove are recorded where they are absent, not omitted silently.** The `@moduledoc` states that the mock ignores page size and cursor and returns one synthetic item per list, which is why no pagination test lives here and why every count assertion is presence-based (`list.data != []`) rather than an exact number. A future contributor who "fixes" this by asserting a count will find the test flaps against the mock's synthetic response.
- **No raw-DELETE test was written, deliberately.** Research confirmed `DELETE /v1/entitlements/features/{id}` returns 404 (F-06), but that is a *Stripe* fact. The SDK-shape fact — that no `delete` verb is exported at any arity — is already locked structurally in `feature_test.exs`. Asserting a 404 here would test the mock, not the library.
- **Phase 65 can no longer mis-plan the fixture promotion.** The build-constraints line now says in one sentence that `test/support/fixtures/entitlements.ex` moves to `lib/lattice_stripe/testing/fixtures/entitlements.ex` **and** renames `LatticeStripe.Test.Fixtures.Entitlements` → `LatticeStripe.Testing.Fixtures.Entitlements`, that the private and public fixture namespaces differ so a literal move alone is a compile error, and that the four function bodies transfer unchanged rather than being re-authored.

## Task Commits

Each task was committed atomically:

1. **Task 1: Route all six verbs against stripe-mock** — `17927ed` (test) — 7 tests, 0 failures
2. **Task 2: Record the fixture promote-by-move contract in Phase 65's build constraints** — `54cc8ec` (docs)

**Plan metadata:** see the `docs(63-05)` commit that carries this SUMMARY.

## Files Created/Modified

- `test/integration/entitlements_integration_test.exs` (new, 109 lines, 7 tests, `async: false`) — header and `setup_all` copied verbatim from `charge_integration_test.exs`, changing only the module name and `@moduledoc`. Two `describe` blocks (`ActiveEntitlement`, `Feature`). `async: false` is mandatory: the suite shares the one `LatticeStripe.IntegrationFinch` pool started by `setup_all`.
- `.planning/ROADMAP.md` (modified, 1 line changed) — one sentence appended to the existing `**Build constraints**:` line of `### Phase 65: Webhook ObjectTypes & Testing Fixtures` via a scoped `Edit`. `git diff --stat` shows `1 insertion(+), 1 deletion(-)`; all seven v1.10 phase entries survive.

## Decisions Made

- **Seven tests rather than six.** The plan's `must_haves` names six verbs, and its `<action>` text separately prescribes a second `Feature.list/3` case for the `archived` filter. Both are honored: one test per verb plus the filter case.
- **Presence assertions, never counts.** `assert list.data != []` rather than `length(list.data) >= 1` — semantically identical for this purpose, and it is also what `mix credo --strict` requires (see Deviations).
- **The `archived` filter case asserts `status: 200` explicitly** by destructuring `%LatticeStripe.Response{status: 200, ...}`, since "the filter is accepted" is the only claim stripe-mock can support — the response body does not vary by filter.
- **`mix ci` was deliberately not run** — plan verification step 6 forbids it; it is RED at clean HEAD for pre-existing `docs --warnings-as-errors` reasons (C-02).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `mix credo --strict` flagged `length/1` on a list-emptiness check**

- **Found during:** Task 1 verification
- **Issue:** The plan's action text says "Assert the item count is at least 1", which the first draft rendered as `assert length(list.data) >= 1`. Credo's `Enum.count`/`length` check fired: *"Using `length/1` is expensive, prefer comparing against an empty list."* The phase baseline for `mix credo --strict` is **zero issues** (63-03 recorded "found no issues"), so this was a real regression against a green gate, not pre-existing noise.
- **Fix:** Changed to `assert list.data != []`. This is the identical claim — "at least one item" — expressed the way the linter requires, and it still explicitly does *not* assert an exact count, which is what the plan actually cares about.
- **Files modified:** `test/integration/entitlements_integration_test.exs`
- **Verification:** `mix credo --strict` → 2225 mods/funs, **found no issues**.
- **Committed in:** `17927ed`

**2. [Rule 3 - Blocking] The moduledoc's honest pagination note tripped the plan's own `starting_after` grep criterion**

- **Found during:** Task 1 verification
- **Issue:** The plan requires `grep -c 'starting_after' test/integration/entitlements_integration_test.exs` to return **0**, as a structural guarantee that pagination is not asserted here. The first draft's `@moduledoc` explained *why* pagination is absent by naming the ignored parameters literally — "stripe-mock ignores `limit` and `starting_after`" — which made the count 1. The criterion's intent is that no pagination is *exercised*; a prose mention in a moduledoc is not an assertion, but the criterion is a literal grep and a future guard that fires on prose is a guard that will be deleted.
- **Fix:** Reworded the moduledoc to "ignores both the page size and the cursor parameter". The recorded reason is fully preserved — arguably clearer, since it names the concepts rather than two Stripe parameter spellings — and the grep now returns 0, so the structural guard stays meaningful.
- **Files modified:** `test/integration/entitlements_integration_test.exs`
- **Verification:** `grep -c 'starting_after' test/integration/entitlements_integration_test.exs` → `0`.
- **Committed in:** `17927ed`

---

**Total deviations:** 2 auto-fixed (both Rule 3). No Rule 4 architectural decisions were needed and no checkpoint was reached.
**Impact on plan:** None on behavior or coverage. Both are wording/expression changes that move the file *toward* the plan's own stated criteria.

## Issues Encountered

**A correction to the orchestrator's briefing, recorded because it could mislead a later plan.** The execution briefing for this plan described `Feature` as shipping "full verb surface incl. `archive`/`unarchive`/`retrieve_by_lookup_key`". That is **wrong**, and following it would have produced integration tests calling functions that do not exist. `63-03-SUMMARY.md` records that D-08 and D-12 *held*: `archive/2,3`, `unarchive/2,3`, `set_active/3,4` and `retrieve_by_lookup_key/2,3` are all **absent and structurally refuted** in `feature_test.exs`. Archiving is `update/4` with `active: false`. The shipped ten are `create/3`, `create!/3`, `retrieve/3`, `retrieve!/3`, `update/4`, `update!/4`, `list/3`, `list!/3`, `stream!/3`, `from_map/1`. This plan's tests were written against the module source and 63-03's summary, which are the sources of truth. (The briefing's other correction — that `Feature.list_path/0` was removed — is accurate and was honored.)

**The 63-04 flake did not reproduce.** Plan 63-04's executor recorded one full-suite run reporting `2187 tests, 1 failure` with no failure block printed. `mix test` was run **four** times here (once at default seed, three times at random seeds) and reported `2187 tests, 0 failures, 1 skipped (204 excluded)` every time. The full suite including integration reported `2379 tests, 0 failures, 12 skipped (12 excluded)`. Nothing anomalous was observed; the flake remains unexplained but also unreproduced across 12 total runs between the two plans.

### Verification results

| Check | Result |
|---|---|
| `mix test --include integration test/integration/entitlements_integration_test.exs` | **7 tests, 0 failures** (exit 0) |
| Skipped/excluded in that run | **0** — nothing skipped ✓ |
| `mix test` (integration excluded by default) | **2187 tests, 0 failures, 1 skipped (204 excluded)** |
| `mix test` × 3 more, random seeds | identical every run — no flake |
| `mix test --include integration` (whole suite) | **2379 tests, 0 failures, 12 skipped (12 excluded)** |
| `mix format --check-formatted` | exit 0 |
| `mix compile --warnings-as-errors` | exit 0 |
| `mix credo --strict` | 2225 mods/funs, found no issues |
| Behavior: mock stopped → suite raises with the docker command | ✓ verified by stopping the container |
| `grep -c '@moduletag :integration'` | 1 ✓ |
| `grep -c 'use ExUnit.Case, async: false'` | 1 ✓ |
| `grep -c 'docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest'` | 1 ✓ |
| `grep -c '@tag :skip'` | 0 ✓ |
| `grep -c 'starting_after'` | 0 ✓ |
| `grep -c 'LatticeStripe.Testing.Fixtures.Entitlements' .planning/ROADMAP.md` | 1 ✓ |
| `grep -c 'test/support/fixtures/entitlements.ex' .planning/ROADMAP.md` | 1 ✓ |
| Phase-65-scoped `awk` + grep | 1 ✓ — the text landed inside the right section |
| `grep -c '^### Phase ' .planning/ROADMAP.md` | 7 ✓ — every phase entry survives |
| `git diff --stat .planning/ROADMAP.md` | `1 insertion(+), 1 deletion(-)` ✓ — scoped edit, not a rewrite |
| `mix ci` | **intentionally not run** — plan verification step 6 |

## Environment

`stripe-mock` was **genuinely available and genuinely exercised** — this is not an authored-but-unrun suite. Docker daemon reachable (precondition met); `stripe/stripe-mock:latest` resolved to **v0.199.0**, matching the version recorded in `63-RESEARCH.md` § Environment Availability, and was started as container `gsd-stripe-mock-63-05` on ports 12111-12112. All seven tests executed against it.

To re-run: `docker run -d -p 12111-12112:12111-12112 stripe/stripe-mock:latest`, then
`mix test --include integration test/integration/entitlements_integration_test.exs`.

The suite is correctly excluded from the default `mix test` run by the project's existing
`ExUnit.configure(exclude: [:integration, ...])` in `test/test_helper.exs` — the default-run exclusion count moved from 197 to 204, exactly the seven tests added here.

## Known Stubs

None. Every test issues a real HTTP request through `LatticeStripe.Transport.Finch` to a live server and asserts on the decoded response. There are no placeholder returns, no mock stand-ins, no `@tag :skip`, no TODO or FIXME markers, and no capability probe. The one deliberate non-assertion — pagination — is documented in the moduledoc with its reason, and its proof exists elsewhere (63-02's Mox suite), so it is a recorded division of labor rather than a gap.

## User Setup Required

Docker must be running to execute this suite locally; the suite tells you the exact command if it is not. This plan installs zero packages — no `mix.exs` `deps/0` change (T-63-SC).

## Next Phase Readiness

**Ready.** D-20's triangulation now has two of its three legs complete — Mox unit tests (63-02/63-03/63-04) and stripe-mock integration (this plan). The third, docs-truth, is 63-07's.

- **63-06** (`guides/entitlements.md`) is unblocked and unaffected by this plan; shipping the guide closes the transient ExDoc warning carried since 63-01.
- **63-07**'s docs-truth suite can now cite live-routed behavior rather than only constructed requests.
- **Phase 65** inherits the promote-by-move contract in its build constraints, so the fixture promotion cannot be planned as a verbatim file move.
- **Recorded for the register:** live-Stripe confirmation of multi-page auto-pagination (`must_haves` backstop truth) remains **unverified** — no live Stripe key exists in this environment, which is standing accepted risk A1. stripe-mock structurally cannot close it.

## Self-Check: PASSED

Both claimed files exist on disk (`test/integration/entitlements_integration_test.exs`, `.planning/ROADMAP.md`) and both claimed commits resolve in `git log` (`17927ed`, `54cc8ec`).

---
*Phase: 63-stripe-native-entitlements*
*Completed: 2026-07-28*
