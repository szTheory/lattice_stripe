---
phase: 64-meter-event-summary-reads
plan: 04
subsystem: api
tags: [stripe, metering, webhooks, v2-events, thin-events, value-objects, exdoc]

# Dependency graph
requires:
  - phase: 64-01
    provides: "MeterEventSummary as a flat depth-2 module, its from_map/1 + :extra conventions, and the D-01 wire-named naming decision this plan mirrors"
  - phase: 64-02
    provides: "Drift.parse_known_fields/1 regex fix, which makes @known_fields drift checks genuinely live rather than vacuous"
provides:
  - "LatticeStripe.Billing.MeterErrorReport — the typed data payload of v1.billing.meter.error_report_triggered, flat at depth 2"
  - "MeterErrorReport.Reason / .ErrorType / .SampleError — depth-3 value objects giving every nesting level a named type"
  - "from_event/1 (primary, populates :meter from the event envelope) and from_map/1 (low-level, leaves :meter nil)"
  - "LatticeStripe.Test.Fixtures.Metering.MeterErrorReport — basic/1, event/1, no_meter_found_event/1, meter_id/0, seeded from the verbatim published payload"
  - "A refutation lock proving the object registry structurally cannot reach this payload"
affects: [64-07, 64-08, 65-object-types]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Typed value-object nesting for a non-resource payload: flat depth-2 parent, depth-3 sub-structs owning no %Request{}"
    - "Empty-list-never-nil contract on every nested array decode branch"
    - "Constructor asymmetry as an asserted contract (from_event/1 fills :meter, from_map/1 provably cannot)"

key-files:
  created:
    - lib/lattice_stripe/billing/meter_error_report.ex
    - lib/lattice_stripe/billing/meter_error_report/reason.ex
    - lib/lattice_stripe/billing/meter_error_report/error_type.ex
    - lib/lattice_stripe/billing/meter_error_report/sample_error.ex
    - test/lattice_stripe/billing/meter_error_report_test.exs
  modified:
    - mix.exs
    - test/support/fixtures/metering.ex
    - test/lattice_stripe/object_types_test.exs

key-decisions:
  - "RESEARCH assumption A3 SETTLED against the live reference: validation_start/validation_end are RFC3339 strings ('2024-09-26T17:46:10.000Z'), not Unix integers. Struct types, timestamp assertions and the moduledoc NOTE all stand as planned — no reversal was needed."
  - "from_event/1 raises a directive ArgumentError when the event carries no data, instead of letting a struct update produce a bare BadMapError. That is the exact signature of passing a delivered webhook body rather than a fetched event — the trap the moduledoc leads with."
  - "The ObjectTypes doc reference was written as plain prose rather than a backticked `Module.fun/arity` link, because LatticeStripe.ObjectTypes is @moduledoc false and any autolink to it adds an ExDoc warning."
  - "code stays a String.t() at every level; no atomization anywhere, enforced by a negative grep and an is_binary/1 design assertion."
  - "The fixture keeps every published id, code, message, identifier and timestamp verbatim and documents in-file exactly which two values were extended (a second sample error, a second error type) and why."

patterns-established:
  - "Depth-3 value objects follow value_settings.ex exactly: moduledoc, @type t, defstruct, @spec, from_map(nil) first, then the is_map/1 clause, no %Request{}, no known-fields attribute"
  - "Nested array fan-out returns [] from its catch-all clause rather than nil, so callers comprehend without a nil guard — deliberately diverging from Tax.Calculation's nil-returning equivalent"
  - "A payload with no object key gets a refutation test in object_types_test.exs rather than a registry row, so the structural exclusion cannot be quietly undone"

requirements-completed: [MTR-03]

