---
phase: 64-meter-event-summary-reads
plan: 02
subsystem: metering
tags: [encoder, drift, tests, documentation-truth, MTR-04, D-20]
requires:
  - LatticeStripe.FormEncoder (unchanged, characterized)
  - LatticeStripe.Billing.MeterEvent.create/3 (unchanged, characterized)
  - LatticeStripe.Drift.known_fields_for/1
provides:
  - "Drift.parse_known_fields/1 parses both ~w[] and ~w() delimiter forms"
  - "Executable proof of the six payload-contract facts 64-07's prose will publish"
  - "Executable proof of the float-cliff boundary at 1.0e-5, both sides"
  - "Structural refutation of Billing.Meter.event_summaries/3,4"
affects:
  - "64-07 (guides/metering.md rewrite) — every sentence it writes about payload encoding now has a backing assertion"
  - "mix drift — 18 lib/ modules stop reporting every field as a spurious addition"
tech-stack:
  added: []
  patterns:
    - "refute function_exported? as the only public-surface enforcement (no Dialyzer)"
    - "Mox-at-Transport req.body assertion for wire-level proof"
    - "characterization tests as the lock for published prose (D-26: tests, not greps)"
key-files:
  created:
    - .planning/phases/64-meter-event-summary-reads/deferred-items.md
  modified:
    - lib/lattice_stripe/drift.ex
    - test/lattice_stripe/drift_test.exs
    - test/lattice_stripe/form_encoder_test.exs
    - test/lattice_stripe/billing/meter_event_test.exs
    - test/lattice_stripe/billing/meter_test.exs
decisions:
  - "Widened the Drift regex with a delimiter character class rather than a two-group alternation, so the split-and-MapSet logic and the nil fallback stayed untouched (plan constraint)"
  - "Kept the production comment in drift.ex to one line to hold the diff at the plan's 2-changed-line ceiling; the rationale lives in the named regression test instead"
  - "Added the Mox-at-Transport scaffolding to meter_event_test.exs — the plan assumed it already existed there; it did not"
  - "form_encoder.ex and mix.lock deliberately untouched (D-22, D-23)"
metrics:
  duration: ~13 min
  tasks: 2
  files-changed: 6
  tests-added: 11
  completed: 2026-07-28
status: complete
---

# Phase 64 Plan 02: MTR-04 Encoder Truths + Drift Regex Fix Summary

MTR-04 turned from a documentation claim into eleven executable assertions, and the D-20 known-fields regex bug found in passing is fixed with a named regression lock.

## What Was Built

### Task 1 — Drift known-fields regex (commit `23c1771`)

`Drift.parse_known_fields/1` matched `~r/@known_fields\s+~w\[([^\]]+)\]/s` — square brackets only. 85 files in `lib/` use that form; **18 use `~w(...)`**, including `lib/lattice_stripe/billing/meter.ex:43`. Those 18 fell through to the `nil ->` clause, returned an empty `MapSet`, and therefore produced a drift entry claiming **every field on the object was a new addition** — a silent miscount in the tool whose entire job is catching drift.

The fix is one line: a delimiter character class rather than a hard-coded pair.

```elixir
case Regex.run(~r/@known_fields\s+~w[\[(]([^\])]+)[\])]/s, content) do
```

A two-group alternation was rejected because non-participating capture groups would have forced a change to the `case` clause below it — which the plan explicitly fenced. The character class keeps a single capture group, so the split-and-MapSet logic and the `nil ->` fallback are byte-identical.

`git diff --numstat lib/lattice_stripe/drift.ex` → `2 1` (one regex line, one comment line), inside the plan's ceiling.

Two tests were added to the existing `known_fields_for/1` describe block. The load-bearing one is named `"extracts @known_fields from the parenthesised ~w() form (D-20 regression lock)"` and asserts `Billing.Meter` parses to a non-empty set containing `id`, `display_name`, `event_name`. Narrowing the regex fails exactly that test — verified by running it RED before the fix (`Expected false or nil, got true` on `refute Enum.empty?(fields)`, with `MapSet.new([])`). The second test pins `TransferReversal`'s bracket form so the previously-working path cannot regress.

### Task 2 — the MTR-04 encoder truths (commit `e6131c5`)

