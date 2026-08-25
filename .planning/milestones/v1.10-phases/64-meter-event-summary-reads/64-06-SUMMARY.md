---
phase: 64-meter-event-summary-reads
plan: 06
subsystem: api
tags: [stripe, billing, metering, meter-event-summary, pagination, stream, mox, mutation-testing, security]

# Dependency graph
requires:
  - phase: 64-meter-event-summary-reads
    provides: "64-03's live MeterEventSummary.stream!/2..4, delegating to LatticeStripe.List.stream!/2 and mapping from_map/1"
  - phase: 64-meter-event-summary-reads
    provides: "64-01's Metering.MeterEventSummary fixture — the mtrusg_-prefixed seven-field wire shape"
  - phase: 63-stripe-native-entitlements
    provides: "LatticeStripe.List cursor state machine (base_params preservation, starting_after derivation, idempotency-key strip), TestHelpers.list_json/3's has_more argument, and the Mox-at-Transport multi-page test pattern"
provides:
  - "test/lattice_stripe/billing/meter_event_summary_pagination_test.exs — all nine D-30 assertions, 15 tests"
  - "A mutation-proof record for T-64-03 (base_params preservation) and T-64-14 (cursor-before-typing) on this resource"
  - "The observation helpers query_params/1 and request_path/1 — URL-decoding the outgoing transport request rather than substring-matching it"
affects: [64-09-artifact-inventory, 64-10]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Assert page-2 request shape by URI.decode_query on the outgoing url, not by `=~` substring: `starting_after=mtrusg_b` matches a longer wrong id by prefix, an equality check on the decoded value does not"
    - "Prove the page-2 path comes from the response `url` by serving a DIFFERENT path in the page-1 body than the resource module would reconstruct"
    - "Prove partial-emission-before-error with a synchronous send/2 to self plus assert_received — no timeout, no timing dependency, safe under async: true"

key-files:
  created:
    - test/lattice_stripe/billing/meter_event_summary_pagination_test.exs
  modified: []

key-decisions:
  - "Assertion 7 serves a deliberately different `url` in the page-1 body (/v1/billing/meters/mtr_served_by_stripe/event_summaries) so the test fails if the page-2 path is rebuilt from the meter_id argument instead of read from the response — asserting the same path twice would have proven nothing"
  - "Request assertions decode the query string (URI.decode_query) and compare values exactly, rather than the `req.url =~ \"customer=cus_1\"` idiom used in sibling files: substring matching would also accept customer=cus_10"
  - "The mutation for T-64-14 was applied in lib/lattice_stripe/list.ex, not in meter_event_summary.ex — 64-05 owns that file in this wave, and the cursor derivation being mutated lives in List.from_json/3 anyway"

patterns-established:
  - "A mutation-checked test carries an inline comment naming the mutation that broke it and a do-not-rename instruction, so the proof survives the next refactor"
  - "Each preserved filter is asserted individually, because the failure that matters is a partial drop; a combined comparison would mask it"

requirements-completed: [MTR-02]

