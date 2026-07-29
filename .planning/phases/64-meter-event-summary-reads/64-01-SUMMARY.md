---
phase: 64-meter-event-summary-reads
plan: 01
subsystem: api
tags: [stripe, billing, metering, meter-event-summary, elixir, mox, exdoc]

# Dependency graph
requires:
  - phase: 63-stripe-native-entitlements
    provides: "Resource.require_param!/3 + unwrap_list/2 guard-and-decode idiom, LatticeStripe.List cursor state machine, TestHelpers.list_json/3, the refute function_exported? surface-lock practice"
  - phase: 20-billing-metering
    provides: "The Billing Metering module family, its mix.exs ExDoc group, and test/support/fixtures/metering.ex"
provides:
  - "LatticeStripe.Billing.MeterEventSummary — the library's first metering READ surface: list/2..4 over GET /v1/billing/meters/:meter_id/event_summaries, plus from_map/1"
  - "The flat depth-2 wire-named module name, now a ratified one-way contract for the whole metering read family"
  - "Private path/1 as the single interpolated path source that list/4 and the future stream!/4 both read"
  - "Private validate_id!/2 with the arity-carrying D-09 message"
  - "LatticeStripe.Test.Fixtures.Metering.MeterEventSummary.basic/1 and .list_response/1"
  - "The PROMOTION TARGET (Phase 65 / OBJ-02) header on test/support/fixtures/metering.ex"
affects: [64-03-moduledoc-and-stream, 64-04-meter-error-report, 64-05-guard-04-window-alignment, 64-06-pagination-proof, 64-08-docs-gate, 64-09-artifact-inventory, 65-object-types-and-public-fixtures]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Parent-scoped child resource: flat depth-2 module named after the wire object, parent id positional in the signature (TransferReversal / ExternalAccount precedent, extended)"
    - "Private path/1 as the interpolated analogue of the @list_path single-source constant"
    - "Private validate_id!/2 (external_account.ex shape) whose message carries the calling arity, so every ArgumentError from one function shares a grammar"

key-files:
  created:
    - lib/lattice_stripe/billing/meter_event_summary.ex
    - test/lattice_stripe/billing/meter_event_summary_test.exs
  modified:
    - mix.exs
    - test/support/fixtures/metering.ex

key-decisions:
  - "D-01 ratified as `flat`: the metering read surface ships as LatticeStripe.Billing.MeterEventSummary (depth 2, wire-named), deliberately overruling the literal text of MTR-01/MTR-02 and ROADMAP SC#1/#2"
  - "params \\\\ %{} kept despite three required filters — Phase 63's D-14 no-default rule stays scoped to create/3 (D-06)"
  - "validate_id!/2 kept at arity 2 with the name argument unused, so stream!/4 in 64-03 can call it unchanged"
  - "GUARD-04 window alignment deliberately NOT wired here — it lands in 64-05 between the require_param! block and %Request{}"

patterns-established:
  - "Pattern 1: a metering read module owns no ObjectTypes dependency — typing happens at the resource layer via Resource.unwrap_list(&from_map/1), so Phase 64 has no code dependency on Phase 65"
  - "Pattern 2: deliberate absences are documented in source next to the defstruct (no :customer, F-02) AND asserted in test, so a later contributor cannot 'fix' them by accident"
  - "Pattern 3: pre-network guards are proven by setting no Mox expectation at all — verify_on_exit! turns an escaped request into a distinguishable failure"

requirements-completed: [MTR-01]