coverage:
  - id: D1
    description: "MeterErrorReport.from_event/1 decodes a fetched %Event{} into a fully typed struct whose reason.error_types is a list of %ErrorType{} each holding a list of %SampleError{}"
    requirement: "MTR-03"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_error_report_test.exs#from_event/1 lifts the meter id from the event's related object"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_error_report_test.exs#from_map/1 navigates fully typed all the way down to a request identifier"
        status: pass
    human_judgment: false
  - id: D2
    description: "The struct carries four data fields — developer_message_summary, reason, validation_start, validation_end (N-01) — with the timestamps as binaries, not integers"
    requirement: "MTR-03"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_error_report_test.exs#from_map/1 decodes all four data fields from the published payload"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_error_report_test.exs#from_map/1 validation timestamps round-trip as binaries, not Unix integers"
        status: pass
    human_judgment: false
  - id: D3
    description: "Constructor asymmetry is a contract: from_event/1 populates :meter from related_object.id while from_map/1 leaves it nil, and from_event/1 tolerates a wholly absent related_object (the no_meter_found shape)"
    requirement: "MTR-03"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_error_report_test.exs#from_map/1 leaves :meter nil — the meter id is not in data (asserted contract)"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_error_report_test.exs#from_event/1 tolerates a wholly absent related_object — the no_meter_found shape"
        status: pass
    human_judgment: false
  - id: D4
    description: "SampleError.request_identifier resolves from data.reason.error_types[].sample_errors[].request.identifier — the join key back to the failing MeterEvent.create/3 call — and also from the alternate idempotency_key spelling"
    requirement: "MTR-03"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_error_report_test.exs#SampleError.from_map/1 resolves error_message and the join key from request.identifier"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_error_report_test.exs#SampleError.from_map/1 falls back to the alternate idempotency_key spelling under request"
        status: pass
    human_judgment: false
  - id: D5
    description: "Every nested-decode path is total: nil reason yields nil, absent error_types yields [], absent sample_errors yields [], and error_count 900 with an empty sample list still decodes"
    requirement: "MTR-03"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_error_report_test.exs#ErrorType.from_map/1 decodes the high-volume shape: error_count 900 with an empty sample list"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_error_report_test.exs#Reason.from_map/1 yields the empty list — not nil — when error_types is absent"
        status: pass
    human_judgment: false
  - id: D6
    description: "code stays a String.t() — never atomized — and the struct has no :id, :object or :livemode"
    requirement: "MTR-03"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_error_report_test.exs#from_map/1 code decodes as a String — the enum is open and must never be atomized"
        status: pass
      - kind: other
        ref: "grep -v '^\\s*#' lib/lattice_stripe/billing/meter_error_report/error_type.ex | grep -c 'to_atom' => 0"
        status: pass
    human_judgment: false
  - id: D7
    description: "ObjectTypes carries no billing.meter_error_report key and maybe_deserialize/1 returns this payload unchanged; object_types.ex is untouched"
    requirement: "MTR-03"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/object_types_test.exs#carries no billing.meter_error_report key — the dispatch cannot reach it"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/object_types_test.exs#returns the meter error report payload unchanged — it has no object key"
        status: pass
      - kind: other
        ref: "git diff --stat lib/lattice_stripe/object_types.ex => empty"
        status: pass
    human_judgment: false
  - id: D8
    description: "The four modules are published in HexDocs under the Billing Metering group without adding an ExDoc warning"
    requirement: "MTR-03"
    verification:
      - kind: other
        ref: "mix docs => exit 0, 42 warnings (baseline), 0 naming any meter_error_report file"
        status: pass
    human_judgment: false
  - id: D9
    description: "The published moduledoc prose is correct and useful to an adopter — that fetch_event/3 is mandatory, that the registry cannot reach this payload, that a raw inspect emits idempotency keys, and that the default auto-generated idempotency key joins to nothing"
    verification: []
    human_judgment: true
    rationale: "Prose accuracy and pedagogical value cannot be asserted by a test. This plan exists partly because two shipped guides teach a handler that cannot work; the replacement prose needs a human read before it becomes a published semver-adjacent contract at the v1.10 tag."

# Metrics
duration: 21min
completed: 2026-07-28
status: complete
---

# Phase 64 Plan 04: MeterErrorReport Typed Decode Summary

**The `v1.billing.meter.error_report_triggered` payload typed end to end across four modules, so an operator can read which meter, which window, which error codes and which failing request's idempotency key off a struct instead of a nested raw map.**

## Performance

- **Duration:** 21 min
- **Started:** 2026-07-28T23:27:00Z
- **Completed:** 2026-07-28T23:48:00Z
- **Tasks:** 3
- **Files modified:** 8 (5 created, 3 modified)

## Accomplishments