Nine tests in `test/lattice_stripe/form_encoder_test.exs` (27 → **36**, above the plan's ≥34 floor), in two new describe blocks carrying a header comment stating that breaking one of them does not merely change behavior — it makes a shipped, published sentence false.

**Payload contract block:**

| Fact | Assertion |
|------|-----------|
| No allowlist | `region` / `sku` / `tenant_tier` + `value` produce an exact 4-pair body; none shares a prefix with `value`, so a whitelist would visibly drop them |
| Decimals never rounded | a 36-significant-digit decimal string encodes character-for-character |
| Integers safe on v1 | `%{"value" => 5}` and `%{"value" => "5"}` are byte-identical — this is the assertion that makes the guide's shipped pitfall #4 provably wrong |
| nil vanishes | `%{"a" => nil, "b" => "1"}` → `"b=1"`; a zero must be sent as the string `"0"` |
| Purity | encoding the same map twice returns equal binaries |
| UTF-8 backstop | `région_🌍` / `café_東京` reassemble byte-identically after `URI.decode_www_form/1` |

**Float hazard block** — both sides of the cliff, so the guide's warning cannot silently become false:

- `encode(%{"v" => 0.0001}) == "v=0.0001"` (below)
- `encode(%{"v" => 0.00001}) == "v=1.0e-5"` (at)
- `encode(%{"v" => 0.1 + 0.2}) == "v=0.30000000000000004"` — the encoder never repairs what float arithmetic already did, distinct from the decimal-string truth which says it never computes in the first place

**Wire-level pass-through** (`meter_event_test.exs`): a Mox-at-Transport expectation asserts all four payload keys appear in `req.body` for `MeterEvent.create/3`. Nothing between the caller and the wire filters payload keys.

**Surface refutation** (`meter_test.exs`): `refute function_exported?(Meter, :event_summaries, 3)` and arity 4, with the stripe-java#1852 provenance recorded in a comment.

Every expected value above was re-derived by direct execution against HEAD via `mix run -e` **before** being written into an assertion, per the plan's standing re-verify instruction — none was transcribed from a planning document.

## Key Decisions

1. **Character class over alternation** for the regex widening — preserves the single capture group, so the code below the `Regex.run/2` call is untouched.
2. **One-line production comment** in `drift.ex` — the full D-20 rationale lives in the test comment instead, keeping the production diff at the plan's stated ceiling. The test is the enforcement; the comment is only a pointer.
3. **`form_encoder.ex` and `mix.lock` untouched**, verified by an empty `git diff --stat`. D-23's float patch stays rejected and blocked on O-01; these tests lock current behavior precisely so a future decision to change it must be deliberate and tested.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Dependencies absent in the fresh worktree**
- **Found during:** Task 1, first `mix test` run
- **Issue:** the worktree had no `deps/`; `mix test` refused to run with "Unchecked dependencies for environment test".
- **Fix:** `mix deps.get`, restoring the versions already pinned in `mix.lock`. **No package was added, removed or bumped** — `git status` after the fetch showed only the test file I had edited, and `mix.lock` is byte-identical, satisfying the plan's prohibition.
- **Files modified:** none
- **Commit:** n/a (no tracked change)

**2. [Rule 3 — Blocking] `meter_event_test.exs` had no Mox setup to reuse**
- **Found during:** Task 2
- **Issue:** the plan's `read_first` directed me to "the existing Mox-at-Transport setup for `create/3`" in that file. There is none — the file had no `import Mox`, no `import LatticeStripe.TestHelpers`, and no transport-level test at all. Its `create/3` coverage is `from_map/1` decoding plus two pre-network `ArgumentError` cases using a hand-built `minimal_client/0`.
- **Fix:** added `import Mox` / `import LatticeStripe.TestHelpers` at module level and `setup :verify_on_exit!` scoped to the new describe block, mirroring the house pattern in `transfer_reversal_test.exs:19-32` (`test_client/0` + `expect(LatticeStripe.MockTransport, :request, fn req -> ... end)` + `ok_response/1`).
- **Files modified:** `test/lattice_stripe/billing/meter_event_test.exs`
- **Commit:** `e6131c5`

## Deferred Issues

**Pre-existing flaky test, out of scope — logged to `deferred-items.md`, not fixed.**

`test/lattice_stripe/client_test.exs:912` — *"request/2 retry telemetry stop event metadata includes attempts and retries counts"* — intermittently fails `assert metadata.attempts == 2` with `left: 1`. Reproduced twice across roughly 145 full-suite runs (`mix test --repeat-until-failure 60` and `80`), i.e. about 1 in 20.

Scope judgment: this plan touches `lib/lattice_stripe/drift.ex` (a regex consumed only by the drift mix task) and four test files. Nothing here goes near the client retry or telemetry paths. The likely cause is a globally-attached `:telemetry` handler in an `async: true` test receiving a stop event emitted by a different test's request. Per the scope-boundary rule it was logged and left alone.

## Verification

| Gate | Result |
|------|--------|
| `mix test` (4 target files) | 103 tests, 0 failures |
| `mix test` (full suite) | **2201 tests, 0 failures, 1 skipped (204 excluded)** — baseline 2188, +13 |
| `mix format --check-formatted` | exit 0 |
| `mix compile --warnings-as-errors` | exit 0 |
| `mix credo --strict` | 2225 mods/funs, no issues |
| `git diff --stat lib/lattice_stripe/form_encoder.ex mix.lock` | empty |
| `mix test test/lattice_stripe/form_encoder_test.exs` | 36 tests (floor was 34) |

`mix ci` was deliberately not run as a gate — it is RED at clean HEAD on 42 pre-existing ExDoc warnings unrelated to this phase, per the phase's differential-gate posture.

Acceptance criteria re-confirmed by direct execution:

- `Drift.known_fields_for(LatticeStripe.Billing.Meter)` → non-empty set containing `event_name`
- `Drift.known_fields_for(LatticeStripe.TransferReversal)` → set containing `amount`
- `FormEncoder.encode(%{"v" => 0.00001})` → `"v=1.0e-5"`
- `FormEncoder.encode(%{"v" => 0.0001})` → `"v=0.0001"`
- `FormEncoder.encode(%{"v" => 0.1 + 0.2})` → `"v=0.30000000000000004"`
- `encode(%{"payload" => %{"value" => 5}}) == encode(%{"payload" => %{"value" => "5"}})` → `true`
- `FormEncoder.encode(%{"a" => nil, "b" => "1"})` → `"b=1"`
- `function_exported?(LatticeStripe.Billing.Meter, :event_summaries, 3)` and `4` → `false`

## Known Stubs

None. This plan added no placeholder values, no TODO markers and no unwired components. Both tasks shipped complete behavior with passing verification.

## Threat Flags

None. No new network endpoint, auth path, file access pattern or schema at a trust boundary was introduced. T-64-09 (float stringification silently altering a billed value) is **mitigated as planned** — the exponent-form output is now locked by assertions on both sides of the `1.0e-5` threshold, so a change in stringification breaks a named test rather than a customer's bill. No packages were installed, so T-64-SC's premise holds.

## Notes for the Next Phase

- **64-07 can now write its prose against a live contract.** Each row of the payload-contract table above is a test; if 64-07 states something the encoder does not do, the sentence and the assertion will disagree and one of them is wrong.
- **The float cliff is asserted at both `0.0001` and `0.00001`.** 64-07's warning must place the threshold exactly there — one decimal place from values people bill on.
- **O-01 remains open and must not be claimed either way.** Whether Stripe's parser accepts `1.0e-5` as a `payload[value]` is unverified; the guide's wording should stay "do not rely on it either way", which stays correct under all three possible outcomes.
- `mix drift` output will change for the 18 previously-unparsed modules. Anyone comparing drift output against a pre-`23c1771` run should expect those spurious "every field is an addition" entries to disappear.

## Self-Check: PASSED

Files verified present:
- `lib/lattice_stripe/drift.ex` — FOUND (modified)
- `test/lattice_stripe/drift_test.exs` — FOUND (modified)
- `test/lattice_stripe/form_encoder_test.exs` — FOUND (modified)
- `test/lattice_stripe/billing/meter_event_test.exs` — FOUND (modified)
- `test/lattice_stripe/billing/meter_test.exs` — FOUND (modified)
- `.planning/phases/64-meter-event-summary-reads/deferred-items.md` — FOUND (created)

Commits verified in `git log`:
- `23c1771` — FOUND
- `e6131c5` — FOUND
