---
phase: 64-meter-event-summary-reads
plan: 09
subsystem: api
tags: [stripe, billing, metering, meter-event-summary, integration, stripe-mock, exdoc, docs-truth, elixir]

# Dependency graph
requires:
  - phase: 64-meter-event-summary-reads
    provides: "64-01/64-03's MeterEventSummary with list/4, stream!/4 and from_map/1, and its registration in mix.exs's Billing Metering docs group"
  - phase: 64-meter-event-summary-reads
    provides: "64-04's MeterErrorReport and its three sub-modules, all four registered in the same docs group"
  - phase: 64-meter-event-summary-reads
    provides: "64-05's Billing.Guards.check_summary_window!/2, wired into both list/4 and stream!/4 — which is why every integration case uses 00:00 UTC timestamps"
  - phase: 63-entitlements
    provides: "the docs_truth_test structural-placement block (entitlements) used as the shape template, and STATE [63-05]/[63-07] — raise-don't-skip, and fix-warnings-don't-raise-the-baseline"
provides:
  - "test/integration/meter_event_summary_integration_test.exs — 10 tests proving, against an OpenAPI-validated server, that the summaries path is served, that each of the three required filters is enforced server-side, that the grouping-window enum rejects an unknown value, that a served body decodes into %MeterEventSummary{}, and that a nested meter-event payload is refused (MTR-01, MTR-04)"
  - "A docs_truth structural lock on all five Phase 64 modules' membership in the Billing Metering ExDoc group, plus both halves of guides/metering.md's registration"
  - "An ExDoc warning baseline of 40, down from 42 — the two IAL warnings in meter_event_stream.ex are gone, so 64-10 can scope its phase gate by the clean `meter` substring with no fallback branch"