- **Four modules give every level of the payload a name.** `MeterErrorReport` flat at depth 2 (because it is *not a resource at all* — no endpoint, no id, no object string), with `Reason`, `ErrorType` and `SampleError` at depth 3 owning no `%Request{}`. Raw-map access to this payload is the exact shape that produced the two broken guide snippets 64-07 and 64-08 repair.
- **The join key is reachable and documented.** `SampleError.request_identifier` resolves from `data.reason.error_types[].sample_errors[].request.identifier`, tolerating the alternate `idempotency_key` spelling. Its moduledoc states the trap plainly: `Client` auto-generates an `idk_ltc_`-prefixed UUID for POSTs when none is supplied, so by default this field joins to nothing the adopter owns — and it disambiguates against the event's own near-identically named `reason.request.idempotency_key`, which is a different field five levels away.
- **Constructor asymmetry is an asserted contract, not an accident.** `from_event/1` lifts `:meter` from `related_object.id` and is nil-safe for the sibling `no_meter_found` event that carries no related object at all; `from_map/1` provably leaves `:meter` nil, and a test asserts that rather than observing it.
- **The payload was re-verified against the live reference and the open question closed.** RESEARCH flagged assumption A3 (are the validation timestamps strings or integers?) at medium confidence. The published example carries `"validation_start": "2024-09-26T17:46:10.000Z"` — RFC3339 strings. No struct type, assertion or moduledoc note had to reverse.
- **The registry's structural gap is locked.** `object_types.ex` is untouched, and two tests assert both that no `billing.meter_error_report` key exists and that `maybe_deserialize/1` hands this payload back unchanged — so Phase 65's exclusion cannot be quietly undone.

## Task Commits

1. **Task 1: The three depth-3 value objects, built leaf-first** — `fceeb81` (test, RED) → `e318e5e` (feat, GREEN)
2. **Task 2: The MeterErrorReport parent, from_event/1, the fixture, and ExDoc registration** — `17e8a5f` (test, RED) → `fc3b1d9` (feat, GREEN)
3. **Task 3: Lock the surface shape and the registry's structural gap** — `00cbcc7` (test)

No REFACTOR commits were needed — no cleanup was warranted after either GREEN.

## Files Created/Modified

**Created**
- `lib/lattice_stripe/billing/meter_error_report.ex` — the flat depth-2 parent; four data fields plus `:meter` and `:extra`, `from_event/1` and `from_map/1`, and the moduledoc that leads with the fetched-attribute requirement.
- `lib/lattice_stripe/billing/meter_error_report/reason.ex` — `error_count` + `error_types`, and why this library ships no grouping or counting helpers.
- `lib/lattice_stripe/billing/meter_error_report/error_type.ex` — `code` (String, never atomized) + `error_count` + `sample_errors`, with the ten current enum values documented as non-exhaustive.
- `lib/lattice_stripe/billing/meter_error_report/sample_error.ex` — `error_message` + `request_identifier`; the join-key moduledoc.
- `test/lattice_stripe/billing/meter_error_report_test.exs` — 29 pure unit tests, no transport, no client.

**Modified**
- `mix.exs` — four entries appended to the `"Billing Metering"` ExDoc group, parent immediately followed by its own depth-3 value objects. Docs grouping only; no dependency added or bumped, and `mix.lock` is byte-identical (sha256 `508562a3…` before and after).
- `test/support/fixtures/metering.ex` — new nested `MeterErrorReport` fixture module: `basic/1`, `event/1`, `no_meter_found_event/1`, `meter_id/0`.
- `test/lattice_stripe/object_types_test.exs` — two refutation cases plus a top-level alias for the fixture.

## Decisions Made