coverage:
  - id: D1
    description: "MeterEventSummary.list/4 issues GET /v1/billing/meters/{meter_id}/event_summaries and returns {:ok, %Response{}} whose data is a %List{} of %MeterEventSummary{} structs"
    requirement: "MTR-01"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#GETs the parent-scoped /v1/billing/meters/:id/event_summaries path"
        status: pass
    human_judgment: false
  - id: D2
    description: "customer, start_time, end_time and value_grouping_window all reach the wire as query params"
    requirement: "MTR-01"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#places customer, start_time and end_time on the wire as query params"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#places value_grouping_window on the wire when supplied"
        status: pass
    human_judgment: false
  - id: D3
    description: "from_map/1 populates all seven wire fields and keeps aggregated_value a float, never rounded or coerced"
    requirement: "MTR-01"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#populates all seven wire fields"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#keeps aggregated_value a float — never rounded, never coerced"
        status: pass
    human_judgment: false
  - id: D4
    description: "The struct has no :customer key — the customer association is an input, never an output (F-02)"
    requirement: "MTR-01"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#has no :customer key — the customer is an input, never an output"
        status: pass
    human_judgment: false
  - id: D5
    description: "Empty-page and ordering edges: an empty data array decodes to [] not nil; wire order is preserved exactly; from_map(nil) is nil and from_map(struct) is idempotent"
    requirement: "MTR-01"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#decodes an empty data array to an empty list, never nil"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#preserves Stripe's wire ordering exactly"
        status: pass
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#is idempotent — an already-decoded struct passes through unchanged"
        status: pass
    human_judgment: false
  - id: D6
    description: "All five pre-network ArgumentError guards fire before any transport call, first-failure in the order meter_id, customer, start_time, end_time, with the D-08/D-09 messages verbatim"
    requirement: "MTR-01"
    verification:
      - kind: unit
        ref: "test/lattice_stripe/billing/meter_event_summary_test.exs#pre-network guards (8 tests: nil id, empty id, missing customer/start_time/end_time, both first-failure orderings, presence-not-emptiness)"
        status: pass
    human_judgment: false
  - id: D7
    description: "The module is registered in the mix.exs groups_for_modules 'Billing Metering' list so ExDoc publishes it"
    requirement: "MTR-01"
    verification:
      - kind: other
        ref: "grep -c 'LatticeStripe.Billing.MeterEventSummary' mix.exs => 1; mix docs exits 0 with 42 warnings (baseline, unchanged) and zero naming the new file"
        status: pass
    human_judgment: false

# Metrics
duration: 8min
completed: 2026-07-28
status: complete
---

# Phase 64 Plan 01: MeterEventSummary Tracer Slice Summary

**The library's first metering read: `LatticeStripe.Billing.MeterEventSummary.list/4` walks guard validation → `%Request{}` → transport → `Resource.unwrap_list/2` → typed structs, with the flat depth-2 module name ratified as a one-way contract.**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-07-28T17:38:00Z
- **Completed:** 2026-07-28T17:46:00Z
- **Tasks:** 2 (1 decision checkpoint, 1 TDD tracer)
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments

- Shipped `LatticeStripe.Billing.MeterEventSummary` — `list/2..4` over `GET /v1/billing/meters/:meter_id/event_summaries` plus `from_map/1`, proven end to end against a Mox transport. This is the first surface in the library that can read metered usage back; every prior metering surface only wrote.
- Ratified and implemented the phase's only one-way door: the module is **flat at depth 2 and named after the wire `object` string**, matching all ~50 request-owning modules in the repo, both parent-scoped precedents, Stripe's own codegen directive, and every official SDK.
- Encoded four Stripe facts as design rather than accident: the struct carries **no `:customer`** (F-02), `aggregated_value` **stays a float** (F-05), an empty page decodes to `[]` not `nil`, and wire order is preserved exactly.
- Made all four `ArgumentError` paths pre-network and first-failure-ordered, with messages that carry the arity so `list/4`'s whole error grammar is uniform — making LatticeStripe the only Stripe SDK in any language that catches a missing `customer`/`start_time`/`end_time` before the wire.
- Registered the module in the `"Billing Metering"` ExDoc group without moving the docs baseline: `mix docs` still exits 0 at exactly 42 warnings, zero of them naming the new file.

## Task Commits

Each task was committed atomically:

1. **Task 1: Confirm the one-way module name** — no commit (decision checkpoint, pre-ratified by the operator; no files changed)
2. **Task 2: End-to-end "read one page of usage summaries" (TDD tracer)** — `d0c1bb8` (test, RED) → `ae3f680` (feat, GREEN)

No REFACTOR commit: `mix credo --strict` and `mix compile --warnings-as-errors` were both clean on the first GREEN pass, so there was nothing to clean up.

_Note: TDD tasks may have multiple commits (test → feat → refactor)_

## Files Created/Modified

- `lib/lattice_stripe/billing/meter_event_summary.ex` **(new)** — the resource module: `list/2..4`, `from_map/1`, private `path/1`, private `validate_id!/2`, `@known_fields` in the square-bracket sigil form, and a `defstruct` of exactly the seven required wire fields plus `:extra`.
- `test/lattice_stripe/billing/meter_event_summary_test.exs` **(new)** — 19 tests across four blocks: `list/4` wire behaviour, `from_map/1` decode, the struct-shape absence lock, and the eight pre-network guard tests.
- `mix.exs` — one line appended to the `"Billing Metering"` `groups_for_modules` list, after `MeterEventStream.Session`, keeping the family's define → write → read → diagnose lifecycle order.
- `test/support/fixtures/metering.ex` — new nested `MeterEventSummary` fixture module (`basic/1`, `list_response/1`), plus the 6-line `PROMOTION TARGET (Phase 65 / OBJ-02)` header cloned from `test/support/fixtures/entitlements.ex`.