coverage:
  - id: D1
    description: "D-30 assertion 1 — the page-2 request's starting_after is the id of the LAST item of page 1, and page 1 itself carries no cursor"
    requirement: "MTR-02"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_pagination_test.exs#page 2 request uses starting_after from the LAST id of page 1"
        status: pass
    human_judgment: false
  - id: D2
    description: "D-30 assertion 9 / T-64-14 — the cursor is derived from the raw maps before typing: an mtrusg_-prefixed binary, never nil"
    requirement: "MTR-02"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_pagination_test.exs#the starting_after cursor is derived from the raw maps before typing"
        status: pass
      - kind: other
        ref: "Mutation: typing items before last_item_id/1 in List.from_json/3 => this test fails. Reverted."
        status: pass
    human_judgment: false
  - id: D3
    description: "D-30 assertion 2 / T-64-03 — page 2 preserves customer, start_time, end_time AND value_grouping_window, each asserted individually, in addition to the cursor"
    requirement: "MTR-02"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_pagination_test.exs#page 2 preserves customer, start_time, end_time and value_grouping_window"
        status: pass
      - kind: other
        ref: "Mutation: base_params := %{} in List.build_next_page_request/1 => this test fails, and exactly 2 other suite tests. Reverted."
        status: pass
    human_judgment: false
  - id: D4
    description: "D-30 assertion 5 / T-64-02 — the stripe-account header carries to page 2, from client config and from per-request opts"
    requirement: "MTR-02"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_pagination_test.exs#the stripe-account header carries to page 2"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_pagination_test.exs#a per-request stripe_account override also carries to page 2"
        status: pass
    human_judgment: false
  - id: D5
    description: "D-30 assertion 6 / T-64-04 — page 1 sends an idempotency-key and page 2 sends none, proving the strip rather than its absence"
    requirement: "MTR-02"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_pagination_test.exs#no idempotency-key is sent on page 2"
        status: pass
    human_judgment: false
  - id: D6
    description: "D-30 assertion 7 — the page-2 request path is the page-1 response url, not a path the resource module rebuilds"
    requirement: "MTR-02"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_pagination_test.exs#page 2 request path is taken from the page-1 response url, not rebuilt"
        status: pass
    human_judgment: false
  - id: D7
    description: "D-30 assertions 3 and 4 / T-64-07 — N pages produce exactly N transport calls; one page with has_more false and an empty first page each produce exactly one; Stream.take(1) over a two-page stream produces exactly one"
    requirement: "MTR-02"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_pagination_test.exs#streaming N pages makes exactly N transport calls"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_pagination_test.exs#Stream.take/2 on a two-page stream makes exactly ONE transport call"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_pagination_test.exs#an empty first page makes exactly one call and yields an empty list"
        status: pass
    human_judgment: false
  - id: D8
    description: "D-30 assertion 8 — a page-2 error raises LatticeStripe.Error out of the stream, and page-1 items are emitted before it, proving the raise comes from the second fetch"
    requirement: "MTR-02"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_pagination_test.exs#a 500 on page 2 raises LatticeStripe.Error out of the stream"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_pagination_test.exs#page-1 items are emitted before the page-2 error surfaces"
        status: pass
    human_judgment: false
  - id: D9
    description: "MTR-01 ordering — items are emitted in exact wire order within a page and across the page seam; the library never re-sorts"
    requirement: "MTR-02"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_pagination_test.exs#items are emitted in wire order within a page and across the page seam"
        status: pass
    human_judgment: false

# Metrics
duration: 10min
completed: 2026-07-28
status: complete
---

# Phase 64 Plan 06: MeterEventSummary Pagination Proof Summary

**All nine D-30 assertions now hold against a Mox transport, and the two that matter most are no longer merely green: zeroing `base_params` in `List.build_next_page_request/1` fails the four-filter test and exactly two others in the whole suite, and typing the page before the cursor is derived fails the cursor-derivation test — both mutations reverted, `lib/` byte-identical.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-07-28T23:53Z (base commit `f45bdaf`)
- **Completed:** 2026-07-29T00:04Z
- **Tasks:** 2 of 2
- **Files created:** 1

## Accomplishments

- **One new file, 15 tests, zero library changes.** `test/lattice_stripe/billing/meter_event_summary_pagination_test.exs` carries every D-30 assertion. `async: true`, `verify_on_exit!`, and no globally-scoped telemetry handler — the client is built with `telemetry_enabled: false`, so this file adds no second flake alongside the known one at `client_test.exs:912`.
- **Assertions are made on the decoded query string, not on substrings of the URL.** The sibling files use `assert req.url =~ "customer=cus_123"`. That idiom also accepts `customer=cus_1234`, and for a cursor assertion it also accepts a longer wrong id. Every request assertion here runs `URI.decode_query/1` over `URI.parse(url).query` and compares values with `==`.
- **Assertion 7 is genuinely falsifiable.** The page-1 body advertises `/v1/billing/meters/mtr_served_by_stripe/event_summaries` — a path the resource module would never construct from `@meter_id`. A page-2 request rebuilt from `path(meter_id)` fails there and nowhere else. Serving the same path in both would have asserted nothing.
- **Assertion 6 exercises the strip rather than its absence.** Page 1's opts supply `idempotency_key: "idem_123"` and the test asserts the header **is** present on page 1 before asserting it is gone on page 2. `Client.resolve_idempotency_key/2` honours a user-supplied key even on a GET, so this genuinely puts a key on the wire for `List` to delete.
- **Assertion 5 is checked twice** — once with the account on the client (`stripe_account: "acct_connected"`) and once as a per-request override in `opts`. Both resolve through `Keyword.get(req.opts, :stripe_account, client.stripe_account)`, and `List` forwards `_opts` wholesale, so both had to be shown rather than assumed.
- **Assertion 8 is split in two.** One test asserts the raise; a second proves the raise comes from the *second* fetch by threading `Stream.each(&send(parent, {:emitted, &1.id}))` into the pipeline and using `assert_received` afterwards. The send is synchronous and in-process, so this adds no timing dependency under `async: true`.