- **A3 settled: v2 validation timestamps are RFC3339 strings.** Verified directly against the live payload published on Stripe's v2 core event-types reference. The struct types them `String.t()`, tests assert `is_binary/1`, and the moduledoc's RFC3339-versus-Unix `NOTE:` stands — including its remark that one official SDK types v2 timestamps as integers and that this is wrong.
- **The published example carries a bare-UUID request identifier**, not an `idk_ltc_`-prefixed one. The fixture keeps it verbatim, and the fixture doc uses it to make the point concrete: Stripe echoes back whatever key the failing write actually used, which is precisely why letting the client auto-generate one leaves you with a value that joins to nothing.
- **The `ObjectTypes` reference is deliberately un-linked prose.** `LatticeStripe.ObjectTypes` is `@moduledoc false`, so a backticked `LatticeStripe.ObjectTypes.maybe_deserialize/1` produced an ExDoc "references function … but it is hidden" warning (see Issues). The sentence now names the registry in prose and states the same structural fact without an autolink.
- **The fixture's `developer_message_summary` was restated to match its own counts.** The published example reads "There is 1 invalid event" against a single error; this fixture carries 902 errors because the plan requires two error types (one with two samples, one with 900 errors and no samples). Shipping the verbatim string against 902 errors would have made the fixture self-contradictory. The departure is documented inline alongside the exhaustive list of what *is* verbatim.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] `from_event/1` now raises a directive `ArgumentError` on an event with no `data`**
- **Found during:** Task 2 (the parent module and `from_event/1`)
- **Issue:** The planned implementation is `%{from_map(data) | meter: related && related.id}`. When `data` is nil — which is exactly what a *delivered webhook body* looks like, the single trap the moduledoc leads with — `from_map(nil)` returns nil and the struct update raises a bare `** (BadMapError) expected a map, got: nil`. That error names neither the cause nor the fix, at the precise point where the adopter has made the mistake this whole module exists to prevent.
- **Fix:** Added a second `from_event/1` clause (guarded by `is_map(data)` on the first) raising an `ArgumentError` whose message states that `data` is a fetched attribute, that the webhook body does not contain it, and shows the two-line `Webhook.fetch_event/3` fix, plus the offending event's id and type.
- **Files modified:** `lib/lattice_stripe/billing/meter_error_report.ex`, `test/lattice_stripe/billing/meter_error_report_test.exs`
- **Verification:** New test `from_event/1 raises a directive ArgumentError when the event carries no data` asserts `assert_raise ArgumentError, ~r/fetch_event/`. Passes.
- **Committed in:** `fc3b1d9` (Task 2 GREEN commit)
- **Surface impact:** none — no new public function; `from_event/1` keeps arity 1 and its documented success behavior is unchanged. It does not disturb the Task 3 refutation set.

**2. [Rule 3 - Blocking] `mix deps.get` run because `deps/` was absent in a fresh worktree**
- **Found during:** Setup, before Task 1
- **Issue:** The worktree had no `deps/` directory, so nothing could compile or test.
- **Fix:** Ran `mix deps.get` (explicitly permitted by the phase gates). No dependency was added, removed or bumped.
- **Verification:** `mix.lock` sha256 is `508562a3cd1f8dbd98726bead3a5172ed3080e6f59f0c1acbc58da702ab40b48` both before and after; `git diff --stat mix.lock` is empty. The gate's byte-identical requirement holds, so this is reported for completeness rather than as a lock deviation.
- **Committed in:** n/a — no file changed.

---

**Total deviations:** 2 auto-fixed (1 missing critical, 1 blocking)
**Impact on plan:** No scope creep. Deviation 1 is a strictly-additive error-message improvement at the plan's own headline failure mode; deviation 2 changed no tracked file.

## Issues Encountered

- **The docs gate went red at 44 warnings before it went green.** The first draft of the parent moduledoc referenced `` `LatticeStripe.ObjectTypes.maybe_deserialize/1` `` as a backticked autolink. `ObjectTypes` is `@moduledoc false`, so ExDoc emitted "documentation references function … but it is hidden" — once per output format, pushing the count from the 42 baseline to 44 with both new warnings naming `meter_error_report.ex`. Resolved by rewriting the sentence as plain prose with no autolinkable reference. `mix docs` is back to exactly 42, with zero warnings naming any Phase 64 file. Note the pre-existing `webhook.ex:376` warning is the identical pattern against `ObjectTypes.fetch_module/1` — it is one of the baseline 42 and was left alone as out of scope.
- **A moduledoc heredoc interpolated `#{inspect(report)}`** in the "this will put idempotency keys in your logs" section and failed to compile with `undefined variable "report"`. Escaped to `\#{...}`.
- **Credo `--strict` flagged a nested-module call in `object_types_test.exs`** (`Nested modules could be aliased at the top of the invoking module`). Added a top-level `alias … as: MeterErrorReportFixture`. Credo is back to `found no issues`, exit 0.
- **The known flaky retry-telemetry test at `client_test.exs:912` did not fire** in any of this plan's full-suite runs.

## TDD Gate Compliance

Tasks 1 and 2 ran a genuine RED → GREEN cycle: each `test(...)` commit was verified failing (a `CompileError` on the undefined struct) before the corresponding `feat(...)` commit made it pass.