## Decisions Made

### D-01 (one-way door) — ratified as `flat`

**The operator ratified `flat` before execution began.** The metering read surface ships as
`LatticeStripe.Billing.MeterEventSummary` (and, in 64-04, `LatticeStripe.Billing.MeterErrorReport`),
with `.Reason` / `.ErrorType` / `.SampleError` nesting at depth 3 as **value objects only** — they own no
`%Request{}`.

This deliberately overrules the literal text of MTR-01, MTR-02 and ROADMAP success criteria 1 and 2, which
all say `Billing.Meter.EventSummary`. The operator's stated reasoning, recorded here because this is the
phase's only one-way door and this record is what a future contributor will look for when they wonder why
the module is not nested:

- Zero of the ~50 request-owning modules in this repo sit at depth 3. Within `"Billing Metering"`
  specifically, depth 3 *means* value object — nesting would actively invert an established rule.
- Both existing parent-scoped child resources (`TransferReversal`, `ExternalAccount`) are flat and
  wire-named; parent-scoping is expressed in the signature, not the module name.
- Stripe's own codegen directive is `{class_name: "MeterEventSummary", in_package: "Billing"}`, and all six
  official SDKs plus the Elixir peer `stripity_stripe` implement it that way.
- It preserves the wire↔module mental map (dot = module boundary, underscore = CamelCase, already 43/43
  outside the `LineItem` family) that Phase 65's ObjectTypes work depends on.

The requirement text was already amended during the context commit (D-02) and was **re-verified at this
worktree's base before implementing**: `.planning/REQUIREMENTS.md` MTR-01/MTR-02 read
`LatticeStripe.Billing.MeterEventSummary`, MTR-03 reads `reason.error_types`, `.planning/ROADMAP.md`
SC#1/#2/#3 match, and Phase 65's OBJ-01 already excludes `billing.meter_error_report`. **No artifact edit
remained, and none was made.**

The atom `Elixir.LatticeStripe.Billing.MeterEventSummary` becomes a published semver contract at the v1.10
Hex tag. Renaming after that is a major version bump.

### Other decisions

- **`params \\ %{}` kept** despite three required filters — D-06 scopes Phase 63's D-14 no-default rule to
  `create/3` only, and the just-shipped `Entitlements.ActiveEntitlement.list/3` keeps the default despite a
  required `customer`. Dropping it would cost the uniform `list/2..4` shape every other module has.
- **`validate_id!/2` kept at arity 2 with `name` unused in both clauses.** The plan mandates arity 2 (the
  `external_account.ex` shape) while D-09 mandates a message that carries the arity rather than the field
  name. A source comment states why, so the unused argument reads as deliberate: `stream!/4` in 64-03 calls
  the same helper unchanged.
- **GUARD-04 deliberately not wired.** The window-alignment guard lands in 64-05, inserted between the
  `require_param!` block and `%Request{}` — exactly where `meter.ex:110` places its own guard call. The
  ordering comment in `list/4` already names that slot.
- **The moduledoc is first-pass only**, as the plan directs: wire object, `mtrusg_` prefix, endpoint,
  required filters, and the `limit`-default-10 truncation note. The F-02/F-08/F-09 warning admonition, the
  full truncation section and the deliberate-absence section land in 64-03.
- **Moduledoc example restructured to avoid a new ExDoc warning.** The `{:ok, resp} = ...` binding sits in a
  top-level indented code block, never inside a numbered list — the exact shape that produces the two
  existing `meter_event_stream.ex:15/24` "Illegal attributes … ignored in IAL" warnings. Verified: the docs
  warning count is unchanged at 42 and zero warnings name the new file.

## Deviations from Plan

None — plan executed exactly as written.

No deviation rule fired. No bugs were found, no missing critical functionality was needed, nothing blocked,
and no architectural change arose. No packages were installed; `mix.lock` is byte-identical
(`git diff --stat mix.lock` is empty), and `lib/lattice_stripe/object_types.ex` is untouched as the phase
fence requires.

## Issues Encountered

None.

One thing worth recording as a near-miss rather than an issue: the first draft of the moduledoc opened its
usage example with `{:ok, %LatticeStripe.Response{data: ...}} =` as the first line of an indented block
nested under prose. That is the precise construct behind two of the repo's 42 existing ExDoc warnings, and
it would have introduced a warning naming a Phase 64 *new* file — which 64-08's differential docs gate
forbids outright. It was caught before the GREEN commit by measuring `mix docs` warnings before and after,
and the example was rewritten to bind `params` first. Both measurements read 42.