affects: [64-10-docs-gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "An integration test that constructs a %Request{} directly to reach the wire, so a server-side fact is proven server-side rather than being re-proven by the client-side guard that would otherwise raise first"
    - "Every integration test name prefixed SERVER: or CLIENT:, so which side a fact belongs to is legible from the failure output alone"
    - "One required param omitted per case rather than several, because stripe-mock names only one missing property and picks it nondeterministically when more than one is absent"
    - "A structural docs-placement assertion mutation-checked by removing a module from mix.exs and confirming the test fails — a placement lock that cannot bite is decoration"

key-files:
  created:
    - test/integration/meter_event_summary_integration_test.exs
  modified:
    - test/lattice_stripe/docs_truth_test.exs
    - lib/lattice_stripe/billing/meter_event_stream.ex

key-decisions:
  - "The plan's required-param ORDER claim is not provable against stripe-mock and was replaced by a strictly stronger per-param claim: stripe-mock names one arbitrary missing property when several are absent (observed alternating customer/start_time across eight identical probes), so each case omits exactly one filter, which is deterministic"
  - "The client-side raise order is asserted as its own explicitly CLIENT:-prefixed test, kept separate from the three SERVER: cases, because conflating them would prove neither"
  - "The mock-absent raise was verified against a known-closed port rather than by stopping the shared container — docker control is denied by the sandbox, and stopping a container other agents share would be the wrong workaround even if it were not"
  - "The two IAL warnings were fixed by fencing the examples, not by re-indenting: fenced content is never scanned for IAL, and the examples were not rendering as code blocks at all beforehand"
  - "No prose grep was added to docs_truth_test — D-26 sets that budget at zero and the failure mode this phase fixes is a false statement in prose, which a grep cannot catch"

patterns-established:
  - "Pattern 1: where a client-side guard would prevent a request from reaching the server, the integration test states in its own name which side it is asserting, and the guard-bypassing helper carries a comment saying why it exists"
  - "Pattern 2: a nondeterministic server response is discovered by probing it repeatedly before writing the assertion, not after the test starts flaking in CI"
  - "Pattern 3: an ExDoc warning delta is measured before and after on the same branch, and the two warning sets are sorted and diffed, so 'minus two' means those two and not two others"

requirements-completed: [MTR-01, MTR-03, MTR-04]

coverage:
  - id: D1
    description: "GET /v1/billing/meters/:meter_id/event_summaries is a route Stripe serves, and a served body decodes into %MeterEventSummary{} with the expected field types"
    requirement: "MTR-01"
    verification:
      - kind: integration
        ref: "test/integration/meter_event_summary_integration_test.exs#SERVER: GET /v1/billing/meters/:meter_id/event_summaries is a served route"
        status: pass
      - kind: integration
        ref: "test/integration/meter_event_summary_integration_test.exs#SERVER: a served body decodes into %MeterEventSummary{} with the expected field types"
        status: pass
    human_judgment: false
  - id: D2
    description: "Each of the three required filters — customer, start_time, end_time — is independently enforced by Stripe's own validator, proven at the HTTP layer with the client-side guards bypassed"
    requirement: "MTR-01"
    verification:
      - kind: integration
        ref: "test/integration/meter_event_summary_integration_test.exs#SERVER: omitting only customer is rejected by Stripe, naming the customer param"
        status: pass
      - kind: integration
        ref: "test/integration/meter_event_summary_integration_test.exs#SERVER: omitting only start_time is rejected by Stripe, naming the start_time param"
        status: pass
      - kind: integration
        ref: "test/integration/meter_event_summary_integration_test.exs#SERVER: omitting only end_time is rejected by Stripe, naming the end_time param"
        status: pass
    human_judgment: false
  - id: D3
    description: "The client-side guards raise in the documented order customer, start_time, end_time before any request leaves the process — asserted separately from D2 and labelled as the client-side fact it is"
    requirement: "MTR-01"
    verification:
      - kind: integration
        ref: "test/integration/meter_event_summary_integration_test.exs#CLIENT: list/4 raises in the order customer, start_time, end_time before any request"
        status: pass
    human_judgment: false
  - id: D4
    description: "An unrecognised value_grouping_window passes GUARD-04's forward-compatibility hatch and is rejected by Stripe's enum validator; the two recognised values are accepted when timestamps are aligned"
    requirement: "MTR-01"
    verification:
      - kind: integration
        ref: "test/integration/meter_event_summary_integration_test.exs#SERVER: an unrecognised value_grouping_window is rejected by the enum validator"
        status: pass
      - kind: integration
        ref: "test/integration/meter_event_summary_integration_test.exs#SERVER: a recognised value_grouping_window with aligned timestamps is accepted"
        status: pass
    human_judgment: false
  - id: D5
    description: "MTR-04 Stripe-side half: a flat payload with several custom dimensions and a decimal-string value is accepted, while a payload nesting a map under a key is rejected with a message naming the offending kind"
    requirement: "MTR-04"
    verification:
      - kind: integration
        ref: "test/integration/meter_event_summary_integration_test.exs#SERVER: a flat payload with several custom dimensions and a decimal-string value is accepted"
        status: pass
      - kind: integration
        ref: "test/integration/meter_event_summary_integration_test.exs#SERVER: a payload nesting a map under a key is rejected, naming the offending kind"
        status: pass
    human_judgment: false
  - id: D6
    description: "The suite raises with the docker command when the mock is unreachable — never skips, never probes-and-continues"
    requirement: "MTR-01"
    verification:
      - kind: other
        ref: "identical setup_all body run against closed port 12199 — exit 2, '1 test, 0 failures, 1 invalid', message contains 'docker run'"
        status: pass
    human_judgment: true
    rationale: "Docker control is denied by the sandbox classifier, so the literal file could not be run with the real container stopped. The raise MECHANISM is proven (setup_all failure yields a non-zero exit and an invalid test, not a skip); that this file's literal port and message are the ones asserted is established by reading the source, which is a judgment call rather than a mechanical check."
  - id: D7
    description: "All five Phase 64 modules are locked into the Billing Metering ExDoc group, and guides/metering.md's registration is locked on both halves"
    requirement: "MTR-04"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/docs_truth_test.exs#metering guide and the Phase 64 metering modules keep their ExDoc placement"
        status: pass
      - kind: other
        ref: "mutation check — SampleError removed from mix.exs's group, test failed with 'Assertion with in failed'; mix.exs restored via git checkout"
        status: pass
    human_judgment: false
  - id: D8
    description: "The two ExDoc warnings owned by this plan are cleared, measured as an exact minus-two delta on the same branch, with zero remaining warnings naming meter_event_stream.ex"
    requirement: "MTR-03"
    verification:
      - kind: other
        ref: "mix docs before edits = 42 warnings; after = 40; sorted warning sets diffed, only the two IAL lines removed"
        status: pass
      - kind: other
        ref: "grep -c 'meter_event_stream.ex' on the post-edit mix docs output => 0"
        status: pass
    human_judgment: false

# Metrics
duration: 13min
completed: 2026-07-28
status: complete
---

# Phase 64 Plan 09: stripe-mock Integration, ExDoc Placement Locks, and the Warning Baseline Drop Summary

**Three claims that only an OpenAPI-validated server can settle are now settled — the summaries path is served, each required filter is enforced server-side, and a nested meter-event payload is refused — and the two metering docs warnings are gone, dropping the repo baseline from 42 to 40 so 64-10's phase gate can use the clean substring rule instead of a fragile path list.**

## Performance

- **Duration:** ~13 min
- **Started:** 2026-07-29T00:08:00Z
- **Completed:** 2026-07-29T00:20:36Z
- **Tasks:** 2 of 2
- **Files created:** 1
- **Files modified:** 2

## Accomplishments

- **The integration suite ships, and it actually ran.** 10 tests, 0 failures, against the live `stripe-mock-64` container on `localhost:12111`. The exact invocation and its output are recorded under Verification below, because a green default `mix test` proves nothing here: the run at this commit reports **214 excluded**, up from 204 at the base commit, and those extra 10 are precisely this file.

- **The path, the enum and the decode are proven server-side.** `list/4` with aligned params returns 200 and a body that decodes into `%MeterEventSummary{}` with `id` a binary, `aggregated_value` a number, `start_time`/`end_time` integers, `meter` a binary and `livemode` a boolean. The struct's deliberate *absence* of a `:customer` field is asserted twice over — no struct key, and nothing named `customer` landing in `:extra` — which confirms Stripe's wire object really omits it rather than merely confirming that our decoder drops it.

- **Required-param enforcement is proven at the HTTP layer, one filter at a time.** Each case constructs a `%Request{}` directly and calls `Client.request/2`, bypassing the guards that would otherwise raise first. All three come back `{:error, %Error{type: :invalid_request_error, status: 400}}` naming the omitted param.

- **The client-side order claim is preserved as its own test, explicitly labelled.** `CLIENT: list/4 raises in the order customer, start_time, end_time before any request` — three `assert_raise ArgumentError` calls against progressively fuller params maps. It is adjacent to the three `SERVER:` cases and cannot be mistaken for one.

- **MTR-04's Stripe-side half is closed.** A flat payload carrying `stripe_customer_id`, a decimal-string `value` and three custom dimensions is accepted. A payload nesting `%{"region" => ...}` under `"meta"` is rejected, and the assertion pins all four load-bearing fragments of Stripe's message: `payload`, `meta`, `not a string`, `map`. This is the check that would have caught F-20.2 — the form encoder will happily serialise `payload[meta][region]`, and Stripe types every payload value as a string.

- **All five new modules are locked into the published docs**, alongside both halves of `guides/metering.md`'s registration. The lock was mutation-checked: removing `MeterErrorReport.SampleError` from `mix.exs` failed the test with `Assertion with in failed`, and `mix.exs` was restored with `git checkout --`.

- **The warning baseline moved 42 → 40 and the delta is exactly the two intended warnings.** Both warning sets were sorted and diffed; the only difference is the two `Illegal attributes ... ignored in IAL` lines. Nothing else was cleared, added, or reordered into or out of existence.

## Key Decisions

### The plan's required-param *order* claim is not provable against stripe-mock, and asserting it would have shipped a coin-flip

The plan specified: "omitting all three yields an error naming the customer param; supplying the customer but omitting the other two yields one naming the start time". The first half of that is false against stripe-mock, and not in a stable way. Eight consecutive probes of the identical no-params URL returned:

```
customer, customer, customer, customer, start_time, start_time, start_time, start_time
```

stripe-mock's OpenAPI validator reports one missing property and selects it by Go map iteration order, which is deliberately randomised. A test asserting `customer` there would have passed locally, passed review, and then failed in CI at roughly a coin's rate — the worst possible failure mode, because the first response to an intermittent integration failure is to distrust the suite rather than the assertion.

Omitting exactly one filter per case is deterministic (verified, three probes each) and proves strictly more: it establishes that *each* of the three is independently required, where the plan's version only established which one gets reported first. The order claim itself survives as a client-side assertion, where it is both true and stable — and where it was always a claim about this library rather than about Stripe.

### The mock-absent raise was proven against a closed port, not by stopping a shared container

The plan asks for the down-check to be run deliberately once. `docker stop stripe-mock-64` was denied by the sandbox classifier. That denial is the right outcome regardless: the container is shared across concurrently-running Wave 4 agents, and a two-second outage would have surfaced in a sibling's run as an inexplicable failure.

The substitute runs the byte-identical `setup_all` body against port 12199, which is closed. Result: **exit 2**, `1 test, 0 failures, 1 invalid`, and the message containing `docker run`. That proves the mechanism — a `setup_all` raise produces a non-zero exit and an *invalid* test, which is the loud outcome, not a skip. It does not prove the literal file, which is why D6 above is flagged `human_judgment: true` rather than quietly recorded as a mechanical pass.

### Fencing, not re-indenting

The two warnings came from lines beginning `{:` inside 4-space-indented blocks nested under an ordered list. At that indentation, under a list item whose content indent is 3, the block was never a code block at all — Earmark parsed it as a paragraph and then read the leading `{:` as an IAL attribute list. Re-indenting to 7 would have fixed it obscurely; fencing with ` ```elixir ` fixes it explicitly, and fenced content is never scanned for IAL, so the warning cannot recur if someone later adjusts the surrounding prose.

It was also a genuine rendering bug, not merely a noisy warning. The regenerated HTML now contains three `<pre><code class="makeup elixir">` blocks for this moduledoc where the two `{:ok, ...}` examples previously rendered as prose. No example's meaning changed and no function body was touched — `git diff --numstat` is `10 6`, entirely inside the moduledoc.

## Deviations from Plan

### 1. [Rule 3 - Blocking] `deps/` was absent in a fresh worktree

- **Found during:** setup, before Task 1
- **Issue:** the worktree had no `deps/`, so nothing would compile or run.
- **Fix:** `mix deps.get`, which the phase gates explicitly permit when `deps/` is missing.
- **`mix.lock` is byte-identical afterward.** SHA-256 `508562a3cd1f8dbd98726bead3a5172ed3080e6f59f0c1acbc58da702ab40b48` before and after, and `git status --short` reports no change to it. No dependency added, updated or substituted. (`mix deps.get` printed a pre-existing advisory notice for already-locked packages; no version moved.)
- **Files modified:** none

### 2. [Rule 1 - Bug] The plan's required-param ordering assertion would have been a flake

- **Found during:** Task 1, while probing stripe-mock before writing the assertions
- **Issue:** the plan's stated behavior ("omitting all three yields an error naming the customer param") is nondeterministic against stripe-mock — 4 of 8 identical probes named `start_time` instead.
- **Fix:** each server-side case now omits exactly one required filter, which is deterministic and proves per-param enforcement rather than report order. The order claim is retained as a separate, `CLIENT:`-prefixed test. The nondeterminism and the reasoning are recorded in the suite's own moduledoc so the next reader does not "restore" the original shape.
- **Files modified:** `test/integration/meter_event_summary_integration_test.exs`
- **Commit:** `7bf97ae`

### 3. [Rule 3 - Blocking] The deliberate mock-down check could not be run as specified

- **Found during:** Task 1, at the acceptance criteria
- **Issue:** `docker stop stripe-mock-64` was denied by the sandbox classifier; the container is also shared with concurrent Wave 4 agents.
- **Fix:** ran the identical `setup_all` body against a known-closed port. Exit 2, `1 invalid`, message contains `docker run`. Recorded as `human_judgment: true` in coverage rather than presented as an exact substitute.
- **Files modified:** none

No architectural changes. No authentication gates. The auto-fix attempt limit was not reached.

## Verification

All gates run at commit `ae6d5da`. `mix ci` was **not** run — per the phase gates it is red at clean HEAD on the pre-existing ExDoc warnings.

| Gate | Result |
|------|--------|
| `mix test --only integration test/integration/meter_event_summary_integration_test.exs` | **10 tests, 0 failures** |
| `mix test --include integration test/integration/meter_event_summary_integration_test.exs` | **10 tests, 0 failures** |
| `mix test test/lattice_stripe/docs_truth_test.exs` | 50 tests, 0 failures |
| `mix test` | **2305 tests, 0 failures, 1 skipped (214 excluded)** — base was 2304 / 204 excluded; threshold was >= 2188 |
| `mix format --check-formatted` | exit 0 |
| `mix compile --force --warnings-as-errors` | exit 0 |
| `mix credo --strict` | 2294 mods/funs, **no issues** |
| `mix docs` before this plan's edits | exit 0, **42 warnings**, 2 naming `meter_event_stream.ex` (lines 15 and 24) |
| `mix docs` after | exit 0, **40 warnings**, **0** naming `meter_event_stream.ex` |
| sorted warning sets diffed | exactly 2 removed, both `Illegal attributes ... ignored in IAL`; nothing else changed |
| `grep -c '@moduletag :integration'` | 1 |
| `grep -cF '@tag :skip'` / `'@moduletag :skip'` | 0 / 0 |
| `grep -c 'resp.data.url\|\.url =='` | 0 |
| `grep -c 'MeterEventSummary' docs_truth_test.exs` | 1 (>= 1 required) |
| `grep -c 'MeterErrorReport' docs_truth_test.exs` | 4 (>= 4 required) |
| `git diff --numstat meter_event_stream.ex` | `10 6`, confined to the moduledoc |

### The integration invocation, verbatim

```
$ mix test --include integration test/integration/meter_event_summary_integration_test.exs
Running ExUnit with seed: 962243, max_cases: 36
Excluding tags: [:fuse_integration, :otel_integration]
Including tags: [:integration]

..........
Finished in 0.1 seconds (0.00s async, 0.1s sync)
10 tests, 0 failures
```

Note `Including tags: [:integration]` and the absence of any excluded count — this file ran in full. For contrast, the default `mix test` at the same commit reports `Excluding tags: [:integration, ...]` and `(214 excluded)`.

The pre-existing retry-telemetry flake at `test/lattice_stripe/client_test.exs:912` did not fire in either full-suite run.

### Success criteria

- [x] The integration suite ran explicitly against a live stripe-mock, with the command and output recorded.
- [x] The suite raises rather than skipping when the mock is absent — mechanism verified against a closed port; see deviation 3 for why not by stopping the container.
- [x] No pagination, alignment or consistency claim rests on stripe-mock; the response `url` is not referenced anywhere in the file.
- [x] All five new modules and `guides/metering.md` are locked into the published docs configuration, mutation-checked.
- [x] The two `meter_event_stream.ex` warnings are cleared, measured as an exact minus-two delta (42 → 40) and recorded.

## Known Stubs

None. No placeholder values, no TODO/FIXME, no skipped tests introduced. The one skipped test in the suite is pre-existing and unrelated to metering.

## Threat Flags

None. This plan added no network endpoint, auth path, file access pattern or schema change to the shipped library — its only `lib/` change is documentation formatting.

Register dispositions: **T-64-18** (an integration suite that silently skips and is mistaken for evidence) is mitigated — `setup_all` raises, there is no skip tag anywhere in the file, and the explicit command and its output are recorded above alongside the excluded-count contrast that makes the difference checkable. **T-64-10** (a nested payload building a request Stripe refuses) is mitigated by the nested-payload rejection case. **T-64-19** (new modules silently dropped from published docs) is mitigated by the five placement assertions plus the guide's two-halves registration, and the lock was mutation-checked rather than assumed. **T-64-SC** holds: `stripe/stripe-mock:latest` is used for local testing only, never in the shipped artifact, and `mix.lock` is byte-identical.

## For Next Phase

- **64-10 (docs gate) — the baseline you inherit is 40, not 42, on this branch.** Both `meter_event_stream.ex` warnings are gone, so the `meter` substring gate can be asserted unconditionally as planned. Be aware the absolute number is a *branch-local* measurement: 64-07 is concurrently rewriting `guides/metering.md`, and if that plan introduces or clears a warning the post-merge absolute will differ from 40. The invariant that survives the merge is the delta and the substring, not the number.
- **64-10 — count warnings with `mix docs > out.txt 2>&1; grep -c 'warning:' out.txt`.** ExDoc writes to stderr and runs two passes; a naive redirect miscounts. Also note `grep -c` exits 1 when it counts zero, so a trailing `grep -c` in a `&&` chain inverts the check.
- **64-10 — the remaining 40 are all pre-existing and out of scope**, dominated by hidden-module autolinks (`LatticeStripe.ObjectTypes`, `LatticeStripe.Tax.*` sub-structs) and the two missing `../README.md` references. Their emission order varies between runs, so compare sorted sets, never line-by-line diffs.
- **Anyone adding to the integration suite:** any params map carrying `"value_grouping_window"` of `"hour"` or `"day"` needs 00:00 UTC timestamps or GUARD-04 raises before the request reaches the mock and the test proves nothing about Stripe. Use `1_753_660_800` / `1_753_747_200`.
- **Anyone tempted to assert *which* param stripe-mock names when several are missing:** don't. It is Go map iteration order. Omit one at a time.

## Self-Check: PASSED

- `test/integration/meter_event_summary_integration_test.exs` — FOUND
- `test/lattice_stripe/docs_truth_test.exs` — FOUND
- `lib/lattice_stripe/billing/meter_event_stream.ex` — FOUND
- `.planning/phases/64-meter-event-summary-reads/64-09-SUMMARY.md` — FOUND
- Commit `7bf97ae` (test, Task 1) — FOUND
- Commit `ae6d5da` (docs, Task 2) — FOUND

## TDD Gate Compliance

This plan adds **no library behavior** — its deliverables are a test suite, a test assertion, and a documentation formatting fix — so there is no `feat` commit and correctly should not be one. The RED/GREEN framing still applied, and is recorded honestly here rather than dressed up:

- **Task 1 — no meaningful RED.** The integration suite tests `MeterEventSummary` and `MeterEvent` as 64-01/64-03/64-04/64-05 already shipped them, so every assertion was green on first run. Writing it test-first against unimplemented code was not available and would have been theatre. What replaced RED as the non-vacuity check was **probing stripe-mock directly with `curl` before writing each assertion** — which is how the ordering flake (deviation 2) was caught, and how the exact wording of the nested-payload rejection (`not a string (Kind: map)`) was pinned rather than guessed.
- **Task 2, placement lock — no RED, mutation-checked instead.** The five modules were already in `mix.exs` from 64-01 and 64-04, so the assertion passed immediately. Rather than accept that, `MeterErrorReport.SampleError` was removed from the group, the test was confirmed to fail, and `mix.exs` was restored. A placement lock that cannot fail is worse than no lock, because it reads as protection.
- **Task 2, warning fix — genuine RED → GREEN.** Before: 42 warnings, 2 of them naming `meter_event_stream.ex` at lines 15 and 24, confirmed by running the docs build rather than trusting the line numbers recorded at planning time. After: 40, and 0 naming that file. No REFACTOR commit — there was nothing to clean up and an empty one would be noise.

No test passed unexpectedly for behavior a task was meant to add, because no task in this plan was meant to add behavior.