Task 3 is a single `test(...)` commit with no RED gate, and that is deliberate rather than a skipped step. Its entire `<behavior>` block is refutations and assertions about *already-shipped* surface (`refute function_exported?/3`, the registry key absence). There is no new production behavior for a failing test to drive, and manufacturing a RED phase would have meant temporarily adding a verb solely to delete it. No REFACTOR commits were made in any task; none was warranted.

## Verification Results

All five items from the plan's `<verification>` block, with actual numbers:

| # | Check | Result |
|---|-------|--------|
| 1 | `mix test` on the two touched test files | **59 tests, 0 failures** |
| 2 | `mix test` (full suite) | **2251 tests, 0 failures, 1 skipped** (baseline 2220; +31; criterion was ≥ 2188) |
| 3 | `mix docs` | **exit 0, 42 warnings** (= baseline), **0** naming any `meter_error_report` file |
| 4 | `mix format --check-formatted` / `mix compile --force --warnings-as-errors` / `mix credo --strict` | **all exit 0** (credo: 2265 mods/funs, no issues) |
| 5 | `git diff --stat lib/lattice_stripe/object_types.ex mix.lock` | **empty** |

Task-level acceptance greps: `to_atom` in `error_type.ex` → **0**; `Request{` under `meter_error_report/` → **no matches**; `request_identifier` in `sample_error.ex` → **11** (≥ 2); `LatticeStripe.Billing.MeterErrorReport` in `mix.exs` → **4** (≥ 4). Struct shape confirmed at runtime: `:id`/`:object`/`:livemode` all absent; `:validation_start`/`:validation_end`/`:developer_message_summary` all present.

`mix ci` was **not** run, per the phase gates — that alias is red at clean HEAD on the 42 pre-existing ExDoc warnings because it runs `mix docs --warnings-as-errors`.

## Known Stubs

None. No placeholder values, no unwired data paths, no skipped tests, and no `<verify>` block went unrun.

## Threat Flags

None. Every file created is a pure decoder over a payload obtained from an authenticated re-fetch; no network endpoint, auth path, file access or schema was added. The plan's `<threat_model>` dispositions all hold:

- **T-64-08** (trusting `event.data` from the delivered body) — mitigated structurally: `from_event/1` accepts only a `%LatticeStripe.Event{}`, and deviation 1 strengthens this by raising a directive error when a data-less (i.e. notification-shaped) event is passed.
- **T-64-06** (atom-table exhaustion from a server-controlled `code`) — mitigated: `code` is a binary, locked by an `is_binary/1` design assertion and a negative grep.
- **T-64-05** (idempotency keys in logs via default `Inspect`) — accepted per D-19 and mitigated by disclosure: the moduledoc says out loud that a raw `inspect(report)` emits them.
- **T-64-11** (a registry row for an unreachable payload) — mitigated by the Task 3 refutation; `object_types.ex` asserted unchanged.
- **T-64-SC** (package-manager installs) — zero packages installed; `mix.lock` byte-identical.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **64-07 and 64-08 (guide repairs) are unblocked and now have a target to point at.** Both shipped guides teach a handler that pattern-matches `%LatticeStripe.Event{}`, reads `event.data["object"]` and reads `reason.error_code`. All three are wrong. The correct handler now exists verbatim in `LatticeStripe.Billing.MeterErrorReport`'s moduledoc and can be lifted directly. The live enum's ten values are in `ErrorType`'s moduledoc, including the four the guide's table omits; `meter_event_value_not_found` is confirmed retired and absent from the live ten.
- **Phase 65 (OBJ-01) must not add a `billing.meter_error_report` key.** It is now locked by test, with the structural reason recorded in the test comment.
- **64-09's artifact inventory** should record four modules, one new fixture module, and four new `mix.exs` docs-group entries.
- **No blockers.** Nothing in this plan touches `meter_event_summary.ex` or its test file, which 64-03 was editing concurrently.

## Self-Check: PASSED

All five claimed commits (`fceeb81`, `e318e5e`, `17e8a5f`, `fc3b1d9`, `00cbcc7`) are present in `git log`. All five claimed source/test files plus this summary exist on disk. No missing items.

---
*Phase: 64-meter-event-summary-reads*
*Completed: 2026-07-28*