## Mutation-check results

Both mutations were applied to `lib/lattice_stripe/list.ex`, run, and reverted. `git diff --quiet lib/lattice_stripe/list.ex` exits 0 and `git status --porcelain lib/` is empty at both commits.

### Mutation 1 — base-params preservation (T-64-03, D-30 assertion 2)

| | |
|---|---|
| **Mutation** | `list.ex:246`: `base_params = Map.drop(list._params, [...])` → `base_params = Map.drop(%{}, [...])` |
| **Full-suite result** | **2279 tests, 3 failures** |
| **Failing test in this file** | `test stream!/4 request scoping on pages the caller never constructs page 2 preserves customer, start_time, end_time and value_grouping_window` — **the only failure in this file** |
| **Other failures** | `LatticeStripe.Entitlements.ActiveEntitlementStreamTest` — *page 2 preserves the customer filter* (Phase 63's own mutation-checked twin, STATE `[63-02]`); `LatticeStripe.Entitlements.FeatureTest` — *Feature.stream!/3 carries the archived filter onto every page it fetches* |

The blast radius is exactly the three tests in the repository that assert filter survival across a page seam, and no others. That is as narrow as this mutation can be — every other pagination test in the suite passes with the filters silently dropped, which is precisely why this assertion has to exist.

### Mutation 2 — cursor derived before typing (T-64-14, D-30 assertion 9)

| | |
|---|---|
| **Mutation** | `list.ex:129`: `_last_id: last_item_id(items)` → `_last_id: last_item_id(Enum.map(items, &LatticeStripe.Billing.MeterEventSummary.from_map/1))` |
| **Why this shape** | `last_item_id/1` matches `%{"id" => id}` — a **string** key. Typing first produces structs whose id lives under the atom `:id`, so the match falls through to `nil` and the next request goes out with no cursor at all. Nothing raises. This is the D-05 ordering failure, reproduced exactly. |
| **This file** | **15 tests, 3 failures** — `the starting_after cursor is derived from the raw maps before typing` (the named assertion), plus `page 2 request uses starting_after from the LAST id of page 1` and the four-filter test, both of which also assert the cursor value |
| **Full suite** | 2279 tests, 14 failures — every forward-cursor assertion in the repository |

The mutation had to live in `list.ex` rather than `meter_event_summary.ex`: 64-05 owns that file in this wave, and in any case the derivation being tested is `List.from_json/3`'s, not the resource module's. `MeterEventSummary` was read but never written.

## Deviations from Plan

### 1. [Rule 3 - Blocking] `deps/` was absent in a fresh worktree

- **Found during:** first `mix test` run, before Task 1's verification
- **Issue:** `mix test` refused to run — fourteen dependencies "not available".
- **Fix:** ran `mix deps.get`, which the phase gates explicitly permit when `deps/` is missing.
- **`mix.lock` is byte-identical afterward.** SHA-256 `508562a3cd1f8dbd98726bead3a5172ed3080e6f59f0c1acbc58da702ab40b48` before and after; `git status --porcelain` shows no change to it. No dependency added, updated or substituted. T-64-SC holds.
- **Files modified:** none

### 2. [Documented judgment] 15 tests, not the 12 the acceptance criterion floors at

Three tests exist beyond the nine D-30 assertions and the two unclassified edges: a two-page typed-struct enumeration case (the plain MTR-02 truth, separated from the ordering case so a re-sort bug and a decode bug fail different tests), the per-request `stripe_account` override, and the emitted-before-error case. All are above the plan's `>= 12` floor, none duplicate an existing assertion.

### 3. [Documented judgment] The window uses UTC-day-aligned timestamps, not the sibling file's

`meter_event_summary_test.exs` uses `1_753_620_000`/`1_753_706_400`, which are minute-aligned but **not** day-aligned — and several tests here pass `value_grouping_window: "day"`, which Stripe requires day-aligned. This file uses `1_753_574_400`/`1_753_660_800` (= `20296 * 86_400` and one day later) so the fixture window is one Stripe would actually accept. No assertion depends on the choice; it avoids teaching a misaligned window in the file that most reads like a usage example.

No other deviations. No auto-fixed bugs, no architectural changes, no authentication gates.

## Verification

All gates run at the final test commit `1a021c1`. `mix ci` was **not** run — per the phase gates it is red at clean HEAD on 42 pre-existing ExDoc warnings.

| Gate | Result |
|------|--------|
| `mix test test/lattice_stripe/billing/meter_event_summary_pagination_test.exs` | **15 tests, 0 failures** (floor: >= 12) |
| `mix test` | **2279 tests, 0 failures, 1 skipped** (204 excluded) — baseline 2264; threshold was >= 2188 |
| `git diff --quiet lib/lattice_stripe/list.ex` | exit 0 — no mutation committed |
| `git status --porcelain lib/` | empty at commit time |
| `mix format --check-formatted` | exit 0 |
| `mix credo --strict` | 2274 mods/funs, **no issues** |
| `mix compile --force --warnings-as-errors` | exit 0 |
| `mix docs` | exit 0, **42 warnings** (== baseline, never up) |
| `grep -c 'mtrusg_'` | 40 (floor: >= 2) |
| `grep -c 'Stream.take'` | 2 (floor: >= 1) |
| `grep -c 'value_grouping_window'` | 7 (floor: >= 2) |
| `grep -ci 'stripe-account'` | 6 (floor: >= 1) |
| `grep -ci 'idempotency'` | 5 (floor: >= 1) |

The pre-existing retry-telemetry flake at `test/lattice_stripe/client_test.exs:912` did not fire in any of the four full-suite runs (two clean, two under mutation).

### Success criteria

- [x] All nine D-30 assertions are present and green.
- [x] Assertions 2 and 9 are mutation-checked, with results and exact test names recorded above.
- [x] `lib/lattice_stripe/list.ex` is byte-identical to its pre-plan state.
- [x] No pagination claim in this plan rests on stripe-mock — every assertion is made against a Mox transport.

## Known Stubs

None. No placeholder values, no TODO/FIXME, no skipped tests introduced. The one skipped test in the suite is pre-existing and unrelated.

## Threat Flags

None. This plan added no library code, no endpoint, no auth path, no file access and no schema change.

Mitigation status for the threats this plan owns: **T-64-02** (dropped `stripe-account` on page 2) — mitigated, two tests. **T-64-03** (dropped `customer` filter) — mitigated and mutation-proved. **T-64-04** (idempotency-key replay on paginated GETs) — mitigated, with page 1 supplying a key so the strip is exercised. **T-64-14** (nil cursor truncating at page 1) — mitigated and mutation-proved. **T-64-07** (unbounded fetching) — mitigated: `Stream.take(1)` over a two-page stream is proven to make exactly one call, so the moduledoc's memory guidance is actionable. **T-64-SC** — accepted and held: zero packages installed, `mix.lock` byte-identical.

## For Next Phase

- **64-09 (artifact inventory)** — the new file is `test/lattice_stripe/billing/meter_event_summary_pagination_test.exs`, module `LatticeStripe.Billing.MeterEventSummaryPaginationTest`, 15 tests. Suite total at this commit is 2279.
- **Anyone touching `LatticeStripe.List`** — two test names in this file are load-bearing proof and must not be renamed or merged: *page 2 preserves customer, start_time, end_time and value_grouping_window* and *the starting_after cursor is derived from the raw maps before typing*. Both carry the instruction inline.
- **64-05 (GUARD-04)** — no interaction. This file asserts nothing about window alignment and passes both before and after `check_summary_window!/2` lands, provided the guard keeps accepting day-aligned windows with `value_grouping_window: "day"` — which is what `@bucketed_window` here uses.

## Self-Check: PASSED

- `test/lattice_stripe/billing/meter_event_summary_pagination_test.exs` — FOUND
- `.planning/phases/64-meter-event-summary-reads/64-06-SUMMARY.md` — FOUND
- Commit `0ffdf8a` (Task 1) — FOUND
- Commit `1a021c1` (Task 2) — FOUND
- `lib/lattice_stripe/list.ex` unmodified — VERIFIED (`git diff --quiet` exit 0)

## TDD Gate Compliance

This plan is **test-only by design** — its `files_modified` lists exactly one test file and its objective is proof, not surface. The RED/GREEN/REFACTOR cycle does not apply: the behavior under test shipped in 64-03, so a RED phase would require breaking library code this plan is prohibited from touching. The equivalent rigor was supplied instead by the two **mutation checks**, which is a stronger form of the same evidence — each named test was shown to fail when the behavior it protects was broken, then shown to pass again once reverted. Both `test(64-06)` commits are correctly typed; no `feat` commit exists because no feature was added.