## Verification Run

| Gate | Result |
|------|--------|
| `mix test test/lattice_stripe/billing/meter_event_summary_test.exs` | 19 tests, 0 failures |
| `mix test` (full suite) | **2207 tests, 0 failures, 1 skipped (204 excluded)** — baseline was 2188, so +19 and no regression |
| `mix format --check-formatted` | exit 0 |
| `mix compile --warnings-as-errors --force` | exit 0 |
| `mix credo --strict` | 2238 mods/funs, no issues |
| `mix docs` | exit 0, 42 warnings (baseline 42, unchanged), zero naming `meter_event_summary` |
| `git diff --stat mix.lock` | empty |
| `git diff --stat lib/lattice_stripe/object_types.ex` | empty |
| Runtime surface probe | `function_exported?/3` true for `list/2`, `list/3`, `list/4`, `from_map/1`; `Map.has_key?(struct, :customer)` false; `from_map(nil)` returns `nil` |

`mix ci` was deliberately **not** used as a gate — it is RED at clean HEAD on 42 pre-existing ExDoc
warnings unrelated to this phase, per the differential gate in `64-VALIDATION.md`.

## Known Stubs

None. No stub, placeholder, TODO, or unwired data path was introduced. Every surface this plan claims is
implemented and exercised by a passing test.

Two deliberate *absences* are worth distinguishing from stubs, because both are documented design and both
are asserted or slotted rather than left dangling: `stream!/4` and `list!/4` land in 64-03 (this plan's
declared public surface is `list/2..4` + `from_map/1`), and GUARD-04 lands in 64-05 at a named slot inside
`list/4`.

## Threat Flags

None. The plan's threat register covers every surface this plan touched: T-64-01 (path interpolation of
`meter_id`) is mitigated by `validate_id!/2` raising before `%Request{}` is constructed, verified by two
tests that set no transport expectation; T-64-07 (unbounded result set) is bounded by Stripe's `limit` and
documented in the `list/4` `@doc`; T-64-SC is accepted by construction because zero packages were installed.

No new network endpoint, auth path, file access pattern, or trust-boundary schema change was introduced
beyond the single GET this plan exists to add.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Ready. The tracer proved the whole metering read stack on one path, so every later plan in this phase
expands outward from a foundation that is known to work rather than one that is assumed to:

- **64-03** (moduledoc + `stream!/4` + `list!/4`) inherits the private `path/1` single-source and can call
  `validate_id!/2` unchanged at arity 2. The `@moduledoc` is deliberately first-pass and awaits the
  F-02/F-08/F-09 admonition, the truncation section, and the deliberate-absence section.
- **64-05** (GUARD-04) has its insertion point already named by a comment in `list/4`: between the
  `require_param!` block and `%Request{}`.
- **64-06** (pagination proof) has the fixture it needs — `Metering.MeterEventSummary.basic/1` accepts
  overrides, so multi-page bodies with distinct `mtrusg_` ids are one call away, and
  `TestHelpers.list_json/3` already carries `has_more`.
- **64-08** (docs gate) starts from a verified-unmoved baseline of exactly 42 warnings with zero naming any
  Phase 64 file.
- **64-09** (artifact inventory / ExDoc placement) can assert `LatticeStripe.Billing.MeterEventSummary` is
  in the `"Billing Metering"` group; it is the group's eleventh entry, well under the 22 that would force a
  split.
- **Phase 65** (ObjectTypes + public fixtures) gets the `PROMOTION TARGET (Phase 65 / OBJ-02)` header now
  present on `test/support/fixtures/metering.ex`, matching the entitlements fixture file.

No blockers. One concern to carry forward, unchanged from CONTEXT: `MeterEventSummary` returns no
`customer` field, so a partial filter drop on a later page would leak undetectably — which is exactly why
64-06's assertion (2) is the phase's highest-value test.

## Self-Check: PASSED

- `lib/lattice_stripe/billing/meter_event_summary.ex` — FOUND
- `test/lattice_stripe/billing/meter_event_summary_test.exs` — FOUND
- `.planning/phases/64-meter-event-summary-reads/64-01-SUMMARY.md` — FOUND
- Commit `d0c1bb8` (test, RED) — FOUND
- Commit `ae3f680` (feat, GREEN) — FOUND
- Commit `5831337` (docs, SUMMARY) — FOUND
- Working tree clean; base `a22e197` unchanged beneath the three plan commits

---
*Phase: 64-meter-event-summary-reads*
*Completed: 2026-07-28*
